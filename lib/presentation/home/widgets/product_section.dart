import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';
import '../../common/widgets/web_dragscroll.dart';
import 'btn_more.dart';
import 'home_big_card.dart';
import 'home_section_widgets.dart';

class ProductSection extends StatelessWidget {
  const ProductSection({super.key});

  static const String _kTitle = '보미 다이어트환 신제품 출시! 보미 다이어트환';
  static const String _kDescription =
      '쉬워지는 다이어트 보미 다이어트환! 드디어 7~9단계가 출시\n됐습니다. 기존 단계로 효과를 못보신 분들께 적합합니다.';

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final m = HomeBigCardLayout.fromWidth(w);
    final iw = m.cardW.round();
    final ih = m.imageH.round();
    final placeholderUrl = 'https://placehold.co/${iw}x$ih';

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
              line1: 'New',
              line2: 'Product',
              trailing: BtnMore(),
            ),
          ),
          SizedBox(height: healthDp(context, 12)),
          SizedBox(
            height: m.listItemHeight,
            child: WebDragScrollConfiguration(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: healthDp(context, 24)),
                itemCount: 3,
                separatorBuilder: (_, __) =>
                    SizedBox(width: m.rowGapBetweenCards),
                itemBuilder: (_, __) => _ProductCard(
                  m: m,
                  imageUrl: placeholderUrl,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.m,
    required this.imageUrl,
  });

  final HomeBigCardLayout m;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: m.cardW,
      height: m.listItemHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(m.radius),
            child: SizedBox(
              width: m.cardW,
              height: m.imageH,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFFFFE9EA),
                ),
              ),
            ),
          ),
          SizedBox(height: m.columnGap),
          SizedBox(
            width: m.cardW,
            height: m.textPanelHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ProductSection._kTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF231F20),
                    fontSize: m.titleFs,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
                SizedBox(height: m.titleDescGap),
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      ProductSection._kDescription,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF231F20),
                        fontSize: m.descFs,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                        letterSpacing: m.descLetterSpacing,
                        height: 1.35,
                      ),
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
