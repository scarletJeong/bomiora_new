import '../../services/category_service.dart';

/// API 실패 시 메뉴·탭용 기본 건강 콘텐츠 카테고리
const List<String> contentCategoryListFallback = [
  '건강상식',
  '운동가이드',
  '추천식단',
  '질환관리',
];

/// 건강 콘텐츠 카테고리 (메뉴·목록·대시보드 공통)
class ContentCategoryCatalog {
  ContentCategoryCatalog._();

  static List<String>? _cache;

  static Future<List<String>> categories({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null && _cache!.isNotEmpty) {
      return _cache!;
    }

    final result = await CategoryService.getCategoriesByGroup('content');
    final dynamic list = result['categories'];
    if (result['success'] == true && list is List && list.isNotEmpty) {
      final fromApi = list
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (fromApi.isNotEmpty) {
        _cache = fromApi;
        return _cache!;
      }
    }

    _cache = List<String>.from(contentCategoryListFallback);
    return _cache!;
  }

  static void clearCache() {
    _cache = null;
  }
}
