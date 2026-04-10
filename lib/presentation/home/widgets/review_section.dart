import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/review/main_home_review_model.dart';
import '../../../data/services/review_service.dart';

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
      if (result['success'] == true && result['reviews'] is List<MainHomeReviewModel>) {
        _reviews = List<MainHomeReviewModel>.from(result['reviews'] as List<MainHomeReviewModel>);
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
                child: Container(
                  height: 1,
                  color: const Color(0xFFE0E0E0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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
                child: Container(
                  height: 1,
                  color: const Color(0xFFE0E0E0),
                ),
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
        final thumb = r.images.isNotEmpty
            ? ImageUrlHelper.getReviewImageUrl(r.images.first)
            : null;
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

  /// 좁은 화면: 오버레이 PNG 세로 보정
  static const double _overlayNudgeYNarrow = 0;
  /// 가로 450 초과: 곡선 위치 맞추려 조금 더 아래로
  static const double _overlayNudgeYWide = 60;
  static const double _overlayNudgeWideBreakpoint = 450;

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
    final screenW = MediaQuery.sizeOf(context).width;
    final nudgeY = screenW > _overlayNudgeWideBreakpoint
        ? _overlayNudgeYWide
        : _overlayNudgeYNarrow;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFE0E0E0),
                    ),
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
                : Container(
                    color: const Color(0xFFE0E0E0),
                  ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: _overlayOpacity,
              child: Transform.translate(
                offset: Offset(0, nudgeY),
                child: Image.asset(
                  AppAssets.reviewCardOverlay,
                  fit: BoxFit.cover,
                  alignment: Alignment.bottomCenter,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 2,
                        height: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
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
                            height: 1.5,
                            shadows: [
                              Shadow(
                                blurRadius: 4,
                                color: Color(0x66000000),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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
                        Shadow(
                          blurRadius: 4,
                          color: Color(0x66000000),
                        ),
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
