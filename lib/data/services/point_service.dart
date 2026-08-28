import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/point/point_history_model.dart';

/// 포인트 관련 공통 서비스
class PointService {
  static const Duration _cacheTtl = Duration(seconds: 60);
  static final Map<String, int?> _pointCache = {};
  static final Map<String, List<PointHistory>> _historyCache = {};
  static final Map<String, DateTime> _pointCacheAt = {};
  static final Map<String, DateTime> _historyCacheAt = {};
  static final Map<String, Future<int?>> _pointInFlight = {};
  static final Map<String, Future<List<PointHistory>>> _historyInFlight = {};

  static void invalidate([String? userId]) {
    if (userId == null || userId.trim().isEmpty) {
      _pointCache.clear();
      _historyCache.clear();
      _pointCacheAt.clear();
      _historyCacheAt.clear();
      return;
    }
    final id = userId.trim();
    _pointCache.remove(id);
    _historyCache.remove(id);
    _pointCacheAt.remove(id);
    _historyCacheAt.remove(id);
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
      _pointCache[id] = result;
      _pointCacheAt[id] = DateTime.now();
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

  /// 포인트 내역 조회
  static Future<List<PointHistory>> getPointHistory(String userId) async {
    final id = userId.trim();
    final cachedAt = _historyCacheAt[id];
    if (cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheTtl) {
      return List<PointHistory>.from(_historyCache[id] ?? const []);
    }
    final pending = _historyInFlight[id];
    if (pending != null) return pending;

    final request = _fetchPointHistory(id);
    _historyInFlight[id] = request;
    try {
      final result = await request;
      _historyCache[id] = result;
      _historyCacheAt[id] = DateTime.now();
      return List<PointHistory>.from(result);
    } finally {
      _historyInFlight.remove(id);
    }
  }

  static Future<List<PointHistory>> _fetchPointHistory(String userId) async {
    try {
      final response = await ApiClient.get(ApiEndpoints.pointHistory(userId));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> historyJson = data['data'];
          final history = historyJson
              .map((json) => PointHistory.fromJson(json))
              .toList();
          
          // 날짜 내림차순 정렬 (최신순)
          history.sort((a, b) => b.dateTime.compareTo(a.dateTime));

          return history;
        }
      }

      return [];
    } catch (e) {
      return [];
    }
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
