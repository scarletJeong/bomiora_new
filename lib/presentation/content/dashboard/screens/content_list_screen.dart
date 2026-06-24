import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../data/services/content_service.dart';
import '../../../../data/services/category_service.dart';
import '../../../common/widgets/app_bar_menu.dart';
import '../../../common/widgets/appbar_menutap.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/navi_bar.dart';
import '../../../common/widgets/app_footer.dart';
import '../../../health/health_common/health_responsive_scale.dart';

/// 콘텐츠 목록 (카테고리 칩, 검색, 리스트, 글쓰기 FAB)
class ContentListScreen extends StatefulWidget {
  const ContentListScreen({super.key});

  @override
  State<ContentListScreen> createState() => _ContentListScreenState();
}

class _ContentListScreenState extends State<ContentListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _textMuted = Color(0xFF898686);
  static const Color _pink = Color(0xFFFF5B8C);
  static const Color _chipInactive = Color(0xFF898686);

  int _tabIndex = 0;
  bool _appliedRouteCategory = false;
  String? _requestedCategoryName;
  late final Future<List<String>> _categoriesFuture = _loadCategories();
  final TextEditingController _searchController = TextEditingController();
  List<String> _categories = const [];
  List<Map<String, dynamic>> _posts = const [];
  int _totalCount = 0;
  bool _isLoading = true;

  Future<List<String>> _loadCategories() async {
    final result = await CategoryService.getCategoriesByGroup('content');
    final dynamic list = result['categories'];
    if (result['success'] == true && list is List && list.isNotEmpty) {
      final categories = list
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (categories.isNotEmpty) {
        return categories;
      }
    }
    return const [];
  }

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

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    final selectedCategory = (_tabIndex > 0 && _tabIndex - 1 < _categories.length)
        ? _categories[_tabIndex - 1]
        : null;
    final result = await ContentService.getContentList(
      size: 50,
      category: selectedCategory,
      query: _searchController.text,
    );
    if (!mounted) return;
    final data = (result['data'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
        const <Map<String, dynamic>>[];
    final pagination = result['pagination'] as Map<String, dynamic>? ?? const {};
    final total = pagination['total'] is num
        ? (pagination['total'] as num).toInt()
        : data.length;
    setState(() {
      _posts = data;
      _totalCount = total;
      _isLoading = false;
    });
  }

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
    final textScale =
        healthTextScaleByWidth(MediaQuery.sizeOf(context).width);

    return Theme(
      data: gmarketTheme,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: MobileAppLayoutWrapper(
          scaffoldKey: _scaffoldKey,
          appBar: AppBarMenu(
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
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(top: healthDp(context, 10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: healthDp(context, 27),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildCategoryChips(_categories),
                            SizedBox(height: healthDp(context, 10)),
                            _buildSearchBox(),
                            SizedBox(height: healthDp(context, 10)),
                            _buildCountRow(),
                            SizedBox(height: healthDp(context, 10)),
                            if (_isLoading)
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: healthDp(context, 40)),
                                child: Center(
                                  child: SizedBox(
                                    width: healthDp(context, 36),
                                    height: healthDp(context, 36),
                                    child: const CircularProgressIndicator(
                                      color: Color(0xFFFF5B8C),
                                    ),
                                  ),
                                ),
                              )
                            else if (_posts.isEmpty)
                              _buildEmptySearchResult(context)
                            else
                              ..._posts.map((e) => Padding(
                                    padding: EdgeInsets.only(
                                        bottom: healthDp(context, 20)),
                                    child: _buildListCard(context, e),
                                  )),
                            SizedBox(height: healthDp(context, 24)),
                            SizedBox(height: healthDp(context, 100)),
                          ],
                        ),
                      ),
                      const AppFooter(),
                    ],
                  ),
                ),
              ),
              const FooterBar(),
            ],
          ),
        ),
      ),
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
                if (i > 0)
                  SizedBox(width: healthDp(context, i == 1 ? 10 : 14)),
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
            vertical: healthDp(context, 2),
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
              fontWeight: FontWeight.w500,
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

  Widget _buildEmptySearchResult(BuildContext context) {
    final iconSz = healthDp(context, 80);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: healthDp(context, 40)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset(
            AppAssets.searchEmptyIcon,
            width: iconSz,
            height: iconSz,
            fit: BoxFit.contain,
          ),
          SizedBox(height: healthDp(context, 10)),
          Text(
            '검색 결과가 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF1A1A1E),
              fontSize: healthSp(context, 16),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 5)),
          Text(
            '검색어를 다시 입력해주세요.',
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
    );
  }

  Widget _buildSearchBox() {
    final iconSz = healthDp(context, 18);
    return Container(
      width: double.infinity,
      height: healthDp(context, 38),
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 12)),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: const Color(0xFFD2D2D2),
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 20)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _onSearchSubmitted(),
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
          GestureDetector(
            onTap: _onSearchSubmitted,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.all(healthDp(context, 4)),
              child: SvgPicture.asset(
                AppAssets.searchIcon,
                width: iconSz,
                height: iconSz,
                fit: BoxFit.contain,
              ),
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
                  fontWeight: FontWeight.w700,
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

  Widget _buildListCard(BuildContext context, Map<String, dynamic> item) {
    final idRaw = item['id'];
    final contentId = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw');
    final title = item['title']?.toString().trim() ?? '';
    final imageUrl = _resolveContentImageUrl(
      thumbnail: item['thumbnail_url'],
      contentHtml: item['content_html'],
    );
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
            child: SizedBox(
              height: healthDp(context, 200),
              width: double.infinity,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
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
          Padding(
            padding: EdgeInsets.symmetric(vertical: healthDp(context, 10)),
            child: Text(
              title,
              style: TextStyle(
                color: _textDark,
                fontSize: healthSp(context, 14),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                height: 0.94,
                letterSpacing: -1.26,
              ),
            ),
          ),
        ],
      ),
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
