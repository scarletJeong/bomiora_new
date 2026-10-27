import 'package:flutter/material.dart';

import '../../../data/models/product/product_model.dart';
import '../../health/health_common/health_responsive_scale.dart';
import 'app_network_image.dart';

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

/// `it_subject`가 병원명·브레드크럼(보미오라 한의원)인지
bool isBomioraHospitalProductSubject(String strippedSubject) {
  final t = strippedSubject.trim();
  if (t.isEmpty) return false;
  return RegExp(r'보미오라\s*한의원', caseSensitive: false).hasMatch(t);
}

/// `it_subject`를 카드 상단 1줄 라벨로 쓸 수 있는지 (병원 브레드크럼 제외)
bool shouldShowProductCardSubject(String strippedSubject) {
  final t = strippedSubject.trim();
  if (t.isEmpty) return false;
  if (isBomioraHospitalProductSubject(t)) return false;
  return true;
}

/// 비대면 처방·일반 상품 목록 공통 카드 (2열 그리드 Figma)
class ProductCatalogCard extends StatelessWidget {
  static const Color _brandPink = Color(0xFFFF5A8D);
  static const Color _textDark = Color(0xFF1A1A1E);
  static const Color _categoryMuted = Color(0xFF898686);
  static const String _gmarket = 'Gmarket Sans TTF';

  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onImageSettled;

  const ProductCatalogCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onImageSettled,
  });

  /// 한 줄 높이. 시안 텍스트 박스(74)는 글꼴 기본 줄간격보다 짧아 가격이 잘린다.
  static double _textLineH(BuildContext context, double baseFont) {
    return (healthSp(context, baseFont) * 1.2).ceilToDouble();
  }

  /// 브랜드 10 + 간격 4 + 제목 2줄 14 + 간격 10 + 가격 14
  static double textBlockHeight(BuildContext context) {
    return _textLineH(context, 10) +
        healthDp(context, 4) +
        _textLineH(context, 14) * 2 +
        healthDp(context, 10) +
        _textLineH(context, 14);
  }

  /// 그리드 [mainAxisExtent] — 이미지 180 + 간격 10 + 텍스트 영역 (375 기준)
  static double preferredMainAxisExtent(BuildContext context) {
    return healthDp(context, 180) +
        healthDp(context, 10) +
        textBlockHeight(context);
  }

  static double preferredAspectRatio(BuildContext context, double cellWidth) {
    final extent = preferredMainAxisExtent(context);
    if (extent <= 0) return 0.58;
    return cellWidth / extent;
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

  @override
  Widget build(BuildContext context) {
    final title = stripProductCatalogHtml(product.name);
    final category = _categoryLabel();

    final imageH = healthDp(context, 180);
    final imageRadius = healthDp(context, 10);
    final imageGap = healthDp(context, 10);
    final catTitleGap = healthDp(context, 4);
    final priceGap = healthDp(context, 4);
    final textBlockH = textBlockHeight(context);

    final fsCategory = healthSp(context, 10);
    final fsTitle = healthSp(context, 14);
    final fsPrice = healthSp(context, 14);

    final categoryStyle = TextStyle(
      color: _categoryMuted,
      fontSize: fsCategory,
      fontFamily: _gmarket,
      fontWeight: FontWeight.w500,
      height: 1.2,
    );

    final titleStyle = TextStyle(
      color: _textDark,
      fontSize: fsTitle,
      fontFamily: _gmarket,
      fontWeight: FontWeight.w500,
      letterSpacing: healthSp(context, -0.28),
      height: 1.2,
    );

    final pricePinkStyle = TextStyle(
      color: _brandPink,
      fontSize: fsPrice,
      fontFamily: _gmarket,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );

    final priceDarkStyle = TextStyle(
      color: _textDark,
      fontSize: fsPrice,
      fontFamily: _gmarket,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );

    return GestureDetector(
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
                child: product.displayImageUrl.isNotEmpty
                    ? AppNetworkImage(
                        url: product.displayImageUrl,
                        width: double.infinity,
                        height: imageH,
                        decodeHeightLogical: imageH,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        onSettled: onImageSettled,
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
                      )
                    : _placeholder(context),
              ),
            ),
          ),
          SizedBox(height: imageGap),
          SizedBox(
            height: textBlockH,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: categoryStyle,
                    ),
                    SizedBox(height: catTitleGap),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ],
                ),
                Row(
                  children: [
                    if ((product.discountRate ?? 0) > 0) ...[
                      Text(
                        '${product.discountRate!.round()}%',
                        style: pricePinkStyle,
                      ),
                      SizedBox(width: priceGap),
                    ],
                    Expanded(
                      child: Text(
                        product.formattedPrice,
                        style: priceDarkStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
