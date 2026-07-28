import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/review/review_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/coupon_service.dart';
import '../../common/widgets/app_star_rating.dart';
import '../../health/health_common/health_responsive_scale.dart';

const _kGmarket = 'Gmarket Sans TTF';
const _kPink = Color(0xFFFF5A8D);
const _kTextDark = Color(0xFF1A1A1E);
const _kMuted = Color(0xFF898686);

/// 상품 상세·리뷰 목록 공통 1열 리뷰 카드 (기본 접힘, 탭 시 펼침)
class ProductReviewListCard extends StatefulWidget {
  final ReviewModel review;
  final bool showCouponSection;
  /// null 이면 리뷰 종류(is_rvkind)로 판단. 일반 상품 화면에서는 false 고정.
  final bool? showCategoryScores;
  final VoidCallback? onOpenDetail;
  final VoidCallback? onGuestLoginTap;

  const ProductReviewListCard({
    super.key,
    required this.review,
    this.showCouponSection = false,
    this.showCategoryScores,
    this.onOpenDetail,
    this.onGuestLoginTap,
  });

  @override
  State<ProductReviewListCard> createState() => _ProductReviewListCardState();
}

class _ProductReviewListCardState extends State<ProductReviewListCard> {
  bool _expanded = false;
  int _imageIndex = 0;
  PageController? _imagePageController;

  @override
  void dispose() {
    _imagePageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final imageH = healthDp(context, 321);
    final radius = healthDp(context, 10);
    final total = review.averageScore ?? 0.0;
    final imageCount = _reviewImageCount(review);
    final isGeneral = review.isGeneralReview;
    final showCategoryScores =
        widget.showCategoryScores ?? !isGeneral;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: SizedBox(
                width: double.infinity,
                height: imageH,
                child: _buildImage(review, imageH, imageCount),
              ),
            ),
            if (review.isSupporterReview)
              Positioned(
                left: healthDp(context, 8),
                top: healthDp(context, 8),
                child: _SupporterBadge(),
              ),
            if (imageCount > 1) ...[
              Positioned(
                left: healthDp(context, 4),
                top: 0,
                bottom: 0,
                child: Center(
                  child: _ReviewImageNavButton(
                    icon: Icons.chevron_left,
                    enabled: _imageIndex > 0,
                    onTap: () => _imagePageController?.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: healthDp(context, 4),
                top: 0,
                bottom: 0,
                child: Center(
                  child: _ReviewImageNavButton(
                    icon: Icons.chevron_right,
                    enabled: _imageIndex < imageCount - 1,
                    onTap: () => _imagePageController?.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (imageCount > 1) ...[
          SizedBox(height: healthDp(context, 8)),
          _ImageDots(
            count: imageCount,
            index: _imageIndex,
          ),
        ],
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: healthDp(context, 10)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '|',
                    style: TextStyle(
                      color: _kTextDark,
                      fontSize: healthSp(context, 16),
                      fontFamily: _kGmarket,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: healthDp(context, 6)),
                  Flexible(
                    child: Text(
                      review.isName ?? '익명',
                      style: TextStyle(
                        color: _kTextDark,
                        fontSize: healthSp(context, 16),
                        fontFamily: _kGmarket,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: healthDp(context, 10)),
              _ReviewTextBlock(
                text: review.isPositiveReviewText,
                expanded: _expanded,
                collapsedMaxLines: 2,
              ),
              SizedBox(height: healthDp(context, 10)),
              _RatingScorePanel(
                total: total,
                score1: review.score1,
                score2: review.score2,
                score3: review.score3,
                score4: review.score4,
                showCategoryScores: showCategoryScores,
              ),
              if (widget.showCouponSection) ...[
                _CouponHelpSection(
                  review: review,
                  onGuestLoginTap: widget.onGuestLoginTap,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  int _reviewImageCount(ReviewModel review) {
    if (review.images.isNotEmpty) return review.images.length;
    final fallback = review.productImage;
    return fallback != null && fallback.isNotEmpty ? 1 : 0;
  }

  Widget _buildImage(ReviewModel review, double imageH, int imageCount) {
    if (imageCount == 0) {
      return _imagePlaceholder(imageH);
    }

    if (imageCount == 1) {
      final url = review.images.isNotEmpty
          ? ImageUrlHelper.getReviewImageUrl(review.images.first)
          : ImageUrlHelper.convertToLocalUrl(review.productImage!);
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: imageH,
        errorBuilder: (_, __, ___) => _imagePlaceholder(imageH),
      );
    }

    _imagePageController ??= PageController();

    return PageView.builder(
      controller: _imagePageController,
      itemCount: imageCount,
      physics: const PageScrollPhysics(),
      onPageChanged: (i) => setState(() => _imageIndex = i),
      itemBuilder: (context, index) {
        return Image.network(
          ImageUrlHelper.getReviewImageUrl(review.images[index]),
          fit: BoxFit.cover,
          width: double.infinity,
          height: imageH,
          errorBuilder: (_, __, ___) => _imagePlaceholder(imageH),
        );
      },
    );
  }

  Widget _imagePlaceholder(double imageH) {
    return Container(
      width: double.infinity,
      height: imageH,
      color: Colors.grey[200],
      child: Icon(
        Icons.rate_review,
        size: healthDp(context, 40),
        color: Colors.grey[400],
      ),
    );
  }
}

class _SupporterBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 6),
        vertical: healthDp(context, 4),
      ),
      decoration: BoxDecoration(
        color: _kPink,
        borderRadius: BorderRadius.circular(healthDp(context, 4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '서포터',
            style: TextStyle(
              color: Colors.white,
              fontSize: healthSp(context, 8),
              fontFamily: _kGmarket,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          Text(
            '리뷰어',
            style: TextStyle(
              color: Colors.white,
              fontSize: healthSp(context, 8),
              fontFamily: _kGmarket,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewImageNavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _ReviewImageNavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconSz = healthDp(context, 20);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Container(
          padding: EdgeInsets.all(healthDp(context, 6)),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: enabled ? 0.92 : 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: iconSz,
            color: enabled ? Colors.black87 : Colors.black38,
          ),
        ),
      ),
    );
  }
}

class _ImageDots extends StatelessWidget {
  final int count;
  final int index;

  const _ImageDots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return Container(
          width: healthDp(context, active ? 10 : 5),
          height: healthDp(context, active ? 3 : 5),
          margin: EdgeInsets.symmetric(horizontal: healthDp(context, 2.5)),
          decoration: BoxDecoration(
            color: active ? _kPink : const Color(0xFFD2D2D2),
            borderRadius: BorderRadius.circular(healthDp(context, 20)),
          ),
        );
      }),
    );
  }
}

class _ReviewTextBlock extends StatelessWidget {
  final String? text;
  final bool expanded;
  final int collapsedMaxLines;

  const _ReviewTextBlock({
    required this.text,
    required this.expanded,
    this.collapsedMaxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final value = text?.trim() ?? '';
    if (value.isEmpty) return const SizedBox.shrink();

    return Text(
      value,
      style: TextStyle(
        color: _kTextDark,
        fontSize: healthSp(context, 12),
        fontFamily: _kGmarket,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      maxLines: expanded ? null : collapsedMaxLines,
      overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
    );
  }
}

class _RatingScorePanel extends StatelessWidget {
  final double total;
  final double score1;
  final double score2;
  final double score3;
  final double score4;
  final bool showCategoryScores;

  const _RatingScorePanel({
    required this.total,
    required this.score1,
    required this.score2,
    required this.score3,
    required this.score4,
    this.showCategoryScores = true,
  });

  @override
  Widget build(BuildContext context) {
    final border = BorderSide(
      width: healthDp(context, 0.5),
      color: _kPink,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 10),
        vertical: healthDp(context, 8),
      ),
      decoration: BoxDecoration(
        border: Border(
          top: border,
          bottom: border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            total <= 0
                ? '0'
                : ((total * 10).round() % 10 == 0
                    ? total.toStringAsFixed(0)
                    : total.toStringAsFixed(1)),
            style: TextStyle(
              color: _kPink,
              fontSize: healthSp(context, 20),
              fontFamily: _kGmarket,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (showCategoryScores) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
              child: Text(
                '|',
                style: TextStyle(
                  color: const Color(0xFF666666),
                  fontSize: healthSp(context, 18),
                  fontFamily: _kGmarket,
                  fontWeight: FontWeight.w300,
                  height: 1,
                ),
              ),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ScoreChip(label: '효과', value: score1),
                        SizedBox(width: healthDp(context, 10)),
                        _ScoreChip(label: '가성비', value: score2),
                      ],
                    ),
                    SizedBox(width: healthDp(context, 10)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ScoreChip(label: '맛/향', value: score3),
                        SizedBox(width: healthDp(context, 10)),
                        _ScoreChip(label: '편리함', value: score4),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            SizedBox(width: healthDp(context, 8)),
            AppStarRating(
              rating: total,
              starSize: healthDp(context, 16),
              gap: healthDp(context, 2),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final double value;

  const _ScoreChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: _kTextDark,
            fontSize: healthSp(context, 12),
            fontFamily: _kGmarket,
            fontWeight: FontWeight.w300,
          ),
        ),
        SizedBox(width: healthDp(context, 3)),
        AppStarIcon(size: healthDp(context, 10)),
        SizedBox(width: healthDp(context, 1)),
        Text(
          value.round().clamp(0, 5).toString(),
          style: TextStyle(
            color: _kTextDark,
            fontSize: healthSp(context, 10),
            fontFamily: _kGmarket,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}

class _CouponHelpSection extends StatefulWidget {
  final ReviewModel review;
  final VoidCallback? onGuestLoginTap;

  const _CouponHelpSection({
    required this.review,
    this.onGuestLoginTap,
  });

  @override
  State<_CouponHelpSection> createState() => _CouponHelpSectionState();
}

class _CouponHelpSectionState extends State<_CouponHelpSection> {
  late int _downloadCount;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _downloadCount = widget.review.czDownload ?? 0;
  }

  @override
  void didUpdateWidget(covariant _CouponHelpSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.review.isId != widget.review.isId) {
      _downloadCount = widget.review.czDownload ?? 0;
    }
  }

  Future<void> _onDownloadTap() async {
    if (_isDownloading || widget.review.isId == null) return;

    final user = await AuthService.getUser();
    if (!mounted) return;
    if (user == null) {
      if (widget.onGuestLoginTap != null) {
        widget.onGuestLoginTap!();
      } else {
        Navigator.pushNamed(context, '/login');
      }
      return;
    }

    setState(() => _isDownloading = true);
    try {
      final result = await CouponService.downloadHelpCoupon(
        mbId: user.id,
        itId: widget.review.itId,
        isId: widget.review.isId!,
      );
      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          final next = result['downloadCount'];
          if (next is int) {
            _downloadCount = next;
          } else {
            _downloadCount += 1;
          }
        });
        final message = result['message'] as String?;
        if (message != null && message.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      } else {
        final message =
            result['message'] as String? ?? '쿠폰 다운로드에 실패했습니다.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('쿠폰 다운로드 중 오류가 발생했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 10),
        vertical: healthDp(context, 5),
      ),
      decoration: BoxDecoration(
        color: const Color(0x14FF5A8D),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(healthDp(context, 7)),
          bottomRight: Radius.circular(healthDp(context, 7)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SvgPicture.asset(
                      AppAssets.myReviewCouponIcon,
                      width: healthDp(context, 20),
                      height: healthDp(context, 20),
                      fit: BoxFit.contain,
                    ),
                    SizedBox(width: healthDp(context, 5)),
                    Text(
                      '5% 할인 도움 쿠폰',
                      style: TextStyle(
                        color: _kPink,
                        fontSize: healthSp(context, 14),
                        fontFamily: _kGmarket,
                        fontWeight: FontWeight.w700,
                        letterSpacing: healthSp(context, -0.42),
                      ),
                    ),
                    SizedBox(width: healthDp(context, 10)),
                    Flexible(
                      child: Text.rich(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$_downloadCount',
                              style: TextStyle(
                                color: _kPink,
                                fontSize: healthSp(context, 12),
                                fontFamily: _kGmarket,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextSpan(
                              text: '명이 받았어요!',
                              style: TextStyle(
                                color: _kMuted,
                                fontSize: healthSp(context, 12),
                                fontFamily: _kGmarket,
                                fontWeight: FontWeight.w500,
                                letterSpacing: healthSp(context, -0.36),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: healthDp(context, 4)),
                Text(
                  '유효기간 : 발급일로부터 7일',
                  style: TextStyle(
                    color: _kTextDark,
                    fontSize: healthSp(context, 10),
                    fontFamily: _kGmarket,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _isDownloading ? null : _onDownloadTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: healthDp(context, 40),
                height: healthDp(context, 40),
                child: _isDownloading
                    ? Padding(
                        padding: EdgeInsets.all(healthDp(context, 10)),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _kPink,
                        ),
                      )
                    : SvgPicture.asset(
                        AppAssets.myReviewCouponCardDownload,
                        width: healthDp(context, 40),
                        height: healthDp(context, 40),
                        fit: BoxFit.contain,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// + 더보기 버튼
class ProductReviewLoadMoreButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ProductReviewLoadMoreButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: healthDp(context, 40),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPink,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.all(healthDp(context, 10)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
          ),
        ),
        child: Text(
          '+ 더보기',
          style: TextStyle(
            fontSize: healthSp(context, 16),
            fontFamily: _kGmarket,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 1열 리뷰 목록 (게스트 잠금 오버레이 포함)
class ProductReviewListSection extends StatelessWidget {
  final List<ReviewModel> reviews;
  final bool showCouponSection;
  final bool? showCategoryScores;
  final bool guestLoginLocked;
  final VoidCallback? onGuestLoginTap;
  final ValueChanged<ReviewModel>? onReviewTap;

  const ProductReviewListSection({
    super.key,
    required this.reviews,
    this.showCouponSection = false,
    this.showCategoryScores,
    this.guestLoginLocked = false,
    this.onGuestLoginTap,
    this.onReviewTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const SizedBox.shrink();

    // 게스트 잠금 시 첫 카드 부근에서 안내가 보이도록 최대 3개만 노출
    final displayReviews =
        guestLoginLocked ? reviews.take(3).toList() : reviews;

    final list = Column(
      children: [
        for (var i = 0; i < displayReviews.length; i++) ...[
          if (i > 0) SizedBox(height: healthDp(context, 48)),
          ProductReviewListCard(
            review: displayReviews[i],
            showCouponSection: showCouponSection,
            showCategoryScores: showCategoryScores,
            onGuestLoginTap: onGuestLoginTap,
            onOpenDetail: onReviewTap != null
                ? () => onReviewTap!(displayReviews[i])
                : null,
          ),
        ],
      ],
    );

    if (!guestLoginLocked) return list;

    return Stack(
      children: [
        AbsorbPointer(absorbing: true, child: list),
        Positioned.fill(
          child: Material(
            color: Colors.white.withValues(alpha: 0.72),
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  healthDp(context, 20),
                  healthDp(context, 120),
                  healthDp(context, 20),
                  healthDp(context, 20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '의료법에 의거하여 의약품 후기는',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: healthSp(context, 15),
                        height: 1.45,
                        color: Colors.grey[800],
                        fontFamily: _kGmarket,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: healthDp(context, 8)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 8),
                        vertical: healthDp(context, 4),
                      ),
                      color: _kPink,
                      child: Text(
                        '로그인 후 확인이 가능합니다',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: healthSp(context, 15),
                          color: Colors.white,
                          fontFamily: _kGmarket,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(height: healthDp(context, 24)),
                    SizedBox(
                      width: healthDp(context, 200),
                      child: ElevatedButton(
                        onPressed: onGuestLoginTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4081),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: healthDp(context, 12),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(healthDp(context, 8)),
                          ),
                        ),
                        child: Text(
                          '로그인 하기',
                          style: TextStyle(
                            fontSize: healthSp(context, 16),
                            fontWeight: FontWeight.w500,
                            fontFamily: _kGmarket,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
