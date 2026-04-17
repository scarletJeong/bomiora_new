import 'dart:convert';

import 'package:flutter/foundation.dart';

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

  static String _fullUrl(String endpoint) => '${ApiClient.baseUrl}$endpoint';

  static String _bodyPreview(String body, {int max = 900}) {
    final t = body.trim();
    if (t.isEmpty) return '(empty)';
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…(len=${t.length})';
  }

  static List<EventModel> _parseEventList(
    dynamic responseData, {
    required String logLabel,
  }) {
    if (responseData is! Map) {
      debugPrint(
        '[EventService][$logLabel] parse fail: root is ${responseData.runtimeType}, expected Map',
      );
      return [];
    }
    final map = Map<String, dynamic>.from(responseData);
    final success = map['success'];
    if (success != true) {
      debugPrint(
        '[EventService][$logLabel] parse: success=$success message=${map['message'] ?? map['error'] ?? map['msg']}',
      );
      return [];
    }
    final dataList = map['data'];
    if (dataList == null) {
      debugPrint('[EventService][$logLabel] parse: data is null');
      return [];
    }
    if (dataList is! List) {
      debugPrint(
        '[EventService][$logLabel] parse: data is ${dataList.runtimeType}, expected List',
      );
      return [];
    }
    final out = <EventModel>[];
    for (var i = 0; i < dataList.length; i++) {
      final row = dataList[i];
      if (row is! Map) {
        debugPrint(
          '[EventService][$logLabel] parse: skip index $i, not Map (${row.runtimeType})',
        );
        continue;
      }
      try {
        out.add(EventModel.fromJson(Map<String, dynamic>.from(row)));
      } catch (e, st) {
        debugPrint('[EventService][$logLabel] parse: row $i fromJson error: $e');
        debugPrint('$st');
      }
    }
    return out;
  }

  static void _logParsedList(String logLabel, List<EventModel> list) {
    debugPrint('[EventService][$logLabel] parsed count=${list.length}');
    for (final e in list) {
      debugPrint(
        '[EventService][$logLabel]  wr_id=${e.wrId} wr_num=${e.wrNum} '
        'ca=${e.caName} subject=${e.wrSubject} wr_1=${e.wr1} wr_2=${e.wr2} '
        'isActive=${e.isActive} datetime=${e.wrDatetime}',
      );
    }
  }

  /// 진행중인 이벤트 목록 조회
  static Future<List<EventModel>> getActiveEvents() async {
    const label = 'active';
    final path = _withNoCacheParam(ApiEndpoints.getActiveEvents);
    try {
      debugPrint('[EventService][$label] GET ${_fullUrl(path)}');
      final response = await ApiClient.get(
        path,
        additionalHeaders: _noCacheHeaders,
      );

      debugPrint(
        '[EventService][$label] status=${response.statusCode} bodyLen=${response.body.length}',
      );

      // 웹 환경 캐시로 304가 올 수 있음: 목록 로드 실패로 간주하지 않고 빈 목록 처리
      if (response.statusCode == 304 || response.body.trim().isEmpty) {
        debugPrint(
          '[EventService][$label] ⚠️ 304 or empty body → []. preview=${_bodyPreview(response.body, max: 200)}',
        );
        return [];
      }

      debugPrint('[EventService][$label] body preview: ${_bodyPreview(response.body)}');

      final responseData = json.decode(response.body);
      final list = _parseEventList(responseData, logLabel: label);
      _logParsedList(label, list);
      return list;
    } catch (e, st) {
      debugPrint('[EventService][$label] exception: $e');
      debugPrint('$st');
      throw Exception('진행중인 이벤트 목록 조회 실패: $e');
    }
  }

  /// 종료된 이벤트 목록 조회
  static Future<List<EventModel>> getEndedEvents() async {
    const label = 'ended';
    final path = _withNoCacheParam(ApiEndpoints.getEndedEvents);
    try {
      debugPrint('[EventService][$label] GET ${_fullUrl(path)}');
      final response = await ApiClient.get(
        path,
        additionalHeaders: _noCacheHeaders,
      );

      debugPrint(
        '[EventService][$label] status=${response.statusCode} bodyLen=${response.body.length}',
      );

      if (response.statusCode == 304 || response.body.trim().isEmpty) {
        debugPrint(
          '[EventService][$label] ⚠️ 304 or empty body → []. preview=${_bodyPreview(response.body, max: 200)}',
        );
        return [];
      }

      debugPrint('[EventService][$label] body preview: ${_bodyPreview(response.body)}');

      final responseData = json.decode(response.body);
      final list = _parseEventList(responseData, logLabel: label);
      _logParsedList(label, list);
      return list;
    } catch (e, st) {
      debugPrint('[EventService][$label] exception: $e');
      debugPrint('$st');
      throw Exception('종료된 이벤트 목록 조회 실패: $e');
    }
  }

  /// 이벤트 상세 조회
  static Future<EventModel?> getEventDetail(int wrId) async {
    const label = 'detail';
    final path = _withNoCacheParam('${ApiEndpoints.getEventDetail}/$wrId');
    try {
      debugPrint('[EventService][$label] GET ${_fullUrl(path)}');
      final response = await ApiClient.get(
        path,
        additionalHeaders: _noCacheHeaders,
      );

      debugPrint(
        '[EventService][$label] wrId=$wrId status=${response.statusCode} bodyLen=${response.body.length}',
      );

      if (response.statusCode == 304 || response.body.trim().isEmpty) {
        debugPrint(
          '[EventService][$label] ⚠️ 304 or empty → null. preview=${_bodyPreview(response.body, max: 200)}',
        );
        return null;
      }

      debugPrint('[EventService][$label] body preview: ${_bodyPreview(response.body)}');

      final responseData = json.decode(response.body);

      if (responseData is Map &&
          responseData['success'] == true &&
          responseData['data'] != null) {
        final data = responseData['data'];
        if (data is Map) {
          final m = EventModel.fromJson(Map<String, dynamic>.from(data));
          debugPrint(
            '[EventService][$label] ok wr_id=${m.wrId} subject=${m.wrSubject} wr_1=${m.wr1} wr_2=${m.wr2} isActive=${m.isActive}',
          );
          return m;
        }
      }

      debugPrint('[EventService][$label] parse miss success/data shape');
      return null;
    } catch (e, st) {
      debugPrint('[EventService][$label] exception: $e');
      debugPrint('$st');
      throw Exception('이벤트 상세 조회 실패: $e');
    }
  }
}
