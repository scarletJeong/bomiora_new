import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/api_date_time.dart';
import '../../../models/health/health_goal_record_model.dart';

class HealthGoalRepository {
  static const Duration _cacheTtl = Duration(minutes: 2);
  static final Map<String, HealthGoalRecordModel?> _cache = {};
  static final Map<String, DateTime> _cacheAt = {};
  static final Map<String, Future<HealthGoalFetchResult>> _inFlight = {};

  static void seedLatest(String mbId, HealthGoalRecordModel? goal) {
    final id = mbId.trim();
    if (id.isEmpty) return;
    _cache[id] = goal;
    _cacheAt[id] = DateTime.now();
  }

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

  static bool hasCache(String mbId) => _cache.containsKey(mbId.trim());

  static DateTime? cacheUpdatedAt(String mbId) => _cacheAt[mbId.trim()];

  static HealthGoalRecordModel? peekCached(String mbId) {
    final id = mbId.trim();
    if (!_cache.containsKey(id)) return null;
    return _cache[id];
  }

  static HealthGoalRecordModel? peekLatest(String mbId) {
    final id = mbId.trim();
    final cachedAt = _cacheAt[id];
    if (cachedAt == null ||
        DateTime.now().difference(cachedAt) >= _cacheTtl ||
        !_cache.containsKey(id)) {
      return null;
    }
    return _cache[id];
  }

  /// GET 최신 목표 1건 (`mb_id` 기준). 실패와 목표 없음은 구분하지 않는다.
  static Future<HealthGoalRecordModel?> fetchLatest(String mbId) async {
    final result = await fetchLatestResult(mbId);
    return result.failed ? null : result.goal;
  }

  /// 조회 성공(목표 없음 포함)과 실패를 구분한다. 실패는 캐시하지 않는다.
  static Future<HealthGoalFetchResult> fetchLatestResult(String mbId) async {
    final id = mbId.trim();
    final cachedAt = _cacheAt[id];
    if (cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheTtl &&
        _cache.containsKey(id)) {
      return HealthGoalFetchResult(goal: _cache[id]);
    }
    final pending = _inFlight[id];
    if (pending != null) return pending;

    final request = _fetchLatest(id);
    _inFlight[id] = request;
    try {
      final result = await request;
      if (!result.failed) {
        _cache[id] = result.goal;
        _cacheAt[id] = DateTime.now();
      }
      return result;
    } finally {
      _inFlight.remove(id);
    }
  }

  static Future<HealthGoalFetchResult> _fetchLatest(String mbId) async {
    try {
      final response = await ApiClient.get(ApiEndpoints.healthGoalLatest(mbId));
      if (response.statusCode != 200) {
        return HealthGoalFetchResult(
          failed: true,
          reason: 'status ${response.statusCode}',
        );
      }
      final body = json.decode(response.body) as Map<String, dynamic>?;
      if (body == null || body['success'] != true) {
        final message = body?['message']?.toString().trim();
        return HealthGoalFetchResult(
          failed: true,
          reason: message == null || message.isEmpty
              ? '목표를 불러오지 못했습니다'
              : message,
        );
      }
      final data = body['data'];
      if (data == null) return const HealthGoalFetchResult();
      if (data is! Map) {
        return const HealthGoalFetchResult(
          failed: true,
          reason: '목표를 불러오지 못했습니다',
        );
      }
      return HealthGoalFetchResult(
        goal: HealthGoalRecordModel.fromJson(Map<String, dynamic>.from(data)),
      );
    } catch (e) {
      debugPrint('[HealthGoalRepository.fetchLatest] $e');
      return HealthGoalFetchResult(failed: true, reason: e.toString());
    }
  }

  /// POST 목표 저장 (서버에서 bm_weight_records INSERT + bm_health_goal_records UPSERT, mb_id당 1행)
  static Future<HealthGoalRegisterResult> register({
    required String mbId,
    required double currentWeight,
    required double targetWeight,
    required int dailyStepGoal,
    DateTime? measuredAt,
  }) async {
    try {
      final payload = <String, dynamic>{
        'mb_id': mbId,
        'current_weight': currentWeight,
        'target_weight': targetWeight,
        'daily_step_goal': dailyStepGoal,
      };
      if (measuredAt != null) {
        payload['measured_at'] = ApiDateTime.kstDateTimeText(measuredAt);
      }

      final response = await ApiClient.post(
        ApiEndpoints.healthGoal,
        payload,
      );

      final body = json.decode(response.body) as Map<String, dynamic>?;
      final ok = (response.statusCode == 200 || response.statusCode == 201) &&
          body != null &&
          body['success'] == true;

      if (!ok) {
        final msg = body?['message']?.toString() ?? '목표설정 저장에 실패했습니다.';
        return HealthGoalRegisterResult(success: false, message: msg);
      }

      final data = body['data'];
      int? weightRecordId;
      if (data is Map<String, dynamic>) {
        weightRecordId = data['weight_record_id'] is int
            ? data['weight_record_id'] as int
            : int.tryParse('${data['weight_record_id']}');
        final goal = data['goal'];
        if (goal is Map) {
          _cache[mbId.trim()] = HealthGoalRecordModel.fromJson(
            Map<String, dynamic>.from(goal),
          );
          _cacheAt[mbId.trim()] = DateTime.now();
        }
      }

      return HealthGoalRegisterResult(
        success: true,
        message: body['message']?.toString(),
        weightRecordId: weightRecordId,
      );
    } catch (e) {
      debugPrint('[HealthGoalRepository.register] $e');
      return HealthGoalRegisterResult(
        success: false,
        logDetail: e.toString(),
      );
    }
  }
}

class HealthGoalFetchResult {
  final HealthGoalRecordModel? goal;
  final bool failed;
  final String? reason;

  const HealthGoalFetchResult({
    this.goal,
    this.failed = false,
    this.reason,
  });
}

class HealthGoalRegisterResult {
  final bool success;
  final String? message;
  final String? logDetail;
  final int? weightRecordId;

  const HealthGoalRegisterResult({
    required this.success,
    this.message,
    this.logDetail,
    this.weightRecordId,
  });
}
