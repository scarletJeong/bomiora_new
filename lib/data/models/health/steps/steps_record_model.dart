class StepsRecord {
  final int id;
  final int userId;
  final DateTime date;
  final int totalSteps;
  final double distance; // km
  final int calories;
  final List<HourlySteps> hourlySteps;
  /// 30분 슬롯 48개(0=00:00~00:29, …) — `half_hour_steps` API 필드
  final List<int> halfHourSteps;
  final DateTime createdAt;
  final DateTime updatedAt;
  /// 선택 일자 기준 전날 대비 걸음 차이 (`/api/steps/daily-total` 등에서만 채워질 수 있음)
  final int? stepsDifference;

  StepsRecord({
    required this.id,
    required this.userId,
    required this.date,
    required this.totalSteps,
    required this.distance,
    required this.calories,
    required this.hourlySteps,
    this.halfHourSteps = const [],
    required this.createdAt,
    required this.updatedAt,
    this.stepsDifference,
  });

  static int _intVal(dynamic v, [int def = 0]) {
    if (v == null) return def;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString()) ?? def;
  }

  static int? _intNullable(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }

  static double _doubleVal(dynamic v, [double def = 0.0]) {
    if (v == null) return def;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? def;
  }

  static List<int> _halfHourStepsFromJson(
    Map<String, dynamic> json,
    List<HourlySteps> hourlySteps,
  ) {
    final raw = json['half_hour_steps'] ?? json['halfHourSteps'];
    if (raw is List<dynamic>) {
      if (raw.length >= 48 && raw.take(48).every((e) => e == null || e is num)) {
        return List<int>.generate(
          48,
          (i) => i < raw.length ? _intVal(raw[i]) : 0,
        );
      }
      final slots = List<int>.filled(48, 0);
      var any = false;
      for (final e in raw) {
        if (e is Map) {
          final m = Map<String, dynamic>.from(e);
          final slot = _intVal(m['slot'], -1);
          if (slot >= 0 && slot < 48) {
            slots[slot] = _intVal(m['steps']);
            any = true;
          }
        }
      }
      if (any) return slots;
    }
    final slots = List<int>.filled(48, 0);
    for (final h in hourlySteps) {
      if (h.hour >= 0 && h.hour < 24) {
        final half = (h.steps / 2).round();
        slots[h.hour * 2] += half;
        slots[h.hour * 2 + 1] += h.steps - half;
      }
    }
    return slots;
  }

  factory StepsRecord.fromJson(Map<String, dynamic> json) {
    final dateRaw =
        json['date'] ?? json['record_date'] ?? json['recordDate'];
    final List<HourlySteps> hourlySteps =
        (json['hourly_steps'] ?? json['hourlySteps']) is List
            ? List<HourlySteps>.from(
                ((json['hourly_steps'] ?? json['hourlySteps']) as List<dynamic>).map(
                  (e) => HourlySteps.fromJson(Map<String, dynamic>.from(e as Map)),
                ),
              )
            : <HourlySteps>[];
    return StepsRecord(
      id: _intVal(json['id']),
      userId: _intVal(json['user_id'] ?? json['userId']),
      date: _parseDate(dateRaw),
      totalSteps: _intVal(json['total_steps'] ?? json['totalSteps']),
      distance: _doubleVal(
        json['distance'] ?? json['distance_km'] ?? json['distanceKm'],
      ),
      calories: _intVal(json['calories'] ?? json['calories_burned'] ?? json['caloriesBurned']),
      hourlySteps: hourlySteps,
      halfHourSteps: _halfHourStepsFromJson(json, hourlySteps),
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at'] ?? json['updatedAt']) ?? DateTime.now(),
      stepsDifference: _intNullable(json['steps_difference'] ?? json['stepsDifference']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    final s = value.toString();
    try {
      if (s.length == 10 && s.contains('-')) {
        return DateTime.parse('${s}T12:00:00');
      }
      return DateTime.parse(s);
    } catch (_) {
      return DateTime.now();
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    try {
      final raw = value.toString().trim();
      final parsed = DateTime.parse(raw);

      // 서버가 로컬 시각을 보내고 'Z'가 붙어 UTC로 오인되는 경우
      // (예: "2026-04-08T09:00:00.000Z"가 사실 09:00 로컬 의미) 시각 유지.
      final looksLikeWallClockUtcZ =
          raw.endsWith('Z') && !raw.contains('+') && !raw.contains('-');
      if (parsed.isUtc && looksLikeWallClockUtcZ) {
        return DateTime(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
          parsed.microsecond,
        );
      }
      return parsed.isUtc ? parsed.toLocal() : parsed;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'date': date.toIso8601String().split('T')[0],
      'total_steps': totalSteps,
      'distance': distance,
      'calories': calories,
      'hourly_steps': hourlySteps.map((item) => item.toJson()).toList(),
      'half_hour_steps':
          halfHourSteps.asMap().entries.map((e) => {'slot': e.key, 'steps': e.value}).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (stepsDifference != null) 'steps_difference': stepsDifference,
    };
  }

  StepsRecord copyWith({
    int? id,
    int? userId,
    DateTime? date,
    int? totalSteps,
    double? distance,
    int? calories,
    List<HourlySteps>? hourlySteps,
    List<int>? halfHourSteps,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? stepsDifference,
  }) {
    return StepsRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      totalSteps: totalSteps ?? this.totalSteps,
      distance: distance ?? this.distance,
      calories: calories ?? this.calories,
      hourlySteps: hourlySteps ?? this.hourlySteps,
      halfHourSteps: halfHourSteps ?? this.halfHourSteps,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      stepsDifference: stepsDifference ?? this.stepsDifference,
    );
  }
}

class HourlySteps {
  final int hour; // 0-23
  final int steps;
  final double distance;
  final int calories;

  HourlySteps({
    required this.hour,
    required this.steps,
    required this.distance,
    required this.calories,
  });

  static int _intVal(dynamic v, [int def = 0]) {
    if (v == null) return def;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString()) ?? def;
  }

  static double _doubleVal(dynamic v, [double def = 0.0]) {
    if (v == null) return def;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? def;
  }

  factory HourlySteps.fromJson(Map<String, dynamic> json) {
    return HourlySteps(
      hour: _intVal(json['hour']),
      steps: _intVal(json['steps']),
      distance: _doubleVal(
        json['distance'] ?? json['distance_km'] ?? json['distanceKm'],
      ),
      calories: _intVal(json['calories'] ?? json['calories_burned'] ?? json['caloriesBurned']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hour': hour,
      'steps': steps,
      'distance': distance,
      'calories': calories,
    };
  }

  HourlySteps copyWith({
    int? hour,
    int? steps,
    double? distance,
    int? calories,
  }) {
    return HourlySteps(
      hour: hour ?? this.hour,
      steps: steps ?? this.steps,
      distance: distance ?? this.distance,
      calories: calories ?? this.calories,
    );
  }
}

// 걸음수 통계 모델 (Node /api/steps/statistics 의 camelCase 응답 호환)
class StepsStatistics {
  final int todaySteps;
  final int yesterdaySteps;
  final int weeklyAverage;
  final int monthlyAverage;
  final int stepsDifference; // 전날 대비 차이
  final double distanceDifference; // 전날 대비 거리 차이
  final int caloriesDifference; // 전날 대비 칼로리 차이

  StepsStatistics({
    required this.todaySteps,
    required this.yesterdaySteps,
    required this.weeklyAverage,
    required this.monthlyAverage,
    required this.stepsDifference,
    required this.distanceDifference,
    required this.caloriesDifference,
  });

  static int _i(Map<String, dynamic> json, List<String> keys, [int def = 0]) {
    for (final k in keys) {
      final v = json[k];
      if (v == null) continue;
      if (v is int) return v;
      if (v is num) return v.round();
      final p = int.tryParse(v.toString());
      if (p != null) return p;
    }
    return def;
  }

  static double _d(Map<String, dynamic> json, List<String> keys, [double def = 0.0]) {
    for (final k in keys) {
      final v = json[k];
      if (v == null) continue;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      final p = double.tryParse(v.toString());
      if (p != null) return p;
    }
    return def;
  }

  factory StepsStatistics.fromJson(Map<String, dynamic> json) {
    return StepsStatistics(
      todaySteps: _i(json, ['today_steps', 'todaySteps']),
      yesterdaySteps: _i(json, ['yesterday_steps', 'yesterdaySteps']),
      weeklyAverage: _i(json, ['weekly_average', 'weeklyAverageSteps', 'weeklyAverage']),
      monthlyAverage: _i(json, ['monthly_average', 'monthlyAverageSteps', 'monthlyAverage']),
      stepsDifference: _i(json, ['steps_difference', 'stepsDifference']),
      distanceDifference: _d(json, ['distance_difference', 'distanceDifference']),
      caloriesDifference: _i(json, ['calories_difference', 'caloriesDifference']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'today_steps': todaySteps,
      'yesterday_steps': yesterdaySteps,
      'weekly_average': weeklyAverage,
      'monthly_average': monthlyAverage,
      'steps_difference': stepsDifference,
      'distance_difference': distanceDifference,
      'calories_difference': caloriesDifference,
    };
  }
}
