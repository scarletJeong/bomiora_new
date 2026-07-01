import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import 'health_sync_service_stub.dart';
import 'health_sync_snapshot.dart';

export 'health_sync_service_stub.dart' show HealthSyncResult;
export 'health_sync_snapshot.dart';

class HealthSyncService {
  HealthSyncService._();

  static final Health _health = Health();

  static List<HealthDataType> get _readTypes {
    final types = <HealthDataType>[
      HealthDataType.STEPS,
      HealthDataType.HEART_RATE,
      HealthDataType.WEIGHT,
      HealthDataType.BODY_MASS_INDEX,
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
      HealthDataType.BLOOD_GLUCOSE,
      HealthDataType.WORKOUT,
      HealthDataType.SPEED,
      HealthDataType.NUTRITION,
      HealthDataType.MENSTRUATION_FLOW,
      HealthDataType.TOTAL_CALORIES_BURNED,
      HealthDataType.ACTIVE_ENERGY_BURNED,
    ];
    if (Platform.isAndroid) {
      types.addAll([
        HealthDataType.DISTANCE_DELTA,
        HealthDataType.ACTIVITY_INTENSITY,
      ]);
    } else {
      types.addAll([
        HealthDataType.DISTANCE_WALKING_RUNNING,
        HealthDataType.EXERCISE_TIME,
        HealthDataType.DIETARY_ENERGY_CONSUMED,
        HealthDataType.DIETARY_PROTEIN_CONSUMED,
        HealthDataType.DIETARY_FATS_CONSUMED,
        HealthDataType.DIETARY_CARBS_CONSUMED,
      ]);
    }
    return types.where(_health.isDataTypeAvailable).toList();
  }

  static List<HealthDataAccess> _permissionsFor(List<HealthDataType> types) =>
      List.filled(types.length, HealthDataAccess.READ);

  static Future<HealthSyncResult> connectAndFetchToday() async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        return const HealthSyncResult(
          success: false,
          authorized: false,
          supported: false,
          steps: null,
          heartRate: null,
          message: '현재 플랫폼에서는 건강앱 연동이 지원되지 않습니다.',
        );
      }

      await _health.configure();

      if (Platform.isAndroid) {
        final available = await _health.isHealthConnectAvailable();
        if (!available) {
          await _health.installHealthConnect();
          return const HealthSyncResult(
            success: false,
            authorized: false,
            supported: true,
            steps: null,
            heartRate: null,
            message:
                'Health Connect 앱 설치가 필요합니다. 삼성 헬스와 연동하려면 Health Connect를 설치한 뒤 삼성 헬스에서 데이터 공유를 켜 주세요.',
          );
        }
        await Permission.activityRecognition.request();
      }

      final types = _readTypes;
      final authorized = await _health.requestAuthorization(
        types,
        permissions: _permissionsFor(types),
      );

      if (!authorized) {
        return HealthSyncResult(
          success: false,
          authorized: false,
          supported: true,
          steps: null,
          heartRate: null,
          message: Platform.isAndroid
              ? '건강 데이터 읽기 권한이 필요합니다. Health Connect에서 보미오라 권한을 허용해 주세요.'
              : '건강 데이터 읽기 권한이 필요합니다. 설정에서 보미오라의 건강 권한을 허용해 주세요.',
        );
      }

      return fetchToday(authorized: true);
    } catch (e, st) {
      debugPrint('HealthSyncService.connectAndFetchToday: $e\n$st');
      return HealthSyncResult(
        success: false,
        authorized: false,
        supported: true,
        steps: null,
        heartRate: null,
        message: '연동 중 오류가 발생했습니다: $e',
      );
    }
  }

  static Future<HealthSyncResult> fetchToday({bool authorized = false}) async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        return const HealthSyncResult(
          success: false,
          authorized: false,
          supported: false,
          steps: null,
          heartRate: null,
          message: '현재 플랫폼에서는 건강앱 연동이 지원되지 않습니다.',
        );
      }

      await _health.configure();

      if (Platform.isAndroid) {
        final available = await _health.isHealthConnectAvailable();
        if (!available) {
          return const HealthSyncResult(
            success: false,
            authorized: false,
            supported: true,
            steps: null,
            heartRate: null,
            message: 'Health Connect가 설치되어 있지 않습니다.',
          );
        }
      }

      final types = _readTypes;
      var hasPermission = authorized;
      if (!hasPermission) {
        hasPermission = await _health.hasPermissions(
              types,
              permissions: _permissionsFor(types),
            ) ??
            false;
      }

      if (!hasPermission) {
        return const HealthSyncResult(
          success: false,
          authorized: false,
          supported: true,
          steps: null,
          heartRate: null,
          message: '건강 데이터 읽기 권한이 없습니다. 연동하기를 먼저 진행해 주세요.',
        );
      }

      final snapshot = await _buildTodaySnapshot(types);
      return HealthSyncResult(
        success: true,
        authorized: true,
        supported: true,
        steps: snapshot.activity.steps,
        heartRate: snapshot.latestHeartRate,
        snapshot: snapshot,
        message: Platform.isAndroid
            ? 'Health Connect에서 오늘 건강 데이터를 불러왔습니다.'
            : '애플 건강에서 오늘 데이터를 불러왔습니다.',
      );
    } catch (e, st) {
      debugPrint('HealthSyncService.fetchToday: $e\n$st');
      return HealthSyncResult(
        success: false,
        authorized: false,
        supported: true,
        steps: null,
        heartRate: null,
        message: '데이터 조회 중 오류가 발생했습니다: $e',
      );
    }
  }

  static Future<HealthSyncSnapshot> _buildTodaySnapshot(
    List<HealthDataType> types,
  ) async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    final points = _health.removeDuplicates(
      await _health.getHealthDataFromTypes(
        types: types,
        startTime: midnight,
        endTime: now,
      ),
    );

    int? steps;
    try {
      steps = await _health.getTotalStepsInInterval(midnight, now);
    } catch (e) {
      debugPrint('getTotalStepsInInterval failed: $e');
    }

    final heartPoints = _filterType(points, HealthDataType.HEART_RATE);
    final latestHeartRate = _latestNumeric(heartPoints)?.round();

    final distanceM = _sumNumeric(
      _filterType(points, HealthDataType.DISTANCE_DELTA) +
          _filterType(points, HealthDataType.DISTANCE_WALKING_RUNNING),
    );
    final distanceKm = distanceM != null ? distanceM / 1000.0 : null;

    final caloriesKcal = _sumNumeric(
      _filterType(points, HealthDataType.TOTAL_CALORIES_BURNED) +
          _filterType(points, HealthDataType.ACTIVE_ENERGY_BURNED),
    );

    var activeMinutes = 0;
    for (final p in _filterType(points, HealthDataType.WORKOUT)) {
      activeMinutes += p.dateTo.difference(p.dateFrom).inMinutes;
    }
    for (final p in _filterType(points, HealthDataType.ACTIVITY_INTENSITY)) {
      activeMinutes += p.dateTo.difference(p.dateFrom).inMinutes;
    }
    final exerciseSeconds = _sumNumeric(
      _filterType(points, HealthDataType.EXERCISE_TIME),
    );
    if (exerciseSeconds != null) {
      activeMinutes += (exerciseSeconds / 60).round();
    }

    final activity = HealthActivitySnapshot(
      steps: steps ?? 0,
      distanceKm: distanceKm != null && distanceKm > 0
          ? double.parse(distanceKm.toStringAsFixed(2))
          : null,
      activeMinutes: activeMinutes > 0 ? activeMinutes : null,
      caloriesKcal: caloriesKcal != null && caloriesKcal > 0
          ? double.parse(caloriesKcal.toStringAsFixed(1))
          : null,
    );

    final workouts = _buildWorkouts(points, heartPoints);

    final weightPoint = _latestPoint(_filterType(points, HealthDataType.WEIGHT));
    final bmiPoint =
        _latestPoint(_filterType(points, HealthDataType.BODY_MASS_INDEX));
    HealthBodySnapshot? body;
    if (weightPoint != null || bmiPoint != null) {
      body = HealthBodySnapshot(
        weightKg: weightPoint != null
            ? _numericValue(weightPoint)?.toDouble()
            : null,
        bmi: bmiPoint != null ? _numericValue(bmiPoint)?.toDouble() : null,
        measuredAt: weightPoint?.dateTo ?? bmiPoint?.dateTo,
      );
    }

    final bloodPressure = _buildBloodPressure(points);
    final bloodGlucose = _buildBloodGlucose(points);
    final nutrition = _buildNutrition(points, midnight, now);
    final menstruation = _buildMenstruation(points);

    return HealthSyncSnapshot(
      activity: activity,
      workouts: workouts,
      latestHeartRate: latestHeartRate,
      body: body,
      bloodPressure: bloodPressure,
      bloodGlucose: bloodGlucose,
      nutrition: nutrition,
      menstruation: menstruation,
    );
  }

  static List<HealthWorkoutSnapshot> _buildWorkouts(
    List<HealthDataPoint> allPoints,
    List<HealthDataPoint> heartPoints,
  ) {
    final workouts = <HealthWorkoutSnapshot>[];
    for (final p in _filterType(allPoints, HealthDataType.WORKOUT)) {
      final value = p.value;
      if (value is! WorkoutHealthValue) continue;

      final durationMinutes = p.dateTo.difference(p.dateFrom).inMinutes;
      final hrInWorkout = heartPoints
          .where(
            (h) =>
                !h.dateFrom.isBefore(p.dateFrom) && !h.dateTo.isAfter(p.dateTo),
          )
          .map(_numericValue)
          .whereType<num>()
          .map((n) => n.round())
          .toList();

      int? avgHr;
      int? maxHr;
      if (hrInWorkout.isNotEmpty) {
        maxHr = hrInWorkout.reduce((a, b) => a > b ? a : b);
        avgHr =
            (hrInWorkout.reduce((a, b) => a + b) / hrInWorkout.length).round();
      }

      double? speedKmh;
      final speedPoints = _filterType(allPoints, HealthDataType.SPEED)
          .where(
            (s) =>
                !s.dateFrom.isBefore(p.dateFrom) && !s.dateTo.isAfter(p.dateTo),
          )
          .map(_numericValue)
          .whereType<num>()
          .toList();
      if (speedPoints.isNotEmpty) {
        final avgMs = speedPoints.reduce((a, b) => a + b) / speedPoints.length;
        speedKmh = double.parse((avgMs * 3.6).toStringAsFixed(1));
      } else if (value.totalDistance != null &&
          value.totalDistance! > 0 &&
          durationMinutes > 0) {
        final km = value.totalDistance! / 1000.0;
        speedKmh = double.parse(
          (km / (durationMinutes / 60.0)).toStringAsFixed(1),
        );
      }

      workouts.add(
        HealthWorkoutSnapshot(
          typeLabel: _workoutLabel(value.workoutActivityType),
          durationMinutes: durationMinutes > 0 ? durationMinutes : 1,
          avgHeartRate: avgHr,
          maxHeartRate: maxHr,
          speedKmh: speedKmh,
          caloriesKcal: value.totalEnergyBurned?.toDouble(),
          startedAt: p.dateFrom,
        ),
      );
    }
    workouts.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return workouts;
  }

  static HealthBloodPressureSnapshot? _buildBloodPressure(
    List<HealthDataPoint> points,
  ) {
    final sys =
        _latestPoint(_filterType(points, HealthDataType.BLOOD_PRESSURE_SYSTOLIC));
    final dia = _latestPoint(
      _filterType(points, HealthDataType.BLOOD_PRESSURE_DIASTOLIC),
    );
    if (sys == null && dia == null) return null;
    return HealthBloodPressureSnapshot(
      systolic: sys != null ? _numericValue(sys)?.round() : null,
      diastolic: dia != null ? _numericValue(dia)?.round() : null,
      measuredAt: sys?.dateTo ?? dia?.dateTo,
    );
  }

  static HealthBloodGlucoseSnapshot? _buildBloodGlucose(
    List<HealthDataPoint> points,
  ) {
    final latest = _latestPoint(_filterType(points, HealthDataType.BLOOD_GLUCOSE));
    if (latest == null) return null;
    return HealthBloodGlucoseSnapshot(
      valueMgDl: _numericValue(latest)?.toDouble(),
      measuredAt: latest.dateTo,
    );
  }

  static List<HealthNutritionSnapshot> _buildNutrition(
    List<HealthDataPoint> points,
    DateTime start,
    DateTime end,
  ) {
    final meals = <HealthNutritionSnapshot>[];

    for (final p in _filterType(points, HealthDataType.NUTRITION)) {
      final v = p.value;
      if (v is! NutritionHealthValue) continue;
      meals.add(
        HealthNutritionSnapshot(
          mealName: v.name,
          mealType: v.mealType,
          caloriesKcal: v.calories,
          proteinG: v.protein,
          fatG: v.fat,
          carbsG: v.carbs,
          recordedAt: p.dateFrom,
        ),
      );
    }

    if (meals.isEmpty && Platform.isIOS) {
      final kcal = _sumNumeric(
        _filterType(points, HealthDataType.DIETARY_ENERGY_CONSUMED),
      );
      final protein = _sumNumeric(
        _filterType(points, HealthDataType.DIETARY_PROTEIN_CONSUMED),
      );
      final fat = _sumNumeric(
        _filterType(points, HealthDataType.DIETARY_FATS_CONSUMED),
      );
      final carbs = _sumNumeric(
        _filterType(points, HealthDataType.DIETARY_CARBS_CONSUMED),
      );
      if ([kcal, protein, fat, carbs].any((v) => v != null && v > 0)) {
        meals.add(
          HealthNutritionSnapshot(
            mealName: '오늘 섭취 합계',
            caloriesKcal: kcal,
            proteinG: protein,
            fatG: fat,
            carbsG: carbs,
            recordedAt: end,
          ),
        );
      }
    }

    meals.sort((a, b) {
      final ad = a.recordedAt ?? start;
      final bd = b.recordedAt ?? start;
      return bd.compareTo(ad);
    });
    return meals;
  }

  static List<HealthMenstruationSnapshot> _buildMenstruation(
    List<HealthDataPoint> points,
  ) {
    final entries = <HealthMenstruationSnapshot>[];
    for (final p in _filterType(points, HealthDataType.MENSTRUATION_FLOW)) {
      final value = _numericValue(p)?.round();
      entries.add(
        HealthMenstruationSnapshot(
          date: p.dateFrom,
          flowLabel: value != null ? _menstruationFlowLabel(value) : null,
        ),
      );
    }
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  static List<HealthDataPoint> _filterType(
    List<HealthDataPoint> points,
    HealthDataType type,
  ) =>
      points.where((p) => p.type == type).toList();

  static HealthDataPoint? _latestPoint(List<HealthDataPoint> points) {
    if (points.isEmpty) return null;
    final sorted = [...points]..sort((a, b) => b.dateTo.compareTo(a.dateTo));
    return sorted.first;
  }

  static num? _latestNumeric(List<HealthDataPoint> points) {
    final p = _latestPoint(points);
    return p != null ? _numericValue(p) : null;
  }

  static num? _numericValue(HealthDataPoint point) {
    final value = point.value;
    if (value is NumericHealthValue) {
      return value.numericValue;
    }
    return null;
  }

  static double? _sumNumeric(List<HealthDataPoint> points) {
    var sum = 0.0;
    var has = false;
    for (final p in points) {
      final n = _numericValue(p);
      if (n != null) {
        sum += n.toDouble();
        has = true;
      }
    }
    return has ? sum : null;
  }

  static String _workoutLabel(HealthWorkoutActivityType type) {
    final labels = <HealthWorkoutActivityType, String>{
      HealthWorkoutActivityType.WALKING: '걷기',
      HealthWorkoutActivityType.RUNNING: '달리기',
      HealthWorkoutActivityType.BIKING: '자전거',
      HealthWorkoutActivityType.SWIMMING: '수영',
      HealthWorkoutActivityType.HIKING: '하이킹',
      HealthWorkoutActivityType.YOGA: '요가',
      HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING: '근력운동',
      HealthWorkoutActivityType.FUNCTIONAL_STRENGTH_TRAINING: '근력운동',
      HealthWorkoutActivityType.ELLIPTICAL: '일립티컬',
      HealthWorkoutActivityType.ROWING: '로잉',
      HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING: 'HIIT',
    };
    return labels[type] ?? type.name.replaceAll('_', ' ');
  }

  static String _menstruationFlowLabel(int value) {
    if (value <= 1) return '가벼움';
    if (value == 2) return '보통';
    if (value == 3) return '많음';
    return '기록';
  }
}
