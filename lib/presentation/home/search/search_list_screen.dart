import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/announcement/announcement_model.dart';
import '../../../data/models/content/content_post.dart';
import '../../../data/models/event/event_model.dart';
import '../../../data/models/product/product_model.dart';
import '../../../data/services/content_service.dart';
import '../../../data/services/recent_search_service.dart';
import '../../../data/services/search_service.dart';
import '../../common/widgets/app_network_image.dart';
import '../../common/widgets/centered_empty_state.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/product_card.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../../health/health_common/widgets/health_focus_outline_box.dart';

/// 검색 결과 주소. 검색어가 있으면 `/search?q=검색어`.
String searchResultLocation(String query) {
  final q = query.trim();
  if (q.isEmpty) return '/search';
  return Uri(path: '/search', queryParameters: {'q': q}).toString();
}

/// 통합 검색 결과 — 카테고리별 리스트.
class SearchListScreen extends StatefulWidget {
  const SearchListScreen({
    super.key,
    required this.initialQuery,
  });

  final String initialQuery;

  @override
  State<SearchListScreen> createState() => _SearchListScreenState();
}

class _SearchListScreenState extends State<SearchListScreen> {
  static const Color _ink = Color(0xFF1A1A1A);
  static const Color _muted = Color(0xFF898686);
  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _border = Color(0x7FD2D2D2);
  static const Color _sectionBg = Color(0xFFF9FAFB);
  static const Color _rowBorder = Color(0xFFF3F4F6);
  static const Color _titleDark = Color(0xFF1F2937);

  late final TextEditingController _queryController;
  int _searchRequestId = 0;

  List<Product> _rx = const [];
  List<Product> _store = const [];
  List<EventModel> _events = const [];
  List<AnnouncementModel> _announcements = const [];
  List<ContentPost> _content = const <ContentPost>[];
  bool _rxHasMore = false;
  bool _storeHasMore = false;
  bool _eventHasMore = false;
  bool _announcementHasMore = false;
  bool _contentHasMore = false;
  int _rxTotal = 0;
  int _storeTotal = 0;
  int _eventTotal = 0;
  int _announcementTotal = 0;
  int _contentTotal = 0;
  String? _loadingSection;
  bool _loading = true;
  bool _initialLoad = true;
  String? _error;

  static const int _pageSize = 5;

  double _hPad(BuildContext context) => healthDp(context, 20);

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery.trim());
    final initial = _queryController.text.trim();
    if (initial.isNotEmpty) {
      unawaited(RecentSearchService.addQuery(initial));
    }
    _runSearch(initial);
  }

  @override
  void dispose() {
    final lastQuery = _queryController.text.trim();
    if (lastQuery.isNotEmpty) {
      unawaited(RecentSearchService.addQuery(lastQuery));
    }
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _commitSearch(String raw) async {
    final q = raw.trim();
    final next = searchResultLocation(q);
    final current = ModalRoute.of(context)?.settings.name;
    if (current != null && current != next) {
      Navigator.of(context).pushReplacementNamed<void, void>(next);
      return;
    }
    if (q.isEmpty) {
      await _runSearch(q);
      return;
    }
    await RecentSearchService.addQuery(q);
    await _runSearch(q);
  }

  Future<void> _runSearch(String raw) async {
    final q = raw.trim();
    final requestId = ++_searchRequestId;
    if (q.isEmpty) {
      setState(() {
        _rx = const [];
        _store = const [];
        _events = const [];
        _announcements = const [];
        _content = const <ContentPost>[];
        _rxHasMore = false;
        _storeHasMore = false;
        _eventHasMore = false;
        _announcementHasMore = false;
        _contentHasMore = false;
        _rxTotal = 0;
        _storeTotal = 0;
        _eventTotal = 0;
        _announcementTotal = 0;
        _contentTotal = 0;
        _loadingSection = null;
        _loading = false;
        _initialLoad = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (!mounted) return;
      final result = await SearchService.searchAll(q, limit: _pageSize);
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _rx = result.prescriptionProducts;
        _store = result.storeProducts;
        _events = result.events;
        _announcements = result.announcements;
        _content = result.contents;
        _rxHasMore = result.prescriptionHasMore;
        _storeHasMore = result.storeHasMore;
        _eventHasMore = result.eventHasMore;
        _announcementHasMore = result.announcementHasMore;
        _contentHasMore = result.contentHasMore;
        _rxTotal = result.prescriptionTotal;
        _storeTotal = result.storeTotal;
        _eventTotal = result.eventTotal;
        _announcementTotal = result.announcementTotal;
        _contentTotal = result.contentTotal;
        _loadingSection = null;
        _loading = false;
        _initialLoad = false;
      });
    } catch (e) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _rx = const [];
        _store = const [];
        _events = const [];
        _announcements = const [];
        _content = const <ContentPost>[];
        _rxHasMore = false;
        _storeHasMore = false;
        _eventHasMore = false;
        _announcementHasMore = false;
        _contentHasMore = false;
        _rxTotal = 0;
        _storeTotal = 0;
        _eventTotal = 0;
        _announcementTotal = 0;
        _contentTotal = 0;
        _loadingSection = null;
        _loading = false;
        _initialLoad = false;
        _error = e.toString();
      });
    }
  }

  int _loadedCount(String section) {
    switch (section) {
      case 'prescription':
        return _rx.length;
      case 'store':
        return _store.length;
      case 'event':
        return _events.length;
      case 'announcement':
        return _announcements.length;
      case 'content':
        return _content.length;
      default:
        return 0;
    }
  }

  List<T> _appendById<T>(
    List<T> current,
    List<T> incoming,
    Object? Function(T item) idOf,
  ) {
    final seen = <Object?>{for (final item in current) idOf(item)};
    final next = List<T>.of(current);
    for (final item in incoming) {
      if (seen.add(idOf(item))) next.add(item);
    }
    return next;
  }

  Future<void> _loadMore(String section) async {
    if (_loading || _loadingSection != null) return;
    final q = _queryController.text.trim();
    if (q.isEmpty) return;
    final requestId = _searchRequestId;
    final offset = _loadedCount(section);
    setState(() => _loadingSection = section);
    try {
      final result = await SearchService.searchAll(
        q,
        limit: _pageSize,
        section: section,
        offset: offset,
      );
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        switch (section) {
          case 'prescription':
            _rx = _appendById(_rx, result.prescriptionProducts, (item) => item.id);
            _rxHasMore = result.prescriptionProducts.isEmpty
                ? false
                : result.prescriptionHasMore;
            _rxTotal = result.prescriptionTotal;
          case 'store':
            _store = _appendById(
              _store,
              result.storeProducts,
              (item) => item.id,
            );
            _storeHasMore =
                result.storeProducts.isEmpty ? false : result.storeHasMore;
            _storeTotal = result.storeTotal;
          case 'event':
            _events = _appendById(_events, result.events, (item) => item.wrId);
            _eventHasMore =
                result.events.isEmpty ? false : result.eventHasMore;
            _eventTotal = result.eventTotal;
          case 'announcement':
            _announcements = _appendById(
              _announcements,
              result.announcements,
              (item) => item.id,
            );
            _announcementHasMore = result.announcements.isEmpty
                ? false
                : result.announcementHasMore;
            _announcementTotal = result.announcementTotal;
          case 'content':
            _content = _appendById(_content, result.contents, (item) => item.id);
            _contentHasMore =
                result.contents.isEmpty ? false : result.contentHasMore;
            _contentTotal = result.contentTotal;
        }
        _loadingSection = null;
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() => _loadingSection = null);
    }
  }

  int get _total =>
      _rxTotal +
      _storeTotal +
      _eventTotal +
      _announcementTotal +
      _contentTotal;

  void _openEvent(EventModel event) {
    if (event.isEnded) return;
    Navigator.pushNamed(context, '/event/${event.wrId}');
  }

  void _openAnnouncement(AnnouncementModel item) {
    Navigator.pushNamed(context, '/announcement/${item.id}');
  }

  void _openProduct(Product p, {required bool general}) {
    final kind = (p.productKind ?? '').trim().toLowerCase();
    final useGeneral = kind == 'general'
        ? true
        : kind == 'prescription'
            ? false
            : general;
    final route =
        useGeneral ? '/product-general/${p.id}' : '/product/${p.id}';
    Navigator.pushNamed(context, route);
  }

  void _openContent(ContentPost item) {
    final id = item.id;
    if (id == null) return;
    final cat = item.category;
    Navigator.pushNamed(
      context,
      '/content/detail',
      arguments: {
        'id': id,
        if (cat.isNotEmpty) 'category': cat,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(title: '검색'),
      child: _initialLoad && _loading
          ? const Center(child: CircularProgressIndicator(color: _pink))
          : _buildResults(),
    );
  }

  Widget _buildResults() {
    final showEmpty = !_loading && (_error != null || _total == 0);
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              _hPad(context),
              healthDp(context, 12),
              _hPad(context),
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchBar(),
                SizedBox(height: healthDp(context, 12)),
                _buildResultCountRow(),
              ],
            ),
          ),
        ),
        if (_loading)
          SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: healthDp(context, 40)),
                child: const CircularProgressIndicator(color: _pink),
              ),
            ),
          )
        else if (_error != null || _total == 0)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: SizedBox.shrink(),
          )
        else
          SliverPadding(
            padding: EdgeInsets.only(
              top: healthDp(context, 10),
              bottom: healthDp(context, 24),
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                _buildGroupedListChildren(),
              ),
            ),
          ),
      ],
        ),
        if (showEmpty)
          PageCenteredEmptyOverlay(child: _buildGlobalEmptyContent()),
      ],
    );
  }

  List<Widget> _buildGroupedListChildren() {
    final children = <Widget>[];

    void addSection({
      required String title,
      required String section,
      required int count,
      required List<Widget> items,
      required bool hasMore,
    }) {
      if (items.isEmpty) return;
      children.add(_buildSectionHeader(title, count));
      children.addAll(items);
      if (hasMore) children.add(_buildMoreButton(section));
    }

    addSection(
      title: '비대면 진료',
      section: 'prescription',
      count: _rxTotal,
      items: _rx.map((p) => _buildProductListRow(p, general: false)).toList(),
      hasMore: _rxHasMore,
    );
    addSection(
      title: '스토어',
      section: 'store',
      count: _storeTotal,
      items: _store.map((p) => _buildProductListRow(p, general: true)).toList(),
      hasMore: _storeHasMore,
    );
    addSection(
      title: '이벤트',
      section: 'event',
      count: _eventTotal,
      items: _events.map(_buildEventListRow).toList(),
      hasMore: _eventHasMore,
    );
    addSection(
      title: '공지사항',
      section: 'announcement',
      count: _announcementTotal,
      items: _announcements.map(_buildAnnouncementListRow).toList(),
      hasMore: _announcementHasMore,
    );
    addSection(
      title: '콘텐츠',
      section: 'content',
      count: _contentTotal,
      items: _content.map(_buildContentListRow).toList(),
      hasMore: _contentHasMore,
    );

    return children;
  }

  Widget _buildSectionHeader(String title, int count) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: _hPad(context),
        vertical: healthDp(context, 8),
      ),
      decoration: const BoxDecoration(
        color: _sectionBg,
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: title,
              style: TextStyle(
                color: _titleDark,
                fontSize: healthSp(context, 12),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: ' ($count개)',
              style: TextStyle(
                color: _muted,
                fontSize: healthSp(context, 12),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreButton(String section) {
    final loading = _loadingSection == section;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _hPad(context),
        healthDp(context, 4),
        _hPad(context),
        healthDp(context, 12),
      ),
      child: TextButton(
        onPressed: loading ? null : () => _loadMore(section),
        style: TextButton.styleFrom(
          foregroundColor: _pink,
          overlayColor: Colors.transparent,
          minimumSize: Size(double.infinity, healthDp(context, 36)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: loading
            ? SizedBox(
                width: healthDp(context, 16),
                height: healthDp(context, 16),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _pink,
                ),
              )
            : Text(
                '더보기',
                style: TextStyle(
                  color: _pink,
                  fontSize: healthSp(context, 13),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }

  double _rowImageSize(BuildContext context) => healthDp(context, 72);

  Widget _imageFallback(BuildContext context, IconData icon) {
    return Container(
      color: _rowBorder,
      alignment: Alignment.center,
      child: Icon(
        icon,
        color: Colors.grey.shade400,
        size: healthDp(context, 28),
      ),
    );
  }

  Widget _buildProductListRow(Product product, {required bool general}) {
    final title = stripProductCatalogHtml(product.name);
    final imageSize = _rowImageSize(context);
    final radius = healthDp(context, 4);

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _openProduct(product, general: general),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: _hPad(context),
            vertical: healthDp(context, 10),
          ),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0x80D2D2D2), width: 1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: SizedBox(
                  width: imageSize,
                  height: imageSize,
                  child: _SearchRowImage(
                    url: product.displayImageUrl,
                    size: imageSize,
                    fallback: _imageFallback(context, Icons.image_not_supported),
                  ),
                ),
              ),
              SizedBox(width: healthDp(context, 10)),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: const Color(0xFF1A1A1E),
                        fontSize: healthSp(context, 14),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        letterSpacing: healthSp(context, -0.56),
                        height: 1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: healthDp(context, 6)),
                    Text(
                      product.formattedPrice,
                      style: TextStyle(
                        color: const Color(0xFF1A1A1E),
                        fontSize: healthSp(context, 14),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbListRow({
    required String title,
    String? imageUrl,
    IconData fallbackIcon = Icons.article_outlined,
    required VoidCallback onTap,
  }) {
    final imageSize = _rowImageSize(context);
    final radius = healthDp(context, 4);

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: _hPad(context),
            vertical: healthDp(context, 10),
          ),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: _rowBorder, width: 1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: SizedBox(
                  width: imageSize,
                  height: imageSize,
                  child: imageUrl == null || imageUrl.isEmpty
                      ? _imageFallback(context, fallbackIcon)
                      : _SearchRowImage(
                          url: imageUrl,
                          size: imageSize,
                          fallback: _imageFallback(context, fallbackIcon),
                        ),
                ),
              ),
              SizedBox(width: healthDp(context, 10)),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: const Color(0xFF1A1A1E),
                        fontSize: healthSp(context, 14),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        letterSpacing: healthSp(context, -0.56),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventListRow(EventModel event) {
    return _buildThumbListRow(
      title: event.wrSubject,
      imageUrl: event.getImageUrl(),
      fallbackIcon: Icons.celebration_outlined,
      onTap: () => _openEvent(event),
    );
  }

  Widget _buildAnnouncementListRow(AnnouncementModel item) {
    final imagePath = item.imagePath?.trim();
    return _buildThumbListRow(
      title: item.title,
      imageUrl: imagePath != null && imagePath.isNotEmpty
          ? ImageUrlHelper.getImageUrl(imagePath)
          : null,
      fallbackIcon: Icons.campaign_outlined,
      onTap: () => _openAnnouncement(item),
    );
  }

  Widget _buildContentListRow(ContentPost item) {
    final title = item.title;
    return _buildThumbListRow(
      title: title,
      imageUrl: _contentThumb(item),
      onTap: () => _openContent(item),
    );
  }

  Widget _buildGlobalEmptyContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CenteredEmptyState.assetIcon(context, AppAssets.searchEmptyIcon),
        SizedBox(height: healthDp(context, 10)),
        Text(
          '검색 결과가 없습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFFC0C0C0),
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: healthDp(context, 10)),
        Text(
          '검색어를 다시 입력해주세요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFFC0C0C0),
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildResultCountRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: healthDp(context, 1), color: _border),
        SizedBox(height: healthDp(context, 5)),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '총 ',
                style: TextStyle(
                  color: _muted,
                  fontSize: healthSp(context, 12),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextSpan(
                text: '$_total',
                style: TextStyle(
                  color: _pink,
                  fontSize: healthSp(context, 12),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextSpan(
                text: '건',
                style: TextStyle(
                  color: _muted,
                  fontSize: healthSp(context, 12),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: healthDp(context, 5)),
        Container(height: healthDp(context, 1), color: _border),
      ],
    );
  }

  Widget _buildSearchBar() {
    return HealthFocusOutlineBox(
      height: healthDp(context, 34),
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
      borderRadius: healthDp(context, 10),
      fillColor: Colors.white,
      builder: (focusNode) => Row(
        children: [
          Expanded(
            child: TextField(
              controller: _queryController,
              focusNode: focusNode,
              onSubmitted: (s) => _commitSearch(s),
              style: TextStyle(
                color: const Color(0xFF333333),
                fontSize: healthSp(context, 14),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: '검색',
                hintStyle: TextStyle(
                  color: _muted,
                  fontSize: healthSp(context, 14),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                ),
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          GestureDetector(
            onTap: () => _commitSearch(_queryController.text),
            behavior: HitTestBehavior.opaque,
            child: SvgPicture.asset(
              AppAssets.searchIcon,
              width: healthDp(context, 24),
              height: healthDp(context, 24),
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  String _contentThumb(ContentPost item) {
    return ContentService.resolveThumbnailUrl(item.thumbnailUrl, fallback: '');
  }
}

class _SearchRowImage extends StatefulWidget {
  const _SearchRowImage({
    required this.url,
    required this.size,
    required this.fallback,
  });

  final String url;
  final double size;
  final Widget fallback;

  @override
  State<_SearchRowImage> createState() => _SearchRowImageState();
}

class _SearchRowImageState extends State<_SearchRowImage> {
  late String _url;
  var _usedOriginal = false;

  @override
  void initState() {
    super.initState();
    _url = _thumbUrl(widget.url);
  }

  @override
  void didUpdateWidget(covariant _SearchRowImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _usedOriginal = false;
      _url = _thumbUrl(widget.url);
    }
  }

  /// 목록 칸은 72px. 수 MB 원본 대신 가로 160px만 받는다.
  String _thumbUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return ImageUrlHelper.contentListThumbUrl(trimmed, width: 160);
  }

  String _originalUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final direct = ImageUrlHelper.browserImageSrc(trimmed);
    return direct.isEmpty ? trimmed : direct;
  }

  @override
  Widget build(BuildContext context) {
    if (_url.isEmpty) return widget.fallback;
    return AppNetworkImage(
      url: _url,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
      decodeWidthLogical: 72,
      decodeHeightLogical: 72,
      preferHtmlElementOnWeb: true,
      errorBuilder: (_, __, ___) {
        final original = _originalUrl(widget.url);
        if (!_usedOriginal && original.isNotEmpty && original != _url) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _usedOriginal = true;
              _url = original;
            });
          });
          return const SizedBox.shrink();
        }
        return widget.fallback;
      },
    );
  }
}
