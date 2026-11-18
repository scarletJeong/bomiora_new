import 'dart:convert';
import '../../../core/logging/failure_log.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../models/product/product_model.dart';
import '../../models/product/product_option_model.dart';
import '../../services/auth_service.dart';

class ProductOptionRepository {
  /// 제품 옵션 목록 조회. 실패와 옵션이 없는 상품을 구분한다.
  static Future<({List<ProductOption> items, bool failed})> getProductOptions(
    String productId, {
    int? ioType,
  }) async {
    try {
      final response = await ApiClient.get(
        ApiEndpoints.productOptions(productId, ioType: ioType),
      );

      if (response.statusCode != 200) {
        await _logFailure(productId, '옵션 HTTP ${response.statusCode}');
        return (items: const <ProductOption>[], failed: true);
      }

      final data = json.decode(response.body);
      if (data is! Map || data['success'] != true) {
        final message = data is Map
            ? data['message']?.toString().trim() ?? ''
            : '';
        await _logFailure(
          productId,
          message.isEmpty ? '옵션 조회에 실패했습니다.' : message,
        );
        return (items: const <ProductOption>[], failed: true);
      }

      final raw = data['data'];
      if (raw == null) {
        return (items: const <ProductOption>[], failed: false);
      }
      if (raw is! List) {
        await _logFailure(productId, '옵션 응답이 올바르지 않습니다.');
        return (items: const <ProductOption>[], failed: true);
      }

      return (
        items: raw
            .whereType<Map>()
            .map((json) => ProductOption.fromJson(Map<String, dynamic>.from(json)))
            .toList(),
        failed: false,
      );
    } catch (e) {
      await _logFailure(productId, e.toString());
      return (items: const <ProductOption>[], failed: true);
    }
  }

  static Future<void> _logFailure(String productId, String reason) {
    return FailureLog.record(
      code: 'product.option',
      mbId: AuthService.currentUser?.id ?? '',
      reason: reason,
      detail: {'productId': productId},
    );
  }

  /// 연결상품 요약 목록
  static Future<List<Product>> getSupplyProducts(String productId) async {
    try {
      final response =
          await ApiClient.get(ApiEndpoints.productSupplyProducts(productId));
      if (response.statusCode != 200) return [];
      final data = json.decode(response.body);
      if (data is! Map || data['success'] != true) return [];
      final raw = data['data'];
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
