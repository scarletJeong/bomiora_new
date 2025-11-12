import 'package:flutter/material.dart';
import '../../../data/models/review/review_model.dart';
import '../../../data/services/review_service.dart';
import '../../shopping/screens/product_detail_screen.dart';

class ReviewSection extends StatefulWidget {
  const ReviewSection({super.key});

  @override
  State<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<ReviewSection> {
  List<ReviewModel> reviews = [];
  bool isLoading = true;
  int _supporterCount = 0;
  int _generalCount = 0;
  
  // 기본 상품 ID (보미오라 다이어트환)
  final String defaultProductId = '1686290723';

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      // 서포터 리뷰와 일반 리뷰 개수 조회
      final supporterResult = await ReviewService.getProductReviews(
        itId: defaultProductId,
        rvkind: 'supporter',
        page: 0,
        size: 1, // 개수만 필요
      );
      
      final generalResult = await ReviewService.getProductReviews(
        itId: defaultProductId,
        rvkind: 'general',
        page: 0,
        size: 1, // 개수만 필요
      );
      
      // 실제 리뷰 데이터 로드 (서포터 리뷰만)
      final result = await ReviewService.getProductReviews(
        itId: defaultProductId,
        rvkind: 'supporter',
        page: 0,
        size: 6, // 최대 6개만 로드
      );
      
      if (mounted) {
        setState(() {
          if (result['success'] == true) {
            reviews = result['reviews'] as List<ReviewModel>;
          }
          _supporterCount = supporterResult['totalElements'] ?? 0;
          _generalCount = generalResult['totalElements'] ?? 0;
          isLoading = false;
        });
      }
    } catch (e) {
      print('리뷰 로드 오류: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 섹션 타이틀
          const Text(
            '셀럽, 인생의 봄이 오다!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              children: [
                TextSpan(
                  text: '보미오라 ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF007FAE),
                  ),
                ),
                TextSpan(
                  text: '다이어트&디톡스 환',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // 서포터/일반 리뷰 개수 표시
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4081).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '서포터 리뷰 $_supporterCount개',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF4081),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '일반 리뷰 $_generalCount개',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          
          // 리뷰 그리드
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: reviews.length > 4 ? 4 : reviews.length,
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    return _buildReviewCard(review);
                  },
                ),
          
          const SizedBox(height: 30),
          
          // 리뷰 더보기 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // 상품 상세 페이지로 이동 (리뷰 탭)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailScreen(
                      productId: defaultProductId,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007FAE),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '+ 리뷰 더보기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    return GestureDetector(
      onTap: () {
        // 상품 상세 페이지로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              productId: review.itId,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 리뷰 이미지 (있으면 표시, 없으면 기본 이미지)
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: review.images.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: Image.network(
                          review.images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(
                                Icons.rate_review,
                                size: 40,
                                color: Colors.grey[400],
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.rate_review,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                      ),
              ),
            ),
            
            // 별점
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: List.generate(5, (index) {
                  final rating = review.averageScore ?? 0;
                  return Icon(
                    index < rating.round()
                        ? Icons.star
                        : Icons.star_border,
                    size: 16,
                    color: const Color(0xFFFF4081),
                  );
                }),
              ),
            ),
            
            // 리뷰 내용
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 작성자명
                    Text(
                      review.isName ?? '익명',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // 리뷰 내용
                    Expanded(
                      child: Text(
                        review.isPositiveReviewText ?? '',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
