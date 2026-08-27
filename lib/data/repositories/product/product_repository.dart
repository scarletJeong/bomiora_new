import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../presentation/shopping/utils/get_product.dart';
import '../../models/product/product_model.dart';
import '../../services/auth_service.dart';

class ProductRepository {
  static const Duration _listCacheTtl = Duration(seconds: 30);
  static final Map<String, _ProductListCacheEntry> _listCache = {};
  static const Duration _detailCacheTtl = Duration(minutes: 2);
  static final Map<String, Product> _detailCache = {};
  static final Map<String, Product> _previewCache = {};
  static final Map<String, DateTime> _detailCacheAt = {};
  static final Map<String, Future<Product?>> _detailInFlight = {};

  static List<Product> _parseProductList(dynamic data) {
    if (data is Map && data['success'] == true && data['data'] != null) {
      final raw = data['data'];
      if (raw is List) {
        return _rememberProductList(raw
            .whereType<Map>()
            .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
            .toList());
      }
    } else if (data is List) {
      return _rememberProductList(data
          .whereType<Map>()
          .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
          .toList());
    } else if (data is Map && data['products'] != null) {
      final raw = data['products'];
      if (raw is List) {
        return _rememberProductList(raw
            .whereType<Map>()
            .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
            .toList());
      }
    }
    return const [];
  }

  static List<Product> _rememberProductList(List<Product> products) {
    for (final product in products) {
      _previewCache[product.id] = product;
    }
    return products;
  }

  static Product? getProductPreview(String productId) =>
      _detailCache[productId.trim()] ?? _previewCache[productId.trim()];

  // 카테고리별 상품 목록 가져오기
  static Future<List<Product>> getProductsByCategory({
    required String categoryId,
    String? productKind,
    int page = 1,
    int pageSize = 20,
  }) async {
    final cacheKey = '$categoryId|${productKind ?? ''}|$page|$pageSize';
    final hit = _listCache[cacheKey];
    if (hit != null && DateTime.now().isBefore(hit.expiresAt)) {
      return hit.products;
    }

    try {      
      // 먼저 Spring Boot API를 시도
      String endpoint = ApiEndpoints.productListByCategory(categoryId, productKind: productKind);
      endpoint += '&page=$page&pageSize=$pageSize';
      
      
      // 인증 토큰이 있으면 헤더에 추가
      final token = await AuthService.getToken();
      Map<String, String>? headers;
      if (token != null && token.isNotEmpty) {
        headers = {'Authorization': 'Bearer $token'};
      }
      
      final response = await ApiClient.get(endpoint, additionalHeaders: headers);
      
      // Spring Boot API가 성공하면 처리
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          final products = _parseProductList(data);
          _listCache[cacheKey] = _ProductListCacheEntry(
            products: products,
            expiresAt: DateTime.now().add(_listCacheTtl),
          );
          return products;
        } catch (_) {
          return hit?.products ?? [];
        }
      }
      
      return hit?.products ?? [];
    } catch (e) {
      return hit?.products ?? [];
    }
  }

  // 상품 상세 정보 가져오기
  static Future<Product?> getProductDetail(String productId) async {
    final id = productId.trim();
    final cachedAt = _detailCacheAt[id];
    if (cachedAt != null &&
        DateTime.now().difference(cachedAt) < _detailCacheTtl) {
      return _detailCache[id];
    }
    final pending = _detailInFlight[id];
    if (pending != null) return pending;

    final request = _fetchProductDetail(id);
    _detailInFlight[id] = request;
    try {
      final result = await request;
      if (result != null) {
        _detailCache[id] = result;
        _previewCache[id] = result;
        _detailCacheAt[id] = DateTime.now();
      }
      return result;
    } finally {
      _detailInFlight.remove(id);
    }
  }

  static Future<Product?> _fetchProductDetail(String productId) async {
    try {
      final response = await ApiClient.get('${ApiEndpoints.productDetail}?id=$productId');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        Product? productObj;
        if (data is Map && data['success'] == true && data['data'] != null) {
          final product = data['data'];
          if (product is Map) {
            productObj = Product.fromJson(Map<String, dynamic>.from(product));
          }
        } else if (data is Map && data['product'] != null) {
          final product = data['product'];
          if (product is Map) {
            productObj = Product.fromJson(Map<String, dynamic>.from(product));
          }
        }
        return productObj;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  // 인기 상품 목록 가져오기
  static Future<List<Product>> getPopularProducts({int limit = 10}) async {
    try {
      final response = await ApiClient.get('${ApiEndpoints.popularProducts}?limit=$limit');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data is Map && data['success'] == true && data['data'] != null) {
          final List<dynamic> products = data['data'];
          return _rememberProductList(products
              .whereType<Map>()
              .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
              .toList());
        } else if (data is List) {
          return _rememberProductList(data
              .whereType<Map>()
              .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
              .toList());
        }
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 신상품 — API 정렬(`it_order, it_id desc`) 그대로, [limit]개
  static Future<List<Product>> getNewProducts({int limit = 4}) async {
    final cacheKey = 'new|$limit';
    final hit = _listCache[cacheKey];
    if (hit != null && DateTime.now().isBefore(hit.expiresAt)) {
      return hit.products;
    }

    try {
      final response = await ApiClient.get(
        '${ApiEndpoints.newProducts}?limit=$limit',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        var list = _parseProductList(data);

        if (limit > 0 && list.length > limit) {
          list = list.take(limit).toList();
        }
        _listCache[cacheKey] = _ProductListCacheEntry(
          products: list,
          expiresAt: DateTime.now().add(_listCacheTtl),
        );
        return list;
      }

      return hit?.products ?? [];
    } catch (e) {
      return hit?.products ?? [];
    }
  }

  /// MD pick — API(`/md-pick`)가 it_type5 + 정렬.
  /// 클라이언트: it_kind=general + ca_id ≠ a0, 최대 [limit]개
  static Future<List<Product>> getMdPickProducts({
    int limit = 4,
    String? productKind = 'general',
  }) async {
    try {
      // ca_id≠a0 필터 후 limit를 맞추기 위해 여유분 요청
      final fetchLimit = limit <= 0 ? 20 : (limit * 5).clamp(limit, 50);
      var endpoint = '${ApiEndpoints.mdPickProducts}?limit=$fetchLimit';
      if (productKind != null && productKind.isNotEmpty) {
        endpoint += '&it_kind=${Uri.encodeComponent(productKind)}';
      }

      final response = await ApiClient.get(endpoint);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = _parseProductList(data);
        final filtered = list.where(_isHomeMdPickEligible).toList();
        if (limit > 0 && filtered.length > limit) {
          return filtered.take(limit).toList();
        }
        return filtered;
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// it_kind=general(또는 비어 있음) + ca_id가 a0이 아님.
  /// it_type5는 `/md-pick` API에서 이미 선별되므로 응답 필드로 재검증하지 않음.
  static bool _isHomeMdPickEligible(Product product) {
    final kind = (product.productKind ?? '').trim().toLowerCase();
    if (kind.isNotEmpty && kind != 'general') return false;

    final caId = product.categoryId.trim().toLowerCase();
    if (caId.isEmpty || caId == 'a0') return false;

    return true;
  }

  /// 웹 get_categories_with_products — 판매 중 상품이 있는 1단계 카테고리
  static Future<List<ProductCategoryItem>> getCategoriesWithProducts({
    required String productKind,
  }) async {
    try {
      final response = await ApiClient.get(
        ApiEndpoints.categoriesWithProducts(productKind),
      );

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      if (data is! Map || data['success'] != true || data['data'] == null) {
        return [];
      }

      final raw = data['data'];
      if (raw is! List) return [];

      final out = <ProductCategoryItem>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final id = (map['categoryId'] ?? map['ca_id'])?.toString().trim() ?? '';
        final name =
            (map['categoryName'] ?? map['ca_name'])?.toString().trim() ?? '';
        final kind =
            (map['productKind'] ?? map['it_kind'] ?? productKind).toString();
        if (id.isEmpty || name.isEmpty) continue;
        out.add(
          ProductCategoryItem(
            label: name,
            categoryId: id,
            productKind: kind,
          ),
        );
      }
      return out;
    } catch (e) {
      return [];
    }
  }
}

class _ProductListCacheEntry {
  final List<Product> products;
  final DateTime expiresAt;

  const _ProductListCacheEntry({
    required this.products,
    required this.expiresAt,
  });
}
