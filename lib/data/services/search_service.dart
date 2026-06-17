import 'dart:convert';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/product/product_model.dart';
import '../repositories/product/product_repository.dart';

class SearchResult {
  final String query;
  final List<Product> prescriptionProducts;
  final List<Product> storeProducts;
  final List<Map<String, dynamic>> contents;

  const SearchResult({
    required this.query,
    required this.prescriptionProducts,
    required this.storeProducts,
    required this.contents,
  });
}

/// 홈 통합 검색: `/api/search` 단일 호출.
class SearchService {
  SearchService._();

  /// 비대면 진료 공식 카탈로그 (`get_product.dart` productPrescriptionCategoryList)
  static const List<String> _rxCatalogCategoryIds = ['10', '20', '80', '50'];

  /// 스토어 공식 카탈로그 (`get_product.dart` productGeneralCategoryList)
  static const List<String> _storeCatalogCategoryIds = [
    '11',
    '21',
    '51',
    '60',
    '70',
  ];

  static List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        out.add(item);
      } else if (item is Map) {
        out.add(Map<String, dynamic>.from(item));
      }
    }
    return out;
  }

  static List<Product> _parseProductsExcludingInfluencer(dynamic raw) {
    final list = _asMapList(raw);
    return list
        .where((m) => !Product.isInfluencerFromRawJson(m))
        .map((m) => Product.fromJson(m))
        .toList(growable: false);
  }

  static String _normalizeSearchText(String? raw) {
    if (raw == null) return '';
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _productMatchesQuery(Product product, String query) {
    final q = query.trim();
    if (q.isEmpty) return false;

    final fields = <String?>[
      product.name,
      product.itBasic,
      product.itSubject,
      product.description,
      product.categoryName,
    ];

    for (final field in fields) {
      if (_normalizeSearchText(field).contains(q)) return true;
    }
    return false;
  }

  /// 검색 API가 인플루언서·기타 채널 위주로 반환할 때 공식 카탈로그에서 보완.
  static Future<List<Product>> _searchCatalogProducts({
    required String query,
    required List<String> categoryIds,
    required String productKind,
  }) async {
    final q = query.trim();
    if (q.isEmpty || categoryIds.isEmpty) return const [];

    try {
      final lists = await Future.wait(
        categoryIds.map(
          (categoryId) => ProductRepository.getProductsByCategory(
            categoryId: categoryId,
            productKind: productKind,
            page: 1,
            pageSize: 100,
          ),
        ),
      );

      return lists
          .expand((list) => list)
          .where((p) => !p.isInfluencerProduct)
          .where((p) => _productMatchesQuery(p, q))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// 카탈로그 매칭을 우선, 검색 API 결과는 중복 없이 뒤에 합침.
  static List<Product> _mergeProductsById(
    List<Product> primary,
    List<Product> secondary,
  ) {
    final seen = <String>{};
    final merged = <Product>[];

    void addAll(Iterable<Product> items) {
      for (final product in items) {
        if (seen.add(product.id)) {
          merged.add(product);
        }
      }
    }

    addAll(primary);
    addAll(secondary);
    return merged;
  }

  static Future<SearchResult> searchAll(
    String query, {
    int rxLimit = 20,
    int storeLimit = 20,
    int contentLimit = 20,
  }) async {
    final q = query.trim();
    if (q.isEmpty) {
      return const SearchResult(
        query: '',
        prescriptionProducts: [],
        storeProducts: [],
        contents: [],
      );
    }

    final endpoint =
        '${ApiEndpoints.search}?q=${Uri.encodeQueryComponent(q)}'
        '&rxLimit=$rxLimit&storeLimit=$storeLimit&contentLimit=$contentLimit';

    final responseFuture = ApiClient.get(endpoint);
    final catalogRxFuture = _searchCatalogProducts(
      query: q,
      categoryIds: _rxCatalogCategoryIds,
      productKind: 'prescription',
    );
    final catalogStoreFuture = _searchCatalogProducts(
      query: q,
      categoryIds: _storeCatalogCategoryIds,
      productKind: 'general',
    );

    final response = await responseFuture;
    final catalogRxItems = await catalogRxFuture;
    final catalogStoreItems = await catalogStoreFuture;

    if (response.statusCode != 200) {
      throw Exception('검색 API 실패 (status=${response.statusCode})');
    }

    final decoded = json.decode(response.body);
    if (decoded is! Map) {
      throw Exception('검색 API 응답 형식이 올바르지 않습니다.');
    }

    final body = Map<String, dynamic>.from(decoded);
    if (body['success'] != true) {
      throw Exception((body['message'] ?? '검색 실패').toString());
    }

    final results = body['results'] is Map
        ? Map<String, dynamic>.from(body['results'] as Map)
        : const <String, dynamic>{};

    final rx = results['prescription'] is Map
        ? Map<String, dynamic>.from(results['prescription'] as Map)
        : const <String, dynamic>{};
    final store = results['store'] is Map
        ? Map<String, dynamic>.from(results['store'] as Map)
        : const <String, dynamic>{};
    final content = results['content'] is Map
        ? Map<String, dynamic>.from(results['content'] as Map)
        : const <String, dynamic>{};

    final apiRxItems = _parseProductsExcludingInfluencer(rx['items']);
    final apiStoreItems = _parseProductsExcludingInfluencer(store['items']);
    final contentItems = _asMapList(content['items']);

    return SearchResult(
      query: (body['query'] ?? q).toString(),
      prescriptionProducts:
          _mergeProductsById(catalogRxItems, apiRxItems),
      storeProducts:
          _mergeProductsById(catalogStoreItems, apiStoreItems),
      contents: contentItems,
    );
  }
}
