import 'package:flutter/material.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../common/widgets/web_dragscroll.dart';
import 'home_section_widgets.dart';

/// Figma 기준 폭 375에 맞춘 웰니스 PICK 카드 레이아웃 — [healthTextScaleByWidth]로 스케일.
class WellnessSection extends StatelessWidget {
  const WellnessSection({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final s = healthTextScaleByWidth(w);

    double d(num v) => v.toDouble() * s;

    final cardW = d(317.31);
    final listH = d(172.50 + 12 + 90.50);
    final gapCards = d(12);
    final iw = d(317.31).round();
    final ih = d(172.50).round();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: healthDp(context, 24)),
            child: const HomeSectionTitleRow(
              line1: '나만의',
              line2: '웰니스 Pick!',
            ),
          ),
          SizedBox(height: healthDp(context, 12)),
          SizedBox(
            height: listH,
            child: WebDragScrollConfiguration(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: healthDp(context, 24)),
                itemCount: 3,
                separatorBuilder: (_, __) => SizedBox(width: gapCards),
                itemBuilder: (context, index) {
                  return _WellnessPickCard(
                    scale: s,
                    cardWidth: cardW,
                    title: '김동은 원장의 필라테스 요가 강의 커밍순!',
                    description:
                        '김동은 원장의 필라테스 강의 커밍순! 로봇처럼 정확하지만\n인간미가 넘치는 필라테스 강의 지금 신청하세요.',
                    originalPrice: '8,888,000원',
                    discountLabel: '26%',
                    salePrice: '8,888,000원',
                    imageUrl: ImageUrlHelper.placeholdCo(iw, ih),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WellnessPickCard extends StatelessWidget {
  final double scale;
  final double cardWidth;
  final String title;
  final String description;
  final String originalPrice;
  final String discountLabel;
  final String salePrice;
  final String imageUrl;

  const _WellnessPickCard({
    required this.scale,
    required this.cardWidth,
    required this.title,
    required this.description,
    required this.originalPrice,
    required this.discountLabel,
    required this.salePrice,
    required this.imageUrl,
  });

  double d(num v) => v.toDouble() * scale;

  @override
  Widget build(BuildContext context) {
    final imgH = d(172.50);
    final imgPad = d(5.77);
    final imgRadius = d(11.54);
    final infoH = d(90.50);
    final colGap = d(12);
    final titleDescGap = d(6.92);
    final strikeSaleGap = d(0.58);

    final titleSize = d(14);
    final bodySize = d(10);
    final priceAccentSize = d(14);

    return SizedBox(
      width: cardWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(imgRadius),
            child: Container(
              width: cardWidth,
              height: imgH,
              color: const Color(0xFFFFE9EA),
              padding: EdgeInsets.all(imgPad),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFFFFE9EA),
                ),
              ),
            ),
          ),
          SizedBox(height: colGap),
          SizedBox(
            height: infoH,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF231F20),
                        fontSize: titleSize,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: titleDescGap),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF898686),
                        fontSize: bodySize,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                        height: 1.35,
                        letterSpacing: -0.50,
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        originalPrice,
                        style: TextStyle(
                          color: const Color(0xFF898686),
                          fontSize: bodySize,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      SizedBox(height: strikeSaleGap),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$discountLabel  ',
                              style: TextStyle(
                                color: const Color(0xFFFF5A8D),
                                fontSize: priceAccentSize,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextSpan(
                              text: salePrice,
                              style: TextStyle(
                                color: const Color(0xFF231F20),
                                fontSize: priceAccentSize,
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
          ),
        ],
      ),
    );
  }
}
