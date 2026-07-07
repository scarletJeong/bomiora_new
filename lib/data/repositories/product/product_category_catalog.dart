import 'product_repository.dart';
import '../../../presentation/shopping/utils/get_product.dart';

/// 웹 `get_categories_with_products()` — 판매 중 상품이 있는 카테고리 (메모리 캐시)
class ProductCategoryCatalog {
  ProductCategoryCatalog._();

  static List<ProductCategoryItem>? _generalCache;
  static List<ProductCategoryItem>? _prescriptionCache;

  static Future<List<ProductCategoryItem>> generalCategories({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _generalCache != null) {
      return _generalCache!;
    }

    final fromApi = await ProductRepository.getCategoriesWithProducts(
      productKind: 'general',
    );

    _generalCache = fromApi;
    return fromApi;
  }

  static Future<List<ProductCategoryItem>> prescriptionCategories({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _prescriptionCache != null &&
        _prescriptionCache!.isNotEmpty) {
      return _prescriptionCache!;
    }

    final fromApi = await ProductRepository.getCategoriesWithProducts(
      productKind: 'prescription',
    );

    _prescriptionCache = fromApi.isNotEmpty
        ? fromApi
        : List<ProductCategoryItem>.from(
            productPrescriptionCategoryListFallback,
          );

    return _prescriptionCache!;
  }

  static void clearCache() {
    _generalCache = null;
    _prescriptionCache = null;
  }
}
