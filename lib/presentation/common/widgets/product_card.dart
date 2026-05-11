import 'package:flutter/material.dart';

import '../../../data/models/product/product_model.dart';
import '../../health/health_common/health_responsive_scale.dart';

/// 상품 목록/그리드용 HTML·엔티티 제거 (카드 타이틀·요약)
String stripProductCatalogHtml(String? raw) {
  if (raw == null) return '';
  var s = raw.replaceAll(RegExp(r'<[^>]*>'), ' ');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

/// `it_subject`에 붙는 병원명·브레드크럼(예: 보미오라 한의원 >)만 카드 2줄로 쓰지 않음
bool shouldShowProductCardSubject(String strippedSubject) {
  final t = strippedSubject.trim();
  if (t.isEmpty) return false;
  if (RegExp(r'보미오라\s*한의원', caseSensitive: false).hasMatch(t)) {
    return false;
  }
  return true;
}

/// 비대면 처방·일반 상품 목록 공통 카드 (`ProductListScreen` Figma 타이포 기준)
class ProductCatalogCard extends StatelessWidget {
  static const Color _brandPink = Color(0xFFFF5A8D);
  static const Color _textDark = Color(0xFF231F20);
  static const Color _ratingGrey = Color(0xFF999999);
  static const Color _starGold = Color(0xFFFFCC00);
  static const String _gmarket = 'Gmarket Sans TTF';

  final Product product;
  final VoidCallback onTap;

  const ProductCatalogCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final namePlain = stripProductCatalogHtml(product.name);
    final subjectPlain = stripProductCatalogHtml(product.itSubject);
    final basicPlain = stripProductCatalogHtml(
      product.itBasic ?? product.description,
    );

    final fsTitle = healthSp(context, 12.18);
    final fsBody = healthSp(context, 8.77);
    final fsDiscNum = healthSp(context, 11.70);
    final fsPriceRow = healthSp(context, 12);
    final fsRating = healthSp(context, 7.80);
    final fsOrig = healthSp(context, 10);

    return LayoutBuilder(
      builder: (context, itemConstraints) {
        final imageHeight = itemConstraints.hasBoundedHeight
            ? itemConstraints.maxHeight * 0.58
            : healthDp(context, 220);

        final cardRadius = healthDp(context, 12);
        final innerPad = EdgeInsets.fromLTRB(
          healthDp(context, 8),
          healthDp(context, 8),
          healthDp(context, 8),
          healthDp(context, 6),
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
            elevation: healthDp(context, 2),
            shadowColor: Colors.black26,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: imageHeight,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(cardRadius),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        product.imageUrl != null
                            ? Image.network(
                                product.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _placeholder(context),
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
                              )
                            : _placeholder(context),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: innerPad,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                namePlain,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _textDark,
                                  fontSize: fsTitle,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: _gmarket,
                                  height: 1.2,
                                ),
                              ),
                              if (shouldShowProductCardSubject(subjectPlain)) ...[
                                SizedBox(height: healthDp(context, 3)),
                                Text(
                                  subjectPlain,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _textDark,
                                    fontSize: fsTitle,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: _gmarket,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                              if (basicPlain.isNotEmpty) ...[
                                SizedBox(height: healthDp(context, 6)),
                                Text(
                                  basicPlain,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _textDark,
                                    fontSize: fsBody,
                                    fontWeight: FontWeight.w300,
                                    fontFamily: _gmarket,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (product.originalPrice != null &&
                            product.originalPrice! > product.price) ...[
                          Text(
                            product.formattedOriginalPrice ?? '',
                            style: TextStyle(
                              fontSize: fsOrig,
                              color: Colors.grey[600],
                              decoration: TextDecoration.lineThrough,
                              fontFamily: _gmarket,
                            ),
                          ),
                          SizedBox(height: healthDp(context, 4)),
                        ],
                        Row(
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
