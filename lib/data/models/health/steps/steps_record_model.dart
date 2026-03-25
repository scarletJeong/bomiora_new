class StepsRecord {
  final int id;
  final int userId;
  final DateTime date;
  final int totalSteps;
  final double distance; // km
  final int calories;
  final List<HourlySteps> hourlySteps;
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

  factory StepsRecord.fromJson(Map<String, dynamic> json) {
    final dateRaw =
        json['date'] ?? json['record_date'] ?? json['recordDate'];
    return StepsRecord(
      id: _intVal(json['id']),
      userId: _intVal(json['user_id'] ?? json['userId']),
      date: _parseDate(dateRaw),
      totalSteps: _intVal(json['total_steps'] ?? json['totalSteps']),
      distance: _doubleVal(
        json['distance'] ?? json['distance_km'] ?? json['distanceKm'],
      ),
      calories: _intVal(json['calories'] ?? json['calories_burned'] ?? json['caloriesBurned']),
      hourlySteps: (json['hourly_steps'] ?? json['hourlySteps']) is List
          ? ((json['hourly_steps'] ?? json['hourlySteps']) as List<dynamic>)
              .map((e) => HourlySteps.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : [],
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
      return DateTime.parse(value.toString());
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
