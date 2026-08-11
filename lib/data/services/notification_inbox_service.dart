import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/node_value_parser.dart';
import '../models/notification/app_notification_model.dart';
import 'auth_service.dart';

/// 푸시·서버 알림 인박스 (로컬 캐시 + 서버 동기화)
class NotificationInboxService {
  NotificationInboxService._();

  static const String _localKeyPrefix = 'notification_inbox_v1_';

  static final ValueNotifier<int> revision = ValueNotifier(0);

  static void _bump() => revision.value++;

  static String _localKey(String mbId) => '$_localKeyPrefix$mbId';

  static String _categoryFromType(String? type) {
    switch (type?.toLowerCase()) {
      case 'login':
        return '로그인';
      case 'contact':
      case 'inquiry':
      case 'qna':
        return '1:1문의';
      case 'order':
        return '결제완료';
      case 'delivery':
        return '배송시작';
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
    final explicit = (data['notification_id'] ?? data['noti_id'])?.toString().trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final odId = (data['od_id'] ?? data['order_number'])?.toString().trim() ?? '';
    final wrId = data['wr_id']?.toString().trim() ?? '';
    final cpId = data['cp_id']?.toString().trim() ?? '';
    final t = (type ?? '').toLowerCase();

    if (t == 'review' && odId.isNotEmpty) return 'review_$odId';
    if ((t == 'order' || t == 'delivery') && odId.isNotEmpty) {
      return '${t}_$odId';
    }
    if ((t == 'contact' || t == 'inquiry' || t == 'qna') && wrId.isNotEmpty) {
      return 'contact_$wrId';
    }
    if (t == 'coupon' && cpId.isNotEmpty) return 'coupon_$cpId';

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

    final resolvedTitle =
        (title ?? data['title']?.toString() ?? '알림').trim();
    var resolvedBody =
        (body ?? data['body']?.toString())?.trim() ?? '';
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

  static Future<List<AppNotificationItem>> fetchList({
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    final user = await AuthService.getUser();
    if (user == null || user.id.trim().isEmpty) return [];

    final mbId = user.id.trim();
    List<AppNotificationItem> items;

    final server = await _fetchFromServer(mbId, limit);
    if (server != null) {
      await _saveLocalList(mbId, server);
      items = server;
    } else {
      items = await _loadLocal(mbId);
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (unreadOnly) {
      items = items.where((e) => !e.isRead).toList();
    }
    return items.take(limit).toList();
  }

  static Future<bool> markAsRead(String notificationId) async {
    final user = await AuthService.getUser();
    if (user == null || user.id.trim().isEmpty) return false;

    final mbId = user.id.trim();
    final list = await _loadLocal(mbId);
    final idx = list.indexWhere((e) => e.id == notificationId);
    if (idx >= 0) {
      list[idx] = list[idx].copyWith(isRead: true);
      await _saveLocalList(mbId, list);
    }

    try {
      await ApiClient.post(
        ApiEndpoints.userNotificationRead,
        {
          'mb_id': mbId,
          'notification_id': notificationId,
        },
      );
    } catch (_) {}

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

  /// 단일 알림 삭제 (로컬 인박스)
  static Future<bool> removeById(String notificationId) async {
    final id = notificationId.trim();
    if (id.isEmpty) return false;

    final user = await AuthService.getUser();
    if (user == null || user.id.trim().isEmpty) return false;

    final mbId = user.id.trim();
    final list = await _loadLocal(mbId);
    final next = list.where((e) => e.id != id).toList();
    if (next.length == list.length) return false;

    await _saveLocalList(mbId, next);
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
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200 || response.body.trim().isEmpty) {
        return null;
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map) return null;
      final map = NodeValueParser.normalizeMap(
        Map<String, dynamic>.from(decoded),
      );
      if (map['success'] == false) return null;

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
    } catch (_) {
      return null;
    }
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
