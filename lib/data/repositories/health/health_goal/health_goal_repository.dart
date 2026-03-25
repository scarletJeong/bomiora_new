import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../models/health/health_goal_record_model.dart';

class HealthGoalRepository {
  /// GET 최신 목표 1건 (`mb_id` 기준)
  static Future<HealthGoalRecordModel?> fetchLatest(String mbId) async {
    try {
      final response = await ApiClient.get(ApiEndpoints.healthGoalLatest(mbId));
      if (response.statusCode != 200) return null;
      final body = json.decode(response.body) as Map<String, dynamic>?;
      if (body == null || body['success'] != true) return null;
      final data = body['data'];
      if (data is! Map<String, dynamic>) return null;
      return HealthGoalRecordModel.fromJson(data);
    } catch (e) {
      debugPrint('[HealthGoalRepository.fetchLatest] $e');
      return null;
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
        payload['measured_at'] = measuredAt.toUtc().toIso8601String();
      }

      final response = await ApiClient.post(
        ApiEndpoints.healthGoal,
        payload,
      );

      final body = json.decode(response.body) as Map<String, dynamic>?;
      final ok =
          (response.statusCode == 200 || response.statusCode == 201) &&
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
        message: e.toString(),
      );
    }
  }
}

class HealthGoalRegisterResult {
  final bool success;
  final String? message;
  final int? weightRecordId;

  const HealthGoalRegisterResult({
    required this.success,
    this.message,
    this.weightRecordId,
  });
}
