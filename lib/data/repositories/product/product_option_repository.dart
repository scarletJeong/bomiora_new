import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../models/product/product_option_model.dart';

class ProductOptionRepository {
  /// 제품 옵션 목록 조회
  static Future<List<ProductOption>> getProductOptions(String productId) async {
    try {
      final response = await ApiClient.get(ApiEndpoints.productOptions(productId));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> optionsJson = data['data'];
          return optionsJson
              .map((json) => ProductOption.fromJson(json))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }
}

