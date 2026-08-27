import 'dart:convert';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../models/health/weight/weight_record_model.dart';

class WeightRepository {
  static const Duration _cacheTtl = Duration(seconds: 15);
  static final Map<String, List<WeightRecord>> _cache = {};
  static final Map<String, DateTime> _cacheAt = {};
  static final Map<String, Future<List<WeightRecord>>> _inFlight = {};

  static void invalidate([String? mbId]) {
    if (mbId == null || mbId.trim().isEmpty) {
      _cache.clear();
      _cacheAt.clear();
      return;
    }
    final id = mbId.trim();
    _cache.remove(id);
    _cacheAt.remove(id);
  }

  // 이미지 파일 업로드 (새로 추가)
  static Future<String?> uploadImage(dynamic imageFile) async {
    try {
      final response = await ApiClient.uploadFile(
          '/api/health/weight/upload-image', imageFile);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final relativeUrl = data['url']?.toString().trim() ?? '';
          if (relativeUrl.isEmpty) return null;
          if (relativeUrl.startsWith('http')) return relativeUrl;
          return '${ApiClient.baseUrl}$relativeUrl';
        }
      }
      if (response.statusCode == 413) {
        return null;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 체중 기록 추가
  static Future<bool> addWeightRecord(WeightRecord record) async {
    try {
      final response = await ApiClient.post(
        ApiEndpoints.weightRecords,
        record.toJson(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final ok = data['success'] == true;
        if (ok && data['record'] is Map) {
          final saved = WeightRecord.fromJson(
            Map<String, dynamic>.from(data['record']),
          );
          final records = List<WeightRecord>.from(_cache[record.mbId] ?? []);
          records.insert(0, saved);
          _cache[record.mbId] = records;
          _cacheAt[record.mbId] = DateTime.now();
        } else if (ok) {
          invalidate(record.mbId);
        }
        return ok;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // 체중 기록 수정
  static Future<bool> updateWeightRecord(WeightRecord record) async {
    try {
      if (record.id == null) {
        throw Exception('수정할 기록의 ID가 없습니다');
      }

      final response = await ApiClient.put(
        '${ApiEndpoints.weightRecords}/${record.id}',
        record.toJson(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final ok = data['success'] == true;
        if (ok && data['record'] is Map) {
          final saved = WeightRecord.fromJson(
            Map<String, dynamic>.from(data['record']),
          );
          final records = List<WeightRecord>.from(_cache[record.mbId] ?? []);
          final index = records.indexWhere((item) => item.id == record.id);
          if (index >= 0) {
            records[index] = saved;
            _cache[record.mbId] = records;
            _cacheAt[record.mbId] = DateTime.now();
          } else {
            invalidate(record.mbId);
          }
        } else if (ok) {
          invalidate(record.mbId);
        }
        return ok;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // 체중 기록 목록 조회 (최적화: 한 번에 모든 데이터 로드)
  static Future<List<WeightRecord>> getWeightRecords(String mbId) async {
    final id = mbId.trim();
    final cachedAt = _cacheAt[id];
    if (cachedAt != null && DateTime.now().difference(cachedAt) < _cacheTtl) {
      return List<WeightRecord>.from(_cache[id] ?? const []);
    }
    final pending = _inFlight[id];
    if (pending != null) return pending;

    final request = _fetchWeightRecords(id);
    _inFlight[id] = request;
    try {
      final records = await request;
      _cache[id] = records;
      _cacheAt[id] = DateTime.now();
      return List<WeightRecord>.from(records);
    } finally {
      _inFlight.remove(id);
    }
  }

  static Future<List<WeightRecord>> _fetchWeightRecords(String mbId) async {
    try {
      final response =
          await ApiClient.get('${ApiEndpoints.weightRecords}?mb_id=$mbId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> records = data['data'];
          return records.map((json) => WeightRecord.fromJson(json)).toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  // 체중 기록 삭제
  static Future<bool> deleteWeightRecord(int recordId, {String? mbId}) async {
    try {
      final id = mbId?.trim() ?? '';
      final query = id.isEmpty ? '' : '?mb_id=${Uri.encodeQueryComponent(id)}';
      final response = await ApiClient.delete(
        '${ApiEndpoints.weightRecords}/$recordId$query',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final ok = data['success'] == true;
        if (ok && id.isNotEmpty) {
          final records = List<WeightRecord>.from(_cache[id] ?? []);
          records.removeWhere((record) => record.id == recordId);
          _cache[id] = records;
          _cacheAt[id] = DateTime.now();
        }
        return ok;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // 최신 체중 기록 조회
  static Future<WeightRecord?> getLatestWeightRecord(String mbId) async {
    try {
      final response = await ApiClient.get(
          '${ApiEndpoints.weightRecords}/latest?mb_id=$mbId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return WeightRecord.fromJson(data['data']);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
