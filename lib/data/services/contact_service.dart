import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/node_value_parser.dart';
import '../models/contact/contact_model.dart';
import '../services/auth_service.dart';

/// 문의 상세 API 응답: 본문 + 상세 JSON에 포함된 답변 목록(있는 경우)
class ContactDetailPayload {
  const ContactDetailPayload({
    required this.contact,
    this.nestedReplies = const [],
    this.thread = const [],
    this.rootWrId,
    this.fallbackReplyText = '',
    this.fallbackReplyDatetime = '',
  });

  final Contact contact;
  final List<Contact> nestedReplies;
  final List<Contact> thread;
  final int? rootWrId;
  final String fallbackReplyText;
  final String fallbackReplyDatetime;
}

class ContactService {
  static const Map<String, String> _noCacheHeaders = {
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache',
  };

  static String _withNoCacheParam(String endpoint) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return endpoint.contains('?') ? '$endpoint&_ts=$ts' : '$endpoint?_ts=$ts';
  }

  static List<Contact> _mapJsonToContacts(List<dynamic> list) {
    return list
        .whereType<Map>()
        .map((json) => Contact.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// 상세 `data` 맵 안에 포함된 답변 배열 추출 (백엔드 스키마 차이 대응)
  static List<Contact> _repliesFromDetailData(Map<String, dynamic> map) {
    for (final key in ['replies', 'reply_list', 'comments', 'answer_list', 'rows', 'list', 'items']) {
      final raw = map[key];
      if (raw is List && raw.isNotEmpty) {
        return _mapJsonToContacts(raw);
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
    for (final key in ['reply_datetime', 'answer_datetime', 're_datetime', 'wr_last', 'updated_at']) {
      final value = NodeValueParser.asString(map[key])?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  /// `data`가 리스트가 아닐 때, 맵 안의 리스트 필드에서 답변 추출
  static List<Contact> _repliesFromListApiData(dynamic data) {
    if (data is List) {
      return _mapJsonToContacts(data);
    }
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      return _repliesFromDetailData(m);
    }
    return [];
  }

  /// 내 문의내역 조회
  static Future<List<Contact>> getMyContacts() async {
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final endpoint = _withNoCacheParam(
        '${ApiEndpoints.getMyContacts}?mb_id=${user.id}',
      );
      final response = await ApiClient.get(
        endpoint,
        additionalHeaders: _noCacheHeaders,
      );

      final responseData = json.decode(response.body);
      
      if (responseData['success'] == true && responseData['data'] != null) {
        final List<dynamic> dataList = responseData['data'];
        final contacts = dataList
            .whereType<Map>()
            .map((json) => Contact.fromJson(Map<String, dynamic>.from(json)))
            .toList();

        // 최신 질문 작성일(추가질문 포함, 서버 wr_datetime 반영) 기준 최신순 정렬(내림차순)
        contacts.sort((a, b) {
          final byDt = b.wrDatetime.compareTo(a.wrDatetime);
          if (byDt != 0) return byDt;
          return b.wrId.compareTo(a.wrId);
        });

        return contacts;
      }

      return [];
    } catch (e) {
      throw Exception('문의내역 조회 실패: $e');
    }
  }

  /// 문의 상세 조회 (`data`에 답변 배열이 같이 올 수 있음)
  static Future<ContactDetailPayload?> getContactDetail(int wrId) async {
    try {
      final response = await ApiClient.get(
        '${ApiEndpoints.getContactDetail}/$wrId',
      );

      final responseData = json.decode(response.body);

      if (responseData['success'] == true && responseData['data'] != null) {
        final data = responseData['data'];
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          if (kDebugMode) {
            final wr7 = map['wr_7'];
            final wrReply = map['wr_reply'];
            debugPrint('[ContactDetail] wr_id=$wrId wr_7=$wr7 (type=${wr7.runtimeType}) wr_reply=$wrReply');
          }
          final nested = _repliesFromDetailData(map);
          final threadRaw = responseData['thread'];
          final thread = threadRaw is List
              ? threadRaw
                  .whereType<Map>()
                  .map((json) => Contact.fromJson(Map<String, dynamic>.from(json)))
                  .toList()
              : const <Contact>[];
          final rootWrId = NodeValueParser.asInt(responseData['root_wr_id']);
          return ContactDetailPayload(
            contact: Contact.fromJson(map),
            nestedReplies: nested,
            thread: thread,
            rootWrId: rootWrId,
            fallbackReplyText: _extractReplyText(map),
            fallbackReplyDatetime: _extractReplyDatetime(map),
          );
        }
      }

      return null;
    } catch (e) {
      throw Exception('문의 상세 조회 실패: $e');
    }
  }

  /// 문의 답변 목록 조회
  static Future<List<Contact>> getContactReplies(int wrId) async {
    try {
      final response = await ApiClient.get(
        '${ApiEndpoints.getContactReplies}/$wrId/replies',
      );

      final decoded = json.decode(response.body);
      if (decoded is! Map) return [];

      final responseData = NodeValueParser.normalizeMap(
        Map<String, dynamic>.from(decoded),
      );

      if (responseData['success'] == true && responseData['data'] != null) {
        final data = responseData['data'];
        // 작동하던 앱과 동일: data가 리스트면 그대로 파싱 (맵 래핑 형태는 별도 처리)
        if (data is List) {
          return data
              .whereType<Map>()
              .map((json) => Contact.fromJson(Map<String, dynamic>.from(json)))
              .toList();
        }
        return _repliesFromListApiData(data);
      }

      return [];
    } catch (e) {
      throw Exception('답변 목록 조회 실패: $e');
    }
  }

  /// 문의 작성
  static Future<Map<String, dynamic>> createContact({
    required String subject,
    required String content,
    int? parentWrId,
  }) async {
    try {
      final user = await AuthService.getUser();

      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // wr_5에 휴대폰 번호 저장 (- 제거하고 숫자만)
      String phoneNumber = '';
      if (user.phone != null && user.phone!.isNotEmpty) {
        phoneNumber = user.phone!.replaceAll(RegExp(r'[^0-9]'), ''); // 숫자만 추출
        print('   - 추출된 번호: $phoneNumber');
      } else {
        print('   - ⚠️ 전화번호가 없습니다! 재로그인이 필요할 수 있습니다.');
      }

      final response = await ApiClient.post(
        ApiEndpoints.createContact,
        {
          'mb_id': user.id,
          'wr_name': user.name.isNotEmpty ? user.name : user.id,
          'wr_email': user.email.isNotEmpty ? user.email : '',
          'wr_subject': subject,
          'wr_content': content,
          if (parentWrId != null) 'parent_wr_id': parentWrId,
          'wr_password': (user.password != null && user.password!.isNotEmpty)
              ? user.password
              : user.id, // 사용자 비밀번호 없으면 ID 사용
          'wr_5': phoneNumber, // 휴대폰 번호 (숫자만)
          'wr_option': 'secret', // 비밀글로 설정 (웹에서 비밀글 아이콘 표시)
        },
      );

      final decoded = json.decode(response.body);
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
    } catch (e) {
      throw Exception('문의 작성 실패: $e');
    }
  }

  /// 문의 수정
  static Future<Map<String, dynamic>> updateContact({
    required int wrId,
    required String subject,
    required String content,
  }) async {
    try {
      final user = await AuthService.getUser();

      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final response = await ApiClient.put(
        ApiEndpoints.updateContact(wrId),
        {
          'wr_subject': subject,
          'wr_content': content,
        },
      );

      final decoded = json.decode(response.body);
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
    } catch (e) {
      throw Exception('문의 수정 실패: $e');
    }
  }

  /// 문의 삭제 (본인 글만)
  static Future<Map<String, dynamic>> deleteContact(int wrId) async {
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }
      final response = await ApiClient.delete(
        '${ApiEndpoints.deleteContact(wrId)}?mb_id=${Uri.encodeComponent(user.id)}',
      );
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        return NodeValueParser.normalizeMap(decoded);
      }
      if (decoded is Map) {
        return NodeValueParser.normalizeMap(Map<String, dynamic>.from(decoded));
      }
      return {'success': false, 'message': '응답 형식이 올바르지 않습니다.'};
    } catch (e) {
      throw Exception('문의 삭제 실패: $e');
    }
  }
}

