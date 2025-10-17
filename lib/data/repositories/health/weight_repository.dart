import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../models/health/weight_record_model.dart';

class WeightRepository {
  // 사용자의 모든 체중 기록 가져오기
  static Future<List<WeightRecord>> getWeightRecords(String userId) async {
    try {
      final response = await ApiClient.get('${ApiEndpoints.weightRecords}?mb_id=$userId');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // 응답 구조에 따라 처리
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> records = data['data'];
          return records.map((json) => WeightRecord.fromJson(json)).toList();
        } else if (data is List) {
          // 배열로 직접 반환되는 경우
          return data.map((json) => WeightRecord.fromJson(json)).toList();
        }
      }
      
      return [];
    } catch (e) {
      print('체중 기록 가져오기 오류: $e');
      return [];
    }
  }

  // 최신 체중 기록 하나만 가져오기
  static Future<WeightRecord?> getLatestWeightRecord(String userId) async {
    try {
      print('🔍 [DEBUG] API 호출: ${ApiEndpoints.weightRecords}/latest?mb_id=$userId');
      final response = await ApiClient.get('${ApiEndpoints.weightRecords}/latest?mb_id=$userId');
      
      print('📡 [DEBUG] 응답 상태: ${response.statusCode}');
      print('📦 [DEBUG] 응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        print('✅ [DEBUG] 파싱된 데이터: $data');
        
        if (data['success'] == true && data['data'] != null) {
          return WeightRecord.fromJson(data['data']);
        }
      }
      
      return null;
    } catch (e) {
      print('최신 체중 기록 가져오기 오류: $e');
      return null;
    }
  }

  // 체중 기록 추가
  static Future<bool> addWeightRecord(WeightRecord record) async {
    try {
      print('🔍 [DEBUG] 체중 기록 추가 시작');
      print('📤 [DEBUG] 요청 데이터: ${record.toJson()}');
      
      final response = await ApiClient.post(
        ApiEndpoints.weightRecords,
        record.toJson(),
      );
      
      print('📡 [DEBUG] 응답 상태: ${response.statusCode}');
      print('📦 [DEBUG] 응답 본문: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        print('✅ [DEBUG] 성공 여부: ${data['success']}');
        return data['success'] == true;
      }
      
      print('❌ [DEBUG] 응답 코드 실패: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ 체중 기록 추가 오류: $e');
      return false;
    }
  }

  // 체중 기록 수정
  static Future<bool> updateWeightRecord(WeightRecord record) async {
    try {
      if (record.id == null) {
        throw Exception('수정할 기록의 ID가 없습니다');
      }
      
      final response = await ApiClient.put(
        '${ApiEndpoints.weightRecords}/${record.id}',
        record.toJson(),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      
      return false;
    } catch (e) {
      print('체중 기록 수정 오류: $e');
      return false;
    }
  }

  // 체중 기록 삭제
  static Future<bool> deleteWeightRecord(int recordId) async {
    try {
      final response = await ApiClient.delete(
        '${ApiEndpoints.weightRecords}/$recordId',
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      
      return false;
    } catch (e) {
      print('체중 기록 삭제 오류: $e');
      return false;
    }
  }

  // 날짜 범위로 체중 기록 조회
  static Future<List<WeightRecord>> getWeightRecordsByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final response = await ApiClient.get(
        '${ApiEndpoints.weightRecords}/range?mb_id=$userId&start_date=${startDate.toIso8601String()}&end_date=${endDate.toIso8601String()}',
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> records = data['data'];
          return records.map((json) => WeightRecord.fromJson(json)).toList();
        }
      }
      
      return [];
    } catch (e) {
      print('날짜 범위 체중 기록 조회 오류: $e');
      return [];
    }
  }
}

