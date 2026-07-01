import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';
import '../../../data/models/review/review_model.dart';
import 'product_review_list_card.dart';

class ProductSupportReview extends StatelessWidget {
  final List<ReviewModel> reviews;
  final bool isLoading;
  final int visibleCount;
  final VoidCallback onLoadMore;
  final ValueChanged<ReviewModel> onReviewTap;
  final bool guestLoginLocked;
  final VoidCallback? onGuestLoginTap;
  final bool embedInParentScroll;

  const ProductSupportReview({
    super.key,
    required this.reviews,
    required this.isLoading,
    required this.visibleCount,
    required this.onLoadMore,
    required this.onReviewTap,
    this.guestLoginLocked = false,
    this.onGuestLoginTap,
    this.embedInParentScroll = false,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<ReviewModel>.from(reviews)
      ..sort((a, b) {
        final aHasPhoto = a.images.isNotEmpty;
        final bHasPhoto = b.images.isNotEmpty;
        if (aHasPhoto && !bHasPhoto) return -1;
        if (!aHasPhoto && bHasPhoto) return 1;
        return 0;
      });
    final stats = _ReviewStats.fromReviews(sorted);
    final cappedCount =
        visibleCount > sorted.length ? sorted.length : visibleCount;
    final visibleReviews = sorted.take(cappedCount).toList();
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
          _SupportStatsCard(stats: stats),
          SizedBox(height: healthDp(context, 14)),
          if (visibleReviews.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: ProductReviewListSection(
                reviews: visibleReviews,
                showCouponSection: true,
                guestLoginLocked: guestLoginLocked,
                onGuestLoginTap: onGuestLoginTap,
                onReviewTap: onReviewTap,
              ),
            ),
          if (cappedCount < sorted.length)
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
      key: const PageStorageKey<String>('support_review_tab'),
      child: content,
    );
  }
}

class _SupportStatsCard extends StatelessWidget {
  final _ReviewStats stats;

  const _SupportStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: healthDp(context, 16)),
      padding: EdgeInsets.all(healthDp(context, 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(healthDp(context, 8)),
      ),
      child: Column(
        children: [
          Row(
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
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFF5A8D),
                        height: 0.95,
                      ),
                    ),
                    SizedBox(height: healthDp(context, 4)),
                    _buildStars(context, stats.average),
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
              fontFamily: 'Gmarket Sans TTF',
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
                widthFactor: percentage / 100,
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
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildStars(BuildContext context, double average) {
    final starSize = healthDp(context, 20);
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starIndex = index + 1;
            if (average >= starIndex) {
              return Icon(Icons.star,
                  color: const Color(0xFFFFCC00), size: starSize);
            }
            if (average >= starIndex - 0.5) {
              return Icon(Icons.star_half,
                  color: const Color(0xFFFFCC00), size: starSize);
            }
            return Icon(
              Icons.star,
              color: const Color(0xFFFFCC00).withValues(alpha: 0.25),
              size: starSize,
            );
          }),
        ),
      ),
    );
  }
}

class _ReviewStats {
  final double average;
  final int score1Percent;
  final int score2Percent;
  final int score3Percent;
  final int score4Percent;

  const _ReviewStats({
    required this.average,
    required this.score1Percent,
    required this.score2Percent,
    required this.score3Percent,
    required this.score4Percent,
  });

  factory _ReviewStats.fromReviews(List<ReviewModel> reviews) {
    if (reviews.isEmpty) {
      return const _ReviewStats(
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

    double avgScore(int Function(ReviewModel) pick) {
      return reviews.map((r) => pick(r).toDouble()).reduce((a, b) => a + b) /
          reviews.length;
    }

    return _ReviewStats(
      average: average,
      score1Percent: (avgScore((r) => r.score1) * 20).round(),
      score2Percent: (avgScore((r) => r.score2) * 20).round(),
      score3Percent: (avgScore((r) => r.score3) * 20).round(),
      score4Percent: (avgScore((r) => r.score4) * 20).round(),
    );
  }
}
