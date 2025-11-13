import 'package:flutter/material.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../../data/models/review/review_model.dart';
import '../../../data/services/review_service.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../shopping/screens/product_detail_screen.dart';

/// 리뷰 상세보기 화면
class ReviewDetailScreen extends StatefulWidget {
  final ReviewModel review;
  
  const ReviewDetailScreen({
    super.key,
    required this.review,
  });

  @override
  State<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends State<ReviewDetailScreen> {
  late ReviewModel _review;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _review = widget.review;
  }

  @override
  Widget build(BuildContext context) {
    return MobileLayoutWrapper(
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          title: const Text(
            '리뷰 상세',
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
          actions: [
            // 상품 보기 버튼
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailScreen(
                      productId: _review.itId,
                    ),
                  ),
                );
              },
              child: const Text(
                '상품보기',
                style: TextStyle(
                  color: Color(0xFFFF4081),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 작성자 정보
              _buildAuthorInfo(),
              
              // 평점
              _buildRatingSection(),
              
              // 리뷰 내용
              _buildReviewContent(),
              
              // 이미지
              if (_review.images.isNotEmpty) _buildImageSection(),
              
              // 사용자 정보
              if (_review.isWeight != null || _review.isHeight != null)
                _buildUserInfo(),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  /// 작성자 정보
  Widget _buildAuthorInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFFFF4081).withOpacity(0.1),
            child: Text(
              _review.isName?.substring(0, 1) ?? '?',
              style: const TextStyle(
                color: Color(0xFFFF4081),
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _review.isName ?? '익명',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_review.isSupporterReview)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '서포터',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_review.isTime != null)
                  Text(
                    '${_review.isTime!.year}.${_review.isTime!.month.toString().padLeft(2, '0')}.${_review.isTime!.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 평점 섹션
  Widget _buildRatingSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        children: [
          // 전체 평점
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(5, (index) {
                final rating = _review.averageScore ?? 0;
                return Icon(
                  index < rating.round() ? Icons.star : Icons.star_border,
                  size: 32,
                  color: const Color(0xFFFF4081),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_review.averageScore?.toStringAsFixed(1) ?? '0.0'}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF4081),
            ),
          ),
          const SizedBox(height: 24),
          
          // 세부 평점
          _buildDetailRating('효과', _review.isScore1),
          const SizedBox(height: 12),
          _buildDetailRating('가성비', _review.isScore2),
          const SizedBox(height: 12),
          _buildDetailRating('맛/향', _review.isScore3),
          const SizedBox(height: 12),
          _buildDetailRating('편리함', _review.isScore4),
        ],
      ),
    );
  }

  Widget _buildDetailRating(String label, int score) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: List.generate(5, (index) {
              return Icon(
                index < score ? Icons.star : Icons.star_border,
                size: 20,
                color: const Color(0xFFFF4081),
              );
            }),
          ),
        ),
        Text(
          '$score.0',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  /// 리뷰 내용
  Widget _buildReviewContent() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 좋았던 점
          if (_review.isPositiveReviewText != null &&
              _review.isPositiveReviewText!.isNotEmpty) ...[
            const Text(
              '좋았던 점',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _review.isPositiveReviewText!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 아쉬운 점
          if (_review.isNegativeReviewText != null &&
              _review.isNegativeReviewText!.isNotEmpty) ...[
            const Text(
              '아쉬운 점',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _review.isNegativeReviewText!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 꿀팁
          if (_review.isMoreReviewText != null &&
              _review.isMoreReviewText!.isNotEmpty) ...[
            Row(
              children: [
                const Icon(
                  Icons.lightbulb,
                  color: Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  '꿀팁',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _review.isMoreReviewText!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 이미지 섹션
  Widget _buildImageSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '사진',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _review.images.length,
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  ImageUrlHelper.getReviewImageUrl(_review.images[index]),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Icon(
                        Icons.image,
                        color: Colors.grey[400],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 사용자 정보
  Widget _buildUserInfo() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '작성자 정보',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          if (_review.isHeight != null && _review.isWeight != null)
            Row(
              children: [
                _buildInfoChip('키', '${_review.isHeight}cm'),
                const SizedBox(width: 8),
                _buildInfoChip('체중', '${_review.isWeight}kg'),
              ],
            ),
          if (_review.isOutageNum != null) ...[
            const SizedBox(height: 8),
            _buildInfoChip('감량', '-${_review.isOutageNum}kg', isHighlight: true),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlight 
            ? const Color(0xFFFF4081).withOpacity(0.1)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isHighlight ? const Color(0xFFFF4081) : Colors.black87,
        ),
      ),
    );
  }

  /// 하단 바 (도움이 돼요)
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _handleHelpful,
              icon: Icon(
                Icons.thumb_up,
                size: 20,
                color: _isLoading ? Colors.grey : const Color(0xFFFF4081),
              ),
              label: Text(
                '도움이 돼요 (${_review.isGood ?? 0})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _isLoading ? Colors.grey : const Color(0xFFFF4081),
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(
                  color: _isLoading ? Colors.grey[300]! : const Color(0xFFFF4081),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 도움이 돼요 처리
  Future<void> _handleHelpful() async {
    if (_review.isId == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ReviewService.incrementReviewHelpful(_review.isId!);

      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _review = ReviewModel(
              isId: _review.isId,
              itId: _review.itId,
              mbId: _review.mbId,
              isName: _review.isName,
              isTime: _review.isTime,
              isConfirm: _review.isConfirm,
              isScore1: _review.isScore1,
              isScore2: _review.isScore2,
              isScore3: _review.isScore3,
              isScore4: _review.isScore4,
              averageScore: _review.averageScore,
              isRvkind: _review.isRvkind,
              isRecommend: _review.isRecommend,
              isGood: result['isGood'] ?? (_review.isGood ?? 0) + 1,
              isPositiveReviewText: _review.isPositiveReviewText,
              isNegativeReviewText: _review.isNegativeReviewText,
              isMoreReviewText: _review.isMoreReviewText,
              images: _review.images,
              isBirthday: _review.isBirthday,
              isWeight: _review.isWeight,
              isHeight: _review.isHeight,
              isPayMthod: _review.isPayMthod,
              isOutageNum: _review.isOutageNum,
              odId: _review.odId,
            );
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('도움이 돼요를 눌렀습니다!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('처리 중 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
          ),
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
}

