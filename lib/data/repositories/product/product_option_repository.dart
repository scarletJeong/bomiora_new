import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../models/product/product_model.dart';
import '../../models/product/product_option_model.dart';

class ProductOptionRepository {
  /// 제품 옵션 목록 조회
  static Future<List<ProductOption>> getProductOptions(
    String productId, {
    int? ioType,
  }) async {
    try {
      final response = await ApiClient.get(
        ApiEndpoints.productOptions(productId, ioType: ioType),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> optionsJson = data['data'];
          return optionsJson
              .map((json) => ProductOption.fromJson(
                    Map<String, dynamic>.from(json as Map),
                  ))
              .toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
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
