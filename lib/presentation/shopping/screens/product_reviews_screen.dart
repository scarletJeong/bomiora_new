import 'package:flutter/material.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_footer.dart';
import '../../../data/models/review/review_model.dart';
import '../../../data/services/review_service.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../review/screens/review_detail_screen.dart';

/// 제품별 리뷰 목록 화면
class ProductReviewsScreen extends StatefulWidget {
  final String productId;
  final String productName;

  const ProductReviewsScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<ProductReviewsScreen> createState() => _ProductReviewsScreenState();
}

class _ProductReviewsScreenState extends State<ProductReviewsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ReviewModel> _supporterReviews = [];
  List<ReviewModel> _generalReviews = [];
  bool _isLoading = false;
  
  // 리뷰 통계
  Map<String, dynamic>? _supporterStats;
  Map<String, dynamic>? _generalStats;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReviews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);

    try {
      final result = await ReviewService.getProductReviews(
        itId: widget.productId,
        page: 0,
        size: 100,
      );

      if (result['success'] == true) {
        final allReviews = result['reviews'] as List<ReviewModel>;
        
        final supporter = allReviews.where((r) => r.isSupporterReview).toList();
        final general = allReviews.where((r) => r.isGeneralReview).toList();
        
        // 서포터 리뷰 통계 계산
        double supporterAverage = 0.0;
        int supporterSatisfied = 0;
        double supporterScore1Avg = 0.0;
        double supporterScore2Avg = 0.0;
        double supporterScore3Avg = 0.0;
        double supporterScore4Avg = 0.0;
        
        if (supporter.isNotEmpty) {
          final supporterWithScore = supporter.where((r) => r.averageScore != null).toList();
          if (supporterWithScore.isNotEmpty) {
            supporterAverage = supporterWithScore
                .map((r) => r.averageScore!)
                .reduce((a, b) => a + b) / supporterWithScore.length;
          }
          supporterSatisfied = supporter.where((r) => r.isSatisfied).length;
          
          supporterScore1Avg = supporter.map((r) => r.score1.toDouble()).reduce((a, b) => a + b) / supporter.length;
          supporterScore2Avg = supporter.map((r) => r.score2.toDouble()).reduce((a, b) => a + b) / supporter.length;
          supporterScore3Avg = supporter.map((r) => r.score3.toDouble()).reduce((a, b) => a + b) / supporter.length;
          supporterScore4Avg = supporter.map((r) => r.score4.toDouble()).reduce((a, b) => a + b) / supporter.length;
        }
        
        // 일반 리뷰 통계 계산
        double generalAverage = 0.0;
        int generalSatisfied = 0;
        double generalScore1Avg = 0.0;
        double generalScore2Avg = 0.0;
        double generalScore3Avg = 0.0;
        double generalScore4Avg = 0.0;
        
        if (general.isNotEmpty) {
          final generalWithScore = general.where((r) => r.averageScore != null).toList();
          if (generalWithScore.isNotEmpty) {
            generalAverage = generalWithScore
                .map((r) => r.averageScore!)
                .reduce((a, b) => a + b) / generalWithScore.length;
          }
          generalSatisfied = general.where((r) => r.isSatisfied).length;
          
          generalScore1Avg = general.map((r) => r.score1.toDouble()).reduce((a, b) => a + b) / general.length;
          generalScore2Avg = general.map((r) => r.score2.toDouble()).reduce((a, b) => a + b) / general.length;
          generalScore3Avg = general.map((r) => r.score3.toDouble()).reduce((a, b) => a + b) / general.length;
          generalScore4Avg = general.map((r) => r.score4.toDouble()).reduce((a, b) => a + b) / general.length;
        }
        
        // 서포터 리뷰: 포토가 있는 것 먼저 정렬
        supporter.sort((a, b) {
          final aHasPhoto = a.images.isNotEmpty;
          final bHasPhoto = b.images.isNotEmpty;
          if (aHasPhoto && !bHasPhoto) return -1;
          if (!aHasPhoto && bHasPhoto) return 1;
          return 0;
        });
        
        setState(() {
          _supporterReviews = supporter;
          _generalReviews = general;
          _supporterStats = {
            'average': supporterAverage,
            'satisfied': supporterSatisfied,
            'totalCount': supporter.length,
            'score1Avg': supporterScore1Avg,
            'score2Avg': supporterScore2Avg,
            'score3Avg': supporterScore3Avg,
            'score4Avg': supporterScore4Avg,
          };
          _generalStats = {
            'average': generalAverage,
            'satisfied': generalSatisfied,
            'totalCount': general.length,
            'score1Avg': generalScore1Avg,
            'score2Avg': generalScore2Avg,
            'score3Avg': generalScore3Avg,
            'score4Avg': generalScore4Avg,
          };
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('리뷰 로드 오류: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: Text(
          '${widget.productName} 리뷰',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFF4081),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFFF4081),
          tabs: [
            Tab(text: '서포터 리뷰 (${_supporterReviews.length})'),
            Tab(text: '일반 리뷰 (${_generalReviews.length})'),
          ],
        ),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildReviewList(_supporterReviews, isSupporter: true),
                _buildReviewList(_generalReviews, isSupporter: false),
              ],
            ),
    );
  }

  Widget _buildReviewList(List<ReviewModel> reviews, {required bool isSupporter}) {
    if (reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '리뷰가 없습니다',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 300),
            const AppFooter(),
          ],
        ),
      );
    }

    // 리뷰 통계
    final stats = isSupporter ? _supporterStats : _generalStats;
    final title = isSupporter ? '서포터 리뷰 평가' : '일반 리뷰 평가';

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reviews.length + 2, // 통계 + footer 추가
      itemBuilder: (context, index) {
        // 첫 번째 아이템은 통계
        if (index == 0) {
          if (stats != null && reviews.isNotEmpty) {
            return _buildReviewStats(
              title: title,
              average: stats['average'] as double,
              satisfied: stats['satisfied'] as int,
              totalCount: stats['totalCount'] as int,
              score1Avg: stats['score1Avg'] as double,
              score2Avg: stats['score2Avg'] as double,
              score3Avg: stats['score3Avg'] as double,
              score4Avg: stats['score4Avg'] as double,
            );
          }
          return const SizedBox.shrink();
        }
        
        // 마지막 아이템은 Footer
        if (index == reviews.length + 1) {
          return const Column(
            children: [
              SizedBox(height: 300),
              AppFooter(),
            ],
          );
        }
        
        final review = reviews[index - 1]; // 통계가 첫 번째이므로 index - 1
        
        // 서포터 리뷰는 포토 카드형, 일반 리뷰는 일반 카드형
        if (isSupporter) {
          return _buildPhotoReviewCard(review);
        } else {
          return _buildReviewCard(review);
        }
      },
    );
  }

  /// 포토 카드형 리뷰 (서포터 리뷰용)
  Widget _buildPhotoReviewCard(ReviewModel review) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewDetailScreen(
              review: review,
              fromProductDetail: true,
            ),
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
              height: 140,
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

  /// 일반 카드형 리뷰 (일반 리뷰용)
  Widget _buildReviewCard(ReviewModel review) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewDetailScreen(
              review: review,
              fromProductDetail: true,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  review.isName ?? '익명',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                ...List.generate(5, (i) {
                  final rating = review.averageScore ?? 0;
                  return Icon(
                    i < rating.round() ? Icons.star : Icons.star_border,
                    size: 16,
                    color: Colors.amber,
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),
            if (review.isPositiveReviewText != null)
              Text(
                review.isPositiveReviewText!,
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  /// 리뷰 평가 통계
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
}

