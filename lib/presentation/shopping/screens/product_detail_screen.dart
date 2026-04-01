import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_html/flutter_html.dart';
import '../../../data/models/product/product_model.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../../data/models/review/review_model.dart';
import '../../../data/services/review_service.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/html_parser.dart' as custom_html_parser;
import '../../../core/utils/point_helper.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/utils/node_value_parser.dart';
import '../../../data/services/point_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/wish_service.dart';
import '../../../data/services/cart_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../data/models/product/product_option_model.dart';
import '../../../data/repositories/product/product_option_repository.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_footer.dart';
import '../widgets/product_tail_info_section.dart';
import '../../user/healthprofile/screens/health_profile_form_screen.dart';
import 'prescription_booking/prescription_profile_screen.dart';
import 'product_reviews_screen.dart';
import 'webview_screen.dart';
import '../../review/screens/review_detail_screen.dart';
import '../../customer_service/screens/contact_form_screen.dart';
import '../../common/widgets/login_required_dialog.dart';

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
  String? _errorMessage;
  bool _isFavorite = false;
  int _currentImageIndex = 0;
  late TabController _tabController;
  PageController? _pageController;
  
  // 리뷰 관련 상태
  List<ReviewModel> _reviews = [];
  List<ReviewModel> _supporterReviews = [];
  List<ReviewModel> _generalReviews = [];
  Map<String, dynamic>? _reviewStats;
  bool _isLoadingReviews = false;
  int? _userPoint; // 현재 사용자 보유 포인트
  bool? _usePointConfig; // cf_use_point 설정값
  
  // 옵션 관련 상태
  List<ProductOption> _productOptions = [];
  Map<ProductOption, int> _selectedOptions = {}; // 옵션과 수량을 함께 관리

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // 상품정보, 리뷰, 문의
    _tabController.addListener(() {
      // 탭 변경 시 UI 업데이트
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadProductDetail().then((_) {
      // 제품 정보 로드 후 리뷰 로드 (it_org_id 확인을 위해)
      _loadReviews();
    });
    _loadUserPoint();
    _loadConfig();
    _loadProductOptions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _loadProductDetail() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final product = await ProductRepository.getProductDetail(widget.productId);
      setState(() {
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
          
          // 상품 종류 로그 출력
          print('✅ [상품 상세 로드 완료]');
          print('  - productId: ${product.id}');
          print('  - productKind: ${product.productKind}');
          print('  - ctKind (getter): ${product.ctKind}');
        }
      });
      
      // 찜하기 상태 확인
      await _checkFavoriteStatus();
    } catch (e) {
      setState(() {
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
      
      setState(() {
        _isFavorite = isFavorite;
      });
      
      print('📌 [찜하기] 상태 확인 완료 - 상품 ID: ${widget.productId}, 찜 상태: $_isFavorite');
    } catch (e) {
      print('⚠️ [찜하기] 상태 확인 실패: $e');
      // 에러 발생 시 기본값(false) 유지
    }
  }

  Future<void> _loadReviews() async {
    if (widget.productId.isEmpty) return;
    
    setState(() {
      _isLoadingReviews = true;
    });

    try {
      // it_org_id가 있으면 원본 제품 ID 사용, 없으면 현재 제품 ID 사용
      String reviewProductId = widget.productId;
      if (_product != null && _product!.additionalInfo != null) {
        final itOrgId =
            NodeValueParser.asString(_product!.additionalInfo!['it_org_id']) ??
            NodeValueParser.asString(_product!.additionalInfo!['itOrgId']);
        if (itOrgId != null && itOrgId.isNotEmpty) {
          reviewProductId = itOrgId;
        }
      }
      
      // 전체 리뷰 가져오기 (rvkind만 사용, ct_kind는 사용하지 않음)
      final result = await ReviewService.getProductReviews(
        itId: reviewProductId,
        rvkind: null, // 전체 리뷰
        page: 0,
        size: 50,
      );
      
      if (result['success'] == true) {
        final allReviews = result['reviews'] as List<ReviewModel>;
        
        // 서포터 리뷰와 일반 리뷰 분류
        final supporter = allReviews.where((r) => r.isSupporterReview).toList();
        final general = allReviews.where((r) => r.isGeneralReview).toList();
        
        // 리뷰 통계 직접 계산
        double totalAverage = 0.0;
        double supporterAverage = 0.0;
        int totalSatisfied = 0;
        int supporterSatisfied = 0;
        double score1Avg = 0.0; // 서포터 리뷰 카테고리별 평균
        double score2Avg = 0.0;
        double score3Avg = 0.0;
        double score4Avg = 0.0;
        double totalScore1Avg = 0.0; // 전체 리뷰 카테고리별 평균
        double totalScore2Avg = 0.0;
        double totalScore3Avg = 0.0;
        double totalScore4Avg = 0.0;
        
        final reviewsWithScore = allReviews.where((r) => r.averageScore != null).toList();
        if (reviewsWithScore.isNotEmpty) {
          totalAverage = reviewsWithScore
              .map((r) => r.averageScore!)
              .reduce((a, b) => a + b) / reviewsWithScore.length;
          totalSatisfied = allReviews.where((r) => r.isSatisfied).length;
          
          // 전체 리뷰 카테고리별 평균 점수
          if (allReviews.isNotEmpty) {
            totalScore1Avg = allReviews.map((r) => r.score1.toDouble()).reduce((a, b) => a + b) / allReviews.length;
            totalScore2Avg = allReviews.map((r) => r.score2.toDouble()).reduce((a, b) => a + b) / allReviews.length;
            totalScore3Avg = allReviews.map((r) => r.score3.toDouble()).reduce((a, b) => a + b) / allReviews.length;
            totalScore4Avg = allReviews.map((r) => r.score4.toDouble()).reduce((a, b) => a + b) / allReviews.length;
          }
        }
        
        final supporterWithScore = supporter.where((r) => r.averageScore != null).toList();
        if (supporterWithScore.isNotEmpty) {
          supporterAverage = supporterWithScore
              .map((r) => r.averageScore!)
              .reduce((a, b) => a + b) / supporterWithScore.length;
          supporterSatisfied = supporter.where((r) => r.isSatisfied).length;
          
          // 카테고리별 평균 점수 (서포터 리뷰만)
          if (supporter.isNotEmpty) {
            score1Avg = supporter.map((r) => r.score1.toDouble()).reduce((a, b) => a + b) / supporter.length;
            score2Avg = supporter.map((r) => r.score2.toDouble()).reduce((a, b) => a + b) / supporter.length;
            score3Avg = supporter.map((r) => r.score3.toDouble()).reduce((a, b) => a + b) / supporter.length;
            score4Avg = supporter.map((r) => r.score4.toDouble()).reduce((a, b) => a + b) / supporter.length;
          }
        }
        
        setState(() {
          _reviews = allReviews;
          _supporterReviews = supporter;
          _generalReviews = general;
          _reviewStats = {
            'totalCount': allReviews.length,
            'totalAverage': totalAverage,
            'supporterAverage': supporterAverage,
            'totalSatisfied': totalSatisfied,
            'supporterSatisfied': supporterSatisfied,
            'score1Avg': score1Avg, // 서포터 리뷰 카테고리별 평균
            'score2Avg': score2Avg,
            'score3Avg': score3Avg,
            'score4Avg': score4Avg,
            'totalScore1Avg': totalScore1Avg, // 전체 리뷰 카테고리별 평균
            'totalScore2Avg': totalScore2Avg,
            'totalScore3Avg': totalScore3Avg,
            'totalScore4Avg': totalScore4Avg,
          };
          _isLoadingReviews = false;
        });
      } else {
        setState(() {
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      setState(() {
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
        setState(() {
          _userPoint = point;
        });
      }
    } catch (e) {
    }
  }

  /// 설정 조회 (cf_use_point)
  Future<void> _loadConfig() async {
    try {
      final response = await ApiClient.get(ApiEndpoints.config);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final config = data['data'];
          setState(() {
            _usePointConfig = config['cf_use_point'] == 1 || config['cf_use_point'] == true;
          });
        }
      }
    } catch (e) {
      // 기본값 설정
      setState(() {
        _usePointConfig = true;
      });
    }
  }

  /// 제품 옵션 조회
  Future<void> _loadProductOptions() async {
    if (widget.productId.isEmpty) return;
    
    try {
      final options = await ProductOptionRepository.getProductOptions(widget.productId);
      print('📦 [옵션] 로드된 옵션 개수: ${options.length}');
      for (var option in options) {
        print('  - 옵션 ID: ${option.id}');
        print('    상위 옵션: ${option.step}');
        print('    하위 옵션: ${option.subOption}');
        print('    표시명: ${option.displayText}');
        print('    가격: ${option.price}원');
      }
      setState(() {
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
      setState(() {
        _isFavorite = !_isFavorite;
      });

      // API 호출
      if (wasFavorite) {
        // 찜하기 해제
        await WishService.removeFromWish(widget.productId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('찜하기 해제 완료'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              width: 568, // 600px - 32px (양쪽 16px 여백)
              duration: Duration(milliseconds: 500),
            ),
          );
        }
      } else {
        // 찜하기 추가
        await WishService.addToWish(widget.productId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('찜하기 완료'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              width: 568, // 600px - 32px (양쪽 16px 여백)
              duration: Duration(milliseconds: 500),
            ),
          );
        }
      }
    } catch (e) {
      // 실패 시 원래 상태로 되돌리기
      setState(() {
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
        final normalized = ImageUrlHelper.normalizeThumbnailUrl(raw, _product!.id);
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
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(40), // AppBar 높이 축소
        child: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pushReplacementNamed('/home');
              }
            },
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _hasError
                ? _buildErrorState()
                : _product == null
                    ? _buildErrorState()
                    : _buildProductDetail(),
        bottomNavigationBar: _product == null
            ? null
            : _buildBottomActionBar(),
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
    final images = _getProductImages();
    final allReviewCount = _reviews.length;
    
    return NestedScrollView(
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return [
          // 썸네일 (이미지 캐러셀)
          SliverToBoxAdapter(
            child: _buildImageCarousel(images),
          ),
          
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
                tabs: [
                  const Tab(
                    child: Text(
                      '상품정보',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  Tab(
                    child: Text(
                      '리뷰 $allReviewCount',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const Tab(
                    child: Text(
                      '문의',
                      style: TextStyle(fontSize: 14),
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
          // 상품정보 탭
          _buildProductInfoTab(),
          // 리뷰 탭
          _buildReviewTab(),
          // 문의 탭
          _buildInquiryTab(),
        ],
      ),
    );
  }

  /// 제품 정보 섹션 (탭 위에 고정)
  Widget _buildProductInfoSection() {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제품 태그
            if (_product!.categoryName != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _product!.categoryName!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (_product!.categoryName != null) const SizedBox(height: 12),
            
            // 제품명
            Text(
              _product!.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            
            // 간단 설명 (it_basic)
            _buildBasicDescription(),
            const SizedBox(height: 16),
            
            // 가격 정보
            _buildPriceSection(),
            
            // 가격 아래 구분선
            const Divider(
              height: 32,
              thickness: 1,
              color: Colors.grey,
            ),
            
            // 제품 스펙
            _buildProductSpecs(),
            const SizedBox(height: 16),
            
            // 현재 나의 보유포인트
            _buildUserPointSection(),
            
            // 선택된 옵션 표시
            if (_selectedOptions.isNotEmpty)
              _buildSelectedOptionSection(),
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
          // 상세페이지 HTML 콘텐츠
          _buildDetailContent(),
          
          const Divider(height: 1, thickness: 1),
          
          // 공통 정보 섹션 (배송, 처방 프로세스, 교환/환불)
          const ProductTailInfoSection(),
          
          // 하단 여백
          const SizedBox(height: 100),
          
          // Footer
          const AppFooter(),
        ],
      ),
    );
  }

  /// 리뷰 탭
  Widget _buildReviewTab() {
    // 서포터 리뷰: 포토가 있는 것 먼저 정렬
    final sortedSupporterReviews = List<ReviewModel>.from(_supporterReviews)
      ..sort((a, b) {
        final aHasPhoto = a.images.isNotEmpty;
        final bHasPhoto = b.images.isNotEmpty;
        if (aHasPhoto && !bHasPhoto) return -1;
        if (!aHasPhoto && bHasPhoto) return 1;
        return 0;
      });
    
    return SingleChildScrollView(
      key: const PageStorageKey<String>('review_tab'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 탭바와 리뷰 사이 간격
          const SizedBox(height: 16),
          
          // 전체 리뷰 통계 (서포터/일반 구분 없이 전체 합산)
          if (_reviewStats != null && _reviews.isNotEmpty)
            _buildReviewStats(
              title: '리뷰 평가',
              average: _reviewStats!['totalAverage'] as double,
              satisfied: _reviewStats!['totalSatisfied'] as int,
              totalCount: _reviewStats!['totalCount'] as int,
              score1Avg: _reviewStats!['totalScore1Avg'] as double,
              score2Avg: _reviewStats!['totalScore2Avg'] as double,
              score3Avg: _reviewStats!['totalScore3Avg'] as double,
              score4Avg: _reviewStats!['totalScore4Avg'] as double,
            ),
          
          // 탭바와 리뷰 사이 간격
          const SizedBox(height: 30),

          // 리뷰 목록
          if (_isLoadingReviews)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (sortedSupporterReviews.isEmpty && _generalReviews.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Text(
                  '리뷰가 없습니다',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else ...[
            // 서포터 리뷰 목록 (최대 5개)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  ...sortedSupporterReviews.take(5).map((review) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildPhotoReviewCard(review),
                  )),
                ],
              ),
            ),
            
            // 더보기 버튼
            if (sortedSupporterReviews.length > 5 || _reviews.length > 5)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductReviewsScreen(
                            productId: widget.productId,
                            productName: _product?.name ?? '',
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFFF4081)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '리뷰 더보기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF4081),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${_reviews.length}개)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          
          const SizedBox(height: 100),
          const AppFooter(),
        ],
      ),
    );
  }

  /// 문의 탭
  Widget _buildInquiryTab() {
    return SingleChildScrollView(
      key: const PageStorageKey<String>('inquiry_tab'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 배송/결제/교환/반품 안내 링크
          InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => DraggableScrollableSheet(
                  initialChildSize: 0.9,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  builder: (context, scrollController) => Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: scrollController,
                            child: const Padding(
                              padding: EdgeInsets.all(16),
                              child: ProductTailInfoSection(initialExpanded: true),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '배송 / 결제 / 교환 / 반품 안내',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
          
          // 문의 안내 섹션
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '지금 보고 있는 상품이 궁금하신가요?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                
                // 예시 질문
                _buildExampleQuestion(
                  '상품 재입고 언제되는지 궁금해요',
                ),
                const SizedBox(height: 32),
                
                // 상품 문의하기 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ContactFormScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '상품 문의하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 100),
          const AppFooter(),
        ],
      ),
    );
  }

  /// 예시 질문 위젯
  Widget _buildExampleQuestion(String question) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '예시',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              question,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(List<String> images) {

    // 화면 크기에 따라 동적으로 조절
    final screenWidth = MediaQuery.of(context).size.width;
    // 높이: 화면 너비에 비례 (최소 200px, 최대 550px)
    final imageHeight = (screenWidth * 1.0).clamp(200.0, 600.0);
    // 너비: 화면 너비에서 패딩을 뺀 값 (최대 600px)
    final maxWidth = (screenWidth).clamp(200.0, 600.0);


    if (images.isEmpty) {
      final emptyContainer = Container(
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
      );
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
    final stackWidget = Stack(
      children: [
          PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() {
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
    );

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
        fontSize: 14,
        color: Colors.grey[700],
        height: 1.5,
      ),
    );
  }

  Widget _buildProductSpecs() {
    final specs = <Map<String, String>>[];
    
    if (_product!.additionalInfo != null) {
      
      final info = _product!.additionalInfo!;
      
      // 처방단위 (it_prescription)
      if (info['it_prescription'] != null && info['it_prescription'].toString().isNotEmpty) {
        specs.add({
          'label': '처방단위',
          'value': info['it_prescription'].toString(),
        });
      }
      
      // 복용방법 (it_takeway)
      if (info['it_takeway'] != null && info['it_takeway'].toString().isNotEmpty) {
        specs.add({
          'label': '복용방법',
          'value': info['it_takeway'].toString(),
        });
      }
      
      // 패키지구성 (it_package)
      if (info['it_package'] != null && info['it_package'].toString().isNotEmpty) {
        specs.add({
          'label': '패키지구성',
          'value': info['it_package'].toString(),
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
        'label': '배송비결제',
        'value': '주문시 결제',
      });
    } else {
      // 기본값 (데이터가 없을 때)
      specs.add({
        'label': '배송비결제',
        'value': '주문시 결제',
      });
    }

    if (specs.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: specs.map((spec) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    spec['label']!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    spec['value']!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.5,
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
      ],
    );
  }

  /// 현재 나의 보유포인트 섹션 (별도 섹션)
  Widget _buildUserPointSection() {
    if (_userPoint == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Text(
            '현재 나의 보유포인트',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '${PointHelper.formatPoint(_userPoint!)}점',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF4081),
            ),
          ),
        ],
      ),
    );
  }

  /// 선택된 옵션 표시 섹션
  Widget _buildSelectedOptionSection() {
    if (_selectedOptions.isEmpty || _product == null) return const SizedBox.shrink();
    
    // 총 가격 계산
    final basePrice = _product!.price;
    int totalOptionPrice = 0;
    int totalQuantity = 0;
    _selectedOptions.forEach((option, quantity) {
      totalOptionPrice += option.price * quantity;
      totalQuantity += quantity;
    });
    final totalPrice = (basePrice * totalQuantity) + totalOptionPrice;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4081).withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFF4081).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '선택된 옵션 (${_selectedOptions.length}개)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedOptions.clear();
                  });
                },
                child: const Text(
                  '전체 삭제',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._selectedOptions.entries.map((entry) {
            final option = entry.key;
            final quantity = entry.value;
            final itemPrice = basePrice + option.price;
            final itemTotalPrice = itemPrice * quantity;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.displayText,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${itemPrice.toString().replaceAllMapped(
                                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                (Match m) => '${m[1]},',
                              )}원',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 수량 조절
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: quantity > 1
                                ? () {
                                    setState(() {
                                      _selectedOptions[option] = quantity - 1;
                                    });
                                  }
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '$quantity',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _selectedOptions[option] = quantity + 1;
                              });
                            },
                          ),
                        ],
                      ),
                      // 삭제 버튼
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: Colors.grey[600],
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            _selectedOptions.remove(option);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${itemTotalPrice.toString().replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (Match m) => '${m[1]},',
                        )}원',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF4081),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
          const Divider(height: 24),
          // 총 가격 표시
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '총 결제금액',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${totalPrice.toString().replaceAllMapped(
                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                  (Match m) => '${m[1]},',
                )}원',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF4081),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  /// 포토형 리뷰 카드
  Widget _buildPhotoReviewCard(ReviewModel review) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewDetailScreen(review: review),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지
            Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
              ),
              child: review.images.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10),
                      ),
                      child: Image.network(
                        ImageUrlHelper.getReviewImageUrl(review.images.first),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              Icons.rate_review,
                              size: 32,
                              color: Colors.grey[400],
                            ),
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Icon(
                        Icons.rate_review,
                        size: 32,
                        color: Colors.grey[400],
                      ),
                    ),
            ),
            
            // 내용
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 작성자 및 별점
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          review.isName ?? '익명',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: List.generate(5, (index) {
                          final rating = review.averageScore ?? 0;
                          return Icon(
                            index < rating.round()
                                ? Icons.star
                                : Icons.star_border,
                            size: 12,
                            color: Colors.amber,
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 리뷰 내용
                  if (review.isPositiveReviewText != null && review.isPositiveReviewText!.isNotEmpty)
                    Text(
                      review.isPositiveReviewText!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  // 날짜 및 도움수
                  Row(
                    children: [
                      if (review.isTime != null)
                        Text(
                          '${review.isTime!.year}.${review.isTime!.month.toString().padLeft(2, '0')}.${review.isTime!.day.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                      const SizedBox(width: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.thumb_up,
                            size: 11,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${review.isGood ?? 0}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 리뷰 평가 통계 (공통 메서드)
  Widget _buildReviewStats({
    required String title,
    required double average,
    required int satisfied,
    required int totalCount,
    required double score1Avg,
    required double score2Avg,
    required double score3Avg,
    required double score4Avg,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 별점 아이콘 (1개만)
              Builder(
                builder: (context) {
                  final filledStars = average.floor();
                  final hasHalfStar = average - filledStars >= 0.5;
                  if (filledStars > 0) {
                    return const Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 28,
                    );
                  } else if (hasHalfStar) {
                    return const Icon(
                      Icons.star_half,
                      color: Colors.amber,
                      size: 28,
                    );
                  } else {
                    return const Icon(
                      Icons.star_border,
                      color: Colors.amber,
                      size: 28,
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              Text(
                average.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 만족 건 (가운데 정렬)
          Center(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
                children: [
                  const TextSpan(text: '만족 '),
                  TextSpan(
                    text: '${satisfied}건',
                    style: TextStyle(
                      color: const Color(0xFFFF4081),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(text: ' / $totalCount'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildReviewRatingBar('효과', (score1Avg * 20).round()),
          const SizedBox(height: 8),
          _buildReviewRatingBar('가성비', (score2Avg * 20).round()),
          const SizedBox(height: 8),
          _buildReviewRatingBar('맛/향', (score3Avg * 20).round()),
          const SizedBox(height: 8),
          _buildReviewRatingBar('편리함', (score4Avg * 20).round()),
        ],
      ),
    );
  }

  Widget _buildReviewRatingBar(String label, int percentage) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percentage / 100,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4081),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$percentage%',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewItem(ReviewModel review) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 사용자 정보 및 평점
          Row(
            children: [
              Expanded(
                child: Text(
                  review.isName ?? '익명',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              // 별점 표시
              Row(
                children: List.generate(5, (index) {
                  final rating = review.averageScore ?? 0;
                  return Icon(
                    index < rating.round()
                        ? Icons.star
                        : Icons.star_border,
                    size: 16,
                    color: Colors.amber,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 리뷰 제목 (좋았던 점)
          if (review.isPositiveReviewText != null && review.isPositiveReviewText!.isNotEmpty)
            Text(
              review.isPositiveReviewText!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          if (review.isPositiveReviewText != null && review.isPositiveReviewText!.isNotEmpty) const SizedBox(height: 8),
          // 아쉬운 점
          if (review.isNegativeReviewText != null && review.isNegativeReviewText!.isNotEmpty)
          Text(
              review.isNegativeReviewText!,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // 날짜 및 도움수
          Row(
            children: [
              if (review.isTime != null)
              Text(
                  '${review.isTime!.year}.${review.isTime!.month.toString().padLeft(2, '0')}.${review.isTime!.day.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  Icon(
                    Icons.thumb_up,
                    size: 14,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${review.isGood ?? 0}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 상세페이지 HTML 콘텐츠 표시 (리뷰 아래)
  Widget _buildDetailContent() {
    if (_product == null) return const SizedBox.shrink();
    
    // it_explain에서 HTML 콘텐츠 가져오기
    final itExplain = _product!.additionalInfo?['it_explain']?.toString() ?? 
                      _product!.description;
    if (itExplain == null || itExplain.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // HTML 이미지 URL을 현재 실행 환경에 맞게 변환
    String processedHtml = itExplain;
    final srcPattern = RegExp(r'''src\s*=\s*(['"])(https?://[^'"]+)\1''', caseSensitive: false);
    processedHtml = processedHtml.replaceAllMapped(srcPattern, (match) {
      final quote = match.group(1) ?? '"';
      final originalUrl = match.group(2) ?? '';
      final convertedUrl = ImageUrlHelper.convertToLocalUrl(originalUrl);
      return 'src=$quote$convertedUrl$quote';
    });
    
    // 이미지 너비 설정 (화면 너비에 맞춰 동적으로 조절)
    final screenWidth = MediaQuery.of(context).size.width;
    // 패딩(좌우 16px씩 = 32px)을 빼고, 최대값 제한
    final imageWidth = (screenWidth - 32).clamp(200.0, 600.0);
    
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 24),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // HTML 콘텐츠 렌더링 (콘텐츠 길이에 맞게 자동 조정)
          Html(
            data: processedHtml,
            shrinkWrap: true, // 콘텐츠에 맞게 크기 조정
            style: {
              'body': Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
              ),
              'img': Style(
                width: Width(imageWidth),
                display: Display.block,
                margin: Margins.symmetric(vertical: 8),
              ),
              'div': Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
              ),
              'p': Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                display: Display.block,
              ),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    final isGeneralProduct = _product?.ctKind == 'general';
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
                  color: _isFavorite 
                      ? const Color(0xFFFF4081)
                      : Colors.grey[600],
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
                  isGeneralProduct ? '구매하기' : '처방 예약하기',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
    
    // 옵션이 없는 상품 처리
    if (_productOptions.isEmpty) {
      if (_product!.ctKind == 'general') {
        _showGeneralQuantityBottomSheet();
      } else {
        _proceedWithReservation();
      }
      return;
    }
    
    // 옵션 선택 바텀 시트 표시
    final optionSubject = _product!.additionalInfo?['it_option_subject']?.toString() ?? '옵션 선택';
    print('  - 옵션 주제(it_option_subject): $optionSubject');
    
    // it_option_subject를 콤마로 분리하여 여러 주제로 나눔
    final subjects = optionSubject.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    print('  - 분리된 주제: $subjects');
    
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(50),
          topRight: Radius.circular(50),
        ),
      ),
      builder: (context) => _OptionSelectionBottomSheet(
        title: optionSubject,
        subjects: subjects.isEmpty ? ['옵션 선택'] : subjects,
        options: _productOptions,
        selectedOptions: _selectedOptions,
        basePrice: _product!.price,
        productKind: _product!.productKind ?? _product!.additionalInfo?['it_kind']?.toString(),
        onOptionsChanged: (newOptions) {
          print('📝 [부모] 옵션 변경 콜백 호출 - 새로운 옵션 개수: ${newOptions.length}');
          newOptions.forEach((option, quantity) {
            print('  - ${option.displayText}: $quantity개');
          });
          setState(() {
            _selectedOptions = newOptions;
            print('📝 [부모] 상태 업데이트 완료 - _selectedOptions 개수: ${_selectedOptions.length}');
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
          
          // 로딩 표시
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('장바구니에 추가 중...'),
              duration: Duration(seconds: 1),
            ),
          );
          
          // 실제 장바구니 추가
          final result = await CartService.addOptionsToCart(
            product: _product!,
            selectedOptions: _selectedOptions,
          );
          
          if (!mounted) return;
          
          if (result['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('장바구니에 추가되었습니다.'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                width: 568,
                duration: Duration(seconds: 2),
              ),
            );
            // 옵션 초기화
            setState(() {
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
        onReserve: () {
          Navigator.of(context).pop();
          _navigateToQuestionnaire();
        },
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
            _navigateToCheckoutPage();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? '구매 처리에 실패했습니다.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '장바구니에 추가되었습니다.'
              : (result['message'] ?? '장바구니 추가에 실패했습니다.'),
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
    return success;
  }

  void _navigateToCheckoutPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WebViewScreen(
          url: 'https://bomiora.kr/shop/orderform.php?mobile_app=1&hide_header=1&hide_footer=1',
          title: '결제 페이지',
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final totalPrice = _product!.price * quantity;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '수량',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: quantity > 1
                                  ? () => setModalState(() => quantity--)
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text(
                              '$quantity',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            IconButton(
                              onPressed: () => setModalState(() => quantity++),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '총 ${PriceFormatter.format(totalPrice)}원',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF4081),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              final success = await _addGeneralProductToCart(
                                quantity: quantity,
                              );
                              if (!mounted || !success) return;
                              Navigator.pushNamed(
                                this.context,
                                '/cart',
                                arguments: const {'initialTabIndex': 1},
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              side: BorderSide(color: Colors.grey[400]!),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              '장바구니',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              final success = await _addGeneralProductToCart(
                                quantity: quantity,
                              );
                              if (!mounted || !success) return;
                              _navigateToCheckoutPage();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF4081),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              '구매하기',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 처방 예약 페이지로 이동
  void _navigateToQuestionnaire() async {
    if (_product == null) return;

    final user = await AuthService.getUser();
    if (user == null || user.id.isEmpty) {
      if (!mounted) return;
      await showLoginRequiredDialog(
        context,
        message: '로그인 후 이용 가능합니다.',
      );
      return;
    }
    
    // 선택된 옵션 정보를 리스트로 변환 (여러 옵션 지원)
    if (_selectedOptions.isEmpty) {
      // 옵션이 없으면 빈 리스트 반환
      final selectedOptionsData = <Map<String, dynamic>>[];
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrescriptionProfileScreen(
            productId: _product!.id,
            productName: _product!.name,
            selectedOptions: selectedOptionsData,
          ),
        ),
      );
      if (result == true) {
        // 예약 완료 후 처리 (필요시)
      }
      return;
    }
    
    // 모든 옵션을 리스트로 변환
    final selectedOptionsData = _selectedOptions.entries.map((entry) {
      final option = entry.key;
      final quantity = entry.value;
      return {
        'id': option.id,
        'name': option.displayText,
        'price': option.price,
        'quantity': quantity,
        'totalPrice': (_product!.price + option.price) * quantity,
      };
    }).toList();
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrescriptionProfileScreen(
          productId: _product!.id,
          productName: _product!.name,
          selectedOptions: selectedOptionsData,
        ),
      ),
    );
    
    if (result == true) {
      // 예약 완료 후 처리 (필요시)
    }
  }

  /// 옵션 선택 후 예약 진행
  void _proceedWithReservation() {
    if (_selectedOptions.isEmpty || _product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('옵션을 선택해주세요.'),
          behavior: SnackBarBehavior.floating,
          width: 568, // 600px - 32px (양쪽 16px 여백)
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // 총 가격 계산
    final basePrice = _product!.price;
    int totalOptionPrice = 0;
    int totalQuantity = 0;
    _selectedOptions.forEach((option, quantity) {
      totalOptionPrice += option.price * quantity;
      totalQuantity += quantity;
    });
    final totalPrice = (basePrice * totalQuantity) + totalOptionPrice;
    
    // 선택된 옵션 정보 표시
    String message = '처방 예약 기능은 준비 중입니다.\n\n';
    message += '선택된 옵션:\n';
    _selectedOptions.forEach((option, quantity) {
      final itemPrice = (basePrice + option.price) * quantity;
      message += '  - ${option.displayText} x $quantity: ${itemPrice.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      )}원\n';
    });
    message += '\n총 결제금액: ${totalPrice.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}원';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        width: 568, // 600px - 32px (양쪽 16px 여백)
        duration: const Duration(seconds: 5),
      ),
    );
  }
}

/// 옵션 선택 바텀 시트 위젯
class _OptionSelectionBottomSheet extends StatefulWidget {
  final String title;
  final List<String> subjects; // 옵션 주제 리스트 (예: ["단계", "개월수"])
  final List<ProductOption> options;
  final Map<ProductOption, int> selectedOptions; // 이미 선택된 옵션들
  final int basePrice; // 기본 상품 가격
  final String? productKind; // 상품 종류 (general or prescription)
  final Function(Map<ProductOption, int>) onOptionsChanged; // 옵션 변경 콜백
  final VoidCallback onAddToCart; // 장바구니 추가 콜백
  final VoidCallback onReserve; // 처방예약하기 콜백
  final VoidCallback onBuyNow; // 일반상품 바로구매 콜백
  
  const _OptionSelectionBottomSheet({
    required this.title,
    required this.subjects,
    required this.options,
    required this.selectedOptions,
    required this.basePrice,
    this.productKind,
    required this.onOptionsChanged,
    required this.onAddToCart,
    required this.onReserve,
    required this.onBuyNow,
  });
  
  @override
  State<_OptionSelectionBottomSheet> createState() => _OptionSelectionBottomSheetState();
}

class _OptionSelectionBottomSheetState extends State<_OptionSelectionBottomSheet> {
  // subjects를 기반으로 그룹화
  // 첫 번째 subject: 단계별 그룹화 (step으로)
  // 두 번째 subject: 개월수별 그룹화 (months로)
  Map<String, List<ProductOption>> _groupedOptionsByStep = {}; // 단계별 그룹
  Map<int, List<ProductOption>> _groupedOptionsByMonths = {}; // 개월수별 그룹 (선택된 단계 내에서)
  List<String> _stepGroups = []; // 단계 리스트
  List<int> _monthsGroups = []; // 개월수 리스트 (필터링된)
  
  String? _selectedStep; // 선택된 단계
  int? _selectedMonths; // 선택된 개월수
  String? _expandedSubject; // 현재 확장된 옵션 (단계 또는 개월수)
  
  // 바텀시트 내부에서 관리하는 옵션 상태 (부모와 동기화)
  late Map<ProductOption, int> _selectedOptions;
  
  @override
  void initState() {
    super.initState();
    // 부모의 selectedOptions로 초기화
    _selectedOptions = Map<ProductOption, int>.from(widget.selectedOptions);
    _initializeGroups();
  }
  
  @override
  void didUpdateWidget(_OptionSelectionBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 부모의 selectedOptions가 변경되었을 때 동기화
    // 길이 비교 또는 참조 비교로 변경 감지
    if (oldWidget.selectedOptions.length != widget.selectedOptions.length ||
        oldWidget.selectedOptions != widget.selectedOptions) {
      print('🔄 [바텀시트] 부모 옵션 변경 감지 - 이전: ${oldWidget.selectedOptions.length}개, 현재: ${widget.selectedOptions.length}개');
      setState(() {
        // 부모의 새로운 옵션으로 완전히 교체
        _selectedOptions = Map<ProductOption, int>.from(widget.selectedOptions);
        print('🔄 [바텀시트] 내부 상태 업데이트 완료 - 현재: ${_selectedOptions.length}개');
      });
    }
  }
  
  /// 옵션 추가
  void _addOption(ProductOption option) {
    print('➕ [옵션 추가] 옵션: ${option.displayText}, ID: ${option.id}');
    
    // 바텀시트 내부 상태 먼저 업데이트 (UI 즉시 반영)
    setState(() {
      // 기존 옵션과 비교하여 동일한 옵션 찾기 (ID 기준)
      ProductOption? existingOption;
      for (final existing in _selectedOptions.keys) {
        if (existing.id == option.id) {
          existingOption = existing;
          break;
        }
      }
      
      if (existingOption != null) {
        // 기존 옵션이 있으면 수량 증가
        _selectedOptions[existingOption] = (_selectedOptions[existingOption] ?? 0) + 1;
        print('  - 기존 옵션 발견, 수량 증가: ${_selectedOptions[existingOption]}');
      } else {
        // 새 옵션 추가
        _selectedOptions[option] = 1;
        print('  - 새 옵션 추가, 수량: 1');
      }
      
      // 옵션 선택 후 처리
      _selectedMonths = null; // 개월수만 초기화
      
      if (_stepGroups.length > 1) {
        // 단계가 여러 개인 경우: 단계 선택 초기화 (다른 단계 선택 가능)
        _selectedStep = null;
        _expandedSubject = null;
        print('  - 단계가 여러 개이므로 단계 선택 초기화');
      } else {
        // 단계가 1개만 있는 경우: 단계 선택은 유지하되 확장 닫기
        // _selectedStep은 유지 (자동 선택된 상태 유지)
        _expandedSubject = null; // 확장 닫기
        print('  - 단계가 1개뿐이므로 단계 선택 유지, 확장 닫기: $_selectedStep');
      }
      
      _updateMonthsGroups();
      
      print('  - 바텀시트 내부 상태 업데이트 완료, 총 옵션 개수: ${_selectedOptions.length}');
    });
    
    // 부모에게도 알림 (상위 화면 동기화)
    widget.onOptionsChanged(Map<ProductOption, int>.from(_selectedOptions));
  }
  
  /// 옵션 수량 변경
  void _updateOptionQuantity(ProductOption option, int quantity) {
    if (quantity <= 0) {
      _removeOption(option);
      return;
    }
    setState(() {
      _selectedOptions[option] = quantity;
    });
    widget.onOptionsChanged(Map<ProductOption, int>.from(_selectedOptions));
  }
  
  /// 옵션 제거
  void _removeOption(ProductOption option) {
    setState(() {
      _selectedOptions.remove(option);
    });
    widget.onOptionsChanged(Map<ProductOption, int>.from(_selectedOptions));
  }
  
  /// 총 가격 계산
  int _calculateTotalPrice() {
    int total = 0;
    _selectedOptions.forEach((option, quantity) {
      total += (widget.basePrice + option.price) * quantity;
    });
    return total;
  }
  
  /// 옵션 그룹 초기화
  void _initializeGroups() {
    _groupedOptionsByStep.clear();
    _stepGroups.clear();
    
    print('📋 [옵션 바텀시트] 옵션 그룹 초기화 시작 - 총 옵션 개수: ${widget.options.length}');
    
    // 단계별로 그룹화
    for (final option in widget.options) {
      final step = option.step;
      
      if (!_groupedOptionsByStep.containsKey(step)) {
        _groupedOptionsByStep[step] = [];
        _stepGroups.add(step);
      }
      
      _groupedOptionsByStep[step]!.add(option);
    }
    
    print('  - 발견된 단계 그룹: $_stepGroups');
    _groupedOptionsByStep.forEach((step, options) {
      print('    • $step: ${options.length}개 옵션');
    });
    
    // 단계 그룹이 1개일 때만 자동 선택 (여러 단계가 있으면 사용자가 직접 선택)
    if (_stepGroups.length == 1) {
      if (_stepGroups.isNotEmpty) {
        _selectedStep = _stepGroups.first;
        print('📋 [옵션 바텀시트] 단계가 1개뿐이므로 자동 선택: $_selectedStep');
      }
    }
    
    // 단계가 선택되어 있으면 해당 단계의 개월수 목록 업데이트
    _updateMonthsGroups();
  }
  
  /// 선택된 단계에 따라 개월수 그룹 업데이트
  void _updateMonthsGroups() {
    _groupedOptionsByMonths.clear();
    _monthsGroups.clear();
    
    if (_selectedStep == null) {
      print('📋 [옵션 바텀시트] 단계가 선택되지 않아 개월수 그룹 업데이트 스킵');
      return;
    }
    
    print('📋 [옵션 바텀시트] 개월수 그룹 업데이트 - 선택된 단계: $_selectedStep');
    final stepOptions = _groupedOptionsByStep[_selectedStep] ?? [];
    
    for (final option in stepOptions) {
      final months = option.months;
      if (months != null) {
        if (!_groupedOptionsByMonths.containsKey(months)) {
          _groupedOptionsByMonths[months] = [];
          _monthsGroups.add(months);
        }
        _groupedOptionsByMonths[months]!.add(option);
      }
    }
    
    // 개월수 오름차순 정렬
    _monthsGroups.sort();
    print('  - 사용 가능한 개월수: $_monthsGroups');
  }
  
  /// 두 번째 드롭다운(개월수)이 활성화되었는지 확인
  bool get _isMonthsEnabled {
    return _selectedStep != null;
  }
  
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: DraggableScrollableSheet(
            initialChildSize: 1.0, // 부모 높이의 100% 사용
            minChildSize: 0.6,
            maxChildSize: 1.0, // 부모 높이의 100%까지만
            builder: (context, scrollController) {
            return Column(
              children: [
                // 드래그 핸들
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // 헤더 섹션
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1),
                
                // 선택된 옵션 목록
                if (_selectedOptions.isNotEmpty) ...[
                  Container(
                    height: 200,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '선택된 옵션',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _selectedOptions.length,
                            itemBuilder: (context, index) {
                              final entry = _selectedOptions.entries.elementAt(index);
                              final option = entry.key;
                              final quantity = entry.value;
                              final itemPrice = (widget.basePrice + option.price) * quantity;
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            option.displayText,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${itemPrice.toString().replaceAllMapped(
                                              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                              (Match m) => '${m[1]},',
                                            )}원',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // 수량 조절
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, size: 18),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: quantity > 1
                                              ? () => _updateOptionQuantity(option, quantity - 1)
                                              : null,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Text(
                                            '$quantity',
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, size: 18),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _updateOptionQuantity(option, quantity + 1),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _removeOption(option),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
                
                // 단계별 옵션 선택 (subjects에 따라 동적 생성)
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        // 드롭다운 필드들
                        ...List.generate(widget.subjects.length, (subjectIndex) {
                          final subject = widget.subjects[subjectIndex];
                          final isFirstSubject = subjectIndex == 0;
                          final isSecondSubject = subjectIndex == 1;
                          
                          // 옵션 주제가 1개만 있는 경우에도 단계가 여러 개면 상위옵션을 먼저 선택하게 한다.
                          if (widget.subjects.length == 1) {
                            return Column(
                              children: [
                                if (_stepGroups.length > 1)
                                  _buildStepSelectionDropdown(subject),
                                if (_isMonthsEnabled)
                                  _buildMonthsSelectionDropdown('개월수 선택')
                                else if (_stepGroups.length > 1)
                                  _buildDisabledDropdown('개월수 선택'),
                              ],
                            );
                          }
                          
                          // 옵션 주제가 2개 이상인 경우: 기존 로직 유지
                          // 첫 번째 subject: 단계 선택
                          if (isFirstSubject) {
                            return _buildStepSelectionDropdown(subject);
                          }
                          
                          // 두 번째 subject: 개월수 선택 (단계 선택 후 활성화)
                          if (isSecondSubject && _isMonthsEnabled) {
                            return _buildMonthsSelectionDropdown(subject);
                          }
                          
                          // 비활성화된 상태
                          if (isSecondSubject && !_isMonthsEnabled) {
                            return _buildDisabledDropdown(subject);
                          }
                          
                          return const SizedBox.shrink();
                        }),
                        
                        // 확장된 옵션 리스트
                        if (_expandedSubject != null) ...[
                          const SizedBox(height: 8),
                          _buildExpandedOptionsList(),
                        ],
                      ],
                    ),
                  ),
                ),
                
                // 주문 요약 및 버튼
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (_selectedOptions.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '총 결제금액',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${_calculateTotalPrice().toString().replaceAllMapped(
                                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                  (Match m) => '${m[1]},',
                                )}원',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF4081),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: widget.productKind == 'general'
                            ? Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _selectedOptions.isEmpty
                                          ? null
                                          : widget.onAddToCart,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        side: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      child: const Text(
                                        '장바구니',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _selectedOptions.isEmpty
                                          ? null
                                          : widget.onBuyNow,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFF4081),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        disabledBackgroundColor: Colors.grey[300],
                                      ),
                                      child: const Text(
                                        '구매하기',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ElevatedButton(
                                onPressed: _selectedOptions.isEmpty
                                    ? null
                                    : widget.onReserve,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF4081),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  disabledBackgroundColor: Colors.grey[300],
                                ),
                                child: const SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    '처방예약하기',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          ),
        ),
      ),
    );
  }
  
  /// 단계 선택 드롭다운
  Widget _buildStepSelectionDropdown(String subject) {
    final isSelected = _selectedStep != null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: isSelected 
            ? const Color(0xFFFF4081).withOpacity(0.05)
            : Colors.grey[50],
        border: Border.all(
          color: isSelected 
              ? const Color(0xFFFF4081)
              : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            if (_expandedSubject == subject) {
              _expandedSubject = null; // 닫기
            } else {
              _expandedSubject = subject; // 열기
            }
          });
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFFFF4081) : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedStep ?? '선택없음 선택하기',
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected ? const Color(0xFFFF4081) : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _expandedSubject == subject ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: isSelected ? const Color(0xFFFF4081) : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }
  
  /// 개월수 선택 드롭다운
  Widget _buildMonthsSelectionDropdown(String subject) {
    final isSelected = _selectedMonths != null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: isSelected 
            ? const Color(0xFFFF4081).withOpacity(0.05)
            : Colors.grey[50],
        border: Border.all(
          color: isSelected 
              ? const Color(0xFFFF4081)
              : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            if (_expandedSubject == subject) {
              _expandedSubject = null; // 닫기
            } else {
              _expandedSubject = subject; // 열기
            }
          });
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFFFF4081) : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedMonths != null ? '$_selectedMonths개월' : '선택없음 선택하기',
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected ? const Color(0xFFFF4081) : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _expandedSubject == subject ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: isSelected ? const Color(0xFFFF4081) : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }
  
  /// 비활성화된 드롭다운
  Widget _buildDisabledDropdown(String subject) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '선택없음 선택하기',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '상위 옵션을 먼저 선택해주세요',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
   /// 확장된 옵션 리스트 빌드 (같은 바텀 시트 내에서 표시)
  Widget _buildExpandedOptionsList() {
    if (_expandedSubject == null) return const SizedBox.shrink();
    
    final subjectIndex = widget.subjects.indexOf(_expandedSubject!);
    final isFirstSubject = subjectIndex == 0;
    final isSecondSubject = subjectIndex == 1;
    
    // 옵션 주제가 1개일 때:
    // 1) 단계 드롭다운이 펼쳐지면 단계 리스트 표시
    // 2) 개월수 드롭다운이 펼쳐지면 개월수 리스트 표시
    if (widget.subjects.length == 1) {
      if (_expandedSubject == widget.subjects.first && _stepGroups.length > 1) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _expandedSubject!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ..._stepGroups.map((step) {
              final isSelected = _selectedStep == step;

              return InkWell(
                onTap: () {
                  print('🔘 [옵션 바텀시트] 단계 선택: $step');
                  setState(() {
                    _selectedStep = step;
                    _selectedMonths = null;
                    _updateMonthsGroups();
                    _expandedSubject = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFF4081).withOpacity(0.05)
                        : Colors.white,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFF4081)
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        step,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? const Color(0xFFFF4081) : Colors.black87,
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFFFF4081),
                          size: 20,
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      }

      if (_expandedSubject != '개월수 선택' || _selectedStep == null) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _expandedSubject!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ..._monthsGroups.map((months) {
            final isSelected = _selectedMonths == months;
            final optionForMonths = _groupedOptionsByMonths[months]?.first;
            
            if (optionForMonths == null) return const SizedBox.shrink();
            
            return InkWell(
              onTap: () {
                print('🔘 [옵션 바텀시트] 개월수 선택: ${months}개월');
                print('  - 선택된 옵션: ID=${optionForMonths.id}, 가격=${optionForMonths.price}원');
                // 옵션 추가
                _addOption(optionForMonths);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? const Color(0xFFFF4081).withOpacity(0.05)
                      : Colors.white,
                  border: Border.all(
                    color: isSelected 
                        ? const Color(0xFFFF4081)
                        : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${months}개월',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFFFF4081) : Colors.black87,
                            ),
                          ),
                          if (optionForMonths.price > 0) ...[
                            const SizedBox(height: 4),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (optionForMonths.price > 0)
                          Text(
                            '+${optionForMonths.formattedPrice.replaceAll('원', '')}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? const Color(0xFFFF4081) : Colors.black87,
                            ),
                          ),
                        if (isSelected) ...[
                          const SizedBox(height: 4),
                          Icon(
                            Icons.check_circle,
                            color: const Color(0xFFFF4081),
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      );
    }
    
    // 첫 번째 subject: 단계 선택 리스트
    if (isFirstSubject) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _expandedSubject!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ..._stepGroups.map((step) {
            final isSelected = _selectedStep == step;
            
            return InkWell(
              onTap: () {
                print('🔘 [옵션 바텀시트] 단계 선택: $step');
                setState(() {
                  _selectedStep = step;
                  _selectedMonths = null; // 단계 변경 시 개월수 초기화
                  _updateMonthsGroups();
                  _expandedSubject = null; // 선택 후 닫기
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? const Color(0xFFFF4081).withOpacity(0.05)
                      : Colors.white,
                  border: Border.all(
                    color: isSelected 
                        ? const Color(0xFFFF4081)
                        : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      step,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? const Color(0xFFFF4081) : Colors.black87,
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: const Color(0xFFFF4081),
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      );
    }
    
    // 두 번째 subject: 개월수 선택 리스트 (실제 옵션 선택)
    if (isSecondSubject && _selectedStep != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _expandedSubject!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ..._monthsGroups.map((months) {
            final isSelected = _selectedMonths == months;
            final optionForMonths = _groupedOptionsByMonths[months]?.first;
            
            if (optionForMonths == null) return const SizedBox.shrink();
            
            return InkWell(
              onTap: () {
                print('🔘 [옵션 바텀시트] 개월수 선택: ${months}개월');
                print('  - 선택된 옵션: ID=${optionForMonths.id}, 가격=${optionForMonths.price}원');
                // 옵션 추가
                _addOption(optionForMonths);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? const Color(0xFFFF4081).withOpacity(0.05)
                      : Colors.white,
                  border: Border.all(
                    color: isSelected 
                        ? const Color(0xFFFF4081)
                        : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${months}개월',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFFFF4081) : Colors.black87,
                            ),
                          ),
                          if (optionForMonths != null && optionForMonths.price > 0) ...[
                            const SizedBox(height: 4),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (optionForMonths != null && optionForMonths.price > 0)
                          Text(
                            '+${optionForMonths.formattedPrice.replaceAll('원', '')}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? const Color(0xFFFF4081) : Colors.black87,
                            ),
                          ),
                        if (isSelected) ...[
                          const SizedBox(height: 4),
                          Icon(
                            Icons.check_circle,
                            color: const Color(0xFFFF4081),
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      );
    }
    
    return const SizedBox.shrink();
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
