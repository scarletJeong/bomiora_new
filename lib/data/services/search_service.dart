import 'dart:convert';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/product/product_model.dart';

class SearchResult {
  final String query;
  final List<Product> prescriptionProducts;
  final List<Product> storeProducts;
  final List<Map<String, dynamic>> contents;

  const SearchResult({
    required this.query,
    required this.prescriptionProducts,
    required this.storeProducts,
    required this.contents,
  });
}

/// 홈 통합 검색: `/api/search` 단일 호출.
class SearchService {
  SearchService._();

  static List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        out.add(item);
      } else if (item is Map) {
        out.add(Map<String, dynamic>.from(item));
      }
    }
    return out;
  }

  static List<Product> _parseProducts(dynamic raw) {
    final list = _asMapList(raw);
    return list.map((m) => Product.fromJson(m)).toList(growable: false);
  }

  static Future<SearchResult> searchAll(
    String query, {
    int rxLimit = 20,
    int storeLimit = 20,
    int contentLimit = 20,
  }) async {
    final q = query.trim();
    if (q.isEmpty) {
      return const SearchResult(
        query: '',
        prescriptionProducts: [],
        storeProducts: [],
        contents: [],
      );
    }

    final endpoint =
        '${ApiEndpoints.search}?q=${Uri.encodeQueryComponent(q)}'
        '&rxLimit=$rxLimit&storeLimit=$storeLimit&contentLimit=$contentLimit';
    final response = await ApiClient.get(endpoint);

    if (response.statusCode != 200) {
      throw Exception('검색 API 실패 (status=${response.statusCode})');
    }

    final decoded = json.decode(response.body);
    if (decoded is! Map) {
      throw Exception('검색 API 응답 형식이 올바르지 않습니다.');
    }

    final body = Map<String, dynamic>.from(decoded);
    if (body['success'] != true) {
      throw Exception((body['message'] ?? '검색 실패').toString());
    }

    final results = body['results'] is Map
        ? Map<String, dynamic>.from(body['results'] as Map)
        : const <String, dynamic>{};

    final rx = results['prescription'] is Map
        ? Map<String, dynamic>.from(results['prescription'] as Map)
        : const <String, dynamic>{};
    final store = results['store'] is Map
        ? Map<String, dynamic>.from(results['store'] as Map)
        : const <String, dynamic>{};
    final content = results['content'] is Map
        ? Map<String, dynamic>.from(results['content'] as Map)
        : const <String, dynamic>{};

    final rxItems = _parseProducts(rx['items']);
    final storeItems = _parseProducts(store['items']);
    final contentItems = _asMapList(content['items']);

    return SearchResult(
      query: (body['query'] ?? q).toString(),
      prescriptionProducts: rxItems,
      storeProducts: storeItems,
      contents: contentItems,
    );
  }
}

