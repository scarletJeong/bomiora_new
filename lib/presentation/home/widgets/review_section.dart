import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/review/main_home_review_model.dart';
import '../../../data/services/review_service.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../review/screens/review_best_screen.dart';
import 'home_section_widgets.dart';

/// 베스트 리뷰 화면과 동일 — `mr_img` 우선, 없으면 상품 썸네일
String? _mainHomeReviewCardImageUrl(MainHomeReviewModel r) {
  if (r.images.isNotEmpty) {
    return ImageUrlHelper.getMainReviewImageUrl(r.images.first);
  }
  final productImage = r.productImage?.trim();
  if (productImage != null && productImage.isNotEmpty) {
    return ImageUrlHelper.getImageUrl(productImage);
  }
  return null;
}

/// Figma 375 기준 리뷰 카드·그리드 치수 — [healthDp] / [healthSp]로 스케일.
class _ReviewCardLayout {
  const _ReviewCardLayout({
    required this.cardHeight,
    required this.radius,
    required this.overlayLeft,
    required this.overlayTop,
    required this.overlayWidth,
    required this.overlayHeight,
    required this.textColumnGap,
    required this.nameFontSize,
    required this.bodyFontSize,
    required this.gridCrossSpacing,
    required this.gridMainSpacing,
    required this.titleToGridGap,
  });

  final double cardHeight;
  final double radius;
  final double overlayLeft;
  final double overlayTop;
  final double overlayWidth;
  final double overlayHeight;
  final double textColumnGap;
  final double nameFontSize;
  final double bodyFontSize;
  final double gridCrossSpacing;
  final double gridMainSpacing;
  final double titleToGridGap;

  factory _ReviewCardLayout.fromContext(BuildContext context) {
    return _ReviewCardLayout(
      cardHeight: healthDp(context, 199.62),
      radius: healthDp(context, 10),
      overlayLeft: healthDp(context, 5),
      overlayTop: healthDp(context, 136.48),
      overlayWidth: healthDp(context, 145),
      overlayHeight: healthDp(context, 51),
      textColumnGap: healthDp(context, 8),
      nameFontSize: healthSp(context, 14),
      bodyFontSize: healthSp(context, 10),
      gridCrossSpacing: healthDp(context, 10),
      gridMainSpacing: healthDp(context, 10),
      titleToGridGap: healthDp(context, 18),
    );
  }
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
    final layout = _ReviewCardLayout.fromContext(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeSectionTitleRow(
            line1: 'BEST',
            line2: '리뷰',
          ),
          SizedBox(height: layout.titleToGridGap),
          _buildGridBody(context, layout),
          SizedBox(height: healthDp(context, 48)),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const ReviewBestScreen(),
                ),
              );
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: SizedBox(
                    height: healthDp(context, 1),
                    child: const ColoredBox(color: Color(0xFFE0E0E0)),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 12),
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 20),
                      vertical: healthDp(context, 6),
                    ),
                    decoration: ShapeDecoration(
                      color: const Color(0xFFFF5A8D),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 17.88)),
                      ),
                    ),
                    child: Text(
                      '+ 리뷰 더 보기',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: healthSp(context, 12),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: healthDp(context, 1),
                    child: const ColoredBox(color: Color(0xFFE0E0E0)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridBody(BuildContext context, _ReviewCardLayout layout) {
    if (_loading) {
      return SizedBox(
        height: layout.cardHeight * 2 + layout.gridMainSpacing,
        child: Center(
          child: SizedBox(
            width: healthDp(context, 28),
            height: healthDp(context, 28),
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_reviews.isEmpty) {
      final iconSz = healthDp(context, 40);
      return SizedBox(
        height: healthDp(context, 100),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                AppAssets.emptyProductReviewIcon,
                width: iconSz,
                height: iconSz,
                fit: BoxFit.contain,
              ),
              SizedBox(height: healthDp(context, 8)),
              Text(
                '등록된 리뷰가 없습니다.',
                style: TextStyle(
                  color: const Color(0x995B3F43),
                  fontSize: healthSp(context, 13),
                  fontFamily: 'Gmarket Sans TTF',
                ),
              ),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: layout.cardHeight,
        crossAxisSpacing: layout.gridCrossSpacing,
        mainAxisSpacing: layout.gridMainSpacing,
      ),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        final r = _reviews[index];
        final thumb = _mainHomeReviewCardImageUrl(r);
        final fallbackThumb = r.productImage != null &&
                r.productImage!.trim().isNotEmpty
            ? ImageUrlHelper.getImageUrl(r.productImage)
            : null;
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ReviewBestScreen(initialMrNo: r.mrNo),
              ),
            );
          },
          child: _ReviewCard(
            layout: layout,
            titleLine: r.reviewerName,
            bodyLine: r.cardTitleText,
            imageUrl: thumb,
            fallbackImageUrl: fallbackThumb,
          ),
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final _ReviewCardLayout layout;
  final String titleLine;
  final String bodyLine;
  final String? imageUrl;
  final String? fallbackImageUrl;

  const _ReviewCard({
    required this.layout,
    required this.titleLine,
    required this.bodyLine,
    this.imageUrl,
    this.fallbackImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final m = layout;
    return ClipRRect(
      borderRadius: BorderRadius.circular(m.radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? _ReviewCardImage(
                    primaryUrl: imageUrl!,
                    fallbackUrl: fallbackImageUrl,
                    fit: BoxFit.cover,
                  )
                : const ColoredBox(color: Color(0xFFE0E0E0)),
          ),
          // 리뷰 목록 카드와 동일 핑크 그라데이션
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(0.5, 0),
                end: Alignment(0.5, 0.69),
                colors: [
                  Color(0x00FFFFFF),
                  Color(0x00FF96B6),
                  Color(0x7FFF5A8D),
                ],
              ),
            ),
          ),
          Positioned(
            left: m.overlayLeft,
            top: m.overlayTop,
            width: m.overlayWidth,
            height: m.overlayHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  titleLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: m.nameFontSize,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    shadows: const [
                      Shadow(blurRadius: 4, color: Color(0x66000000)),
                    ],
                  ),
                ),
                SizedBox(height: m.textColumnGap),
                Expanded(
                  child: Text(
                    bodyLine,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: m.bodyFontSize,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                      height: 1.38,
                      shadows: const [
                        Shadow(blurRadius: 4, color: Color(0x66000000)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCardImage extends StatefulWidget {
  final String primaryUrl;
  final String? fallbackUrl;
  final BoxFit fit;

  const _ReviewCardImage({
    required this.primaryUrl,
    this.fallbackUrl,
    this.fit = BoxFit.cover,
  });

  @override
  State<_ReviewCardImage> createState() => _ReviewCardImageState();
}

class _ReviewCardImageState extends State<_ReviewCardImage> {
  @override
  Widget build(BuildContext context) {
    return Image.network(
      widget.primaryUrl,
      fit: widget.fit,
      alignment: Alignment.center,
      errorBuilder: (_, __, ___) {
        final fallback = widget.fallbackUrl;
        if (fallback != null &&
            fallback.isNotEmpty &&
            fallback != widget.primaryUrl) {
          return Image.network(
            fallback,
            fit: widget.fit,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFFE0E0E0)),
          );
        }
        return Container(color: const Color(0xFFE0E0E0));
      },
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
    );
  }
}
