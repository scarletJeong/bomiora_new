import 'dart:convert';
import '../models/order/order_model.dart';
import '../../core/network/api_client.dart';

/// 주문/배송 서비스
class OrderService {
  /// 주문 목록 조회
  /// 
  /// [mbId] 회원 ID
  /// [period] 기간 (개월 수: 1, 3, 6, 0=전체)
  /// [status] 상태 (all, cancel, preparing, delivering, finish)
  /// [page] 페이지 번호 (0부터 시작)
  /// [size] 페이지 크기
  static Future<Map<String, dynamic>> getOrderList({
    required String mbId,
    int period = 0,
    String status = 'all',
    int page = 0,
    int size = 10,
  }) async {
    try {
      print('📦 [주문 목록 조회] 요청');
      print('  - mbId: $mbId');
      print('  - period: $period');
      print('  - status: $status');
      print('  - page: $page, size: $size');

      final queryParams = {
        'mbId': mbId,
        'period': period.toString(),
        'status': status,
        'page': page.toString(),
        'size': size.toString(),
      };

      final response = await ApiClient.get(
        '/orders',
        queryParameters: queryParams,
      );

      print('📡 [주문 목록 조회] 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // 주문 목록 파싱
        List<OrderListModel> orders = [];
        if (data['orders'] != null) {
          orders = (data['orders'] as List)
              .map((order) => OrderListModel.fromJson(order))
              .toList();
        }
        
        print('✅ [주문 목록 조회] 성공: ${orders.length}개');
        
        return {
          'success': true,
          'orders': orders,
          'currentPage': data['currentPage'] ?? 0,
          'totalPages': data['totalPages'] ?? 0,
          'totalItems': data['totalItems'] ?? 0,
          'hasNext': data['hasNext'] ?? false,
        };
      } else {
        print('❌ [주문 목록 조회] 실패: ${response.statusCode}');
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['error'] ?? '주문 목록을 불러올 수 없습니다.',
        };
      }
    } catch (e) {
      print('❌ [주문 목록 조회] 에러: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다.',
      };
    }
  }

  /// 주문 상세 조회
  /// 
  /// [odId] 주문 ID
  /// [mbId] 회원 ID
  static Future<Map<String, dynamic>> getOrderDetail({
    required int odId,
    required String mbId,
  }) async {
    try {
      print('📦 [주문 상세 조회] 요청');
      print('  - odId: $odId');
      print('  - mbId: $mbId');

      final response = await ApiClient.get(
        '/orders/$odId',
        queryParameters: {'mbId': mbId},
      );

      print('📡 [주문 상세 조회] 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final order = OrderDetailModel.fromJson(data);
        
        print('✅ [주문 상세 조회] 성공');
        
        return {
          'success': true,
          'order': order,
        };
      } else {
        print('❌ [주문 상세 조회] 실패: ${response.statusCode}');
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['error'] ?? '주문 정보를 불러올 수 없습니다.',
        };
      }
    } catch (e) {
      print('❌ [주문 상세 조회] 에러: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다.',
      };
    }
  }

  /// 주문 취소
  /// 
  /// [odId] 주문 ID
  /// [mbId] 회원 ID
  static Future<Map<String, dynamic>> cancelOrder({
    required int odId,
    required String mbId,
  }) async {
    try {
      print('📦 [주문 취소] 요청');
      print('  - odId: $odId');
      print('  - mbId: $mbId');

      final response = await ApiClient.post(
        '/orders/$odId/cancel',
        body: {'mbId': mbId},
      );

      print('📡 [주문 취소] 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ [주문 취소] 성공');
        
        return {
          'success': true,
          'message': data['message'] ?? '주문이 취소되었습니다.',
        };
      } else {
        print('❌ [주문 취소] 실패: ${response.statusCode}');
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['error'] ?? '주문 취소에 실패했습니다.',
        };
      }
    } catch (e) {
      print('❌ [주문 취소] 에러: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다.',
      };
    }
  }

  /// 구매 확정
  /// 
  /// [odId] 주문 ID
  /// [mbId] 회원 ID
  static Future<Map<String, dynamic>> confirmPurchase({
    required int odId,
    required String mbId,
  }) async {
    try {
      print('📦 [구매 확정] 요청');
      print('  - odId: $odId');
      print('  - mbId: $mbId');

      final response = await ApiClient.post(
        '/orders/$odId/confirm',
        body: {'mbId': mbId},
      );

      print('📡 [구매 확정] 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ [구매 확정] 성공');
        
        return {
          'success': true,
          'message': data['message'] ?? '구매가 확정되었습니다.',
        };
      } else {
        print('❌ [구매 확정] 실패: ${response.statusCode}');
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['error'] ?? '구매 확정에 실패했습니다.',
        };
      }
    } catch (e) {
      print('❌ [구매 확정] 에러: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다.',
      };
    }
  }
}

