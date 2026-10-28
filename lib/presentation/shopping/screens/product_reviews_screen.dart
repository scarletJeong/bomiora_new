import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../common/widgets/app_star_rating.dart';
import '../../common/widgets/centered_empty_state.dart';
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
  final String? fallbackImageUrl;

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
    this.fallbackImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = _sortPhotoFirst(reviews);
    final stats = PrescriptionReviewStats.fromReviews(sorted);
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
          PrescriptionReviewStatsCard(stats: stats),
          SizedBox(height: healthDp(context, 20)),
          if (guestLoginLocked && visible.isNotEmpty)
            _PrescriptionReviewGuestLock(onLogin: onGuestLoginTap)
          else if (visible.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: healthDp(context, 24)),
              child: CenteredEmptyState(
                iconWidget: CenteredEmptyState.assetIcon(
                  context,
                  AppAssets.emptyReviewIcon,
                ),
                message: '등록된 리뷰가 없습니다.',
              ),
            )
          else
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: ProductReviewListSection(
                reviews: visible,
                // 비대면 상세: 서포터/일반(비서포터) 모두 효과·가성비·맛향·편리함 표시
                showCategoryScores: true,
                showCouponSection: showCouponSection,
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
        SizedBox(height: healthDp(context, embedInParentScroll ? 48 : 56)),
      ],
    );

    if (embedInParentScroll) return content;
    return SingleChildScrollView(
      key: const PageStorageKey<String>('prescription_review_tab'),
      child: content,
    );
  }
}

/// 비로그인 의약품 후기 안내. 322×524 프레임 크기는 빼고, 안쪽 여백·글자·버튼만 맞춘다.
class _PrescriptionReviewGuestLock extends StatelessWidget {
  final VoidCallback? onLogin;

  const _PrescriptionReviewGuestLock({this.onLogin});

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF1A1A1E);
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 10),
          vertical: healthDp(context, 113),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            productDetailReviewLockBadge(context),
            SizedBox(height: healthDp(context, 14)),
            Text(
              '의료법에 의거하여 의약품 후기는',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: dark,
                fontSize: healthSp(context, 16),
                fontFamily: _kGmarket,
                fontWeight: FontWeight.w300,
              ),
            ),
            SizedBox(height: healthDp(context, 8)),
            Text(
              '로그인 후 확인이 가능합니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: dark,
                fontSize: healthSp(context, 16),
                fontFamily: _kGmarket,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: healthDp(context, 20)),
            Align(
              alignment: Alignment.center,
              child: Material(
                color: _kPink,
                borderRadius: BorderRadius.circular(healthDp(context, 50)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onLogin,
                  child: SizedBox(
                    height: healthDp(context, 40),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 18),
                      ),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          '로그인하기',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: healthSp(context, 16),
                            fontFamily: _kGmarket,
                            fontWeight: FontWeight.w500,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 비대면 리뷰 통계 — 평균 + 효과/가성비/맛향/편리함
class PrescriptionReviewStatsCard extends StatelessWidget {
  final PrescriptionReviewStats stats;

  const PrescriptionReviewStatsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final dividerHeight =
        healthDp(context, 50) + healthDp(context, 10) + healthDp(context, 15);
    return Padding(
      padding: EdgeInsets.only(
        left: healthDp(context, 30),
        right: healthDp(context, 20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                stats.average.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: healthSp(context, 50),
                  fontFamily: _kGmarket,
                  fontWeight: FontWeight.w700,
                  color: _kPink,
                  height: 1,
                ),
              ),
              SizedBox(height: healthDp(context, 10)),
              AppStarRating(
                rating: stats.average,
                starSize: healthDp(context, 18),
                gap: healthDp(context, 0),
                alignment: MainAxisAlignment.end,
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: healthDp(context, 12)),
            child: ColoredBox(
              color: const Color(0xFF666666),
              child: SizedBox(
                width: healthDp(context, 0.5),
                height: dividerHeight,
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _ratingBar(context, '효과', stats.score1Percent),
                SizedBox(height: healthDp(context, 5)),
                _ratingBar(context, '가성비', stats.score2Percent),
                SizedBox(height: healthDp(context, 5)),
                _ratingBar(context, '맛/향', stats.score3Percent),
                SizedBox(height: healthDp(context, 5)),
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
          width: healthDp(context, 42),
          child: Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: healthSp(context, 12),
              fontFamily: _kGmarket,
              fontWeight: FontWeight.w300,
              color: const Color(0xFF1A1A1E),
            ),
          ),
        ),
        SizedBox(width: healthDp(context, 6)),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: healthDp(context, 3),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(healthDp(context, 2)),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (percentage.clamp(0, 100)) / 100,
                child: Container(
                  height: healthDp(context, 3),
                  decoration: BoxDecoration(
                    color: _kPink,
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
            fontSize: healthSp(context, 12),
            fontFamily: _kGmarket,
            fontWeight: FontWeight.w300,
            color: const Color(0xFF1A1A1E),
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
