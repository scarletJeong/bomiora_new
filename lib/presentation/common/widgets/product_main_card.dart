import 'package:flutter/material.dart';

import '../../../data/models/product/product_model.dart';
import '../../health/health_common/health_responsive_scale.dart';
import 'app_clickable.dart';
import 'app_network_image.dart';
import 'product_card.dart';

/// 홈 New Product 카드 (375 기준: 이미지 150×170 + 텍스트 74).
class ProductMainCard extends StatelessWidget {
  static const Color _brandPink = Color(0xFFFF5A8D);
  static const Color _textDark = Color(0xFF1A1A1E);
  static const Color _categoryMuted = Color(0xFF898686);
  static const String _gmarket = 'Gmarket Sans TTF';
  static const String _bomioraHospitalLabel = '보미오라 한의원';

  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onImageSettled;

  const ProductMainCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onImageSettled,
  });

  static double preferredCardWidth(BuildContext context) =>
      healthDp(context, 150);

  /// 이미지 170 + 간격 10 + 텍스트 74
  static double preferredMainAxisExtent(BuildContext context) {
    return healthDp(context, 170) +
        healthDp(context, 10) +
        healthDp(context, 74);
  }

  bool get _isPrescriptionProduct =>
      product.productKind != null && product.productKind != 'general';

  String _categoryLabel() {
    final subject = stripProductCatalogHtml(product.itSubject ?? '');

    if (isBomioraHospitalProductSubject(subject)) {
      return _bomioraHospitalLabel;
    }
    if (shouldShowProductCardSubject(subject)) {
      return subject;
    }
    if (_isPrescriptionProduct) {
      return _bomioraHospitalLabel;
    }
    final name = stripProductCatalogHtml(product.categoryName);
    if (name.isNotEmpty && name != '기타') return name;
    return '헬스케어';
  }

  @override
  Widget build(BuildContext context) {
    final title = stripProductCatalogHtml(product.name);
    final category = _categoryLabel();
    final hasDiscount =
        product.discountRate != null && product.discountRate! > 0;

    final imageW = healthDp(context, 150);
    final imageH = healthDp(context, 170);
    final imageRadius = healthDp(context, 11.54);
    final blockGap = healthDp(context, 10);
    final textH = healthDp(context, 74);
    final innerGap = healthDp(context, 4);
    final priceGap = healthDp(context, 4);

    final fsCategory = healthSp(context, 10);
    final fsTitle = healthSp(context, 14);
    final fsPrice = healthSp(context, 14);

    return AppClickable(
      onTap: onTap,
      child: SizedBox(
        width: imageW,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(imageRadius),
              child: SizedBox(
                width: imageW,
                height: imageH,
                child: ColoredBox(
                  color: const Color(0xFFF3F3F3),
                  child: product.displayImageUrl.isNotEmpty
                      ? AppNetworkImage(
                          url: product.displayImageUrl,
                          width: imageW,
                          height: imageH,
                          decodeWidthLogical: imageW,
                          decodeHeightLogical: imageH,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          onSettled: onImageSettled,
                          errorBuilder: (_, __, ___) => _placeholder(context),
                        )
                      : _placeholder(context),
                ),
              ),
            ),
            SizedBox(height: blockGap),
            SizedBox(
              width: double.infinity,
              height: textH,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _categoryMuted,
                      fontSize: fsCategory,
                      fontFamily: _gmarket,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: innerGap),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textDark,
                        fontSize: fsTitle,
                        fontFamily: _gmarket,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(height: blockGap),
                  Row(
                    children: [
                      if (hasDiscount) ...[
                        Text(
                          '${product.discountRate!.round()}%',
                          style: TextStyle(
                            color: _brandPink,
                            fontSize: fsPrice,
                            fontFamily: _gmarket,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(width: priceGap),
                      ],
                      Flexible(
                        child: Text(
                          product.formattedPrice,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _textDark,
                            fontSize: fsPrice,
                            fontFamily: _gmarket,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
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
