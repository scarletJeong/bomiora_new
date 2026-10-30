import 'package:shared_preferences/shared_preferences.dart';

/// 회원별 건강앱 자동 연동 여부.
/// 끄면 이후 자동 조회를 하지 않는다. 서버에 이미 저장된 기록은 지우지 않는다.
class HealthSyncLinkStore {
  HealthSyncLinkStore._();

  static String _key(String mbId) => 'health_sync_enabled_${mbId.trim()}';

  static Future<bool> isEnabled(String mbId) async {
    final id = mbId.trim();
    if (id.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(id)) ?? false;
  }

  static Future<void> setEnabled(String mbId, bool enabled) async {
    final id = mbId.trim();
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(id), enabled);
  }
}
