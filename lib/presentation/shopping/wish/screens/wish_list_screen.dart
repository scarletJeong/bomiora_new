import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../core/utils/node_value_parser.dart';
import '../../../../data/services/auth_service.dart';
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
  static const Color _textMain = Color(0xFF1A1A1E);
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

  /// API `it_kind` 기준 — 비대면: prescription, 스토어: general
  /// 상품은 마스터 `it_kind`를 우선하고, 콘텐츠만 `wi_it_kind`를 본다.
  String _itKindLower(Map<String, dynamic> item) {
    final wishKind = (NodeValueParser.asString(item['wi_it_kind']) ??
            NodeValueParser.asString(item['wiItKind']) ??
            '')
        .toLowerCase()
        .trim();
    if (wishKind == 'content') return 'content';
    final productKind = (NodeValueParser.asString(item['it_kind']) ??
            NodeValueParser.asString(item['product_kind']) ??
            NodeValueParser.asString(item['productKind']) ??
            NodeValueParser.asString(item['ct_kind']) ??
            '')
        .toLowerCase()
        .trim();
    if (productKind.isNotEmpty) return productKind;
    return wishKind;
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

  void _openProductDetail(String productId, Map<String, dynamic> item) {
    final route = _itKindLower(item) == 'prescription'
        ? '/product/$productId'
        : '/product-general/$productId';
    Navigator.pushNamed(context, route);
  }

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

  Future<void> _applyWishRows(List<dynamic> raw, {required bool showSpinner}) async {
    if (!mounted) return;
    final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    setState(() {
      _wishList = list;
      _selectTabIfCurrentEmpty();
      if (showSpinner) _isLoading = false;
      _errorMessage = null;
      _requiresLogin = false;
      _syncVisibleCount();
    });
  }

  void _selectTabIfCurrentEmpty() {
    if (_currentTabList.isNotEmpty || _wishList.isEmpty) return;
    final newest = _wishList.first;
    final kind = _itKindLower(newest);
    if (kind == 'content') {
      _selectedTabIndex = 2;
    } else if (kind == 'prescription') {
      _selectedTabIndex = 0;
    } else {
      _selectedTabIndex = 1;
    }
  }

  Future<void> _loadWishList() async {
    if (!mounted) return;

    try {
      final user = await AuthService.getUser();
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _requiresLogin = true;
          _errorMessage = null;
          _isLoading = false;
        });
        return;
      }

      final cached = WishService.peekWishList(user.id);
      if (cached != null) {
        await _applyWishRows(cached, showSpinner: true);
      } else {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
          _requiresLogin = false;
        });
      }
      try {
        final raw = await WishService.getWishList(forceRefresh: true);
        if (!mounted) return;
        await _applyWishRows(raw, showSpinner: true);
      } catch (e) {
        if (cached != null) return;
        rethrow;
      }
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
    final id = productId.trim();
    if (id.isEmpty) return;
    final index = _wishList.indexWhere((e) => (e['it_id']?.toString() ?? '') == id);
    if (index < 0) return;
    final removed = Map<String, dynamic>.from(_wishList[index]);
    setState(() {
      _wishList.removeAt(index);
      _syncVisibleCount();
    });
    WishService.removeFromLocalList(id);
    try {
      await WishService.removeFromWish(id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final i = index > _wishList.length ? _wishList.length : index;
        _wishList.insert(i, removed);
        _syncVisibleCount();
      });
      WishService.restoreLocalListItem(index, removed);
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
                : (_requiresLogin || AuthService.currentUser == null)
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
        padding: EdgeInsets.symmetric(horizontal: healthDp(context, 20)),
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
    return CenteredEmptyState(
      iconWidget: CenteredEmptyState.assetIcon(
        context,
        AppAssets.emptyWishlistIcon,
      ),
      message: '로그인 후 이용가능합니다.',
      trailing: CenteredEmptyState.loginButtonTrailing(
        context,
        onPressed: () async {
          await Navigator.pushNamed(context, '/login');
          if (!mounted) return;
          await _loadWishList();
        },
      ),
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
          padding: EdgeInsets.fromLTRB(
            healthDp(context, 20),
            healthDp(context, 10),
            healthDp(context, 20),
            healthDp(context, 20),
          ),
          child: _buildTabs(),
        ),
        if (list.isEmpty)
          Expanded(
            child: CenteredEmptyState(
              iconWidget: CenteredEmptyState.assetIcon(
                context,
                AppAssets.emptyWishlistIcon,
              ),
              message: _emptyMessageForTab(),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: healthDp(context, 20),
                right: healthDp(context, 20),
                bottom: healthDp(context, 20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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
    Widget tabCell({
      required int index,
      required String label,
      required int count,
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
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selected ? '$label$count' : label,
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
                color: selected ? _pink : const Color(0xFFD2D2D2),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: tabCell(
            index: 0,
            label: '비대면 진료',
            count: _telemedWishes.length,
          ),
        ),
        Expanded(
          child: tabCell(
            index: 1,
            label: '스토어',
            count: _storeWishes.length,
          ),
        ),
        Expanded(
          child: tabCell(
            index: 2,
            label: '콘텐츠',
            count: _contentWishes.length,
          ),
        ),
      ],
    );
  }

  BorderRadius get _cardBottomRadius => BorderRadius.only(
        bottomLeft: Radius.circular(healthDp(context, 10)),
        bottomRight: Radius.circular(healthDp(context, 10)),
      );

  Widget _wishCardImage({
    required String imageUrl,
    required BoxFit fit,
    VoidCallback? onTap,
  }) {
    final radius = healthDp(context, 10);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(radius),
        ),
        child: SizedBox(
          width: double.infinity,
          height: healthDp(context, 200),
          child: Image.network(
            imageUrl,
            fit: fit,
            width: double.infinity,
            height: healthDp(context, 200),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return ColoredBox(
                color: const Color(0xFFF5F5F5),
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
            errorBuilder: (_, __, ___) => ColoredBox(
              color: const Color(0xFFF0F0F0),
              child: Icon(
                Icons.image_not_supported,
                size: healthDp(context, 48),
                color: Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _wishCardBody({
    required VoidCallback? onTextTap,
    required VoidCallback? onUnwish,
    required List<Widget> textChildren,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 10)),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: _border,
          ),
          borderRadius: _cardBottomRadius,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTextTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: textChildren,
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          _unwishButton(onTap: onUnwish),
        ],
      ),
    );
  }

  Widget _unwishButton({required VoidCallback? onTap}) {
    final iconSize = healthDp(context, 24);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(healthDp(context, 4)),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: healthDp(context, 5)),
          decoration: ShapeDecoration(
            color: _chipFill,
            shape: RoundedRectangleBorder(
              side: BorderSide(width: healthDp(context, 1), color: _pink),
              borderRadius: BorderRadius.circular(healthDp(context, 4)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: iconSize,
                height: iconSize,
                child: Center(
                  child: SvgPicture.asset(
                    AppAssets.heartIconFilled,
                    width: healthDp(context, 18),
                    height: healthDp(context, 18),
                    colorFilter: const ColorFilter.mode(_pink, BlendMode.srcIn),
                  ),
                ),
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
    );
  }

  Widget _wishMetaText(String text) {
    return Text(
      text,
      style: TextStyle(
        color: _textMuted,
        fontSize: healthSp(context, 10),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _wishTitleText(String text) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: _textMain,
        fontSize: healthSp(context, 14),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w500,
        letterSpacing: healthSp(context, -0.56),
      ),
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
    final openDetail =
        productId.isEmpty ? null : () => _openProductDetail(productId, item);

    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _wishCardImage(
            imageUrl: ImageUrlHelper.getImageUrl(productImage),
            fit: BoxFit.fill,
            onTap: openDetail,
          ),
          _wishCardBody(
            onTextTap: openDetail,
            onUnwish: productId.isEmpty ? null : () => _removeWishItem(productId),
            textChildren: [
              _wishMetaText(
                subject.trim().isNotEmpty ? subject.trim() : '보미오라 한의원',
              ),
              SizedBox(height: healthDp(context, 4)),
              _wishTitleText(productName.isNotEmpty ? productName : '상품'),
              if (descriptionLine.isNotEmpty) ...[
                SizedBox(height: healthDp(context, 4)),
                Text(
                  descriptionLine,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textSub,
                    fontSize: healthSp(context, 12),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ],
          ),
        ],
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

    final openDetail = contentId == null
        ? null
        : () {
            Navigator.pushNamed(
              context,
              '/content/detail',
              arguments: {'id': contentId},
            );
          };

    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _wishCardImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            onTap: openDetail,
          ),
          _wishCardBody(
            onTextTap: openDetail,
            onUnwish: idStr.isEmpty ? null : () => _removeWishItem(idStr),
            textChildren: [
              _wishMetaText(category.isNotEmpty ? category : '콘텐츠'),
              SizedBox(height: healthDp(context, 4)),
              _wishTitleText(title.isNotEmpty ? title : '제목 없음'),
            ],
          ),
        ],
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
