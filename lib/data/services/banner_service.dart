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
    String platform = 'mobile',
  }) async {
    final kind = placement == 'list'
        ? _normalizeProductKind(productKind)
        : '';
    final cacheKey = '$platform|$placement|$kind';
    final hit = _cache[cacheKey];
    if (hit != null && DateTime.now().isBefore(hit.expiresAt)) {
      return hit.banners;
    }
    final pending = _inFlight[cacheKey];
    if (pending != null) return pending;

    final future = () async {
      try {
        final query = <String, String>{
          'platform': platform,
          'placement': placement,
        };
        if (placement == 'list') {
          query['target_kind'] = kind;
        }

        final uri = Uri.parse(ApiEndpoints.mainBanners).replace(
          queryParameters: query,
        );
        final response = await ApiClient.get(uri.toString());
        if (response.statusCode != 200) return const <BannerModel>[];

        final decoded = json.decode(response.body);
        if (decoded is! Map<String, dynamic>) return const <BannerModel>[];
        if (decoded['success'] != true) return const <BannerModel>[];

        final raw = decoded['data'];
        if (raw is! List) return const <BannerModel>[];

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
      } catch (_) {
        return hit?.banners ?? const <BannerModel>[];
      } finally {
        _inFlight.remove(cacheKey);
      }
    }();
    _inFlight[cacheKey] = future;
    return future;
  }

  static Future<List<BannerModel>> fetchMobileBanners() {
    return fetchBanners(placement: 'main');
  }

  static Future<List<BannerModel>> fetchListBanners({
    String? productKind,
  }) {
    return fetchBanners(placement: 'list', productKind: productKind);
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
