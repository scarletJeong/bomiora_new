import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static Future<NotificationSettingsModel> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final local = NotificationSettingsModel(
      orderAgree: prefs.getBool(_prefsOrder) ?? false,
      marketingAgree: prefs.getBool(_prefsMarketing) ?? false,
      appPushAgree: prefs.getBool(_prefsAppPush) ?? false,
      smsAgree: prefs.getBool(_prefsSms) ?? false,
    );

    if (!await AuthService.isLoggedIn()) return local;

    try {
      final user = await AuthService.getUser();
      if (user == null || user.id.isEmpty) return local;

      final response = await ApiClient.get(
        '${ApiEndpoints.userNotificationSettings}?mb_id=${Uri.encodeQueryComponent(user.id)}',
      );
      if (response.statusCode != 200) return local;

      final decoded = json.decode(response.body);
      if (decoded is! Map) return local;
      final map = NodeValueParser.normalizeMap(
        Map<String, dynamic>.from(decoded),
      );
      if (map['success'] != true || map['data'] == null) return local;

      final data = map['data'];
      if (data is! Map) return local;
      final remote = NotificationSettingsModel.fromJson(
        Map<String, dynamic>.from(data),
      );
      await _saveLocal(remote);
      return remote;
    } catch (_) {
      return local;
    }
  }

  static Future<bool> saveSettings(NotificationSettingsModel settings) async {
    await _saveLocal(settings);

    if (!await AuthService.isLoggedIn()) return true;

    try {
      final user = await AuthService.getUser();
      if (user == null || user.id.isEmpty) return true;

      final body = {
        'mb_id': user.id,
        ...settings.toJson(),
      };
      final response = await ApiClient.put(
        ApiEndpoints.userNotificationSettings,
        body,
      );
      if (response.statusCode == 404) return true;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = json.decode(response.body);
        if (decoded is Map && decoded['success'] == false) return false;
        return true;
      }
      return false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> _saveLocal(NotificationSettingsModel settings) async {
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
