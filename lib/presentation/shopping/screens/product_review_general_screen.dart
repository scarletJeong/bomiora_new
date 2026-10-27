import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../common/widgets/app_star_rating.dart';
import '../../../core/constants/app_assets.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../../data/models/review/review_model.dart';
import '../widgets/product_review_list_card.dart';

const _kGmarket = 'Gmarket Sans TTF';
const _kPink = Color(0xFFFF5A8D);

/// 일반 상품 상세 리뷰 탭 본문 (통합 평점만)
class GeneralReviewTabPanel extends StatelessWidget {
  final List<ReviewModel> reviews;
  final bool isLoading;
  final int visibleCount;
  final VoidCallback onLoadMore;
  final ValueChanged<ReviewModel> onReviewTap;
  final bool guestLoginLocked;
  final VoidCallback? onGuestLoginTap;
  final bool embedInParentScroll;
  final bool showCouponSection;
  final String? fallbackImageUrl;

  const GeneralReviewTabPanel({
    super.key,
    required this.reviews,
    required this.isLoading,
    required this.visibleCount,
    required this.onLoadMore,
    required this.onReviewTap,
    this.guestLoginLocked = false,
    this.onGuestLoginTap,
    this.embedInParentScroll = false,
    this.showCouponSection = false,
    this.fallbackImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = _sortPhotoFirst(reviews);
    final average = GeneralReviewStats.averageOf(sorted);
    final capped =
        visibleCount > sorted.length ? sorted.length : visibleCount;
    final visible = sorted.take(capped).toList();
    final hPad = healthDp(context, 20);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: healthDp(context, 20)),
        if (isLoading)
          Padding(
            padding: EdgeInsets.all(healthDp(context, 32)),
            child: const Center(child: CircularProgressIndicator()),
          )
        else ...[
          GeneralReviewStatsCard(average: average),
          SizedBox(height: healthDp(context, 14)),
          if (visible.isEmpty)
            const _GeneralReviewEmpty()
          else
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: ProductReviewListSection(
                reviews: visible,
                showCategoryScores: false,
                showCouponSection: showCouponSection,
                guestLoginLocked: guestLoginLocked,
                onGuestLoginTap: onGuestLoginTap,
                onReviewTap: onReviewTap,
                fallbackImageUrl: fallbackImageUrl,
              ),
            ),
          if (!guestLoginLocked && capped < sorted.length)
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, healthDp(context, 48), hPad, 0),
              child: ProductReviewLoadMoreButton(
                onPressed: onLoadMore,
                neutral: true,
              ),
            ),
        ],
        SizedBox(height: healthDp(context, embedInParentScroll ? 20 : 56)),
      ],
    );

    if (embedInParentScroll) return content;
    return SingleChildScrollView(
      key: const PageStorageKey<String>('general_review_tab'),
      child: content,
    );
  }
}

/// 일반 상품 리뷰 통계 — 통합 평점 + 별 아이콘
class GeneralReviewStatsCard extends StatelessWidget {
  final double average;

  const GeneralReviewStatsCard({super.key, required this.average});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
        Text(
          average.toStringAsFixed(1),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _kPink,
            fontSize: healthSp(context, 50),
            fontFamily: _kGmarket,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        SizedBox(height: healthDp(context, 10)),
        AppStarRating(
          rating: average,
          starSize: healthDp(context, 20),
          gap: healthDp(context, 0),
          alignment: MainAxisAlignment.center,
        ),
      ],
      ),
    );
  }
}

class GeneralReviewStats {
  GeneralReviewStats._();

  static double averageOf(List<ReviewModel> reviews) {
    if (reviews.isEmpty) return 0;
    final scores = reviews
        .map((r) => r.averageScore ?? 0)
        .where((s) => s > 0)
        .toList();
    if (scores.isEmpty) return 0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }
}

List<ReviewModel> _sortPhotoFirst(List<ReviewModel> reviews) {
  final sorted = List<ReviewModel>.from(reviews)
    ..sort((a, b) {
      final aHas = a.images.isNotEmpty;
      final bHas = b.images.isNotEmpty;
      if (aHas && !bHas) return -1;
      if (!aHas && bHas) return 1;
      return 0;
    });
  return sorted;
}

class _GeneralReviewEmpty extends StatelessWidget {
  const _GeneralReviewEmpty();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: healthDp(context, 50)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          SizedBox(
            width: healthDp(context, 80),
            height: healthDp(context, 80),
            child: SvgPicture.asset(
              AppAssets.emptyReviewIcon,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          Text(
            '등록된 리뷰가 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFFC0C0C0),
              fontSize: healthSp(context, 14),
              fontFamily: _kGmarket,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        ),
      ),
    );
  }
}
