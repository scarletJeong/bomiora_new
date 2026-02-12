import 'dart:convert';
import '../models/event/event_model.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';

class EventService {
  static String _withNoCacheParam(String endpoint) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return endpoint.contains('?') ? '$endpoint&_ts=$ts' : '$endpoint?_ts=$ts';
  }

  static const Map<String, String> _noCacheHeaders = {
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache',
  };

  static List<EventModel> _parseEventList(dynamic responseData) {
    if (responseData is Map && responseData['success'] == true && responseData['data'] != null) {
      final dataList = responseData['data'];
      if (dataList is List) {
        return dataList
            .whereType<Map>()
            .map((json) => EventModel.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      }
    }
    return [];
  }

  /// 진행중인 이벤트 목록 조회
  static Future<List<EventModel>> getActiveEvents() async {
    try {
      final response = await ApiClient.get(
        _withNoCacheParam(ApiEndpoints.getActiveEvents),
        additionalHeaders: _noCacheHeaders,
      );

      // 웹 환경 캐시로 304가 올 수 있음: 목록 로드 실패로 간주하지 않고 빈 목록 처리
      if (response.statusCode == 304 || response.body.trim().isEmpty) {
        return [];
      }

      final responseData = json.decode(response.body);
      return _parseEventList(responseData);
    } catch (e) {
      throw Exception('진행중인 이벤트 목록 조회 실패: $e');
    }
  }

  /// 종료된 이벤트 목록 조회
  static Future<List<EventModel>> getEndedEvents() async {
    try {
      final response = await ApiClient.get(
        _withNoCacheParam(ApiEndpoints.getEndedEvents),
        additionalHeaders: _noCacheHeaders,
      );

      if (response.statusCode == 304 || response.body.trim().isEmpty) {
        return [];
      }

      final responseData = json.decode(response.body);
      return _parseEventList(responseData);
    } catch (e) {
      throw Exception('종료된 이벤트 목록 조회 실패: $e');
    }
  }

  /// 이벤트 상세 조회
  static Future<EventModel?> getEventDetail(int wrId) async {
    try {
      final response = await ApiClient.get(
        _withNoCacheParam('${ApiEndpoints.getEventDetail}/$wrId'),
        additionalHeaders: _noCacheHeaders,
      );

      if (response.statusCode == 304 || response.body.trim().isEmpty) {
        return null;
      }

      final responseData = json.decode(response.body);

      if (responseData is Map && responseData['success'] == true && responseData['data'] != null) {
        final data = responseData['data'];
        if (data is Map) {
          return EventModel.fromJson(Map<String, dynamic>.from(data));
        }
      }

      return null;
    } catch (e) {
      throw Exception('이벤트 상세 조회 실패: $e');
    }
  }
}
