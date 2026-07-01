/// Health Connect / HealthKit에서 읽은 오늘 스냅샷 (미리보기·향후 서버 동기화용)
class HealthSyncSnapshot {
  final HealthActivitySnapshot activity;
  final List<HealthWorkoutSnapshot> workouts;
  final int? latestHeartRate;
  final HealthBodySnapshot? body;
  final HealthBloodPressureSnapshot? bloodPressure;
  final HealthBloodGlucoseSnapshot? bloodGlucose;
  final List<HealthNutritionSnapshot> nutrition;
  final List<HealthMenstruationSnapshot> menstruation;

  const HealthSyncSnapshot({
    required this.activity,
    this.workouts = const [],
    this.latestHeartRate,
    this.body,
    this.bloodPressure,
    this.bloodGlucose,
    this.nutrition = const [],
    this.menstruation = const [],
  });

  bool get hasAnyData =>
      activity.hasData ||
      workouts.isNotEmpty ||
      latestHeartRate != null ||
      body != null ||
      bloodPressure != null ||
      bloodGlucose != null ||
      nutrition.isNotEmpty ||
      menstruation.isNotEmpty;
}

class HealthActivitySnapshot {
  final int? steps;
  final double? distanceKm;
  final int? activeMinutes;
  final double? caloriesKcal;

  const HealthActivitySnapshot({
    this.steps,
    this.distanceKm,
    this.activeMinutes,
    this.caloriesKcal,
  });

  bool get hasData =>
      (steps != null && steps! > 0) ||
      (distanceKm != null && distanceKm! > 0) ||
      (activeMinutes != null && activeMinutes! > 0) ||
      (caloriesKcal != null && caloriesKcal! > 0);
}

class HealthWorkoutSnapshot {
  final String typeLabel;
  final int durationMinutes;
  final int? avgHeartRate;
  final int? maxHeartRate;
  final double? speedKmh;
  final double? caloriesKcal;
  final DateTime startedAt;

  const HealthWorkoutSnapshot({
    required this.typeLabel,
    required this.durationMinutes,
    this.avgHeartRate,
    this.maxHeartRate,
    this.speedKmh,
    this.caloriesKcal,
    required this.startedAt,
  });
}

class HealthBodySnapshot {
  final double? weightKg;
  final double? bmi;
  final DateTime? measuredAt;

  const HealthBodySnapshot({
    this.weightKg,
    this.bmi,
    this.measuredAt,
  });
}

class HealthBloodPressureSnapshot {
  final int? systolic;
  final int? diastolic;
  final DateTime? measuredAt;

  const HealthBloodPressureSnapshot({
    this.systolic,
    this.diastolic,
    this.measuredAt,
  });
}

class HealthBloodGlucoseSnapshot {
  final double? valueMgDl;
  final DateTime? measuredAt;

  const HealthBloodGlucoseSnapshot({
    this.valueMgDl,
    this.measuredAt,
  });
}

class HealthNutritionSnapshot {
  final String? mealName;
  final String? mealType;
  final double? caloriesKcal;
  final double? proteinG;
  final double? fatG;
  final double? carbsG;
  final DateTime? recordedAt;

  const HealthNutritionSnapshot({
    this.mealName,
    this.mealType,
    this.caloriesKcal,
    this.proteinG,
    this.fatG,
    this.carbsG,
    this.recordedAt,
  });
}

class HealthMenstruationSnapshot {
  final DateTime date;
  final String? flowLabel;

  const HealthMenstruationSnapshot({
    required this.date,
    this.flowLabel,
  });
}
