import 'dart:convert';

import '../models/event/event_model.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';

class EventPageResult {
  const EventPageResult({
    required this.items,
    required this.total,
    required this.hasMore,
  });

  final List<EventModel> items;
  final int total;
  final bool hasMore;
}

class EventService {
  static const Duration _listCacheTtl = Duration(minutes: 3);
  static const int _pageSize = 10;
  static final Map<String, EventPageResult> _pageCache = {};
  static final Map<String, DateTime> _pageCacheAt = {};
  static final Map<String, Future<EventPageResult>> _pageInFlight = {};

  static String _withNoCacheParam(String endpoint) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return endpoint.contains('?') ? '$endpoint&_ts=$ts' : '$endpoint?_ts=$ts';
  }

  static const Map<String, String> _noCacheHeaders = {
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache',
  };

  static EventPageResult _parseEventPage(
    dynamic responseData, {
    required int page,
    required int size,
  }) {
    if (responseData is! Map) {
      return const EventPageResult(items: [], total: 0, hasMore: false);
    }
    final map = Map<String, dynamic>.from(responseData);
    if (map['success'] != true) {
      return const EventPageResult(items: [], total: 0, hasMore: false);
    }

    final dataList = map['data'];
    final out = <EventModel>[];
    if (dataList is List) {
      for (final row in dataList) {
        if (row is! Map) continue;
        try {
          out.add(EventModel.fromJson(Map<String, dynamic>.from(row)));
        } catch (_) {
          continue;
        }
      }
    }
    final total = int.tryParse('${map['total']}') ?? out.length;
    final hasMore = map.containsKey('hasMore')
        ? map['hasMore'] == true
        : page * size < total;
    return EventPageResult(items: out, total: total, hasMore: hasMore);
  }

  /// 홈 등에서 진행중 이벤트 첫 10건만 쓴다.
  static Future<List<EventModel>> getActiveEvents({
    bool forceRefresh = false,
  }) async {
    final page = await getActiveEventsPage(forceRefresh: forceRefresh);
    return page.items;
  }

  static Future<EventPageResult> getActiveEventsPage({
    int page = 1,
    int size = _pageSize,
    bool forceRefresh = false,
  }) {
    return _getPage(
      kind: 'active',
      endpoint: ApiEndpoints.getActiveEvents,
      page: page,
      size: size,
      forceRefresh: forceRefresh,
      failureLabel: '진행중인 이벤트 목록',
    );
  }

  /// 홈 외 호출 호환. 종료 이벤트 첫 10건.
  static Future<List<EventModel>> getEndedEvents() async {
    final page = await getEndedEventsPage();
    return page.items;
  }

  static Future<EventPageResult> getEndedEventsPage({
    int page = 1,
    int size = _pageSize,
    bool forceRefresh = false,
  }) {
    return _getPage(
      kind: 'ended',
      endpoint: ApiEndpoints.getEndedEvents,
      page: page,
      size: size,
      forceRefresh: forceRefresh,
      failureLabel: '종료된 이벤트 목록',
    );
  }

  static String _pageKey(String kind, int page, int size) => '$kind:$page:$size';

  static Future<EventPageResult> _getPage({
    required String kind,
    required String endpoint,
    required int page,
    required int size,
    required bool forceRefresh,
    required String failureLabel,
  }) {
    final safePage = page < 1 ? 1 : page;
    final safeSize = size < 1 ? _pageSize : size;
    final key = _pageKey(kind, safePage, safeSize);
    final cachedAt = _pageCacheAt[key];
    final cached = _pageCache[key];
    if (forceRefresh) {
      final prefix = '$kind:';
      _pageCache.removeWhere((cacheKey, _) => cacheKey.startsWith(prefix));
      _pageCacheAt.removeWhere((cacheKey, _) => cacheKey.startsWith(prefix));
    } else if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _listCacheTtl) {
      return Future.value(cached);
    }
    final pending = _pageInFlight[key];
    if (pending != null) return pending;

    final request = _fetchPage(
      key: key,
      endpoint: endpoint,
      page: safePage,
      size: safeSize,
      failureLabel: failureLabel,
      forceRefresh: forceRefresh,
    );
    _pageInFlight[key] = request;
    return request.whenComplete(() {
      if (identical(_pageInFlight[key], request)) _pageInFlight.remove(key);
    });
  }

  static Future<EventPageResult> _fetchPage({
    required String key,
    required String endpoint,
    required int page,
    required int size,
    required String failureLabel,
    bool forceRefresh = false,
  }) async {
    final path = endpoint.contains('?')
        ? '$endpoint&page=$page&size=$size'
        : '$endpoint?page=$page&size=$size';
    try {
      final response = await ApiClient.get(path);
      if (response.statusCode == 304 || response.body.trim().isEmpty) {
        final cached = forceRefresh ? null : _pageCache[key];
        if (cached != null) return cached;
        throw Exception('$failureLabel 응답이 비어 있습니다.');
      }
      if (response.statusCode != 200) {
        throw Exception('$failureLabel HTTP ${response.statusCode}');
      }
      final responseData = json.decode(response.body);
      if (responseData is Map && responseData['success'] != true) {
        final message = responseData['message']?.toString().trim() ?? '';
        throw Exception(
          message.isEmpty ? '$failureLabel 조회에 실패했습니다.' : '$failureLabel: $message',
        );
      }
      final result = _parseEventPage(responseData, page: page, size: size);
      _pageCache[key] = result;
      _pageCacheAt[key] = DateTime.now();
      return result;
    } catch (e) {
      final cached = forceRefresh ? null : _pageCache[key];
      if (cached != null) return cached;
      throw Exception('$failureLabel 조회 실패: $e');
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

      if (response.statusCode == 404) return null;
      if (response.statusCode == 304 || response.body.trim().isEmpty) {
        throw Exception('이벤트 상세 응답이 비어 있습니다.');
      }
      if (response.statusCode != 200) {
        throw Exception('이벤트 상세 HTTP ${response.statusCode}');
      }

      final responseData = json.decode(response.body);
      if (responseData is Map &&
          responseData['success'] == true &&
          responseData['data'] is Map) {
        return EventModel.fromJson(
          Map<String, dynamic>.from(responseData['data'] as Map),
        );
      }
      final message = responseData is Map
          ? responseData['message']?.toString().trim() ?? ''
          : '';
      if (message.contains('찾을 수 없') || message.contains('종료된 이벤트')) {
        return null;
      }
      throw Exception(
        message.isEmpty ? '이벤트 상세 조회에 실패했습니다.' : message,
      );
    } catch (e) {
      throw Exception('이벤트 상세 조회 실패: $e');
    }
  }
}
