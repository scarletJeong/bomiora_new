import 'dart:async';

import 'package:flutter/material.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/confirm_dialog.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/review/review_model.dart';
import '../../../data/services/review_service.dart';
import '../../../data/services/auth_service.dart';
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

  /// `it_kind` 또는 `is_rvkind` 가 일반일 때 일반 리뷰 작성/수정 화면 사용
  bool _reviewUsesGeneralWriteEditor(ReviewModel r) {
    if (r.isRvkind.toLowerCase() == 'general') return true;
    final raw = (r.itKind ?? '').trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    return raw == 'general' || raw == 'normal' || raw == 'goods' || raw == 'product';
  }

  /// 일반 상품 리뷰 카드 상단 만족도 — `total_is_score` (없으면 0)
  double _generalReviewTotalRating(ReviewModel r) {
    final t = r.totalIsScore;
    if (t == null || t <= 0) return 0.0;
    return t.clamp(0.0, 5.0);
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
          setState(() {
            _requiresLogin = true;
          });
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
          _requiresLogin = false;
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

  Widget _starsRowFromRating(double rating, {double size = 14}) {
    final r = rating.clamp(0.0, 5.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final full = i + 1.0;
        final half = i + 0.5;
        final IconData ic;
        if (r >= full - 1e-9) {
          ic = Icons.star_rounded;
        } else if (r >= half - 1e-9) {
          ic = Icons.star_half_rounded;
        } else {
          ic = Icons.star_border_rounded;
        }
        final active = r >= half - 1e-9;
        return Icon(ic, size: size, color: active ? _kPink : const Color(0xFFD2D2D2));
      }),
    );
  }

  /// 비대면 카드 — 평점 2×2 그리드(효과·가성비 / 향·맛·복용 편의성), 셀마다 별 5개.
  Widget _prescriptionRatingCell(String label, int score) {
    final s = score.clamp(0, 5);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 12)),
      decoration: BoxDecoration(
        color: _kGrayBox,
        borderRadius: BorderRadius.circular(healthDp(context, 12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _kMuted2,
              fontSize: healthSp(context, 10),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
              height: 1.65,
            ),
          ),
          SizedBox(height: healthDp(context, 4)),
          _starsRow(s, size: healthDp(context, 16)),
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
          SizedBox(width: healthDp(context, 8)),
          Expanded(child: _prescriptionRatingCell(b, sb)),
        ],
      );
    }

    return Column(
      children: [
        pair('효과', r.isScore1, '가성비', r.isScore2),
        SizedBox(height: healthDp(context, 8)),
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
          style: TextStyle(
            color: _kInk,
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: healthDp(context, 10)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 20),
            vertical: healthDp(context, 10),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(healthDp(context, 12)),
            border: Border.all(
                width: healthDp(context, 1), color: _kBorder),
          ),
          child: Text(
            body,
            style: TextStyle(
              color: _kInk,
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              height: 1.50,
            ),
          ),
        ),
      ],
    );
  }

  /// 리뷰 첨부(`images` 등) 우선, 없으면 상품 썸네일(`productImage` / it_img1 등)
  String? _reviewListImageUrl(ReviewModel r) {
    String? guardNoImg(String? url) {
      final t = (url ?? '').toLowerCase();
      if (t.contains('no_img.png')) return null;
      return url;
    }

    if (r.images.isNotEmpty) {
      return guardNoImg(ImageUrlHelper.getReviewImageUrl(r.images.first));
    }
    final thumb = r.productImage?.trim();
    if (thumb != null && thumb.isNotEmpty) {
      final normalized = ImageUrlHelper.getImageUrl(thumb);
      // 리뷰에 이미지가 없을 때 내려오는 기본 no_img.png는 프록시에서 415가 날 수 있어
      // 리뷰 화면에서는 네트워크로 불러오지 않고 플레이스홀더로 처리한다.
      return guardNoImg(normalized);
    }
    return null;
  }

  Widget _productImage(ReviewModel r) {
    final url = _reviewListImageUrl(r);
    final side = healthDp(context, 80);
    return ClipRRect(
      borderRadius: BorderRadius.circular(healthDp(context, 4)),
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
    return Container(
      color: const Color(0xFFE8E8E8),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        color: _kMuted,
        size: healthDp(context, 32),
      ),
    );
  }

  Widget _productHeaderRow(ReviewModel r) {
    // 수정|삭제 액션은 레이아웃(상품명 줄)과 분리해서 카드 우상단에 고정한다.
    // (텍스트 우측에 붙어 줄바꿈/정렬이 깨지는 것을 방지)
    final rightGutter = healthDp(context, 54);

    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _productImage(r),
            SizedBox(width: healthDp(context, 20)),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: rightGutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _kBrandFallback,
                      style: TextStyle(
                        color: _kInk,
                        fontSize: healthSp(context, 10),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: healthDp(context, 2)),
                    Text(
                      _productTitle(r),
                      style: TextStyle(
                        color: _kInk,
                        fontSize: healthSp(context, 14),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.26,
                        height: 1.25,
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
            ),
          ],
        ),
        Positioned(
          top: 0,
          right: 0,
          child: _headerActionsInline(r),
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
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(width: healthDp(context, 8)),
        Text(
          '|',
          style: TextStyle(
            color: _kHeaderAction,
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: healthDp(context, 6)),
        GestureDetector(
          onTap: enabled ? () => _deleteReview(r) : null,
          child: Text(
            '삭제',
            style: TextStyle(
              color: actionColor,
              fontSize: healthSp(context, 12),
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
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 20),
        vertical: healthDp(context, 5),
      ),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _kPink),
          borderRadius: BorderRadius.circular(healthDp(context, 4)),
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
                    Icon(
                      Icons.local_offer_outlined,
                      color: _kPink,
                      size: healthDp(context, 20),
                    ),
                    SizedBox(width: healthDp(context, 5)),
                    Text(
                      '5% 할인 도움 쿠폰',
                      style: TextStyle(
                        color: _kPink,
                        fontSize: healthSp(context, 12),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: healthDp(context, 6)),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                      fontSize: healthSp(context, 10),
                    ),
                    children: [
                      TextSpan(
                          text: '$n',
                          style: const TextStyle(color: _kPink)),
                      const TextSpan(
                        text: '명이 받았어요!',
                        style: TextStyle(color: _kMuted),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: healthDp(context, 4)),
                Text(
                  '유효기간 : 발급일로부터 7일',
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: healthSp(context, 8),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: healthDp(context, 40),
            height: healthDp(context, 40),
            decoration: BoxDecoration(
              color: const Color(0x19FF5A8D),
              borderRadius: BorderRadius.circular(healthDp(context, 50)),
            ),
            child: Icon(
              Icons.download_rounded,
              color: _kPink,
              size: healthDp(context, 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _expandedPrescriptionCard(ReviewModel r) {
    final children = <Widget>[
      _productHeaderRow(r),
      SizedBox(height: healthDp(context, 10)),
      _prescriptionRatingGrid(r),
    ];

    void appendTextSection(String title, String? raw) {
      final text = (raw ?? '').trim();
      if (text.isEmpty) return;
      children.add(SizedBox(height: healthDp(context, 10)));
      children.add(_prescriptionTextSection(title, text));
    }

    appendTextSection('좋았던 점', r.isPositiveReviewText);
    appendTextSection('아쉬운 점', r.isNegativeReviewText);
    appendTextSection('꿀팁', r.isMoreReviewText);

    children
      ..add(SizedBox(height: healthDp(context, 10)))
      ..add(_couponBanner(r));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 15),
        vertical: healthDp(context, 20),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
        border: Border.all(width: healthDp(context, 1), color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _expandedGeneralCard(ReviewModel r) {
    final starScore = _generalReviewTotalRating(r);
    final body = [
      r.isPositiveReviewText,
      r.isNegativeReviewText,
      r.isMoreReviewText,
    ].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).join('\n\n');

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
          _productHeaderRow(r),
          SizedBox(height: healthDp(context, 10)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _starsRowFromRating(starScore, size: healthDp(context, 18)),
                SizedBox(width: healthDp(context, 8)),
                Text(
                  starScore < 0.5 ? '0.0' : starScore.toStringAsFixed(1),
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
        ],
      ),
    );
  }

  Widget _collapsedTile(ReviewModel r) {
    final listThumb = _reviewListImageUrl(r);
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
              SizedBox(width: healthDp(context, 16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.isTime == null ? '-' : DateDisplayFormatter.formatYmd(r.isTime!),
                      style: TextStyle(
                        color: _kDateBrown,
                        fontSize: healthSp(context, 10),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        height: 1.65,
                      ),
                    ),
                    Text(
                      _productTitle(r),
                      style: TextStyle(
                        color: _kInk,
                        fontSize: healthSp(context, 16),
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
    return SizedBox(
      width: healthDp(context, 140),
      child: TextField(
        onChanged: (v) {
          setState(() {
            _productNameQuery = v;
            _ensureActiveInVisible(_visibleReviews());
          });
        },
        style: TextStyle(
          color: _kMuted,
          fontSize: healthSp(context, 10),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w300,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 10),
            vertical: healthDp(context, 8),
          ),
          hintText: '상품명',
          hintStyle: TextStyle(
            color: _kMuted,
            fontSize: healthSp(context, 10),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
            borderSide: const BorderSide(color: _kBorderStrong),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
            borderSide: const BorderSide(color: _kBorderStrong),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
            borderSide:
                BorderSide(color: _kPink, width: healthDp(context, 1)),
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
        builder: (context) => _reviewUsesGeneralWriteEditor(review)
            ? ReviewWriteGeneralScreen.edit(review: review)
            : ReviewWriteScreen.edit(review: review),
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
      if (result['success'] == true) {
        setState(() {
          _historyHeadId = null;
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
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );
    final textScale =
        healthTextScaleByWidth(MediaQuery.sizeOf(context).width);

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
              titleFontSize: healthSp(context, 18),
              leadingIconSize: healthDp(context, 24),
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
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                SliverPadding(
                                  padding: EdgeInsets.fromLTRB(
                                    healthDp(context, 27),
                                    healthDp(context, 20),
                                    healthDp(context, 27),
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
                                      SizedBox(height: healthDp(context, 24)),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: healthDp(context, 8)),
                                        child: Text(
                                          '이전 리뷰 내역',
                                          style: TextStyle(
                                            color: _kMuted,
                                            fontSize:
                                                healthSp(context, 12),
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
                                    healthDp(context, 27),
                                    0,
                                    healthDp(context, 27),
                                    healthDp(context, 20),
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        if (index == collapsed.length) {
                                          if (_hasMore && !_isLoading) {
                                            scheduleMicrotask(() {
                                              if (mounted) _loadReviews();
                                            });
                                          }
                                          if (_isLoading &&
                                              _reviews.isNotEmpty) {
                                            return Padding(
                                              padding: EdgeInsets.all(
                                                  healthDp(context, 24)),
                                              child: Center(
                                                child: SizedBox(
                                                  width: healthDp(
                                                      context, 36),
                                                  height: healthDp(
                                                      context, 36),
                                                  child:
                                                      const CircularProgressIndicator(
                                                          color: _kPink),
                                                ),
                                              ),
                                            );
                                          }
                                          return SizedBox(
                                              height:
                                                  healthDp(context, 24));
                                        }
                                        return Padding(
                                          padding: EdgeInsets.only(
                                              bottom:
                                                  healthDp(context, 12)),
                                          child: _collapsedTile(
                                              collapsed[index]),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: healthDp(context, 64),
            color: Colors.grey[400],
          ),
          SizedBox(height: healthDp(context, 16)),
          Text(
            '작성한 리뷰가 없습니다',
            style: TextStyle(
              fontSize: healthSp(context, 16),
              color: Colors.grey[600],
              fontFamily: 'Gmarket Sans TTF',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: healthDp(context, 64),
            color: Colors.grey[400],
          ),
          SizedBox(height: healthDp(context, 16)),
          Text(
            '로그인 후 이용 가능합니다.',
            style: TextStyle(
              fontSize: healthSp(context, 16),
              color: Colors.grey[600],
              fontFamily: 'Gmarket Sans TTF',
            ),
          ),
        ],
      ),
    );
  }
}
