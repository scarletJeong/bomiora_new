import 'dart:convert';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../models/health/menstrual_cycle/menstrual_cycle_model.dart';

class MenstrualCycleRepository {
  // 생리주기 기록 추가
  static Future<bool> addMenstrualCycleRecord(MenstrualCycleRecord record) async {
    try {
      final response = await ApiClient.post(
        ApiEndpoints.menstrualCycleRecords,
        record.toJson(),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  // 생리주기 기록 수정
  static Future<bool> updateMenstrualCycleRecord(MenstrualCycleRecord record) async {
    try {
      if (record.id == null) {
        throw Exception('수정할 기록의 ID가 없습니다');
      }
      
      final response = await ApiClient.put(
        '${ApiEndpoints.menstrualCycleRecords}/${record.id}',
        record.toJson(),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  // 생리주기 기록 목록 조회
  static Future<List<MenstrualCycleRecord>> getMenstrualCycleRecords(String mbId) async {
    try {
      final response = await ApiClient.get('${ApiEndpoints.menstrualCycleRecords}?mb_id=$mbId');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> records = data['data'];
          return records.map((json) => MenstrualCycleRecord.fromJson(json)).toList();
        }
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  // 생리주기 기록 삭제
  static Future<bool> deleteMenstrualCycleRecord(int recordId) async {
    try {
      final response = await ApiClient.delete('${ApiEndpoints.menstrualCycleRecords}/$recordId');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  // 최신 생리주기 기록 조회
  static Future<MenstrualCycleRecord?> getLatestMenstrualCycleRecord(String mbId) async {
    try {
      final response = await ApiClient.get('${ApiEndpoints.menstrualCycleRecords}/latest?mb_id=$mbId');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final payload = data['data'] ?? data['record'];
        if (data['success'] == true && payload is Map<String, dynamic>) {
          return MenstrualCycleRecord.fromJson(payload);
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  // 생리주기 통계 조회
  static Future<Map<String, dynamic>?> getMenstrualCycleStats(String mbId) async {
    try {
      final response = await ApiClient.get('${ApiEndpoints.menstrualCycleRecords}/stats?mb_id=$mbId');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
}
