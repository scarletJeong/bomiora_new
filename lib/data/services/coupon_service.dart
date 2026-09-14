import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/coupon/coupon_model.dart';

/// 쿠폰 관련 서비스
class CouponService {
  static const Duration _availableCacheTtl = Duration(minutes: 3);
  static final Map<String, List<Coupon>> _availableCache = {};
  static final Map<String, DateTime> _availableCacheAt = {};
  static final Map<String, Future<List<Coupon>>> _availableInFlight = {};
  static final Map<String, Map<String, List<Coupon>>> _tabsCache = {};
  static final Map<String, DateTime> _tabsCacheAt = {};
  static final Map<String, Future<Map<String, List<Coupon>>>> _tabsInFlight = {};

  static Future<Map<String, List<Coupon>>> getCouponTabs(
    String userId, {
    bool forceRefresh = false,
  }) async {
    final id = userId.trim();
    final cachedAt = _tabsCacheAt[id];
    if (!forceRefresh &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _availableCacheTtl &&
        _tabsCache.containsKey(id)) {
      return {
        'available': List<Coupon>.from(_tabsCache[id]!['available'] ?? const []),
        'used': List<Coupon>.from(_tabsCache[id]!['used'] ?? const []),
        'expired': List<Coupon>.from(_tabsCache[id]!['expired'] ?? const []),
      };
    }
    final pending = _tabsInFlight[id];
    if (!forceRefresh && pending != null) return pending;

    final request = _fetchCouponTabs(id);
    _tabsInFlight[id] = request;
    try {
      final result = await request;
      _tabsCache[id] = result;
      _tabsCacheAt[id] = DateTime.now();
      _availableCache[id] = List<Coupon>.from(result['available'] ?? const []);
      _availableCacheAt[id] = DateTime.now();
      return {
        'available': List<Coupon>.from(result['available'] ?? const []),
        'used': List<Coupon>.from(result['used'] ?? const []),
        'expired': List<Coupon>.from(result['expired'] ?? const []),
      };
    } finally {
      _tabsInFlight.remove(id);
    }
  }

  static Future<Map<String, List<Coupon>>> _fetchCouponTabs(String userId) async {
    try {
      final response = await ApiClient.get(ApiEndpoints.couponTabs(userId));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['success'] == true) {
          List<Coupon> parse(dynamic raw) {
            if (raw is! List) return [];
            return raw
                .whereType<Map>()
                .map((e) => Coupon.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          }
          return {
            'available': parse(data['available']),
            'used': parse(data['used']),
            'expired': parse(data['expired']),
          };
        }
      }
    } catch (_) {}
    return {
      'available': <Coupon>[],
      'used': <Coupon>[],
      'expired': <Coupon>[],
    };
  }

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

  /// 사용 가능한 쿠폰 개수 (쿠폰 화면 '사용가능한 쿠폰'과 동일 기준)
  static Future<int> getAvailableCouponCount(String userId) async {
    final tabs = await getCouponTabs(userId, forceRefresh: true);
    return (tabs['available'] ?? const <Coupon>[]).length;
  }

  /// 사용 가능한 쿠폰 조회
  static Future<List<Coupon>> getAvailableCoupons(String userId) async {
    final id = userId.trim();
    final cachedAt = _availableCacheAt[id];
    if (cachedAt != null &&
        DateTime.now().difference(cachedAt) < _availableCacheTtl) {
      return List<Coupon>.from(_availableCache[id] ?? const []);
    }
    final pending = _availableInFlight[id];
    if (pending != null) return pending;

    final request = _fetchAvailableCoupons(id);
    _availableInFlight[id] = request;
    try {
      final result = await request;
      _availableCache[id] = result;
      _availableCacheAt[id] = DateTime.now();
      return List<Coupon>.from(result);
    } finally {
      _availableInFlight.remove(id);
    }
  }

  static Future<List<Coupon>> _fetchAvailableCoupons(String userId) async {
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
          _availableCache.remove(mbId);
          _availableCacheAt.remove(mbId);
          _tabsCache.remove(mbId);
          _tabsCacheAt.remove(mbId);
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

