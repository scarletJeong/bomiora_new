import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../data/repositories/content/content_category_catalog.dart';
import '../../../../data/services/content_service.dart';
import '../../../common/widgets/appbar_menutap.dart';
import '../../../common/widgets/app_network_image.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../../../common/widgets/centered_empty_state.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/navi_bar.dart';
import '../../../common/widgets/app_footer.dart';
import '../../../common/widgets/scroll_reveal_top_overlay.dart';
import '../../../health/health_common/health_responsive_scale.dart';

/// 콘텐츠 목록 (카테고리 칩, 검색, 리스트, 글쓰기 FAB)
class ContentListScreen extends StatefulWidget {
  const ContentListScreen({super.key});

  @override
  State<ContentListScreen> createState() => _ContentListScreenState();
}

class _ContentListScreenState extends State<ContentListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();

  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _textMuted = Color(0xFF898686);
  static const Color _pink = Color(0xFFFF5B8C);
  static const Color _chipInactive = Color(0xFF898686);

  int _tabIndex = 0;
  bool _appliedRouteCategory = false;
  String? _requestedCategoryName;
  late final Future<List<String>> _categoriesFuture =
      ContentCategoryCatalog.categories();
  final TextEditingController _searchController = TextEditingController();
  List<String> _categories = const [];
  List<Map<String, dynamic>> _posts = const [];
  int _totalCount = 0;
  int _page = 1;
  static const int _pageSize = 5;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _imageWaitId = 0;
  int _pendingImages = 0;
  int _settledImages = 0;

  @override
  void initState() {
    super.initState();
    _categoriesFuture.then((categories) {
      if (!mounted) return;
      setState(() {
        _categories = categories;
      });
      _applyRequestedCategory();
      _loadPosts();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedRouteCategory) return;
    _appliedRouteCategory = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      final selectedCategory = args['category']?.toString().trim();
      if (selectedCategory != null && selectedCategory.isNotEmpty) {
        _requestedCategoryName = selectedCategory;
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _applyRequestedCategory() {
    if (_requestedCategoryName == null) return;
    final index = _categories.indexOf(_requestedCategoryName!);
    if (index >= 0) {
      _tabIndex = index + 1;
    }
    _requestedCategoryName = null;
  }

  Future<void> _loadPosts({bool reset = true}) async {
    final waitId = reset ? ++_imageWaitId : _imageWaitId;
    if (reset) {
      setState(() {
        _isLoading = true;
        _page = 1;
        _pendingImages = 0;
        _settledImages = 0;
      });
    } else {
      if (_isLoadingMore || _posts.length >= _totalCount) return;
      setState(() => _isLoadingMore = true);
    }

    final selectedCategory =
        (_tabIndex > 0 && _tabIndex - 1 < _categories.length)
            ? _categories[_tabIndex - 1]
            : null;
    final nextPage = reset ? 1 : _page + 1;
    final result = await ContentService.getContentList(
      page: nextPage,
      size: _pageSize,
      category: selectedCategory,
      query: _searchController.text,
    );
    if (!mounted || waitId != _imageWaitId) return;
    final data =
        (result['data'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
            const <Map<String, dynamic>>[];
    final pagination =
        result['pagination'] as Map<String, dynamic>? ?? const {};
    final total = pagination['total'] is num
        ? (pagination['total'] as num).toInt()
        : data.length;
    final imageCount = reset
        ? data.where((item) => _imageUrlOf(item).isNotEmpty).length
        : 0;
    setState(() {
      if (reset) {
        _posts = data;
        _page = 1;
        _pendingImages = imageCount;
        _settledImages = 0;
        _isLoading = imageCount > 0;
      } else {
        _posts = [..._posts, ...data];
        _page = nextPage;
        _isLoading = false;
      }
      _totalCount = total;
      _isLoadingMore = false;
    });
    if (reset && imageCount > 0) {
      Future<void>.delayed(const Duration(seconds: 20), () {
        if (!mounted || waitId != _imageWaitId || !_isLoading) return;
        setState(() => _isLoading = false);
      });
    }
  }

  void _onListImageSettled(int waitId) {
    if (waitId != _imageWaitId) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || waitId != _imageWaitId || !_isLoading) return;
      _settledImages += 1;
      if (_settledImages >= _pendingImages) {
        setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _loadMorePosts() async {
    await _loadPosts(reset: false);
  }

  bool get _showLoadMore =>
      !_isLoading && _posts.isNotEmpty && _posts.length < _totalCount;

  Future<void> _onSearchSubmitted() async {
    await _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );
    final textScale = healthTextScaleByWidth(MediaQuery.sizeOf(context).width);

    return Theme(
      data: gmarketTheme,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: MobileAppLayoutWrapper(
          resizeToAvoidBottomInset: false,
          scaffoldKey: _scaffoldKey,
          appBar: HealthAppBar.logo(
            onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          drawer: AppBarMenuTapDrawer(
            onHealthDashboardTap: () {
              Navigator.pushReplacementNamed(context, '/health');
            },
          ),
          backgroundColor: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ScrollRevealTopOverlay(
                      controller: _scrollController,
                      revealAfterOffset: healthDp(context, 80),
                      topBar: _buildTopControls(),
                      scrollChild: _buildContentScroll(),
                    ),
                    if (_isLoading && _posts.isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: _topControlsExtent(context),
                        bottom: 0,
                        child: const ColoredBox(
                          color: Colors.white,
                          child: Center(
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                color: Color(0xFFFF5B8C),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!_isLoading && _posts.isEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: _topControlsExtent(context),
                        bottom: 0,
                        child: IgnorePointer(
                          child: Center(
                            child: _hasActiveSearch
                                ? _buildEmptySearchResult(context)
                                : _buildEmptyPostsState(context),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const FooterBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 20),
        healthDp(context, 0),
        healthDp(context, 20),
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchBox(),
          SizedBox(height: healthDp(context, 20)),
          _buildCategoryChips(_categories),
          SizedBox(height: healthDp(context, 10)),
          _buildCountRow(),
          SizedBox(height: healthDp(context, 20)),
        ],
      ),
    );
  }

  Widget _buildContentScroll() {
    return CustomScrollView(
      controller: _scrollController,
      cacheExtent: _isLoading ? 8000 : null,
      slivers: [
        SliverToBoxAdapter(child: _buildTopControls()),
        if (_isLoading && _posts.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: Color(0xFFFF5B8C),
                ),
              ),
            ),
          )
        else if (_posts.isEmpty && !_isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: SizedBox.shrink(),
          )
        else ...[
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 20),
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: EdgeInsets.only(bottom: healthDp(context, 32)),
                  child: _buildListCard(
                    context,
                    _posts[index],
                    waitForImage: _isLoading,
                  ),
                ),
                childCount: _posts.length,
              ),
            ),
          ),
          if (_showLoadMore)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                healthDp(context, 20),
                0,
                healthDp(context, 20),
                0,
              ),
              sliver: SliverToBoxAdapter(child: _buildLoadMoreButton()),
            ),
          SliverToBoxAdapter(child: SizedBox(height: healthDp(context, 48))),
          const SliverToBoxAdapter(child: AppFooter()),
        ],
      ],
    );
  }

  Widget _buildCategoryChips(List<String> categories) {
    final tabs = ['전체', ...categories];

    return SizedBox(
      height: healthDp(context, 30),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: EdgeInsets.only(top: healthDp(context, 3)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < tabs.length; i++) ...[
                if (i > 0) SizedBox(width: healthDp(context, 10)),
                _buildTabChip(
                  label: tabs[i],
                  selected: i == _tabIndex,
                  onTap: () async {
                    setState(() => _tabIndex = i);
                    await _loadPosts();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    if (selected) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 10),
            vertical: healthDp(context, 4),
          ),
          decoration: ShapeDecoration(
            color: _pink,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(healthDp(context, 20)),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: healthSp(context, 14),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.only(bottom: healthDp(context, 3)),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _chipInactive,
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  bool get _hasActiveSearch => _searchController.text.trim().isNotEmpty;

  /// 검색·칩·건수 높이. 빈 안내를 그 아래 영역의 가운데에 둔다.
  double _topControlsExtent(BuildContext context) {
    final countText = healthSp(context, 12);
    return healthDp(context, 46.15) +
        healthDp(context, 20) +
        healthDp(context, 30) +
        healthDp(context, 10) +
        healthDp(context, 1) +
        healthDp(context, 5) +
        countText +
        healthDp(context, 5) +
        healthDp(context, 1) +
        healthDp(context, 20);
  }

  Widget _buildEmptyPostsState(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenteredEmptyState.assetIcon(
          context,
          AppAssets.emptyContentIcon,
          slot: 58,
        ),
        SizedBox(height: healthDp(context, 15)),
        Text(
          '등록된 게시글이 없습니다.',
          textAlign: TextAlign.center,
          textScaler: TextScaler.noScaling,
          style: CenteredEmptyState.defaultMessageStyle(context),
        ),
      ],
    );
  }

  Widget _buildEmptySearchResult(BuildContext context) {
    return CenteredEmptyState(
      iconWidget: CenteredEmptyState.assetIcon(
        context,
        AppAssets.emptySearchIcon,
      ),
      message: '검색 결과가 없습니다.',
      trailing: [
        Text(
          '검색어를 다시 입력해주세요.',
          textAlign: TextAlign.center,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: const Color(0xFF898686),
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBox() {
    final iconSz = healthDp(context, 18);
    return Container(
      width: double.infinity,
      height: healthDp(context, 46.15),
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 14)),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: const Color(0xFFD2D2D2),
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 12)),
        ),
      ),
      alignment: Alignment.center,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _onSearchSubmitted(),
              cursorColor: _pink,
              decoration: InputDecoration(
                hintText: '검색',
                hintStyle: TextStyle(
                  color: _textMuted,
                  fontSize: healthSp(context, 14),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hoverColor: Colors.transparent,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(
                color: _textDark,
                fontSize: healthSp(context, 14),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          SizedBox(width: healthDp(context, 5)),
          GestureDetector(
            onTap: _onSearchSubmitted,
            behavior: HitTestBehavior.opaque,
            child: SvgPicture.asset(
              AppAssets.searchIcon,
              width: iconSz,
              height: iconSz,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountRow() {
    final dividerH = healthDp(context, 1);
    final countStyle = TextStyle(
      color: _textMuted,
      fontSize: healthSp(context, 12),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w500,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: dividerH, color: const Color(0x7FD2D2D2)),
        SizedBox(height: healthDp(context, 5)),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '총 ', style: countStyle),
              TextSpan(
                text: '$_totalCount',
                style: TextStyle(
                  color: const Color(0xFFFF5A8D),
                  fontSize: healthSp(context, 12),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextSpan(text: '건', style: countStyle),
            ],
          ),
        ),
        SizedBox(height: healthDp(context, 5)),
        Container(height: dividerH, color: const Color(0x7FD2D2D2)),
      ],
    );
  }

  Widget _buildLoadMoreButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoadingMore ? null : _loadMorePosts,
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
        child: Container(
          width: double.infinity,
          height: healthDp(context, 40),
          padding: EdgeInsets.all(healthDp(context, 10)),
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: healthDp(context, 0.5),
                color: const Color(0xFFD2D2D2),
              ),
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_isLoadingMore)
                SizedBox(
                  width: healthDp(context, 18),
                  height: healthDp(context, 18),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFF5B8C),
                  ),
                )
              else
                Text(
                  '더보기',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF898686),
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListCard(
    BuildContext context,
    Map<String, dynamic> item, {
    bool waitForImage = false,
  }) {
    final idRaw = item['id'];
    final contentId = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw');
    final title = item['title']?.toString().trim() ?? '';
    final imageUrl = _imageUrlOf(item);
    final waitId = _imageWaitId;
    return GestureDetector(
      onTap: () {
        if (contentId == null) return;
        final cat = (item['category'] ?? '').toString().trim();
        Navigator.pushNamed(
          context,
          '/content/detail',
          arguments: {
            'id': contentId,
            if (cat.isNotEmpty) 'category': cat,
          },
        );
      },
      behavior: HitTestBehavior.opaque,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 375에서 좌우 여백 20을 뺀 335 중 이미지는 321.
          // 화면이 넓어지면 그 비율 그대로 커진다.
          final available = constraints.maxWidth;
          final imageW = available * (321 / 335);
          final imageH = imageW * (200 / 321);
          return Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: imageW,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(healthDp(context, 10)),
                    child: SizedBox(
                      height: imageH,
                      width: imageW,
                      child: AppNetworkImage(
                        url: imageUrl,
                        fit: BoxFit.cover,
                        width: imageW,
                        height: imageH,
                        decodeWidthLogical: imageW,
                        onSettled: waitForImage && imageUrl.isNotEmpty
                            ? () => _onListImageSettled(waitId)
                            : null,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFF2F2F2),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: healthDp(context, 40),
                            color: const Color(0xFFBDBDBD),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: healthDp(context, 12)),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _textDark,
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                      letterSpacing: healthSp(context, -1.26),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _imageUrlOf(Map<String, dynamic> item) {
    return _resolveContentImageUrl(
      thumbnail: item['thumbnail_url'],
      contentHtml: item['content_html'],
    );
  }

  String _resolveContentImageUrl({
    required dynamic thumbnail,
    required dynamic contentHtml,
  }) {
    final rawThumbnail = thumbnail?.toString();
    final resolvedThumbnail = ContentService.resolveThumbnailUrl(
      rawThumbnail,
      fallback: '',
    );
    if (resolvedThumbnail.isNotEmpty) {
      return resolvedThumbnail;
    }
    return ContentService.resolveDisplayImageUrl(
      thumbnail: rawThumbnail,
      contentHtml: contentHtml?.toString(),
      fallback: ImageUrlHelper.placeholdCo(321, 200),
    );
  }
}
