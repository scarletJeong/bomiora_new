import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/point/point_history_model.dart';

class PointHistoryPage {
  final List<PointHistory> items;
  final bool hasMore;

  const PointHistoryPage({
    required this.items,
    required this.hasMore,
  });
}

/// 포인트 관련 공통 서비스
class PointService {
  static const Duration _cacheTtl = Duration(minutes: 3);
  static final Map<String, int?> _pointCache = {};
  static final Map<String, PointHistoryPage> _historyCache = {};
  static final Map<String, DateTime> _pointCacheAt = {};
  static final Map<String, DateTime> _historyCacheAt = {};
  static final Map<String, Future<int?>> _pointInFlight = {};
  static final Map<String, Future<PointHistoryPage>> _historyInFlight = {};

  static String _historyKey(String id, int size, int offset) =>
      '$id:$size:$offset';

  static void invalidate([String? userId]) {
    if (userId == null || userId.trim().isEmpty) {
      _pointCache.clear();
      _historyCache.clear();
      _pointCacheAt.clear();
      _historyCacheAt.clear();
      return;
    }
    final id = userId.trim();
    final prefix = '$id:';
    _pointCache.remove(id);
    _pointCacheAt.remove(id);
    _historyCache.removeWhere((key, _) => key.startsWith(prefix));
    _historyCacheAt.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// 사용자의 현재 보유 포인트 조회
  /// bomiora_point 테이블에서 mb_id에 해당하는 가장 최근의 po_mb_point 값을 반환
  static Future<int?> getUserPoint(String userId) async {
    final id = userId.trim();
    final cachedAt = _pointCacheAt[id];
    if (cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheTtl) {
      return _pointCache[id];
    }
    final pending = _pointInFlight[id];
    if (pending != null) return pending;

    final request = _fetchUserPoint(id);
    _pointInFlight[id] = request;
    try {
      final result = await request;
      if (result != null) {
        _pointCache[id] = result;
        _pointCacheAt[id] = DateTime.now();
      } else {
        _pointCache.remove(id);
        _pointCacheAt.remove(id);
      }
      return result;
    } finally {
      _pointInFlight.remove(id);
    }
  }

  static Future<int?> _fetchUserPoint(String userId) async {
    try {
      final response = await ApiClient.get(ApiEndpoints.userPoint(userId));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final pointData = data['data'];
          // po_mb_point 값 추출
          final point = pointData['po_mb_point'] ?? pointData['point'];
          return point is int ? point : (point != null ? int.tryParse(point.toString()) : null);
        } else if (data['point'] != null) {
          // 직접 point 필드가 있는 경우
          final point = data['point'];
          return point is int ? point : (point != null ? int.tryParse(point.toString()) : null);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 포인트 내역 조회. [offset]부터 [size]건을 서버에 요청한다.
  static Future<PointHistoryPage> getPointHistory(
    String userId, {
    int size = 50,
    int offset = 0,
  }) async {
    final id = userId.trim();
    final safeSize = size.clamp(1, 100).toInt();
    final safeOffset = offset < 0 ? 0 : offset;
    final key = _historyKey(id, safeSize, safeOffset);
    final cachedAt = _historyCacheAt[key];
    if (cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheTtl) {
      final cached = _historyCache[key];
      if (cached != null) {
        return PointHistoryPage(
          items: List<PointHistory>.from(cached.items),
          hasMore: cached.hasMore,
        );
      }
    }
    final pending = _historyInFlight[key];
    if (pending != null) return pending;

    final request = _fetchPointHistory(id, size: safeSize, offset: safeOffset);
    _historyInFlight[key] = request;
    try {
      final result = await request;
      _historyCache[key] = result;
      _historyCacheAt[key] = DateTime.now();
      return PointHistoryPage(
        items: List<PointHistory>.from(result.items),
        hasMore: result.hasMore,
      );
    } finally {
      _historyInFlight.remove(key);
    }
  }

  static Future<PointHistoryPage> _fetchPointHistory(
    String userId, {
    required int size,
    required int offset,
  }) async {
    final response = await ApiClient.get(
      ApiEndpoints.pointHistory(userId, size: size, offset: offset),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map && data['success'] == true && data['data'] is List) {
        final history = (data['data'] as List)
            .whereType<Map>()
            .map((json) => PointHistory.fromJson(Map<String, dynamic>.from(json)))
            .toList();
        history.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        final hasMore = data['hasMore'] == true;
        return PointHistoryPage(items: history, hasMore: hasMore);
      }
    }

    throw Exception('point history failed');
  }
  
  /// 포인트 포맷팅 (콤마 추가)
  static String formatPoint(int? point) {
    if (point == null) return '0';
    return point.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
