import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/health/steps/steps_record_model.dart';
import '../../../../core/network/api_client.dart';

class StepsRepository {
  // ApiClient의 동적 baseUrl 사용
  static String get _baseUrl => ApiClient.baseUrl;

  // 오늘의 걸음수 기록 가져오기
  static Future<StepsRecord?> getTodayStepsRecord(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/steps/today/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
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

  // 특정 날짜의 걸음수 기록 가져오기
  static Future<StepsRecord?> getStepsRecordByDate(int userId, DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final response = await http.get(
        Uri.parse('$_baseUrl/api/steps/date/$userId?date=$dateStr'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null) {
          return StepsRecord.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      print('걸음수 기록 가져오기 오류: $e');
      return null;
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

  // 걸음수 통계 가져오기
  static Future<StepsStatistics?> getStepsStatistics(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/steps/statistics/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null) {
          return StepsStatistics.fromJson(data);
        }
      }
      return null;
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
        final data = json.decode(response.body);
        if (data != null && data is List<dynamic>) {
          return (data as List)
              .map((item) => StepsRecord.fromJson(item))
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
        final data = json.decode(response.body);
        if (data != null && data is List<dynamic>) {
          return (data as List)
              .map((item) => StepsRecord.fromJson(item))
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
        final data = json.decode(response.body);
        if (data != null && data['dailyGoal'] != null) {
          return data['dailyGoal'];
        }
      }
      return null;
    } catch (e) {
      print('목표 걸음수 가져오기 오류: $e');
      return null;
    }
  }
}
