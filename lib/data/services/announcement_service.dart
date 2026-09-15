import 'dart:convert';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/announcement/announcement_model.dart';

class AnnouncementService {
  static const Duration _listCacheTtl = Duration(minutes: 3);
  static final Map<String, Map<String, dynamic>> _listCache = {};
  static final Map<String, DateTime> _listCacheAt = {};
  static final Map<String, Future<Map<String, dynamic>>> _listInFlight = {};

  static Future<Map<String, dynamic>> getAnnouncements({
    int page = 1,
    int size = 6,
    String query = '',
  }) async {
    final cacheKey = '$page:$size:${query.trim()}';
    final cachedAt = _listCacheAt[cacheKey];
    if (cachedAt != null &&
        DateTime.now().difference(cachedAt) < _listCacheTtl) {
      return Map<String, dynamic>.from(_listCache[cacheKey]!);
    }
    final pending = _listInFlight[cacheKey];
    if (pending != null) return pending;

    final request = _fetchAnnouncements(
      page: page,
      size: size,
      query: query,
      cacheKey: cacheKey,
    );
    _listInFlight[cacheKey] = request;
    try {
      return await request;
    } finally {
      if (identical(_listInFlight[cacheKey], request)) {
        _listInFlight.remove(cacheKey);
      }
    }
  }

  static Future<Map<String, dynamic>> _fetchAnnouncements({
    required int page,
    required int size,
    required String query,
    required String cacheKey,
  }) async {
    try {
      final endpoint =
          '${ApiEndpoints.getAnnouncementList}?page=$page&size=$size&query=${Uri.encodeComponent(query)}';
      final response = await ApiClient.get(endpoint);

      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': '공지사항 목록을 불러오지 못했습니다.',
          'items': <AnnouncementModel>[],
          'total': 0,
          'page': page,
          'size': size,
          'totalPages': 0,
        };
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final data = body['data'];
      final pagination = body['pagination'] as Map<String, dynamic>?;
      final items = <AnnouncementModel>[];
      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            items.add(AnnouncementModel.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }

      final result = {
        'success': body['success'] == true,
        'message': body['message']?.toString(),
        'items': items,
        'total': pagination?['total'] ?? items.length,
        'page': pagination?['page'] ?? page,
        'size': pagination?['size'] ?? size,
        'totalPages': pagination?['totalPages'] ?? 1,
      };
      if (result['success'] == true) {
        _listCache[cacheKey] = Map<String, dynamic>.from(result);
        _listCacheAt[cacheKey] = DateTime.now();
      }
      return result;
    } catch (e) {
      return {
        'success': false,
        'message': '공지사항 목록 조회 오류: $e',
        'items': <AnnouncementModel>[],
        'total': 0,
        'page': page,
        'size': size,
        'totalPages': 0,
      };
    }
  }

  static Future<Map<String, dynamic>> getAnnouncementDetail(int id) async {
    try {
      final endpoint = '${ApiEndpoints.getAnnouncementDetail}/$id';
      final response = await ApiClient.get(endpoint);
      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': '공지사항 상세를 불러오지 못했습니다.',
          'item': null,
        };
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final itemRaw = body['data'];
      final prevRaw = body['prev'];
      final nextRaw = body['next'];
      return {
        'success': body['success'] == true,
        'message': body['message']?.toString(),
        'item': itemRaw is Map
            ? AnnouncementModel.fromJson(Map<String, dynamic>.from(itemRaw))
            : null,
        'prev': prevRaw is Map<String, dynamic>
            ? prevRaw
            : (prevRaw is Map ? Map<String, dynamic>.from(prevRaw) : null),
        'next': nextRaw is Map<String, dynamic>
            ? nextRaw
            : (nextRaw is Map ? Map<String, dynamic>.from(nextRaw) : null),
      };
    } catch (e) {
      return {
        'success': false,
        'message': '공지사항 상세 조회 오류: $e',
        'item': null,
      };
    }
  }
}
