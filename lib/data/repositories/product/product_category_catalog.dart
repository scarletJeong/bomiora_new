import '../../../core/logging/failure_log.dart';
import '../../services/auth_service.dart';
import 'product_repository.dart';
import '../../../presentation/shopping/utils/get_product.dart';

/// 판매 중 상품이 있는 분류. 서버 조회가 성공한 목록만 메모리에 둔다.
class ProductCategoryCatalog {
  ProductCategoryCatalog._();

  static List<ProductCategoryItem>? _generalCache;
  static List<ProductCategoryItem>? _prescriptionCache;
  static Future<({List<ProductCategoryItem> items, bool failed})>?
      _generalInFlight;
  static Future<({List<ProductCategoryItem> items, bool failed})>?
      _prescriptionInFlight;

  static Future<List<ProductCategoryItem>> generalCategories({
    bool forceRefresh = false,
  }) async {
    final result = await loadGeneral(forceRefresh: forceRefresh);
    return result.items;
  }

  static Future<({List<ProductCategoryItem> items, bool failed})> loadGeneral({
    bool forceRefresh = false,
  }) {
    return _load(
      productKind: 'general',
      forceRefresh: forceRefresh,
      readCache: () => _generalCache,
      writeCache: (value) => _generalCache = value,
      readInFlight: () => _generalInFlight,
      writeInFlight: (value) => _generalInFlight = value,
    );
  }

  static Future<List<ProductCategoryItem>> prescriptionCategories({
    bool forceRefresh = false,
  }) async {
    final result = await loadPrescription(forceRefresh: forceRefresh);
    return result.items;
  }

  static Future<({List<ProductCategoryItem> items, bool failed})>
      loadPrescription({
    bool forceRefresh = false,
  }) {
    return _load(
      productKind: 'prescription',
      forceRefresh: forceRefresh,
      readCache: () => _prescriptionCache,
      writeCache: (value) => _prescriptionCache = value,
      readInFlight: () => _prescriptionInFlight,
      writeInFlight: (value) => _prescriptionInFlight = value,
    );
  }

  static Future<({List<ProductCategoryItem> items, bool failed})> _load({
    required String productKind,
    required bool forceRefresh,
    required List<ProductCategoryItem>? Function() readCache,
    required void Function(List<ProductCategoryItem>?) writeCache,
    required Future<({List<ProductCategoryItem> items, bool failed})>?
        Function() readInFlight,
    required void Function(
      Future<({List<ProductCategoryItem> items, bool failed})>?,
    ) writeInFlight,
  }) async {
    final pending = readInFlight();
    if (pending != null) return pending;
    final cached = readCache();
    if (!forceRefresh && cached != null) {
      return (items: cached, failed: false);
    }

    final request = () async {
      try {
        final fromApi = await ProductRepository.getCategoriesWithProducts(
          productKind: productKind,
        );
        writeCache(fromApi);
        return (items: fromApi, failed: false);
      } catch (e) {
        writeCache(null);
        final user = await AuthService.getUser();
        await FailureLog.record(
          code: 'product.category',
          mbId: user?.id ?? '',
          reason: e.toString(),
          detail: {'productKind': productKind},
        );
        return (
          items: const <ProductCategoryItem>[],
          failed: true,
        );
      }
    }();
    writeInFlight(request);
    try {
      return await request;
    } finally {
      if (identical(readInFlight(), request)) writeInFlight(null);
    }
  }

  static void clearCache() {
    _generalCache = null;
    _prescriptionCache = null;
    _generalInFlight = null;
    _prescriptionInFlight = null;
  }
}
