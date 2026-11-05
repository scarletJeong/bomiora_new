import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/failure_log.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/node_value_parser.dart';
import '../models/notification/app_notification_model.dart';
import 'auth_service.dart';

/// 알림 목록 조회 결과. 서버 실패와 빈 목록을 구분한다.
class NotificationInboxPage {
  const NotificationInboxPage({
    required this.items,
    required this.serverFailed,
  });

  final List<AppNotificationItem> items;
  final bool serverFailed;
}

/// 푸시·서버 알림 인박스 (로컬 캐시 + 서버 동기화)
class NotificationInboxService {
  NotificationInboxService._();

  static const String _localKeyPrefix = 'notification_inbox_v1_';
  static const String _deletedKeyPrefix = 'notification_inbox_deleted_v1_';

  static final ValueNotifier<int> revision = ValueNotifier(0);
  static bool _serverListMissing = false;

  static void _bump() => revision.value++;

  static String _localKey(String mbId) => '$_localKeyPrefix$mbId';
  static String _deletedKey(String mbId) => '$_deletedKeyPrefix$mbId';

  static String _categoryFromType(String? type) {
    switch (type?.toLowerCase()) {
      case 'login':
        return '로그인';
      case 'contact':
      case 'inquiry':
      case 'qna':
        return '1:1문의';
      case 'review':
        return '리뷰';
      case 'point':
        return '포인트 적립';
      case 'coupon':
        return '쿠폰';
      case 'announcement':
      case 'notice':
        return '공지사항';
      case 'event':
        return '이벤트';
      default:
        return '알림';
    }
  }

  /// 동일 푸시 중복 저장 방지용 안정 ID
  static String _stableInboxId(Map<String, dynamic> data, String? type) {
    final explicit =
        (data['notification_id'] ?? data['noti_id'])?.toString().trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final odId =
        (data['od_id'] ?? data['order_number'])?.toString().trim() ?? '';
    final wrId = data['wr_id']?.toString().trim() ?? '';
    final cpId = data['cp_id']?.toString().trim() ?? '';
    final t = (type ?? '').toLowerCase();

    if (t == 'review' && odId.isNotEmpty) return 'review_$odId';
    if ((t == 'contact' || t == 'inquiry' || t == 'qna') && wrId.isNotEmpty) {
      return 'contact_$wrId';
    }
    if (t == 'coupon' && cpId.isNotEmpty) return 'coupon_$cpId';
    if (t == 'point') {
      final day = (data['ymd'] ?? data['date'])?.toString().trim();
      final stamp = (day != null && day.isNotEmpty)
          ? day
          : DateTime.now().toIso8601String().substring(0, 10);
      final amount = (data['point'] ?? data['id'] ?? '').toString().trim();
      return 'point_${stamp}_$amount';
    }

    final fallbackId = data['id']?.toString().trim() ?? '';
    if (fallbackId.isNotEmpty && t.isNotEmpty) return '${t}_$fallbackId';

    return '${DateTime.now().millisecondsSinceEpoch}_${t.isEmpty ? 'push' : t}';
  }

  /// FCM 수신 시 인박스에 저장
  static Future<void> addFromFcm({
    required Map<String, dynamic> data,
    String? title,
    String? body,
  }) async {
    final mbId = data['mb_id']?.toString().trim() ??
        (await AuthService.getUser())?.id.trim() ??
        '';
    if (mbId.isEmpty) return;

    final type = data['type']?.toString();
    final id = _stableInboxId(data, type);

    final resolvedTitle = (title ?? data['title']?.toString() ?? '알림').trim();
    var resolvedBody = (body ?? data['body']?.toString())?.trim() ?? '';
    // 제목과 본문이 같으면 회색 보조문구로 중복 표시되지 않게 제거
    if (resolvedBody.isEmpty || resolvedBody == resolvedTitle) {
      resolvedBody = '';
    }

    final linkId = data['od_id']?.toString() ??
        data['order_number']?.toString() ??
        data['wr_id']?.toString() ??
        data['cp_id']?.toString() ??
        data['id']?.toString();

    final item = AppNotificationItem(
      id: id,
      category: _categoryFromType(type),
      title: resolvedTitle,
      description: resolvedBody.isEmpty ? null : resolvedBody,
      createdAt: DateTime.now(),
      isRead: false,
      type: type,
      linkId: linkId,
    );

    await _upsertLocal(mbId, item);
    _bump();
  }

  static Future<NotificationInboxPage> fetchList({
    int limit = 50,
    bool unreadOnly = false,
    bool allowServer = true,
    bool refresh = false,
  }) async {
    if (refresh) _serverListMissing = false;

    final user = await AuthService.getUser();
    if (user == null || user.id.trim().isEmpty) {
      return const NotificationInboxPage(items: [], serverFailed: false);
    }

    final mbId = user.id.trim();
    List<AppNotificationItem> items;

    final deleted = await _loadDeleted(mbId);
    final List<AppNotificationItem>? server;
    final bool serverFailed;
    if (!allowServer) {
      server = null;
      serverFailed = false;
    } else if (_serverListMissing) {
      server = null;
      serverFailed = true;
    } else {
      server = await _fetchFromServer(mbId, limit);
      serverFailed = server == null;
    }
    final local = (await _loadLocal(mbId))
        .where((item) => !deleted.contains(item.id))
        .toList();
    if (server != null) {
      final visibleServer =
          server.where((item) => !deleted.contains(item.id)).toList();
      items = _mergeInbox(local, visibleServer);
      await _saveLocalList(mbId, items);
    } else {
      items = local;
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (unreadOnly) {
      items = items.where((e) => !e.isRead).toList();
    }
    return NotificationInboxPage(
      items: items.take(limit).toList(),
      serverFailed: serverFailed,
    );
  }

  static Future<bool> markAsRead(String notificationId) async {
    final id = notificationId.trim();
    if (id.isEmpty) return false;

    final user = await AuthService.getUser();
    if (user == null || user.id.trim().isEmpty) return false;

    final mbId = user.id.trim();
    try {
      final response = await ApiClient.post(
        ApiEndpoints.userNotificationRead,
        {
          'mb_id': mbId,
          'notification_id': id,
        },
      );
      if (!_isApiSuccess(response)) {
        await FailureLog.record(
          code: 'notification.read',
          mbId: mbId,
          reason: _failureReason(response),
        );
        return false;
      }
    } catch (e) {
      await FailureLog.record(
        code: 'notification.read',
        mbId: mbId,
        reason: e.toString(),
      );
      return false;
    }

    final list = await _loadLocal(mbId);
    final idx = list.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      list[idx] = list[idx].copyWith(isRead: true);
      await _saveLocalList(mbId, list);
    }
    _bump();
    return true;
  }

  /// 알림센터 전체 삭제 (로컬 인박스)
  static Future<bool> clearAll() async {
    final user = await AuthService.getUser();
    if (user == null || user.id.trim().isEmpty) return false;

    final mbId = user.id.trim();
    await _saveLocalList(mbId, []);
    _bump();
    return true;
  }

  /// 단일 알림 삭제. 삭제 API가 없으면 지운 id만 남겨 다시 합치지 않는다.
  static Future<bool> removeById(String notificationId) async {
    final id = notificationId.trim();
    if (id.isEmpty) return false;

    final user = await AuthService.getUser();
    if (user == null || user.id.trim().isEmpty) return false;

    final mbId = user.id.trim();
    try {
      final response = await ApiClient.delete(
        '${ApiEndpoints.userNotificationDelete(id)}?mb_id=${Uri.encodeQueryComponent(mbId)}',
      );
      if (_isMissingApi(response)) {
        await _rememberDeleted(mbId, id);
      } else if (!_isApiSuccess(response)) {
        await FailureLog.record(
          code: 'notification.delete',
          mbId: mbId,
          reason: _failureReason(response),
        );
        return false;
      }
    } catch (e) {
      await FailureLog.record(
        code: 'notification.delete',
        mbId: mbId,
        reason: e.toString(),
      );
      return false;
    }

    final list = await _loadLocal(mbId);
    final next = list.where((e) => e.id != id).toList();
    if (next.length != list.length) {
      await _saveLocalList(mbId, next);
    }
    _bump();
    return true;
  }

  static Future<List<AppNotificationItem>?> _fetchFromServer(
    String mbId,
    int limit,
  ) async {
    try {
      final response = await ApiClient.get(
        '${ApiEndpoints.userNotifications}?mb_id=${Uri.encodeQueryComponent(mbId)}&limit=$limit',
      );
      if (response.statusCode == 404) {
        _serverListMissing = true;
        await FailureLog.record(
          code: 'notification.list',
          mbId: mbId,
          reason: 'HTTP 404',
        );
        return null;
      }
      if (response.statusCode != 200 || response.body.trim().isEmpty) {
        await FailureLog.record(
          code: 'notification.list',
          mbId: mbId,
          reason: _failureReason(response),
        );
        return null;
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map) {
        await FailureLog.record(
          code: 'notification.list',
          mbId: mbId,
          reason: '응답 형식이 올바르지 않습니다.',
        );
        return null;
      }
      final map = NodeValueParser.normalizeMap(
        Map<String, dynamic>.from(decoded),
      );
      if (map['success'] == false) {
        await FailureLog.record(
          code: 'notification.list',
          mbId: mbId,
          reason: _failureReason(response),
        );
        return null;
      }

      final rows = map['data'] ?? map['notifications'] ?? map['items'];
      if (rows is! List) return [];

      return rows
          .map((raw) {
            if (raw is! Map) return null;
            final item = AppNotificationItem.fromJson(
              NodeValueParser.normalizeMap(Map<String, dynamic>.from(raw)),
            );
            if (item.id.isEmpty || item.title.isEmpty) return null;
            return item;
          })
          .whereType<AppNotificationItem>()
          .toList();
    } catch (e) {
      await FailureLog.record(
        code: 'notification.list',
        mbId: mbId,
        reason: e.toString(),
      );
      return null;
    }
  }

  static List<AppNotificationItem> _mergeInbox(
    List<AppNotificationItem> local,
    List<AppNotificationItem> server,
  ) {
    final byId = <String, AppNotificationItem>{
      for (final item in local) item.id: item,
    };
    for (final item in server) {
      final prev = byId[item.id];
      if (prev == null) {
        byId[item.id] = item;
        continue;
      }
      byId[item.id] = prev.copyWith(isRead: prev.isRead || item.isRead);
    }
    return byId.values.toList();
  }

  static Future<List<AppNotificationItem>> _loadLocal(String mbId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey(mbId));
      if (raw == null || raw.trim().isEmpty) return [];

      final decoded = json.decode(raw);
      if (decoded is! List) return [];

      return decoded
          .map((item) {
            if (item is! Map) return null;
            return AppNotificationItem.fromJson(
              Map<String, dynamic>.from(item),
            );
          })
          .whereType<AppNotificationItem>()
          .where((e) => e.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveLocalList(
    String mbId,
    List<AppNotificationItem> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_localKey(mbId), encoded);
  }

  static bool _isMissingApi(http.Response response) {
    return response.statusCode == 404 || response.statusCode == 405;
  }

  static bool _isApiSuccess(http.Response response) {
    final code = response.statusCode;
    if (code < 200 || code >= 300) return false;
    final body = response.body.trim();
    if (body.isEmpty) return true;
    try {
      final decoded = json.decode(body);
      if (decoded is Map && decoded['success'] == false) return false;
    } catch (_) {}
    return true;
  }

  static String _failureReason(http.Response response) {
    final code = response.statusCode;
    final body = response.body.trim();
    if (body.isEmpty) return 'HTTP $code';
    try {
      final decoded = json.decode(body);
      if (decoded is Map) {
        final message =
            (decoded['message'] ?? decoded['error'])?.toString().trim();
        if (message != null && message.isNotEmpty) return message;
      }
    } catch (_) {}
    return 'HTTP $code';
  }

  static Future<Set<String>> _loadDeleted(String mbId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_deletedKey(mbId)) ?? const <String>[];
      return raw.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> _rememberDeleted(String mbId, String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_deletedKey(mbId)) ?? <String>[];
    if (!current.contains(id)) current.add(id);
    await prefs.setStringList(_deletedKey(mbId), current);
  }

  static Future<void> _upsertLocal(
    String mbId,
    AppNotificationItem item,
  ) async {
    final list = await _loadLocal(mbId);
    list.removeWhere((e) => e.id == item.id);
    list.insert(0, item);
    while (list.length > 100) {
      list.removeLast();
    }
    await _saveLocalList(mbId, list);
  }
}
