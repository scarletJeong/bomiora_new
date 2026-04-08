import 'dart:convert';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../models/health/blood_pressure/blood_pressure_record_model.dart';

class BloodPressureRepository {
  static Future<List<BloodPressureRecord>> getBloodPressureRecords(String userId) async {
    try {
      final response = await ApiClient.get('${ApiEndpoints.bloodPressureRecords}?mb_id=$userId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> records = data['data'];
          return records.map((json) => BloodPressureRecord.fromJson(json)).toList();
        } else if (data is List) {
          return data.map((json) => BloodPressureRecord.fromJson(json)).toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<BloodPressureRecord?> getLatestBloodPressureRecord(String userId) async {
    try {
      final response = await ApiClient.get('${ApiEndpoints.bloodPressureRecords}/latest?mb_id=$userId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          return BloodPressureRecord.fromJson(data['data']);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> addBloodPressureRecord(BloodPressureRecord record) async {
    try {
      final response = await ApiClient.post(
        ApiEndpoints.bloodPressureRecords,
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

  static Future<bool> updateBloodPressureRecord(BloodPressureRecord record) async {
    try {
      if (record.id == null) {
        throw Exception('수정할 기록의 ID가 없습니다');
      }

      final response = await ApiClient.put(
        '${ApiEndpoints.bloodPressureRecords}/${record.id}',
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

  static Future<bool> deleteBloodPressureRecord(int recordId) async {
    try {
      final response = await ApiClient.delete(
        '${ApiEndpoints.bloodPressureRecords}/$recordId',
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

  static Future<List<BloodPressureRecord>> getBloodPressureRecordsByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final response = await ApiClient.get(
        '${ApiEndpoints.bloodPressureRecords}/range?mb_id=$userId&start_date=${startDate.toIso8601String()}&end_date=${endDate.toIso8601String()}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> records = data['data'];
          return records.map((json) => BloodPressureRecord.fromJson(json)).toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }
}
