import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../models/health/blood_pressure/blood_pressure_record_model.dart';
import '../../../models/health/blood_sugar/blood_sugar_record_model.dart';
import '../../../models/health/heart_rate/heart_rate_record_model.dart';
import '../../../models/health/health_goal_record_model.dart';
import '../../../models/health/menstrual_cycle/menstrual_cycle_model.dart';
import '../../../models/health/steps/steps_record_model.dart';
import '../../../models/health/weight/weight_record_model.dart';
import '../blood_pressure/blood_pressure_repository.dart';
import '../blood_sugar/blood_sugar_repository.dart';
import '../health_goal/health_goal_repository.dart';
import '../heart_rate/heart_rate_repository.dart';
import '../menstrual_cycle/menstrual_cycle_repository.dart';
import '../steps/steps_repository.dart';
import '../weight/weight_repository.dart';

class HealthDashboardPayload {
  final List<WeightRecord> weightRecords;
  final List<BloodPressureRecord> bloodPressureRecords;
  final List<BloodSugarRecord> bloodSugarRecords;
  final List<HeartRateRecord> heartRateRecords;
  final MenstrualCycleRecord? menstrualCycle;
  final StepsRecord? steps;
  final HealthGoalRecordModel? healthGoal;

  const HealthDashboardPayload({
    required this.weightRecords,
    required this.bloodPressureRecords,
    required this.bloodSugarRecords,
    required this.heartRateRecords,
    this.menstrualCycle,
    this.steps,
    this.healthGoal,
  });
}

class HealthDashboardRepository {
  static const Duration _cacheTtl = Duration(seconds: 10);
  static final Map<String, HealthDashboardPayload> _cache = {};
  static final Map<String, DateTime> _cacheAt = {};
  static final Map<String, Future<HealthDashboardPayload?>> _inFlight = {};

  static void invalidate([String? mbId]) {
    if (mbId == null || mbId.trim().isEmpty) {
      _cache.clear();
      _cacheAt.clear();
      return;
    }
    final prefix = '${mbId.trim()}|';
    _cache.removeWhere((key, _) => key.startsWith(prefix));
    _cacheAt.removeWhere((key, _) => key.startsWith(prefix));
  }

  static Future<HealthDashboardPayload?> fetchDashboard({
    required String mbId,
    required DateTime date,
    bool forceRefresh = false,
  }) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final key = '${mbId.trim()}|$dateStr';
    final cachedAt = _cacheAt[key];
    if (!forceRefresh &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheTtl) {
      return _cache[key];
    }

    final pending = _inFlight[key];
    if (pending != null) return pending;

    final request = _fetchDashboard(
      mbId: mbId,
      date: date,
      dateStr: dateStr,
    );
    _inFlight[key] = request;
    try {
      final result = await request;
      if (result != null) {
        _cache[key] = result;
        _cacheAt[key] = DateTime.now();
      }
      return result;
    } finally {
      _inFlight.remove(key);
    }
  }

  static Future<HealthDashboardPayload?> _fetchDashboard({
    required String mbId,
    required DateTime date,
    required String dateStr,
  }) async {
    try {
      final response = await ApiClient.get(
        ApiEndpoints.healthDashboard(mbId: mbId, dateYyyyMmDd: dateStr),
      );
      // 프로덕션에 아직 배포 전이면 404 → 기존 개별 API로 fallback
      if (response.statusCode == 404) {
        return _fetchLegacyDashboard(mbId: mbId, date: date);
      }
      if (response.statusCode != 200) return _fetchLegacyDashboard(mbId: mbId, date: date);

      final body = json.decode(response.body) as Map<String, dynamic>?;
      if (body == null || body['success'] != true) {
        return _fetchLegacyDashboard(mbId: mbId, date: date);
      }

      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        return _fetchLegacyDashboard(mbId: mbId, date: date);
      }

      return _parseBundle(data);
    } catch (_) {
      return _fetchLegacyDashboard(mbId: mbId, date: date);
    }
  }

  static HealthDashboardPayload _parseBundle(Map<String, dynamic> data) {
    List<T> parseList<T>(
      dynamic raw,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    StepsRecord? steps;
    final stepsRaw = data['steps'];
    if (stepsRaw is Map<String, dynamic>) {
      steps = StepsRecord.fromJson(stepsRaw);
    }

    HealthGoalRecordModel? healthGoal;
    final goalRaw = data['healthGoal'];
    if (goalRaw is Map<String, dynamic>) {
      healthGoal = HealthGoalRecordModel.fromJson(goalRaw);
    }

    MenstrualCycleRecord? menstrual;
    final menstrualRaw = data['menstrualCycle'];
    if (menstrualRaw is Map<String, dynamic>) {
      menstrual = MenstrualCycleRecord.fromJson(menstrualRaw);
    }

    return HealthDashboardPayload(
      weightRecords: parseList(data['weight'], WeightRecord.fromJson),
      bloodPressureRecords:
          parseList(data['bloodPressure'], BloodPressureRecord.fromJson),
      bloodSugarRecords:
          parseList(data['bloodSugar'], BloodSugarRecord.fromJson),
      heartRateRecords:
          parseList(data['heartRate'], HeartRateRecord.fromJson),
      menstrualCycle: menstrual,
      steps: steps,
      healthGoal: healthGoal,
    );
  }

  static Future<HealthDashboardPayload?> _fetchLegacyDashboard({
    required String mbId,
    required DateTime date,
  }) async {
    try {
      final results = await Future.wait([
        WeightRepository.getWeightRecords(mbId).catchError((_) => <WeightRecord>[]),
        BloodPressureRepository.getBloodPressureRecords(mbId)
            .catchError((_) => <BloodPressureRecord>[]),
        BloodSugarRepository.getBloodSugarRecords(mbId)
            .catchError((_) => <BloodSugarRecord>[]),
        HeartRateRepository.getHeartRateRecords(mbId)
            .catchError((_) => <HeartRateRecord>[]),
        MenstrualCycleRepository.getLatestMenstrualCycleRecord(mbId)
            .catchError((_) => null),
        StepsRepository.getStepsRecordByMbId(mbId, date).catchError((_) => null),
        HealthGoalRepository.fetchLatest(mbId).catchError((_) => null),
      ]);

      return HealthDashboardPayload(
        weightRecords: results[0] as List<WeightRecord>,
        bloodPressureRecords: results[1] as List<BloodPressureRecord>,
        bloodSugarRecords: results[2] as List<BloodSugarRecord>,
        heartRateRecords: results[3] as List<HeartRateRecord>,
        menstrualCycle: results[4] as MenstrualCycleRecord?,
        steps: results[5] as StepsRecord?,
        healthGoal: results[6] as HealthGoalRecordModel?,
      );
    } catch (_) {
      return null;
    }
  }
}
