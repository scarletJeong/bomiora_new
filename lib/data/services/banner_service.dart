import 'dart:convert';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/home/banner_model.dart';

/// `bm_banner` 슬라이드 배너 API (`GET /api/main/banners`)
class BannerService {
  static String _normalizeProductKind(String? productKind) {
    final kind = (productKind ?? '').trim().toLowerCase();
    return kind == 'general' ? 'general' : 'prescription';
  }

  static Future<List<BannerModel>> fetchBanners({
    required String placement,
    String? productKind,
    String platform = 'mobile',
  }) async {
    try {
      final query = <String, String>{
        'platform': platform,
        'placement': placement,
      };
      if (placement == 'list') {
        query['target_kind'] = _normalizeProductKind(productKind);
      }

      final uri = Uri.parse(ApiEndpoints.mainBanners).replace(
        queryParameters: query,
      );
      final response = await ApiClient.get(uri.toString());
      if (response.statusCode != 200) return const [];

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) return const [];
      if (decoded['success'] != true) return const [];

      final raw = decoded['data'];
      if (raw is! List) return const [];

      return raw
          .whereType<Map<String, dynamic>>()
          .map(BannerModel.fromJson)
          .where((b) => b.imageUrl.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
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
