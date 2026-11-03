import 'dart:convert';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/announcement/announcement_model.dart';
import '../models/content/content_post.dart';
import '../models/event/event_model.dart';
import '../models/product/product_model.dart';

class SearchResult {
  final String query;
  final List<Product> prescriptionProducts;
  final List<Product> storeProducts;
  final List<EventModel> events;
  final List<AnnouncementModel> announcements;
  final List<ContentPost> contents;
  final bool prescriptionHasMore;
  final bool storeHasMore;
  final bool eventHasMore;
  final bool announcementHasMore;
  final bool contentHasMore;
  final int prescriptionTotal;
  final int storeTotal;
  final int eventTotal;
  final int announcementTotal;
  final int contentTotal;

  const SearchResult({
    required this.query,
    required this.prescriptionProducts,
    required this.storeProducts,
    required this.events,
    required this.announcements,
    required this.contents,
    this.prescriptionHasMore = false,
    this.storeHasMore = false,
    this.eventHasMore = false,
    this.announcementHasMore = false,
    this.contentHasMore = false,
    this.prescriptionTotal = 0,
    this.storeTotal = 0,
    this.eventTotal = 0,
    this.announcementTotal = 0,
    this.contentTotal = 0,
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

  static bool _contentTitleMatchesQuery(ContentPost item, String query) {
    return _textMatchesQuery(item.title, query);
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

  static List<ContentPost> _filterContentsByTitle(
    List<ContentPost> items,
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
    int limit = 5,
    String? section,
    int offset = 0,
  }) {
    final q = query.trim();
    final key = '${q.toLowerCase()}|$limit|${section ?? ''}|$offset';
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.$1) < _cacheTtl) {
      return Future.value(cached.$2);
    }
    final pending = _inFlight[key];
    if (pending != null) return pending;

    final request = _searchAllNetwork(
      q,
      limit: limit,
      section: section,
      offset: offset,
    );
    _inFlight[key] = request;
    return request.then((result) {
      _cache[key] = (DateTime.now(), result);
      return result;
    }).whenComplete(() => _inFlight.remove(key));
  }

  static int _sectionTotal(Map<String, dynamic> section, int visibleCount) {
    final raw = section['total'] ?? section['count'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw') ?? visibleCount;
  }

  static bool _sectionHasMore(Map<String, dynamic> section) {
    return section['hasMore'] == true;
  }

  static Future<SearchResult> _searchAllNetwork(
    String query, {
    int limit = 5,
    String? section,
    int offset = 0,
  }) async {
    final q = query.trim();
    if (q.isEmpty) {
      return const SearchResult(
        query: '',
        prescriptionProducts: [],
        storeProducts: [],
        events: [],
        announcements: [],
        contents: <ContentPost>[],
      );
    }

    final params = <String, String>{
      'q': q,
      'limit': '$limit',
    };
    final sectionName = (section ?? '').trim();
    if (sectionName.isNotEmpty) {
      params['section'] = sectionName;
      params['offset'] = '$offset';
    }
    final endpoint = Uri(
      path: ApiEndpoints.search,
      queryParameters: params,
    ).toString();

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
    final contentItems = _asMapList(content['items'])
        .map(ContentPost.fromJson)
        .toList(growable: false);
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
      prescriptionHasMore: _sectionHasMore(rx),
      storeHasMore: _sectionHasMore(store),
      eventHasMore: _sectionHasMore(event),
      announcementHasMore: _sectionHasMore(announcement),
      contentHasMore: _sectionHasMore(content),
      prescriptionTotal: _sectionTotal(rx, apiRxItems.length),
      storeTotal: _sectionTotal(store, apiStoreItems.length),
      eventTotal: _sectionTotal(event, apiEventItems.length),
      announcementTotal: _sectionTotal(announcement, apiAnnouncementItems.length),
      contentTotal: _sectionTotal(content, contentItems.length),
    );
  }
}
