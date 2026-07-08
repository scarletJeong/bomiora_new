import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_assets.dart';
import '../../../data/models/product/product_model.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../../data/models/review/review_model.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/point_helper.dart';
import '../../../core/utils/node_value_parser.dart';
import '../../../core/utils/product_share.dart';
import '../../../core/utils/inf_code_tracker.dart';
import '../../../data/services/point_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/wish_service.dart';
import '../../../data/services/recent_view_service.dart';
import '../../../data/services/cart_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../data/models/user/user_model.dart';
import '../../../data/models/product/product_option_model.dart';
import '../../../data/repositories/product/product_option_repository.dart';
import '../../../data/models/cart/cart_item_model.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../widgets/product_tail_info_section.dart';
import '../widgets/option_bottomup.dart';
import '../widgets/producrt_normal_review.dart';
import '../widgets/recommend_product.dart';
import '../widgets/recommend_product_bottomup.dart';
import '../utils/get_review.dart';
import '../utils/product_detail_html_helper.dart';
import 'cart_general_screen.dart' as cart_general;
import 'payment_screen.dart';
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
  String? _errorMessage;
  bool _isFavorite = false;
  int _currentImageIndex = 0;
  late TabController _tabController;
  PageController? _pageController;

  // 리뷰 관련 상태
  List<ReviewModel> _generalReviews = [];
  bool _isLoadingReviews = false;
  int? _userPoint; // 현재 사용자 보유 포인트
  bool? _usePointConfig; // cf_use_point 설정값
  bool? _isDetailExpanded = false;
  int _visibleNormalReviewCount = 4;
  UserModel? _loggedInUser;

  // 옵션 관련 상태
  List<ProductOption> _productOptions = [];
  Map<ProductOption, int> _selectedOptions = {}; // 옵션과 수량을 함께 관리
  List<Product> _recommendedProducts = [];

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // 탭 변경 시 UI 업데이트
      if (!_tabController.indexIsChanging) {
        _safeSetState(() {});
      }
    });
    _loadProductDetail().then((_) {
      _loadReviews();
      if (_product?.isInfluencerProduct != true) {
        _loadUserPoint();
      }
    });
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
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _loadProductDetail() async {
    _safeSetState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final product =
          await ProductRepository.getProductDetail(widget.productId);
      _safeSetState(() {
        _product = product;
        _isLoading = false;
        if (product == null) {
          _hasError = true;
          _errorMessage = '제품 정보를 찾을 수 없습니다.';
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
          );
        }
      });

      // 찜하기 상태 확인
      await _checkFavoriteStatus();
      await _loadRecommendedProducts();
    } catch (e) {
      _safeSetState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = '제품 정보를 불러오는데 실패했습니다: $e';
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
    final basePath =
        kind == 'general' ? '/product-general/${product.id}' : '/product/${product.id}';
    final inf = InfCodeTracker.current;
    final route = (inf != null && inf.isNotEmpty)
        ? '$basePath?infcode=${Uri.encodeComponent(inf)}'
        : basePath;
    await Navigator.pushNamed(context, route);
    if (!mounted) return;
    await _loadProductDetail();
  }

  Widget _buildRecommendedSection() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 27),
        healthDp(context, 20),
        healthDp(context, 27),
        healthDp(context, 40),
      ),
      child: RecommendProductSection(
        excludedProductNames: [_product?.name ?? ''],
        products: _recommendedProducts,
        title: '추가 상품 구매하기',
        titleStyle: shoppingSectionTitleStyle(context),
        showLeadingBar: true,
        hideWhenEmpty: true,
        useVerticalList: true,
        prescriptionGroupOrdering: false,
        maxItems: 4,
        onProductTap: _openRecommendProduct,
      ),
    );
  }

  /// 찜하기 상태 확인
  Future<void> _checkFavoriteStatus() async {
    try {
      final wishList = await WishService.getWishList();

      // 현재 상품이 찜 목록에 있는지 확인
      final isFavorite = wishList.any((item) {
        // it_id 필드로 비교
        final itemId = item is Map
            ? (NodeValueParser.asString(item['it_id']) ??
                NodeValueParser.asString(item['itId']) ??
                '')
            : '';
        return itemId == widget.productId;
      });

      _safeSetState(() {
        _isFavorite = isFavorite;
      });
    } catch (e) {
      // 에러 발생 시 기본값(false) 유지
    }
  }

  Future<void> _loadReviews() async {
    if (widget.productId.isEmpty) return;

    _safeSetState(() {
      _isLoadingReviews = true;
    });

    try {
      final loaded = await ProductReviewLoader.load(
        productId: widget.productId,
        product: _product,
      );

      if (loaded != null) {
        _safeSetState(() {
          _generalReviews = loaded.generalReviews;
          _visibleNormalReviewCount = 4;
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
    try {
      final response = await ApiClient.get(ApiEndpoints.config);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final config = data['data'];
          _safeSetState(() {
            _usePointConfig =
                config['cf_use_point'] == 1 || config['cf_use_point'] == true;
          });
        }
      }
    } catch (e) {
      // 기본값 설정
      _safeSetState(() {
        _usePointConfig = true;
      });
    }
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
    } catch (e) {
      // 옵션 로드 실패 시 무시
    }
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
        await WishService.addToWish(widget.productId);
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: healthDp(context, 64),
            color: Colors.grey[400],
          ),
          SizedBox(height: healthDp(context, 16)),
          Text(
            _errorMessage ?? '제품 정보를 불러올 수 없습니다',
            style: TextStyle(
              fontSize: healthSp(context, 16),
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: healthDp(context, 24)),
          ElevatedButton(
            onPressed: _loadProductDetail,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductDetail() {
    final generalReviewCount = _generalReviews.length;

    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildProductInfoSection(),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                _buildProductTabBar(
                  context,
                  generalReviewCount: generalReviewCount,
                ),
                height: _productTabBarHeight(context),
              ),
            ),
            if (_tabController.index == 0) ...[
              SliverToBoxAdapter(child: _buildDetailPreviewSection()),
              SliverToBoxAdapter(
                child: ProductTailInfoSection(
                  showCertification: false,
                  showWarning: false,
                  showPrescriptionProcess: false,
                  deliveryText: _product
                      ?.additionalInfo?['it_baesong_content']
                      ?.toString(),
                  changeContentText: _product
                      ?.additionalInfo?['it_change_content']
                      ?.toString(),
                ),
              ),
              SliverToBoxAdapter(child: _buildRecommendedSection()),
              SliverToBoxAdapter(
                child: SizedBox(height: healthDp(context, 40)),
              ),
            ] else
              SliverToBoxAdapter(child: _buildNormalReviewTab()),
          ],
        );
      },
    );
  }

  double _productTabBarPaddingTop(BuildContext context) => healthDp(context, 20);

  double _productTabBarPaddingBottom(BuildContext context) =>
      healthDp(context, 10);

  double _productTabBarContentHeight(BuildContext context) {
    final gap = healthDp(context, 5);
    final indicatorH = healthDp(context, 1.5);
    final labelStyle = TextStyle(
      fontSize: healthSp(context, 12),
      fontFamily: _kGmarketSans,
      fontWeight: FontWeight.w700,
      height: 1.0,
    );
    final textPainter = TextPainter(
      text: TextSpan(text: '일반 리뷰 (999)', style: labelStyle),
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
    required int generalReviewCount,
  }) {
    const pink = Color(0xFFFF5A8D);
    const gray = Color(0xFF898383);
    final gap = healthDp(context, 5);
    final indicatorH = healthDp(context, 1.5);
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
      text: TextSpan(text: '일반 리뷰 (999)', style: labelStyle),
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
              decoration: BoxDecoration(
                color: pink,
                borderRadius: BorderRadius.circular(healthDp(context, 22)),
              ),
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
            healthDp(context, 27),
            _productTabBarPaddingTop(context),
            healthDp(context, 27),
            _productTabBarPaddingBottom(context),
          ),
          child: SizedBox(
            height: _productTabBarContentHeight(context),
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildTabItem(
                  0,
                  '상품 소개',
                ),
                SizedBox(width: healthDp(context, 12)),
                Padding(
                  padding: EdgeInsets.only(top: dividerTop),
                  child: _buildTabDivider(context),
                ),
                SizedBox(width: healthDp(context, 12)),
                buildTabItem(
                  1,
                  '일반 리뷰 ($generalReviewCount)',
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
        padding: EdgeInsets.symmetric(horizontal: healthDp(context, 27)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: topInset + kToolbarHeight + healthDp(context, 0),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    top: healthDp(context, 3),
                    right: healthDp(context, 8),
                  ),
                  child: Container(
                    width: healthDp(context, 1),
                    height: healthDp(context, 20),
                    color: const Color(0xFF1A1A1E),
                  ),
                ),
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
            SizedBox(height: healthDp(context, 10)),
            _buildImageCarousel(_getProductImages()),
            SizedBox(height: healthDp(context, 10)),
            _buildPriceSection(),
            SizedBox(height: healthDp(context, 10)),
            Divider(
              height: healthDp(context, 1),
              thickness: healthDp(context, 1),
              color: Colors.grey.shade300,
            ),
            _buildProductSpecs(),
          ],
        ),
      ),
    );
  }

  Widget _buildNormalReviewTab() {
    return ProductNormalReview(
      reviews: _generalReviews,
      isLoading: _isLoadingReviews,
      visibleCount: _visibleNormalReviewCount,
      guestLoginLocked: !_isReviewLoginOk,
      onGuestLoginTap: _onGuestReviewLoginTap,
      embedInParentScroll: true,
      onLoadMore: () {
        _safeSetState(() {
          _visibleNormalReviewCount += 8;
        });
      },
      onReviewTap: (_) {},
    );
  }

  Widget _buildImageCarousel(List<String> images) {
    final screenWidth = MediaQuery.of(context).size.width;
    final imageHeight = healthDp(context, 240);
    final maxWidth = screenWidth.clamp(
      healthDp(context, 200),
      healthDp(context, 600),
    );

    if (images.isEmpty) {
      final emptyContainer = ClipRRect(
          borderRadius: BorderRadius.circular(healthDp(context, 12)),
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
        borderRadius: BorderRadius.circular(healthDp(context, 12)),
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

    return Text(
      itBasic,
      style: TextStyle(
        color: const Color(0xFF808080),
        fontSize: healthSp(context, 10),
        fontFamily: _kGmarketSans,
        fontWeight: FontWeight.w300,
      ),
    );
  }

  Widget _buildProductSpecs() {
    final mainSpecs = <Map<String, String>>[];

    if (_product!.additionalInfo != null) {
      final info = _product!.additionalInfo!;
      final weightRaw = info['it_weight'];
      final weightValue = weightRaw?.toString().trim();
      if (weightValue != null && weightValue.isNotEmpty) {
        mainSpecs.add({
          'label': '중량/용량',
          'value': weightValue,
        });
      }

      if (info['it_prescription'] != null &&
          info['it_prescription'].toString().isNotEmpty) {
        mainSpecs.add({
          'label': '처방단위',
          'value': info['it_prescription'].toString(),
        });
      }

      if (info['it_takeway'] != null &&
          info['it_takeway'].toString().isNotEmpty) {
        mainSpecs.add({
          'label': '복용방법',
          'value': info['it_takeway'].toString(),
        });
      }

      final pointText = PointHelper.calculatePointText(
        pointType: info['it_point_type'],
        point: info['it_point'],
        usePoint: _usePointConfig ?? true,
        price: _product!.price,
      );

      if (pointText != null && _product?.isInfluencerProduct != true) {
        mainSpecs.add({
          'label': '적립포인트',
          'value': pointText,
        });
      }
    }

    const deliverySpec = {
      'label': '배송비',
      'value': '주문시 결제',
    };

    final specTextStyle = TextStyle(
      fontSize: healthSp(context, 12),
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
            width: healthDp(context, 78),
            child: Text(
              spec['label']!,
              style: specTextStyle,
            ),
          ),
          Expanded(
            child: Text(
              spec['value']!,
              style: specTextStyle,
            ),
          ),
        ],
      );
    }

    Widget specDivider() => Divider(
          height: healthDp(context, 1),
          thickness: healthDp(context, 1),
          color: Colors.grey.shade300,
        );

    final itemGap = healthDp(context, 10);
    final children = <Widget>[
      SizedBox(height: healthDp(context, 20)),
    ];

    for (var i = 0; i < mainSpecs.length; i++) {
      if (i > 0) {
        children.add(SizedBox(height: itemGap));
      }
      children.add(buildSpecRow(mainSpecs[i]));
    }

    if (mainSpecs.isNotEmpty) {
      children.add(SizedBox(height: itemGap));
    }
    children.add(buildSpecRow(deliverySpec));
    children.add(SizedBox(height: healthDp(context, 20)));
    children.add(specDivider());
    children.add(SizedBox(height: healthDp(context, 10)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildPriceSection() {
    final discountRate = _product!.discountRate;
    const originalPriceColor = Color(0xFFB3B3B3);
    final hasOriginalPrice = _product!.originalPrice != null &&
        _product!.originalPrice! > _product!.price;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
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
                    color: originalPriceColor,
                    fontSize: healthSp(context, 12),
                    fontFamily: _kGmarketSans,
                    fontWeight: FontWeight.w300,
                    height: 1.0,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: originalPriceColor,
                  ),
                ),
              if (hasOriginalPrice) SizedBox(height: healthDp(context, 5)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _product!.formattedPrice,
                    style: TextStyle(
                      fontSize: healthSp(context, 20),
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      fontFamily: _kGmarketSans,
                    ),
                  ),
                  if (discountRate != null && discountRate > 0) ...[
                    SizedBox(width: healthDp(context, 8)),
                    Text(
                      '${discountRate.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: healthSp(context, 20),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFF4081),
                        fontFamily: _kGmarketSans,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildShareButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildShareButton() {
    final iconSz = healthDp(context, 20);
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

  Widget _buildFloatingTransparentAppBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.chevron_left,
                  color: Colors.black,
                  size: healthDp(context, 28),
                ),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacementNamed('/home');
                  }
                },
              ),
            ],
          ),
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

  Widget _buildDetailHtml({required String html}) {
    return buildProductDetailHtml(
      context: context,
      html: html,
      fontFamily: _kGmarketSans,
    );
  }

  Widget _buildDetailPreviewSection() {
    final processedHtml = _getProcessedDetailHtml();
    if (processedHtml.isEmpty) return const SizedBox.shrink();
    final collapsedPreviewHeight = healthDp(context, 320);
    final isExpanded = _isDetailExpanded == true;
    final hPad = healthDp(context, 27);

    return Container(
      margin: EdgeInsets.only(top: healthDp(context, 24)),
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        children: [
          if (isExpanded) ...[
            _buildDetailHtml(html: processedHtml),
          ] else ...[
            ClipRect(
              child: SizedBox(
                height: collapsedPreviewHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _buildDetailHtml(html: processedHtml),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                          child: Container(
                            height: healthDp(context, 50),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withOpacity(0.05),
                                  Colors.white.withOpacity(0.78),
                                ],
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
            SizedBox(
              height: healthDp(context, 24),
              child: OutlinedButton(
                onPressed: () {
                  _safeSetState(() {
                    _isDetailExpanded = true;
                  });
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: const Color(0xFFFF4081),
                    width: healthDp(context, 1),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 14)),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 40),
                    vertical: healthDp(context, 5),
                  ),
                  foregroundColor: const Color(0xFFFF4081),
                ),
                child: Text(
                  '+ 자세히 보기',
                  style: TextStyle(
                    fontSize: healthSp(context, 12),
                    fontWeight: FontWeight.w500,
                    fontFamily: _kGmarketSans,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 27),
        vertical: healthDp(context, 12),
      ),
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
                  color:
                      _isFavorite ? const Color(0xFFFF4081) : Colors.grey[600],
                ),
                onPressed: () => _toggleFavorite(),
              ),
            ),
            SizedBox(width: healthDp(context, 10)),
            Expanded(
              child: ElevatedButton(
                onPressed: _showOptionSelectionDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4081),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: healthDp(context, 10)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 10)),
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
          ],
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

        final result = await CartService.addOptionsToCart(
          product: _product!,
          selectedOptions: _selectedOptions,
          mergeIfExists: true,
        );

        if (!mounted) return;

        if (result['success'] == true) {
          _safeSetState(() {
            _selectedOptions.clear();
          });
          await _showRecommendProductBottomup();
        }
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
        Navigator.of(context).pop();
        if (!mounted) return;

        await _buySelectedGeneralProductNow(selectedOptions: options);
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

  Future<Set<int>> _snapshotGeneralCartIds() async {
    final cart = await CartService.getCart();
    if (cart['success'] != true) return {};
    return _parseGeneralCartItems(cart).map((e) => e.ctId).toSet();
  }

  String _ctOptionText(ProductOption option) {
    if (option.months != null) {
      return '${option.step} / ${option.months}일';
    }
    return option.step;
  }

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
            (item) =>
                item.itId == _product!.id && item.ctOption.trim().isEmpty,
          )
          .toList();
      if (noOptionItems.isEmpty) return [];
      return [noOptionItems.last];
    }

    return [];
  }

  void _showBuyNowFailedSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('결제 정보를 불러오지 못했습니다. 다시 시도해 주세요.')),
    );
  }

  int _resolveBuyNowShippingCost({
    required List<CartItem> payItems,
    required List<CartItem> allGeneralItems,
    required int cartShippingCost,
  }) {
    if (payItems.isEmpty) return 0;
    if (payItems.length == allGeneralItems.length &&
        payItems.every(
          (item) => allGeneralItems.any((all) => all.ctId == item.ctId),
        )) {
      return cartShippingCost;
    }
    return 0;
  }

  Future<void> _openGeneralPaymentScreen({
    required List<CartItem> payItems,
    required int shippingCost,
  }) async {
    if (!mounted || payItems.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/pay'),
        builder: (_) => PaymentScreen(
          cartItems: payItems,
          shippingCost: shippingCost,
          sourceTitle: '일반상품 결제',
        ),
      ),
    );
  }

  Future<void> _buySelectedGeneralProductNow({
    Map<ProductOption, int>? selectedOptions,
    int? quantity,
  }) async {
    if (_product == null) return;

    final hasOptions =
        selectedOptions != null && selectedOptions.isNotEmpty;
    if (!hasOptions && (quantity == null || quantity <= 0)) return;

    final beforeIds = await _snapshotGeneralCartIds();

    final Map<String, dynamic> result;
    if (hasOptions) {
      result = await CartService.addOptionsToCart(
        product: _product!,
        selectedOptions: selectedOptions!,
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
    });

    final payItems = await _resolveGeneralBuyNowPayItems(
      beforeIds: beforeIds,
      selectedOptions: selectedOptions,
      quantity: quantity,
    );
    if (!mounted || payItems.isEmpty) {
      _showBuyNowFailedSnackBar();
      return;
    }

    final cart = await CartService.getCart();
    if (!mounted || cart['success'] != true) return;

    final allGeneralItems = _parseGeneralCartItems(cart);
    final cartShippingCost = (cart['shipping_cost'] as num?)?.toInt() ?? 0;
    final shippingCost = _resolveBuyNowShippingCost(
      payItems: payItems,
      allGeneralItems: allGeneralItems,
      cartShippingCost: cartShippingCost,
    );

    await _openGeneralPaymentScreen(
      payItems: payItems,
      shippingCost: shippingCost,
    );
  }

  Future<void> _showRecommendProductBottomup() async {
    if (_product == null || !mounted) return;

    final products =
        await CartService.getProductRecommendProducts(_product!.id);
    if (!mounted || products.isEmpty) return;

    await showRecommendProductBottomup(
      context: context,
      products: products,
      onProductTap: (product) {
        Navigator.of(context).pop();
        _openRecommendProduct(product);
      },
      onGoToCart: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const cart_general.CartScreen(),
          ),
        );
      },
    );
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
        final success = await _addGeneralProductToCart(quantity: quantity);
        if (!mounted || !success) return;
        await _showRecommendProductBottomup();
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
