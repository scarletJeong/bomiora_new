import 'package:flutter/material.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../core/utils/node_value_parser.dart';
import '../../../../data/services/wish_service.dart';
import '../../../../data/services/content_service.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/centered_empty_state.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';

class WishListScreen extends StatefulWidget {
  const WishListScreen({super.key});

  @override
  State<WishListScreen> createState() => _WishListScreenState();
}

class _WishListScreenState extends State<WishListScreen> {
  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _border = Color(0x7FD2D2D2);
  static const Color _divider = Color(0xFFD2D2D2);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _textMuted = Color(0xFF898686);
  static const Color _textSub = Color(0xFF898383);
  static const Color _chipFill = Color(0x0CFF5A8D);

  static const int _pageSize = 5;

  List<Map<String, dynamic>> _wishList = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _requiresLogin = false;
  int _visibleCount = _pageSize;
  /// 0: 비대면 진료, 1: 스토어, 2: 콘텐츠
  int _selectedTabIndex = 0;

  /// 콘텐츠 찜 항목 메타 캐시 (bm_content)
  final Map<int, Map<String, dynamic>> _contentCache = {};
  final Set<int> _contentLoadingIds = {};

  /// API `it_kind` 기준 — 비대면: prescription, 스토어: general (우선 it_kind)
  String _itKindLower(Map<String, dynamic> item) {
    return (NodeValueParser.asString(item['wi_it_kind']) ??
            NodeValueParser.asString(item['it_kind']) ??
            NodeValueParser.asString(item['product_kind']) ??
            NodeValueParser.asString(item['productKind']) ??
            NodeValueParser.asString(item['ct_kind']) ??
            '')
        .toLowerCase()
        .trim();
  }

  List<Map<String, dynamic>> get _telemedWishes => _wishList
      .where((e) => !_isContentWish(e) && _itKindLower(e) == 'prescription')
      .toList();

  /// 스토어: `general` + `it_kind` 비어 있음 + 그 외 prescription·콘텐츠가 아닌 상품(폴백)
  /// API에 `it_kind`가 없으면 여기로 모여 목록이 비지 않도록 함
  List<Map<String, dynamic>> get _storeWishes => _wishList
      .where((e) => !_isContentWish(e) && _itKindLower(e) != 'prescription')
      .toList();

  List<Map<String, dynamic>> get _contentWishes =>
      _wishList.where(_isContentWish).toList();

  List<Map<String, dynamic>> get _currentTabList {
    switch (_selectedTabIndex) {
      case 0:
        return _telemedWishes;
      case 1:
        return _storeWishes;
      case 2:
        return _contentWishes;
      default:
        return [];
    }
  }

  /// 콘텐츠 찜 — `wi_it_kind`·`product_kind` 또는 wish_type / wr_id / content_id
  bool _isContentWish(Map<String, dynamic> item) {
    if (_itKindLower(item) == 'content') return true;
    final wt = NodeValueParser.asString(item['wish_type']) ??
        NodeValueParser.asString(item['item_type']) ??
        '';
    if (wt.toLowerCase().contains('content')) return true;
    if (item['wr_id'] != null &&
        '${item['wr_id']}'.trim().isNotEmpty &&
        '${item['wr_id']}' != '0') {
      return true;
    }
    if (item['content_id'] != null &&
        '${item['content_id']}'.trim().isNotEmpty &&
        '${item['content_id']}' != '0') {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadWishList();
  }

  void _syncVisibleCount() {
    final n = _currentTabList.length;
    _visibleCount = n < _pageSize ? n : _pageSize;
  }

  Future<void> _loadWishList() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _requiresLogin = false;
    });

    try {
      final raw = await WishService.getWishList();
      if (!mounted) return;

      final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        _wishList = list;
        _isLoading = false;
        _syncVisibleCount();
      });
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      setState(() {
        if (message.contains('로그인')) {
          _requiresLogin = true;
          _errorMessage = null;
        } else {
          _errorMessage = '찜 목록을 불러오는데 실패했습니다: $e';
        }
        _isLoading = false;
      });
    }
  }

  void _loadMore() {
    setState(() {
      _visibleCount += _pageSize;
      final len = _currentTabList.length;
      if (_visibleCount > len) {
        _visibleCount = len;
      }
    });
  }

  Future<void> _removeWishItem(String productId) async {
    try {
      await WishService.removeFromWish(productId);
      if (!mounted) return;
      await _loadWishList();
    } catch (e) {
      if (!mounted) return;
    }
  }

  List<Map<String, dynamic>> get _visibleItems {
    final list = _currentTabList;
    if (list.isEmpty) return [];
    final end = _visibleCount > list.length ? list.length : _visibleCount;
    return list.sublist(0, end);
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );
    return Theme(
      data: gmarketTheme,
      child: MobileAppLayoutWrapper(
        appBar: HealthAppBar(
          title: '찜목록',
          titleFontSize: healthSp(context, 18),
          leadingIconSize: healthDp(context, 24),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
          child: ColoredBox(
            color: Colors.white,
            child: _isLoading
                ? Center(
                    child: SizedBox(
                      width: healthDp(context, 36),
                      height: healthDp(context, 36),
                      child: const CircularProgressIndicator(color: _pink),
                    ),
                  )
                : _requiresLogin
                    ? _buildLoginMessage()
                    : _errorMessage != null
                        ? _buildError()
                        : _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: healthDp(context, 27)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: TextStyle(
                  color: Colors.red, fontSize: healthSp(context, 14)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: healthDp(context, 16)),
            OutlinedButton(
              onPressed: _loadWishList,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginMessage() {
    return const CenteredEmptyState(
      icon: Icons.favorite_border,
      message: '로그인 후 이용 가능합니다.',
    );
  }

  String _emptyMessageForTab() {
    switch (_selectedTabIndex) {
      case 0:
        return '비대면 진료 찜 상품이 없습니다.';
      case 1:
        return '스토어 찜 상품이 없습니다.';
      case 2:
        return '찜한 콘텐츠가 없습니다.';
      default:
        return '찜한 항목이 없습니다.';
    }
  }

  Widget _buildContent() {
    final list = _currentTabList;
    final hasMore = _visibleCount < list.length;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: healthDp(context, 27),
            right: healthDp(context, 27),
            bottom: healthDp(context, 20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: healthDp(context, 15)),
              _buildTabs(),
              SizedBox(height: healthDp(context, 10)),
              _buildHeader(),
            ],
          ),
        ),
        if (list.isEmpty)
          Expanded(
            child: CenteredEmptyState(
              icon: Icons.favorite_border,
              message: _emptyMessageForTab(),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: healthDp(context, 27),
                right: healthDp(context, 27),
                bottom: healthDp(context, 20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: healthDp(context, 10)),
                  for (var i = 0; i < _visibleItems.length; i++) ...[
                    if (i > 0) SizedBox(height: healthDp(context, 20)),
                    _buildWishCard(_visibleItems[i]),
                  ],
                  if (hasMore) ...[
                    SizedBox(height: healthDp(context, 20)),
                    _buildLoadMoreButton(),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTabs() {
    final sepW = healthDp(context, 0.5);

    Widget vSep() => Container(
          width: sepW,
          height: healthDp(context, 11),
          color: _divider,
        );

    Widget tabCell({
      required int index,
      required String label,
    }) {
      final selected = _selectedTabIndex == index;
      return GestureDetector(
        onTap: () => setState(() {
          _selectedTabIndex = index;
          _syncVisibleCount();
        }),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: healthDp(context, 0),
            bottom: healthDp(context, 0),
          ),
          alignment: Alignment.center,
          child: Center(
            // 탭 영역은 Expanded로 넓게 유지하되, underline은 텍스트 폭만큼만 그려지게.
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? _pink : _textSub,
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 4)),
                  Container(
                    width: double.infinity,
                    height: healthDp(context, 1),
                    color: selected ? _pink : Colors.transparent,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: tabCell(index: 0, label: '비대면 진료')),
        vSep(),
        Expanded(child: tabCell(index: 1, label: '스토어')),
        vSep(),
        Expanded(child: tabCell(index: 2, label: '콘텐츠')),
      ],
    );
  }

  Widget _buildHeader() {
    final count = _currentTabList.length;
    final prefix = switch (_selectedTabIndex) {
      0 => '찜한 상품 ',
      1 => '찜한 상품 ',
      2 => '찜한 목록 ',
      _ => '찜한 항목 ',
    };
    final lineH = healthDp(context, 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: lineH, color: _divider),
        SizedBox(height: healthDp(context, 8)),
        RichText(
          text: TextSpan(
            style: TextStyle(
              color: _textMuted,
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              height: 1,
            ),
            children: [
              TextSpan(text: prefix),
              TextSpan(
                text: '$count',
                style: TextStyle(
                  color: const Color(0xFFFF5A8D),
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Gmarket Sans TTF',
                  fontSize: healthSp(context, 12),
                  height: 1,
                ),
              ),
              const TextSpan(text: '개'),
            ],
          ),
        ),
        SizedBox(height: healthDp(context, 5)),
        Container(height: lineH, color: _divider),
      ],
    );
  }

  Widget _buildWishCard(Map<String, dynamic> item) {
    if (_isContentWish(item)) {
      return _buildContentWishCard(item);
    }

    final productId = item['it_id']?.toString() ?? '';
    final productName = item['product_name']?.toString() ??
        item['it_name']?.toString() ??
        '';
    final subject = item['it_subject']?.toString() ?? '';
    final descriptionLine = (item['it_basic']?.toString() ?? '').trim();
    final productImage =
        item['image_url']?.toString() ?? item['it_img1']?.toString() ?? item['it_img']?.toString() ?? '';

    return SizedBox(
      width: double.infinity,
      child: Container(
          decoration: BoxDecoration(
            border: Border.all(
                width: healthDp(context, 1), color: _border),
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
            color: Colors.white,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: productId.isEmpty
                    ? null
                    : () {
                        Navigator.pushNamed(context, '/product/$productId');
                      },
                behavior: HitTestBehavior.opaque,
                child: AspectRatio(
                  aspectRatio: 1.45,
                  child: Image.network(
                    ImageUrlHelper.getImageUrl(productImage),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[100],
                        child: Center(
                          child: SizedBox(
                            width: healthDp(context, 28),
                            height: healthDp(context, 28),
                            child: CircularProgressIndicator(
                              strokeWidth: healthDp(context, 2),
                              color: _pink,
                            ),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[200],
                      child: Icon(
                        Icons.image_not_supported,
                        size: healthDp(context, 48),
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  top: healthDp(context, 10),
                  left: healthDp(context, 10),
                  right: healthDp(context, 10),
                  bottom: healthDp(context, 10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: productId.isEmpty
                          ? null
                          : () {
                              Navigator.pushNamed(context, '/product/$productId');
                            },
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject.trim().isNotEmpty ? subject.trim() : '보미오라',
                            style: TextStyle(
                              color: _textMain,
                              fontSize: healthSp(context, 12),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                          Text(
                            productName.isNotEmpty ? productName : '상품',
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: true,
                            ),
                            style: TextStyle(
                              color: _textMain,
                              fontSize: healthSp(context, 14),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.44,
                              height: 1.25,
                            ),
                          ),
                          if (descriptionLine.isNotEmpty) ...[
                            SizedBox(height: healthDp(context, 10)),
                            Text(
                              descriptionLine,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textSub,
                                fontSize: healthSp(context, 12),
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: healthDp(context, 20)),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: productId.isEmpty ? null : () => _removeWishItem(productId),
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 4)),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                              vertical: healthDp(context, 5)),
                          decoration: ShapeDecoration(
                            color: _chipFill,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(
                                  width: healthDp(context, 1), color: _pink),
                              borderRadius:
                                  BorderRadius.circular(healthDp(context, 4)),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.favorite,
                                size: healthDp(context, 20),
                                color: _pink.withValues(alpha: 0.9),
                              ),
                              SizedBox(width: healthDp(context, 5)),
                              Text(
                                '찜 해제',
                                style: TextStyle(
                                  color: _pink,
                                  fontSize: healthSp(context, 12),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }

  int? _contentIdFromWish(Map<String, dynamic> item) {
    final raw = item['content_id'] ?? item['wr_id'] ?? item['it_id'] ?? item['itId'];
    if (raw is num) return raw.toInt();
    return int.tryParse('${raw ?? ''}');
  }

  void _ensureContentLoaded(int contentId) {
    if (_contentCache.containsKey(contentId)) return;
    if (_contentLoadingIds.contains(contentId)) return;
    _contentLoadingIds.add(contentId);
    Future.microtask(() async {
      try {
        final r = await ContentService.getContentDetail(contentId);
        final data = (r['data'] is Map) ? Map<String, dynamic>.from(r['data'] as Map) : <String, dynamic>{};
        if (!mounted) return;
        setState(() {
          _contentCache[contentId] = data;
        });
      } finally {
        _contentLoadingIds.remove(contentId);
      }
    });
  }

  Widget _buildContentWishCard(Map<String, dynamic> item) {
    final contentId = _contentIdFromWish(item);
    final idStr = contentId?.toString() ?? (item['it_id']?.toString() ?? '');
    final cached = contentId != null ? _contentCache[contentId] : null;
    if (contentId != null) {
      _ensureContentLoaded(contentId);
    }

    final category = (cached?['category'] ?? item['category'] ?? '').toString().trim();
    final title = (cached?['title'] ?? item['title'] ?? '').toString().trim();
    final thumbRaw = (cached?['thumbnail'] ?? cached?['thumbnail_url'] ?? item['thumbnail'] ?? item['thumbnail_url'])
        ?.toString();
    final imageUrl = ContentService.resolveThumbnailUrl(
      thumbRaw,
      fallback: ImageUrlHelper.placeholdCo(321, 200),
    );

    return SizedBox(
      width: double.infinity,
      child: Container(
          decoration: BoxDecoration(
            border: Border.all(
                width: healthDp(context, 1), color: _border),
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
            color: Colors.white,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: contentId == null
                    ? null
                    : () {
                        Navigator.pushNamed(
                          context,
                          '/content/detail',
                          arguments: {'id': contentId},
                        );
                      },
                behavior: HitTestBehavior.opaque,
                child: AspectRatio(
                  aspectRatio: 1.45,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[100],
                        child: Center(
                          child: SizedBox(
                            width: healthDp(context, 28),
                            height: healthDp(context, 28),
                            child: CircularProgressIndicator(
                              strokeWidth: healthDp(context, 2),
                              color: _pink,
                            ),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[200],
                      child: Icon(
                        Icons.image_not_supported,
                        size: healthDp(context, 48),
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  top: healthDp(context, 10),
                  left: healthDp(context, 10),
                  right: healthDp(context, 10),
                  bottom: healthDp(context, 10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: contentId == null
                          ? null
                          : () {
                              Navigator.pushNamed(
                                context,
                                '/content/detail',
                                arguments: {'id': contentId},
                              );
                            },
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.isNotEmpty ? category : '콘텐츠',
                            style: TextStyle(
                              color: _textMain,
                              fontSize: healthSp(context, 12),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                          Text(
                            title.isNotEmpty ? title : '제목 없음',
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: true,
                            ),
                            style: TextStyle(
                              color: _textMain,
                              fontSize: healthSp(context, 14),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.44,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: healthDp(context, 20)),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: idStr.isEmpty ? null : () => _removeWishItem(idStr),
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 4)),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                              vertical: healthDp(context, 5)),
                          decoration: ShapeDecoration(
                            color: const Color(0x0CFF5A8D),
                            shape: RoundedRectangleBorder(
                              side: BorderSide(
                                  width: healthDp(context, 1),
                                  color: const Color(0xFFFF5A8D)),
                              borderRadius:
                                  BorderRadius.circular(healthDp(context, 4)),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: healthDp(context, 24),
                                height: healthDp(context, 24),
                                child: Center(
                                  child: Icon(
                                    Icons.favorite,
                                    size: healthDp(context, 18),
                                    color: const Color(0xFFFF5A8D),
                                  ),
                                ),
                              ),
                              SizedBox(width: healthDp(context, 5)),
                              Text(
                                '찜 해제',
                                style: TextStyle(
                                  color: const Color(0xFFFF5A8D),
                                  fontSize: healthSp(context, 12),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _loadMore,
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
              Text(
                '더보기',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF898686),
                  fontSize: healthSp(context, 16),
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
}
