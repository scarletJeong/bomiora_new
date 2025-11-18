import 'package:flutter/material.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_footer.dart';
import '../../../data/models/review/review_model.dart';
import '../../../data/services/review_service.dart';
import '../../../data/services/auth_service.dart';
import 'review_edit_screen.dart';
import '../../review/screens/review_detail_screen.dart';

/// 내 리뷰 목록 화면
class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  List<ReviewModel> _reviews = [];
  bool _isLoading = false;
  int _currentPage = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  /// 리뷰 목록 로드
  Future<void> _loadReviews({bool refresh = false}) async {
    if (_isLoading) return;
    if (!refresh && !_hasMore) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _currentPage = 0;
        _reviews.clear();
        _hasMore = true;
      }
    });

    try {
      final user = await AuthService.getUser();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다.')),
          );
        }
        return;
      }

      final result = await ReviewService.getMemberReviews(
        mbId: user.id,
        page: _currentPage,
        size: 20,
      );

      if (result['success'] == true) {
        final newReviews = result['reviews'] as List<ReviewModel>;
        
        setState(() {
          if (refresh) {
            _reviews = newReviews;
          } else {
            _reviews.addAll(newReviews);
          }
          _currentPage++;
          _hasMore = result['hasNext'] ?? false;
        });
      }
    } catch (e) {
      print('리뷰 로드 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리뷰를 불러오는데 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          title: const Text(
            '내 리뷰',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _reviews.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF4081),
        ),
      );
    }

    if (_reviews.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => _loadReviews(refresh: true),
      color: const Color(0xFFFF4081),
      child: CustomScrollView(
        slivers: [
          // 리뷰 리스트 (padding 적용)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == _reviews.length) {
                    // 로딩 인디케이터
                    if (!_isLoading) {
                      _loadReviews();
                    }
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF4081),
                        ),
                      ),
                    );
                  }
                  return _buildReviewCard(_reviews[index]);
                },
                childCount: _reviews.length + (_hasMore ? 1 : 0),
              ),
            ),
          ),
          
          // Footer
          const SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(height: 300),
                AppFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 빈 상태 위젯
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '작성한 리뷰가 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// 리뷰 카드
  Widget _buildReviewCard(ReviewModel review) {
    return InkWell(
      onTap: () {
        // 리뷰 상세 페이지로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewDetailScreen(review: review),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 (날짜, 승인 상태)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (review.isTime != null)
                  Text(
                    '${review.isTime!.year}.${review.isTime!.month.toString().padLeft(2, '0')}.${review.isTime!.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: review.isConfirm == 1
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    review.isConfirm == 1 ? '승인됨' : '검토중',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: review.isConfirm == 1 ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 평점
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      final rating = review.averageScore ?? 0;
                      return Icon(
                        index < rating.round() ? Icons.star : Icons.star_border,
                        size: 20,
                        color: const Color(0xFFFF4081),
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      '${review.averageScore?.toStringAsFixed(1) ?? '0.0'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF4081),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 좋았던 점
                if (review.isPositiveReviewText != null &&
                    review.isPositiveReviewText!.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '좋았던 점',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        review.isPositiveReviewText!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),

                // 아쉬운 점
                if (review.isNegativeReviewText != null &&
                    review.isNegativeReviewText!.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '아쉬운 점',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        review.isNegativeReviewText!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),

                // 이미지
                if (review.images.isNotEmpty)
                  Column(
                    children: [
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: review.images.length,
                          itemBuilder: (context, index) {
                            return Container(
                              width: 80,
                              height: 80,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.image,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),

                // 도움이 돼요
                Row(
                  children: [
                    Icon(
                      Icons.thumb_up,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '도움이 돼요 ${review.isGood ?? 0}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 액션 버튼
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _editReview(review),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    side: const BorderSide(color: Color(0xFFFF4081)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    '수정',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFFF4081),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _deleteReview(review),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    side: BorderSide(color: Colors.grey[400]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    '삭제',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  /// 리뷰 수정
  Future<void> _editReview(ReviewModel review) async {
    if (review.isId == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewEditScreen(review: review),
      ),
    );

    if (result == true) {
      _loadReviews(refresh: true);
    }
  }

  /// 리뷰 삭제
  Future<void> _deleteReview(ReviewModel review) async {
    if (review.isId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('리뷰 삭제'),
        content: const Text('정말 이 리뷰를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '삭제',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final user = await AuthService.getUser();
      if (user == null) return;

      final result = await ReviewService.deleteReview(
        review.isId!,
        user.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '리뷰가 삭제되었습니다.'),
            backgroundColor:
                result['success'] == true ? Colors.green : Colors.red,
          ),
        );

        if (result['success'] == true) {
          _loadReviews(refresh: true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('리뷰 삭제 중 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

