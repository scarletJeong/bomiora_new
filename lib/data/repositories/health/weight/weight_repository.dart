import 'dart:convert';
import 'dart:io';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../models/health/weight/weight_record_model.dart';

class WeightRepository {
  // 이미지 파일 업로드 (새로 추가)
  static Future<String?> uploadImage(dynamic imageFile) async {
    try {
      final response = await ApiClient.uploadFile('/api/health/weight/upload-image', imageFile);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // 상대 URL을 절대 URL로 변환
          String relativeUrl = data['url'];
          String baseUrl = ApiClient.baseUrl;
          String fullUrl = '$baseUrl$relativeUrl';
          return fullUrl; // 완전한 서버 URL 반환
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 체중 기록 추가
  static Future<bool> addWeightRecord(WeightRecord record) async {
    try {
      final response = await ApiClient.post(
        ApiEndpoints.weightRecords,
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
      return false;
    }
  }

  // 체중 기록 목록 조회 (최적화: 한 번에 모든 데이터 로드)
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

      return [];
    } catch (e) {
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

      return false;
    } catch (e) {
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

      return null;
    } catch (e) {
      return null;
    }
  }
}