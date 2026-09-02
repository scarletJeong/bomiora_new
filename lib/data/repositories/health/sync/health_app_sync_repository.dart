import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../services/health_sync_snapshot.dart';

class HealthAppSyncResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? saved;

  const HealthAppSyncResult({
    required this.success,
    required this.message,
    this.saved,
  });

  bool get hasStoredData {
    final map = saved;
    if (map == null) return false;
    return map.values.any((v) => v != null);
  }
}

/// 건강앱에서 읽은 오늘 값을 Node `POST /api/health/sync` 로 저장.
class HealthAppSyncRepository {
  static String ymd(DateTime date) {
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String iso(DateTime date) => date.toUtc().toIso8601String();

  static Future<HealthAppSyncResult> persistToday({
    required String mbId,
    required String provider,
    required HealthSyncSnapshot snapshot,
    DateTime? date,
  }) async {
    final id = mbId.trim();
    if (id.isEmpty) {
      return const HealthAppSyncResult(
        success: false,
        message: '로그인 정보가 없습니다.',
      );
    }

    final payload = <String, dynamic>{
      'mb_id': id,
      'provider': provider,
      'date': ymd(date ?? DateTime.now()),
    };

    final activity = snapshot.activity;
    if (activity.hasData) {
      payload['steps'] = {
        if (activity.steps != null) 'total_steps': activity.steps,
        if (activity.distanceKm != null) 'distance_km': activity.distanceKm,
        if (activity.caloriesKcal != null)
          'calories': activity.caloriesKcal!.round(),
        if (activity.activeMinutes != null)
          'active_minutes': activity.activeMinutes,
        if (activity.intervals.isNotEmpty)
          'intervals': activity.intervals
              .take(200)
              .map(
                (i) => {
                  'interval_start': iso(i.start),
                  'interval_end': iso(i.end),
                  'steps': i.steps,
                  if (i.externalUid != null && i.externalUid!.isNotEmpty)
                    'external_uid': i.externalUid,
                },
              )
              .toList(),
      };
    }

    final body = snapshot.body;
    if (body?.weightKg != null && body!.weightKg! > 0) {
      payload['weight'] = {
        'weight': body.weightKg,
        if (body.bmi != null) 'bmi': body.bmi,
        if (body.measuredAt != null) 'measured_at': iso(body.measuredAt!),
      };
    }

    final sugar = snapshot.bloodGlucose;
    if (sugar?.valueMgDl != null && sugar!.valueMgDl! > 0) {
      payload['blood_sugar'] = {
        'blood_sugar': sugar.valueMgDl!.round(),
        'measurement_type': '평상시',
        if (sugar.measuredAt != null) 'measured_at': iso(sugar.measuredAt!),
      };
    }

    final bp = snapshot.bloodPressure;
    if (bp?.systolic != null &&
        bp!.systolic! > 0 &&
        bp.diastolic != null &&
        bp.diastolic! > 0) {
      payload['blood_pressure'] = {
        'systolic': bp.systolic,
        'diastolic': bp.diastolic,
        if (snapshot.latestHeartRate != null) 'pulse': snapshot.latestHeartRate,
        if (bp.measuredAt != null) 'measured_at': iso(bp.measuredAt!),
      };
    }

    if (snapshot.latestHeartRate != null && snapshot.latestHeartRate! > 0) {
      payload['heart_rate'] = {
        'heart_rate': snapshot.latestHeartRate,
        'status': snapshot.workouts.isNotEmpty ? '운동' : '일상',
        if (snapshot.workouts.isNotEmpty)
          'measured_at': iso(snapshot.workouts.first.startedAt),
      };
    }

    if (payload.length <= 3) {
      return const HealthAppSyncResult(
        success: true,
        message: '건강앱에서 저장할 오늘 측정값을 찾지 못했습니다.',
      );
    }

    try {
      final response = await ApiClient.post(ApiEndpoints.healthSync, payload);
      final decoded = json.decode(response.body);
      if (decoded is! Map) {
        return const HealthAppSyncResult(
          success: false,
          message: '건강 기록 저장 응답이 올바르지 않습니다.',
        );
      }
      final map = Map<String, dynamic>.from(decoded);
      final ok = (response.statusCode == 200 || response.statusCode == 201) &&
          map['success'] == true;
      final saved = map['data'] is Map
          ? Map<String, dynamic>.from(map['data'] as Map)['saved']
          : null;
      return HealthAppSyncResult(
        success: ok,
        message: (map['message'] ??
                (ok ? '건강앱 연동 데이터가 저장되었습니다.' : '건강앱 연동 저장에 실패했습니다.'))
            .toString(),
        saved: saved is Map ? Map<String, dynamic>.from(saved) : null,
      );
    } catch (e) {
      debugPrint('[HealthAppSyncRepository.persistToday] $e');
      return const HealthAppSyncResult(
        success: false,
        message: '건강 기록 저장 중 오류가 발생했습니다.',
      );
    }
  }
}
