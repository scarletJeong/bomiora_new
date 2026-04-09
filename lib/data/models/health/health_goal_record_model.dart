import '../../../core/utils/api_date_time.dart';

/// 목표설정 이력 (`bm_health_goal_records`) — API 응답 파싱용
class HealthGoalRecordModel {
  final int? goalRecordId;
  final String? mbId;
  final double? currentWeight;
  final double? targetWeight;
  final int? dailyStepGoal;
  final int? weightRecordId;
  final DateTime? createdAt;

  const HealthGoalRecordModel({
    this.goalRecordId,
    this.mbId,
    this.currentWeight,
    this.targetWeight,
    this.dailyStepGoal,
    this.weightRecordId,
    this.createdAt,
  });

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }

  factory HealthGoalRecordModel.fromJson(Map<String, dynamic> json) {
    return HealthGoalRecordModel(
      goalRecordId: _parseInt(json['goalRecordId'] ?? json['goal_record_id']),
      mbId: (json['mbId'] ?? json['mb_id'])?.toString(),
      currentWeight: _parseDouble(json['currentWeight'] ?? json['current_weight']),
      targetWeight: _parseDouble(json['targetWeight'] ?? json['target_weight']),
      dailyStepGoal: _parseInt(json['dailyStepGoal'] ?? json['daily_step_goal']),
      weightRecordId: _parseInt(
          json['weightRecordId'] ?? json['weight_record_id']),
      createdAt: ApiDateTime.parseInstant(json['createdAt'] ?? json['created_at']),
    );
  }
}
