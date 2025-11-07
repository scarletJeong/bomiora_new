import 'dart:convert';
import '../models/event/event_model.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';

class EventService {
  /// 진행중인 이벤트 목록 조회
  static Future<List<EventModel>> getActiveEvents() async {
    try {
      final response = await ApiClient.get(ApiEndpoints.getActiveEvents);
      final responseData = json.decode(response.body);

      if (responseData['success'] == true && responseData['data'] != null) {
        final List<dynamic> dataList = responseData['data'];
        return dataList.map((json) => EventModel.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      throw Exception('진행중인 이벤트 목록 조회 실패: $e');
    }
  }

  /// 종료된 이벤트 목록 조회
  static Future<List<EventModel>> getEndedEvents() async {
    try {
      final response = await ApiClient.get(ApiEndpoints.getEndedEvents);
      final responseData = json.decode(response.body);

      if (responseData['success'] == true && responseData['data'] != null) {
        final List<dynamic> dataList = responseData['data'];
        return dataList.map((json) => EventModel.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      throw Exception('종료된 이벤트 목록 조회 실패: $e');
    }
  }

  /// 이벤트 상세 조회
  static Future<EventModel?> getEventDetail(int wrId) async {
    try {
      final response = await ApiClient.get('${ApiEndpoints.getEventDetail}/$wrId');
      final responseData = json.decode(response.body);

      if (responseData['success'] == true && responseData['data'] != null) {
        return EventModel.fromJson(responseData['data']);
      }

      return null;
    } catch (e) {
      throw Exception('이벤트 상세 조회 실패: $e');
    }
  }
}
