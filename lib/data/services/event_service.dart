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
    if (responseData is! Map) return [];
    final map = Map<String, dynamic>.from(responseData);
    if (map['success'] != true) return [];

    final dataList = map['data'];
    if (dataList is! List) return [];

    final out = <EventModel>[];
    for (final row in dataList) {
      if (row is! Map) continue;
      try {
        out.add(EventModel.fromJson(Map<String, dynamic>.from(row)));
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  /// 진행중인 이벤트 목록 조회
  static Future<List<EventModel>> getActiveEvents() async {
    final path = _withNoCacheParam(ApiEndpoints.getActiveEvents);
    try {
      final response = await ApiClient.get(
        path,
        additionalHeaders: _noCacheHeaders,
      );

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
    final path = _withNoCacheParam(ApiEndpoints.getEndedEvents);
    try {
      final response = await ApiClient.get(
        path,
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
    final path = _withNoCacheParam('${ApiEndpoints.getEventDetail}/$wrId');
    try {
      final response = await ApiClient.get(
        path,
        additionalHeaders: _noCacheHeaders,
      );

      if (response.statusCode == 304 || response.body.trim().isEmpty) {
        return null;
      }

      final responseData = json.decode(response.body);
      if (responseData is Map &&
          responseData['success'] == true &&
          responseData['data'] is Map) {
        return EventModel.fromJson(
          Map<String, dynamic>.from(responseData['data'] as Map),
        );
      }
      return null;
    } catch (e) {
      throw Exception('이벤트 상세 조회 실패: $e');
    }
  }
}
