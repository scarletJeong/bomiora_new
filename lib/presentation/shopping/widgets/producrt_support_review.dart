import 'package:flutter/material.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/review/review_model.dart';

class ProductSupportReview extends StatelessWidget {
  final List<ReviewModel> reviews;
  final bool isLoading;
  final int visibleCount;
  final VoidCallback onLoadMore;
  final ValueChanged<ReviewModel> onReviewTap;

  const ProductSupportReview({
    super.key,
    required this.reviews,
    required this.isLoading,
    required this.visibleCount,
    required this.onLoadMore,
    required this.onReviewTap,
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

    return SingleChildScrollView(
      key: const PageStorageKey<String>('support_review_tab'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _SupportStatsCard(stats: stats),
            const SizedBox(height: 14),
            if (visibleReviews.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visibleReviews.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemBuilder: (context, index) {
                    return _ReviewGridCard(
                      review: visibleReviews[index],
                      onTap: () => onReviewTap(visibleReviews[index]),
                    );
                  },
                ),
              ),
            if (cappedCount < sorted.length)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onLoadMore,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFFF4081)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      '리뷰 더보기',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF4081),
                      ),
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _SupportStatsCard extends StatelessWidget {
  final _ReviewStats stats;

  const _SupportStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            '서포터 리뷰 평가',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFFFF5A95),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      stats.average.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF5A95),
                        height: 0.95,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildStars(stats.average),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 84,
                color: Colors.grey[300],
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Expanded(
                child: Column(
                  children: [
                    _ratingBar('효과', stats.score1Percent),
                    const SizedBox(height: 8),
                    _ratingBar('가성비', stats.score2Percent),
                    const SizedBox(height: 8),
                    _ratingBar('맛/향', stats.score3Percent),
                    const SizedBox(height: 8),
                    _ratingBar('편리함', stats.score4Percent),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ratingBar(String label, int percentage) {
    return Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[700]),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percentage / 100,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5A95),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$percentage%',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildStars(double average) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        if (average >= starIndex) {
          return const Icon(Icons.star, color: Color(0xFFFFCC00), size: 14);
        }
        if (average >= starIndex - 0.5) {
          return const Icon(Icons.star_half,
              color: Color(0xFFFFCC00), size: 14);
        }
        return Icon(
          Icons.star,
          color: const Color(0xFFFFCC00).withOpacity(0.25),
          size: 14,
        );
      }),
    );
  }
}

class _ReviewGridCard extends StatelessWidget {
  final ReviewModel review;
  final VoidCallback onTap;

  const _ReviewGridCard({
    required this.review,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            Container(
              width: double.infinity,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: review.images.isNotEmpty
                  ? ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(10)),
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
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  if (review.isPositiveReviewText != null &&
                      review.isPositiveReviewText!.isNotEmpty)
                    Text(
                      review.isPositiveReviewText!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
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
