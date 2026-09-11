import 'dart:convert';
import '../../core/utils/inf_code_tracker.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/node_value_parser.dart';
import '../services/auth_service.dart';

class WishService {
  static const Duration _checkCacheTtl = Duration(seconds: 30);
  static const Duration _listCacheTtl = Duration(seconds: 45);
  static final Map<String, bool> _checkCache = {};
  static final Map<String, DateTime> _checkCacheAt = {};
  static final Map<String, Future<bool>> _checkInFlight = {};
  static final Map<String, Future<Map<String, dynamic>>> _toggleInFlight = {};
  static List<Map<String, dynamic>>? _listCache;
  static DateTime? _listCacheAt;
  static String? _listCacheUserId;
  static Future<List<dynamic>>? _listInFlight;

  static const Map<String, String> _noCacheHeaders = {
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache',
  };

  static Map<String, dynamic>? _normalizeWishItem(dynamic raw) {
    if (raw is! Map) return null;
    final item = NodeValueParser.normalizeMap(Map<String, dynamic>.from(raw));
    // API는 `product_kind`(snake, Buffer)만 주는 경우가 많음 → 탭/상세와 맞추기 위해 it_kind·productKind 보강
    final productKindRaw = NodeValueParser.asString(item['product_kind']) ??
        NodeValueParser.asString(item['productKind']) ??
        '';
    final itKindRaw = NodeValueParser.asString(item['it_kind']) ??
        NodeValueParser.asString(item['itKind']) ??
        '';
    final wiKindRaw =
        NodeValueParser.asString(item['wi_it_kind']) ?? NodeValueParser.asString(item['wiItKind']) ?? '';
    final wishKind = wiKindRaw.trim().toLowerCase();
    final productKind = itKindRaw.isNotEmpty ? itKindRaw : productKindRaw;
    final kind = wishKind == 'content'
        ? 'content'
        : (productKind.isNotEmpty ? productKind : wiKindRaw);

    return {
      ...item,
      'it_id':
          NodeValueParser.asString(item['it_id']) ??
          NodeValueParser.asString(item['itId']) ??
          '',
      'mb_id':
          NodeValueParser.asString(item['mb_id']) ??
          NodeValueParser.asString(item['mbId']) ??
          '',
      if (kind.isNotEmpty) 'it_kind': kind,
      if (productKindRaw.isNotEmpty) 'productKind': productKindRaw,
      if (wiKindRaw.isNotEmpty) 'wi_it_kind': wiKindRaw,
    };
  }

  static List<Map<String, dynamic>>? peekWishList(String userId) {
    if (_listCache == null || _listCacheUserId != userId.trim()) return null;
    return _listCache;
  }

  static void rememberWishList(String userId, List<Map<String, dynamic>> list) {
    _listCacheUserId = userId.trim();
    _listCache = list.map((e) => Map<String, dynamic>.from(e)).toList();
    _listCacheAt = DateTime.now();
  }

  static void removeFromLocalList(String productId) {
    final id = productId.trim();
    if (id.isEmpty || _listCache == null) return;
    _listCache!.removeWhere((e) => (e['it_id']?.toString() ?? '') == id);
  }

  static void restoreLocalListItem(int index, Map<String, dynamic> item) {
    if (_listCache == null) return;
    final i = index < 0 ? 0 : (index > _listCache!.length ? _listCache!.length : index);
    _listCache!.insert(i, Map<String, dynamic>.from(item));
  }

  /// 찜 목록 조회
  static Future<List<dynamic>> getWishList({bool forceRefresh = false}) async {
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final fresh = _listCache != null &&
          _listCacheUserId == user.id &&
          _listCacheAt != null &&
          DateTime.now().difference(_listCacheAt!) < _listCacheTtl;
      if (!forceRefresh && fresh) {
        return _listCache!.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      final pending = _listInFlight;
      if (pending != null) return pending;

      final request = _fetchWishList(user.id);
      _listInFlight = request;
      try {
        return await request;
      } finally {
        _listInFlight = null;
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<dynamic>> _fetchWishList(String userId) async {
    final url = '${ApiEndpoints.getWishList}?mb_id=$userId';
    final response = await ApiClient.get(url);

    if (response.statusCode == 404) {
      throw Exception('API 엔드포인트를 찾을 수 없습니다: $url');
    }

    if (response.statusCode == 304 || response.body.trim().isEmpty) {
      return peekWishList(userId) ?? [];
    }

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map && data['data'] != null && data['data'] is List) {
        final normalized = (data['data'] as List)
            .map(_normalizeWishItem)
            .whereType<Map<String, dynamic>>()
            .toList();
        rememberWishList(userId, normalized);
        return normalized;
      }
    }

    return [];
  }

  static String _cacheKey(String userId, String productId) =>
      '${userId.trim()}|${productId.trim()}';

  static bool? peekIsWished(String userId, String productId) {
    return _checkCache[_cacheKey(userId, productId)];
  }

  static void rememberWished(String userId, String productId, bool wished) {
    final key = _cacheKey(userId, productId);
    _checkCache[key] = wished;
    _checkCacheAt[key] = DateTime.now();
  }

  /// 찜 여부 (콘텐츠는 [productId]에 글 id 문자열, 상품은 it_id)
  static Future<bool> isWished(String productId) async {
    final user = await AuthService.getUser();
    if (user == null) return false;
    final key = _cacheKey(user.id, productId);
    final cachedAt = _checkCacheAt[key];
    if (cachedAt != null &&
        DateTime.now().difference(cachedAt) < _checkCacheTtl) {
      return _checkCache[key] ?? false;
    }
    final pending = _checkInFlight[key];
    if (pending != null) return pending;

    final request = _fetchIsWished(user.id, productId);
    _checkInFlight[key] = request;
    try {
      final result = await request;
      _checkCache[key] = result;
      _checkCacheAt[key] = DateTime.now();
      return result;
    } finally {
      _checkInFlight.remove(key);
    }
  }

  static Future<bool> _fetchIsWished(String userId, String productId) async {
    try {
      final q = Uri.encodeQueryComponent(userId);
      final p = Uri.encodeQueryComponent(productId);
      final response = await ApiClient.get(
        '${ApiEndpoints.checkWish}?mb_id=$q&it_id=$p',
        additionalHeaders: _noCacheHeaders,
      );
      if (response.statusCode != 200) return false;
      final data = json.decode(response.body);
      if (data is! Map<String, dynamic>) return false;
      return data['is_wished'] == true;
    } catch (_) {
      return false;
    }
  }

  /// 찜 토글. 같은 상품에 대한 중복 요청은 하나로 합친다.
  static Future<Map<String, dynamic>> addToWish(
    String productId, {
    String? wiItKind,
    String? infCode,
    String? mbId,
  }) async {
    final userId = (mbId ?? '').trim().isNotEmpty
        ? mbId!.trim()
        : (await AuthService.getUser())?.id;
    if (userId == null || userId.isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }

    final key = _cacheKey(userId, productId);
    final pending = _toggleInFlight[key];
    if (pending != null) return pending;

    final request = _postToggle(
      userId: userId,
      productId: productId,
      wiItKind: wiItKind,
      infCode: infCode,
    );
    _toggleInFlight[key] = request;
    try {
      return await request;
    } finally {
      _toggleInFlight.remove(key);
    }
  }

  static Future<Map<String, dynamic>> _postToggle({
    required String userId,
    required String productId,
    String? wiItKind,
    String? infCode,
  }) async {
    try {
      final body = <String, dynamic>{
        'mb_id': userId,
        'it_id': productId,
      };
      final k = wiItKind?.trim();
      if (k != null && k.isNotEmpty) {
        body['wi_it_kind'] = k;
      }

      final resolvedInfCode = (infCode ?? InfCodeTracker.current)?.trim();
      if (resolvedInfCode != null && resolvedInfCode.isNotEmpty) {
        body['inf_code'] = resolvedInfCode;
      }

      final response = await ApiClient.post(
        ApiEndpoints.addToWish,
        body,
      );

      final result = json.decode(response.body);
      if (result is Map<String, dynamic> && result.containsKey('is_wished')) {
        rememberWished(userId, productId, result['is_wished'] == true);
      }
      return result is Map<String, dynamic>
          ? result
          : <String, dynamic>{'success': false};
    } catch (e) {
      throw Exception('찜 추가 실패: $e');
    }
  }

  /// 찜 삭제
  static Future<Map<String, dynamic>> removeFromWish(String productId) async {
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final response = await ApiClient.delete(
        ApiEndpoints.removeFromWish,
        data: {
          'mb_id': user.id,
          'it_id': productId,
        },
      );

      final result = json.decode(response.body);
      _checkCache['${user.id}|${productId.trim()}'] = false;
      _checkCacheAt['${user.id}|${productId.trim()}'] = DateTime.now();
      removeFromLocalList(productId);
      return result;
    } catch (e) {
      throw Exception('찜 삭제 실패: $e');
    }
  }
}

