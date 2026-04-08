import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/health/steps/steps_record_model.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';

class StepsRepository {
  static String get _baseUrl => ApiClient.baseUrl;

  static Map<String, dynamic>? _tryDecodeObject(String body) {
    final t = body.trim();
    if (t.isEmpty || !(t.startsWith('{') || t.startsWith('['))) return null;
    try {
      final decoded = json.decode(t);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  // 오늘의 걸음수 기록 가져오기
  static Future<StepsRecord?> getTodayStepsRecord(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/steps/today/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = _tryDecodeObject(response.body);
        if (data != null) {
          return StepsRecord.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      print('오늘의 걸음수 기록 가져오기 오류: $e');
      return null;
    }
  }

  /// 특정 날짜 일별 총 걸음 — `/api/steps/daily-total` (mb_id: VARCHAR 지원)
  static Future<StepsRecord?> getStepsRecordByMbId(String mbId, DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final response = await ApiClient.get(
        ApiEndpoints.stepsDailyTotal(mbId: mbId, dateYyyyMmDd: dateStr),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final root = _tryDecodeObject(response.body);
      if (root == null) return null;

      if (root['success'] == true && root['data'] is Map) {
        final data = Map<String, dynamic>.from(root['data'] as Map);
        return StepsRecord.fromJson(data);
      }

      // 레거시: 본문이 곧바로 레코드 객체인 경우
      if (root['total_steps'] != null || root['totalSteps'] != null) {
        return StepsRecord.fromJson(root);
      }

      return null;
    } catch (e) {
      print('걸음수 기록 가져오기 오류: $e');
      return null;
    }
  }

  /// 하위 호환: 숫자 userId 기반 호출
  static Future<StepsRecord?> getStepsRecordByDate(int userId, DateTime date) {
    return getStepsRecordByMbId('$userId', date);
  }

  /// `bm_steps` 일자별 합계 — 주간 차트용 (`GET /api/steps/daily-range`)
  static Future<Map<String, int>> getStepsDailyRange(
    String mbId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final s = DateTime(start.year, start.month, start.day);
      final e = DateTime(end.year, end.month, end.day);
      final ss = s.toIso8601String().split('T')[0];
      final ee = e.toIso8601String().split('T')[0];
      final response = await ApiClient.get(
        ApiEndpoints.stepsDailyRange(mbId: mbId, startYyyyMmDd: ss, endYyyyMmDd: ee),
      );
      if (response.statusCode != 200) return {};
      final root = _tryDecodeObject(response.body);
      if (root == null) return {};
      if (root['success'] != true || root['data'] is! Map) return {};
      final data = Map<String, dynamic>.from(root['data'] as Map);
      final days = data['days'];
      if (days is! List) return {};
      final out = <String, int>{};
      for (final item in days) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final d = m['date']?.toString();
        if (d == null || d.isEmpty) continue;
        final key = d.length >= 10 ? d.substring(0, 10) : d;
        final steps = m['total_steps'] ?? m['totalSteps'];
        out[key] = steps is num ? steps.round() : int.tryParse(steps?.toString() ?? '') ?? 0;
      }
      return out;
    } catch (e) {
      print('기간별 걸음 조회 오류: $e');
      return {};
    }
  }

  /// 연도별 월 합계 12개 (`GET /api/steps/monthly-totals`)
  static Future<List<int>> getStepsMonthlyTotalsForYear(String mbId, int year) async {
    try {
      final response = await ApiClient.get(
        ApiEndpoints.stepsMonthlyTotals(mbId: mbId, year: year),
      );
      if (response.statusCode != 200) return List<int>.filled(12, 0);
      final root = _tryDecodeObject(response.body);
      if (root == null) return List<int>.filled(12, 0);
      if (root['success'] != true || root['data'] is! Map) return List<int>.filled(12, 0);
      final data = Map<String, dynamic>.from(root['data'] as Map);
      final months = data['months'];
      final out = List<int>.filled(12, 0);
      if (months is List) {
        for (final item in months) {
          if (item is! Map) continue;
          final m = Map<String, dynamic>.from(item);
          final mi = m['month'];
          final month = mi is num ? mi.round() : int.tryParse(mi?.toString() ?? '') ?? 0;
          if (month < 1 || month > 12) continue;
          final ts = m['total_steps'] ?? m['totalSteps'];
          out[month - 1] = ts is num ? ts.round() : int.tryParse(ts?.toString() ?? '') ?? 0;
        }
      }
      return out;
    } catch (e) {
      print('월별 걸음 조회 오류: $e');
      return List<int>.filled(12, 0);
    }
  }

  // 걸음수 기록 저장
  static Future<bool> saveStepsRecord(StepsRecord record) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/steps'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(record.toJson()),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('걸음수 기록 저장 오류: $e');
      return false;
    }
  }

  // 걸음수 기록 업데이트
  static Future<bool> updateStepsRecord(StepsRecord record) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/steps/${record.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(record.toJson()),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('걸음수 기록 업데이트 오류: $e');
      return false;
    }
  }

  // 걸음수 통계 가져오기 (mb_id 기반; 비숫자 mb_id는 0 통계 반환)
  static Future<StepsStatistics?> getStepsStatisticsByMbId(String mbId) async {
    final userId = int.tryParse(mbId.trim());
    if (userId == null) {
      return StepsStatistics(
        todaySteps: 0,
        yesterdaySteps: 0,
        weeklyAverage: 0,
        monthlyAverage: 0,
        stepsDifference: 0,
        distanceDifference: 0.0,
        caloriesDifference: 0,
      );
    }
    return getStepsStatistics(userId);
  }

  // 걸음수 통계 가져오기 (기존 숫자 userId)
  static Future<StepsStatistics?> getStepsStatistics(int userId) async {
    try {
      final response = await ApiClient.get(ApiEndpoints.stepsStatistics(userId));

      if (response.statusCode != 200) {
        return null;
      }

      final data = _tryDecodeObject(response.body);
      if (data == null) return null;

      return StepsStatistics.fromJson(data);
    } catch (e) {
      print('걸음수 통계 가져오기 오류: $e');
      return null;
    }
  }

  // 주간 걸음수 데이터 가져오기
  static Future<List<StepsRecord>> getWeeklyStepsRecords(int userId, DateTime startDate) async {
    try {
      final startDateStr = startDate.toIso8601String().split('T')[0];

      final response = await http.get(
        Uri.parse('$_baseUrl/api/steps/weekly/$userId?startDate=$startDateStr'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List<dynamic>) {
          return decoded
              .map((item) => StepsRecord.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('주간 걸음수 데이터 가져오기 오류: $e');
      return [];
    }
  }

  // 월간 걸음수 데이터 가져오기
  static Future<List<StepsRecord>> getMonthlyStepsRecords(int userId, DateTime month) async {
    try {
      final year = month.year;
      final monthNum = month.month;

      final response = await http.get(
        Uri.parse('$_baseUrl/api/steps/monthly/$userId?year=$year&month=$monthNum'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List<dynamic>) {
          return decoded
              .map((item) => StepsRecord.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('월간 걸음수 데이터 가져오기 오류: $e');
      return [];
    }
  }

  // 걸음수 기록 삭제
  static Future<bool> deleteStepsRecord(int recordId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/steps/$recordId'),
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 200;
    } catch (e) {
      print('걸음수 기록 삭제 오류: $e');
      return false;
    }
  }

  // 목표 걸음수 설정
  static Future<bool> setStepsGoal(int userId, int goalSteps) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/steps'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'goal_steps': goalSteps,
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('목표 걸음수 설정 오류: $e');
      return false;
    }
  }

  // 목표 걸음수 가져오기
  static Future<int?> getStepsGoal(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/steps/today/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = _tryDecodeObject(response.body);
        if (data != null && data['dailyGoal'] != null) {
          final v = data['dailyGoal'];
          if (v is int) return v;
          if (v is num) return v.round();
          return int.tryParse(v.toString());
        }
      }
      return null;
    } catch (e) {
      print('목표 걸음수 가져오기 오류: $e');
      return null;
    }
  }
}
