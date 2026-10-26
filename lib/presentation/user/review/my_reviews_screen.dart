import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_assets.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/confirm_dialog.dart';
import '../../common/widgets/centered_empty_state.dart';
import '../../common/widgets/app_star_rating.dart';
import '../../common/widgets/dropdown_btn.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../../health/health_common/widgets/health_focus_outline_box.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/review/review_model.dart';
import '../../../data/services/review_service.dart';
import '../../../data/services/auth_service.dart';
import 'review_photo_viewer.dart';
import 'review_write_general_screen.dart';
import 'review_write_screen.dart';

/// 내 리뷰 — 상단 1건 펼침 + 이전 리뷰 내역(탭 시 교체)
class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  List<ReviewModel> _reviews = [];
  bool _isLoading = false;
  bool _requiresLogin = false;
  int _currentPage = 0;
  bool _hasMore = true;
  static const int _historyPageSize = 5;
  int _historyVisibleCount = _historyPageSize;

  ReviewModel? _activeReview;

  String _productNameQuery = '';
  final TextEditingController _productNameFilterController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _filterDebounce;

  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kBorder = Color(0x7FD2D2D2);
  static const Color _kBorderStrong = Color(0xFFD2D2D2);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kMuted2 = Color(0xFF898383);
  static const Color _kInk = Color(0xFF1A1A1E);

  @override
  void initState() {
    super.initState();
    _productNameFilterController.addListener(_onProductNameFilterChanged);
    _loadReviews();
  }

  @override
  void dispose() {
    _filterDebounce?.cancel();
    _productNameFilterController.removeListener(_onProductNameFilterChanged);
    _productNameFilterController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onProductNameFilterChanged() {
    if (!mounted) return;
    setState(() {});
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final v = _productNameFilterController.text;
      if (v == _productNameQuery) return;
      setState(() {
        _productNameQuery = v;
        _historyVisibleCount = _historyPageSize;
        _ensureActiveInVisible(_visibleReviews());
      });
    });
  }

  /// `it_kind` 또는 `is_rvkind` 가 일반일 때 일반 리뷰 작성/수정 화면 사용
  bool _reviewUsesGeneralWriteEditor(ReviewModel r) {
    if (r.isRvkind.toLowerCase() == 'general') return true;
    final raw =
        (r.itKind ?? '').trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    return raw == 'general' ||
        raw == 'normal' ||
        raw == 'goods' ||
        raw == 'product';
  }

  /// 정수는 `4`, 0.1 단위 소수는 `3.1`, `4.8` 형태로 표시
  String _formatGeneralReviewRating(double score) {
    if (score < 0.1) return '0';
    final rounded = (score * 10).round() / 10;
    final frac = ((rounded * 10).round() % 10).abs();
    if (frac == 0) {
      return rounded.round().toString();
    }
    return rounded.toStringAsFixed(1);
  }

  bool _isPrescriptionStyle(ReviewModel r) {
    final raw = (r.itKind ?? '').trim();
    if (raw.isNotEmpty) {
      final k = raw.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
      if (k == 'general' || k == 'normal' || k == 'goods' || k == 'product') {
        return false;
      }
      if (k.contains('prescription') ||
          k.contains('nonface') ||
          k == 'rx' ||
          k.contains('telemedicine')) {
        return true;
      }
    }
    return r.isSupporterReview || r.isRvkind.toLowerCase() == 'prescription';
  }

  /// API `it_name` / `itName` 등은 [ReviewModel]에서만 파싱합니다. 없으면 ID 대신 안내 문구.
  String _productTitle(ReviewModel r) {
    final n = (r.itName ?? '').trim();
    if (n.isNotEmpty) return n;
    return '상품명 없음';
  }

  /// 상품명 위 제조사. `it_subject`가 있고 상품명과 다를 때만 표시한다.
  String? _makerLabel(ReviewModel r) {
    final subject = (r.itSubject ?? '').trim();
    if (subject.isEmpty || subject == _productTitle(r)) return null;
    return subject;
  }

  /// HTML·공백만 있는 리뷰 본문은 미작성으로 처리
  bool _hasReviewBodyText(String? raw) {
    var t = (raw ?? '').trim();
    if (t.isEmpty) return false;
    t = t
        .replaceAll(RegExp(r'<[^>]*>', multiLine: true), ' ')
        .replaceAll(RegExp(r'&nbsp;|&#160;', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return t.isNotEmpty;
  }

  String? _reviewBodyPlain(String? raw) {
    if (!_hasReviewBodyText(raw)) return null;
    return (raw ?? '').trim();
  }

  List<ReviewModel> _sorted(List<ReviewModel> list) {
    final copy = List<ReviewModel>.from(list);
    copy.sort((a, b) {
      final ta = a.isTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.isTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return copy;
  }

  List<ReviewModel> _visibleReviews() {
    final sorted = _sorted(_reviews);
    final q = _productNameQuery.trim().toLowerCase();
    if (q.isEmpty) return sorted;
    return sorted
        .where((r) => _productTitle(r).toLowerCase().contains(q))
        .toList();
  }

  void _ensureActiveInVisible(List<ReviewModel> visible) {
    if (visible.isEmpty) {
      _activeReview = null;
      return;
    }
    if (_activeReview == null) {
      _activeReview = visible.first;
      return;
    }
    final activeId = _activeReview!.isId;
    ReviewModel? fresh;
    for (final r in visible) {
      if (r.isId == activeId) {
        fresh = r;
        break;
      }
    }
    if (fresh == null) {
      _activeReview = visible.first;
    } else {
      // 새로고침 후 동일 리뷰면 펼침 카드가 예전 객체를 물고 있지 않도록 최신 인스턴스로 교체
      _activeReview = fresh;
    }
  }

  int _compareReviewNewestFirst(ReviewModel a, ReviewModel b) {
    final ta = a.isTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    final tb = b.isTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    final byTime = tb.compareTo(ta);
    if (byTime != 0) return byTime;
    return (b.isId ?? 0).compareTo(a.isId ?? 0);
  }

  /// 펼친 리뷰를 뺀 나머지. 작성일 최신순이며, 항목을 골라도 순서는 바뀌지 않는다.
  List<ReviewModel> _collapsedOrdered() {
    final visible = _visibleReviews();
    final activeId = _activeReview?.isId;
    final others = visible.where((r) => r.isId != activeId).toList();
    others.sort(_compareReviewNewestFirst);
    return others;
  }

  Future<void> _loadMoreHistory() async {
    final collapsed = _collapsedOrdered();
    if (_historyVisibleCount < collapsed.length) {
      setState(() {
        _historyVisibleCount = (_historyVisibleCount + _historyPageSize)
            .clamp(0, collapsed.length);
      });
      return;
    }
    if (_hasMore && !_isLoading) {
      await _loadReviews();
      if (!mounted) return;
      setState(() {
        final next = _collapsedOrdered();
        _historyVisibleCount =
            (_historyVisibleCount + _historyPageSize).clamp(0, next.length);
      });
    }
  }

  Widget _buildHistoryLoadMoreButton() {
    return SizedBox(
      width: double.infinity,
      height: healthDp(context, 40),
      child: OutlinedButton(
        onPressed: _isLoading ? null : _loadMoreHistory,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            width: healthDp(context, 0.5),
            color: _kBorderStrong,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
          ),
          backgroundColor: Colors.white,
        ),
        child: _isLoading
            ? SizedBox(
                width: healthDp(context, 20),
                height: healthDp(context, 20),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _kPink,
                ),
              )
            : Text(
                '더보기',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _kMuted,
                  fontSize: healthSp(context, 16),
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }

  void _selectReview(ReviewModel tapped) {
    if (tapped.isId == _activeReview?.isId) return;
    setState(() {
      final before = _collapsedOrdered();
      final showingAll =
          before.isNotEmpty && _historyVisibleCount >= before.length;
      _activeReview = tapped;
      if (showingAll) {
        _historyVisibleCount = _collapsedOrdered().length;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _loadReviews({bool refresh = false}) async {
    if (_isLoading && !refresh) return;
    if (!refresh && !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final user = await AuthService.getUser();
      if (user == null) {
        if (mounted) {
          setState(() {
            _requiresLogin = true;
          });
        }
        return;
      }

      final result = await ReviewService.getMemberReviews(
        mbId: user.id,
        page: refresh ? 0 : _currentPage,
        size: 20,
        forceRefresh: refresh,
      );

      if (result['success'] == true) {
        final newReviews = result['reviews'] as List<ReviewModel>;

        setState(() {
          _requiresLogin = false;
          if (refresh) {
            _reviews = newReviews;
            _currentPage = 1;
            _historyVisibleCount = _historyPageSize;
          } else {
            _reviews.addAll(newReviews);
            _currentPage++;
          }
          _hasMore = result['hasNext'] ?? false;
          final vis = _visibleReviews();
          _ensureActiveInVisible(vis);
        });
      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _writtenLine(ReviewModel r) {
    return '${r.isTime == null ? '-' : DateDisplayFormatter.formatYmd(r.isTime!)} 작성';
  }

  /// 비대면 카드 — 평점 2×2 그리드(효과·가성비 / 향·맛·복용 편의성), 셀마다 별 5개.
  Widget _prescriptionRatingCell(String label, double score) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 10)),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: const Color(0xFFD2D2D2),
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 12)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF1A1A1E),
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 8)),
          AppStarRating(
            rating: score,
            starSize: healthDp(context, 20.25),
            gap: healthDp(context, 2),
            color: _kPink,
          ),
        ],
      ),
    );
  }

  Widget _prescriptionRatingGrid(ReviewModel r) {
    Widget pair(String a, double sa, String b, double sb) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _prescriptionRatingCell(a, sa)),
          SizedBox(width: healthDp(context, 10)),
          Expanded(child: _prescriptionRatingCell(b, sb)),
        ],
      );
    }

    return Column(
      children: [
        pair('효과', r.isScore1, '가성비', r.isScore2),
        SizedBox(height: healthDp(context, 10)),
        pair('향/맛', r.isScore3, '편리함', r.isScore4),
      ],
    );
  }

  Widget _prescriptionTextSection(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _kMuted,
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            letterSpacing: -0.70,
          ),
        ),
        SizedBox(height: healthDp(context, 10)),
        Text(
          body,
          style: TextStyle(
            color: _kInk,
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            height: 1.67,
            letterSpacing: -0.60,
          ),
        ),
      ],
    );
  }

  String? _guardProductImageUrl(String? url) {
    final t = (url ?? '').toLowerCase();
    if (t.contains('no_img.png')) return null;
    return url;
  }

  /// 상품 썸네일만 (`productImage` / it_img1 등) — 리뷰 첨부와 무관
  String? _productThumbnailUrl(ReviewModel r) {
    final thumb = r.productImage?.trim();
    if (thumb == null || thumb.isEmpty) return null;
    return _guardProductImageUrl(ImageUrlHelper.getImageUrl(thumb));
  }

  List<String> _reviewAttachImageUrls(ReviewModel r) {
    return r.images
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .map(ImageUrlHelper.getReviewImageUrl)
        .toList();
  }

  Widget _productImage(
    ReviewModel r, {
    double sideBase = 64,
    double radiusBase = 8,
  }) {
    final url = _productThumbnailUrl(r);
    final side = healthDp(context, sideBase);
    return ClipRRect(
      borderRadius: BorderRadius.circular(healthDp(context, radiusBase)),
      child: SizedBox(
        width: side,
        height: side,
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _imagePlaceholder(),
              )
            : _imagePlaceholder(),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return const ColoredBox(
      color: Color(0xFFE8E8E8),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: Color(0xFF898686),
        ),
      ),
    );
  }

  Widget _squareReviewPhoto({
    required String url,
    required double side,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
        child: SizedBox(
          width: side,
          height: side,
          child: Image.network(
            url,
            width: side,
            height: side,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _imagePlaceholder(),
          ),
        ),
      ),
    );
  }

  String _dateOnly(ReviewModel r) {
    if (r.isTime == null) return '-';
    return DateDisplayFormatter.formatYmd(r.isTime!);
  }

  double _prescriptionAverage(ReviewModel r) {
    final total = r.totalIsScore;
    if (total != null && total > 0) return total.clamp(0.0, 5.0);
    final scores = [r.isScore1, r.isScore2, r.isScore3, r.isScore4]
        .where((score) => score >= 0.1)
        .toList();
    if (scores.isEmpty) return (r.averageScore ?? 0).clamp(0.0, 5.0);
    final sum = scores.reduce((a, b) => a + b);
    return (sum / scores.length).clamp(0.0, 5.0);
  }

  Widget _reviewMenuButton(ReviewModel r) {
    final enabled = r.isId != null;
    return Builder(
      builder: (anchorContext) {
        return GestureDetector(
          onTap: !enabled
              ? null
              : () {
                  DropdownBtn.showMenu(
                    context: context,
                    anchorContext: anchorContext,
                    items: const ['수정', '삭제'],
                    gap: 0,
                    menuWidth: healthDp(context, 150),
                    itemFontSizeBase: 12,
                    itemFontFamily: 'Gmarket Sans TTF',
                    itemFontWeight: FontWeight.w300,
                    itemPadding: EdgeInsets.symmetric(
                      vertical: healthDp(context, 10),
                      horizontal: healthDp(context, 12),
                    ),
                    blurBackdrop: true,
                    blurSigma: 2,
                    backdropOpacity: 0.35,
                    alignRight: true,
                    onSelected: (label) {
                      if (label == '수정') _editReview(r);
                      if (label == '삭제') _deleteReview(r);
                    },
                  );
                },
          child: Icon(
            Icons.more_vert,
            size: healthDp(context, 16),
            color: enabled ? _kMuted2 : _kMuted2.withValues(alpha: 0.5),
          ),
        );
      },
    );
  }

  Widget _prescriptionHeader(ReviewModel r) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _productImage(r),
        SizedBox(width: healthDp(context, 12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _makerLabel(r) == null
                        ? const SizedBox.shrink()
                        : Text(
                            _makerLabel(r)!,
                            style: TextStyle(
                              color: _kMuted2,
                              fontSize: healthSp(context, 10),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                  _reviewMenuButton(r),
                ],
              ),
              SizedBox(height: healthDp(context, 2)),
              Text(
                _productTitle(r),
                style: TextStyle(
                  color: _kInk,
                  fontSize: healthSp(context, 14),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  height: 1.29,
                  letterSpacing: -1.26,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: healthDp(context, 4)),
              Text(
                _dateOnly(r),
                style: TextStyle(
                  color: _kMuted2,
                  fontSize: healthSp(context, 10),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _generalHeader(ReviewModel r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: _reviewMenuButton(r),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _productImage(r, sideBase: 80, radiusBase: 4),
            SizedBox(width: healthDp(context, 20)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_makerLabel(r) != null) ...[
                    Text(
                      _makerLabel(r)!,
                      style: TextStyle(
                        color: _kInk,
                        fontSize: healthSp(context, 10),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: healthDp(context, 2)),
                  ],
                  Text(
                    _productTitle(r),
                    style: TextStyle(
                      color: _kInk,
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.26,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: healthDp(context, 10)),
                  Text(
                    _writtenLine(r),
                    style: TextStyle(
                      color: _kMuted2,
                      fontSize: healthSp(context, 10),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _reviewPhotosGallery(ReviewModel r) {
    final urls = _reviewAttachImageUrls(r);
    if (urls.isEmpty) return const SizedBox.shrink();

    final side = healthDp(context, 96);
    return SizedBox(
      height: side,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => SizedBox(width: healthDp(context, 8)),
        itemBuilder: (context, index) {
          final url = urls[index];
          return _squareReviewPhoto(
            url: url,
            side: side,
            onTap: () => ReviewPhotoViewer.open(
              context,
              urls: urls,
              initialIndex: index,
            ),
          );
        },
      ),
    );
  }

  Widget _prescriptionPhotoRow(ReviewModel r) {
    final urls = _reviewAttachImageUrls(r);
    if (urls.isEmpty) return const SizedBox.shrink();
    final shown = urls.take(3).toList();
    final side = healthDp(context, 96);
    return SizedBox(
      height: side,
      child: Row(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) SizedBox(width: healthDp(context, 8)),
            _squareReviewPhoto(
              url: shown[i],
              side: side,
              onTap: () => ReviewPhotoViewer.open(
                context,
                urls: shown,
                initialIndex: i,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _prescriptionScoreSummary(ReviewModel r) {
    final average = _prescriptionAverage(r);
    final kg = r.isOutageNum;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 10),
        vertical: healthDp(context, 4),
      ),
      child: Row(
        children: [
          Text(
            average.toStringAsFixed(1),
            style: TextStyle(
              color: _kPink,
              fontSize: healthSp(context, 32),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: healthDp(context, 8)),
          Flexible(
            child: Wrap(
              spacing: healthDp(context, 8),
              runSpacing: healthDp(context, 6),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppStarRating(
                  rating: average,
                  starSize: healthDp(context, 20.25),
                  gap: healthDp(context, 4),
                  color: _kPink,
                  preciseFill: true,
                ),
                if (kg != null && kg > 0)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 6),
                      vertical: healthDp(context, 5.5),
                    ),
                    decoration: ShapeDecoration(
                      color: const Color(0x19FF5A8D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(healthDp(context, 20)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          AppAssets.myReviewCardWeightLossIcon,
                          width: healthDp(context, 13),
                          height: healthDp(context, 13),
                          fit: BoxFit.contain,
                        ),
                        SizedBox(width: healthDp(context, 4)),
                        Text(
                          '${kg}kg 감량',
                          style: TextStyle(
                            color: _kPink,
                            fontSize: healthSp(context, 10),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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

  Widget _expandedPrescriptionCard(ReviewModel r) {
    final children = <Widget>[
      _prescriptionHeader(r),
      SizedBox(height: healthDp(context, 10)),
      Container(height: healthDp(context, 1), color: _kBorder),
      SizedBox(height: healthDp(context, 16)),
      _prescriptionScoreSummary(r),
      SizedBox(height: healthDp(context, 10)),
      _prescriptionRatingGrid(r),
    ];

    void appendTextSection(String title, String? raw) {
      final text = _reviewBodyPlain(raw);
      if (text == null) return;
      children
        ..add(SizedBox(height: healthDp(context, 20)))
        ..add(_prescriptionTextSection(title, text));
    }

    appendTextSection('좋았던 점', r.isPositiveReviewText);
    appendTextSection('아쉬운 점', r.isNegativeReviewText);
    appendTextSection('꿀팁', r.isMoreReviewText);

    if (_reviewAttachImageUrls(r).isNotEmpty) {
      children
        ..add(SizedBox(height: healthDp(context, 16)))
        ..add(_prescriptionPhotoRow(r));
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 14)),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _kBorder),
          borderRadius: BorderRadius.circular(healthDp(context, 12)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _expandedGeneralCard(ReviewModel r) {
    final starScore = (r.totalIsScore ?? r.averageScore ?? 0).clamp(0.0, 5.0);
    final body = _reviewBodyPlain(r.isPositiveReviewText) ?? '';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 15),
        vertical: healthDp(context, 20),
      ),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _kBorder),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _generalHeader(r),
          SizedBox(height: healthDp(context, 10)),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 10),
              vertical: healthDp(context, 14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppStarRating(
                  rating: starScore,
                  starSize: healthDp(context, 25),
                  gap: healthDp(context, 4),
                  color: _kPink,
                  preciseFill: true,
                ),
                SizedBox(width: healthDp(context, 10)),
                Text(
                  _formatGeneralReviewRating(starScore),
                  style: TextStyle(
                    color: _kInk,
                    fontSize: healthSp(context, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: healthDp(context, 76)),
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 20),
              vertical: healthDp(context, 10),
            ),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                side: BorderSide(width: healthDp(context, 1), color: _kBorder),
                borderRadius: BorderRadius.circular(healthDp(context, 12)),
              ),
            ),
            child: Text(
              body.isEmpty ? '작성된 리뷰 내용이 없습니다.' : body,
              style: TextStyle(
                color: _kInk,
                fontSize: healthSp(context, 12),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                height: 1.50,
                letterSpacing: -0.60,
              ),
            ),
          ),
          if (_reviewAttachImageUrls(r).isNotEmpty) ...[
            SizedBox(height: healthDp(context, 20)),
            _reviewPhotosGallery(r),
          ],
        ],
      ),
    );
  }

  Widget _collapsedTile(ReviewModel r) {
    final listThumb = _productThumbnailUrl(r);
    final prescription = _isPrescriptionStyle(r);
    final score = prescription
        ? _prescriptionAverage(r)
        : (r.totalIsScore ?? r.averageScore ?? 0).clamp(0.0, 5.0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectReview(r),
        borderRadius: BorderRadius.circular(healthDp(context, 16)),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(healthDp(context, 16)),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: BorderSide(width: healthDp(context, 1), color: _kBorder),
              borderRadius: BorderRadius.circular(healthDp(context, 16)),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(healthDp(context, 8)),
                child: SizedBox(
                  width: healthDp(context, 40),
                  height: healthDp(context, 40),
                  child: listThumb != null && listThumb.isNotEmpty
                      ? Image.network(
                          listThumb,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0x4CD2D2D2),
                            child: Icon(
                              Icons.image_outlined,
                              size: healthDp(context, 18),
                              color: _kMuted,
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0x4CD2D2D2),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.image_outlined,
                            size: healthDp(context, 18),
                            color: _kMuted,
                          ),
                        ),
                ),
              ),
              SizedBox(width: healthDp(context, 10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _productTitle(r),
                      style: TextStyle(
                        color: _kInk,
                        fontSize: healthSp(context, 14),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        height: 1.29,
                        letterSpacing: -1.26,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: healthDp(context, 8)),
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: healthDp(context, 12),
                          color: _kPink,
                        ),
                        SizedBox(width: healthDp(context, 2)),
                        Text(
                          score.toStringAsFixed(1),
                          style: TextStyle(
                            color: _kInk,
                            fontSize: healthSp(context, 10),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: healthDp(context, 8)),
                        Text(
                          _dateOnly(r),
                          style: TextStyle(
                            color: _kMuted,
                            fontSize: healthSp(context, 10),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _kMuted,
                size: healthDp(context, 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterField() {
    final fieldH = healthDp(context, 28);
    final radius = healthDp(context, 15);
    final padH = healthDp(context, 10);
    final iconSize = healthDp(context, 12);
    final fontSize = healthSp(context, 10);
    final textStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w300,
      height: 1,
    );

    return SizedBox(
      width: healthDp(context, 150),
      height: fieldH,
      child: HealthFocusOutlineBox(
        height: fieldH,
        padding: EdgeInsets.zero,
        borderRadius: radius,
        fillColor: Colors.white,
        builder: (focusNode) => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _productNameFilterController,
                focusNode: focusNode,
                maxLines: 1,
                textAlignVertical: TextAlignVertical.center,
                cursorColor: _kInk,
                style: textStyle.copyWith(color: _kInk),
                decoration: InputDecoration(
                  hintText: '상품명',
                  hintStyle: textStyle.copyWith(color: _kMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.only(left: padH),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: padH),
              child: SvgPicture.asset(
                AppAssets.searchIcon,
                width: iconSize,
                height: iconSize,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editReview(ReviewModel review) async {
    if (review.isId == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => _reviewUsesGeneralWriteEditor(review)
            ? ReviewWriteGeneralScreen.edit(review: review)
            : ReviewWriteScreen.edit(review: review),
      ),
    );
    if (!mounted) return;
    if (result != true) return;
    final user = await AuthService.getUser();
    if (user == null || !mounted) return;
    final latest = await ReviewService.getMemberReviews(
      mbId: user.id,
      page: 0,
      size: 20,
      forceRefresh: true,
    );
    if (!mounted || latest['success'] != true) return;
    setState(() {
      _currentPage = 1;
      _reviews = List<ReviewModel>.from(latest['reviews'] as List<ReviewModel>);
      _hasMore = latest['hasNext'] == true;
      _requiresLogin = false;
      final vis = _visibleReviews();
      _ensureActiveInVisible(vis);
    });
  }

  Future<void> _deleteReview(ReviewModel review) async {
    if (review.isId == null) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: '리뷰 삭제',
      message: '정말 이 리뷰를 삭제하시겠습니까?',
      confirmText: '삭제',
    );
    if (!confirmed) return;
    try {
      final user = await AuthService.getUser();
      if (user == null) return;
      final result = await ReviewService.deleteReview(
        review.isId!,
        user.id,
        itId: review.itId,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() {
          if (_activeReview?.isId == review.isId) _activeReview = null;
        });
        _loadReviews(refresh: true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleReviews();
    final collapsed = _collapsedOrdered();
    final shownHistory = collapsed.take(_historyVisibleCount).toList();
    final canLoadMoreHistory =
        shownHistory.length < collapsed.length || _hasMore;
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );
    final textScale = healthTextScaleByWidth(MediaQuery.sizeOf(context).width);
    final prescriptionPage =
        _activeReview != null && _isPrescriptionStyle(_activeReview!);
    final pageH = healthDp(context, prescriptionPage ? 20 : 27);

    return Theme(
      data: gmarketTheme,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'Gmarket Sans TTF', color: _kInk),
          child: MobileAppLayoutWrapper(
            backgroundColor: Colors.white,
            appBar: HealthAppBar(
              title: '내 리뷰',
              leadingIconSize: healthDp(context, 16),
            ),
            child: _isLoading && _reviews.isEmpty
                ? Center(
                    child: SizedBox(
                      width: healthDp(context, 36),
                      height: healthDp(context, 36),
                      child: const CircularProgressIndicator(color: _kPink),
                    ),
                  )
                : _requiresLogin
                    ? _buildLoginMessage()
                    : _reviews.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            color: _kPink,
                            onRefresh: () => _loadReviews(refresh: true),
                            child: CustomScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                SliverPadding(
                                  padding: EdgeInsets.fromLTRB(
                                    pageH,
                                    healthDp(context, 5),
                                    pageH,
                                    0,
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildListDelegate([
                                      _buildCountAndFilterRow(visible.length),
                                      SizedBox(height: healthDp(context, 20)),
                                      if (_activeReview != null)
                                        _isPrescriptionStyle(_activeReview!)
                                            ? _expandedPrescriptionCard(
                                                _activeReview!)
                                            : _expandedGeneralCard(
                                                _activeReview!),
                                      SizedBox(height: healthDp(context, 20)),
                                      prescriptionPage
                                          ? Row(
                                              children: [
                                                Container(
                                                  width: healthDp(context, 2),
                                                  height: healthDp(context, 14),
                                                  decoration: BoxDecoration(
                                                    color: _kInk,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      healthDp(context, 10),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                    width: healthDp(context, 10)),
                                                Text(
                                                  '이전 리뷰 내역',
                                                  style: TextStyle(
                                                    color: _kInk,
                                                    fontSize: healthSp(context, 14),
                                                    fontFamily: 'Gmarket Sans TTF',
                                                    fontWeight: FontWeight.w500,
                                                    letterSpacing: -1.26,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: healthDp(context, 8),
                                              ),
                                              child: Text(
                                                '이전 리뷰 내역',
                                                style: TextStyle(
                                                  color: _kMuted,
                                                  fontSize: healthSp(context, 12),
                                                  fontWeight: FontWeight.w500,
                                                  height: 1.67,
                                                ),
                                              ),
                                            ),
                                      SizedBox(height: healthDp(context, 12)),
                                    ]),
                                  ),
                                ),
                                SliverPadding(
                                  padding: EdgeInsets.fromLTRB(
                                    pageH,
                                    0,
                                    pageH,
                                    healthDp(context, 48),
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        if (index == shownHistory.length) {
                                          if (!canLoadMoreHistory) {
                                            return SizedBox(
                                                height: healthDp(context, 24));
                                          }
                                          return Padding(
                                            padding: EdgeInsets.only(
                                              top: healthDp(context, 8),
                                              bottom: healthDp(context, 24),
                                            ),
                                            child:
                                                _buildHistoryLoadMoreButton(),
                                          );
                                        }
                                        return Padding(
                                          padding: EdgeInsets.only(
                                              bottom: healthDp(context, 12)),
                                          child: _collapsedTile(
                                              shownHistory[index]),
                                        );
                                      },
                                      childCount: shownHistory.length + 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountAndFilterRow(int count) {
    final divH = healthDp(context, 1);
    final countStyle = TextStyle(
      color: _kMuted,
      fontSize: healthSp(context, 12),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w500,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: divH, color: _kBorder),
        SizedBox(height: healthDp(context, 5)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '총 리뷰수 ', style: countStyle),
                  TextSpan(
                    text: '$count',
                    style: TextStyle(
                      color: _kPink,
                      fontSize: healthSp(context, 12),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _filterField(),
          ],
        ),
        SizedBox(height: healthDp(context, 5)),
        Container(height: divH, color: _kBorder),
      ],
    );
  }

  Widget _buildEmpty() {
    return CenteredEmptyState(
      iconWidget: CenteredEmptyState.assetIcon(
        context,
        AppAssets.emptyReviewIcon,
      ),
      message: '작성한 리뷰가 없습니다',
    );
  }

  Widget _buildLoginMessage() {
    return CenteredEmptyState(
      iconWidget: CenteredEmptyState.assetIcon(
        context,
        AppAssets.emptyReviewIcon,
      ),
      message: '로그인 후 이용 가능합니다.',
      trailing: CenteredEmptyState.loginButtonTrailing(
        context,
        onPressed: () async {
          await Navigator.pushNamed(context, '/login');
          if (!mounted) return;
          await _loadReviews(refresh: true);
        },
      ),
    );
  }
}
