import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../presentation/shopping/utils/get_product.dart';
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
          if (data is Map && data['success'] == true && data['data'] != null) {
            final List<dynamic> products = data['data'];
            return products
                .whereType<Map>()
                .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else if (data is List) {
            return data
                .whereType<Map>()
                .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else if (data is Map && data['products'] != null) {
            final List<dynamic> products = data['products'];
            return products
                .whereType<Map>()
                .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
                .toList();
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
        
        Product? productObj;
        if (data is Map && data['success'] == true && data['data'] != null) {
          final product = data['data'];
          if (product is Map) {
            // bomiora_shop_item_new 테이블에서 가져온 원본 데이터 로그 출력
            final itId = product['it_id'] ?? product['id'];
            final itKind = product['it_kind'];
            final ctKind = product['ct_kind'];
            final productKind = product['productKind'];
            
            // Buffer 객체 처리
            String? itIdStr;
            String? itKindStr;
            if (itId is Map && itId['type'] == 'Buffer' && itId['data'] != null) {
              itIdStr = String.fromCharCodes((itId['data'] as List).map((e) => e as int));
            } else {
              itIdStr = itId?.toString();
            }
            if (itKind is Map && itKind['type'] == 'Buffer' && itKind['data'] != null) {
              itKindStr = String.fromCharCodes((itKind['data'] as List).map((e) => e as int));
            } else {
              itKindStr = itKind?.toString();
            }
            
            print('📦 [상품 상세 조회] 원본 데이터 (bomiora_shop_item_new):');
            print('  - it_id (원본): $itId');
            print('  - it_id (문자열): $itIdStr');
            print('  - it_kind (원본): $itKind');
            print('  - it_kind (문자열): $itKindStr');
            print('  - ct_kind: $ctKind');
            print('  - productKind: $productKind');
            
            productObj = Product.fromJson(Map<String, dynamic>.from(product));
            if (productObj != null) {
              print('  - 파싱된 productKind: ${productObj.productKind}');
              print('  - 파싱된 ctKind (getter): ${productObj.ctKind}');
            }
          }
        } else if (data is Map && data['product'] != null) {
          final product = data['product'];
          if (product is Map) {
            // bomiora_shop_item_new 테이블에서 가져온 원본 데이터 로그 출력
            final itId = product['it_id'] ?? product['id'];
            final itKind = product['it_kind'];
            final ctKind = product['ct_kind'];
            final productKind = product['productKind'];
            
            // Buffer 객체 처리
            String? itIdStr;
            String? itKindStr;
            if (itId is Map && itId['type'] == 'Buffer' && itId['data'] != null) {
              itIdStr = String.fromCharCodes((itId['data'] as List).map((e) => e as int));
            } else {
              itIdStr = itId?.toString();
            }
            if (itKind is Map && itKind['type'] == 'Buffer' && itKind['data'] != null) {
              itKindStr = String.fromCharCodes((itKind['data'] as List).map((e) => e as int));
            } else {
              itKindStr = itKind?.toString();
            }
            
            print('📦 [상품 상세 조회] 원본 데이터 (bomiora_shop_item_new):');
            print('  - it_id (원본): $itId');
            print('  - it_id (문자열): $itIdStr');
            print('  - it_kind (원본): $itKind');
            print('  - it_kind (문자열): $itKindStr');
            print('  - ct_kind: $ctKind');
            print('  - productKind: $productKind');
            
            productObj = Product.fromJson(Map<String, dynamic>.from(product));
            if (productObj != null) {
              print('  - 파싱된 productKind: ${productObj.productKind}');
              print('  - 파싱된 ctKind (getter): ${productObj.ctKind}');
            }
          }
        }
        return productObj;
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
        
        if (data is Map && data['success'] == true && data['data'] != null) {
          final List<dynamic> products = data['data'];
          return products
              .whereType<Map>()
              .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
              .toList();
        } else if (data is List) {
          return data
              .whereType<Map>()
              .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
              .toList();
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
        
        if (data is Map && data['success'] == true && data['data'] != null) {
          final List<dynamic> products = data['data'];
          return products
              .whereType<Map>()
              .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
              .toList();
        } else if (data is List) {
          return data
              .whereType<Map>()
              .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      print('❌ 신상품 조회 오류: $e');
      return [];
    }
  }

  /// MD pick (it_type5 = 1) — 웹 get_new_product()와 동일
  static Future<List<Product>> getMdPickProducts({
    int limit = 4,
    String? productKind,
  }) async {
    try {
      var endpoint = '${ApiEndpoints.mdPickProducts}?limit=$limit';
      if (productKind != null && productKind.isNotEmpty) {
        endpoint += '&it_kind=${Uri.encodeComponent(productKind)}';
      }

      final response = await ApiClient.get(endpoint);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is Map && data['success'] == true && data['data'] != null) {
          final List<dynamic> products = data['data'];
          return products
              .whereType<Map>()
              .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
              .toList();
        } else if (data is List) {
          return data
              .whereType<Map>()
              .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
              .toList();
        }
      }

      return [];
    } catch (e) {
      print('❌ MD pick 조회 오류: $e');
      return [];
    }
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
      print('❌ 카테고리(상품있음) 조회 오류: $e');
      return [];
    }
  }
}
