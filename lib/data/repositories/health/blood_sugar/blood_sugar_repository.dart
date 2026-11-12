import 'dart:convert';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/api_date_time.dart';
import '../../../models/health/blood_sugar/blood_sugar_record_model.dart';
import '../health_save_result.dart';

class BloodSugarRepository {
  static const Duration _cacheTtl = Duration(seconds: 30);
  static final Map<String, List<BloodSugarRecord>> _cache = {};
  static final Map<String, DateTime> _cacheAt = {};
  static final Map<String, Future<List<BloodSugarRecord>>> _inFlight = {};

  static DateTime? cacheUpdatedAt(String userId) => _cacheAt[userId.trim()];

  static List<BloodSugarRecord>? peekRecords(String userId) {
    final id = userId.trim();
    final list = _cache[id];
    if (list == null) return null;
    return List<BloodSugarRecord>.from(list);
  }

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
    final response = await ApiClient.get(
        '${ApiEndpoints.bloodSugarRecords}?mb_id=$userId');
    if (response.statusCode != 200) {
      throw Exception('혈당 기록 조회 실패 (${response.statusCode})');
    }
    final data = json.decode(response.body);
    if (data is Map && data['success'] == true) {
      final raw = data['data'];
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((json) =>
              BloodSugarRecord.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    }
    if (data is List) {
      return data
          .whereType<Map>()
          .map((json) =>
              BloodSugarRecord.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    }
    final message = data is Map ? data['message']?.toString().trim() : null;
    throw Exception(
      message == null || message.isEmpty ? '혈당 기록 조회에 실패했습니다' : message,
    );
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

  static Future<HealthSaveResult> addBloodSugarRecord(
    BloodSugarRecord record,
  ) async {
    try {
      final response = await ApiClient.post(
        ApiEndpoints.bloodSugarRecords,
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

  static Future<HealthSaveResult> updateBloodSugarRecord(
    BloodSugarRecord record,
  ) async {
    try {
      if (record.id == null) {
        return const HealthSaveResult(success: false);
      }

      final response = await ApiClient.put(
        '${ApiEndpoints.bloodSugarRecords}/${record.id}',
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
        '${ApiEndpoints.bloodSugarRecords}/range?mb_id=$userId'
        '&start_date=${Uri.encodeQueryComponent(ApiDateTime.kstDateTimeText(startDate))}'
        '&end_date=${Uri.encodeQueryComponent(ApiDateTime.kstDateTimeText(endDate))}',
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
