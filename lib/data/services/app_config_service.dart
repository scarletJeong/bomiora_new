import 'dart:convert';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';

class AppConfigService {
  static const Duration _cacheTtl = Duration(minutes: 5);
  static bool? _usePoint;
  static DateTime? _cachedAt;
  static Future<bool>? _inFlight;

  static Future<bool> usePoint() async {
    if (_usePoint != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      return _usePoint!;
    }
    final pending = _inFlight;
    if (pending != null) return pending;

    final request = _fetchUsePoint();
    _inFlight = request;
    try {
      final value = await request;
      _usePoint = value;
      _cachedAt = DateTime.now();
      return value;
    } finally {
      if (identical(_inFlight, request)) _inFlight = null;
    }
  }

  static Future<bool> _fetchUsePoint() async {
    try {
      final response = await ApiClient.get(ApiEndpoints.config);
      if (response.statusCode != 200) return true;
      final body = json.decode(response.body);
      if (body is! Map || body['success'] != true || body['data'] is! Map) {
        return true;
      }
      final value = (body['data'] as Map)['cf_use_point'];
      return value == 1 || value == true || value == '1';
    } catch (_) {
      return true;
    }
  }
}
