import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../models/health/heart_rate/heart_rate_record_model.dart';

class HeartRateRepository {
  static const Duration _cacheTtl = Duration(seconds: 30);
  static final Map<String, List<HeartRateRecord>> _cache = {};
  static final Map<String, DateTime> _cacheAt = {};
  static final Map<String, Future<List<HeartRateRecord>>> _inFlight = {};

  static void seedRecords(String userId, List<HeartRateRecord> records) {
    final id = userId.trim();
    if (id.isEmpty) return;
    _cache[id] = List<HeartRateRecord>.from(records);
    _cacheAt[id] = DateTime.now();
  }

  static Future<List<HeartRateRecord>> getHeartRateRecords(
      String userId) async {
    final id = userId.trim();
    final cachedAt = _cacheAt[id];
    if (cachedAt != null && DateTime.now().difference(cachedAt) < _cacheTtl) {
      return List<HeartRateRecord>.from(_cache[id] ?? const []);
    }
    final pending = _inFlight[id];
    if (pending != null) return pending;
    final request = _fetchHeartRateRecords(id);
    _inFlight[id] = request;
    try {
      final records = await request;
      seedRecords(id, records);
      return List<HeartRateRecord>.from(records);
    } finally {
      _inFlight.remove(id);
    }
  }

  static Future<List<HeartRateRecord>> _fetchHeartRateRecords(
      String userId) async {
    try {
      final response = await ApiClient.get(
        '${ApiEndpoints.heartRateRecords}?mb_id=$userId',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final records = data['data'] as List<dynamic>;
          return records
              .map((e) => HeartRateRecord.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<HeartRateRecord?> getLatestHeartRateRecord(
      String userId) async {
    try {
      final response = await ApiClient.get(
        '${ApiEndpoints.heartRateRecords}/latest?mb_id=$userId',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return HeartRateRecord.fromJson(data['data'] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
