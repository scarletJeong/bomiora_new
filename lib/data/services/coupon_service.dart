import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/coupon/coupon_model.dart';

/// 쿠폰 관련 서비스
class CouponService {
  /// 사용자의 모든 쿠폰 조회
  static Future<List<Coupon>> getUserCoupons(String userId) async {
    try {
      final response = await ApiClient.get(ApiEndpoints.userCoupons(userId));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> couponsJson = data['data'];
          final coupons = couponsJson
              .map((json) => Coupon.fromJson(json))
              .toList();
          
          return coupons;
        }
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 사용 가능한 쿠폰 조회
  static Future<List<Coupon>> getAvailableCoupons(String userId) async {
    try {
      final response = await ApiClient.get(ApiEndpoints.availableCoupons(userId));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> couponsJson = data['data'];
          return couponsJson
              .map((json) => Coupon.fromJson(json))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 사용한 쿠폰 조회
  static Future<List<Coupon>> getUsedCoupons(String userId) async {
    try {
      final response = await ApiClient.get(ApiEndpoints.usedCoupons(userId));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> couponsJson = data['data'];
          return couponsJson
              .map((json) => Coupon.fromJson(json))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 만료된 쿠폰 조회
  static Future<List<Coupon>> getExpiredCoupons(String userId) async {
    try {
      final response = await ApiClient.get(ApiEndpoints.expiredCoupons(userId));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> couponsJson = data['data'];
          return couponsJson
              .map((json) => Coupon.fromJson(json))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 쿠폰 등록
  static Future<Map<String, dynamic>> registerCoupon(String userId, String couponCode) async {
    try {
      final response = await ApiClient.post(
        ApiEndpoints.registerCoupon,
        {
          'mb_id': userId,
          'cp_id': couponCode,
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? false,
          'message': data['message'] ?? (data['success'] == true ? '쿠폰이 등록되었습니다.' : '쿠폰 등록에 실패했습니다.'),
        };
      }
      
      return {
        'success': false,
        'message': '쿠폰 등록에 실패했습니다.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': '쿠폰 등록 중 오류가 발생했습니다: $e',
      };
    }
  }
  
  /// 도움쿠폰 다운로드
  static Future<Map<String, dynamic>> downloadHelpCoupon({
    required String mbId,
    required String itId,
    required int isId,
  }) async {
    try {
      final response = await ApiClient.post(
        ApiEndpoints.downloadHelpCoupon,
        {
          'mbId': mbId,
          'itId': itId,
          'isId': isId,
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          return {
            'success': true,
            'message': data['message'],
            'downloadCount': data['downloadCount'],
            'cpId': data['cpId'],
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? '쿠폰 다운로드에 실패했습니다.',
          };
        }
      }
      
      return {
        'success': false,
        'message': '쿠폰 다운로드에 실패했습니다.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': '쿠폰 다운로드 중 오류가 발생했습니다.',
      };
    }
  }
}

