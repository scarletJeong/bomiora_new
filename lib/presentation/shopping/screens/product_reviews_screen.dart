import 'package:flutter/material.dart';

import '../../common/widgets/app_star_rating.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../../data/models/review/review_model.dart';
import '../widgets/product_review_list_card.dart';

const _kGmarket = 'Gmarket Sans TTF';
const _kPink = Color(0xFFFF5A8D);

/// 비대면 상세 리뷰 탭 본문 (효과·가성비·맛향·편리함 통계)
class PrescriptionReviewTabPanel extends StatelessWidget {
  final List<ReviewModel> reviews;
  final bool isLoading;
  final int visibleCount;
  final VoidCallback onLoadMore;
  final ValueChanged<ReviewModel> onReviewTap;
  final bool guestLoginLocked;
  final VoidCallback? onGuestLoginTap;
  final bool embedInParentScroll;
  final bool showCouponSection;

  const PrescriptionReviewTabPanel({
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
  });

  @override
  Widget build(BuildContext context) {
    final sorted = _sortPhotoFirst(reviews);
    final stats = PrescriptionReviewStats.fromReviews(sorted);
    final capped =
        visibleCount > sorted.length ? sorted.length : visibleCount;
    final visible = sorted.take(capped).toList();
    final hPad = healthDp(context, 27);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: healthDp(context, 16)),
        if (isLoading)
          Padding(
            padding: EdgeInsets.all(healthDp(context, 32)),
            child: const Center(child: CircularProgressIndicator()),
          )
        else ...[
          PrescriptionReviewStatsCard(stats: stats),
          SizedBox(height: healthDp(context, 14)),
          if (visible.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: ProductReviewListSection(
                reviews: visible,
                // 비대면 상세: 서포터/일반(비서포터) 모두 효과·가성비·맛향·편리함 표시
                showCategoryScores: true,
                showCouponSection: showCouponSection,
                guestLoginLocked: guestLoginLocked,
                onGuestLoginTap: onGuestLoginTap,
                onReviewTap: onReviewTap,
              ),
            ),
          if (!guestLoginLocked && capped < sorted.length)
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, healthDp(context, 48), hPad, 0),
              child: ProductReviewLoadMoreButton(onPressed: onLoadMore),
            ),
        ],
        SizedBox(height: healthDp(context, embedInParentScroll ? 20 : 56)),
      ],
    );

    if (embedInParentScroll) return content;
    return SingleChildScrollView(
      key: const PageStorageKey<String>('prescription_review_tab'),
      child: content,
    );
  }
}

/// 비대면 리뷰 통계 — 평균 + 효과/가성비/맛향/편리함
class PrescriptionReviewStatsCard extends StatelessWidget {
  final PrescriptionReviewStats stats;

  const PrescriptionReviewStatsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: healthDp(context, 16)),
      padding: EdgeInsets.all(healthDp(context, 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(healthDp(context, 8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: healthDp(context, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  stats.average.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: healthSp(context, 48.73),
                    fontFamily: _kGmarket,
                    fontWeight: FontWeight.w700,
                    color: _kPink,
                    height: 0.95,
                  ),
                ),
                SizedBox(height: healthDp(context, 4)),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AppStarRating(
                      rating: stats.average,
                      starSize: healthDp(context, 20),
                      alignment: MainAxisAlignment.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: healthDp(context, 84),
            color: Colors.grey[300],
            margin: EdgeInsets.symmetric(horizontal: healthDp(context, 12)),
          ),
          Expanded(
            child: Column(
              children: [
                _ratingBar(context, '효과', stats.score1Percent),
                SizedBox(height: healthDp(context, 8)),
                _ratingBar(context, '가성비', stats.score2Percent),
                SizedBox(height: healthDp(context, 8)),
                _ratingBar(context, '맛/향', stats.score3Percent),
                SizedBox(height: healthDp(context, 8)),
                _ratingBar(context, '편리함', stats.score4Percent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingBar(BuildContext context, String label, int percentage) {
    return Row(
      children: [
        SizedBox(
          width: healthDp(context, 34),
          child: Text(
            label,
            style: TextStyle(
              fontSize: healthSp(context, 11),
              fontFamily: _kGmarket,
              fontWeight: FontWeight.w300,
              color: Colors.black,
            ),
          ),
        ),
        SizedBox(width: healthDp(context, 6)),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: healthDp(context, 4),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(healthDp(context, 2)),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (percentage.clamp(0, 100)) / 100,
                child: Container(
                  height: healthDp(context, 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5A95),
                    borderRadius: BorderRadius.circular(healthDp(context, 2)),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: healthDp(context, 8)),
        Text(
          '$percentage%',
          style: TextStyle(
            fontSize: healthSp(context, 11),
            fontFamily: _kGmarket,
            fontWeight: FontWeight.w300,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

class PrescriptionReviewStats {
  final double average;
  final int score1Percent;
  final int score2Percent;
  final int score3Percent;
  final int score4Percent;

  const PrescriptionReviewStats({
    required this.average,
    required this.score1Percent,
    required this.score2Percent,
    required this.score3Percent,
    required this.score4Percent,
  });

  factory PrescriptionReviewStats.fromReviews(List<ReviewModel> reviews) {
    if (reviews.isEmpty) {
      return const PrescriptionReviewStats(
        average: 0,
        score1Percent: 0,
        score2Percent: 0,
        score3Percent: 0,
        score4Percent: 0,
      );
    }
    final withScore = reviews.where((r) => r.averageScore != null).toList();
    final average = withScore.isEmpty
        ? 0.0
        : withScore.map((r) => r.averageScore!).reduce((a, b) => a + b) /
            withScore.length;

    double avgScore(double Function(ReviewModel) pick) =>
        reviews.map(pick).reduce((a, b) => a + b) / reviews.length;

    return PrescriptionReviewStats(
      average: average,
      score1Percent: (avgScore((r) => r.score1) * 20).round(),
      score2Percent: (avgScore((r) => r.score2) * 20).round(),
      score3Percent: (avgScore((r) => r.score3) * 20).round(),
      score4Percent: (avgScore((r) => r.score4) * 20).round(),
    );
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
