import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/logging/failure_log.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/product/product_model.dart';
import '../../../data/services/auth_service.dart';
import '../../health/health_common/health_responsive_scale.dart';
import 'app_clickable.dart';
import 'product_card.dart';

/// 홈 New Product 카드 (375 기준: 이미지 칸 150×170).
class ProductMainCard extends StatelessWidget {
  static final Set<String> _loggedImageUrls = {};
  static const Color _brandPink = Color(0xFFFF5A8D);
  static const Color _textDark = Color(0xFF1A1A1A);
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

  static const double _lineHeight = 1.2;

  static double _lineH(BuildContext context, double baseFont) {
    return (healthSp(context, baseFont) * _lineHeight).ceilToDouble() + 1;
  }

  /// 카테고리 1줄 + 제목 2줄 + 가격. 폰트 하단이 잘리지 않게 여백을 더한다.
  static double textBlockHeight(BuildContext context) {
    return _lineH(context, 10) +
        healthDp(context, 4) +
        _lineH(context, 14) * 2 +
        healthDp(context, 10) +
        _lineH(context, 14) +
        healthDp(context, 6);
  }

  /// 이미지 칸 170 + 간격 10 + 텍스트 블록
  static double preferredMainAxisExtent(BuildContext context) {
    return healthDp(context, 170) +
        healthDp(context, 10) +
        textBlockHeight(context);
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

    final imageUrl =
        ImageUrlHelper.productGridThumbUrl(product.displayImageUrl);
    final imageW = preferredCardWidth(context);
    final slotH = healthDp(context, 170);
    final imageRadius = healthDp(context, 11.54);
    final blockGap = healthDp(context, 10);
    final textH = textBlockHeight(context);
    final titleH = _lineH(context, 14) * 2;
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
                height: slotH,
                child: ColoredBox(
                  color: const Color(0xFFF3F3F3),
                  child: imageUrl.isNotEmpty
                      ? ProductCoverRatioImage(
                          url: imageUrl,
                          onSettled: onImageSettled,
                          errorBuilder: (_, error, __) {
                            _logImageFailure(imageUrl, error);
                            return _placeholder(context);
                          },
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
                  SizedBox(
                    height: titleH,
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textDark,
                        fontSize: fsTitle,
                        fontFamily: _gmarket,
                        fontWeight: FontWeight.w500,
                        height: _lineHeight,
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

  void _logImageFailure(String url, Object error) {
    if (!_loggedImageUrls.add(url)) return;
    unawaited(
      FailureLog.record(
        code: 'home.product.image',
        mbId: AuthService.currentUser?.id ?? '',
        reason: '상품 사진을 불러오지 못했습니다.',
        detail: {
          'url': url,
          'itId': product.id,
          'error': error.toString(),
        },
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
        color: const Color(0xFF898686),
      ),
    );
  }
}
