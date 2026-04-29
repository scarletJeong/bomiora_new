import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_assets.dart';
import '../../utils/get_product.dart';

/// 상품 리스트 상단 카테고리 바로가기
class ProductMainCategoryTap extends StatelessWidget {
  /// 'prescription' | 'general'
  final String productKind;

  const ProductMainCategoryTap({
    super.key,
    required this.productKind,
  });

  static const _circleDiameter = 80.0;
  static const _svgSize = 24.0;
  static const _hGap = 22.0;
  static const _lineColor = Color(0xFFD9D9D9);

  static const List<String> _prescriptionSvgAssets = [
    AppAssets.generalMainIcon1, // 다이어트
    AppAssets.generalMainIcon2, // 디톡스
    AppAssets.generalMainIcon4, // 심신안정
    AppAssets.generalMainIcon3, // 건강/면역
  ];

  static const List<String> _generalSvgAssets = [
    AppAssets.generalMainIcon1, // 다이어트
    AppAssets.generalMainIcon2, // 디톡스
    AppAssets.generalMainIcon3, // 건강/면역
    AppAssets.generalMainIcon5, // 뷰티/코스메틱
    AppAssets.generalMainIcon6, // 헤어/탈모
  ];

  @override
  Widget build(BuildContext context) {
    final isGeneral = productKind == 'general';
    final categories =
        isGeneral ? productGeneralCategoryList : productPrescriptionCategoryList;
    final svgAssets = isGeneral ? _generalSvgAssets : _prescriptionSvgAssets;

    void goToCategory({
      required String categoryId,
      required String categoryName,
    }) {
      Navigator.pushNamed(
        context,
        isGeneral ? '/product-general/' : '/product/',
        arguments: {
          'categoryId': categoryId,
          'categoryName': categoryName,
          'productKind': isGeneral ? 'general' : 'prescription',
        },
      );
    }

    Widget item({
      required String svgAsset,
      required String label,
      required VoidCallback onTap,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: _circleDiameter,
            height: _circleDiameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _lineColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                SvgPicture.asset(
                  svgAsset,
                  width: _svgSize,
                  height: _svgSize,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF676767),
                    fontSize: 9.5,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final grayLineWidth =
            ((maxW * 3 / 4 + _circleDiameter) * 0.58).clamp(140.0, maxW);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: maxW,
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(categories.length, (i) {
                        final c = categories[i];
                        final asset = svgAssets[i.clamp(0, svgAssets.length - 1)];
                        return Padding(
                          padding: EdgeInsets.only(right: i == categories.length - 1 ? 0 : _hGap),
                          child: item(
                            svgAsset: asset,
                            label: c.label,
                            onTap: () => goToCategory(
                              categoryId: c.categoryId,
                              categoryName: c.label,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                width: grayLineWidth,
                child: const Divider(
                  height: 1,
                  thickness: 1,
                  color: _lineColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
