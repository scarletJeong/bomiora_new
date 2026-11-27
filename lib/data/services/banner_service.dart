import 'dart:convert';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/home/banner_model.dart';

/// `bm_banner` 슬라이드 배너 API (`GET /api/main/banners`)
class BannerService {
  static const Duration _cacheTtl = Duration(seconds: 60);
  static final Map<String, _BannerCacheEntry> _cache = {};
  static final Map<String, Future<List<BannerModel>>> _inFlight = {};

  static String _normalizeProductKind(String? productKind) {
    final kind = (productKind ?? '').trim().toLowerCase();
    return kind == 'general' ? 'general' : 'prescription';
  }

  static Future<List<BannerModel>> fetchBanners({
    required String placement,
    String? productKind,
    String? categoryId,
    String platform = 'mobile',
    bool forceRefresh = false,
  }) async {
    final kind = placement == 'list'
        ? _normalizeProductKind(productKind)
        : '';
    final caId = placement == 'list'
        ? (categoryId ?? '').trim().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '')
        : '';
    final cacheKey = '$platform|$placement|$kind|$caId';
    if (forceRefresh) {
      _cache.remove(cacheKey);
    }
    final hit = _cache[cacheKey];
    if (!forceRefresh &&
        hit != null &&
        DateTime.now().isBefore(hit.expiresAt)) {
      return hit.banners;
    }
    if (!forceRefresh) {
      final pending = _inFlight[cacheKey];
      if (pending != null) return pending;
    }

    late final Future<List<BannerModel>> future;
    future = () async {
      try {
        final query = <String, String>{
          'platform': platform,
          'placement': placement,
        };
        if (placement == 'list') {
          query['target_kind'] = kind;
          if (caId.isNotEmpty) {
            query['ca_id'] = caId;
          }
        }

        final uri = Uri.parse(ApiEndpoints.mainBanners).replace(
          queryParameters: query,
        );
        final response = await ApiClient.get(uri.toString());
        if (response.statusCode != 200) {
          throw StateError('배너를 불러오지 못했습니다. (${response.statusCode})');
        }

        final decoded = json.decode(response.body);
        if (decoded is! Map<String, dynamic> || decoded['success'] != true) {
          throw StateError('배너를 불러오지 못했습니다.');
        }

        final raw = decoded['data'];
        if (raw is! List) {
          throw StateError('배너를 불러오지 못했습니다.');
        }

        final banners = raw
            .whereType<Map<String, dynamic>>()
            .map(BannerModel.fromJson)
            .where((b) => b.imageUrl.trim().isNotEmpty)
            .toList();

        _cache[cacheKey] = _BannerCacheEntry(
          banners: banners,
          expiresAt: DateTime.now().add(_cacheTtl),
        );
        return banners;
      } finally {
        if (identical(_inFlight[cacheKey], future)) {
          _inFlight.remove(cacheKey);
        }
      }
    }();
    _inFlight[cacheKey] = future;
    return future;
  }

  static Future<List<BannerModel>> fetchMobileBanners({
    bool forceRefresh = false,
  }) {
    return fetchBanners(placement: 'main', forceRefresh: forceRefresh);
  }

  static Future<List<BannerModel>> fetchListBanners({
    String? productKind,
    String? categoryId,
    bool forceRefresh = false,
  }) {
    return fetchBanners(
      placement: 'list',
      productKind: productKind,
      categoryId: categoryId,
      forceRefresh: forceRefresh,
    );
  }
}

class _BannerCacheEntry {
  final List<BannerModel> banners;
  final DateTime expiresAt;

  const _BannerCacheEntry({
    required this.banners,
    required this.expiresAt,
  });
}
