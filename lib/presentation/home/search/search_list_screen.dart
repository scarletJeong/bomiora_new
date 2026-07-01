import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/announcement/announcement_model.dart';
import '../../../data/models/event/event_model.dart';
import '../../../data/models/product/product_model.dart';
import '../../../data/services/content_service.dart';
import '../../../data/services/search_service.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/product_card.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';

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
  static const Color _priceDark = Color(0xFF111827);

  late final TextEditingController _queryController;
  Timer? _debounce;

  List<Product> _rx = const [];
  List<Product> _store = const [];
  List<EventModel> _events = const [];
  List<AnnouncementModel> _announcements = const [];
  List<Map<String, dynamic>> _content = const [];
  bool _loading = true;
  bool _initialLoad = true;
  String? _error;

  double _hPad(BuildContext context) => healthDp(context, 16);

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery.trim());
    _queryController.addListener(_onQueryChanged);
    _runSearch(_queryController.text);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _runSearch(_queryController.text);
    });
  }

  Future<void> _runSearch(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) {
      setState(() {
        _rx = const [];
        _store = const [];
        _events = const [];
        _announcements = const [];
        _content = const [];
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
      final result = await SearchService.searchAll(q);
      if (!mounted) return;
      setState(() {
        _rx = result.prescriptionProducts;
        _store = result.storeProducts;
        _events = result.events;
        _announcements = result.announcements;
        _content = result.contents;
        _loading = false;
        _initialLoad = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _initialLoad = false;
        _error = e.toString();
      });
    }
  }

  int get _total =>
      _rx.length +
      _store.length +
      _events.length +
      _announcements.length +
      _content.length;

  void _openEvent(EventModel event) {
    Navigator.pushNamed(context, '/event/${event.wrId}');
  }

  void _openAnnouncement(AnnouncementModel item) {
    Navigator.pushNamed(context, '/announcement/${item.id}');
  }

  void _openProduct(Product p, {required bool general}) {
    final route = general ? '/product-general/${p.id}' : '/product/${p.id}';
    Navigator.pushNamed(context, route);
  }

  void _openContent(Map<String, dynamic> item) {
    final idRaw = item['id'];
    final id = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw');
    if (id == null) return;
    final cat = (item['category'] ?? '').toString().trim();
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
      appBar: const HealthAppBar(title: '검색', centerTitle: false),
      child: _initialLoad && _loading
          ? const Center(child: CircularProgressIndicator(color: _pink))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(healthDp(context, 24)),
                    child: Text(
                      '검색 중 오류가 발생했습니다.\n$_error',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: healthSp(context, 14),
                        color: _muted,
                        fontFamily: 'Gmarket Sans TTF',
                      ),
                    ),
                  ),
                )
              : _buildResults(),
    );
  }

  Widget _buildResults() {
    return CustomScrollView(
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
        else if (_total == 0)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildGlobalEmptyContent(),
          )
        else
          SliverPadding(
            padding: EdgeInsets.only(
              top: healthDp(context, 5),
              bottom: healthDp(context, 24),
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                _buildGroupedListChildren(),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildGroupedListChildren() {
    final children = <Widget>[];

    void addSection({
      required String title,
      required List<Widget> items,
    }) {
      if (items.isEmpty) return;
      children.add(_buildSectionHeader(title, items.length));
      children.addAll(items);
    }

    addSection(
      title: '비대면 진료',
      items: _rx
          .map((p) => _buildProductListRow(p, general: false))
          .toList(),
    );
    addSection(
      title: '스토어',
      items: _store
          .map((p) => _buildProductListRow(p, general: true))
          .toList(),
    );
    addSection(
      title: '이벤트',
      items: _events.map(_buildEventListRow).toList(),
    );
    addSection(
      title: '공지사항',
      items: _announcements.map(_buildAnnouncementListRow).toList(),
    );
    addSection(
      title: '콘텐츠',
      items: _content.map(_buildContentListRow).toList(),
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
        border: Border(
          top: BorderSide(color: _rowBorder, width: 1),
          bottom: BorderSide(color: _rowBorder, width: 1),
        ),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: title,
              style: TextStyle(
                color: _titleDark,
                fontSize: healthSp(context, 14),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: ' ($count개)',
              style: TextStyle(
                color: _muted,
                fontSize: healthSp(context, 14),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _rowImageSize(BuildContext context) => healthDp(context, 72);

  Widget _buildProductListRow(Product product, {required bool general}) {
    final title = stripProductCatalogHtml(product.name);
    final imageSize = _rowImageSize(context);
    final radius = healthDp(context, 6);

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _openProduct(product, general: general),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: SizedBox(
                  width: imageSize,
                  height: imageSize,
                  child: Image.network(
                    product.displayImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: _rowBorder,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey.shade400,
                        size: healthDp(context, 28),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: healthDp(context, 10)),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: healthDp(context, 4)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: _titleDark,
                          fontSize: healthSp(context, 13),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: healthDp(context, 4)),
                      Text(
                        product.formattedPrice,
                        style: TextStyle(
                          color: _priceDark,
                          fontSize: healthSp(context, 12),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
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
    String? subtitle,
    String? imageUrl,
    IconData fallbackIcon = Icons.article_outlined,
    required VoidCallback onTap,
  }) {
    final imageSize = _rowImageSize(context);
    final radius = healthDp(context, 6);

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: SizedBox(
                  width: imageSize,
                  height: imageSize,
                  child: imageUrl == null || imageUrl.isEmpty
                      ? Container(
                          color: _rowBorder,
                          alignment: Alignment.center,
                          child: Icon(
                            fallbackIcon,
                            color: Colors.grey.shade400,
                            size: healthDp(context, 28),
                          ),
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: _rowBorder,
                            alignment: Alignment.center,
                            child: Icon(
                              fallbackIcon,
                              color: Colors.grey.shade400,
                              size: healthDp(context, 28),
                            ),
                          ),
                        ),
                ),
              ),
              SizedBox(width: healthDp(context, 16)),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: healthDp(context, 4)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: _titleDark,
                          fontSize: healthSp(context, 13),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        SizedBox(height: healthDp(context, 4)),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: _muted,
                            fontSize: healthSp(context, 11),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
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
      subtitle: DateDisplayFormatter.formatYmdFromString(event.wrDatetime),
      imageUrl: event.getImageUrl(),
      fallbackIcon: Icons.celebration_outlined,
      onTap: () => _openEvent(event),
    );
  }

  Widget _buildAnnouncementListRow(AnnouncementModel item) {
    final imagePath = item.imagePath?.trim();
    return _buildThumbListRow(
      title: item.title,
      subtitle: DateDisplayFormatter.formatYmdFromString(item.createdAtRaw),
      imageUrl: imagePath != null && imagePath.isNotEmpty
          ? ImageUrlHelper.getImageUrl(imagePath)
          : null,
      fallbackIcon: Icons.campaign_outlined,
      onTap: () => _openAnnouncement(item),
    );
  }

  Widget _buildContentListRow(Map<String, dynamic> item) {
    final title = item['title']?.toString().trim() ?? '';
    return _buildThumbListRow(
      title: title,
      imageUrl: _contentThumb(item),
      onTap: () => _openContent(item),
    );
  }

  Widget _buildGlobalEmptyContent() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _hPad(context),
        healthDp(context, 20),
        _hPad(context),
        healthDp(context, 20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            AppAssets.searchEmptyIcon,
            width: healthDp(context, 80),
            height: healthDp(context, 80),
            fit: BoxFit.contain,
          ),
          SizedBox(height: healthDp(context, 10)),
          Text(
            '검색 결과가 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ink,
              fontSize: healthSp(context, 16),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '검색어를 다시 입력해주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: healthSp(context, 14),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: '개',
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
    return Container(
      height: healthDp(context, 34),
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 12)),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(healthDp(context, 8)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _queryController,
              onSubmitted: (s) => _runSearch(s),
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
                  fontWeight: FontWeight.w400,
                ),
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          GestureDetector(
            onTap: () => _runSearch(_queryController.text),
            behavior: HitTestBehavior.opaque,
            child: SvgPicture.asset(
              AppAssets.searchIcon,
              width: healthDp(context, 18),
              height: healthDp(context, 18),
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  String _contentThumb(Map<String, dynamic> item) {
    final raw = item['thumbnail_url']?.toString();
    final thumb = ContentService.resolveThumbnailUrl(raw, fallback: '');
    if (thumb.isNotEmpty) return thumb;
    return ContentService.resolveDisplayImageUrl(
      thumbnail: raw,
      contentHtml: item['content_html']?.toString(),
      fallback: '${ImageUrlHelper.imageBaseUrl}/data/item/no_img.png',
    );
  }
}
