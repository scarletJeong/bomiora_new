import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/review/main_home_review_model.dart';
import '../../../data/services/review_service.dart';

/// 메인 리뷰 `mr_img` — `it_id/파일` 형태가 아니면 `itId`를 붙여 상품 리뷰와 같은 itemuse URL 생성
String? _mainHomeReviewCardImageUrl(MainHomeReviewModel r) {
  if (r.images.isEmpty) return null;
  var raw = r.images.first.trim();
  if (raw.isEmpty) return null;
  if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
    raw = raw.replaceAll('\\', '/');
    while (raw.startsWith('/')) {
      raw = raw.substring(1);
    }
    const prefix = 'data/itemuse/';
    if (raw.startsWith(prefix)) {
      raw = raw.substring(prefix.length);
    }
    if (!raw.contains('/') && (r.itId?.trim().isNotEmpty ?? false)) {
      raw = '${r.itId!.trim()}/$raw';
    }
  }
  return ImageUrlHelper.getReviewImageUrl(raw);
}

class ReviewSection extends StatefulWidget {
  const ReviewSection({super.key});

  @override
  State<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<ReviewSection> {
  static const int _fetchSize = 8;

  bool _loading = true;
  List<MainHomeReviewModel> _reviews = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ReviewService.getMainHomeReviews(size: _fetchSize);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true &&
          result['reviews'] is List<MainHomeReviewModel>) {
        _reviews = List<MainHomeReviewModel>.from(
            result['reviews'] as List<MainHomeReviewModel>);
      } else {
        _reviews = [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 2,
                    height: 40,
                    color: const Color(0xFF28171A),
                  ),
                  const SizedBox(width: 6),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'BEST',
                        style: TextStyle(
                          color: Color(0x665B3F43),
                          fontSize: 10,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '리뷰',
                        style: TextStyle(
                          color: Color(0xFF28171A),
                          fontSize: 20,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: ShapeDecoration(
                  color: const Color(0xFFFF5A8D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
                child: const Text(
                  '+ More',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 0),
          Transform.translate(
            offset: const Offset(0, -35),
            child: _buildGridBody(),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Container(height: 1, color: const Color(0xFFE0E0E0)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFF5A8D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                  child: const Text(
                    '리뷰 더보기',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(height: 1, color: const Color(0xFFE0E0E0)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridBody() {
    if (_loading) {
      return const SizedBox(
        height: 185 * 2 + 8,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_reviews.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: Text(
            '등록된 리뷰가 없습니다.',
            style: TextStyle(
              color: Color(0x995B3F43),
              fontSize: 13,
              fontFamily: 'Gmarket Sans TTF',
            ),
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 185,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        final r = _reviews[index];
        final thumb = _mainHomeReviewCardImageUrl(r);
        return _ReviewCard(
          titleLine: r.headline,
          bodyLine: r.bodyText,
          imageUrl: thumb,
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  static const double _overlayOpacity = 0.9;

  final String titleLine;
  final String bodyLine;
  final String? imageUrl;

  const _ReviewCard({
    required this.titleLine,
    required this.bodyLine,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 배경 이미지
          Positioned.fill(
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) =>
                        Container(color: const Color(0xFFE0E0E0)),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: const Color(0xFFE8E8E8),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                  )
                : Container(color: const Color(0xFFE0E0E0)),
          ),

          // 핑크 오버레이
          Positioned.fill(
            child: Opacity(
              opacity: _overlayOpacity,
              child: ClipPath(
                clipper: BottomCurveClipper(),
                child: const ColoredBox(color: Color(0xFFFF8EAC)),
              ),
            ),
          ),

          // 텍스트 — `bottom:0`만 쓰면 블록이 카드 맨 아래에 붙어 위쪽 핑크가 빈 것처럼 보임.
          // 핑크 수평 경계(flatY)부터 영역을 잡아 제목이 핑크 상단에 붙도록 함.
          Positioned(
            left: 0,
            right: 0,
            top: BottomCurveClipper.flatY,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 2,
                        height: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          titleLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            shadows: [
                              Shadow(
                                  blurRadius: 4,
                                  color: Color(0x66000000)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    bodyLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w400,
                      height: 1.45,
                      shadows: [
                        Shadow(blurRadius: 4, color: Color(0x66000000)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 이미지2 기준:
/// - 핑크가 하단을 차지
/// - 경계선: x=0 에서 가장 높이 올라와 있고(왼쪽 상단 꼭짓점)
///   오른쪽으로 곡선을 그리며 내려오다가 수평이 됨
/// - 곡선은 concave(오목): 핑크 영역 안쪽으로 파임
///
/// Path 논리 (size = 클리퍼에 주어진 전체 크기):
///   시작: (0, topY)          ← 왼쪽, 가장 높은 지점
///   베지어 제어점: (0, flatY) ← 왼쪽 벽을 따라 아래로
///   베지어 끝점: (curveEndX, flatY) ← 수평선과 만나는 지점
///   직선: (width - r, flatY) … (width, flatY+r) ← 오른쪽 상단 모서리 라운드
///   직선: (width, height)    ← 오른쪽 하단
///   직선: (0, height)        ← 왼쪽 하단
class BottomCurveClipper extends CustomClipper<Path> {
  // 수평 기준선 y (카드 상단에서 얼마나 아래인가 — 고정값)
  // 카드높이 185 기준, 핑크가 약 40% = 74px → topY = 185 - 74 = 111
  static const double flatY = 111.0;

  // 왼쪽 꼭짓점이 flatY보다 얼마나 위로 올라가는가
  static const double riseAmount = 36.0;

  // 곡선이 수평선(flatY)에 닿는 x 위치
  static const double curveEndX = 56.0;

  /// 수평선과 오른쪽 변이 만나는 꼭짓점을 둥글게 (카드 오른쪽 상단 느낌과 맞춤)
  static const double topRightCornerRadius = 12.0;

  @override
  Path getClip(Size size) {
    const double topY = flatY - riseAmount; // 왼쪽 꼭짓점 y
    final path = Path()..moveTo(0, topY);

    path.quadraticBezierTo(0, flatY, curveEndX, flatY);

    final maxR = math.min(
      topRightCornerRadius,
      math.min(
        (size.width - curveEndX) * 0.5,
        (size.height - flatY).clamp(0.0, double.infinity),
      ),
    );
    var r = maxR.clamp(0.0, topRightCornerRadius);
    if (r > 0 && size.width - r < curveEndX) {
      r = math.max(0.0, size.width - curveEndX - 0.5);
    }

    if (r <= 0) {
      path
        ..lineTo(size.width, flatY)
        ..lineTo(size.width, size.height);
    } else {
      path
        ..lineTo(size.width - r, flatY)
        ..quadraticBezierTo(size.width, flatY, size.width, flatY + r)
        ..lineTo(size.width, size.height);
    }

    path
      ..lineTo(0, size.height)
      ..close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}