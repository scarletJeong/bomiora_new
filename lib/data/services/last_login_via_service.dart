import 'package:shared_preferences/shared_preferences.dart';

/// 이 기기에서 마지막으로 쓴 로그인 수단 (카카오 / 네이버 / 이메일).
class LastLoginViaService {
  LastLoginViaService._();

  static const String prefsKey = 'bomiora_last_login_via';
  static const String kakao = 'kakao';
  static const String naver = 'naver';
  static const String email = 'email';

  static String? normalize(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    if (value == kakao || value == naver || value == email) return value;
    return null;
  }

  static Future<void> save(String via) async {
    final value = normalize(via);
    if (value == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, value);
  }

  static Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return normalize(prefs.getString(prefsKey));
  }
}
