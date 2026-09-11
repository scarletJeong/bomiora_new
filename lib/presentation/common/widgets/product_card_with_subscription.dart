import 'package:flutter/material.dart';

import '../../../data/models/product/product_model.dart';
import '../../health/health_common/health_responsive_scale.dart';
import 'app_clickable.dart';
import 'app_network_image.dart';
import 'product_card.dart';

/// 설명 포함 상품 카드 (375 기준: 이미지 150×170 + 텍스트 102).
/// 설명은 `it_basic` → `description` 순입니다.
class ProductCardWithSubscription extends StatelessWidget {
  static const Color _brandPink = Color(0xFFFF5A8D);
  static const Color _textDark = Color(0xFF1A1A1E);
  static const Color _descColor = Color(0xFF1A1A1A);
  static const Color _categoryMuted = Color(0xFF898686);
  static const String _gmarket = 'Gmarket Sans TTF';

  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onImageSettled;
  final bool showMoreOverlay;

  const ProductCardWithSubscription({
    super.key,
    required this.product,
    required this.onTap,
    this.onImageSettled,
    this.showMoreOverlay = false,
  });

  static double preferredCardWidth(BuildContext context) =>
      healthDp(context, 150);

  /// 이미지 170 + 간격 10 + 텍스트 102
  static double preferredMainAxisExtent(BuildContext context) {
    return healthDp(context, 170) +
        healthDp(context, 10) +
        healthDp(context, 102);
  }

  static const String _bomioraHospitalLabel = '보미오라 한의원';

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

  String _description() {
    final basic = stripProductCatalogHtml(product.itBasic);
    if (basic.isNotEmpty) return basic;
    return stripProductCatalogHtml(product.description);
  }

  @override
  Widget build(BuildContext context) {
    final title = stripProductCatalogHtml(product.name);
    final category = _categoryLabel();
    final desc = _description();
    final hasDiscount =
        product.discountRate != null && product.discountRate! > 0;

    final imageW = healthDp(context, 150);
    final imageH = healthDp(context, 170);
    final imageRadius = healthDp(context, 10);
    final blockGap = healthDp(context, 10);
    final textH = healthDp(context, 102);
    final innerGap = healthDp(context, 4);
    final priceGap = healthDp(context, 4);

    final fsCategory = healthSp(context, 10);
    final fsTitle = healthSp(context, 14);
    final fsDesc = healthSp(context, 10);
    final fsPrice = healthSp(context, 14);
    final descLetterSpacing = healthSp(context, -0.50);

    return AppClickable(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(imageRadius),
            child: SizedBox(
              width: double.infinity,
              height: imageH,
              child: ColoredBox(
                color: const Color(0xFFF3F3F3),
                child: _buildImage(context, imageW, imageH),
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
                Text(
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
                if (desc.isNotEmpty) ...[
                  SizedBox(height: innerGap),
                  Expanded(
                    child: Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _descColor,
                        fontSize: fsDesc,
                        fontFamily: _gmarket,
                        fontWeight: FontWeight.w300,
                        letterSpacing: descLetterSpacing,
                        height: 1.2,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
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
    );
  }

  Widget _buildImage(BuildContext context, double imageW, double imageH) {
    final image = product.displayImageUrl.isNotEmpty
        ? AppNetworkImage(
            url: product.displayImageUrl,
            width: double.infinity,
            height: imageH,
            decodeWidthLogical: imageW,
            decodeHeightLogical: imageH,
            fit: BoxFit.fill,
            alignment: Alignment.center,
            onSettled: onImageSettled,
            errorBuilder: (_, __, ___) => _placeholder(context),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Center(
                child: SizedBox(
                  width: healthDp(context, 28),
                  height: healthDp(context, 28),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
          )
        : _placeholder(context);

    if (!showMoreOverlay) return image;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: image),
        const ColoredBox(color: Color(0x40FF5A8D)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: healthDp(context, 34),
              ),
              SizedBox(height: healthDp(context, 6)),
              Text(
                'More',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: healthSp(context, 12),
                  fontFamily: _gmarket,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
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
