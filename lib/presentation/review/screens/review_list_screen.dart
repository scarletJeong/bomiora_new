import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/review/review_model.dart';
import '../../../data/services/review_service.dart';
import '../../common/widgets/centered_empty_state.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import 'review_detail_screen.dart';

/// 홈 「리뷰 더 보기」 — 서포터 / 사용자 리뷰 목록
class ReviewListScreen extends StatefulWidget {
  const ReviewListScreen({super.key});

  @override
  State<ReviewListScreen> createState() => _ReviewListScreenState();
}

class _ReviewListScreenState extends State<ReviewListScreen> {
  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _ink = Color(0xFF1A1A1E);
  static const Color _muted = Color(0xFF898686);
  static const Color _border = Color(0x7FD2D2D2);
  static const String _font = 'Gmarket Sans TTF';
  static const int _pageSize = 6;

  /// 0: 서포터, 1: 사용자(general)
  int _tabIndex = 0;
  int _page = 0;
  int _totalPages = 0;
  int _totalElements = 0;
  bool _loading = true;
  List<ReviewModel> _reviews = [];

  String get _rvkind => _tabIndex == 0 ? 'supporter' : 'general';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int page = 0}) async {
    setState(() {
      _loading = true;
      _page = page;
    });
    final result = await ReviewService.getAllReviews(
      rvkind: _rvkind,
      page: page,
      size: _pageSize,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _reviews = List<ReviewModel>.from(
          result['reviews'] as List<ReviewModel>? ?? const [],
        );
        _totalPages = _asInt(result['totalPages']);
        _totalElements = _asInt(result['totalElements']);
        _page = _asInt(result['currentPage'], fallback: page);
      } else {
        _reviews = [];
        _totalPages = 0;
        _totalElements = 0;
      }
    });
  }

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  void _onTab(int index) {
    if (_tabIndex == index) return;
    setState(() => _tabIndex = index);
    _load(page: 0);
  }

  void _openDetail(ReviewModel review) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReviewDetailScreen(
          review: review,
          fromProductDetail: false,
        ),
      ),
    );
  }

  _ListStats get _stats => _ListStats.fromReviews(_reviews);

  @override
  Widget build(BuildContext context) {
    final padH = healthDp(context, 27);

    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(
        title: '리뷰 페이지',
      ),
      child: _loading && _reviews.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: _pink,
              onRefresh: () => _load(page: _page),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  padH,
                  healthDp(context, 20),
                  padH,
                  healthDp(context, 40),
                ),
                children: [
                  _buildTabBar(context),
                  SizedBox(height: healthDp(context, 10)),
                  _buildCountRow(context),
                  SizedBox(height: healthDp(context, 10)),
                  _buildStatsCard(context),
                  SizedBox(height: healthDp(context, 20)),
                  if (_loading)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: healthDp(context, 40),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  else if (_reviews.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: healthDp(context, 40),
                      ),
                      child: CenteredEmptyState(
                        iconWidget: CenteredEmptyState.assetIcon(
                          context,
                          AppAssets.emptyProductReviewIcon,
                        ),
                        message: '등록된 리뷰가 없습니다.',
                      ),
                    )
                  else
                    _buildReviewGrid(context),
                  if (_totalPages > 1) ...[
                    SizedBox(height: healthDp(context, 20)),
                    _buildPagination(context),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: ShapeDecoration(
        color: const Color(0xFFF9F9F9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 20)),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _tabCell(context, 0, '서포터 리뷰')),
          Expanded(child: _tabCell(context, 1, '사용자 리뷰')),
        ],
      ),
    );
  }

  Widget _tabCell(BuildContext context, int index, String label) {
    final selected = _tabIndex == index;
    return GestureDetector(
      onTap: () => _onTab(index),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: healthDp(context, 10)),
        decoration: ShapeDecoration(
          color: selected ? Colors.white : Colors.transparent,
          shape: RoundedRectangleBorder(
            side: selected
                ? BorderSide(
                    width: healthDp(context, 0.5),
                    color: const Color(0x7F898686),
                  )
                : BorderSide.none,
            borderRadius: BorderRadius.circular(healthDp(context, 20)),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _ink : const Color(0x7F898686),
            fontSize: healthSp(context, 14),
            fontFamily: _font,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCountRow(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: healthDp(context, 1),
          color: _border,
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: healthDp(context, 5)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '전체리뷰 ',
                    style: TextStyle(
                      color: _muted,
                      fontSize: healthSp(context, 12),
                      fontFamily: _font,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: '$_totalElements ',
                    style: TextStyle(
                      color: _pink,
                      fontSize: healthSp(context, 12),
                      fontFamily: _font,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: '개',
                    style: TextStyle(
                      color: _muted,
                      fontSize: healthSp(context, 12),
                      fontFamily: _font,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          height: healthDp(context, 1),
          color: _border,
        ),
      ],
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    final stats = _stats;
    final avgText = stats.average <= 0
        ? '0'
        : (stats.average * 10).round() % 10 == 0
            ? stats.average.toStringAsFixed(0)
            : stats.average.toStringAsFixed(1);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 10)),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _border),
          borderRadius: BorderRadius.circular(healthDp(context, 20)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: healthDp(context, 82),
            child: Text(
              avgText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _pink,
                fontSize: healthSp(context, 50),
                fontFamily: _font,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
          SizedBox(width: healthDp(context, 16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _statPercentRow(context, '효과', stats.score1Percent),
                SizedBox(height: healthDp(context, 8)),
                _statPercentRow(context, '가성비', stats.score2Percent),
                SizedBox(height: healthDp(context, 8)),
                _statPercentRow(context, '맛/향', stats.score3Percent),
                SizedBox(height: healthDp(context, 8)),
                _statPercentRow(context, '편리함', stats.score4Percent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statPercentRow(BuildContext context, String label, int percent) {
    return Row(
      children: [
        SizedBox(
          width: healthDp(context, 48),
          child: Text(
            label,
            style: TextStyle(
              color: _ink,
              fontSize: healthSp(context, 12),
              fontFamily: _font,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(healthDp(context, 4)),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: healthDp(context, 6),
              backgroundColor: const Color(0xFFF6F6F6),
              color: _pink,
            ),
          ),
        ),
        SizedBox(width: healthDp(context, 8)),
        Text(
          '$percent%',
          style: TextStyle(
            color: _ink,
            fontSize: healthSp(context, 12),
            fontFamily: _font,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewGrid(BuildContext context) {
    final gap = healthDp(context, 10);
    final cardH = healthDp(context, 200);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = (constraints.maxWidth - gap) / 2;
        final rows = <Widget>[];
        for (var i = 0; i < _reviews.length; i += 2) {
          final left = _reviews[i];
          final right = i + 1 < _reviews.length ? _reviews[i + 1] : null;
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: cardW,
                  height: cardH,
                  child: _ReviewGridCard(
                    review: left,
                    showSupporterBadge: _tabIndex == 0,
                    onTap: () => _openDetail(left),
                  ),
                ),
                SizedBox(width: gap),
                SizedBox(
                  width: cardW,
                  height: cardH,
                  child: right == null
                      ? const SizedBox.shrink()
                      : _ReviewGridCard(
                          review: right,
                          showSupporterBadge: _tabIndex == 0,
                          onTap: () => _openDetail(right),
                        ),
                ),
              ],
            ),
          );
          if (i + 2 < _reviews.length) {
            rows.add(SizedBox(height: gap));
          }
        }
        return Column(children: rows);
      },
    );
  }

  Widget _buildPagination(BuildContext context) {
    final maxShow = 5;
    var start = (_page - (maxShow ~/ 2)).clamp(0, (_totalPages - maxShow).clamp(0, _totalPages));
    var end = (start + maxShow).clamp(0, _totalPages);
    if (end - start < maxShow && _totalPages >= maxShow) {
      start = (end - maxShow).clamp(0, _totalPages);
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: healthDp(context, 1),
          color: _border,
        ),
        SizedBox(height: healthDp(context, 5)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _pageIconBtn(
              context,
              icon: Icons.chevron_left,
              enabled: _page > 0,
              onTap: () => _load(page: _page - 1),
            ),
            for (var p = start; p < end; p++)
              _pageNumBtn(context, p, selected: p == _page),
            _pageIconBtn(
              context,
              icon: Icons.chevron_right,
              enabled: _page < _totalPages - 1,
              onTap: () => _load(page: _page + 1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pageIconBtn(
    BuildContext context, {
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: healthDp(context, 30),
        height: healthDp(context, 30),
        child: Icon(
          icon,
          size: healthDp(context, 20),
          color: enabled ? _ink : const Color(0x7F898686),
        ),
      ),
    );
  }

  Widget _pageNumBtn(BuildContext context, int page, {required bool selected}) {
    return GestureDetector(
      onTap: selected ? null : () => _load(page: page),
      child: Container(
        width: healthDp(context, 30),
        height: healthDp(context, 30),
        margin: EdgeInsets.symmetric(horizontal: healthDp(context, 2)),
        alignment: Alignment.center,
        decoration: selected
            ? ShapeDecoration(
                color: const Color(0xCCFF5A8D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 7)),
                ),
              )
            : null,
        child: Text(
          '${page + 1}',
          style: TextStyle(
            color: selected ? Colors.white : const Color(0x7F898686),
            fontSize: healthSp(context, 14),
            fontFamily: _font,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ListStats {
  final double average;
  final int score1Percent;
  final int score2Percent;
  final int score3Percent;
  final int score4Percent;

  const _ListStats({
    required this.average,
    required this.score1Percent,
    required this.score2Percent,
    required this.score3Percent,
    required this.score4Percent,
  });

  factory _ListStats.fromReviews(List<ReviewModel> reviews) {
    if (reviews.isEmpty) {
      return const _ListStats(
        average: 0,
        score1Percent: 0,
        score2Percent: 0,
        score3Percent: 0,
        score4Percent: 0,
      );
    }

    double avgOf(double Function(ReviewModel) pick) {
      return reviews.map(pick).reduce((a, b) => a + b) / reviews.length;
    }

    double displayAvg(ReviewModel r) => r.averageScore ?? 0;

    return _ListStats(
      average: avgOf(displayAvg),
      score1Percent: (avgOf((r) => r.score1) * 20).round(),
      score2Percent: (avgOf((r) => r.score2) * 20).round(),
      score3Percent: (avgOf((r) => r.score3) * 20).round(),
      score4Percent: (avgOf((r) => r.score4) * 20).round(),
    );
  }
}

class _ReviewGridCard extends StatelessWidget {
  final ReviewModel review;
  final bool showSupporterBadge;
  final VoidCallback onTap;

  const _ReviewGridCard({
    required this.review,
    required this.showSupporterBadge,
    required this.onTap,
  });

  String get _name {
    final n = review.isName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return '회원';
  }

  String get _body {
    final p = review.isPositiveReviewText?.trim();
    if (p != null && p.isNotEmpty) return p;
    final m = review.isMoreReviewText?.trim();
    if (m != null && m.isNotEmpty) return m;
    final n = review.isNegativeReviewText?.trim();
    if (n != null && n.isNotEmpty) return n;
    return '';
  }

  double get _score => review.averageScore ?? 0;

  String? get _imageUrl {
    if (review.images.isNotEmpty) {
      return ImageUrlHelper.getReviewImageUrl(review.images.first);
    }
    final product = review.productImage?.trim();
    if (product != null && product.isNotEmpty) {
      return ImageUrlHelper.getImageUrl(product);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final radius = healthDp(context, 10);
    final scoreText = _score <= 0
        ? '0.0'
        : ((_score * 10).round() % 10 == 0
            ? _score.toStringAsFixed(1)
            : _score.toStringAsFixed(1));

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_imageUrl != null)
              Image.network(
                _imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFFE0E0E0)),
              )
            else
              const ColoredBox(color: Color(0xFFE0E0E0)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(0.5, 0),
                  end: const Alignment(0.5, 0.69),
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    const Color(0x00FF96B6),
                    const Color(0x7FFF5A8D),
                  ],
                ),
              ),
            ),
            if (showSupporterBadge)
              Positioned(
                top: healthDp(context, 6),
                right: healthDp(context, 6),
                child: Column(
                  children: [
                    Text(
                      '서포터',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: healthSp(context, 8),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                        shadows: const [
                          Shadow(blurRadius: 3, color: Color(0x66000000)),
                        ],
                      ),
                    ),
                    Text(
                      '리뷰어',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: healthSp(context, 8),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                        shadows: const [
                          Shadow(blurRadius: 3, color: Color(0x66000000)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Positioned(
              left: healthDp(context, 5),
              right: healthDp(context, 5),
              bottom: healthDp(context, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: healthSp(context, 14),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '★ $scoreText',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: healthSp(context, 9.4),
                          fontFamily: 'Noto Sans KR',
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: healthDp(context, 8)),
                  Text(
                    _body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: healthSp(context, 10),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                      height: 1.38,
                    ),
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
