import 'dart:convert';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/announcement/announcement_model.dart';
import '../models/event/event_model.dart';
import '../models/product/product_model.dart';
import '../repositories/product/product_repository.dart';
import 'announcement_service.dart';
import 'event_service.dart';

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

  /// 비대면 진료 공식 카탈로그 (`get_product.dart` productPrescriptionCategoryList)
  static const List<String> _rxCatalogCategoryIds = ['10', '20', '80', '50'];

  /// 스토어 공식 카탈로그 (`get_product.dart` productGeneralCategoryList)
  static const List<String> _storeCatalogCategoryIds = [
    '11',
    '21',
    '51',
    '60',
    '70',
  ];

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

  static bool _eventMatchesQuery(EventModel event, String query) {
    return _eventTitleMatchesQuery(event, query);
  }

  static Future<List<EventModel>> _searchEvents(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    try {
      final results = await Future.wait([
        EventService.getActiveEvents(),
        EventService.getEndedEvents(),
      ]);
      final byId = <int, EventModel>{};
      for (final list in results) {
        for (final event in list) {
          byId.putIfAbsent(event.wrId, () => event);
        }
      }
      return byId.values
          .where((event) => _eventMatchesQuery(event, q))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static Future<List<AnnouncementModel>> _searchAnnouncements(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    try {
      final result = await AnnouncementService.getAnnouncements(
        page: 1,
        size: 20,
        query: q,
      );
      if (result['success'] != true) return const [];
      final items = (result['items'] as List<AnnouncementModel>?) ?? const [];
      return _filterAnnouncementsByTitle(items, q);
    } catch (_) {
      return const [];
    }
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

  static bool _productMatchesQuery(Product product, String query) {
    return _productTitleMatchesQuery(product, query);
  }

  /// 검색 API가 인플루언서·기타 채널 위주로 반환할 때 공식 카탈로그에서 보완.
  static Future<List<Product>> _searchCatalogProducts({
    required String query,
    required List<String> categoryIds,
    required String productKind,
  }) async {
    final q = query.trim();
    if (q.isEmpty || categoryIds.isEmpty) return const [];

    try {
      final lists = await Future.wait(
        categoryIds.map(
          (categoryId) => ProductRepository.getProductsByCategory(
            categoryId: categoryId,
            productKind: productKind,
            page: 1,
            pageSize: 100,
          ),
        ),
      );

      return lists
          .expand((list) => list)
          .where((p) => !p.isInfluencerProduct)
          .where((p) => _productMatchesQuery(p, q))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// 카탈로그 매칭을 우선, 검색 API 결과는 중복 없이 뒤에 합침.
  static List<Product> _mergeProductsById(
    List<Product> primary,
    List<Product> secondary,
  ) {
    final seen = <String>{};
    final merged = <Product>[];

    void addAll(Iterable<Product> items) {
      for (final product in items) {
        if (seen.add(product.id)) {
          merged.add(product);
        }
      }
    }

    addAll(primary);
    addAll(secondary);
    return merged;
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
        events: [],
        announcements: [],
        contents: [],
      );
    }

    final endpoint =
        '${ApiEndpoints.search}?q=${Uri.encodeQueryComponent(q)}'
        '&rxLimit=$rxLimit&storeLimit=$storeLimit&contentLimit=$contentLimit';

    final responseFuture = ApiClient.get(endpoint);
    final catalogRxFuture = _searchCatalogProducts(
      query: q,
      categoryIds: _rxCatalogCategoryIds,
      productKind: 'prescription',
    );
    final catalogStoreFuture = _searchCatalogProducts(
      query: q,
      categoryIds: _storeCatalogCategoryIds,
      productKind: 'general',
    );
    final eventsFuture = _searchEvents(q);
    final announcementsFuture = _searchAnnouncements(q);

    final response = await responseFuture;
    final catalogRxItems = await catalogRxFuture;
    final catalogStoreItems = await catalogStoreFuture;
    final eventItems = await eventsFuture;
    final announcementItems = await announcementsFuture;

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

    List<EventModel> mergedEvents = _filterEventsByTitle(eventItems, q);
    if (apiEventItems.isNotEmpty) {
      final seen = mergedEvents.map((e) => e.wrId).toSet();
      mergedEvents = [
        ...mergedEvents,
        ..._filterEventsByTitle(apiEventItems, q).where((e) => seen.add(e.wrId)),
      ];
    }

    List<AnnouncementModel> mergedAnnouncements =
        _filterAnnouncementsByTitle(announcementItems, q);
    if (apiAnnouncementItems.isNotEmpty) {
      final seen = mergedAnnouncements.map((e) => e.id).toSet();
      mergedAnnouncements = [
        ...mergedAnnouncements,
        ..._filterAnnouncementsByTitle(apiAnnouncementItems, q)
            .where((e) => seen.add(e.id)),
      ];
    }

    final filteredContentItems = _filterContentsByTitle(contentItems, q);

    return SearchResult(
      query: (body['query'] ?? q).toString(),
      prescriptionProducts: _filterProductsByTitle(
        _mergeProductsById(catalogRxItems, apiRxItems),
        q,
      ),
      storeProducts: _filterProductsByTitle(
        _mergeProductsById(catalogStoreItems, apiStoreItems),
        q,
      ),
      events: mergedEvents,
      announcements: mergedAnnouncements,
      contents: filteredContentItems,
    );
  }
}
