import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../../data/models/product/product_model.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../../data/models/review/review_model.dart';
import '../../../data/repositories/review/review_repository.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/html_parser.dart' as custom_html_parser;
import '../../../core/utils/point_helper.dart';
import '../../../data/services/point_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../data/models/product/product_option_model.dart';
import '../../../data/repositories/product/product_option_repository.dart';
import '../widgets/product_tail_info_section.dart';
import '../../user/questionnaire/screens/questionnaire_form_screen.dart';

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
  String _selectedReviewType = 'supporter'; // 'supporter' or 'all'
  PageController? _pageController;
  
  // 리뷰 관련 상태
  List<Review> _reviews = [];
  List<Review> _supporterReviews = [];
  List<Review> _generalReviews = [];
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
    _tabController = TabController(length: 2, vsync: this);
    _loadProductDetail();
    _loadReviews();
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
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = '제품 정보를 불러오는데 실패했습니다: $e';
      });
    }
  }

  Future<void> _loadReviews() async {
    if (widget.productId.isEmpty) return;
    
    setState(() {
      _isLoadingReviews = true;
    });

    try {
      // 전체 리뷰 가져오기
      final allReviews = await ReviewRepository.getProductReviews(
        productId: widget.productId,
      );
      
      // 서포터 리뷰와 일반 리뷰 분류
      final supporter = allReviews.where((r) => r.isSupporterReview).toList();
      final general = allReviews.where((r) => r.isGeneralReview).toList();
      
      // 리뷰 통계 가져오기
      final stats = await ReviewRepository.getReviewStats(widget.productId);
      
      setState(() {
        _reviews = allReviews;
        _supporterReviews = supporter;
        _generalReviews = general;
        _reviewStats = stats;
        _isLoadingReviews = false;
      });
      
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
        print('  - 옵션 ID: ${option.id}, 이름: ${option.displayText}, 가격: ${option.price}원');
      }
      setState(() {
        _productOptions = options;
      });
    } catch (e) {
      print('⚠️ [옵션] 로드 실패: $e');
      // 옵션 로드 실패 시 무시
    }
  }

  List<String> _getProductImages() {
    if (_product == null) return [];
    final images = <String>[];
    
    // 1. 메인 썸네일 이미지
    if (_product!.imageUrl != null && _product!.imageUrl!.isNotEmpty) {
      images.add(_product!.imageUrl!);
    }
    
    // 2. additionalInfo에서 추가 이미지 가져오기
    if (_product!.additionalInfo != null) {
      final itImg2 = _product!.additionalInfo!['it_img2']?.toString();
      final itImg3 = _product!.additionalInfo!['it_img3']?.toString();
      if (itImg2 != null && itImg2.isNotEmpty) {
        final normalized = ImageUrlHelper.normalizeThumbnailUrl(itImg2, _product!.id);
        if (normalized != null) images.add(normalized);
      }
      if (itImg3 != null && itImg3.isNotEmpty) {
        final normalized = ImageUrlHelper.normalizeThumbnailUrl(itImg3, _product!.id);
        if (normalized != null) images.add(normalized);
      }
      
      // 3. HTML 콘텐츠(it_explain)에서 이미지 추출
      final itExplain = _product!.additionalInfo!['it_explan']?.toString() ?? 
                        _product!.description;
      if (itExplain != null && itExplain.isNotEmpty) {
        final htmlImages = custom_html_parser.HtmlParser.extractImageUrls(itExplain);
        for (final imgUrl in htmlImages) {
          // URL 정규화 (상대 경로인 경우 처리)
          String normalizedUrl = imgUrl;
          // 전체 URL이 아닌 경우 정규화
          if (!imgUrl.startsWith('http://') && !imgUrl.startsWith('https://')) {
            // 상대 경로인 경우
            normalizedUrl = ImageUrlHelper.normalizeThumbnailUrl(imgUrl, _product!.id) ?? imgUrl;
          } else {
            // 전체 URL인 경우
            // 1. bomiora.kr 도메인을 로컬 환경에 맞게 변경
            if (imgUrl.contains('bomiora.kr')) {
              // 로컬 개발 환경인 경우 localhost로 변경
              normalizedUrl = ImageUrlHelper.convertToLocalUrl(imgUrl);
            }
          }
          
          // 중복 제거
          if (!images.contains(normalizedUrl)) {
            images.add(normalizedUrl);
          }
        }
      }
    }
    
    return images;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(40), // AppBar 높이 축소
        child: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
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
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // 콘텐츠 길이에 맞게 조정
        children: [
          // 이미지 캐러셀
          _buildImageCarousel(images),
          
          // 제품 정보 섹션
          Padding(
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
                const SizedBox(height: 12),
                
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
                
                // 가격 정보 (간단 설명 아래)
                _buildPriceSection(),
                
                // 가격 아래 구분선
                const Divider(
                  height: 32,
                  thickness: 1,
                  color: Colors.grey,
                ),
                
                // 제품 스펙 (처방단위, 복용방법, 패키지구성, 적립포인트, 배송비결제)
                _buildProductSpecs(),
                const SizedBox(height: 16),
                
                // 현재 나의 보유포인트 (별도 섹션)
                _buildUserPointSection(),
                
                // 선택된 옵션 표시 (옵션이 선택되었을 때만)
                if (_selectedOptions.isNotEmpty)
                  _buildSelectedOptionSection(),
              ],
            ),
          ),
          
          // 리뷰 탭
          _buildReviewSection(),
          
          // 상세페이지 HTML 콘텐츠 (리뷰 아래)
          _buildDetailContent(),
          
          // 공통 정보 섹션 (배송, 처방 프로세스, 교환/환불)
          const ProductTailInfoSection(),
          
          // 하단 여백 (하단 액션 바 공간)
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(List<String> images) {
    if (images.isEmpty) {
      return Container(
        height: 300,
        width: double.infinity,
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
    }

    // PageController 초기화 (이미지가 2개 이상일 때만)
    if (images.length > 1 && _pageController == null) {
      _pageController = PageController();
    }

    return SizedBox(
      height: 300,
      child: Stack(
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
      ),
    );
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

  Widget _buildReviewSection() {
    // 실제 리뷰 데이터 사용
    final supporterReviewCount = _supporterReviews.length;
    final allReviewCount = _reviews.length;
    final currentReviews = _selectedReviewType == 'supporter' 
        ? _supporterReviews 
        : _generalReviews;
    
    return Container(
      margin: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          // 리뷰 탭
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFFF4081),
              indicatorWeight: 3,
              labelColor: const Color(0xFFFF4081),
              unselectedLabelColor: Colors.grey[600],
              onTap: (index) {
                setState(() {
                  _selectedReviewType = index == 0 ? 'supporter' : 'all';
                });
              },
              tabs: [
                Tab(
                  child: Text(
                    '서포터 리뷰($supporterReviewCount)',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                Tab(
                  child: Text(
                    '전체 리뷰($allReviewCount)',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          
          // 리뷰 평가 요약
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '서포터 리뷰 평가',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 32,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _reviewStats != null 
                          ? _reviewStats!['supporterAverage']?.toStringAsFixed(1) ?? '0'
                          : '0',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                    children: [
                      const TextSpan(text: '만족 '),
                      TextSpan(
                        text: '${_reviewStats != null ? _reviewStats!['supporterSatisfied'] ?? 0 : 0}건',
                        style: TextStyle(
                          color: const Color(0xFFFF4081),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(text: ' / $supporterReviewCount'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildReviewRatingBar(
                  '효과', 
                  _reviewStats != null 
                      ? ((_reviewStats!['score1Avg'] ?? 0.0) * 20).round()
                      : 0,
                ),
                const SizedBox(height: 8),
                _buildReviewRatingBar(
                  '가성비', 
                  _reviewStats != null 
                      ? ((_reviewStats!['score2Avg'] ?? 0.0) * 20).round()
                      : 0,
                ),
                const SizedBox(height: 8),
                _buildReviewRatingBar(
                  '맛/향', 
                  _reviewStats != null 
                      ? ((_reviewStats!['score3Avg'] ?? 0.0) * 20).round()
                      : 0,
                ),
                const SizedBox(height: 8),
                _buildReviewRatingBar(
                  '편리함', 
                  _reviewStats != null 
                      ? ((_reviewStats!['score4Avg'] ?? 0.0) * 20).round()
                      : 0,
                ),
              ],
            ),
          ),
          
          // 리뷰 목록
          _isLoadingReviews
              ? Container(
                  padding: const EdgeInsets.all(32),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : currentReviews.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(32),
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
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: currentReviews.length,
                      itemBuilder: (context, index) {
                        final review = currentReviews[index];
                        return _buildReviewItem(review);
                      },
                    ),
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

  Widget _buildReviewItem(Review review) {
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
                  review.userName,
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
                  return Icon(
                    index < review.rating.round()
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
          // 리뷰 제목
          if (review.subject.isNotEmpty)
            Text(
              review.subject,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          if (review.subject.isNotEmpty) const SizedBox(height: 8),
          // 리뷰 내용
          Text(
            review.content,
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
              Text(
                '${review.createdAt.year}.${review.createdAt.month.toString().padLeft(2, '0')}.${review.createdAt.day.toString().padLeft(2, '0')}',
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
                    '${review.helpfulCount}',
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
    
    // it_explan에서 HTML 콘텐츠 가져오기
    final itExplain = _product!.additionalInfo?['it_explan']?.toString() ?? 
                      _product!.description;
    if (itExplain == null || itExplain.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // HTML에서 bomiora.kr URL을 localhost로 변환
    String processedHtml = itExplain;
    if (processedHtml.contains('bomiora.kr')) {
      final urlPattern = RegExp(r'''https?://bomiora\.kr([^"']+)''', caseSensitive: false);
      processedHtml = processedHtml.replaceAllMapped(
        urlPattern,
        (match) {
          final path = match.group(1) ?? '';
          // imageBaseUrl 사용하여 변환
          final baseUrl = ImageUrlHelper.imageBaseUrl;
          String localBase = baseUrl;
          if (localBase.startsWith('http://localhost')) {
            localBase = localBase.replaceFirst('http://', 'https://');
          }
          return '$localBase$path';
        },
      );
    }
    
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
                width: Width(MediaQuery.of(context).size.width - 32),
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
                onPressed: () {
                  setState(() {
                    _isFavorite = !_isFavorite;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            // 처방 예약하기 버튼
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
                child: const Text(
                  '처방 예약하기',
                  style: TextStyle(
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
    
    // 옵션이 없으면 직접 예약 진행
    if (_productOptions.isEmpty) {
      _proceedWithReservation();
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
        onAddToCart: () {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('장바구니에 추가되었습니다.')),
          );
        },
        onReserve: () {
          Navigator.of(context).pop();
          _navigateToQuestionnaire();
        },
      ),
    );
  }

  /// 문진표 작성 페이지로 이동
  void _navigateToQuestionnaire() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QuestionnaireFormScreen(),
      ),
    );
    
    if (result == true) {
      // 문진표 작성 완료 후 처리 (필요시)
    }
  }

  /// 옵션 선택 후 예약 진행
  void _proceedWithReservation() {
    if (_selectedOptions.isEmpty || _product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('옵션을 선택해주세요.')),
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
      
      // 선택 초기화
      _selectedStep = null;
      _selectedMonths = null;
      _expandedSubject = null;
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
    return _selectedStep != null && widget.subjects.length >= 2;
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
                            ? OutlinedButton(
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
                                child: const SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    '장바구니',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
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
                            Text(
                              '오늘출발 주문 마감으로 내일 출발!',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[400],
                              ),
                            ),
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
