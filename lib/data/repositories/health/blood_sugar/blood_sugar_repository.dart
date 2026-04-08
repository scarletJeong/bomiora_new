import 'dart:convert';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../models/health/blood_sugar/blood_sugar_record_model.dart';

class BloodSugarRepository {
  // 사용자의 모든 혈당 기록 가져오기 (최적화: 한 번에 모든 데이터 로드)
  static Future<List<BloodSugarRecord>> getBloodSugarRecords(String userId) async {
    try {
      final response = await ApiClient.get('${ApiEndpoints.bloodSugarRecords}?mb_id=$userId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> records = data['data'];
          return records.map((json) => BloodSugarRecord.fromJson(json)).toList();
        } else if (data is List) {
          return data.map((json) => BloodSugarRecord.fromJson(json)).toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<BloodSugarRecord?> getLatestBloodSugarRecord(String userId) async {
    try {
      final response = await ApiClient.get('${ApiEndpoints.bloodSugarRecords}/latest?mb_id=$userId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          return BloodSugarRecord.fromJson(data['data']);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> addBloodSugarRecord(BloodSugarRecord record) async {
    try {
      final response = await ApiClient.post(
        ApiEndpoints.bloodSugarRecords,
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

  static Future<bool> updateBloodSugarRecord(BloodSugarRecord record) async {
    try {
      if (record.id == null) {
        throw Exception('수정할 기록의 ID가 없습니다');
      }

      final response = await ApiClient.put(
        '${ApiEndpoints.bloodSugarRecords}/${record.id}',
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

  static Future<bool> deleteBloodSugarRecord(int recordId) async {
    try {
      final response = await ApiClient.delete(
        '${ApiEndpoints.bloodSugarRecords}/$recordId',
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

  static Future<List<BloodSugarRecord>> getBloodSugarRecordsByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final response = await ApiClient.get(
        '${ApiEndpoints.bloodSugarRecords}/range?mb_id=$userId&start_date=${startDate.toIso8601String()}&end_date=${endDate.toIso8601String()}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> records = data['data'];
          return records.map((json) => BloodSugarRecord.fromJson(json)).toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }
}
