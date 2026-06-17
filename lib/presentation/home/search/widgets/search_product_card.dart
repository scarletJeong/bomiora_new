import 'package:flutter/material.dart';

import '../../../../data/models/product/product_model.dart';
import '../../../common/widgets/product_card.dart';
import '../../../health/health_common/health_responsive_scale.dart';

/// 검색 결과 그리드용 상품 카드 — [ProductCatalogCard] 기반, 제목 2줄·설명 없음.
class SearchProductCard extends StatelessWidget {
  static const Color _brandPink = Color(0xFFFF5A8D);
  static const Color _textDark = Color(0xFF231F20);
  static const Color _ratingGrey = Color(0xFF999999);
  static const Color _starGold = Color(0xFFFFCC00);
  static const String _gmarket = 'Gmarket Sans TTF';

  final Product product;
  final VoidCallback onTap;

  const SearchProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  /// 그리드 [mainAxisExtent] — 이미지 185 + 간격·텍스트 영역 합산
  static double preferredMainAxisExtent(BuildContext context) {
    final gap = healthDp(context, 8);
    final titleLineH = healthSp(context, 12) * 1.2;
    final rowH = healthSp(context, 12) * 1.2;
    return healthDp(context, 185) +
        gap +
        titleLineH * 2 +
        gap +
        rowH +
        healthDp(context, 8) +
        healthDp(context, 2);
  }

  @override
  Widget build(BuildContext context) {
    final title = stripProductCatalogHtml(product.name);

    final fsTitle = healthSp(context, 12);
    final fsDiscNum = healthSp(context, 11.70);
    final fsPriceRow = healthSp(context, 12);
    final fsRating = healthSp(context, 7.80);
    final imageHeight = healthDp(context, 185);
    final gap = healthDp(context, 8);
    final hPad = healthDp(context, 8);

    final cardRadius = healthDp(context, 12);

    final titleStyle = TextStyle(
      color: _textDark,
      fontSize: fsTitle,
      fontWeight: FontWeight.w500,
      fontFamily: _gmarket,
      letterSpacing: healthSp(context, -1.08),
      height: 1.2,
    );

    final ratingStyle = TextStyle(
      fontSize: fsRating,
      color: _ratingGrey,
      fontWeight: FontWeight.w500,
      fontFamily: _gmarket,
      height: 1.1,
    );

    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: healthDp(context, 2),
        shadowColor: Colors.black26,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: imageHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    product.displayImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(context),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: SizedBox(
                          width: healthDp(context, 28),
                          height: healthDp(context, 28),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: gap),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: hPad),
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: gap),
                  Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 0, hPad, hPad),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: product.discountRate != null
                              ? Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: product.discountRate!
                                            .toStringAsFixed(0),
                                        style: TextStyle(
                                          fontSize: fsDiscNum,
                                          color: _brandPink,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: _gmarket,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '%  ',
                                        style: TextStyle(
                                          fontSize: fsPriceRow,
                                          color: _brandPink,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: _gmarket,
                                        ),
                                      ),
                                      TextSpan(
                                        text: product.formattedPrice,
                                        style: TextStyle(
                                          fontSize: fsPriceRow,
                                          color: _textDark,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: _gmarket,
                                        ),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : Text(
                                  product.formattedPrice,
                                  style: TextStyle(
                                    fontSize: fsPriceRow,
                                    fontWeight: FontWeight.w700,
                                    color: _textDark,
                                    fontFamily: _gmarket,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                        if ((product.rating ?? 0) > 0 ||
                            (product.reviewCount ?? 0) > 0) ...[
                          SizedBox(width: healthDp(context, 3)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: healthDp(context, 8),
                                color: _starGold,
                              ),
                              SizedBox(width: healthDp(context, 1)),
                              Text(
                                (product.rating ?? 0).toStringAsFixed(1),
                                style: ratingStyle,
                              ),
                              Text(
                                '(${product.reviewCount ?? 0})',
                                style: ratingStyle,
                              ),
                            ],
                          ),
                        ],
                      ],
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

  Widget _placeholder(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.grey[200],
      child: Icon(
        Icons.image_not_supported,
        size: healthDp(context, 40),
        color: Colors.grey[400],
      ),
    );
  }
}
