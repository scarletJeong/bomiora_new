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
      case 'point':
        return '포인트 적립';
      case 'announcement':
      case 'notice':
        return '공지사항';
      case 'event':
        return '이벤트';
      default:
        return '알림';
    }
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
    final id = (data['notification_id'] ??
            data['noti_id'] ??
            '${DateTime.now().millisecondsSinceEpoch}_${type ?? 'push'}')
        .toString();

    final item = AppNotificationItem(
      id: id,
      category: _categoryFromType(type),
      title: (title ?? data['title']?.toString() ?? '알림').trim(),
      description: (body ?? data['body']?.toString())?.trim(),
      createdAt: DateTime.now(),
      isRead: false,
      type: type,
      linkId: data['id']?.toString() ?? data['wr_id']?.toString(),
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
