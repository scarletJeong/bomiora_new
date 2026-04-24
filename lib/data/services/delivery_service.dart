import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/delivery/delivery_model.dart';
import '../../core/network/api_client.dart';

/// 주문/배송 서비스
class OrderService {
  static dynamic _decodeBody(http.Response response) {
    return json.decode(response.body);
  }

  static Future<http.Response> _getOrderListResponse(String queryString) async {
    var response = await ApiClient.get('/api/orders?$queryString');
    if (response.statusCode == 404) {
      response = await ApiClient.get('/api/user/orders?$queryString');
    }
    return response;
  }

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

      // 쿼리 파라미터를 URL에 직접 추가
      final queryString =
          'mbId=$mbId&mb_id=$mbId&period=$period&status=$status&page=$page&size=$size';
      
      final response = await _getOrderListResponse(queryString);

      if (response.statusCode == 200) {
        final data = _decodeBody(response);
        
        // 주문 목록 파싱
        List<OrderListModel> orders = [];
        if (data is Map && data['orders'] != null) {
          orders = (data['orders'] as List)
              .whereType<Map>()
              .map((order) => OrderListModel.fromJson(Map<String, dynamic>.from(order)))
              .toList();
        }
      
        return {
          'success': true,
          'orders': orders,
          'currentPage': data is Map ? (data['currentPage'] ?? 0) : 0,
          'totalPages': data is Map ? (data['totalPages'] ?? 0) : 0,
          'totalItems': data is Map
              ? (data['totalItems'] ?? data['totalElements'] ?? 0)
              : 0,
          'hasNext': data is Map ? (data['hasNext'] ?? false) : false,
        };
      } else {
        final errorData = _decodeBody(response);
        return {
          'success': false,
          'message': errorData['error'] ?? '주문 목록을 불러올 수 없습니다.',
        };
      }
    } catch (e) {
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
    required String odId,
    required String mbId,
  }) async {
    try {
      var response = await ApiClient.get('/api/orders/$odId?mbId=$mbId&mb_id=$mbId');
      if (response.statusCode == 404) {
        response = await ApiClient.get('/api/user/orders/$odId?mbId=$mbId&mb_id=$mbId');
      }

      if (response.statusCode == 200) {
        final data = _decodeBody(response);
        if (data is! Map) {
          return {
            'success': false,
            'message': '주문 상세 응답 형식이 올바르지 않습니다.',
          };
        }

        final order = OrderDetailModel.fromJson(Map<String, dynamic>.from(data));
        return {
          'success': true,
          'order': order,
        };
      } else {
        final errorData = _decodeBody(response);
        return {
          'success': false,
          'message': errorData['error'] ?? '주문 정보를 불러올 수 없습니다.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다.',
      };
    }
  }

  /// 주문 취소
  /// 
  /// [odId] 주문 ID (String - 큰 숫자 정밀도 손실 방지)
  /// [mbId] 회원 ID
  static Future<Map<String, dynamic>> cancelOrder({
    required String odId,
    required String mbId,
  }) async {
    try {
      final response = await ApiClient.post(
        '/api/orders/$odId/cancel',
        {'mbId': mbId},
      );

      if (response.statusCode == 200) {
        final data = _decodeBody(response);
        return {
          'success': true,
          'message': data['message'] ?? '주문이 취소되었습니다.',
        };
      } else {
        final errorData = _decodeBody(response);
        return {
          'success': false,
          'message': errorData['error'] ?? '주문 취소에 실패했습니다.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다.',
      };
    }
  }

  /// 구매 확정
  /// 
  /// [odId] 주문 ID (String - 큰 숫자 정밀도 손실 방지)
  /// [mbId] 회원 ID
  static Future<Map<String, dynamic>> confirmPurchase({
    required String odId,
    required String mbId,
  }) async {
    try {
      print('📦 [구매 확정] 요청');
      print('  - odId: $odId');
      print('  - mbId: $mbId');

      final response = await ApiClient.post(
        '/api/orders/$odId/confirm',
        {'mbId': mbId},
      );

      print('📡 [구매 확정] 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = _decodeBody(response);
        print('✅ [구매 확정] 성공');
        
        return {
          'success': true,
          'message': data['message'] ?? '구매가 확정되었습니다.',
        };
      } else {
        print('❌ [구매 확정] 실패: ${response.statusCode}');
        final errorData = _decodeBody(response);
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

  /// 예약 시간 변경
  /// 
  /// [odId] 주문 ID (String - 큰 숫자 정밀도 손실 방지)
  /// [mbId] 회원 ID
  /// [reservationDate] 예약 날짜 (yyyy-MM-dd 형식)
  /// [reservationTime] 예약 시간 (HH:mm 형식)
  static Future<Map<String, dynamic>> changeReservationTime({
    required String odId,
    required String mbId,
    required String reservationDate,
    required String reservationTime,
  }) async {
    try {
      print('📦 [예약 시간 변경] 요청');
      print('  - odId: $odId');
      print('  - mbId: $mbId');
      print('  - reservationDate: $reservationDate');
      print('  - reservationTime: $reservationTime');

      final response = await ApiClient.put(
        '/api/orders/$odId/reservation',
        {
          'mbId': mbId,
          'reservationDate': reservationDate,
          'reservationTime': reservationTime,
        },
      );

      print('📡 [예약 시간 변경] 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = _decodeBody(response);
        print('✅ [예약 시간 변경] 성공');
        
        return {
          'success': true,
          'message': data['message'] ?? '예약 시간이 변경되었습니다.',
        };
      } else {
        print('❌ [예약 시간 변경] 실패: ${response.statusCode}');
        final errorData = _decodeBody(response);
        return {
          'success': false,
          'message': errorData['error'] ?? errorData['message'] ?? '예약 시간 변경에 실패했습니다.',
        };
      }
    } catch (e) {
      print('❌ [예약 시간 변경] 에러: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다.',
      };
    }
  }

  /// 배송지 변경
  ///
  /// [odId] 주문 ID
  /// [mbId] 회원 ID
  /// [addressId] 선택한 배송지 ID
  static Future<Map<String, dynamic>> changeDeliveryAddress({
    required String odId,
    required String mbId,
    required int addressId,
  }) async {
    try {
      print('📦 [배송지 변경] 요청');
      print('  - odId: $odId');
      print('  - mbId: $mbId');
      print('  - addressId: $addressId');

      final payload = {
        'mbId': mbId,
        'addressId': addressId,
        'adId': addressId, // 서버 키 호환
      };

      http.Response response = await ApiClient.put('/api/orders/$odId/address', payload);
      if (response.statusCode == 404) {
        response = await ApiClient.put('/api/orders/$odId/delivery-address', payload);
      }
      if (response.statusCode == 404) {
        response = await ApiClient.put('/api/user/orders/$odId/address', payload);
      }
      if (response.statusCode == 404) {
        response = await ApiClient.put('/api/user/orders/$odId/delivery-address', payload);
      }

      print('📡 [배송지 변경] 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = _decodeBody(response);
        return {
          'success': true,
          'message': data['message'] ?? '배송지가 변경되었습니다.',
        };
      }

      final errorData = _decodeBody(response);
      return {
        'success': false,
        'message': errorData['error'] ?? errorData['message'] ?? '배송지 변경에 실패했습니다.',
      };
    } catch (e) {
      print('❌ [배송지 변경] 에러: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다.',
      };
    }
  }
}

