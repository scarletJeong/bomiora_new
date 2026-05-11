import 'package:shared_preferences/shared_preferences.dart';

/// 최근 검색어 (로컬). 동일 문구는 맨 앞으로만 옮기고 중복 제거.
class RecentSearchService {
  RecentSearchService._();

  static const String _key = 'recent_search_queries_v1';
  static const int _maxItems = 15;

  static Future<List<String>> getQueries() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_key);
    if (raw == null) return const [];
    return raw.where((e) => e.trim().isNotEmpty).toList();
  }

  /// 최근 목록 앞에 추가. 빈 문자열은 무시.
  static Future<void> addQuery(String raw) async {
    final t = raw.trim();
    if (t.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final list = List<String>.from(p.getStringList(_key) ?? []);
    list.remove(t);
    list.insert(0, t);
    while (list.length > _maxItems) {
      list.removeLast();
    }
    await p.setStringList(_key, list);
  }

  static Future<void> removeQuery(String raw) async {
    final t = raw.trim();
    final p = await SharedPreferences.getInstance();
    final list = List<String>.from(p.getStringList(_key) ?? [])
      ..removeWhere((e) => e.trim() == t);
    await p.setStringList(_key, list);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}
