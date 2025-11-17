import 'package:flutter/material.dart';
import 'dart:convert';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../../data/models/review/review_model.dart';
import '../../../data/services/review_service.dart';
import '../../../data/services/coupon_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/snackbar_utils.dart';
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
  bool _hasUserHelpful = false; // 사용자가 이미 추천했는지

  @override
  void initState() {
    super.initState();
    _review = widget.review;
    _checkUserHelpful();
  }
  
  /// 사용자가 이미 추천했는지 확인
  Future<void> _checkUserHelpful() async {
    if (_review.isId == null || _review.isGeneralReview == false) return;
    
    try {
      final user = await AuthService.getUser();
      if (user == null) return;
      
      final response = await ApiClient.get(
        '/api/user/reviews/${_review.isId}/helpful/check?mbId=${user.id}&itId=${_review.itId}',
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _hasUserHelpful = data['hasHelpful'] == true;
          });
        }
      }
    } catch (e) {
      print('❌ 추천 여부 확인 에러: $e');
    }
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
              
              // 추천 섹션 (일반: 도움이 돼요, 서포터: 도움쿠폰)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                color: Colors.white,
                child: _review.isGeneralReview
                    ? Center(
                        child: SizedBox(
                          width: double.infinity,
                          child: _buildHelpfulButton(),
                        ),
                      )
                    : _buildHelpCouponBanner(),
              ),
              
              // 이미지
              if (_review.images.isNotEmpty) _buildImageSection(),
              
              // 사용자 정보
              if (_review.isWeight != null || _review.isHeight != null)
                _buildUserInfo(),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
        bottomNavigationBar: _buildProductBottomBar(),
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
                    // 서포터 뱃지
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
                    // 일반 리뷰: 내돈내산 또는 평가단 뱃지
                    if (_review.isGeneralReview && _review.isPayMthod != null) ...[
                      if (_review.isPayMthod == 'solo')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '내돈내산',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      if (_review.isPayMthod == 'group')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '평가단',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                    ],
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
            Text(
                _review.isMoreReviewText!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.6,
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

  /// 도움 쿠폰 배너
  Widget _buildHelpCouponBanner() {
    final downloadCount = _review.czDownload ?? 0;
    
    return InkWell(
      onTap: _downloadHelpCoupon,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F5), // 연한 핑크 배경
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFFFB3D9), // 핑크 점선 느낌
            width: 0.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Row(
          children: [
            // 쿠폰 아이콘
            const Icon(
              Icons.local_offer,
              color: Color(0xFFFF4081),
              size: 24,
            ),
            const SizedBox(width: 12),
            // 쿠폰 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '■ 5% 할인 도움쿠폰',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF4081),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$downloadCount명이 받았어요 · 유효기간 7일',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFFF7AAD),
                    ),
                  ),
                ],
              ),
            ),
            // 다운로드 버튼
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4081),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.download,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 도움 쿠폰 다운로드
  Future<void> _downloadHelpCoupon() async {
    if (_review.isId == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      // 현재 사용자 정보 가져오기
      final user = await AuthService.getUser();
      if (user == null) {
        if (mounted) {
          SnackBarUtils.showError(context, '로그인이 필요합니다.');
        }
        return;
      }
      
      // 도움쿠폰 다운로드 API 호출
      final result = await CouponService.downloadHelpCoupon(
        mbId: user.id,
        itId: _review.itId,
        isId: _review.isId!,
      );
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        // 성공 시 다운로드 카운트 업데이트
        setState(() {
          _review = ReviewModel(
            isId: _review.isId,
            itId: _review.itId,
            itName: _review.itName,
            mbId: _review.mbId,
            isName: _review.isName,
            isTime: _review.isTime,
            isConfirm: _review.isConfirm,
            isScore1: _review.isScore1,
            isScore2: _review.isScore2,
            isScore3: _review.isScore3,
            isScore4: _review.isScore4,
            isRvkind: _review.isRvkind,
            isRecommend: _review.isRecommend,
            isGood: _review.isGood,
            czDownload: result['downloadCount'] ?? 0,
            isPositiveReviewText: _review.isPositiveReviewText,
            isNegativeReviewText: _review.isNegativeReviewText,
            isMoreReviewText: _review.isMoreReviewText,
            images: _review.images,
            isHeight: _review.isHeight,
            isWeight: _review.isWeight,
            isPayMthod: _review.isPayMthod,
            isOutageNum: _review.isOutageNum,
            odId: _review.odId,
          );
        });
        
        SnackBarUtils.showSuccess(context, result['message'] ?? '쿠폰이 발급되었습니다.');
      } else {
        SnackBarUtils.showError(context, result['message'] ?? '쿠폰 다운로드에 실패했습니다.');
      }
    } catch (e) {
      print('❌ 도움쿠폰 다운로드 에러: $e');
      if (mounted) {
        SnackBarUtils.showError(context, '쿠폰 다운로드 중 오류가 발생했습니다.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 도움이 돼요 버튼
  Widget _buildHelpfulButton() {
    // 이미 추천했으면 비활성화
    final isDisabled = _isLoading || _hasUserHelpful;
    
    return OutlinedButton.icon(
      onPressed: isDisabled ? null : _handleHelpful,
      icon: Icon(
        _hasUserHelpful ? Icons.thumb_up : Icons.thumb_up_outlined,
        size: 20,
        color: isDisabled ? Colors.grey : const Color(0xFFFF4081),
      ),
      label: Text(
        _hasUserHelpful ? '추천했어요 (${_review.isGood ?? 0})' : '도움이 돼요 (${_review.isGood ?? 0})',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDisabled ? Colors.grey : const Color(0xFFFF4081),
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(
          color: isDisabled ? Colors.grey[300]! : const Color(0xFFFF4081),
        ),
        backgroundColor: _hasUserHelpful ? const Color(0xFFFF4081).withOpacity(0.05) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// 하단 바 (제품 보러가기로 변경)
  Widget _buildProductBottomBar() {
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
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/product/${_review.itId}',
          );
        },
        icon: const Icon(Icons.shopping_bag_outlined, size: 20),
        label: const Text(
          '이 제품 보러가기',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF3787),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
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
      // 현재 사용자 정보 가져오기
      final user = await AuthService.getUser();
      if (user == null) {
        if (mounted) {
          SnackBarUtils.showError(context, '로그인이 필요합니다.');
        }
        setState(() => _isLoading = false);
        return;
      }
      
      final result = await ReviewService.incrementReviewHelpful(_review.isId!, user.id);

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

          setState(() {
            _hasUserHelpful = true; // 추천 상태 업데이트
          });
          SnackBarUtils.showSuccess(context, '추천했어요');
        } else {
          // 중복 클릭 시
          SnackBarUtils.showWarning(context, result['message'] ?? '이미 추천 하신 리뷰 입니다.');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, '처리 중 오류가 발생했습니다.');
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

