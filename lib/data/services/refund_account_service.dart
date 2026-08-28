import 'dart:convert';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';

/// 환불계좌 조회·저장 (`bomiora_back` GET/PUT `/api/user/refund-account`)
class RefundAccountService {
  static const Duration _cacheTtl = Duration(seconds: 60);
  static final Map<String, Map<String, dynamic>> _cache = {};
  static final Map<String, DateTime> _cacheAt = {};
  static final Map<String, Future<Map<String, dynamic>>> _inFlight = {};

  static Future<Map<String, dynamic>> fetch(String mbId) async {
    final id = mbId.trim();
    final cachedAt = _cacheAt[id];
    if (cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheTtl) {
      return Map<String, dynamic>.from(_cache[id]!);
    }
    final pending = _inFlight[id];
    if (pending != null) return pending;

    final request = _fetch(id);
    _inFlight[id] = request;
    try {
      final result = await request;
      if (result['success'] == true) {
        _cache[id] = Map<String, dynamic>.from(result);
        _cacheAt[id] = DateTime.now();
      }
      return result;
    } finally {
      _inFlight.remove(id);
    }
  }

  static Future<Map<String, dynamic>> _fetch(String mbId) async {
    final q = Uri.encodeComponent(mbId);
    final response = await ApiClient.get(
      '${ApiEndpoints.userRefundAccount}?mb_id=$q',
    );
    if (response.statusCode != 200) {
      Map<String, dynamic>? err;
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) err = decoded;
      } catch (_) {}
      return {
        'success': false,
        'message': err?['message'] ?? '환불계좌 조회에 실패했습니다. (${response.statusCode})',
      };
    }
    final body = response.body.isNotEmpty ? json.decode(response.body) : <String, dynamic>{};
    if (body is! Map<String, dynamic>) {
      return {'success': false, 'message': '응답 형식이 올바르지 않습니다.'};
    }
    return Map<String, dynamic>.from(body);
  }

  static Future<Map<String, dynamic>> save({
    required String mbId,
    required String refundBank,
    required String refundAccountDigits,
    required String refundHolder,
  }) async {
    final response = await ApiClient.put(
      ApiEndpoints.userRefundAccount,
      {
        'mbId': mbId,
        'refundBank': refundBank,
        'refundAccount': refundAccountDigits,
        'refundHolder': refundHolder,
      },
    );
    if (response.statusCode != 200) {
      Map<String, dynamic>? err;
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) err = decoded;
      } catch (_) {}
      return {
        'success': false,
        'message': err?['message'] ?? '환불계좌 저장에 실패했습니다. (${response.statusCode})',
      };
    }
    final body = response.body.isNotEmpty ? json.decode(response.body) : <String, dynamic>{};
    if (body is! Map<String, dynamic>) {
      return {'success': false, 'message': '응답 형식이 올바르지 않습니다.'};
    }
    _cache[mbId.trim()] = Map<String, dynamic>.from(body);
    _cacheAt[mbId.trim()] = DateTime.now();
    return Map<String, dynamic>.from(body);
  }
}
