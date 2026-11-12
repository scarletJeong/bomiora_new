import 'dart:convert';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/api_date_time.dart';
import '../../../models/health/blood_pressure/blood_pressure_record_model.dart';
import '../health_save_result.dart';

class BloodPressureRepository {
  static const Duration _cacheTtl = Duration(seconds: 30);
  static final Map<String, List<BloodPressureRecord>> _cache = {};
  static final Map<String, DateTime> _cacheAt = {};
  static final Map<String, Future<List<BloodPressureRecord>>> _inFlight = {};

  static DateTime? cacheUpdatedAt(String userId) => _cacheAt[userId.trim()];

  static List<BloodPressureRecord>? peekRecords(String userId) {
    final id = userId.trim();
    final list = _cache[id];
    if (list == null) return null;
    return List<BloodPressureRecord>.from(list);
  }

  static void seedRecords(String userId, List<BloodPressureRecord> records) {
    final id = userId.trim();
    if (id.isEmpty) return;
    _cache[id] = List<BloodPressureRecord>.from(records);
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

  static List<BloodPressureRecord> optimisticallyUpsert(
    BloodPressureRecord record,
  ) {
    final id = record.mbId.trim();
    final previous = List<BloodPressureRecord>.from(_cache[id] ?? const []);
    final next = List<BloodPressureRecord>.from(previous);
    final index = record.id == null
        ? -1
        : next.indexWhere((candidate) => candidate.id == record.id);
    if (index >= 0) {
      next[index] = record;
    } else {
      next.insert(0, record);
    }
    seedRecords(id, next);
    return previous;
  }

  static void restoreRecords(
    String userId,
    List<BloodPressureRecord> records,
  ) {
    seedRecords(userId, records);
  }

  static Future<List<BloodPressureRecord>> getBloodPressureRecords(
      String userId) async {
    final id = userId.trim();
    final cachedAt = _cacheAt[id];
    if (cachedAt != null && DateTime.now().difference(cachedAt) < _cacheTtl) {
      return List<BloodPressureRecord>.from(_cache[id] ?? const []);
    }
    final pending = _inFlight[id];
    if (pending != null) return pending;
    final request = _fetchBloodPressureRecords(id);
    _inFlight[id] = request;
    try {
      final records = await request;
      seedRecords(id, records);
      return List<BloodPressureRecord>.from(records);
    } finally {
      _inFlight.remove(id);
    }
  }

  static Future<List<BloodPressureRecord>> _fetchBloodPressureRecords(
      String userId) async {
    final response = await ApiClient.get(
        '${ApiEndpoints.bloodPressureRecords}?mb_id=$userId');
    if (response.statusCode != 200) {
      throw Exception('혈압 기록 조회 실패 (${response.statusCode})');
    }
    final data = json.decode(response.body);
    if (data is Map && data['success'] == true) {
      final raw = data['data'];
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((json) =>
              BloodPressureRecord.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    }
    if (data is List) {
      return data
          .whereType<Map>()
          .map((json) =>
              BloodPressureRecord.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    }
    final message = data is Map ? data['message']?.toString().trim() : null;
    throw Exception(
      message == null || message.isEmpty ? '혈압 기록 조회에 실패했습니다' : message,
    );
  }

  static Future<BloodPressureRecord?> getLatestBloodPressureRecord(
      String userId) async {
    try {
      final response = await ApiClient.get(
          '${ApiEndpoints.bloodPressureRecords}/latest?mb_id=$userId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          return BloodPressureRecord.fromJson(data['data']);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<HealthSaveResult> addBloodPressureRecord(
    BloodPressureRecord record,
  ) async {
    try {
      final response = await ApiClient.post(
        ApiEndpoints.bloodPressureRecords,
        record.toJson(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final ok = data is Map && data['success'] == true;
        if (ok) invalidate(record.mbId);
        return ok ? HealthSaveResult.ok : HealthSaveResult.failed(data);
      }

      return HealthSaveResult.failed(HealthSaveResult.decode(response.body));
    } catch (e) {
      return const HealthSaveResult(success: false);
    }
  }

  static Future<HealthSaveResult> updateBloodPressureRecord(
    BloodPressureRecord record,
  ) async {
    try {
      if (record.id == null) {
        return const HealthSaveResult(success: false);
      }

      final response = await ApiClient.put(
        '${ApiEndpoints.bloodPressureRecords}/${record.id}',
        record.toJson(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final ok = data is Map && data['success'] == true;
        if (ok) invalidate(record.mbId);
        return ok ? HealthSaveResult.ok : HealthSaveResult.failed(data);
      }

      return HealthSaveResult.failed(HealthSaveResult.decode(response.body));
    } catch (e) {
      return const HealthSaveResult(success: false);
    }
  }

  static Future<bool> deleteBloodPressureRecord(
    int recordId, {
    String? mbId,
  }) async {
    try {
      final id = mbId?.trim() ?? '';
      final query = id.isEmpty ? '' : '?mb_id=${Uri.encodeQueryComponent(id)}';
      final response = await ApiClient.delete(
        '${ApiEndpoints.bloodPressureRecords}/$recordId$query',
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

  static Future<List<BloodPressureRecord>> getBloodPressureRecordsByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final response = await ApiClient.get(
        '${ApiEndpoints.bloodPressureRecords}/range?mb_id=$userId'
        '&start_date=${Uri.encodeQueryComponent(ApiDateTime.kstDateTimeText(startDate))}'
        '&end_date=${Uri.encodeQueryComponent(ApiDateTime.kstDateTimeText(endDate))}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> records = data['data'];
          return records
              .map((json) => BloodPressureRecord.fromJson(json))
              .toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }
}
