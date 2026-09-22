import 'dart:convert';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../models/health/menstrual_cycle/menstrual_cycle_model.dart';

class MenstrualCycleRepository {
  static const Duration _cacheTtl = Duration(seconds: 30);
  static final Map<String, List<MenstrualCycleRecord>> _cache = {};
  static final Map<String, DateTime> _cacheAt = {};
  static final Map<String, Future<List<MenstrualCycleRecord>>> _inFlight = {};
  static final Map<String, MenstrualCycleRecord?> _latestCache = {};

  static void seedLatest(String mbId, MenstrualCycleRecord? record) {
    final id = mbId.trim();
    if (id.isNotEmpty) _latestCache[id] = record;
  }

  static void invalidate([String? mbId]) {
    final id = mbId?.trim() ?? '';
    if (id.isEmpty) {
      _cache.clear();
      _cacheAt.clear();
      _latestCache.clear();
    } else {
      _cache.remove(id);
      _cacheAt.remove(id);
      _latestCache.remove(id);
    }
  }

  static List<MenstrualCycleRecord> optimisticallyUpsert(
    MenstrualCycleRecord record,
  ) {
    final id = record.mbId.trim();
    final previous = List<MenstrualCycleRecord>.from(_cache[id] ?? const []);
    final next = List<MenstrualCycleRecord>.from(previous);
    final index = record.id == null
        ? -1
        : next.indexWhere((candidate) => candidate.id == record.id);
    if (index >= 0) {
      next[index] = record;
    } else {
      next.insert(0, record);
    }
    _cache[id] = next;
    _cacheAt[id] = DateTime.now();
    _latestCache[id] = next.isEmpty ? null : next.first;
    return previous;
  }

  static void restoreRecords(
    String mbId,
    List<MenstrualCycleRecord> records,
  ) {
    final id = mbId.trim();
    _cache[id] = List<MenstrualCycleRecord>.from(records);
    _cacheAt[id] = DateTime.now();
    _latestCache[id] = records.isEmpty ? null : records.first;
  }

  // 생리주기 기록 추가
  static Future<bool> addMenstrualCycleRecord(
      MenstrualCycleRecord record) async {
    try {
      final response = await ApiClient.post(
        ApiEndpoints.menstrualCycleRecords,
        record.toJson(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final ok = data['success'] == true;
        if (ok && data['data'] is Map) {
          try {
            optimisticallyUpsert(
              MenstrualCycleRecord.fromJson(
                Map<String, dynamic>.from(data['data'] as Map),
              ),
            );
          } catch (_) {}
        }
        return ok;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // 생리주기 기록 수정
  static Future<bool> updateMenstrualCycleRecord(
      MenstrualCycleRecord record) async {
    try {
      if (record.id == null) {
        throw Exception('수정할 기록의 ID가 없습니다');
      }

      final response = await ApiClient.put(
        '${ApiEndpoints.menstrualCycleRecords}/${record.id}',
        record.toJson(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final ok = data['success'] == true;
        if (ok) optimisticallyUpsert(record);
        return ok;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // 생리주기 기록 목록 조회
  static Future<List<MenstrualCycleRecord>> getMenstrualCycleRecords(
      String mbId) async {
    final id = mbId.trim();
    final cachedAt = _cacheAt[id];
    if (cachedAt != null && DateTime.now().difference(cachedAt) < _cacheTtl) {
      return List<MenstrualCycleRecord>.from(_cache[id] ?? const []);
    }
    final pending = _inFlight[id];
    if (pending != null) return pending;
    final request = _fetchMenstrualCycleRecords(id);
    _inFlight[id] = request;
    try {
      final records = await request;
      _cache[id] = records;
      _cacheAt[id] = DateTime.now();
      if (records.isNotEmpty) _latestCache[id] = records.first;
      return List<MenstrualCycleRecord>.from(records);
    } finally {
      _inFlight.remove(id);
    }
  }

  static Future<List<MenstrualCycleRecord>> _fetchMenstrualCycleRecords(
      String mbId) async {
    try {
      final response = await ApiClient.get(
          '${ApiEndpoints.menstrualCycleRecords}?mb_id=$mbId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> records = data['data'];
          return records
              .map((json) => MenstrualCycleRecord.fromJson(json))
              .toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  // 생리주기 기록 삭제
  static Future<bool> deleteMenstrualCycleRecord(int recordId) async {
    try {
      final response = await ApiClient.delete(
          '${ApiEndpoints.menstrualCycleRecords}/$recordId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final ok = data['success'] == true;
        if (ok) invalidate();
        return ok;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // 최신 생리주기 기록 조회
  static Future<MenstrualCycleRecord?> getLatestMenstrualCycleRecord(
      String mbId) async {
    final id = mbId.trim();
    if (_latestCache.containsKey(id)) return _latestCache[id];
    try {
      final response = await ApiClient.get(
          '${ApiEndpoints.menstrualCycleRecords}/latest?mb_id=$mbId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final payload = data['data'] ?? data['record'];
        if (data['success'] == true && payload is Map<String, dynamic>) {
          final record = MenstrualCycleRecord.fromJson(payload);
          _latestCache[id] = record;
          return record;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // 생리주기 통계 조회
  static Future<Map<String, dynamic>?> getMenstrualCycleStats(
      String mbId) async {
    try {
      final response = await ApiClient.get(
          '${ApiEndpoints.menstrualCycleRecords}/stats?mb_id=$mbId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
