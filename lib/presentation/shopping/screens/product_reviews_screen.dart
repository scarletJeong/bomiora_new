import 'package:flutter/material.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_footer.dart';
import '../../../data/models/review/review_model.dart';
import '../../../data/services/review_service.dart';
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
        
        setState(() {
          _supporterReviews = allReviews.where((r) => r.isSupporterReview).toList();
          _generalReviews = allReviews.where((r) => r.isGeneralReview).toList();
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
                _buildReviewList(_supporterReviews),
                _buildReviewList(_generalReviews),
              ],
            ),
    );
  }

  Widget _buildReviewList(List<ReviewModel> reviews) {
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reviews.length + 1, // footer 추가
      itemBuilder: (context, index) {
        // 마지막 아이템은 Footer
        if (index == reviews.length) {
          return const Column(
            children: [
              SizedBox(height: 300),
              AppFooter(),
            ],
          );
        }
        
        final review = reviews[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReviewDetailScreen(
                  review: review,
                  fromProductDetail: true, // 제품 상세페이지에서 왔음을 표시
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
      },
    );
  }
}

