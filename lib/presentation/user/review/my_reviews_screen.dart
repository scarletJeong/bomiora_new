import 'dart:async';

import 'package:flutter/material.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_bar.dart';
import '../../common/widgets/confirm_dialog.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/review/review_model.dart';
import '../../../data/services/review_service.dart';
import '../../../data/services/auth_service.dart';
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
  int _currentPage = 0;
  bool _hasMore = true;

  ReviewModel? _activeReview;
  /// 방금 접힌 리뷰는 '이전 리뷰 내역' 맨 위로
  int? _historyHeadId;
  String _productNameQuery = '';

  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kBorder = Color(0x7FD2D2D2);
  static const Color _kBorderStrong = Color(0xFFD2D2D2);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kMuted2 = Color(0xFF898383);
  static const Color _kHeaderAction = Color(0xFF898383);
  static const Color _kInk = Color(0xFF1A1A1A);
  static const Color _kDateBrown = Color(0xFF584045);
  static const Color _kGrayBox = Color(0xCCF6F6F6);
  static const String _kBrandFallback = '보미오라';

  @override
  void initState() {
    super.initState();
    _loadReviews();
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
      _historyHeadId = null;
    } else {
      // 새로고침 후 동일 리뷰면 펼침 카드가 예전 객체를 물고 있지 않도록 최신 인스턴스로 교체
      _activeReview = fresh;
    }
  }

  List<ReviewModel> _collapsedOrdered() {
    final visible = _visibleReviews();
    final activeId = _activeReview?.isId;
    var others = visible.where((r) => r.isId != activeId).toList();

    if (_historyHeadId != null) {
      final head = others.where((r) => r.isId == _historyHeadId).toList();
      final tail = others.where((r) => r.isId != _historyHeadId).toList();
      tail.sort((a, b) {
        final ta = a.isTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = b.isTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
      return [...head, ...tail];
    }

    others.sort((a, b) {
      final ta = a.isTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.isTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return others;
  }

  void _selectReview(ReviewModel tapped) {
    if (tapped.isId == _activeReview?.isId) return;
    setState(() {
      _historyHeadId = _activeReview?.isId;
      _activeReview = tapped;
    });
  }

  Future<void> _loadReviews({bool refresh = false}) async {
    if (_isLoading && !refresh) return;
    if (!refresh && !_hasMore) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _currentPage = 0;
        _reviews.clear();
        _hasMore = true;
        _historyHeadId = null;
      }
    });

    try {
      final user = await AuthService.getUser();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다.')),
          );
        }
        return;
      }

      final result = await ReviewService.getMemberReviews(
        mbId: user.id,
        page: _currentPage,
        size: 20,
      );

      if (result['success'] == true) {
        final newReviews = result['reviews'] as List<ReviewModel>;

        setState(() {
          if (refresh) {
            _reviews = newReviews;
          } else {
            _reviews.addAll(newReviews);
          }
          _currentPage++;
          _hasMore = result['hasNext'] ?? false;
          final vis = _visibleReviews();
          _ensureActiveInVisible(vis);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리뷰를 불러오는데 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _writtenLine(ReviewModel r) {
    return '${r.isTime == null ? '-' : DateDisplayFormatter.formatYmd(r.isTime!)} 작성';
  }

  Widget _starsRow(int score, {double size = 14}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < score ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: i < score ? _kPink : const Color(0xFFD2D2D2),
        );
      }),
    );
  }

  /// 비대면 카드 — 평점 2×2 그리드(효과·가성비 / 향·맛·복용 편의성), 셀마다 별 5개.
  Widget _prescriptionRatingCell(String label, int score) {
    final s = score.clamp(0, 5);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kGrayBox,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _kMuted2,
              fontSize: 10,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 4),
          _starsRow(s, size: 16),
        ],
      ),
    );
  }

  Widget _prescriptionRatingGrid(ReviewModel r) {
    Widget pair(String a, int sa, String b, int sb) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _prescriptionRatingCell(a, sa)),
          const SizedBox(width: 8),
          Expanded(child: _prescriptionRatingCell(b, sb)),
        ],
      );
    }

    return Column(
      children: [
        pair('효과', r.isScore1, '가성비', r.isScore2),
        const SizedBox(height: 8),
        pair('향/맛', r.isScore3, '복용 편의성', r.isScore4),
      ],
    );
  }

  Widget _prescriptionTextSection(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _kInk,
            fontSize: 14,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(width: 1, color: _kBorder),
          ),
          child: Text(
            body,
            style: const TextStyle(
              color: _kInk,
              fontSize: 12,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              height: 1.50,
            ),
          ),
        ),
      ],
    );
  }

  Widget _productImage(ReviewModel r) {
    final url = r.images.isNotEmpty ? ImageUrlHelper.getReviewImageUrl(r.images.first) : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 80,
        height: 80,
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
    return Container(
      color: const Color(0xFFE8E8E8),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: _kMuted, size: 32),
    );
  }

  Widget _productHeaderRow(ReviewModel r) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _productImage(r),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _kBrandFallback,
                      style: const TextStyle(
                        color: _kInk,
                        fontSize: 10,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _headerActionsInline(r),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _productTitle(r),
                style: const TextStyle(
                  color: _kInk,
                  fontSize: 14,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.26,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Text(
                _writtenLine(r),
                style: const TextStyle(
                  color: _kMuted2,
                  fontSize: 10,
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

  Widget _headerActionsInline(ReviewModel r) {
    final enabled = r.isId != null;
    final actionColor = enabled ? _kHeaderAction : _kHeaderAction.withValues(alpha: 0.5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: enabled ? () => _editReview(r) : null,
          child: Text(
            '수정',
            style: TextStyle(
              color: actionColor,
              fontSize: 12,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          '|',
          style: TextStyle(
            color: _kHeaderAction,
            fontSize: 12,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: enabled ? () => _deleteReview(r) : null,
          child: Text(
            '삭제',
            style: TextStyle(
              color: actionColor,
              fontSize: 12,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _couponBanner(ReviewModel r) {
    final n = r.czDownload ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _kPink),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_offer_outlined, color: _kPink, size: 20),
                    const SizedBox(width: 5),
                    const Text(
                      '5% 할인 도움 쿠폰',
                      style: TextStyle(
                        color: _kPink,
                        fontSize: 12,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                    ),
                    children: [
                      TextSpan(text: '$n', style: const TextStyle(color: _kPink)),
                      const TextSpan(
                        text: '명이 받았어요!',
                        style: TextStyle(color: _kMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '유효기간 : 발급일로부터 7일',
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: 8,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0x19FF5A8D),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(Icons.download_rounded, color: _kPink, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _expandedPrescriptionCard(ReviewModel r) {
    final children = <Widget>[
      _productHeaderRow(r),
      const SizedBox(height: 10),
      _prescriptionRatingGrid(r),
    ];

    void appendTextSection(String title, String? raw) {
      final text = (raw ?? '').trim();
      if (text.isEmpty) return;
      children.add(const SizedBox(height: 10));
      children.add(_prescriptionTextSection(title, text));
    }

    appendTextSection('좋았던 점', r.isPositiveReviewText);
    appendTextSection('아쉬운 점', r.isNegativeReviewText);
    appendTextSection('꿀팁', r.isMoreReviewText);

    children
      ..add(const SizedBox(height: 10))
      ..add(_couponBanner(r));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(width: 1, color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _expandedGeneralCard(ReviewModel r) {
    final avg = r.averageScore != null
        ? r.averageScore!.round().clamp(0, 5)
        : ((r.isScore1 + r.isScore2 + r.isScore3 + r.isScore4) / 4.0).round().clamp(0, 5);
    final body = [
      r.isPositiveReviewText,
      r.isNegativeReviewText,
      r.isMoreReviewText,
    ].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).join('\n\n');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _kBorder),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _productHeaderRow(r),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _starsRow(avg, size: 18),
                const SizedBox(width: 8),
                Text(
                  '$avg',
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 16,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 1, color: _kBorder),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              body.isEmpty ? '작성된 리뷰 내용이 없습니다.' : body,
              style: const TextStyle(
                color: _kInk,
                fontSize: 12,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                height: 1.50,
                letterSpacing: -0.60,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _collapsedTile(ReviewModel r) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectReview(r),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: _kBorder),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: r.images.isNotEmpty
                      ? Image.network(
                          ImageUrlHelper.getReviewImageUrl(r.images.first),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0x4CD2D2D2),
                            child: const Icon(Icons.image_outlined, size: 18, color: _kMuted),
                          ),
                        )
                      : Container(
                          color: const Color(0x4CD2D2D2),
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_outlined, size: 18, color: _kMuted),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.isTime == null ? '-' : DateDisplayFormatter.formatYmd(r.isTime!),
                      style: const TextStyle(
                        color: _kDateBrown,
                        fontSize: 10,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        height: 1.65,
                      ),
                    ),
                    Text(
                      _productTitle(r),
                      style: const TextStyle(
                        color: _kInk,
                        fontSize: 16,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        letterSpacing: -1.44,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _kMuted, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterField() {
    return SizedBox(
      width: 140,
      child: TextField(
        onChanged: (v) {
          setState(() {
            _productNameQuery = v;
            _ensureActiveInVisible(_visibleReviews());
          });
        },
        style: const TextStyle(
          color: _kMuted,
          fontSize: 10,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w300,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          hintText: '상품명',
          hintStyle: const TextStyle(
            color: _kMuted,
            fontSize: 10,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorderStrong),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorderStrong),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kPink, width: 1),
          ),
        ),
      ),
    );
  }

  Future<void> _editReview(ReviewModel review) async {
    if (review.isId == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewWriteScreen.edit(review: review),
      ),
    );
    if (!mounted) return;
    if (result == true) await _loadReviews(refresh: true);
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
      final result = await ReviewService.deleteReview(review.isId!, user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? '처리되었습니다.'),
          backgroundColor: result['success'] == true ? Colors.green : Colors.red,
        ),
      );
      if (result['success'] == true) {
        setState(() {
          _historyHeadId = null;
          if (_activeReview?.isId == review.isId) _activeReview = null;
        });
        _loadReviews(refresh: true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리뷰 삭제 중 오류가 발생했습니다.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleReviews();
    final collapsed = _collapsedOrdered();

    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'Gmarket Sans TTF', color: _kInk),
      child: MobileAppLayoutWrapper(
        backgroundColor: Colors.white,
        appBar: const HealthAppBar(title: '내 리뷰'),
        child: _isLoading && _reviews.isEmpty
            ? const Center(child: CircularProgressIndicator(color: _kPink))
            : _reviews.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
                    color: _kPink,
                    onRefresh: () => _loadReviews(refresh: true),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(27, 20, 27, 0),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              _buildCountAndFilterRow(visible.length),
                              const SizedBox(height: 20),
                              if (_activeReview != null)
                                _isPrescriptionStyle(_activeReview!)
                                    ? _expandedPrescriptionCard(_activeReview!)
                                    : _expandedGeneralCard(_activeReview!),
                              const SizedBox(height: 24),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '이전 리뷰 내역',
                                  style: TextStyle(
                                    color: _kMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    height: 1.67,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ]),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(27, 0, 27, 20),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index == collapsed.length) {
                                  if (_hasMore && !_isLoading) {
                                    scheduleMicrotask(() {
                                      if (mounted) _loadReviews();
                                    });
                                  }
                                  if (_isLoading && _reviews.isNotEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Center(child: CircularProgressIndicator(color: _kPink)),
                                    );
                                  }
                                  return const SizedBox(height: 24);
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _collapsedTile(collapsed[index]),
                                );
                              },
                              childCount: collapsed.length + 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildCountAndFilterRow(int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: _kBorder),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: '총 리뷰수 ',
                    style: TextStyle(
                      color: _kMuted,
                      fontSize: 12,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: '$count',
                    style: const TextStyle(
                      color: _kPink,
                      fontSize: 12,
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
        const SizedBox(height: 5),
        Container(height: 1, color: _kBorder),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '작성한 리뷰가 없습니다',
            style: TextStyle(fontSize: 16, color: Colors.grey[600], fontFamily: 'Gmarket Sans TTF'),
          ),
        ],
      ),
    );
  }
}
