import 'dart:convert';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/announcement/announcement_model.dart';
import '../models/event/event_model.dart';
import '../models/product/product_model.dart';

class SearchResult {
  final String query;
  final List<Product> prescriptionProducts;
  final List<Product> storeProducts;
  final List<EventModel> events;
  final List<AnnouncementModel> announcements;
  final List<Map<String, dynamic>> contents;

  const SearchResult({
    required this.query,
    required this.prescriptionProducts,
    required this.storeProducts,
    required this.events,
    required this.announcements,
    required this.contents,
  });
}

/// 홈 통합 검색: `/api/search` 단일 호출.
class SearchService {
  SearchService._();

  static const Duration _cacheTtl = Duration(minutes: 2);
  static final Map<String, (DateTime, SearchResult)> _cache = {};
  static final Map<String, Future<SearchResult>> _inFlight = {};

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

  static List<Product> _parseProductsExcludingInfluencer(dynamic raw) {
    final list = _asMapList(raw);
    return list
        .where((m) => !Product.isInfluencerFromRawJson(m))
        .map((m) => Product.fromJson(m))
        .toList(growable: false);
  }

  static String _normalizeSearchText(String? raw) {
    if (raw == null) return '';
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _textMatchesQuery(String? raw, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return false;
    return _normalizeSearchText(raw).toLowerCase().contains(q);
  }

  static bool _productTitleMatchesQuery(Product product, String query) {
    return _textMatchesQuery(product.name, query);
  }

  static bool _contentTitleMatchesQuery(
    Map<String, dynamic> item,
    String query,
  ) {
    return _textMatchesQuery(item['title']?.toString(), query);
  }

  static bool _eventTitleMatchesQuery(EventModel event, String query) {
    return _textMatchesQuery(event.wrSubject, query);
  }

  static bool _announcementTitleMatchesQuery(
    AnnouncementModel item,
    String query,
  ) {
    return _textMatchesQuery(item.title, query);
  }

  static List<Product> _filterProductsByTitle(
    List<Product> items,
    String query,
  ) {
    return items
        .where((product) => _productTitleMatchesQuery(product, query))
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _filterContentsByTitle(
    List<Map<String, dynamic>> items,
    String query,
  ) {
    return items
        .where((item) => _contentTitleMatchesQuery(item, query))
        .toList(growable: false);
  }

  static List<EventModel> _filterEventsByTitle(
    List<EventModel> items,
    String query,
  ) {
    return items
        .where((event) => _eventTitleMatchesQuery(event, query))
        .toList(growable: false);
  }

  static List<AnnouncementModel> _filterAnnouncementsByTitle(
    List<AnnouncementModel> items,
    String query,
  ) {
    return items
        .where((item) => _announcementTitleMatchesQuery(item, query))
        .toList(growable: false);
  }

  static List<EventModel> _parseEvents(dynamic raw) {
    return _asMapList(raw)
        .map((m) => EventModel.fromJson(m))
        .toList(growable: false);
  }

  static List<AnnouncementModel> _parseAnnouncements(dynamic raw) {
    return _asMapList(raw)
        .map((m) => AnnouncementModel.fromJson(m))
        .toList(growable: false);
  }

  static Future<SearchResult> searchAll(
    String query, {
    int rxLimit = 20,
    int storeLimit = 20,
    int contentLimit = 20,
  }) {
    final q = query.trim();
    final key = '${q.toLowerCase()}|$rxLimit|$storeLimit|$contentLimit';
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.$1) < _cacheTtl) {
      return Future.value(cached.$2);
    }
    final pending = _inFlight[key];
    if (pending != null) return pending;

    final request = _searchAllNetwork(
      q,
      rxLimit: rxLimit,
      storeLimit: storeLimit,
      contentLimit: contentLimit,
    );
    _inFlight[key] = request;
    return request.then((result) {
      _cache[key] = (DateTime.now(), result);
      return result;
    }).whenComplete(() => _inFlight.remove(key));
  }

  static Future<SearchResult> _searchAllNetwork(
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
        events: [],
        announcements: [],
        contents: [],
      );
    }

    final endpoint = '${ApiEndpoints.search}?q=${Uri.encodeQueryComponent(q)}'
        '&rxLimit=$rxLimit&storeLimit=$storeLimit&contentLimit=$contentLimit';

    final responseFuture = ApiClient.get(endpoint);
    final response = await responseFuture;

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
    final event = results['event'] is Map
        ? Map<String, dynamic>.from(results['event'] as Map)
        : const <String, dynamic>{};
    final announcement = results['announcement'] is Map
        ? Map<String, dynamic>.from(results['announcement'] as Map)
        : const <String, dynamic>{};

    final apiRxItems = _parseProductsExcludingInfluencer(rx['items']);
    final apiStoreItems = _parseProductsExcludingInfluencer(store['items']);
    final contentItems = _asMapList(content['items']);
    final apiEventItems = _parseEvents(event['items']);
    final apiAnnouncementItems = _parseAnnouncements(announcement['items']);

    final mergedEvents = _filterEventsByTitle(apiEventItems, q);
    final mergedAnnouncements =
        _filterAnnouncementsByTitle(apiAnnouncementItems, q);

    final filteredContentItems = _filterContentsByTitle(contentItems, q);

    return SearchResult(
      query: (body['query'] ?? q).toString(),
      prescriptionProducts: _filterProductsByTitle(apiRxItems, q),
      storeProducts: _filterProductsByTitle(apiStoreItems, q),
      events: mergedEvents,
      announcements: mergedAnnouncements,
      contents: filteredContentItems,
    );
  }
}
