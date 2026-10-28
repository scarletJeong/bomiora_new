import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_assets.dart';
import '../../common/widgets/centered_empty_state.dart';
import '../../common/widgets/web_dragscroll.dart';
import '../../../data/models/cart/cart_item_model.dart';
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
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_toast_overlay.dart';
import '../widgets/product_tail_info_section.dart';
import '../widgets/option_bottomup.dart';
import '../widgets/recommend_product_bottomup.dart';
import '../utils/cart_navigation.dart';
import 'prescription_booking/prescription_profile_screen.dart';
import 'product_reviews_screen.dart';
import '../../review/screens/review_detail_screen.dart';
import '../utils/get_review.dart';
import '../utils/product_detail_html_helper.dart';
import '../utils/product_info_spec_helper.dart';
import '../../common/widgets/login_required_dialog.dart';
import '../../user/healthprofile/screens/health_profile_list_screen.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../../data/services/pending_product_checkout.dart';

const _kGmarketSans = 'Gmarket Sans TTF';

class ProductDetailScreen extends StatefulWidget {
  final String productId;

  const ProductDetailScreen({
    super.key,
    required this.productId,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
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
  UserModel? _loggedInUser;

  // 옵션 관련 상태
  List<ProductOption> _productOptions = [];
  Map<ProductOption, int> _selectedOptions = {}; // 옵션과 수량을 함께 관리
  List<SupplyCartLine> _supplyLines = [];

  /// 장바구니 추천 바텀시트와 동일한 API 목록 (`추가 상품 구매하기`)
  List<Product> _recommendedProducts = [];

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
    final productId = widget.productId.trim();
    await Navigator.pushNamed(
      context,
      '/login',
      arguments: {
        if (productId.isNotEmpty) 'returnTo': '/product/$productId',
        'popOnSuccess': true,
      },
    );
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
            productKind: product.productKind ?? 'prescription',
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
      _resumePendingCheckoutIfNeeded();
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

  /// 찜하기 상태 확인
  Future<void> _checkFavoriteStatus() async {
    final isFavorite = await WishService.isWished(widget.productId);
    _safeSetState(() {
      _isFavorite = isFavorite;
    });
  }

  Future<void> _loadReviews() async {
    if (widget.productId.isEmpty) return;

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

  /// 제품 옵션 조회
  Future<void> _loadProductOptions() async {
    if (widget.productId.isEmpty) return;

    try {
      final options =
          await ProductOptionRepository.getProductOptions(widget.productId);
      _safeSetState(() {
        _productOptions = options;
      });
      await _resumePendingCheckoutIfNeeded();
    } catch (e) {
      // 옵션 로드 실패 시 무시
    }
  }

  Future<void> _resumePendingCheckoutIfNeeded() async {
    final pending = PendingProductCheckout.peek();
    if (pending == null || pending.productId != widget.productId) return;
    if (_product == null) return;

    final user = await AuthService.getUser();
    if (user == null || user.id.isEmpty || !mounted) return;

    final taken = PendingProductCheckout.take();
    if (taken == null) return;

    _safeSetState(() {
      _selectedOptions = taken.restoreOptions(_productOptions);
      _supplyLines = taken.restoreSupplyLines();
    });
    if (_selectedOptions.isEmpty || !mounted) return;

    if (taken.action == PendingProductCheckoutAction.reserve) {
      await _startPrescriptionReservationCheckout();
      return;
    }
    final added = await _addPrescriptionItemsToShoppingCart(
      navigateToCart: true,
    );
    if (added != null && mounted) {
      await _loadRecommendedProducts();
    }
  }

  Future<bool> _requireLoginForCheckout({
    required PendingProductCheckoutAction action,
    required String message,
  }) async {
    if (_product == null || _selectedOptions.isEmpty) return false;
    final user = await AuthService.getUser();
    if (user != null && user.id.isNotEmpty) return true;
    if (!mounted) return false;

    PendingProductCheckout.save(
      productId: _product!.id,
      action: action,
      selectedOptions: _selectedOptions,
      supplyLines: _supplyLines,
    );
    if (!mounted) return false;
    final went = await showLoginRequiredDialog(
      context,
      message: message,
      returnTo: '/product/${_product!.id}',
    );
    if (went != true) {
      PendingProductCheckout.clear();
    }
    return false;
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
          wiItKind: 'prescription',
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
    return MobileAppLayoutWrapper(
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
    final supporterReviewCount = _supporterReviews.length;
    final generalReviewCount = _generalReviews.length;

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
                  supporterReviewCount: supporterReviewCount,
                  generalReviewCount: generalReviewCount,
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
                    : _buildNormalReviewTabContent(),
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

  /// 탭 글자 ↔ 핑크 인디케이터 간격 5px
  Widget _buildProductTabBar(
    BuildContext context, {
    required int supporterReviewCount,
    required int generalReviewCount,
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
                    '처방약 소개',
                    indicatorAlign: Alignment.centerLeft,
                    textAlign: TextAlign.left,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: dividerTop),
                  child: _buildTabDivider(context),
                ),
                buildTabItem(1, '서포터 리뷰${supporterReviewCount == 0 ? '(0)' : '(+$supporterReviewCount)'}'),
                Padding(
                  padding: EdgeInsets.only(top: dividerTop),
                  child: _buildTabDivider(context),
                ),
                Padding(
                  padding: EdgeInsets.only(right: healthDp(context, 10)),
                  child: buildTabItem(
                    2,
                    '전체 리뷰${generalReviewCount == 0 ? '(0)' : '(+$generalReviewCount)'}',
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
            SizedBox(height: healthDp(context, 5)), // 상품이름 위 여백
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
                    _displayProductName(),
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
            if (_influencerHandleLine() != null) ...[
              SizedBox(height: healthDp(context, 10)),
              Padding(
                padding: EdgeInsets.only(left: healthDp(context, 8)),
                child: Text(
                  _influencerHandleLine()!,
                  style: TextStyle(
                    color: const Color(0xFF1A1A1E),
                    fontSize: healthSp(context, 16),
                    fontFamily: _kGmarketSans,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ],
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

  Widget _koreanMedicineBadge() {
    return Container(
      padding: EdgeInsets.all(healthDp(context, 5)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(healthDp(context, 30)),
        border: Border.all(
          color: const Color(0xFFFF5A8D),
          width: healthDp(context, 0.5),
        ),
      ),
      child: Text(
        '한의약품',
        style: TextStyle(
          fontSize: healthSp(context, 12),
          fontWeight: FontWeight.w300,
          color: const Color(0xFFFF5A8D),
          fontFamily: _kGmarketSans,
          height: 1.0,
        ),
      ),
    );
  }

  /// 상세 이미지가 모두 끝난 뒤 이어지는 상품 안내 영역.
  Widget _buildProductInfoTail() {
    final precautionsText = _formatPrecautionsForDisplay(
      _product?.additionalInfo?['it_precautions']?.toString(),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: healthDp(context, 20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ProductTailInfoSection(
            framed: true,
            warningText: precautionsText,
            deliveryText:
                _product?.additionalInfo?['it_baesong_content']?.toString(),
            prescriptionProcessText:
                _product?.additionalInfo?['it_shipping_process']?.toString(),
            changeContentText:
                _product?.additionalInfo?['it_change_content']?.toString(),
          ),
          _buildRecommendedSection(),
        ],
      ),
    );
  }

  Widget _buildRecommendedSection() {
    if (_recommendedProducts.isEmpty) return const SizedBox.shrink();

    final products = _recommendedProducts;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 20),
        healthDp(context, 48),
        healthDp(context, 20),
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '|',
                style: TextStyle(
                  color: const Color(0xFF1A1A1E),
                  fontSize: healthSp(context, 22),
                  fontFamily: _kGmarketSans,
                  fontWeight: FontWeight.w300,
                  height: 1,
                ),
              ),
              SizedBox(width: healthDp(context, 6)),
              Text(
                '추가 상품 구매하기',
                style: TextStyle(
                  color: const Color(0xFF1A1A1E),
                  fontSize: healthSp(context, 16),
                  fontFamily: _kGmarketSans,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: healthDp(context, 20)),
          RecommendProductSquareRow(
            products: products,
            detailDesign: true,
            onProductTap: _openRecommendProduct,
          ),
        ],
      ),
    );
  }

  String _formatPrecautionsForDisplay(String? raw) {
    if (raw == null) return '';
    var s = raw.trim();
    if (s.isEmpty) return '';

    // DB 값 예: "과다복용<br />주의|노약자<br />금지|..."
    s = s
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final parts =
        s.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    return parts.join(' | ');
  }

  Widget _buildSupportReviewTabContent() {
    final hideCoupon = _product?.isInfluencerProduct == true;
    return PrescriptionReviewTabPanel(
      reviews: _supporterReviews,
      isLoading: _isLoadingReviews,
      visibleCount: _visibleSupporterReviewCount,
      guestLoginLocked: !_isReviewLoginOk,
      onGuestLoginTap: _onGuestReviewLoginTap,
      embedInParentScroll: true,
      showCouponSection: !hideCoupon,
      fallbackImageUrl: _reviewFallbackImageUrl,
      onLoadMore: () {
        _safeSetState(() {
          _visibleSupporterReviewCount += 3;
        });
      },
      onReviewTap: _openReviewDetail,
    );
  }

  Widget _buildNormalReviewTabContent() {
    return PrescriptionReviewTabPanel(
      reviews: _generalReviews,
      isLoading: _isLoadingReviews,
      visibleCount: _visibleNormalReviewCount,
      guestLoginLocked: !_isReviewLoginOk,
      onGuestLoginTap: _onGuestReviewLoginTap,
      embedInParentScroll: true,
      showCouponSection: false,
      fallbackImageUrl: _reviewFallbackImageUrl,
      onLoadMore: () {
        _safeSetState(() {
          _visibleNormalReviewCount += 3;
        });
      },
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
    final imageHeight = healthDp(context, 230);

    if (images.isEmpty) {
      return ClipRRect(
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
          child: Container(
            height: imageHeight,
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
    }

    // PageController 초기화 (이미지가 2개 이상일 때만)
    if (images.length > 1 && _pageController == null) {
      _pageController = PageController();
    }

    return SizedBox(
      height: imageHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
        child: Stack(
          children: [
            WebDragScrollConfiguration(
              child: PageView.builder(
              controller: _pageController,
              physics: const PageScrollPhysics(),
              itemCount: images.length,
              onPageChanged: (index) {
                _safeSetState(() {
                  _currentImageIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final imageUrl = images[index];

                return ColoredBox(
                  color: const Color(0xFFF8F8F8),
                  child: buildProductCarouselImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  height: imageHeight,
                  fit: BoxFit.cover,
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
                ),
                );
              },
              ),
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
        ),
      ),
    );
  }

  /// 상품명에 들어 있는 `(@아이디)`만 따로 뺀다. 없으면 줄을 만들지 않는다.
  String _displayProductName() {
    final name = _product?.name ?? '';
    final stripped = name
        .replaceAll(RegExp(r'\s*\(@[^)]+\)'), '')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .trim();
    return stripped.isEmpty ? name : stripped;
  }

  String? _influencerHandleLine() {
    final name = _product?.name ?? '';
    return RegExp(r'\(@[^)]+\)').firstMatch(name)?.group(0);
  }

  /// 제목 밑 설명 (it_basic) 표시
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
      height: 1.50,
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
    const originalPriceColor = Color(0xFF898686);
    const priceColor = Color(0xFF1A1A1E);
    const discountColor = Color(0xFFFF5A8D);
    final hasOriginalPrice = _product!.originalPrice != null &&
        _product!.originalPrice! > _product!.price;
    final showDiscount = discountRate != null && discountRate > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasOriginalPrice)
          Text(
            _product!.formattedOriginalPrice ?? '',
            style: TextStyle(
              color: originalPriceColor,
              fontSize: healthSp(context, 14),
              fontFamily: _kGmarketSans,
              fontWeight: FontWeight.w300,
              decoration: TextDecoration.lineThrough,
              decorationColor: originalPriceColor,
            ),
          ),
        if (hasOriginalPrice) SizedBox(height: healthDp(context, 4)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (showDiscount) ...[
                    Text(
                      '${discountRate.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: healthSp(context, 20),
                        fontWeight: FontWeight.w700,
                        color: discountColor,
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
                      color: priceColor,
                      fontFamily: _kGmarketSans,
                    ),
                  ),
                  SizedBox(width: healthDp(context, 8)),
                  _koreanMedicineBadge(),
                ],
              ),
            ),
            _buildShareButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildShareButton() {
    final iconSz = healthDp(context, 24);
    final tapSize = healthDp(context, 24);

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
              productKind: _product!.productKind,
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
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).pushReplacementNamed('/home');
                    }
                  },
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
                      prescriptionTab: _product?.ctKind != 'general',
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
                  horizontalPadding: healthDp(context, 20),
                  expandButtonColor: const Color(0xFFFF5A8D),
                  expandButtonHorizontalPadding: 24,
                  expandButtonGap: 20,
                  expandButtonHug: true,
                  margin: EdgeInsets.only(
                    top: healthDp(context, 20),
                    bottom: healthDp(context, 20),
                  ),
                  onExpand: () => _detailExpanded.value = true,
                ),
              ),
            SliverToBoxAdapter(child: _buildProductInfoTail()),
          ],
        );
      },
    );
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

  Widget _buildBottomActionBar() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.80),
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
              Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                  side: BorderSide(
                    color: const Color(0xFFD2D2D2),
                    width: healthDp(context, 0.5),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _toggleFavorite,
                  child: SizedBox(
                    width: healthDp(context, 40),
                    height: healthDp(context, 40),
                    child: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: healthDp(context, 22),
                      color: _isFavorite
                          ? const Color(0xFFFF5A8D)
                          : const Color(0xFF898686),
                    ),
                  ),
                ),
              ),
              SizedBox(width: healthDp(context, 10)),
              Expanded(
                child: SizedBox(
                  height: healthDp(context, 40),
                  child: Material(
                    color: const Color(0xFFFF5A8D),
                    borderRadius: BorderRadius.circular(healthDp(context, 10)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _showOptionSelectionDialog,
                      child: Center(
                        child: Text(
                          '처방 예약하기',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: healthSp(context, 16),
                            fontFamily: _kGmarketSans,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
      onToggleFavorite: _toggleFavorite,
      onNoOptionGeneral: () async {},
      onNoOptionPrescription: _proceedWithReservation,
      onOptionsChanged: (newOptions) {
        // 수량 탭마다 상세 페이지를 다시 그리면 바텀시트가 멈춘 것처럼 보인다.
        _selectedOptions = newOptions;
      },
      onSupplyLinesChanged: (lines) {
        _supplyLines = lines;
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

        Navigator.of(context).pop();

        if (!mounted) return;

        final addFuture = CartService.addOptionsToCart(
          product: _product!,
          selectedOptions: _selectedOptions,
          supplyLines: _supplyLines,
        );
        addFuture.then(_onCartAddCompleted);

        if (!mounted) return;
        await _showRecommendProductBottomup(cartAddFuture: addFuture);
      },
      onAddToPrescriptionCart: () async {
        if (_product == null || _selectedOptions.isEmpty) return;

        final loggedIn = await _requireLoginForCheckout(
          action: PendingProductCheckoutAction.prescriptionCart,
          message: '진료담기는 로그인 후 이용할 수 있습니다.',
        );
        if (!loggedIn || !mounted) return;

        Navigator.of(context).pop();

        if (!mounted) return;

        final addFuture = CartService.addOptionsToCart(
          product: _product!,
          selectedOptions: _selectedOptions,
          supplyLines: _supplyLines,
        );
        addFuture.then(_onCartAddCompleted);

        if (!mounted) return;
        await _showRecommendProductBottomup(cartAddFuture: addFuture);
      },
      onReserve: () async {
        if (_product == null || _selectedOptions.isEmpty) return;

        final loggedIn = await _requireLoginForCheckout(
          action: PendingProductCheckoutAction.reserve,
          message: '처방예약은 로그인 후 이용할 수 있습니다.',
        );
        if (!loggedIn || !mounted) return;

        Navigator.of(context).pop();

        if (!mounted) return;

        await _startPrescriptionReservationCheckout();
      },
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

        Navigator.of(context).pop();

        if (!mounted) return;

        await _addPrescriptionItemsToShoppingCart(navigateToCart: true);
      },
    );
  }

  List<Map<String, dynamic>> _cartItemsToBookingOptions(List<CartItem> items) {
    return items
        .map(
          (item) => <String, dynamic>{
            'it_id': item.itId,
            'it_name': item.itName,
            'id': item.ioId ?? '',
            'name': item.displayOptionText.isNotEmpty
                ? item.displayOptionText
                : item.itName,
            'price': item.ioPrice ?? 0,
            'quantity': item.ctQty,
            'totalPrice': item.ctPrice,
            'ct_kind': item.ctKind,
          },
        )
        .toList();
  }

  Future<void> _startPrescriptionReservationCheckout() async {
    if (_product == null || _selectedOptions.isEmpty || !mounted) return;

    final product = _product!;
    final options = Map<ProductOption, int>.from(_selectedOptions);
    final supply = List<SupplyCartLine>.from(_supplyLines);
    final itemsFuture = _bookingItemsAfterAdd(
      product: product,
      options: options,
      supply: supply,
    );
    setState(() {
      _selectedOptions.clear();
      _supplyLines.clear();
    });

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => PrescriptionProfileScreen(
          productId: product.id,
          productName: product.name,
          checkoutItemsFuture: itemsFuture,
        ),
      ),
    );
  }

  Future<List<CartItem>> _bookingItemsAfterAdd({
    required Product product,
    required Map<ProductOption, int> options,
    required List<SupplyCartLine> supply,
  }) async {
    final result = await CartService.addOptionsToCart(
      product: product,
      selectedOptions: options,
      supplyLines: supply,
    );
    if (result['success'] != true) return const [];

    final added = CartService.addedItemsFromAddOptionsResult(result);
    if (added.isNotEmpty) return added;

    final cartIds = CartService.cartIdsFromAddOptionsResult(result);
    if (cartIds.isEmpty) return const [];

    final cartResult = await CartService.getCart();
    if (cartResult['success'] != true) return const [];
    final rawItems = cartResult['data'];
    final allItems = (rawItems is List ? rawItems : [])
        .whereType<Map>()
        .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final addedIdSet = cartIds.toSet();
    return allItems.where((item) => addedIdSet.contains(item.ctId)).toList();
  }

  Future<void> _openMatchingCart(
    Future<Map<String, dynamic>>? cartAddFuture,
  ) async {
    final result = cartAddFuture != null ? await cartAddFuture : null;
    if (!mounted) return;
    final items = result == null
        ? const <CartItem>[]
        : CartService.addedItemsFromAddOptionsResult(result);
    await CartNavigation.openCart(
      context,
      prescriptionTab: CartNavigation.prescriptionTabFor(
        product: _product,
        addedItems: items,
      ),
    );
  }

  Future<void> _showRecommendProductBottomup({
    Future<Map<String, dynamic>>? cartAddFuture,
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
    if (cached.isEmpty && productsLoader == null) return;

    await showRecommendProductBottomup(
      context: context,
      products: cached,
      productsLoader: productsLoader,
      onProductTap: (product) {
        Navigator.of(context).pop();
        _openRecommendProduct(product);
      },
      onGoToCart: () {
        _openMatchingCart(cartAddFuture);
      },
      onPrimaryAction: () async {
        await _navigateToPrescriptionBooking(cartAddFuture: cartAddFuture);
      },
    );
  }

  Future<void> _navigateToPrescriptionBooking({
    Future<Map<String, dynamic>>? cartAddFuture,
  }) async {
    if (_product == null || !mounted) return;

    Map<String, dynamic>? addResult;
    if (cartAddFuture != null) {
      addResult = await cartAddFuture;
      if (!mounted || addResult['success'] != true) return;
    } else {
      final addedCtIds = await _addPrescriptionItemsToShoppingCart(
        navigateToCart: false,
      );
      if (addedCtIds == null || addedCtIds.isEmpty || !mounted) return;

      final cartResult = await CartService.getCart();
      if (!mounted || cartResult['success'] != true) return;

      final rawItems = cartResult['data'];
      final allItems = (rawItems is List ? rawItems : [])
          .whereType<Map>()
          .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final addedIdSet = addedCtIds.toSet();
      final bookingItems =
          allItems.where((item) => addedIdSet.contains(item.ctId)).toList();
      if (bookingItems.isEmpty || !mounted) return;

      await _openPrescriptionProfileFlow(bookingItems);
      return;
    }

    var bookingItems = CartService.addedItemsFromAddOptionsResult(addResult);
    if (bookingItems.isEmpty) {
      final cartIds = CartService.cartIdsFromAddOptionsResult(addResult);
      if (cartIds.isEmpty || !mounted) return;

      final cartResult = await CartService.getCart();
      if (!mounted || cartResult['success'] != true) return;

      final rawItems = cartResult['data'];
      final allItems = (rawItems is List ? rawItems : [])
          .whereType<Map>()
          .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final addedIdSet = cartIds.toSet();
      bookingItems =
          allItems.where((item) => addedIdSet.contains(item.ctId)).toList();
    }

    if (bookingItems.isEmpty || !mounted) return;
    await _openPrescriptionProfileFlow(bookingItems);
  }

  Future<void> _openPrescriptionProfileFlow(List<CartItem> bookingItems) async {
    if (bookingItems.isEmpty || !mounted) return;

    if (!mounted) return;

    final booking = HealthProfilePrescriptionBookingArgs(
      productId: bookingItems.first.itId,
      productName: bookingItems.first.itName,
      selectedOptions: _cartItemsToBookingOptions(bookingItems),
      cartCtIdsForCheckout: bookingItems.map((e) => e.ctId).toList(),
      checkoutCartItems: bookingItems,
      checkoutShippingCost: 0,
    );

    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => PrescriptionProfileScreen(
          productId: booking.productId,
          productName: booking.productName,
          selectedOptions: booking.selectedOptions,
          cartCtIdsForCheckout: booking.cartCtIdsForCheckout,
          checkoutCartItems: booking.checkoutCartItems,
          checkoutShippingCost: booking.checkoutShippingCost,
        ),
      ),
    );
  }

  void _onCartAddCompleted(Map<String, dynamic> result) {
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _selectedOptions.clear();
        _supplyLines.clear();
      });
      return;
    }
    final message = (result['message'] ?? '장바구니 담기에 실패했습니다.').toString();
    AppToastOverlay.show(context, message);
  }

  Future<List<int>?> _addPrescriptionItemsToShoppingCart({
    bool navigateToCart = true,
  }) async {
    if (_product == null || _selectedOptions.isEmpty) return null;

    final user = await AuthService.getUser();
    if (user == null || user.id.isEmpty) {
      if (!mounted) return null;
      await showLoginRequiredDialog(
        context,
        message: '진료담기는 로그인 후 이용할 수 있습니다.',
      );
      return null;
    }

    if (!mounted) return null;

    final result = await CartService.addOptionsToCart(
      product: _product!,
      selectedOptions: _selectedOptions,
      supplyLines: _supplyLines,
    );

    if (!mounted) return null;

    if (result['success'] == true) {
      final cartIds = CartService.cartIdsFromAddOptionsResult(result);
      setState(() {
        _selectedOptions.clear();
        _supplyLines.clear();
      });
      if (navigateToCart && mounted) {
        await CartNavigation.openCart(
          context,
          prescriptionTab: CartNavigation.prescriptionTabFor(product: _product),
        );
      }
      return cartIds;
    }
    return null;
  }

  /// 옵션 선택 후 예약 진행
  void _proceedWithReservation() {
    if (_selectedOptions.isEmpty || _product == null) return;
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
