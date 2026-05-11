import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../utils/get_product.dart';

/// 상품 리스트 상단 카테고리 바로가기
class ProductMainCategoryTap extends StatelessWidget {
  /// 'prescription' | 'general'
  final String productKind;

  /// `true`이면 동그라미·아이콘을 더 작게(상품 목록 상단 등).
  final bool compact;

  const ProductMainCategoryTap({
    super.key,
    required this.productKind,
    this.compact = false,
  });

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
    final circleDiameter = healthDp(context, compact ? 56 : 80);
    final svgSize = healthDp(context, compact ? 17 : 24);
    final hGap = healthDp(context, compact ? 16 : 22);

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
            width: circleDiameter,
            height: circleDiameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: _lineColor,
                width: healthDp(context, 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: healthDp(context, 8),
                  offset: Offset(0, healthDp(context, 2)),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              healthDp(context, compact ? 4 : 6),
              healthDp(context, compact ? 6 : 10),
              healthDp(context, compact ? 4 : 6),
              healthDp(context, compact ? 5 : 8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                SvgPicture.asset(
                  svgAsset,
                  width: svgSize,
                  height: svgSize,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: healthDp(context, compact ? 2 : 4)),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF676767),
                    fontSize: healthSp(context, compact ? 7.5 : 8),
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
            ((maxW * 3 / 4 + circleDiameter) * 0.58).clamp(140.0, maxW);

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
                    padding:
                        EdgeInsets.symmetric(horizontal: healthDp(context, 12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(categories.length, (i) {
                        final c = categories[i];
                        final asset = svgAssets[i.clamp(0, svgAssets.length - 1)];
                        return Padding(
                          padding: EdgeInsets.only(
                            right: i == categories.length - 1 ? 0 : hGap,
                          ),
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
            SizedBox(height: healthDp(context, 20)),
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
