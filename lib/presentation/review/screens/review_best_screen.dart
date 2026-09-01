import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/review/main_home_review_model.dart';
import '../../../data/services/review_service.dart';
import '../../common/widgets/app_star_rating.dart';
import '../../common/widgets/centered_empty_state.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';

/// 홈 BEST 리뷰 — `bomiora_main_review` 목록 (펼침만, 상세 페이지 없음)
class ReviewBestScreen extends StatefulWidget {
  /// 홈 카드에서 진입 시 해당 리뷰로 스크롤·펼침
  final int? initialMrNo;

  const ReviewBestScreen({super.key, this.initialMrNo});

  @override
  State<ReviewBestScreen> createState() => _ReviewBestScreenState();
}

class _ReviewBestScreenState extends State<ReviewBestScreen> {
  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _ink = Color(0xFF1A1A1E);
  static const Color _muted = Color(0xFF898686);
  static const Color _border = Color(0x7FD2D2D2);
  static const String _font = 'Gmarket Sans TTF';
  static const int _pageSize = 5;

  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};

  int _page = 0;
  int _totalPages = 0;
  int _totalElements = 0;
  bool _loading = true;
  List<MainHomeReviewModel> _reviews = [];
  MainReviewStats _stats = const MainReviewStats();
  int? _expandedMrNo;
  bool _didScrollToInitial = false;

  @override
  void initState() {
    super.initState();
    _expandedMrNo = widget.initialMrNo;
    _load(page: 0, focusMrNo: widget.initialMrNo);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int mrNo) =>
      _itemKeys.putIfAbsent(mrNo, () => GlobalKey());

  Future<void> _load({required int page, int? focusMrNo}) async {
    setState(() {
      _loading = true;
      _page = page;
      _didScrollToInitial = false;
    });
    final result = await ReviewService.getMainHomeReviewsBest(
      page: page,
      size: _pageSize,
      mrNo: focusMrNo,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _reviews = List<MainHomeReviewModel>.from(
          result['reviews'] as List<MainHomeReviewModel>? ?? const [],
        );
        _totalPages = _asInt(result['totalPages']);
        _totalElements = _asInt(result['totalElements']);
        _page = _asInt(result['currentPage'], fallback: page);
        _stats = result['stats'] is MainReviewStats
            ? result['stats'] as MainReviewStats
            : const MainReviewStats();
      } else {
        _reviews = [];
        _totalPages = 0;
        _totalElements = 0;
      }
    });

    final target = focusMrNo ?? widget.initialMrNo;
    if (target != null && target > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToMrNo(target);
      });
    }
  }

  /// 헤더(카운트+통계) + 카드(이미지 320 등) 대략 높이 — healthDp 기준
  double _estimateOffsetForIndex(BuildContext context, int index) {
    final header = healthDp(context, 200);
    final item = healthDp(context, 520);
    return header + (index * item);
  }

  Future<void> _scrollToMrNo(int mrNo) async {
    if (!mounted || _didScrollToInitial) return;
    final index = _reviews.indexWhere((r) => r.mrNo == mrNo);
    if (index < 0) return;

    // ListView는 화면 밖 자식을 아직 mount 하지 않아 key.context 가 null일 수 있음.
    // 예상 오프셋으로 먼저 이동해 해당 카드를 빌드한 뒤 ensureVisible.
    if (_scrollController.hasClients) {
      final estimated = _estimateOffsetForIndex(context, index);
      final max = _scrollController.position.maxScrollExtent;
      final target = estimated.clamp(0.0, max);
      _scrollController.jumpTo(target);
    }

    for (var attempt = 0; attempt < 8; attempt++) {
      if (!mounted) return;
      await Future<void>.delayed(
        Duration(milliseconds: attempt == 0 ? 16 : 60),
      );
      if (!mounted || _didScrollToInitial) return;

      final ctx = _itemKeys[mrNo]?.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          alignment: 0.08,
        );
        _didScrollToInitial = true;
        return;
      }

      // 아직 없으면 조금 더 내려 빌드 유도
      if (_scrollController.hasClients) {
        final step = healthDp(context, 280);
        final next = (_scrollController.offset + step)
            .clamp(0.0, _scrollController.position.maxScrollExtent);
        _scrollController.jumpTo(next);
      }
    }
  }

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  void _toggleExpand(int mrNo) {
    setState(() {
      _expandedMrNo = _expandedMrNo == mrNo ? null : mrNo;
    });
  }

  String _avgText(double avg) {
    if (avg <= 0) return '0';
    if ((avg * 10).round() % 10 == 0) return avg.toStringAsFixed(0);
    return avg.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final padH = healthDp(context, 27);

    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(
        title: '베스트 리뷰',
      ),
      child: _loading && _reviews.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _pink))
          : RefreshIndicator(
              color: _pink,
              onRefresh: () => _load(page: _page),
              child: ListView(
                controller: _scrollController,
                // 페이지당 소수 카드 — 화면 밖 카드도 미리 빌드해 스크롤 타겟 키 확보
                cacheExtent: 5000,
                padding: EdgeInsets.fromLTRB(
                  padH,
                  healthDp(context, 0),
                  padH,
                  healthDp(context, 40),
                ),
                children: [
                  _buildCountRow(context),
                  SizedBox(height: healthDp(context, 10)),
                  _buildStatsCard(context),
                  SizedBox(height: healthDp(context, 20)),
                  if (_loading)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: healthDp(context, 20),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: _pink),
                      ),
                    )
                  else if (_reviews.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: healthDp(context, 48),
                      ),
                      child: CenteredEmptyState(
                        iconWidget: CenteredEmptyState.assetIcon(
                          context,
                          AppAssets.emptyProductReviewIcon,
                        ),
                        message: '등록된 베스트 리뷰가 없습니다.',
                      ),
                    )
                  else
                    ..._buildReviewItems(context),
                  if (_totalPages > 1) ...[
                    SizedBox(height: healthDp(context, 24)),
                    _buildPagination(context),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildCountRow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: healthDp(context, 1),
          color: _border,
        ),
        SizedBox(height: healthDp(context, 5)),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '전체 ',
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
        SizedBox(height: healthDp(context, 5)),
        Container(
          width: double.infinity,
          height: healthDp(context, 1),
          color: _border,
        ),
      ],
    );
  }

  /// 점수(0~5)에 맞춰 둥근 노랑 별 행
  Widget _starRow(BuildContext context, double score, {double size = 14}) {
    return AppStarRating(
      rating: score,
      starSize: healthDp(context, size),
      gap: healthDp(context, 1),
      alignment: MainAxisAlignment.center,
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    final avgText = _avgText(_stats.averageScore);
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
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
                SizedBox(height: healthDp(context, 8)),
                _starRow(context, _stats.averageScore, size: 14),
              ],
            ),
          ),
          SizedBox(width: healthDp(context, 16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _statPercentRow(context, '효과', _stats.score1Percent),
                SizedBox(height: healthDp(context, 8)),
                _statPercentRow(context, '가성비', _stats.score2Percent),
                SizedBox(height: healthDp(context, 8)),
                _statPercentRow(context, '맛/향', _stats.score3Percent),
                SizedBox(height: healthDp(context, 8)),
                _statPercentRow(context, '편리함', _stats.score4Percent),
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

  List<Widget> _buildReviewItems(BuildContext context) {
    final widgets = <Widget>[];
    for (var i = 0; i < _reviews.length; i++) {
      final r = _reviews[i];
      widgets.add(
        KeyedSubtree(
          key: _keyFor(r.mrNo),
          child: _BestReviewCard(
            review: r,
            expanded: _expandedMrNo == r.mrNo,
            onTap: () => _toggleExpand(r.mrNo),
          ),
        ),
      );
      if (i < _reviews.length - 1) {
        widgets.add(SizedBox(height: healthDp(context, 48)));
      }
    }
    return widgets;
  }

  Widget _buildPagination(BuildContext context) {
    const maxShow = 5;
    var start =
        (_page - (maxShow ~/ 2)).clamp(0, (_totalPages - maxShow).clamp(0, _totalPages));
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
          color: enabled ? _ink : _muted.withValues(alpha: 0.5),
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
        decoration: ShapeDecoration(
          color: selected ? const Color(0xCCFF5A8D) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 7)),
          ),
        ),
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

class _BestReviewCard extends StatefulWidget {
  final MainHomeReviewModel review;
  final bool expanded;
  final VoidCallback onTap;

  const _BestReviewCard({
    required this.review,
    required this.expanded,
    required this.onTap,
  });

  @override
  State<_BestReviewCard> createState() => _BestReviewCardState();
}

class _BestReviewCardState extends State<_BestReviewCard> {
  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _ink = Color(0xFF1A1A1E);
  static const String _font = 'Gmarket Sans TTF';

  final PageController _pageController = PageController();
  int _imageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<String> get _imageUrls {
    final urls = <String>[];
    for (final raw in widget.review.images) {
      final u = ImageUrlHelper.getMainReviewImageUrl(raw);
      if (u.isNotEmpty && !urls.contains(u)) urls.add(u);
    }
    if (urls.isEmpty) {
      final p = widget.review.productImage?.trim();
      if (p != null && p.isNotEmpty) {
        urls.add(ImageUrlHelper.getImageUrl(p));
      }
    }
    return urls;
  }

  String get _avgText {
    final avg = widget.review.displayAverage;
    if (avg <= 0) return '0';
    if ((avg * 10).round() % 10 == 0) return avg.toStringAsFixed(0);
    return avg.toStringAsFixed(1);
  }

  int _scoreInt(double v) => v.round().clamp(0, 5);

  @override
  Widget build(BuildContext context) {
    final images = _imageUrls;
    final summaryOrContent = widget.expanded
        ? widget.review.fullBodyText
        : widget.review.bodyText;
    final title = widget.review.mrTitle?.trim() ?? '';
    final imageSize = healthDp(context, 320);

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(healthDp(context, 10)),
                child: SizedBox(
                  width: double.infinity,
                  height: imageSize,
                  child: images.isEmpty
                      ? const ColoredBox(color: Color(0xFFE0E0E0))
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            PageView.builder(
                              controller: _pageController,
                              itemCount: images.length,
                              onPageChanged: (i) {
                                setState(() => _imageIndex = i);
                              },
                              itemBuilder: (_, i) {
                                return Image.network(
                                  images[i],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const ColoredBox(color: Color(0xFFE0E0E0)),
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return const ColoredBox(
                                      color: Color(0xFFE8E8E8),
                                      child: Center(
                                        child: SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _pink,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            if (widget.review.isInfluencer)
                              Positioned(
                                left: healthDp(context, 8),
                                top: healthDp(context, 8),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: healthDp(context, 6),
                                    vertical: healthDp(context, 4),
                                  ),
                                  decoration: BoxDecoration(
                                    color: _pink.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(
                                      healthDp(context, 4),
                                    ),
                                  ),
                                  child: Text(
                                    '서포터\n리뷰어',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: healthSp(context, 8),
                                      fontFamily: _font,
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              if (images.length > 1) ...[
                SizedBox(height: healthDp(context, 8)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(images.length, (i) {
                    final active = i == _imageIndex;
                    return Container(
                      width: healthDp(context, 5),
                      height: healthDp(context, 5),
                      margin: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 2.5),
                      ),
                      decoration: ShapeDecoration(
                        color: active ? _pink : const Color(0xFFD2D2D2),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 20)),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
          SizedBox(height: healthDp(context, 10)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '|',
                style: TextStyle(
                  color: _ink,
                  fontSize: healthSp(context, 16),
                  fontFamily: _font,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: healthDp(context, 6)),
              Flexible(
                child: Text(
                  widget.review.reviewerName,
                  style: TextStyle(
                    color: _ink,
                    fontSize: healthSp(context, 16),
                    fontFamily: _font,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (title.isNotEmpty) ...[
            SizedBox(height: healthDp(context, 10)),
            Text(
              title,
              style: TextStyle(
                color: _ink,
                fontSize: healthSp(context, 12),
                fontFamily: _font,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ],
          if (summaryOrContent.isNotEmpty) ...[
            SizedBox(height: healthDp(context, title.isNotEmpty ? 5 : 10)),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              child: Text(
                summaryOrContent,
                maxLines: widget.expanded ? null : 2,
                overflow: widget.expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: TextStyle(
                  color: _ink,
                  fontSize: healthSp(context, 12),
                  fontFamily: _font,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
          ],
          SizedBox(height: healthDp(context, 10)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 10),
              vertical: healthDp(context, 8),
            ),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  width: healthDp(context, 0.5),
                  color: _pink,
                ),
                bottom: BorderSide(
                  width: healthDp(context, 0.5),
                  color: _pink,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _avgText,
                  style: TextStyle(
                    color: _pink,
                    fontSize: healthSp(context, 20),
                    fontFamily: _font,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: healthDp(context, 8)),
                Container(
                  width: healthDp(context, 1),
                  height: healthDp(context, 18),
                  color: _pink.withValues(alpha: 0.45),
                ),
                SizedBox(width: healthDp(context, 8)),
                Expanded(
                  child: Wrap(
                    spacing: healthDp(context, 10),
                    runSpacing: healthDp(context, 4),
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _scoreChip(context, '효과', widget.review.mrScore1),
                      _scoreChip(context, '가성비', widget.review.mrScore2),
                      _scoreChip(context, '맛/향', widget.review.mrScore3),
                      _scoreChip(context, '편리함', widget.review.mrScore4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreChip(BuildContext context, String label, double score) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _ink,
            fontSize: healthSp(context, 12),
            fontFamily: _font,
            fontWeight: FontWeight.w300,
          ),
        ),
        SizedBox(width: healthDp(context, 3)),
        AppStarIcon(size: healthDp(context, 11)),
        SizedBox(width: healthDp(context, 2)),
        Text(
          '${_scoreInt(score)}',
          style: TextStyle(
            color: _ink,
            fontSize: healthSp(context, 10),
            fontFamily: _font,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}