import 'dart:convert';
import 'dart:io';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../models/health/weight/weight_record_model.dart';

class WeightRepository {
  // 이미지 파일 업로드 (새로 추가)
  static Future<String?> uploadImage(dynamic imageFile) async {
    try {
      print('🔍 [DEBUG] 이미지 업로드 시작');
      print('📁 [DEBUG] 파일 타입: ${imageFile.runtimeType}');
      
      final response = await ApiClient.uploadFile('/api/health/weight/upload-image', imageFile);
      
      print('📡 [DEBUG] 응답 상태: ${response.statusCode}');
      print('📄 [DEBUG] 응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // 상대 URL을 절대 URL로 변환
          String relativeUrl = data['url'];
          String baseUrl = ApiClient.baseUrl;
          String fullUrl = '$baseUrl$relativeUrl';
          print('✅ [DEBUG] 업로드 성공: $fullUrl');
          return fullUrl; // 완전한 서버 URL 반환
        }
      }
      
      print('❌ [DEBUG] 이미지 업로드 실패: ${response.statusCode}');
      print('📄 [DEBUG] 오류 응답: ${response.body}');
      return null;
    } catch (e) {
      print('💥 [DEBUG] 이미지 업로드 오류: $e');
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
      
      print('체중 기록 추가 실패: ${response.statusCode}');
      return false;
    } catch (e) {
      print('체중 기록 추가 오류: $e');
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
      
      print('체중 기록 수정 실패: ${response.statusCode}');
      return false;
    } catch (e) {
      print('체중 기록 수정 오류: $e');
      return false;
    }
  }

  // 체중 기록 목록 조회
  static Future<List<WeightRecord>> getWeightRecords(String mbId) async {
    try {
      final response = await ApiClient.get('${ApiEndpoints.weightRecords}?mb_id=$mbId');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> records = data['data'];
          return records.map((json) => WeightRecord.fromJson(json)).toList();
        }
      }
      
      print('체중 기록 조회 실패: ${response.statusCode}');
      return [];
    } catch (e) {
      print('체중 기록 조회 오류: $e');
      return [];
    }
  }

  // 체중 기록 삭제
  static Future<bool> deleteWeightRecord(int recordId) async {
    try {
      final response = await ApiClient.delete('${ApiEndpoints.weightRecords}/$recordId');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      
      print('체중 기록 삭제 실패: ${response.statusCode}');
      return false;
    } catch (e) {
      print('체중 기록 삭제 오류: $e');
      return false;
    }
  }

  // 최신 체중 기록 조회
  static Future<WeightRecord?> getLatestWeightRecord(String mbId) async {
    try {
      final response = await ApiClient.get('${ApiEndpoints.weightRecords}/latest?mb_id=$mbId');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return WeightRecord.fromJson(data['data']);
        }
      }
      
      print('최신 체중 기록 조회 실패: ${response.statusCode}');
      return null;
    } catch (e) {
      print('최신 체중 기록 조회 오류: $e');
      return null;
    }
  }
}