import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/failure_log.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/node_value_parser.dart';
import '../models/notification/notification_settings_model.dart';
import 'auth_service.dart';

/// 알림 설정 저장·서버 동기화, FCM 토큰 등록
class NotificationService {
  static const _prefsOrder = 'notif_order_agree';
  static const _prefsMarketing = 'notif_marketing_agree';
  static const _prefsAppPush = 'notif_app_push_agree';
  static const _prefsSms = 'notif_sms_agree';
  static const _listCacheTtl = Duration(minutes: 3);

  static NotificationSettingsModel? _memory;
  static DateTime? _memoryAt;
  static Future<NotificationSettingsModel>? _inFlight;

  static void invalidate() {
    _memory = null;
    _memoryAt = null;
    _inFlight = null;
  }

  static NotificationSettingsModel? peekSettings() {
    final cachedAt = _memoryAt;
    if (_memory == null || cachedAt == null) return null;
    if (DateTime.now().difference(cachedAt) >= _listCacheTtl) return null;
    return _memory;
  }

  static Future<NotificationSettingsModel> loadSettings({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = peekSettings();
      if (cached != null) return cached;
      if (_inFlight != null) return _inFlight!;
    }

    final request = _fetchSettings();
    _inFlight = request;
    try {
      return await request;
    } finally {
      if (identical(_inFlight, request)) _inFlight = null;
    }
  }

  static Future<NotificationSettingsModel> _readLocal() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationSettingsModel(
      orderAgree: prefs.getBool(_prefsOrder) ?? false,
      marketingAgree: prefs.getBool(_prefsMarketing) ?? false,
      appPushAgree: prefs.getBool(_prefsAppPush) ?? false,
      smsAgree: prefs.getBool(_prefsSms) ?? false,
    );
  }

  /// 라우트가 아직 없을 때의 404. 회원 없음처럼 `success`가 있는 404는 제외한다.
  static bool _isUndeployedApi(int statusCode, Map<String, dynamic>? map) {
    if (statusCode != 404) return false;
    if (map != null && map.containsKey('success')) return false;
    return true;
  }

  static Map<String, dynamic>? _decodeMap(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is! Map) return null;
      return NodeValueParser.normalizeMap(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  static String _failureMessage(Map<String, dynamic>? map, String fallback) {
    final message = map?['message']?.toString().trim();
    if (message != null && message.isNotEmpty) return message;
    final error = map?['error']?.toString().trim();
    if (error != null && error.isNotEmpty) return error;
    return fallback;
  }

  static Future<NotificationSettingsModel> _fetchSettings() async {
    if (!await AuthService.isLoggedIn()) return _readLocal();

    final user = await AuthService.getUser();
    if (user == null || user.id.isEmpty) return _readLocal();

    final response = await ApiClient.get(
      '${ApiEndpoints.userNotificationSettings}?mb_id=${Uri.encodeQueryComponent(user.id)}',
    );
    final map = _decodeMap(response.body);
    if (_isUndeployedApi(response.statusCode, map)) {
      return _readLocal();
    }
    final data = map?['data'];
    if (response.statusCode != 200 ||
        map == null ||
        map['success'] != true ||
        data is! Map) {
      throw Exception(
        _failureMessage(map, '알림 설정을 불러오지 못했습니다.'),
      );
    }

    final remote = NotificationSettingsModel.fromJson(
      Map<String, dynamic>.from(data),
    );
    await _saveLocal(remote);
    return remote;
  }

  static Future<bool> saveSettings(NotificationSettingsModel settings) async {
    if (!await AuthService.isLoggedIn()) return false;

    var mbId = '';
    try {
      final user = await AuthService.getUser();
      if (user == null || user.id.isEmpty) return false;
      mbId = user.id;

      final response = await ApiClient.put(
        ApiEndpoints.userNotificationSettings,
        {
          'mb_id': user.id,
          ...settings.toJson(),
        },
      );
      final map = _decodeMap(response.body);
      if (_isUndeployedApi(response.statusCode, map)) {
        await _saveLocal(settings);
        return true;
      }
      final ok = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          map != null &&
          map['success'] != false;
      if (!ok) {
        await FailureLog.record(
          code: 'notification.settings.save',
          mbId: mbId,
          reason: _failureMessage(map, '알림 설정 저장에 실패했습니다.'),
        );
        return false;
      }
      await _saveLocal(settings);
      return true;
    } catch (e) {
      await FailureLog.record(
        code: 'notification.settings.save',
        mbId: mbId,
        reason: e.toString(),
      );
      return false;
    }
  }

  static Future<void> _saveLocal(NotificationSettingsModel settings) async {
    _memory = settings;
    _memoryAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsOrder, settings.orderAgree);
    await prefs.setBool(_prefsMarketing, settings.marketingAgree);
    await prefs.setBool(_prefsAppPush, settings.appPushAgree);
    await prefs.setBool(_prefsSms, settings.smsAgree);
  }

  /// FCM 디바이스 토큰을 서버에 등록
  static Future<bool> registerFcmToken(String token) async {
    if (token.trim().isEmpty) return false;
    if (!await AuthService.isLoggedIn()) return false;

    try {
      final user = await AuthService.getUser();
      if (user == null || user.id.isEmpty) return false;

      final platform = _platformName();
      final response = await ApiClient.post(
        ApiEndpoints.userFcmToken,
        {
          'mb_id': user.id,
          'fcm_token': token,
          'platform': platform,
        },
      );

      if (response.statusCode == 404) {
        debugPrint('[FCM] 토큰 API 미배포(404) — 로컬 저장만 유지');
        return true;
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = json.decode(response.body);
        if (decoded is Map && decoded['success'] == false) return false;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[FCM] 토큰 등록 실패: $e');
      return false;
    }
  }

  static String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }
}
