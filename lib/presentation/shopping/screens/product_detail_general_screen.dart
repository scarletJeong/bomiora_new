import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_assets.dart';
import '../../common/widgets/centered_empty_state.dart';
import '../../../data/models/product/product_model.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../../data/models/review/review_model.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/product_share.dart';
import '../../../core/utils/inf_code_tracker.dart';
import '../../../data/services/point_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/app_config_service.dart';
import '../../../data/services/wish_service.dart';
import '../../../data/services/recent_view_service.dart';
import '../../../data/services/cart_service.dart';
import '../../../data/models/user/user_model.dart';
import '../../../data/models/product/product_option_model.dart';
import '../../../data/repositories/product/product_option_repository.dart';
import '../../../data/repositories/product/product_category_catalog.dart';
import '../../../data/models/cart/cart_item_model.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_toast_overlay.dart';
import '../widgets/product_tail_info_section.dart';
import '../widgets/option_bottomup.dart';
import '../widgets/recommend_product.dart';
import '../widgets/recommend_product_bottomup.dart';
import '../utils/cart_navigation.dart';
import '../utils/get_product.dart';
import '../utils/get_review.dart';
import '../utils/product_detail_html_helper.dart';
import '../utils/product_info_spec_helper.dart';
import 'payment_screen.dart';
import 'product_review_general_screen.dart';
import '../../review/screens/review_detail_screen.dart';
import '../../common/widgets/login_required_dialog.dart';
import '../../health/health_common/health_responsive_scale.dart';

const _kGmarketSans = 'Gmarket Sans TTF';

class ProductDetailGeneralScreen extends StatefulWidget {
  final String productId;

  const ProductDetailGeneralScreen({
    super.key,
    required this.productId,
  });

  @override
  State<ProductDetailGeneralScreen> createState() =>
      _ProductDetailGeneralScreenState();
}

class _ProductDetailGeneralScreenState extends State<ProductDetailGeneralScreen>
    with SingleTickerProviderStateMixin {
  Product? _product;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isFavorite = false;
  int _currentImageIndex = 0;
  late TabController _tabController;
  final ScrollController _detailScrollController = ScrollController();
  final ValueNotifier<bool> _detailExpanded = ValueNotifier(false);
  PageController? _pageController;

  // 리뷰 관련 상태
  List<ReviewModel> _supporterReviews = [];
  List<ReviewModel> _generalReviews = [];
  bool _isLoadingReviews = false;
  int? _userPoint; // 현재 사용자 보유 포인트
  bool? _usePointConfig; // cf_use_point 설정값
  int _visibleSupporterReviewCount = 3;
  int _visibleNormalReviewCount = 3;
  int? _supporterReviewTotal;
  int? _totalReviewCount;
  double? _supporterReviewAverage;
  double? _allReviewAverage;
  bool _supporterHasNext = false;
  bool _allHasNext = false;
  int _supporterPage = 0;
  int _allPage = 0;
  bool _reviewPaging = false;
  UserModel? _loggedInUser;

  // 옵션 관련 상태
  List<ProductOption> _productOptions = [];
  Map<ProductOption, int> _selectedOptions = {}; // 옵션과 수량을 함께 관리
  List<SupplyCartLine> _supplyLines = [];
  List<Product> _recommendedProducts = [];
  List<CartItem> _lastGeneralAddItems = [];

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      // 탭 변경 시 UI 업데이트
      if (!_tabController.indexIsChanging) {
        _safeSetState(() {});
      }
    });
    final cachedReviews = ProductReviewLoader.cached(widget.productId);
    if (cachedReviews != null) {
      _supporterReviews = cachedReviews.supporterReviews;
      _generalReviews = cachedReviews.generalReviews;
      _supporterHasNext = cachedReviews.supporterHasNext;
      _allHasNext = cachedReviews.allHasNext;
    }
    final cachedCounts = ProductReviewLoader.cachedCounts(widget.productId);
    if (cachedCounts != null) {
      _assignReviewCounts(cachedCounts);
    }
    _loadReviews();
    _loadProductDetail();
    _loadAuthUser();
    _loadConfig();
    _loadProductOptions();
  }

  Future<void> _loadAuthUser() async {
    final user = await AuthService.getUser();
    if (!mounted) return;
    setState(() => _loggedInUser = user);
  }

  bool get _isReviewLoginOk =>
      _loggedInUser != null && _loggedInUser!.id.trim().isNotEmpty;

  Future<void> _onGuestReviewLoginTap() async {
    await Navigator.pushNamed(context, '/login');
    if (!mounted) return;
    await _loadAuthUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _detailScrollController.dispose();
    _detailExpanded.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _loadProductDetail() async {
    final preview = ProductRepository.getProductPreview(widget.productId);
    _safeSetState(() {
      _product = preview;
      _isLoading = preview == null;
      _hasError = false;
    });

    try {
      final product =
          await ProductRepository.getProductDetail(widget.productId);
      _safeSetState(() {
        _product = product;
        _isLoading = false;
        if (product == null) {
          _hasError = true;
        } else {
          // 제품이 로드되면 이미지가 있을 때 PageController 초기화
          final images = _getProductImages();
          if (images.length > 1) {
            _pageController?.dispose();
            _pageController = PageController();
          }
          RecentViewService.recordView(
            product.id,
            productKind: product.productKind ?? 'general',
            productName: product.name,
            imageUrl: product.imageUrl,
            price: product.price,
            originalPrice: product.originalPrice,
            itSubject: product.itSubject,
          );
          if (product.isInfluencerProduct != true) {
            _loadUserPoint();
          }
        }
      });

      _checkFavoriteStatus();
      _loadRecommendedProducts();
    } catch (_) {
      _safeSetState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _loadRecommendedProducts() async {
    if (_product == null) return;

    try {
      final products =
          await CartService.getProductRecommendProducts(_product!.id);
      if (!mounted) return;
      setState(() {
        _recommendedProducts = products;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recommendedProducts = [];
      });
    }
  }

  Future<void> _openRecommendProduct(Product product) async {
    final kind = (product.productKind ?? '').toLowerCase();
    final basePath = kind == 'general'
        ? '/product-general/${product.id}'
        : '/product/${product.id}';
    final inf = InfCodeTracker.current;
    final route = (inf != null && inf.isNotEmpty)
        ? '$basePath?infcode=${Uri.encodeComponent(inf)}'
        : basePath;
    await Navigator.pushNamed(context, route);
    if (!mounted) return;
    await _loadProductDetail();
  }

  Widget _buildRecommendedSection() {
    if (_recommendedProducts.isEmpty) return const SizedBox.shrink();

    final products = _recommendedProducts;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 27),
        healthDp(context, 20),
        healthDp(context, 27),
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: healthDp(context, 1),
                height: healthDp(context, 14),
                margin: EdgeInsets.only(right: healthDp(context, 6)),
                color: const Color(0xFF1A1A1A),
              ),
              Text(
                '추가 상품 구매하기',
                style: shoppingSectionTitleStyle(context),
              ),
            ],
          ),
          SizedBox(height: healthDp(context, 12)),
          // 바텀시트(함께 구매하기 좋은 상품)와 동일 상품·가로 카드
          RecommendProductSquareRow(
            products: products,
            onProductTap: _openRecommendProduct,
          ),
        ],
      ),
    );
  }

  /// 찜하기 상태 확인
  Future<void> _checkFavoriteStatus() async {
    final isFavorite = await WishService.isWished(widget.productId);
    _safeSetState(() {
      _isFavorite = isFavorite;
    });
  }

  void _assignReviewCounts(ProductReviewCounts counts) {
    _supporterReviewTotal = counts.supporterCount;
    _totalReviewCount = counts.totalCount;
    _supporterReviewAverage = counts.supporterAverage;
    _allReviewAverage = counts.totalAverage;
  }

  String _reviewCountSuffix(int? count) {
    if (count == null) return '';
    return count == 0 ? '(0)' : '(+$count)';
  }

  Future<void> _loadReviewCounts() async {
    try {
      final counts = await ProductReviewLoader.loadCounts(widget.productId);
      if (!mounted || counts == null) return;
      _safeSetState(() => _assignReviewCounts(counts));
    } catch (_) {}
  }

  Future<void> _loadReviews() async {
    if (widget.productId.isEmpty) return;
    await Future.wait([
      _loadReviewCounts(),
      _loadReviewPages(),
    ]);
  }

  Future<void> _loadReviewPages() async {
    final hadCache = ProductReviewLoader.cached(widget.productId) != null;
    if (!hadCache) {
      _safeSetState(() {
        _isLoadingReviews = true;
      });
    }

    try {
      final loaded = await ProductReviewLoader.load(
        productId: widget.productId,
      );

      if (loaded != null) {
        _safeSetState(() {
          _supporterReviews = loaded.supporterReviews;
          _generalReviews = loaded.generalReviews;
          _supporterHasNext = loaded.supporterHasNext;
          _allHasNext = loaded.allHasNext;
          _supporterPage = 0;
          _allPage = 0;
          _visibleSupporterReviewCount = 3;
          _visibleNormalReviewCount = 3;
          _isLoadingReviews = false;
        });
      } else {
        _safeSetState(() {
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      _safeSetState(() {
        _isLoadingReviews = false;
      });
    }
  }

  Future<void> _revealMoreReviews({required bool supporter}) async {
    if (_reviewPaging) return;
    final loaded = supporter ? _supporterReviews : _generalReviews;
    final visible =
        supporter ? _visibleSupporterReviewCount : _visibleNormalReviewCount;
    final hasNext = supporter ? _supporterHasNext : _allHasNext;
    final page = supporter ? _supporterPage : _allPage;
    final nextVisible = visible + 3;
    if (nextVisible <= loaded.length || !hasNext) {
      final cap = nextVisible > loaded.length ? loaded.length : nextVisible;
      _safeSetState(() {
        if (supporter) {
          _visibleSupporterReviewCount = cap;
        } else {
          _visibleNormalReviewCount = cap;
        }
      });
      return;
    }

    _reviewPaging = true;
    try {
      final more = await ProductReviewLoader.fetchPage(
        productId: widget.productId,
        rvkind: supporter ? 'supporter' : null,
        page: page + 1,
      );
      if (!mounted || more == null) return;
      _safeSetState(() {
        final merged = [...loaded, ...more.reviews];
        final cap = nextVisible > merged.length ? merged.length : nextVisible;
        if (supporter) {
          _supporterReviews = merged;
          _supporterPage = page + 1;
          _supporterHasNext = more.hasNext;
          _visibleSupporterReviewCount = cap;
        } else {
          _generalReviews = merged;
          _allPage = page + 1;
          _allHasNext = more.hasNext;
          _visibleNormalReviewCount = cap;
        }
      });
    } finally {
      _reviewPaging = false;
    }
  }

  /// 사용자 포인트 조회
  Future<void> _loadUserPoint() async {
    try {
      final user = await AuthService.getUser();
      if (user != null) {
        final point = await PointService.getUserPoint(user.id);
        _safeSetState(() {
          _userPoint = point;
        });
      }
    } catch (e) {}
  }

  /// 설정 조회 (cf_use_point)
  Future<void> _loadConfig() async {
    final usePoint = await AppConfigService.usePoint();
    _safeSetState(() => _usePointConfig = usePoint);
  }

  /// 상품 옵션 조회
  Future<void> _loadProductOptions() async {
    if (widget.productId.isEmpty) return;

    try {
      final options =
          await ProductOptionRepository.getProductOptions(widget.productId);
      _safeSetState(() {
        _productOptions = options;
      });
    } catch (_) {}
  }

  /// 찜하기 토글
  Future<void> _toggleFavorite() async {
    if (_product == null) return;

    final user = await AuthService.getUser();
    if (user == null || user.id.isEmpty) {
      if (!mounted) return;
      await showLoginRequiredDialog(
        context,
        message: '찜하기는 로그인 후 이용할 수 있습니다.',
      );
      return;
    }

    try {
      final wasFavorite = _isFavorite;

      // 즉시 UI 업데이트 (낙관적 업데이트)
      _safeSetState(() {
        _isFavorite = !_isFavorite;
      });

      // API 호출
      if (wasFavorite) {
        // 찜하기 해제
        await WishService.removeFromWish(widget.productId);
      } else {
        // 찜하기 추가
        await WishService.addToWish(
          widget.productId,
          wiItKind: 'general',
        );
      }
    } catch (e) {
      // 실패 시 원래 상태로 되돌리기
      _safeSetState(() {
        _isFavorite = !_isFavorite;
      });
    }
  }

  List<String> _getProductImages() {
    if (_product == null) return [];
    final images = <String>[];

    // 1. 메인 썸네일 이미지
    if (_product!.imageUrl != null && _product!.imageUrl!.isNotEmpty) {
      images.add(_product!.imageUrl!);
    }

    // 2. additionalInfo에서 썸네일 이미지(it_img1~it_img9)만 가져오기
    //    - 썸네일은 /data/item/ 경로만 허용
    //    - /data/editor/ (상세 본문 이미지)는 여기서 제외
    if (_product!.additionalInfo != null) {
      for (int i = 1; i <= 9; i++) {
        final raw = _product!.additionalInfo!['it_img$i']?.toString();
        if (raw == null || raw.isEmpty) continue;
        final normalized =
            ImageUrlHelper.normalizeThumbnailUrl(raw, _product!.id);
        if (normalized != null &&
            normalized.contains('/data/item/') &&
            !images.contains(normalized)) {
          images.add(normalized);
        }
      }
    }

    return images;
  }

  String? get _reviewFallbackImageUrl {
    final thumbs = _getProductImages();
    if (thumbs.isNotEmpty) return thumbs.first;
    final display = _product?.displayImageUrl.trim() ?? '';
    if (display.isNotEmpty) return display;
    return _product?.imageUrl;
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final detailTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: _kGmarketSans),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: _kGmarketSans),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleGeneralDetailBack();
      },
      child: MobileAppLayoutWrapper(
        backgroundColor: Colors.white,
        child: Theme(
          data: detailTheme,
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: _kGmarketSans),
            child: Scaffold(
              backgroundColor: Colors.white,
              body: Stack(
                children: [
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _hasError
                          ? _buildErrorState()
                          : _product == null
                              ? _buildErrorState()
                              : _buildProductDetail(),
                  if (!_isLoading && !_hasError && _product != null)
                    _buildFloatingTransparentAppBar(),
                ],
              ),
              bottomNavigationBar:
                  _product == null ? null : _buildBottomActionBar(),
            ),
          ),
        ),
      ),
    );
  }

  /// 뒤로가기: 스택이 있으면 pop, 없거나 갈 곳 없으면 일반 목록 맨 앞 카테고리
  Future<void> _handleGeneralDetailBack() async {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    await _goToGeneralProductListFirstCategory();
  }

  Future<void> _goToGeneralProductListFirstCategory() async {
    if (!mounted) return;

    var categoryId = productGeneralCategoryListFallback.first.categoryId;
    var categoryName = productGeneralCategoryListFallback.first.label;
    try {
      final cats = await ProductCategoryCatalog.generalCategories();
      if (cats.isNotEmpty) {
        categoryId = cats.first.categoryId;
        categoryName = cats.first.label;
      }
    } catch (_) {}

    if (!mounted) return;
    // 웹에서 disposed view 렌더 충돌을 줄이기 위해 다음 프레임에 이동
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      '/product-general/',
      arguments: <String, dynamic>{
        'categoryId': categoryId,
        'categoryName': categoryName,
        'productKind': 'general',
      },
    );
  }

  Widget _buildErrorState() {
    return CenteredEmptyState(
      iconWidget: CenteredEmptyState.assetIcon(
        context,
        AppAssets.emptyCategoryIcon,
      ),
      message: '상품 정보가 없습니다.',
    );
  }

  Widget _buildProductDetail() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        return CustomScrollView(
          controller: _detailScrollController,
          primary: false,
          slivers: [
            SliverToBoxAdapter(
              child: _buildProductInfoSection(),
            ),
            SliverPersistentHeader(
              pinned: false,
              delegate: _SliverTabBarDelegate(
                _buildProductTabBar(
                  context,
                  supporterReviewCount: _supporterReviewTotal,
                  generalReviewCount: _totalReviewCount,
                ),
                height: _productTabBarHeight(context),
              ),
            ),
            if (_tabController.index == 0)
              _buildProductInfoSliver()
            else
              SliverToBoxAdapter(
                child: _tabController.index == 1
                    ? _buildSupportReviewTabContent()
                    : _buildNormalReviewTab(),
              ),
          ],
        );
      },
    );
  }

  double _productTabBarPaddingTop(BuildContext context) =>
      healthDp(context, 20);

  double _productTabBarPaddingBottom(BuildContext context) => 0;

  double _detailTopChromeHeight(BuildContext context) =>
      healthDp(context, 20) + healthDp(context, 5) * 2 + healthDp(context, 20);

  double _productTabBarContentHeight(BuildContext context) {
    final gap = healthDp(context, 5);
    final indicatorH = healthDp(context, 1);
    final labelStyle = TextStyle(
      fontSize: healthSp(context, 12),
      fontFamily: _kGmarketSans,
      fontWeight: FontWeight.w700,
      height: 1.0,
    );
    final textPainter = TextPainter(
      text: TextSpan(text: '서포터 리뷰(+999)', style: labelStyle),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    return textPainter.height + gap + indicatorH;
  }

  double _productTabBarHeight(BuildContext context) {
    return _productTabBarContentHeight(context) +
        _productTabBarPaddingTop(context) +
        _productTabBarPaddingBottom(context);
  }

  Widget _buildTabDivider(BuildContext context) {
    return Container(
      width: healthDp(context, 0.5),
      height: healthDp(context, 11),
      color: const Color(0xFFD2D2D2),
    );
  }

  Widget _buildProductTabBar(
    BuildContext context, {
    required int? supporterReviewCount,
    required int? generalReviewCount,
  }) {
    const pink = Color(0xFFFF5A8D);
    const gray = Color(0xFF898383);
    final gap = healthDp(context, 5);
    final indicatorH = healthDp(context, 1);
    final labelStyle = TextStyle(
      fontSize: healthSp(context, 12),
      fontFamily: _kGmarketSans,
      fontWeight: FontWeight.w700,
      height: 1.0,
    );
    final unselectedLabelStyle = TextStyle(
      fontSize: healthSp(context, 12),
      fontFamily: _kGmarketSans,
      fontWeight: FontWeight.w500,
      color: gray,
      height: 1.0,
    );
    final textPainter = TextPainter(
      text: TextSpan(text: '서포터 리뷰(+999)', style: labelStyle),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final textH = textPainter.height;
    final dividerTop = (textH - healthDp(context, 11)) / 2;

    Widget buildTabItem(
      int index,
      String label, {
      Alignment indicatorAlign = Alignment.center,
      TextAlign textAlign = TextAlign.center,
    }) {
      final selected = _tabController.index == index;
      final activeStyle = labelStyle.copyWith(color: pink);
      final tabLabelStyle = selected ? activeStyle : unselectedLabelStyle;
      final labelPainter = TextPainter(
        text: TextSpan(text: label, style: tabLabelStyle),
        textDirection: Directionality.of(context),
        maxLines: 1,
      )..layout();
      final labelWidth = labelPainter.width;

      return GestureDetector(
        onTap: () => _tabController.animateTo(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: indicatorAlign == Alignment.centerLeft
              ? CrossAxisAlignment.start
              : indicatorAlign == Alignment.centerRight
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: textAlign,
              style: tabLabelStyle,
            ),
            SizedBox(height: gap),
            Container(
              height: indicatorH,
              width: selected ? labelWidth : 0,
              color: selected ? pink : null,
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            healthDp(context, 20),
            _productTabBarPaddingTop(context),
            healthDp(context, 20),
            _productTabBarPaddingBottom(context),
          ),
          child: SizedBox(
            height: _productTabBarContentHeight(context),
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: healthDp(context, 10)),
                  child: buildTabItem(
                    0,
                    '상품 소개',
                    indicatorAlign: Alignment.centerLeft,
                    textAlign: TextAlign.left,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: dividerTop),
                  child: _buildTabDivider(context),
                ),
                buildTabItem(1, '서포터 리뷰${_reviewCountSuffix(supporterReviewCount)}'),
                Padding(
                  padding: EdgeInsets.only(top: dividerTop),
                  child: _buildTabDivider(context),
                ),
                Padding(
                  padding: EdgeInsets.only(right: healthDp(context, 10)),
                  child: buildTabItem(
                    2,
                    '전체 리뷰${_reviewCountSuffix(generalReviewCount)}',
                    indicatorAlign: Alignment.centerRight,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 상세 이미지가 모두 끝난 뒤 이어지는 상품 안내 영역.
  Widget _buildProductInfoTail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ProductTailInfoSection(
          showCertification: false,
          showWarning: false,
          showPrescriptionProcess: false,
          deliveryText:
              _product?.additionalInfo?['it_baesong_content']?.toString(),
          changeContentText:
              _product?.additionalInfo?['it_change_content']?.toString(),
        ),
        _buildRecommendedSection(),
        SizedBox(height: healthDp(context, 20)),
      ],
    );
  }

  Widget _buildSupportReviewTabContent() {
    final hideCoupon = _product?.isInfluencerProduct == true;
    return GeneralReviewTabPanel(
      reviews: _supporterReviews,
      isLoading: _isLoadingReviews,
      visibleCount: _visibleSupporterReviewCount,
      guestLoginLocked: !_isReviewLoginOk,
      onGuestLoginTap: _onGuestReviewLoginTap,
      embedInParentScroll: true,
      showCouponSection: !hideCoupon,
      fallbackImageUrl: _reviewFallbackImageUrl,
      hasMore: _supporterHasNext,
      averageOverride: _supporterReviewAverage,
      onLoadMore: () => _revealMoreReviews(supporter: true),
      onReviewTap: _openReviewDetail,
    );
  }

  /// 제품 정보 섹션 (탭 위에 고정)
  Widget _buildProductInfoSection() {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: healthDp(context, 20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: topInset + _detailTopChromeHeight(context),
            ),
            SizedBox(height: healthDp(context, 5)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '|',
                  style: TextStyle(
                    color: const Color(0xFF1A1A1E),
                    fontSize: healthSp(context, 24),
                    fontFamily: _kGmarketSans,
                    fontWeight: FontWeight.w200,
                    height: 1.1,
                  ),
                ),
                SizedBox(width: healthDp(context, 6)),
                Expanded(
                  child: Text(
                    _product!.name,
                    style: TextStyle(
                      color: const Color(0xFF1A1A1E),
                      fontSize: healthSp(context, 20),
                      fontFamily: _kGmarketSans,
                      fontWeight: FontWeight.w700,
                      letterSpacing: healthSp(context, -0.80),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: healthDp(context, 10)),
            _buildBasicDescription(),
            SizedBox(height: healthDp(context, 20)),
            _buildImageCarousel(_getProductImages()),
            SizedBox(height: healthDp(context, 20)),
            _buildPriceSection(),
            SizedBox(height: healthDp(context, 20)),
            _detailGrayLine(),
            SizedBox(height: healthDp(context, 20)),
            _buildProductSpecs(),
            SizedBox(height: healthDp(context, 20)),
            _detailGrayLine(),
          ],
        ),
      ),
    );
  }

  Widget _detailGrayLine() {
    return Divider(
      height: healthDp(context, 1),
      thickness: healthDp(context, 1),
      color: Colors.grey.shade300,
    );
  }

  Widget _buildNormalReviewTab() {
    return GeneralReviewTabPanel(
      reviews: _generalReviews,
      isLoading: _isLoadingReviews,
      visibleCount: _visibleNormalReviewCount,
      guestLoginLocked: !_isReviewLoginOk,
      onGuestLoginTap: _onGuestReviewLoginTap,
      embedInParentScroll: true,
      showCouponSection: false,
      fallbackImageUrl: _reviewFallbackImageUrl,
      hasMore: _allHasNext,
      averageOverride: _allReviewAverage,
      onLoadMore: () => _revealMoreReviews(supporter: false),
      onReviewTap: _openReviewDetail,
    );
  }

  void _openReviewDetail(ReviewModel review) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReviewDetailScreen(
          review: review,
          fromProductDetail: true,
        ),
      ),
    );
  }

  Widget _buildImageCarousel(List<String> images) {
    final screenWidth = MediaQuery.of(context).size.width;
    final imageHeight = healthDp(context, 230);
    final maxWidth = screenWidth.clamp(
      healthDp(context, 200),
      healthDp(context, 600),
    );

    if (images.isEmpty) {
      final emptyContainer = ClipRRect(
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
          child: Container(
            height: imageHeight,
            margin: kIsWeb
                ? EdgeInsets.symmetric(horizontal: healthDp(context, 16))
                : null,
            color: Colors.grey[200],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_not_supported,
                  size: healthDp(context, 60),
                  color: Colors.grey[400],
                ),
                SizedBox(height: healthDp(context, 8)),
                Text(
                  'No Image',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: healthSp(context, 14),
                  ),
                ),
              ],
            ),
          ));
      // 웹에서는 Center로 감싸고 width 제한, 앱에서는 원래 구조 유지
      if (kIsWeb) {
        return Center(
          child: SizedBox(
            width: maxWidth,
            child: emptyContainer,
          ),
        );
      } else {
        return emptyContainer;
      }
    }

    // PageController 초기화 (이미지가 2개 이상일 때만)
    if (images.length > 1 && _pageController == null) {
      _pageController = PageController();
    }

    // 웹에서는 Center로 감싸고, 앱에서는 원래 구조 유지
    final stackWidget = ClipRRect(
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: images.length,
              onPageChanged: (index) {
                _safeSetState(() {
                  _currentImageIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final imageUrl = images[index];

                return buildProductCarouselImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  height: imageHeight,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            size: healthDp(context, 60),
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: healthDp(context, 8)),
                          Text(
                            '이미지 로드 실패',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: healthSp(context, 14),
                            ),
                          ),
                          SizedBox(height: healthDp(context, 4)),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: healthDp(context, 16),
                            ),
                            child: Text(
                              imageUrl.length > 50
                                  ? '${imageUrl.substring(0, 50)}...'
                                  : imageUrl,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: healthSp(context, 10),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  },
                );
              },
            ),
            // 이전/다음 버튼
            if (images.length > 1) ...[
              Positioned(
                left: healthDp(context, 8),
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    icon: Container(
                      padding: EdgeInsets.all(healthDp(context, 8)),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.black87,
                      ),
                    ),
                    onPressed: _currentImageIndex > 0
                        ? () {
                            _pageController?.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                  ),
                ),
              ),
              Positioned(
                right: healthDp(context, 8),
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    icon: Container(
                      padding: EdgeInsets.all(healthDp(context, 8)),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: Colors.black87,
                      ),
                    ),
                    onPressed: _currentImageIndex < images.length - 1
                        ? () {
                            _pageController?.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                  ),
                ),
              ),
              // 인디케이터
              Positioned(
                bottom: healthDp(context, 16),
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    images.length,
                    (index) => Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 4),
                      ),
                      width: healthDp(context, 8),
                      height: healthDp(context, 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentImageIndex == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ));

    // 웹에서는 Center로 감싸고, 앱에서는 원래 구조 유지
    if (kIsWeb) {
      return Center(
        child: SizedBox(
          width: maxWidth,
          height: imageHeight,
          child: stackWidget,
        ),
      );
    } else {
      // 앱: 원래 구조 (width 없이 height만)
      return SizedBox(
        height: imageHeight,
        child: stackWidget,
      );
    }
  }

  /// 간단 설명 (it_basic) 표시
  Widget _buildBasicDescription() {
    if (_product?.additionalInfo == null) return const SizedBox.shrink();

    final itBasic = _product!.additionalInfo!['it_basic']?.toString();
    if (itBasic == null || itBasic.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(left: healthDp(context, 8)),
      child: Text(
        itBasic,
        style: TextStyle(
          color: const Color(0xFF767676),
          fontSize: healthSp(context, 12),
          fontFamily: _kGmarketSans,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }

  Widget _buildProductSpecs() {
    final mainSpecs = ProductInfoSpecHelper.buildSpecs(
      info: _product!.additionalInfo,
      price: _product!.price,
      usePoint: _usePointConfig ?? true,
      isInfluencerProduct: _product?.isInfluencerProduct == true,
    );

    if (mainSpecs.isEmpty) return const SizedBox.shrink();

    final specTextStyle = TextStyle(
      fontSize: healthSp(context, 14),
      color: const Color(0xFF1A1A1E),
      fontWeight: FontWeight.w300,
      fontFamily: _kGmarketSans,
      height: 1.5,
    );

    Widget buildSpecRow(Map<String, String> spec) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: healthDp(context, 68),
            child: Text(
              spec['label']!,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: specTextStyle,
            ),
          ),
          SizedBox(width: healthDp(context, 20)),
          Expanded(
            child: Text(
              spec['value']!,
              style: specTextStyle,
            ),
          ),
        ],
      );
    }

    final itemGap = healthDp(context, 8);
    final children = <Widget>[];

    for (var i = 0; i < mainSpecs.length; i++) {
      if (i > 0) {
        children.add(SizedBox(height: itemGap));
      }
      children.add(buildSpecRow(mainSpecs[i]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildPriceSection() {
    final discountRate = _product!.discountRate;
    final hasOriginalPrice = _product!.originalPrice != null &&
        _product!.originalPrice! > _product!.price;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasOriginalPrice)
                Text(
                  _product!.formattedOriginalPrice ?? '',
                  style: TextStyle(
                    color: const Color(0xFF898686),
                    fontSize: healthSp(context, 14),
                    fontFamily: _kGmarketSans,
                    fontWeight: FontWeight.w300,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: const Color(0xFF898686),
                  ),
                ),
              if (hasOriginalPrice) SizedBox(height: healthDp(context, 4)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (discountRate != null && discountRate > 0) ...[
                    Text(
                      '${discountRate.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: healthSp(context, 20),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFF5A8D),
                        fontFamily: _kGmarketSans,
                      ),
                    ),
                    SizedBox(width: healthDp(context, 2)),
                  ],
                  Text(
                    _product!.formattedPrice,
                    style: TextStyle(
                      fontSize: healthSp(context, 20),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1E),
                      fontFamily: _kGmarketSans,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildShareButton(),
      ],
    );
  }

  Widget _buildShareButton() {
    final iconSz = healthDp(context, 24);
    final tapSize = healthDp(context, 32);

    return Builder(
      builder: (anchorContext) {
        return SizedBox(
          width: tapSize,
          height: tapSize,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ProductShare.shareProductWithFeedback(
              context: context,
              anchorContext: anchorContext,
              itId: _product!.id,
              productName: _product!.name,
              productKind: _product!.productKind ?? 'general',
            ),
            child: Center(
              child: SvgPicture.asset(
                AppAssets.shoppingShareIcon,
                width: iconSz,
                height: iconSz,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }

  /// 배경·블러 없이 투명 — 뒤로가기 / 홈 / 장바구니.
  /// 높이는 메인·마이페이지 로고 앱바(60)와 같고, 아이콘은 그 높이의 세로 가운데.
  Widget _buildFloatingTransparentAppBar() {
    final topInset = healthStatusBarTopInset(context);
    final barH = healthAppBarTotalHeight(context);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SizedBox(
        height: topInset + barH,
        child: Padding(
          padding: EdgeInsets.only(
            top: topInset,
            left: healthDp(context, 20),
            right: healthDp(context, 20),
          ),
          child: SizedBox(
            height: barH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _detailAppBarIconButton(
                  onPressed: _handleGeneralDetailBack,
                  child: _detailAppBarSvgIcon(
                    AppAssets.appbarBackIcon,
                    size: 16,
                  ),
                ),
                const Spacer(),
                _detailAppBarIconButton(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/home',
                      (route) => false,
                    );
                  },
                  child: _detailAppBarSvgIcon(
                    AppAssets.appbarHomeIcon,
                    size: 20,
                  ),
                ),
                SizedBox(width: healthDp(context, 8)),
                _detailAppBarIconButton(
                  onPressed: () {
                    CartNavigation.openCart(
                      context,
                      prescriptionTab: _product?.ctKind == 'prescription',
                    );
                  },
                  child: _detailAppBarSvgIcon(
                    AppAssets.appbarCartIcon,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailAppBarSvgIcon(String asset, {double size = 16}) {
    final s = healthDp(context, size);
    return SvgPicture.asset(
      asset,
      width: s,
      height: s,
      fit: BoxFit.contain,
      colorFilter: const ColorFilter.mode(
        Color(0xFF1A1A1A),
        BlendMode.srcIn,
      ),
    );
  }

  Widget _detailAppBarIconButton({
    required Widget child,
    required VoidCallback onPressed,
  }) {
    final tap = healthDp(context, 20);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: tap,
          height: tap,
          child: Center(child: child),
        ),
      ),
    );
  }

  String _getProcessedDetailHtml() {
    if (_product == null) return '';
    final itExplain = _product!.additionalInfo?['it_explain']?.toString() ??
        _product!.description;
    return processProductDetailHtml(itExplain);
  }

  Widget _buildProductInfoSliver() {
    final processedHtml = _getProcessedDetailHtml();
    return ValueListenableBuilder<bool>(
      valueListenable: _detailExpanded,
      builder: (context, expanded, _) {
        return SliverMainAxisGroup(
          slivers: [
            if (processedHtml.isNotEmpty)
              SliverToBoxAdapter(
                child: ProductDetailCollapsedPreview(
                  html: processedHtml,
                  expanded: expanded,
                  fontFamily: _kGmarketSans,
                  horizontalPadding: healthDp(context, 27),
                  margin: EdgeInsets.only(top: healthDp(context, 24)),
                  onExpand: () => _detailExpanded.value = true,
                ),
              ),
            SliverToBoxAdapter(child: _buildProductInfoTail()),
          ],
        );
      },
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: healthDp(context, 1),
            blurRadius: healthDp(context, 4),
            offset: Offset(0, -healthDp(context, 2)),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 20),
            vertical: healthDp(context, 10),
          ),
          child: Row(
            children: [
              Container(
                width: healthDp(context, 40),
                height: healthDp(context, 40),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(healthDp(context, 8)),
                ),
                child: IconButton(
                  iconSize: healthDp(context, 22),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: healthDp(context, 22),
                    color: _isFavorite
                        ? const Color(0xFFFF4081)
                        : Colors.grey[600],
                  ),
                  onPressed: () => _toggleFavorite(),
                ),
              ),
              SizedBox(width: healthDp(context, 10)),
              Expanded(
                child: SizedBox(
                  height: healthDp(context, 40),
                  child: ElevatedButton(
                    onPressed: _showOptionSelectionDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4081),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 10)),
                      ),
                    ),
                    child: Text(
                      '구매하기',
                      style: TextStyle(
                        fontSize: healthSp(context, 16),
                        fontWeight: FontWeight.w500,
                        fontFamily: _kGmarketSans,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 옵션 선택 바텀 시트 표시
  Future<void> _showOptionSelectionDialog() async {
    if (_product == null) return;

    await showProductOptionBottomup(
      context: context,
      product: _product!,
      options: _productOptions,
      selectedOptions: _selectedOptions,
      supplyLines: _supplyLines,
      userPoint: _product!.isInfluencerProduct ? null : _userPoint,
      isFavorite: _isFavorite,
      productKindOverride: 'general',
      onToggleFavorite: _toggleFavorite,
      onNoOptionGeneral: _showGeneralQuantityBottomSheet,
      onNoOptionPrescription: () async {},
      onOptionsChanged: (newOptions) {
        _safeSetState(() {
          _selectedOptions = newOptions;
        });
      },
      onSupplyLinesChanged: (lines) {
        _safeSetState(() {
          _supplyLines = lines;
        });
      },
      onAddToCart: () async {
        if (_product == null || _selectedOptions.isEmpty) return;

        final user = await AuthService.getUser();
        if (user == null || user.id.isEmpty) {
          if (!mounted) return;
          await showLoginRequiredDialog(
            context,
            message: '장바구니 담기는 로그인 후 이용할 수 있습니다.',
          );
          return;
        }

        final options = Map<ProductOption, int>.from(_selectedOptions);
        final supply = List<SupplyCartLine>.from(_supplyLines);
        Navigator.of(context).pop();

        if (!mounted) return;

        final addFuture = CartService.addOptionsToCart(
          product: _product!,
          selectedOptions: options,
          supplyLines: supply,
          mergeIfExists: true,
        );
        addFuture.then(_onCartAddCompleted);

        if (!mounted) return;
        await _showRecommendProductBottomup(
          addedItemsFuture:
              addFuture.then((result) => _parseAddedCartItems(result)),
        );
      },
      onAddToPrescriptionCart: () async {},
      onReserve: () async {},
      onBuyNow: () async {
        if (_product == null || _selectedOptions.isEmpty) return;

        final user = await AuthService.getUser();
        if (user == null || user.id.isEmpty) {
          if (!mounted) return;
          await showLoginRequiredDialog(
            context,
            message: '상품 구매는 로그인 후\n이용할 수 있습니다.',
          );
          return;
        }

        final options = Map<ProductOption, int>.from(_selectedOptions);
        final supply = List<SupplyCartLine>.from(_supplyLines);
        Navigator.of(context).pop();
        if (!mounted) return;

        await _buySelectedGeneralProductNow(
          selectedOptions: options,
          supplyLines: supply,
        );
      },
    );
  }

  Future<bool> _addGeneralProductToCart({required int quantity}) async {
    if (_product == null) return false;
    final user = await AuthService.getUser();
    if (user == null || user.id.isEmpty) {
      if (!mounted) return false;
      await showLoginRequiredDialog(
        context,
        message: '장바구니 담기와 구매는 로그인 후 이용할 수 있습니다.',
      );
      return false;
    }
    final result = await CartService.addOrMergeToCart(
      productId: _product!.id,
      quantity: quantity,
      price: _product!.price * quantity,
      ctKind: _product!.ctKind,
    );

    if (!mounted) return false;

    final success = result['success'] == true;
    if (success) {
      final item = CartService.cartItemFromAddResponseData(result['data']);
      _lastGeneralAddItems = item != null ? [item] : const [];
    } else {
      _lastGeneralAddItems = const [];
    }
    return success;
  }

  List<CartItem> _parseGeneralCartItems(Map<String, dynamic> cart) {
    final rawItems = (cart['items'] as List?) ?? const [];
    return rawItems
        .whereType<Map>()
        .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => !e.isPrescription)
        .toList();
  }

  List<CartItem> _parseAddedCartItems(Map<String, dynamic> result) {
    final raw = result['added_items'];
    if (raw is List && raw.isNotEmpty) {
      return raw.whereType<CartItem>().toList();
    }
    final item = CartService.cartItemFromAddResponseData(result['data']);
    return item != null ? [item] : const [];
  }

  Future<Set<int>> _snapshotGeneralCartIds() async {
    final cart = await CartService.getCart();
    if (cart['success'] != true) return {};
    return _parseGeneralCartItems(cart).map((e) => e.ctId).toSet();
  }

  String _ctOptionText(ProductOption option) => option.displayText.trim();

  Future<List<CartItem>> _resolveGeneralBuyNowPayItems({
    required Set<int> beforeIds,
    Map<ProductOption, int>? selectedOptions,
    int? quantity,
  }) async {
    final cart = await CartService.getCart();
    if (cart['success'] != true || _product == null) return [];

    final all = _parseGeneralCartItems(cart);
    final newlyAdded =
        all.where((item) => !beforeIds.contains(item.ctId)).toList();
    if (newlyAdded.isNotEmpty) return newlyAdded;

    if (selectedOptions != null && selectedOptions.isNotEmpty) {
      final matched = <CartItem>[];
      for (final entry in selectedOptions.entries) {
        final optionText = _ctOptionText(entry.key).trim();
        CartItem? found;
        for (final candidate in all) {
          if (candidate.itId == _product!.id &&
              candidate.ctOption.trim() == optionText) {
            found = candidate;
            break;
          }
        }
        if (found == null) return [];
        matched.add(found);
      }
      return matched;
    }

    if (quantity != null && quantity > 0) {
      final noOptionItems = all
          .where(
            (item) => item.itId == _product!.id && item.ctOption.trim().isEmpty,
          )
          .toList();
      if (noOptionItems.isEmpty) return [];
      return [noOptionItems.last];
    }

    return [];
  }

  void _showBuyNowFailedSnackBar() {
    if (!mounted) return;
    AppToastOverlay.show(context, '결제 정보를 불러오지 못했습니다. 다시 시도해 주세요.');
  }

  /// 바로구매 배송비는 넘기지 않는다. 결제 화면 `_loadShippingQuote`가 정본.
  Future<void> _openGeneralPaymentScreen({
    required List<CartItem> payItems,
  }) async {
    if (!mounted || payItems.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/pay'),
        builder: (_) => PaymentScreen(
          cartItems: payItems,
          shippingCost: 0,
          sourceTitle: '일반상품 결제',
        ),
      ),
    );
  }

  Future<void> _buySelectedGeneralProductNow({
    Map<ProductOption, int>? selectedOptions,
    List<SupplyCartLine>? supplyLines,
    int? quantity,
  }) async {
    if (_product == null) return;

    final hasOptions = selectedOptions != null && selectedOptions.isNotEmpty;
    if (!hasOptions && (quantity == null || quantity <= 0)) return;

    final Map<String, dynamic> result;
    if (hasOptions) {
      result = await CartService.addOptionsToCart(
        product: _product!,
        selectedOptions: selectedOptions!,
        supplyLines: supplyLines ?? _supplyLines,
        mergeIfExists: false,
      );
    } else {
      result = await CartService.addToCart(
        productId: _product!.id,
        quantity: quantity!,
        price: _product!.price * quantity,
        ctKind: _product!.ctKind.isNotEmpty ? _product!.ctKind : 'general',
      );
    }

    if (!mounted || result['success'] != true) {
      _showBuyNowFailedSnackBar();
      return;
    }

    _safeSetState(() {
      _selectedOptions.clear();
      _supplyLines.clear();
    });

    var payItems = _parseAddedCartItems(result);
    if (payItems.isEmpty) {
      final beforeIds = await _snapshotGeneralCartIds();
      payItems = await _resolveGeneralBuyNowPayItems(
        beforeIds: beforeIds,
        selectedOptions: selectedOptions,
        quantity: quantity,
      );
    }
    if (!mounted || payItems.isEmpty) {
      _showBuyNowFailedSnackBar();
      return;
    }

    await _openGeneralPaymentScreen(payItems: payItems);
  }

  Future<void> _openMatchingCart({
    List<CartItem>? addedItems,
    Future<List<CartItem>>? addedItemsFuture,
  }) async {
    final items = addedItems ??
        (addedItemsFuture != null
            ? await addedItemsFuture
            : const <CartItem>[]);
    if (!mounted) return;
    await CartNavigation.openCart(
      context,
      prescriptionTab: CartNavigation.prescriptionTabFor(
        product: _product,
        addedItems: items,
      ),
    );
  }

  Future<void> _showRecommendProductBottomup({
    List<CartItem>? addedItems,
    Future<List<CartItem>>? addedItemsFuture,
  }) async {
    if (_product == null || !mounted) return;

    final cached = _recommendedProducts;
    final productsLoader = cached.isEmpty
        ? CartService.getProductRecommendProducts(_product!.id).then((loaded) {
            if (mounted && loaded.isNotEmpty) {
              setState(() => _recommendedProducts = loaded);
            }
            return loaded;
          })
        : null;

    if (cached.isEmpty && productsLoader == null) {
      final items = addedItems ??
          (addedItemsFuture != null ? await addedItemsFuture : null);
      if (items != null && items.isNotEmpty) {
        await _openGeneralPaymentScreen(payItems: items);
      }
      return;
    }

    await showRecommendProductBottomup(
      context: context,
      products: cached,
      productsLoader: productsLoader,
      addedItems: addedItems,
      addedItemsFuture: addedItemsFuture,
      primaryButtonLabel: '바로 결제하기',
      onProductTap: (product) {
        Navigator.of(context).pop();
        _openRecommendProduct(product);
      },
      onGoToCart: () {
        _openMatchingCart(
          addedItems: addedItems,
          addedItemsFuture: addedItemsFuture,
        );
      },
      onPrimaryAction: () async {
        if (!mounted) return;
        final items = addedItems ??
            (addedItemsFuture != null
                ? await addedItemsFuture
                : const <CartItem>[]);
        if (items.isEmpty) {
          _showBuyNowFailedSnackBar();
          return;
        }
        await _openGeneralPaymentScreen(payItems: items);
      },
    );
  }

  void _onCartAddCompleted(Map<String, dynamic> result) {
    if (!mounted) return;
    if (result['success'] == true) {
      _safeSetState(() {
        _selectedOptions.clear();
        _supplyLines.clear();
      });
      return;
    }
    final message = (result['message'] ?? '장바구니 담기에 실패했습니다.').toString();
    AppToastOverlay.show(context, message);
  }

  Future<void> _showGeneralQuantityBottomSheet() async {
    if (_product == null) return;

    await showGeneralQuantityBottomup(
      context: context,
      productName: _product!.name,
      unitPrice: _product!.price,
      userPoint: _product!.isInfluencerProduct ? null : _userPoint,
      isFavorite: _isFavorite,
      onToggleFavorite: _toggleFavorite,
      onAddToCart: (quantity) async {
        Navigator.of(context).pop();
        if (!mounted) return;

        final addFuture = () async {
          final success = await _addGeneralProductToCart(quantity: quantity);
          if (!success) return <CartItem>[];
          return _lastGeneralAddItems;
        }();
        addFuture.then((items) {
          if (!mounted) return;
          if (items.isNotEmpty) return;
          _showBuyNowFailedSnackBar();
        });

        if (!mounted) return;
        await _showRecommendProductBottomup(
          addedItemsFuture: addFuture,
        );
      },
      onBuyNow: (quantity) async {
        Navigator.of(context).pop();
        if (!mounted) return;
        await _buySelectedGeneralProductNow(quantity: quantity);
      },
    );
  }
}

/// SliverPersistentHeaderDelegate for product tab row
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _SliverTabBarDelegate(this.child, {required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      height: height,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return child != oldDelegate.child || height != oldDelegate.height;
  }
}
