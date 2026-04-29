// TODO step2
import 'dart:ui';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_html/flutter_html.dart';
import '../../../data/models/product/product_model.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../../data/models/review/review_model.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/point_helper.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/utils/node_value_parser.dart';
import '../../../core/utils/product_share.dart';
import '../../../data/services/point_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/wish_service.dart';
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
import '../utils/get_review.dart';
import 'cart_general_screen.dart' as cart_general;
import 'payment_screen.dart';
import '../../common/widgets/login_required_dialog.dart';

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
  List<ReviewModel> _reviews = [];
  List<ReviewModel> _generalReviews = [];
  Map<String, dynamic>? _reviewStats;
  bool _isLoadingReviews = false;
  int? _userPoint; // 현재 사용자 보유 포인트
  bool? _usePointConfig; // cf_use_point 설정값
  bool? _isDetailExpanded = false;
  int _visibleNormalReviewCount = 4;
  UserModel? _loggedInUser;

  // 옵션 관련 상태
  List<ProductOption> _productOptions = [];
  Map<ProductOption, int> _selectedOptions = {}; // 옵션과 수량을 함께 관리

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    // 상품정보, 리뷰 (일반 리뷰 탭은 step2에서 재검토)
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // 탭 변경 시 UI 업데이트
      if (!_tabController.indexIsChanging) {
        _safeSetState(() {});
      }
    });
    _loadProductDetail().then((_) {
      // 제품 정보 로드 후 리뷰 로드 (it_org_id 확인을 위해)
      _loadReviews();
    });
    _loadUserPoint();
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
        }
      });

      // 찜하기 상태 확인
      await _checkFavoriteStatus();
    } catch (e) {
      _safeSetState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = '제품 정보를 불러오는데 실패했습니다: $e';
      });
    }
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

      print(
          '📌 [찜하기] 상태 확인 완료 - 상품 ID: ${widget.productId}, 찜 상태: $_isFavorite');
    } catch (e) {
      print('⚠️ [찜하기] 상태 확인 실패: $e');
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
          _reviews = loaded.allReviews;
          _generalReviews = loaded.generalReviews;
          _visibleNormalReviewCount = 4;
          _reviewStats = loaded.stats;
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
      print('⚠️ [옵션] 로드 실패: $e');
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            width: 568, // 600px - 32px (양쪽 16px 여백)
            duration: const Duration(seconds: 2),
          ),
        );
      }
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
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? '제품 정보를 불러올 수 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
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

    return NestedScrollView(
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return [
          // 제품 정보 섹션
          SliverToBoxAdapter(
            child: _buildProductInfoSection(),
          ),

          // 탭바
          SliverPersistentHeader(
            pinned: false,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFFF4081),
                indicatorWeight: 3,
                labelColor: const Color(0xFFFF4081),
                unselectedLabelColor: Colors.grey[600],
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontFamily: _kGmarketSans,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontFamily: _kGmarketSans,
                ),
                tabs: [
                  const Tab(
                    child: Text(
                      '상품 소개',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: _kGmarketSans,
                      ),
                    ),
                  ),
                  Tab(
                    child: Text(
                      '일반 리뷰 ($generalReviewCount)',
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: _kGmarketSans,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductInfoTab(),
          _buildNormalReviewTab(),
        ],
      ),
    );
  }

  /// 제품 정보 섹션 (탭 위에 고정)
  Widget _buildProductInfoSection() {
    final topSafeInset = MediaQuery.of(context).padding.top;
    final dynamicTopSpacing = topSafeInset + (kToolbarHeight * 1.15);
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: dynamicTopSpacing),
            // 제품명 (앞 세로 막대)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 8),
                  child: Container(
                    width: 2,
                    height: 20,
                    color: Colors.black87,
                  ),
                ),
                Expanded(
                  child: Text(
                    _product!.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 간단 설명 (it_basic)
            _buildBasicDescription(),
            const SizedBox(height: 16),

            _buildImageCarousel(_getProductImages()),
            const SizedBox(height: 16),

            // 가격 정보
            _buildPriceSection(),

            // 제품 스펙
            _buildProductSpecs(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 상품정보 탭
  Widget _buildProductInfoTab() {
    return SingleChildScrollView(
      key: const PageStorageKey<String>('product_info_tab'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 상세페이지 HTML 미리보기 + 자세히 보기
          _buildDetailPreviewSection(),

          // 공통 정보 섹션 (배송, 처방 프로세스, 교환/환불)
          ProductTailInfoSection(
            showCertification: false,
            showWarning: false,
            showPrescriptionProcess: false,
            deliveryText: _product?.additionalInfo?['it_baesong_content']?.toString(),
            changeContentText:
                _product?.additionalInfo?['it_change_content']?.toString(),
          ),

          const SizedBox(height: 16),

          // 하단 여백
          const SizedBox(height: 56),

          // Footer
          // const AppFooter(),
        ],
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
      showCategoryScores: false,
      onLoadMore: () {
        _safeSetState(() {
          _visibleNormalReviewCount += 8;
        });
      },
      onReviewTap: (_) {},
    );
  }

  Widget _buildImageCarousel(List<String> images) {
    // 화면 크기에 따라 동적으로 조절
    final screenWidth = MediaQuery.of(context).size.width;
    // 높이: 화면 너비에 비례 (최소 200px, 최대 550px)
    final imageHeight = (screenWidth * 0.88).clamp(200.0, 420.0);
    // 너비: 화면 너비에서 패딩을 뺀 값 (최대 600px)
    final maxWidth = (screenWidth).clamp(200.0, 600.0);

    if (images.isEmpty) {
      final emptyContainer = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: imageHeight,
            margin: kIsWeb ? const EdgeInsets.symmetric(horizontal: 16) : null,
            color: Colors.grey[200],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_not_supported,
                  size: 60,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  'No Image',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
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
        borderRadius: BorderRadius.circular(12),
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

                return Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            size: 60,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '이미지 로드 실패',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              imageUrl.length > 50
                                  ? '${imageUrl.substring(0, 50)}...'
                                  : imageUrl,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 10,
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
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
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
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
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
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    images.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
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
        fontSize: 13,
        color: Colors.grey[700],
        height: 1.5,
      ),
    );
  }

  Widget _buildProductSpecs() {
    final specs = <Map<String, String>>[];

    if (_product!.additionalInfo != null) {
      final info = _product!.additionalInfo!;
      final weightRaw = info['it_weight'];
      final weightValue = weightRaw?.toString().trim();
      if (weightValue != null && weightValue.isNotEmpty) {
        specs.add({
          'label': '중량/용량',
          'value': weightValue,
        });
      }

      // 처방단위 (it_prescription)
      if (info['it_prescription'] != null &&
          info['it_prescription'].toString().isNotEmpty) {
        specs.add({
          'label': '처방단위',
          'value': info['it_prescription'].toString(),
        });
      }

      // 복용방법 (it_takeway)
      if (info['it_takeway'] != null &&
          info['it_takeway'].toString().isNotEmpty) {
        specs.add({
          'label': '복용방법',
          'value': info['it_takeway'].toString(),
        });
      }

      // 적립포인트 (동적 계산)
      final pointText = PointHelper.calculatePointText(
        pointType: info['it_point_type'],
        point: info['it_point'],
        usePoint: _usePointConfig ?? true,
        price: _product!.price,
      );

      if (pointText != null) {
        specs.add({
          'label': '적립포인트',
          'value': pointText,
        });
      }

      // 배송비결제
      specs.add({
        'label': '배송비',
        'value': '주문시 결제',
      });
    } else {
      // 기본값 (데이터가 없을 때)
      specs.add({
        'label': '배송비',
        'value': '주문시 결제',
      });
    }

    if (specs.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        children: specs.map((spec) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 78,
                  child: Text(
                    spec['label']!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    spec['value']!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPriceSection() {
    final discountRate = _product!.discountRate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 원가 (취소선)
        if (_product!.originalPrice != null &&
            _product!.originalPrice! > _product!.price)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              _product!.formattedOriginalPrice ?? '',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ),

        // 현재 가격
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _product!.formattedPrice,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (discountRate != null && discountRate > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${discountRate.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF4081), // 핑크색
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildShareButton(),
                _buildInlineReviewSummary(),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShareButton() {
    return Builder(
      builder: (anchorContext) {
        return IconButton(
          tooltip: '공유하기',
          onPressed: () async {
            try {
              final usedShareUi = await ProductShare.shareProduct(
                anchorContext: anchorContext,
                itId: _product!.id,
                productName: _product!.name,
              );
              if (!mounted) return;
              if (!usedShareUi) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '공유 창을 띄울 수 없어 링크를 클립보드에 복사했습니다. 붙여넣기로 전달해 주세요.',
                    ),
                  ),
                );
              }
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('공유를 실행할 수 없습니다: $e')),
              );
            }
          },
          icon: const Icon(Icons.share_outlined),
        );
      },
    );
  }

  Widget _buildInlineReviewSummary() {
    final average = (_reviewStats?['totalAverage'] as double?) ?? 0.0;
    final reviewCount = _reviews.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star, size: 14, color: Color(0xFFFFCC00)),
        const SizedBox(width: 4),
        Text(
          '${average.toStringAsFixed(1)} ($reviewCount)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  /// 홈 화면 AppBar와 동일하게 배경·블러 없이 투명 (뒤로가기만)
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
                icon: const Icon(
                  Icons.chevron_left,
                  color: Colors.black,
                  size: 28,
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
    if (itExplain == null || itExplain.isEmpty) {
      return '';
    }

    final srcPattern = RegExp(
      r'''src\s*=\s*(['"])(https?://[^'"]+)\1''',
      caseSensitive: false,
    );
    return itExplain.replaceAllMapped(srcPattern, (match) {
      final quote = match.group(1) ?? '"';
      final originalUrl = match.group(2) ?? '';
      final convertedUrl = ImageUrlHelper.convertToLocalUrl(originalUrl);
      return 'src=$quote$convertedUrl$quote';
    });
  }

  Widget _buildDetailHtml({
    required String html,
    required double imageWidth,
  }) {
    return Html(
      data: html,
      shrinkWrap: true,
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontFamily: _kGmarketSans,
        ),
        'img': Style(
          width: Width(imageWidth),
          display: Display.block,
          margin: Margins.symmetric(vertical: 8),
        ),
        'div': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontFamily: _kGmarketSans,
        ),
        'p': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          display: Display.block,
          fontFamily: _kGmarketSans,
        ),
        'span': Style(fontFamily: _kGmarketSans),
        'li': Style(fontFamily: _kGmarketSans),
        'h1': Style(fontFamily: _kGmarketSans),
        'h2': Style(fontFamily: _kGmarketSans),
        'h3': Style(fontFamily: _kGmarketSans),
        'h4': Style(fontFamily: _kGmarketSans),
        'a': Style(fontFamily: _kGmarketSans),
      },
    );
  }

  Widget _buildDetailPreviewSection() {
    final processedHtml = _getProcessedDetailHtml();
    if (processedHtml.isEmpty) return const SizedBox.shrink();
    final screenWidth = MediaQuery.of(context).size.width;
    final imageWidth = (screenWidth - 32).clamp(200.0, 600.0);
    const collapsedPreviewHeight = 320.0;
    final isExpanded = _isDetailExpanded == true;

    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (isExpanded) ...[
            _buildDetailHtml(
              html: processedHtml,
              imageWidth: imageWidth,
            ),
          ] else ...[
            ClipRect(
              child: SizedBox(
                height: collapsedPreviewHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _buildDetailHtml(
                          html: processedHtml,
                          imageWidth: imageWidth,
                        ),
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
                            height: 50,
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
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: OutlinedButton(
                onPressed: () {
                  _safeSetState(() {
                    _isDetailExpanded = true;
                  });
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFF4081), width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 26, vertical: 0),
                  foregroundColor: const Color(0xFFFF4081),
                ),
                child: const Text(
                  '+ 자세히 보기',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 좋아요 버튼
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color:
                      _isFavorite ? const Color(0xFFFF4081) : Colors.grey[600],
                ),
                onPressed: () => _toggleFavorite(),
              ),
            ),
            const SizedBox(width: 12),
            // 상품 종류에 따른 메인 액션 버튼
            Expanded(
              child: ElevatedButton(
                onPressed: _showOptionSelectionDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4081),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  '구매하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
      userPoint: _userPoint,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('장바구니에 추가 중...'),
            duration: Duration(seconds: 1),
          ),
        );

        final result = await CartService.addOptionsToCart(
          product: _product!,
          selectedOptions: _selectedOptions,
        );

        if (!mounted) return;

        if (result['success'] == true) {
          _safeSetState(() {
            _selectedOptions.clear();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '장바구니 추가에 실패했습니다.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              width: 568,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      onReserve: () async {},
      onBuyNow: () async {
        if (_product == null || _selectedOptions.isEmpty) return;

        final user = await AuthService.getUser();
        if (user == null || user.id.isEmpty) {
          if (!mounted) return;
          await showLoginRequiredDialog(
            context,
            message: '상품 구매는 로그인 후 이용할 수 있습니다.',
          );
          return;
        }

        Navigator.of(context).pop();

        final result = await CartService.addOptionsToCart(
          product: _product!,
          selectedOptions: _selectedOptions,
        );

        if (!mounted) return;
        if (result['success'] == true) {
          setState(() {
            _selectedOptions.clear();
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const cart_general.CartScreen(),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '구매 처리에 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
    final result = await CartService.addToCart(
      productId: _product!.id,
      quantity: quantity,
      price: _product!.price * quantity,
      ctKind: _product!.ctKind,
    );

    if (!mounted) return false;

    final success = result['success'] == true;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? '장바구니 추가에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return success;
  }

  Future<void> _goToGeneralPaymentScreen() async {
    final cart = await CartService.getCart();
    if (cart['success'] != true) return;

    final rawItems = (cart['items'] as List?) ?? const [];
    final List<CartItem> items = rawItems
        .whereType<Map>()
        .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => !e.isPrescription)
        .toList();
    if (!mounted || items.isEmpty) return;

    final shippingCost = (cart['shipping_cost'] as num?)?.toInt() ?? 0;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          cartItems: items,
          shippingCost: shippingCost,
          sourceTitle: '일반상품 결제',
        ),
      ),
    );
  }

  Future<void> _showGeneralQuantityBottomSheet() async {
    if (_product == null) return;

    int quantity = 1;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final sheetTheme = Theme.of(sheetContext).copyWith(
          textTheme: Theme.of(sheetContext).textTheme.apply(
                fontFamily: _kGmarketSans,
              ),
          primaryTextTheme: Theme.of(sheetContext).primaryTextTheme.apply(
                fontFamily: _kGmarketSans,
              ),
        );
        final screenWidth = MediaQuery.of(sheetContext).size.width;
        final constrainedWidth = math.min(screenWidth - 12, 600.0);
        return Theme(
          data: sheetTheme,
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: _kGmarketSans),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final totalPrice = _product!.price * quantity;
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constrainedWidth),
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                      child: Container(
                        color: Colors.white,
                        child: SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 20, 20, 10),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      _product!.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          '수량',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        _buildGeneralQuantityControl(
                                          quantity: quantity,
                                          onDecrease: quantity > 1
                                              ? () => setModalState(
                                                  () => quantity--)
                                              : null,
                                          onIncrease: () =>
                                              setModalState(() => quantity++),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.12),
                                      blurRadius: 6,
                                      offset: const Offset(0, -2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 16, 20, 16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            '총 결제금액',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            '${PriceFormatter.format(totalPrice)}원',
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFFFF4081),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            '보유 포인트 ${PriceFormatter.format(_userPoint ?? 0)}P',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      const Divider(height: 1),
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () async {
                                                Navigator.of(context).pop();
                                                final success =
                                                    await _addGeneralProductToCart(
                                                  quantity: quantity,
                                                );
                                                if (!mounted || !success)
                                                  return;
                                                Navigator.push(
                                                  this.context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const cart_general.CartScreen(),
                                                  ),
                                                );
                                              },
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.black87,
                                                side: BorderSide(
                                                  color: Colors.grey[400]!,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 14,
                                                ),
                                              ),
                                              child: const Text(
                                                '장바구니',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () async {
                                                Navigator.of(context).pop();
                                                final success =
                                                    await _addGeneralProductToCart(
                                                  quantity: quantity,
                                                );
                                                if (!mounted || !success)
                                                  return;
                                                await _goToGeneralPaymentScreen();
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFFFF4081),
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 14,
                                                ),
                                              ),
                                              child: const Text(
                                                '구매하기',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildGeneralQuantityControl({
    required int quantity,
    required VoidCallback? onDecrease,
    required VoidCallback onIncrease,
  }) {
    return Container(
      width: 59.5,
      height: 20,
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 2.14,
            offset: Offset(0, 0.54),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Row(
              children: [
                _buildGeneralQtyButton(
                  icon: Icons.remove,
                  onTap: onDecrease,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '$quantity',
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                _buildGeneralQtyButton(
                  icon: Icons.add,
                  onTap: onIncrease,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralQtyButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        decoration: const ShapeDecoration(
          color: Colors.white,
          shape: OvalBorder(),
          shadows: [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 2.14,
              offset: Offset(0, 0.54),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 13,
          color: onTap == null ? Colors.grey[300] : const Color(0xFFFF5A8D),
        ),
      ),
    );
  }
}

/// SliverPersistentHeaderDelegate for TabBar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}
