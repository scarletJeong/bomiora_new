import 'package:flutter/material.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../../data/models/review/review_model.dart';

class ProductNormalReview extends StatelessWidget {
  final List<ReviewModel> reviews;
  final bool isLoading;
  final int visibleCount;
  final VoidCallback onLoadMore;
  final ValueChanged<ReviewModel> onReviewTap;
  final bool guestLoginLocked;
  final VoidCallback? onGuestLoginTap;
  /// true: (처방약 리뷰) 효과/가성비/맛/향/편리함 항목 표시
  /// false: (일반상품 리뷰) 항목 없이 총점/별점만 표시
  final bool showCategoryScores;

  const ProductNormalReview({
    super.key,
    required this.reviews,
    required this.isLoading,
    required this.visibleCount,
    required this.onLoadMore,
    required this.onReviewTap,
    this.guestLoginLocked = false,
    this.onGuestLoginTap,
    this.showCategoryScores = true,
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
      key: const PageStorageKey<String>('normal_review_tab'),
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
            _NormalStatsCard(stats: stats, showCategoryScores: showCategoryScores),
            const SizedBox(height: 14),
            if (visibleReviews.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _GuestAwareReviewGridNormal(
                  guestLoginLocked: guestLoginLocked,
                  onGuestLoginTap: onGuestLoginTap,
                  itemCount: visibleReviews.length,
                  onReviewTap: onReviewTap,
                  visibleReviews: visibleReviews,
                  showCategoryScores: showCategoryScores,
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
                      backgroundColor: const Color(0xFFFF4081),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFFF4081)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      '+ 더보기',
                      style: TextStyle(
                        fontSize: healthSp(context, 17.54),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 56),
        ],
      ),
    );
  }
}

class _NormalStatsCard extends StatelessWidget {
  final _ReviewStats stats;
  final bool showCategoryScores;

  const _NormalStatsCard({
    required this.stats,
    required this.showCategoryScores,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            '전체 리뷰 평가',
            style: TextStyle(
              fontSize: healthSp(context, 15.54),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              color: const Color(0xFFFF5A8D),
            ),
          ),
          const SizedBox(height: 12),
          if (showCategoryScores)
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
                        style: TextStyle(
                          fontSize: healthSp(context, 48.73),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFF5A8D),
                          height: 0.95,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildStars(context, stats.average),
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
                      _ratingBar(context, '효과', stats.score1Percent),
                      const SizedBox(height: 8),
                      _ratingBar(context, '가성비', stats.score2Percent),
                      const SizedBox(height: 8),
                      _ratingBar(context, '맛/향', stats.score3Percent),
                      const SizedBox(height: 8),
                      _ratingBar(context, '편리함', stats.score4Percent),
                    ],
                  ),
                ),
              ],
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stats.average.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: healthSp(context, 50),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFF5A95),
                    height: 0.95,
                  ),
                ),
                const SizedBox(height: 6),
                _buildStars(context, stats.average),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '만족 ${stats.satisfiedCount}건',
                      style: TextStyle(
                        fontSize: healthSp(context, 12),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '/',
                      style: TextStyle(
                        fontSize: healthSp(context, 12),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                        color: const Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '불만족 ${stats.dissatisfiedCount}건',
                      style: TextStyle(
                        fontSize: healthSp(context, 12),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
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
          width: 34,
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
    final starSize = healthDp(context, 14);
    return Row(
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
          color: const Color(0xFFFFCC00).withOpacity(0.25),
          size: starSize,
        );
      }),
    );
  }
}

class _ReviewGridCard extends StatelessWidget {
  final ReviewModel review;
  final VoidCallback onTap;
  final bool showCategoryScores;

  const _ReviewGridCard({
    required this.review,
    required this.onTap,
    required this.showCategoryScores,
  });

  @override
  Widget build(BuildContext context) {
    final total = review.totalIsScore ?? review.averageScore ?? 0.0;
    final score1 = review.score1;
    final score2 = review.score2;
    final score3 = review.score3;
    final score4 = review.score4;

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final imageH = constraints.maxHeight * 0.58;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: imageH,
                  width: constraints.maxWidth,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                    child: review.images.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(10)),
                            child: Image.network(
                              ImageUrlHelper.getReviewImageUrl(
                                  review.images.first),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(
                                    Icons.rate_review,
                                    size: healthDp(context, 32),
                                    color: Colors.grey[400],
                                  ),
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.rate_review,
                              size: healthDp(context, 32),
                              color: Colors.grey[400],
                            ),
                          ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final h = constraints.maxHeight;
                        final compact = h < 92;
                        final tiny = h < 78;

                        Widget ratingBox({
                          required bool compact,
                          required double rowMaxWidth,
                        }) {
                          final narrow = rowMaxWidth < 178;
                          final scoreFontRaw = narrow
                              ? 16.0
                              : (compact ? 19.0 : 22.0);
                          final barFontRaw =
                              narrow ? 12.0 : (compact ? 18.0 : 22.0);
                          final scoreFont = healthSp(context, scoreFontRaw);
                          final barFont = healthSp(context, barFontRaw);
                          final scoreW = narrow ? 34.0 : (compact ? 38.0 : 44.0);
                          final gap = narrow ? 3.0 : 5.0;
                          final miniGap =
                              narrow ? 6.0 : (compact ? 8.0 : 10.0);

                          Widget categoryScores() {
                            if (!compact) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _ScoreMini(
                                        label: '효과',
                                        value: score1,
                                        labelWidth: narrow ? 28 : 32,
                                      ),
                                      SizedBox(width: miniGap),
                                      _ScoreMini(label: '가성비', value: score2),
                                    ],
                                  ),
                                  SizedBox(height: narrow ? 3 : 5),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _ScoreMini(
                                        label: '맛/향',
                                        value: score3,
                                        labelWidth: narrow ? 28 : 32,
                                      ),
                                      SizedBox(width: miniGap),
                                      _ScoreMini(label: '편리함', value: score4),
                                    ],
                                  ),
                                ],
                              );
                            }
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ScoreMini(label: '효과', value: score1),
                                SizedBox(width: narrow ? 5 : 8),
                                _ScoreMini(label: '가성비', value: score2),
                              ],
                            );
                          }

                          Widget rightBlock() {
                            final starSz = healthDp(context, 14);
                            if (!showCategoryScores) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(5, (index) {
                                  final starIndex = index + 1;
                                  if (total >= starIndex) {
                                    return Icon(
                                      Icons.star,
                                      color: const Color(0xFFFFCC00),
                                      size: starSz,
                                    );
                                  }
                                  if (total >= starIndex - 0.5) {
                                    return Icon(
                                      Icons.star_half,
                                      color: const Color(0xFFFFCC00),
                                      size: starSz,
                                    );
                                  }
                                  return Icon(
                                    Icons.star,
                                    color: const Color(0xFFFFCC00)
                                        .withValues(alpha: 0.25),
                                    size: starSz,
                                  );
                                }),
                              );
                            }
                            return categoryScores();
                          }

                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: narrow ? 4 : 5,
                              vertical: compact ? 4 : 8,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  width: 0.50,
                                  color: Color(0xFFFF5A8D),
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: scoreW,
                                  height: compact ? 22 : 26,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      total.toStringAsFixed(1),
                                      style: TextStyle(
                                        color: const Color(0xFFFF5A8D),
                                        fontSize: scoreFont,
                                        fontFamily: 'Gmarket Sans TTF',
                                        fontWeight: FontWeight.w700,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: gap),
                                Text(
                                  '|',
                                  style: TextStyle(
                                    color: const Color(0xFF666666),
                                    fontSize: barFont,
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                                SizedBox(width: gap),
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: rightBlock(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '| ${review.isName ?? '익명'}',
                                    style: TextStyle(
                                      fontSize: healthSp(context, 14),
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: review.isPositiveReviewText != null &&
                                        review
                                            .isPositiveReviewText!.isNotEmpty
                                    ? Text(
                                        review.isPositiveReviewText!,
                                        style: TextStyle(
                                          fontSize: healthSp(context, 8.77),
                                          color: Colors.black87,
                                          height: 1.35,
                                        ),
                                        maxLines: tiny ? 1 : 2,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                            if (!tiny)
                              ratingBox(
                                compact: compact,
                                rowMaxWidth: constraints.maxWidth,
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScoreMini extends StatelessWidget {
  final String label;
  final int value;
  final double? labelWidth;

  const _ScoreMini({
    required this.label,
    required this.value,
    this.labelWidth,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      color: Colors.black,
      fontSize: healthSp(context, 9),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w300,
    );
    final labelWidget = Text(
      label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
      textAlign: labelWidth != null ? TextAlign.right : TextAlign.left,
      style: labelStyle,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labelWidth != null)
          SizedBox(
            width: labelWidth,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: labelWidth != null
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: labelWidget,
            ),
          )
        else
          labelWidget,
        const SizedBox(width: 3),
        Icon(
          Icons.star,
          size: healthDp(context, 10),
          color: const Color(0xFFFFCC00),
        ),
        const SizedBox(width: 1),
        Text(
          value.toString(),
          style: TextStyle(
            color: Colors.black,
            fontSize: healthSp(context, 9),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}

class _GuestAwareReviewGridNormal extends StatelessWidget {
  final bool guestLoginLocked;
  final VoidCallback? onGuestLoginTap;
  final int itemCount;
  final ValueChanged<ReviewModel> onReviewTap;
  final List<ReviewModel> visibleReviews;
  final bool showCategoryScores;

  const _GuestAwareReviewGridNormal({
    required this.guestLoginLocked,
    required this.onGuestLoginTap,
    required this.itemCount,
    required this.onReviewTap,
    required this.visibleReviews,
    required this.showCategoryScores,
  });

  @override
  Widget build(BuildContext context) {
    final grid = GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: healthDp(context, 12),
        mainAxisSpacing: healthDp(context, 16),
        childAspectRatio: 0.58,
      ),
      itemBuilder: (context, index) {
        return _ReviewGridCard(
          review: visibleReviews[index],
          onTap: () => onReviewTap(visibleReviews[index]),
          showCategoryScores: showCategoryScores,
        );
      },
    );

    if (!guestLoginLocked) return grid;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AbsorbPointer(absorbing: true, child: grid),
        Positioned.fill(
          child: Material(
            color: Colors.white.withValues(alpha: 0.72),
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5A8D),
                        ),
                        child: Text(
                          '로그인 후 확인이 가능합니다',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: healthSp(context, 15),
                            height: 1.45,
                            color: Colors.white,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: SizedBox(
                        width: 200,
                        child: ElevatedButton(
                          onPressed: onGuestLoginTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF4081),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            '로그인 하기',
                            style: TextStyle(
                              fontSize: healthSp(context, 16),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Gmarket Sans TTF',
                            ),
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

class _ReviewStats {
  final double average;
  final int score1Percent;
  final int score2Percent;
  final int score3Percent;
  final int score4Percent;
  final int satisfiedCount;
  final int dissatisfiedCount;

  const _ReviewStats({
    required this.average,
    required this.score1Percent,
    required this.score2Percent,
    required this.score3Percent,
    required this.score4Percent,
    required this.satisfiedCount,
    required this.dissatisfiedCount,
  });

  factory _ReviewStats.fromReviews(List<ReviewModel> reviews) {
    if (reviews.isEmpty) {
      return const _ReviewStats(
        average: 0,
        score1Percent: 0,
        score2Percent: 0,
        score3Percent: 0,
        score4Percent: 0,
        satisfiedCount: 0,
        dissatisfiedCount: 0,
      );
    }
    final scoreValues = reviews
        .map((r) => r.totalIsScore ?? r.averageScore)
        .whereType<double>()
        .toList();
    final average = scoreValues.isEmpty
        ? 0.0
        : scoreValues.reduce((a, b) => a + b) / scoreValues.length;

    final satisfiedCount = reviews.where((r) => r.isRecommend == 'y').length;
    final dissatisfiedCount = reviews.where((r) => r.isRecommend == 'n').length;

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
      satisfiedCount: satisfiedCount,
      dissatisfiedCount: dissatisfiedCount,
    );
  }
}
