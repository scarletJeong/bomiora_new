import 'dart:convert';
import '../../core/network/api_client.dart';
import '../../core/utils/node_value_parser.dart';
import '../models/address/shipping_address.dart';

/// 배송지 목록 조회 결과. 실패와 빈 목록을 구분한다.
class AddressListLoad {
  final bool ok;
  final List<Map<String, dynamic>> items;

  const AddressListLoad._(this.ok, this.items);

  const AddressListLoad.ok(List<Map<String, dynamic>> items) : this._(true, items);

  static const failed = AddressListLoad._(false, <Map<String, dynamic>>[]);
}

/// 배송지 관리 서비스
class AddressService {
  static const String saveFailureFallback = '배송지를 저장하지 못했습니다.';
  static const Duration _listCacheTtl = Duration(minutes: 3);
  static final Map<String, List<Map<String, dynamic>>> _listCache = {};
  static final Map<String, DateTime> _listCacheAt = {};
  static final Map<String, Future<AddressListLoad>> _listInFlight = {};

  static void invalidate(String mbId) {
    final id = mbId.trim();
    _listCache.remove(id);
    _listCacheAt.remove(id);
  }

  static void removeFromCache(String mbId, int adId) {
    final id = mbId.trim();
    final list = _listCache[id];
    if (list == null) return;
    _listCache[id] = list.where((a) => a['adId'] != adId).toList();
    _listCacheAt[id] = DateTime.now();
  }

  static void _rememberSaved(String mbId, dynamic raw, {int? replaceId}) {
    final mapped = _normalizeAddressItem(raw);
    final id = mbId.trim();
    if (mapped == null) {
      invalidate(id);
      return;
    }
    final list = List<Map<String, dynamic>>.from(_listCache[id] ?? const []);
    if ((mapped['adDefault'] ?? 0) == 1) {
      for (final a in list) {
        a['adDefault'] = 0;
      }
    }
    if (replaceId != null) {
      final i = list.indexWhere((a) => a['adId'] == replaceId);
      if (i >= 0) {
        list[i] = mapped;
      } else {
        list.insert(0, mapped);
      }
    } else {
      list.insert(0, mapped);
    }
    _listCache[id] = list;
    _listCacheAt[id] = DateTime.now();
  }

  static Map<String, dynamic>? _normalizeAddressItem(dynamic raw) {
    return ShippingAddress.tryParse(raw)?.toMap();
  }

  static Map<String, dynamic>? _normalizeAddressSearchItem(dynamic raw) {
    if (raw is! Map) return null;
    final item = NodeValueParser.normalizeMap(Map<String, dynamic>.from(raw));
    return {
      'postalCode': NodeValueParser.asString(item['postalCode']) ?? '',
      'roadAddress': NodeValueParser.asString(item['roadAddress']) ?? '',
      'jibunAddress': NodeValueParser.asString(item['jibunAddress']) ?? '',
      'extraAddress': NodeValueParser.asString(item['extraAddress']) ?? '',
      'buildingName': NodeValueParser.asString(item['buildingName']) ?? '',
      'region1DepthName':
          NodeValueParser.asString(item['region1DepthName']) ?? '',
      'region2DepthName':
          NodeValueParser.asString(item['region2DepthName']) ?? '',
      'region3DepthName':
          NodeValueParser.asString(item['region3DepthName']) ?? '',
      'latitude': item['latitude'],
      'longitude': item['longitude'],
      'source': NodeValueParser.asString(item['source']) ?? '',
    };
  }

  static List<Map<String, dynamic>>? peekAddressList(String mbId) {
    final id = mbId.trim();
    final list = _listCache[id];
    if (list == null) return null;
    return List<Map<String, dynamic>>.from(list);
  }

  static List<Map<String, dynamic>>? peekFreshAddressList(String mbId) {
    final id = mbId.trim();
    final cachedAt = _listCacheAt[id];
    if (cachedAt == null ||
        DateTime.now().difference(cachedAt) >= _listCacheTtl) {
      return null;
    }
    final list = _listCache[id];
    if (list == null) return null;
    return List<Map<String, dynamic>>.from(list);
  }

  /// 서버 `message` 또는 `error`가 있으면 그 문구를, 없으면 저장 실패 문구를 쓴다.
  static String failureToast(Object? raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return saveFailureFallback;
    return text;
  }

  static void invalidateAll() {
    _listCache.clear();
    _listCacheAt.clear();
    _listInFlight.clear();
  }

  /// 배송지 목록 조회. 실패해도 기존 호출부는 빈 목록 또는 이전 캐시를 받는다.
  static Future<List<Map<String, dynamic>>> getAddressList(
    String mbId, {
    bool forceRefresh = false,
  }) async {
    final loaded = await loadAddresses(mbId, forceRefresh: forceRefresh);
    if (loaded.ok) return loaded.items;
    final cached = _listCache[mbId.trim()];
    if (cached != null) return List<Map<String, dynamic>>.from(cached);
    return [];
  }

  /// 성공한 목록만 캐시한다. 실패는 빈 목록으로 저장하지 않는다.
  static Future<AddressListLoad> loadAddresses(
    String mbId, {
    bool forceRefresh = false,
  }) async {
    final id = mbId.trim();
    final cachedAt = _listCacheAt[id];
    if (!forceRefresh &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _listCacheTtl) {
      return AddressListLoad.ok(
        List<Map<String, dynamic>>.from(_listCache[id] ?? const []),
      );
    }
    final pending = _listInFlight[id];
    if (pending != null) return pending;

    final request = _fetchAndCacheAddressList(id);
    _listInFlight[id] = request;
    try {
      return await request;
    } finally {
      _listInFlight.remove(id);
    }
  }

  static Future<AddressListLoad> _fetchAndCacheAddressList(String mbId) async {
    try {
      final result = await _fetchAddressList(mbId);
      _listCache[mbId] = result;
      _listCacheAt[mbId] = DateTime.now();
      return AddressListLoad.ok(List<Map<String, dynamic>>.from(result));
    } catch (_) {
      return AddressListLoad.failed;
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchAddressList(String mbId) async {
    final response = await ApiClient.get('/api/user/address?mbId=$mbId');
    if (response.statusCode != 200) {
      throw StateError('address list failed');
    }

    final data = json.decode(response.body);
    if (data is! Map || data['success'] != true) {
      throw StateError('address list failed');
    }

    final raw = data['data'];
    if (raw == null) return [];
    if (raw is! List) {
      throw StateError('address list failed');
    }
    return raw
        .map(_normalizeAddressItem)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  static dynamic _decodeBody(String body) {
    try {
      return json.decode(body);
    } catch (_) {
      return null;
    }
  }

  static String? _serverReason(dynamic body) {
    if (body is! Map) return null;
    for (final key in ['message', 'error']) {
      final text = body[key]?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  /// 주소 검색
  static Future<Map<String, dynamic>> searchAddresses(
    String query, {
    int page = 1,
    int size = 10,
  }) async {
    try {
      final encoded = Uri.encodeQueryComponent(query.trim());
      final response = await ApiClient.get(
          '/api/address/search?q=$encoded&page=$page&size=$size');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['success'] == false) {
          return {
            'success': false,
            'message': _serverReason(data) ?? '',
            'results': <Map<String, dynamic>>[],
          };
        }
        final list = (data is Map && data['results'] is List)
            ? (data['results'] as List)
            : const <dynamic>[];
        final normalized = list
            .map(_normalizeAddressSearchItem)
            .whereType<Map<String, dynamic>>()
            .toList();

        return {
          'success': true,
          'results': normalized,
          'meta': data is Map ? (data['meta'] ?? {}) : {},
        };
      }

      return {
        'success': false,
        'message': _serverReason(_decodeBody(response.body)) ?? '',
        'results': <Map<String, dynamic>>[],
      };
    } catch (e) {
      return {
        'success': false,
        'message': '',
        'results': <Map<String, dynamic>>[],
      };
    }
  }

  /// 주소 정규화/검증
  static Future<Map<String, dynamic>> resolveAddress(
      Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient.post('/api/address/resolve', payload);
      final data = json.decode(response.body);

      if (response.statusCode == 200 &&
          data is Map &&
          data['success'] == true) {
        return {
          'success': true,
          'address': data['address'] ?? {},
        };
      }

      return {
        'success': false,
        'message': _serverReason(data) ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'message': '',
      };
    }
  }

  /// 배송지 추가
  static Future<Map<String, dynamic>> addAddress(
      Map<String, dynamic> addressData) async {
    try {
      final response = await ApiClient.post('/api/user/address', addressData);

      final data = _decodeBody(response.body);
      if (response.statusCode == 200 && data is Map && data['success'] != false) {
        final mbId = (addressData['mbId'] ?? addressData['mb_id'] ?? '').toString();
        _rememberSaved(mbId, data['data']);

        return {
          'success': true,
          'data': data['data'],
          'message': data['message'] ?? '배송지가 추가되었습니다.',
        };
      }
      return {
        'success': false,
        'message': _serverReason(data) ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'message': '',
      };
    }
  }

  /// 배송지 수정
  static Future<Map<String, dynamic>> updateAddress(
      int id, Map<String, dynamic> addressData) async {
    try {
      final response =
          await ApiClient.put('/api/user/address/$id', addressData);

      final data = _decodeBody(response.body);
      if (response.statusCode == 200 && data is Map && data['success'] != false) {
        final mbId = (addressData['mbId'] ?? addressData['mb_id'] ?? '').toString();
        _rememberSaved(mbId, data['data'], replaceId: id);

        return {
          'success': true,
          'data': data['data'],
          'message': data['message'] ?? '배송지가 수정되었습니다.',
        };
      }
      return {
        'success': false,
        'message': _serverReason(data) ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'message': '',
      };
    }
  }

  /// 배송지 삭제
  static Future<Map<String, dynamic>> deleteAddress(int id, String mbId) async {
    try {
      final response =
          await ApiClient.delete('/api/user/address/$id?mbId=$mbId');

      final data = _decodeBody(response.body);
      if (response.statusCode == 200 && data is Map && data['success'] != false) {
        removeFromCache(mbId, id);

        return {
          'success': true,
          'message': data['message'] ?? '배송지가 삭제되었습니다.',
        };
      }
      return {
        'success': false,
        'message': _serverReason(data) ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'message': '',
      };
    }
  }

  /// 기본 배송지 설정
  static Future<Map<String, dynamic>> setDefaultAddress(
      int id, String mbId) async {
    try {
      final response = await ApiClient.put(
        '/api/user/address/$id/default?mbId=$mbId',
        {'mb_id': mbId},
      );

      final data = _decodeBody(response.body);
      if (response.statusCode == 200 && data is Map && data['success'] != false) {
        invalidate(mbId);
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'] ?? '기본 배송지로 설정되었습니다.',
        };
      }

      return {
        'success': false,
        'message': _serverReason(data) ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'message': '',
      };
    }
  }
}
