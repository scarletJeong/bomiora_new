import 'dart:convert';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../data/services/auth_service.dart';
import '../../data/models/product/product_model.dart';
import '../../data/models/product/product_option_model.dart';

class CartService {
  /// 장바구니에 상품 추가
  static Future<Map<String, dynamic>> addToCart({
    required String productId,
    required int quantity,
    required int price,
    String? optionId,
    String? optionText,
    int? optionPrice,
    String? odId, // 처방 예약 플로우의 경우 od_id 전달
    String? ctKind, // 상품 종류 (prescription, general) - 없으면 백엔드에서 판단
  }) async {
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        return {
          'success': false,
          'message': '로그인이 필요합니다.',
        };
      }

      final requestData = {
        'mb_id': user.id,
        'it_id': productId,
        'quantity': quantity,
        'price': price,
      };

      // 옵션이 있으면 추가
      if (optionId != null && optionId.isNotEmpty) {
        requestData['option_id'] = optionId;
        requestData['option_text'] = optionText ?? '';
        requestData['option_price'] = optionPrice ?? 0;
      }

      // od_id가 있으면 추가 (처방 예약 플로우)
      if (odId != null && odId.isNotEmpty) {
        requestData['od_id'] = odId;
      }

      // ct_kind가 있으면 추가 (상품 종류)
      if (ctKind != null && ctKind.isNotEmpty) {
        requestData['ct_kind'] = ctKind;
        print('📦 [장바구니 추가] ct_kind 전달: $ctKind');
      } else {
        print('⚠️ [장바구니 추가] ct_kind가 없습니다!');
      }

      print('📥 [API POST] 요청 데이터: $requestData');

      final response = await ApiClient.post(
        ApiEndpoints.addToCart,
        requestData,
      );

      print('📥 [API POST] 응답 상태: ${response.statusCode}');
      print('📥 [API POST] 응답 본문: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? '장바구니에 추가되었습니다.',
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': '장바구니 추가에 실패했습니다.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '장바구니 추가 중 오류가 발생했습니다: $e',
      };
    }
  }

  /// 여러 옵션을 장바구니에 추가
  static Future<Map<String, dynamic>> addOptionsToCart({
    required Product product,
    required Map<ProductOption, int> selectedOptions,
    String? odId, // 처방 예약 플로우의 경우 od_id 전달
  }) async {
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        return {
          'success': false,
          'message': '로그인이 필요합니다.',
        };
      }

      int successCount = 0;
      int failCount = 0;
      List<String> errorMessages = [];

      // 각 옵션별로 장바구니에 추가
      for (final entry in selectedOptions.entries) {
        final option = entry.key;
        final quantity = entry.value;
        final totalPrice = (product.price + option.price) * quantity;

        // ct_option 형식: "디톡스 / 3일" (단계 / 개월수일)
        String ctOptionText;
        if (option.months != null) {
          // "디톡스 / 3일" 형태로 변환
          ctOptionText = '${option.step} / ${option.months}일';
        } else {
          // 개월수가 없으면 단계만
          ctOptionText = option.step;
        }
        
        final result = await addToCart(
          productId: product.id,
          quantity: quantity,
          price: totalPrice,
          optionId: option.id,
          optionText: ctOptionText, // "디톡스 / 3일" 형태
          optionPrice: option.price,
          odId: odId, // 처방 예약 플로우의 경우 od_id 전달
          ctKind: product.ctKind, // 상품 종류 전달
        );

        if (result['success'] == true) {
          successCount++;
        } else {
          failCount++;
          errorMessages.add('${option.displayText}: ${result['message']}');
        }
      }

      if (failCount == 0) {
        return {
          'success': true,
          'message': '모든 상품이 장바구니에 추가되었습니다.',
        };
      } else if (successCount > 0) {
        return {
          'success': true,
          'message': '일부 상품이 장바구니에 추가되었습니다.',
          'errors': errorMessages,
        };
      } else {
        return {
          'success': false,
          'message': '장바구니 추가에 실패했습니다.',
          'errors': errorMessages,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '장바구니 추가 중 오류가 발생했습니다: $e',
      };
    }
  }

  /// 장바구니 조회 (ct_status가 '쇼핑'인 것만)
  static Future<Map<String, dynamic>> getCart() async {
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        return {
          'success': false,
          'message': '로그인이 필요합니다.',
          'items': [],
        };
      }

      final response = await ApiClient.get('${ApiEndpoints.getCart}?mb_id=${user.id}&ct_status=쇼핑');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'] ?? [],
          'items': data['data'] ?? [], // 하위 호환성
          'shipping_cost': data['shipping_cost'] ?? 0,
          'total_price': data['total_price'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': '장바구니 조회에 실패했습니다.',
          'items': [],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '장바구니 조회 중 오류가 발생했습니다: $e',
        'items': [],
      };
    }
  }

  /// 주문 ID(od_id) 생성
  static Future<Map<String, dynamic>> generateOrderId({
    required String productId,
  }) async {
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        return {
          'success': false,
          'message': '로그인이 필요합니다.',
        };
      }

      final requestData = {
        'mb_id': user.id,
        'it_id': productId,
      };

      final response = await ApiClient.post(
        ApiEndpoints.generateOrderId,
        requestData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final odId = data['od_id'];
        return {
          'success': data['success'] ?? true,
          'od_id': odId,
          'message': data['message'] ?? '주문 ID가 생성되었습니다.',
        };
      } else {
        return {
          'success': false,
          'message': '주문 ID 생성에 실패했습니다.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '주문 ID 생성 중 오류가 발생했습니다: $e',
      };
    }
  }

  /// 장바구니 항목 수량 업데이트
  static Future<Map<String, dynamic>> updateCartQuantity({
    required int ctId,
    required int quantity,
  }) async {
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        return {
          'success': false,
          'message': '로그인이 필요합니다.',
        };
      }

      final requestData = {
        'quantity': quantity,
      };

      final response = await ApiClient.put(
        '${ApiEndpoints.updateCartItem}/$ctId',
        requestData,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? '수량이 변경되었습니다.',
          'data': data['data'],
        };
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? '수량 변경에 실패했습니다.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '수량 변경 중 오류가 발생했습니다: $e',
      };
    }
  }

  /// 장바구니 항목 삭제
  static Future<Map<String, dynamic>> removeCartItem(int ctId) async {
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        return {
          'success': false,
          'message': '로그인이 필요합니다.',
        };
      }

      final response = await ApiClient.delete('${ApiEndpoints.removeCartItem}/$ctId');

      if (response.statusCode == 200 || response.statusCode == 204) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? '장바구니에서 삭제되었습니다.',
        };
      } else {
        return {
          'success': false,
          'message': '장바구니 삭제에 실패했습니다.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '장바구니 삭제 중 오류가 발생했습니다: $e',
      };
    }
  }
}

