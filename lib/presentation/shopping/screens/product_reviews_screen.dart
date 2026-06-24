import 'package:flutter/material.dart';

import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_footer.dart';
import '../../../data/models/review/review_model.dart';
import '../../../data/services/review_service.dart';
import '../../review/screens/review_detail_screen.dart';
import '../widgets/producrt_normal_review.dart';
import '../widgets/producrt_support_review.dart';

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
        fetchAll: true,
      );

      if (result['success'] == true) {
        final allReviews = result['reviews'] as List<ReviewModel>;

        final supporter =
            allReviews.where((r) => r.isSupporterReview).toList();
        final general = allReviews.where((r) => r.isGeneralReview).toList();

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
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _openReviewDetail(ReviewModel review) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewDetailScreen(
          review: review,
          fromProductDetail: true,
        ),
      ),
    );
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
          labelColor: const Color(0xFFFF5A8D),
          unselectedLabelColor: const Color(0xFF898383),
          indicatorColor: const Color(0xFFFF5A8D),
          dividerColor: Colors.transparent,
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
                _buildTabContent(
                  reviews: _supporterReviews,
                  isSupporter: true,
                ),
                _buildTabContent(
                  reviews: _generalReviews,
                  isSupporter: false,
                ),
              ],
            ),
    );
  }

  Widget _buildTabContent({
    required List<ReviewModel> reviews,
    required bool isSupporter,
  }) {
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

    return Column(
      children: [
        Expanded(
          child: isSupporter
              ? ProductSupportReview(
                  reviews: reviews,
                  isLoading: false,
                  visibleCount: reviews.length,
                  onLoadMore: () {},
                  onReviewTap: _openReviewDetail,
                )
              : ProductNormalReview(
                  reviews: reviews,
                  isLoading: false,
                  visibleCount: reviews.length,
                  onLoadMore: () {},
                  onReviewTap: _openReviewDetail,
                ),
        ),
        const AppFooter(),
      ],
    );
  }
}
