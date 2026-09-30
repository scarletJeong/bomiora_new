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
  static const Duration _cacheTtl = Duration(minutes: 2);
  static final Map<String, HealthDashboardPayload> _cache = {};
  static final Map<String, DateTime> _cacheAt = {};
  static final Map<String, Future<HealthDashboardPayload?>> _inFlight = {};

  static void invalidate([
    String? mbId,
    bool invalidateHealthGoal = false,
  ]) {
    if (mbId == null || mbId.trim().isEmpty) {
      _cache.clear();
      _cacheAt.clear();
      if (invalidateHealthGoal) HealthGoalRepository.invalidate();
      return;
    }
    final prefix = '${mbId.trim()}|';
    _cache.removeWhere((key, _) => key.startsWith(prefix));
    _cacheAt.removeWhere((key, _) => key.startsWith(prefix));
    if (invalidateHealthGoal) HealthGoalRepository.invalidate(mbId);
  }

  static HealthDashboardPayload? peek({
    required String mbId,
    required DateTime date,
  }) {
    final dateStr = date.toIso8601String().split('T')[0];
    final key = '${mbId.trim()}|$dateStr';
    final cachedAt = _cacheAt[key];
    if (cachedAt == null || DateTime.now().difference(cachedAt) >= _cacheTtl) {
      return null;
    }
    applyDomainCaches();
    return _cache[key];
  }

  /// 각 건강 기록 캐시에 있는 값을 대시보드 캐시의 해당 영역에 덮어쓴다.
  static void applyDomainCaches() {
    for (final key in _cache.keys.toList()) {
      final separator = key.lastIndexOf('|');
      if (separator <= 0) continue;
      final mbId = key.substring(0, separator);
      final dateStr = key.substring(separator + 1);
      final parts = dateStr.split('-');
      if (parts.length != 3) continue;
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year == null || month == null || day == null) continue;
      _overlayKey(key, mbId, DateTime(year, month, day));
    }
  }

  static void _overlayKey(String key, String mbId, DateTime day) {
    final current = _cache[key];
    final dashboardAt = _cacheAt[key];
    if (current == null || dashboardAt == null) return;

    bool sameDay(DateTime value) =>
        value.year == day.year &&
        value.month == day.month &&
        value.day == day.day;

    bool newer(DateTime? domainAt) =>
        domainAt != null && domainAt.isAfter(dashboardAt);

    final weights = newer(WeightRepository.cacheUpdatedAt(mbId))
        ? WeightRepository.peekRecords(mbId)
        : null;
    final pressures = newer(BloodPressureRepository.cacheUpdatedAt(mbId))
        ? BloodPressureRepository.peekRecords(mbId)
        : null;
    final sugars = newer(BloodSugarRepository.cacheUpdatedAt(mbId))
        ? BloodSugarRepository.peekRecords(mbId)
        : null;
    final heartRates = newer(HeartRateRepository.cacheUpdatedAt(mbId))
        ? HeartRateRepository.peekRecords(mbId)
        : null;
    final useMenstrual = MenstrualCycleRepository.hasRecordsCache(mbId);
    final goalAt = HealthGoalRepository.cacheUpdatedAt(mbId);
    final useGoal = HealthGoalRepository.hasCache(mbId) &&
        goalAt != null &&
        goalAt.isAfter(dashboardAt);

    _cache[key] = HealthDashboardPayload(
      weightRecords: weights == null
          ? current.weightRecords
          : weights.where((record) => sameDay(record.measuredAt)).toList(),
      bloodPressureRecords: pressures == null
          ? current.bloodPressureRecords
          : pressures.where((record) => sameDay(record.measuredAt)).toList(),
      bloodSugarRecords: sugars == null
          ? current.bloodSugarRecords
          : sugars.where((record) => sameDay(record.measuredAt)).toList(),
      heartRateRecords: heartRates == null
          ? current.heartRateRecords
          : heartRates.where((record) => sameDay(record.measuredAt)).toList(),
      menstrualCycle: useMenstrual
          ? MenstrualCycleRepository.peekNewestByPeriodStart(mbId)
          : current.menstrualCycle,
      steps: current.steps,
      healthGoal:
          useGoal ? HealthGoalRepository.peekCached(mbId) : current.healthGoal,
    );
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
      applyDomainCaches();
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
        final previousAt = _cacheAt[key];
        _cache[key] = result;
        _cacheAt[key] = previousAt ?? DateTime.now();
        applyDomainCaches();
        _cacheAt[key] = DateTime.now();
      }
      return _cache[key] ?? result;
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
      if (response.statusCode != 200)
        return _fetchLegacyDashboard(mbId: mbId, date: date);

      final body = json.decode(response.body) as Map<String, dynamic>?;
      if (body == null || body['success'] != true) {
        return _fetchLegacyDashboard(mbId: mbId, date: date);
      }

      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        return _fetchLegacyDashboard(mbId: mbId, date: date);
      }

      return _parseBundle(mbId, data);
    } catch (_) {
      return _fetchLegacyDashboard(mbId: mbId, date: date);
    }
  }

  static StepsRecord? _parseSteps(dynamic raw) {
    if (raw is List) {
      for (final item in raw) {
        final parsed = _parseSteps(item);
        if (parsed != null) return parsed;
      }
      return null;
    }
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final hasTotal =
        map.containsKey('total_steps') || map.containsKey('totalSteps');
    if (!hasTotal && map['data'] is Map) {
      return _parseSteps(map['data']);
    }
    if (!hasTotal) return null;
    try {
      final record = StepsRecord.fromJson(map);
      if (record.totalSteps <= 0) return null;
      return record;
    } catch (_) {
      return null;
    }
  }

  static HealthDashboardPayload _parseBundle(
    String mbId,
    Map<String, dynamic> data,
  ) {
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

    final steps = _parseSteps(data['steps']);

    HealthGoalRecordModel? healthGoal;
    final goalRaw = data['healthGoal'];
    if (goalRaw is Map<String, dynamic>) {
      healthGoal = HealthGoalRecordModel.fromJson(goalRaw);
    }
    HealthGoalRepository.seedLatest(mbId, healthGoal);

    MenstrualCycleRecord? menstrual;
    final menstrualRaw = data['menstrualCycle'];
    if (menstrualRaw is Map<String, dynamic>) {
      menstrual = MenstrualCycleRecord.fromJson(menstrualRaw);
    }

    final List<WeightRecord> weightRecords =
        parseList(data['weight'], WeightRecord.fromJson);
    final List<BloodPressureRecord> bloodPressureRecords =
        parseList(data['bloodPressure'], BloodPressureRecord.fromJson);
    final List<BloodSugarRecord> bloodSugarRecords =
        parseList(data['bloodSugar'], BloodSugarRecord.fromJson);
    final List<HeartRateRecord> heartRateRecords =
        parseList(data['heartRate'], HeartRateRecord.fromJson);
    // 대시보드 응답은 선택일 1건뿐이다. 목록 캐시를 이 조각으로 덮으면
    // 같은 날의 나머지 기록과 다른 날짜가 사라진다.
    MenstrualCycleRepository.seedLatest(mbId, menstrual);

    return HealthDashboardPayload(
      weightRecords: weightRecords,
      bloodPressureRecords: bloodPressureRecords,
      bloodSugarRecords: bloodSugarRecords,
      heartRateRecords: heartRateRecords,
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
        WeightRepository.getWeightRecords(mbId)
            .catchError((_) => <WeightRecord>[]),
        BloodPressureRepository.getBloodPressureRecords(mbId)
            .catchError((_) => <BloodPressureRecord>[]),
        BloodSugarRepository.getBloodSugarRecords(mbId)
            .catchError((_) => <BloodSugarRecord>[]),
        HeartRateRepository.getHeartRateRecords(mbId)
            .catchError((_) => <HeartRateRecord>[]),
        MenstrualCycleRepository.getLatestMenstrualCycleRecord(mbId)
            .catchError((_) => null),
        StepsRepository.getStepsRecordByMbId(mbId, date)
            .catchError((_) => null),
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
