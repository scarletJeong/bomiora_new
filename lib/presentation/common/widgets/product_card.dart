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

  const ProductCatalogCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  /// 텍스트 `height: 1.2` 한 줄 높이 (레이아웃·extent 계산 공통)
  static double _textLineH(BuildContext context, double baseFont) {
    return (healthSp(context, baseFont) * 1.2).ceilToDouble();
  }

  /// 그리드 [mainAxisExtent] — 이미지 185 + 텍스트 영역 (375 기준, 제목 2줄 고정)
  static double preferredMainAxisExtent(BuildContext context) {
    final imageH = healthDp(context, 185);
    final imageGap = healthDp(context, 8);
    final catH = _textLineH(context, 8);
    final titleGap = healthDp(context, 2);
    final titleH = _textLineH(context, 12) * 2;
    final blockGap = healthDp(context, 8);
    final priceH = _textLineH(context, 10);
    // 폰트 메트릭·스케일 반올림으로 인한 미세 overflow 방지
    return imageH +
        imageGap +
        catH +
        titleGap +
        titleH +
        blockGap +
        priceH +
        1;
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

    final imageH = healthDp(context, 185);
    final imageRadius = healthDp(context, 10);
    final imageGap = healthDp(context, 8);
    final catTitleGap = healthDp(context, 2);
    final blockGap = healthDp(context, 8);
    final priceGap = healthDp(context, 4);

    final fsCategory = healthSp(context, 8);
    final fsTitle = healthSp(context, 12);
    final fsPrice = healthSp(context, 10);
    final titleLetterSpacing = healthSp(context, -1.08);
    final titleAreaH = _textLineH(context, 12) * 2;

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
      letterSpacing: titleLetterSpacing,
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
                    ? Image.network(
                        product.displayImageUrl,
                        width: double.infinity,
                        height: imageH,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: categoryStyle,
                  ),
                  SizedBox(height: catTitleGap),
                  SizedBox(
                    height: titleAreaH,
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
                ],
              ),
              SizedBox(height: healthDp(context, 1)),
              Row(
                children: [
                  Text(
                    '${(product.discountRate ?? 0).round()}%',
                    style: pricePinkStyle,
                  ),
                  SizedBox(width: priceGap),
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
