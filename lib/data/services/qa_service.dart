import 'dart:async';
import 'dart:convert';

import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/node_value_parser.dart';
import '../models/qa/qa_inquiry_model.dart';
import '../services/auth_service.dart';

/// 문의 상세 API 응답: 본문 + 상세 JSON에 포함된 답변 목록(있는 경우)
class QaDetailPayload {
  const QaDetailPayload({
    required this.inquiry,
    this.nestedReplies = const [],
    this.thread = const [],
    this.rootWrId,
    this.fallbackReplyText = '',
    this.fallbackReplyDatetime = '',
    this.repliesIncluded = false,
  });

  final QaInquiry inquiry;
  final List<QaInquiry> nestedReplies;
  final List<QaInquiry> thread;
  final int? rootWrId;
  final String fallbackReplyText;
  final String fallbackReplyDatetime;
  /// 상세 응답에 `replies`가 포함되면 별도 replies API를 호출하지 않는다.
  final bool repliesIncluded;
}

class QaService {
  static const Duration _listCacheTtl = Duration(minutes: 2);
  static const Duration _detailCacheTtl = Duration(minutes: 2);
  static const int _prefetchDetailCount = 5;
  static final Map<String, List<QaInquiry>> _listCache = {};
  static final Map<String, DateTime> _listCacheAt = {};
  static final Map<String, Future<List<QaInquiry>>> _listInFlight = {};
  static final Map<int, QaDetailPayload> _detailCache = {};
  static final Map<int, DateTime> _detailCacheAt = {};
  static final Map<int, Future<QaDetailPayload?>> _detailInFlight = {};

  static void invalidateListCache([String? mbId]) {
    if (mbId == null || mbId.trim().isEmpty) {
      _listCache.clear();
      _listCacheAt.clear();
    } else {
      final id = mbId.trim();
      _listCache.remove(id);
      _listCacheAt.remove(id);
    }
    _detailCache.clear();
    _detailCacheAt.clear();
  }

  static List<QaInquiry> _mapJsonToList(List<dynamic> list) {
    return list
        .whereType<Map>()
        .map((json) => QaInquiry.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// 상세 `data` 맵 안에 포함된 답변 배열 추출 (백엔드 스키마 차이 대응)
  static ({List<QaInquiry> replies, bool included}) _repliesFromDetailMap(
    Map<String, dynamic> map,
  ) {
    if (map.containsKey('replies')) {
      final raw = map['replies'];
      final replies = raw is List ? _mapJsonToList(raw) : const <QaInquiry>[];
      return (replies: replies, included: true);
    }
    return (replies: _repliesFromDetailData(map), included: false);
  }

  static List<QaInquiry> _repliesFromDetailData(Map<String, dynamic> map) {
    for (final key in [
      'replies',
      'reply_list',
      'comments',
      'answer_list',
      'rows',
      'list',
      'items',
    ]) {
      final raw = map[key];
      if (raw is List && raw.isNotEmpty) {
        return _mapJsonToList(raw);
      }
    }
    return [];
  }

  static String _extractReplyText(Map<String, dynamic> map) {
    for (final key in [
      'wr_7',
      'wr_reply',
      'reply',
      'reply_text',
      'reply_content',
      'answer',
      'answer_text',
      'answer_content',
      'admin_reply',
      'comment',
      're_content',
      'content_reply',
    ]) {
      final value = NodeValueParser.asString(map[key])?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String _extractReplyDatetime(Map<String, dynamic> map) {
    for (final key in [
      'reply_datetime',
      'answer_datetime',
      're_datetime',
      'wr_last',
      'updated_at',
    ]) {
      final value = NodeValueParser.asString(map[key])?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  /// `data`가 리스트가 아닐 때, 맵 안의 리스트 필드에서 답변 추출
  static List<QaInquiry> _repliesFromListApiData(dynamic data) {
    if (data is List) {
      return _mapJsonToList(data);
    }
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      return _repliesFromDetailData(m);
    }
    return [];
  }

  /// 내 문의내역 조회
  static Future<List<QaInquiry>> getMyList({bool forceRefresh = false}) async {
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }
      final id = user.id.trim();

      if (!forceRefresh) {
        final cachedAt = _listCacheAt[id];
        if (cachedAt != null &&
            DateTime.now().difference(cachedAt) < _listCacheTtl &&
            _listCache.containsKey(id)) {
          return List<QaInquiry>.from(_listCache[id]!);
        }
        final pending = _listInFlight[id];
        if (pending != null) return pending;
      }

      final request = _fetchMyList(id);
      _listInFlight[id] = request;
      try {
        return await request;
      } finally {
        if (identical(_listInFlight[id], request)) {
          _listInFlight.remove(id);
        }
      }
    } catch (e) {
      throw Exception('문의내역 조회 실패: $e');
    }
  }

  static Future<List<QaInquiry>> _fetchMyList(String mbId) async {
    final response = await ApiClient.get(
      '${ApiEndpoints.qaList}?mb_id=${Uri.encodeComponent(mbId)}',
    );

    final responseData = json.decode(response.body);
    if (responseData['success'] == true && responseData['data'] != null) {
      final List<dynamic> dataList = responseData['data'];
      final list = dataList
          .whereType<Map>()
          .map((json) => QaInquiry.fromJson(Map<String, dynamic>.from(json)))
          .toList();

      list.sort((a, b) {
        final byDt = b.wrDatetime.compareTo(a.wrDatetime);
        if (byDt != 0) return byDt;
        return b.wrId.compareTo(a.wrId);
      });

      _listCache[mbId] = list;
      _listCacheAt[mbId] = DateTime.now();
      unawaited(_prefetchVisibleDetails(list));
      return List<QaInquiry>.from(list);
    }

    _listCache[mbId] = const [];
    _listCacheAt[mbId] = DateTime.now();
    return [];
  }

  static Future<void> _prefetchVisibleDetails(List<QaInquiry> list) async {
    final ids = list
        .map((e) => e.wrId)
        .where((id) => id > 0)
        .take(_prefetchDetailCount)
        .toList();
    if (ids.isEmpty) return;
    await Future.wait(ids.map((id) => getDetail(id).catchError((_) => null)));
  }

  /// 문의 상세 조회 (`data`에 답변 배열이 같이 올 수 있음)
  static Future<QaDetailPayload?> getDetail(int wrId) async {
    try {
      if (wrId <= 0) return null;
      final cachedAt = _detailCacheAt[wrId];
      if (cachedAt != null &&
          DateTime.now().difference(cachedAt) < _detailCacheTtl &&
          _detailCache.containsKey(wrId)) {
        return _detailCache[wrId];
      }
      final pending = _detailInFlight[wrId];
      if (pending != null) return pending;

      final request = _fetchDetail(wrId);
      _detailInFlight[wrId] = request;
      try {
        return await request;
      } finally {
        if (identical(_detailInFlight[wrId], request)) {
          _detailInFlight.remove(wrId);
        }
      }
    } catch (e) {
      throw Exception('문의 상세 조회 실패: $e');
    }
  }

  static Future<QaDetailPayload?> _fetchDetail(int wrId) async {
    final response = await ApiClient.get(
      '${ApiEndpoints.qaDetail}/$wrId',
    );

    final responseData = json.decode(response.body);

    if (responseData['success'] == true && responseData['data'] != null) {
      final data = responseData['data'];
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final extracted = _repliesFromDetailMap(map);
        final threadRaw = responseData['thread'];
        final thread = threadRaw is List
            ? threadRaw
                .whereType<Map>()
                .map((json) =>
                    QaInquiry.fromJson(Map<String, dynamic>.from(json)))
                .toList()
            : const <QaInquiry>[];
        final rootWrId = NodeValueParser.asInt(responseData['root_wr_id']);
        final payload = QaDetailPayload(
          inquiry: QaInquiry.fromJson(map),
          nestedReplies: extracted.replies,
          thread: thread,
          rootWrId: rootWrId,
          fallbackReplyText: _extractReplyText(map),
          fallbackReplyDatetime: _extractReplyDatetime(map),
          repliesIncluded: extracted.included,
        );
        _detailCache[wrId] = payload;
        _detailCacheAt[wrId] = DateTime.now();
        return payload;
      }
    }

    return null;
  }

  /// 문의 답변 목록 조회
  static Future<List<QaInquiry>> getReplies(int wrId) async {
    try {
      final response = await ApiClient.get(
        '${ApiEndpoints.qaDetail}/$wrId/replies',
      );

      final decoded = json.decode(response.body);
      if (decoded is! Map) return [];

      final responseData = NodeValueParser.normalizeMap(
        Map<String, dynamic>.from(decoded),
      );

      if (responseData['success'] == true && responseData['data'] != null) {
        final data = responseData['data'];
        if (data is List) {
          return data
              .whereType<Map>()
              .map((json) =>
                  QaInquiry.fromJson(Map<String, dynamic>.from(json)))
              .toList();
        }
        return _repliesFromListApiData(data);
      }

      return [];
    } catch (e) {
      throw Exception('답변 목록 조회 실패: $e');
    }
  }

  /// 문의 첨부 사진 업로드
  static Future<String?> uploadImage(XFile image) async {
    try {
      final response = await ApiClient.uploadFile(
        ApiEndpoints.qaUploadImage,
        image,
      );
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['success'] != true || data['url'] == null) return null;
      final relativeUrl = data['url'].toString().trim();
      if (relativeUrl.isEmpty) return null;
      if (relativeUrl.startsWith('http')) return relativeUrl;
      return relativeUrl.startsWith('/') ? relativeUrl : '/$relativeUrl';
    } catch (_) {
      return null;
    }
  }

  /// 문의 작성 (단일 Q&A — 추가문의 없음)
  static Future<Map<String, dynamic>> create({
    required String subject,
    required String content,
    String? primaryType,
    String? detailType,
    List<XFile>? images,
  }) async {
    try {
      final user = await AuthService.getUser();

      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      String phoneNumber = '';
      if (user.phone != null && user.phone!.isNotEmpty) {
        phoneNumber = user.phone!.replaceAll(RegExp(r'[^0-9]'), '');
      }

      // multipart 대신 create JSON에 base64로 포함 (웹 업로드 실패 방지)
      final imagePayloads = <Map<String, String>>[];
      for (final file in (images ?? const <XFile>[]).take(3)) {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;
        if (bytes.length > 5 * 1024 * 1024) {
          throw Exception('사진 용량은 5MB 이하여야 합니다.');
        }
        final name =
            file.name.trim().isNotEmpty ? file.name.trim() : 'image.jpg';
        final lower = name.toLowerCase();
        final mime = lower.endsWith('.png')
            ? 'image/png'
            : lower.endsWith('.gif')
                ? 'image/gif'
                : lower.endsWith('.webp')
                    ? 'image/webp'
                    : 'image/jpeg';
        imagePayloads.add({
          'filename': name,
          'mime': mime,
          'data': base64Encode(bytes),
        });
      }

      final response = await ApiClient.post(
        ApiEndpoints.qaCreate,
        {
          'mb_id': user.id,
          'wr_name': user.name.isNotEmpty ? user.name : user.id,
          'wr_email': user.email.isNotEmpty ? user.email : '',
          'wr_subject': subject,
          'wr_content': content,
          if (primaryType != null && primaryType.isNotEmpty)
            'ca_name': primaryType,
          if (detailType != null && detailType.isNotEmpty) 'wr_6': detailType,
          if (imagePayloads.isNotEmpty) 'images': imagePayloads,
          'wr_password': (user.password != null && user.password!.isNotEmpty)
              ? user.password
              : user.id,
          'wr_5': phoneNumber,
          'wr_option': 'secret',
        },
      );

      final decoded = json.decode(response.body);
      final result = _normalizeResult(decoded);
      if (result['success'] == true) {
        invalidateListCache(user.id);
      }
      return result;
    } catch (e) {
      throw Exception('문의 작성 실패: $e');
    }
  }

  /// 문의 수정
  static Future<Map<String, dynamic>> update({
    required int wrId,
    required String subject,
    required String content,
    String? primaryType,
    String? detailType,
  }) async {
    try {
      final user = await AuthService.getUser();

      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final response = await ApiClient.put(
        ApiEndpoints.qaUpdate(wrId),
        {
          'wr_subject': subject,
          'wr_content': content,
          if (primaryType != null && primaryType.isNotEmpty)
            'ca_name': primaryType,
          if (detailType != null && detailType.isNotEmpty) 'wr_6': detailType,
        },
      );

      final decoded = json.decode(response.body);
      final result = _normalizeResult(decoded);
      if (result['success'] == true) {
        invalidateListCache(user.id);
      }
      return result;
    } catch (e) {
      throw Exception('문의 수정 실패: $e');
    }
  }

  /// 문의 종료 (스레드 원글 기준)
  static Future<Map<String, dynamic>> close(int wrId) async {
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final response = await ApiClient.put(
        ApiEndpoints.qaUpdate(wrId),
        {
          'mb_id': user.id,
          'is_closed': 1,
        },
      );

      final decoded = json.decode(response.body);
      final result = _normalizeResult(decoded);
      if (result['success'] == true) {
        invalidateListCache(user.id);
      }
      return result;
    } catch (e) {
      throw Exception('문의 종료 실패: $e');
    }
  }

  /// 문의 삭제 (본인 글만)
  static Future<Map<String, dynamic>> delete(int wrId) async {
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }
      final response = await ApiClient.delete(
        '${ApiEndpoints.qaDelete(wrId)}?mb_id=${Uri.encodeComponent(user.id)}',
      );
      final decoded = json.decode(response.body);
      final result = _normalizeResult(decoded);
      if (result['success'] == true) {
        invalidateListCache(user.id);
      }
      return result;
    } catch (e) {
      throw Exception('문의 삭제 실패: $e');
    }
  }

  static Map<String, dynamic> _normalizeResult(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      return NodeValueParser.normalizeMap(decoded);
    }
    if (decoded is Map) {
      return NodeValueParser.normalizeMap(Map<String, dynamic>.from(decoded));
    }
    return {
      'success': false,
      'message': '응답 형식이 올바르지 않습니다.',
    };
  }
}
