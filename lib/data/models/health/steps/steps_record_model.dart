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
  });

  factory StepsRecord.fromJson(Map<String, dynamic> json) {
    return StepsRecord(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      date: _parseDateTime(json['date']),
      totalSteps: json['total_steps'] ?? 0,
      distance: (json['distance'] ?? 0.0).toDouble(),
      calories: json['calories'] ?? 0,
      hourlySteps: (json['hourly_steps'] as List<dynamic>?)
          ?.map((item) => HourlySteps.fromJson(item))
          .toList() ?? [],
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    final parsed = DateTime.parse(value.toString());
    if (parsed.isUtc) {
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
    return parsed;
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

  factory HourlySteps.fromJson(Map<String, dynamic> json) {
    return HourlySteps(
      hour: json['hour'] ?? 0,
      steps: json['steps'] ?? 0,
      distance: (json['distance'] ?? 0.0).toDouble(),
      calories: json['calories'] ?? 0,
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

// 걸음수 통계 모델
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

  factory StepsStatistics.fromJson(Map<String, dynamic> json) {
    return StepsStatistics(
      todaySteps: json['today_steps'] ?? 0,
      yesterdaySteps: json['yesterday_steps'] ?? 0,
      weeklyAverage: json['weekly_average'] ?? 0,
      monthlyAverage: json['monthly_average'] ?? 0,
      stepsDifference: json['steps_difference'] ?? 0,
      distanceDifference: (json['distance_difference'] ?? 0.0).toDouble(),
      caloriesDifference: json['calories_difference'] ?? 0,
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
