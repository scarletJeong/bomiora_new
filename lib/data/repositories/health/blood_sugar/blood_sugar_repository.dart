import 'dart:convert';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../models/health/blood_sugar/blood_sugar_record_model.dart';

class BloodSugarRepository {
  static const Duration _cacheTtl = Duration(seconds: 30);
  static final Map<String, List<BloodSugarRecord>> _cache = {};
  static final Map<String, DateTime> _cacheAt = {};
  static final Map<String, Future<List<BloodSugarRecord>>> _inFlight = {};

  static void seedRecords(String userId, List<BloodSugarRecord> records) {
    final id = userId.trim();
    if (id.isEmpty) return;
    _cache[id] = List<BloodSugarRecord>.from(records);
    _cacheAt[id] = DateTime.now();
  }

  static void invalidate([String? userId]) {
    final id = userId?.trim() ?? '';
    if (id.isEmpty) {
      _cache.clear();
      _cacheAt.clear();
    } else {
      _cache.remove(id);
      _cacheAt.remove(id);
    }
  }

  // 사용자의 모든 혈당 기록 가져오기 (최적화: 한 번에 모든 데이터 로드)
  static Future<List<BloodSugarRecord>> getBloodSugarRecords(
      String userId) async {
    final id = userId.trim();
    final cachedAt = _cacheAt[id];
    if (cachedAt != null && DateTime.now().difference(cachedAt) < _cacheTtl) {
      return List<BloodSugarRecord>.from(_cache[id] ?? const []);
    }
    final pending = _inFlight[id];
    if (pending != null) return pending;
    final request = _fetchBloodSugarRecords(id);
    _inFlight[id] = request;
    try {
      final records = await request;
      seedRecords(id, records);
      return List<BloodSugarRecord>.from(records);
    } finally {
      _inFlight.remove(id);
    }
  }

  static Future<List<BloodSugarRecord>> _fetchBloodSugarRecords(
      String userId) async {
    try {
      final response = await ApiClient.get(
          '${ApiEndpoints.bloodSugarRecords}?mb_id=$userId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> records = data['data'];
          return records
              .map((json) => BloodSugarRecord.fromJson(json))
              .toList();
        } else if (data is List) {
          return data.map((json) => BloodSugarRecord.fromJson(json)).toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<BloodSugarRecord?> getLatestBloodSugarRecord(
      String userId) async {
    try {
      final response = await ApiClient.get(
          '${ApiEndpoints.bloodSugarRecords}/latest?mb_id=$userId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          return BloodSugarRecord.fromJson(data['data']);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> addBloodSugarRecord(BloodSugarRecord record) async {
    try {
      final response = await ApiClient.post(
        ApiEndpoints.bloodSugarRecords,
        record.toJson(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final ok = data['success'] == true;
        if (ok) invalidate(record.mbId);
        return ok;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateBloodSugarRecord(BloodSugarRecord record) async {
    try {
      if (record.id == null) {
        throw Exception('수정할 기록의 ID가 없습니다');
      }

      final response = await ApiClient.put(
        '${ApiEndpoints.bloodSugarRecords}/${record.id}',
        record.toJson(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final ok = data['success'] == true;
        if (ok) invalidate(record.mbId);
        return ok;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteBloodSugarRecord(
    int recordId, {
    String? mbId,
  }) async {
    try {
      final id = mbId?.trim() ?? '';
      final query = id.isEmpty ? '' : '?mb_id=${Uri.encodeQueryComponent(id)}';
      final response = await ApiClient.delete(
        '${ApiEndpoints.bloodSugarRecords}/$recordId$query',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final ok = data['success'] == true;
        if (ok) invalidate(id);
        return ok;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<List<BloodSugarRecord>> getBloodSugarRecordsByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final response = await ApiClient.get(
        '${ApiEndpoints.bloodSugarRecords}/range?mb_id=$userId&start_date=${startDate.toIso8601String()}&end_date=${endDate.toIso8601String()}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> records = data['data'];
          return records
              .map((json) => BloodSugarRecord.fromJson(json))
              .toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }
}
