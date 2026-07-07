import 'package:shared_preferences/shared_preferences.dart';

/// 인플루언서 유입 코드(`infcode` URL 파라미터) 세션·영구 저장.
/// 장바구니·찜 API에 `inf_code`로 전달한다.
class InfCodeTracker {
  InfCodeTracker._();

  static const _prefKey = 'bomiora_inf_code';
  static String? _memory;

  /// 메모리 캐시 (동기 조회용). [init] 호출 후 또는 [set] 직후 유효.
  static String? get current {
    final code = _memory?.trim();
    if (code == null || code.isEmpty) return null;
    return code;
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey)?.trim();
    _memory = (stored != null && stored.isNotEmpty) ? stored : null;
  }

  static Future<void> captureFromUri(Uri? uri) async {
    if (uri == null) return;
    final code = uri.queryParameters['infcode']?.trim() ??
        uri.queryParameters['inf_code']?.trim();
    if (code == null || code.isEmpty) return;
    await set(code);
  }

  static Future<void> set(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    _memory = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, trimmed);
  }

  static Future<void> clear() async {
    _memory = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}
