import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../models/health/heart_rate/heart_rate_record_model.dart';

class HeartRateRepository {
  static Future<List<HeartRateRecord>> getHeartRateRecords(String userId) async {
    try {
      final response = await ApiClient.get(
        '${ApiEndpoints.heartRateRecords}?mb_id=$userId',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final records = data['data'] as List<dynamic>;
          return records
              .map((e) => HeartRateRecord.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<HeartRateRecord?> getLatestHeartRateRecord(String userId) async {
    try {
      final response = await ApiClient.get(
        '${ApiEndpoints.heartRateRecords}/latest?mb_id=$userId',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return HeartRateRecord.fromJson(data['data'] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
