import 'package:flutter/material.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../../data/models/review/review_model.dart';

class ProductSupportReview extends StatelessWidget {
  final List<ReviewModel> reviews;
  final bool isLoading;
  final int visibleCount;
  final VoidCallback onLoadMore;
  final ValueChanged<ReviewModel> onReviewTap;
  /// true면 별점 카드는 그대로 두고, 그리드만 반투명 + 로그인 안내
  final bool guestLoginLocked;
  final VoidCallback? onGuestLoginTap;

  const ProductSupportReview({
    super.key,
    required this.reviews,
    required this.isLoading,
    required this.visibleCount,
    required this.onLoadMore,
    required this.onReviewTap,
    this.guestLoginLocked = false,
    this.onGuestLoginTap,
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
                child: _GuestAwareReviewGrid(
                  guestLoginLocked: guestLoginLocked,
                  onGuestLoginTap: onGuestLoginTap,
                  itemCount: visibleReviews.length,
                  onReviewTap: onReviewTap,
                  visibleReviews: visibleReviews,
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
                      style: const TextStyle(
                        fontSize: 17.54,
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            '서포터즈 리뷰 평가',
            style: TextStyle(
              fontSize: 15.59,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              color: Color(0xFFFF5A8D),
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
                        fontSize: 48.73,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF5A8D),
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
            style: TextStyle(fontSize: 11, fontFamily: 'Gmarket Sans TTF', fontWeight: FontWeight.w300, color: Colors.black),
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
          style: TextStyle(fontSize: 11, fontFamily: 'Gmarket Sans TTF', fontWeight: FontWeight.w300, color: Colors.black),
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
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // 높이가 낮아질수록 별점박스는 축소/간소화해서
                        // "이름 + 리뷰 텍스트" 영역이 사라지지 않게 우선권을 줌.
                        final h = constraints.maxHeight;
                        final compact = h < 92;
                        final tiny = h < 78;

                        Widget ratingBox({
                          required bool compact,
                          required double rowMaxWidth,
                        }) {
                          final narrow = rowMaxWidth < 178;
                          final scoreFont = narrow
                              ? 16.0
                              : (compact ? 19.0 : 22.0);
                          final barFont = narrow ? 12.0 : (compact ? 18.0 : 22.0);
                          final scoreW = narrow ? 34.0 : (compact ? 38.0 : 44.0);
                          final gap = narrow ? 3.0 : 5.0;
                          final miniGap =
                              narrow ? 6.0 : (compact ? 8.0 : 10.0);

                          Widget scoreBlock() {
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
                                    child: scoreBlock(),
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
                                    style: const TextStyle(
                                      fontSize: 15.59,
                                      fontFamily: 'Gmarket Sans TTF',
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
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
                                        style: const TextStyle(
                                          fontSize: 8.77,
                                          fontFamily: 'Gmarket Sans TTF',
                                          color: Colors.black,
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
    final labelStyle = const TextStyle(
      color: Colors.black,
      fontSize: 9,
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
        const Icon(
          Icons.star,
          size: 10,
          color: Color(0xFFFFCC00),
        ),
        const SizedBox(width: 1),
        Text(
          value.toString(),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 9,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}

class _GuestAwareReviewGrid extends StatelessWidget {
  final bool guestLoginLocked;
  final VoidCallback? onGuestLoginTap;
  final int itemCount;
  final ValueChanged<ReviewModel> onReviewTap;
  final List<ReviewModel> visibleReviews;

  const _GuestAwareReviewGrid({
    required this.guestLoginLocked,
    required this.onGuestLoginTap,
    required this.itemCount,
    required this.onReviewTap,
    required this.visibleReviews,
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
                        fontSize: 15,
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
                            vertical: 1, horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5A8D),
                        ),
                        child: const Text(
                          '로그인 후 확인이 가능합니다',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
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
                          child: const Text(
                            '로그인 하기',
                            style: TextStyle(
                              fontSize: 16,
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
