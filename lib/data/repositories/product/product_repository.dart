import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../models/product/product_model.dart';
import '../../services/auth_service.dart';

class ProductRepository {
  // 카테고리별 상품 목록 가져오기
  static Future<List<Product>> getProductsByCategory({
    required String categoryId,
    String? productKind,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {      
      // 먼저 Spring Boot API를 시도
      String endpoint = ApiEndpoints.productListByCategory(categoryId, productKind: productKind);
      endpoint += '&page=$page&pageSize=$pageSize';
      
      
      // 인증 토큰이 있으면 헤더에 추가
      final token = await AuthService.getToken();
      Map<String, String>? headers;
      if (token != null && token.isNotEmpty) {
        headers = {'Authorization': 'Bearer $token'};
        print('🔑 인증 토큰 사용: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
      } else {
        print('⚠️ 인증 토큰 없음 - 인증이 필요할 수 있음');
      }
      
      final response = await ApiClient.get(endpoint, additionalHeaders: headers);
      
      print('📡 응답 상태 코드: ${response.statusCode}');
      
      // Spring Boot API가 성공하면 처리
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          
          // 응답 구조에 따라 처리
          if (data['success'] == true && data['data'] != null) {
            final List<dynamic> products = data['data'];
            return products.map((json) => Product.fromJson(json)).toList();
          } else if (data is List) {
            return data.map((json) => Product.fromJson(json)).toList();
          } else if (data['products'] != null) {
            final List<dynamic> products = data['products'];
            return products.map((json) => Product.fromJson(json)).toList();
          }
        } catch (e) {
          print('⚠️ Spring Boot API 응답 파싱 실패: $e');
        }
      }
      
      return await _getProductsFromPhpServer(
        categoryId: categoryId,
        productKind: productKind,
      );
    } catch (e) {
      print('❌ 상품 목록 조회 오류: $e');
      // 폴백: PHP 서버로 시도
      try {
        return await _getProductsFromPhpServer(
          categoryId: categoryId,
          productKind: productKind,
        );
      } catch (fallbackError) {
        print('❌ PHP 서버 폴백도 실패: $fallbackError');
        return [];
      }
    }
  }

  // bomiora.kr PHP 서버에서 상품 목록 가져오기 (폴백)
  static Future<List<Product>> _getProductsFromPhpServer({
    required String categoryId,
    String? productKind,
  }) async {
    try {
      print('🌐 PHP 서버에서 상품 조회 시도: bomiora.kr');
      
      // bomiora.kr의 API 엔드포인트를 확인해야 함
      // 만약 JSON API가 없다면, Spring Boot 서버가 중간에서 PHP 서버를 호출하는 구조일 수 있음
      // 일단 빈 리스트 반환 (나중에 실제 API 구조를 파악하면 수정)
      
      // TODO: 실제 bomiora.kr API 엔드포인트 확인 후 구현
      // 예: 'https://bomiora.kr/api/products/list.php?ca_id=$categoryId&it_kind=$productKind'
      
      print('⚠️ PHP 서버 API 엔드포인트 미구현. Spring Boot 서버 API 구현 필요.');
      return [];
    } catch (e) {
      print('❌ PHP 서버 조회 오류: $e');
      return [];
    }
  }

  // 상품 상세 정보 가져오기
  static Future<Product?> getProductDetail(String productId) async {
    try {
      print('🔍 상품 상세 조회 시작 - productId: $productId');
      
      final response = await ApiClient.get('${ApiEndpoints.productDetail}?id=$productId');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          return Product.fromJson(data['data']);
        } else if (data['product'] != null) {
          return Product.fromJson(data['product']);
        }
      }
      
      return null;
    } catch (e) {
      print('❌ 상품 상세 조회 오류: $e');
      return null;
    }
  }

  // 인기 상품 목록 가져오기
  static Future<List<Product>> getPopularProducts({int limit = 10}) async {
    try {
      final response = await ApiClient.get('${ApiEndpoints.popularProducts}?limit=$limit');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> products = data['data'];
          return products.map((json) => Product.fromJson(json)).toList();
        } else if (data is List) {
          return data.map((json) => Product.fromJson(json)).toList();
        }
      }
      
      return [];
    } catch (e) {
      print('❌ 인기 상품 조회 오류: $e');
      return [];
    }
  }

  // 신상품 목록 가져오기
  static Future<List<Product>> getNewProducts({int limit = 10}) async {
    try {
      final response = await ApiClient.get('${ApiEndpoints.newProducts}?limit=$limit');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> products = data['data'];
          return products.map((json) => Product.fromJson(json)).toList();
        } else if (data is List) {
          return data.map((json) => Product.fromJson(json)).toList();
        }
      }
      
      return [];
    } catch (e) {
      print('❌ 신상품 조회 오류: $e');
      return [];
    }
  }
}
