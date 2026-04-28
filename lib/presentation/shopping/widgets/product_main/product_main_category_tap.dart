import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_assets.dart';

/// 비대면 처방 메인 — 카테고리(다이어트/디톡스/심신안정/건강·면역) 바로가기
class ProductMainCategoryTap extends StatelessWidget {
  const ProductMainCategoryTap({super.key});

  static const _circleDiameter = 80.0;
  static const _svgSize = 24.0;
  static const _hGap = 22.0;
  static const _lineColor = Color(0xFFD9D9D9);

  /// 탭 순서: 다이어트, 디톡스, 심신안정, 건강/면역 — `AppAssets.generalMainIcon1~4` 매핑
  static const List<String> _categorySvgAssets = [
    AppAssets.generalMainIcon1,
    AppAssets.generalMainIcon2,
    AppAssets.generalMainIcon4,
    AppAssets.generalMainIcon3,
  ];

  @override
  Widget build(BuildContext context) {
    void goToCategory({
      required String categoryId,
      required String categoryName,
    }) {
      Navigator.pushNamed(
        context,
        '/product/',
        arguments: {
          'categoryId': categoryId,
          'categoryName': categoryName,
          'productKind': 'prescription',
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
                      children: [
                        item(
                          svgAsset: _categorySvgAssets[0],
                          label: '다이어트',
                          onTap: () => goToCategory(
                            categoryId: '10',
                            categoryName: '다이어트',
                          ),
                        ),
                        SizedBox(width: _hGap),
                        item(
                          svgAsset: _categorySvgAssets[1],
                          label: '디톡스',
                          onTap: () => goToCategory(
                            categoryId: '20',
                            categoryName: '디톡스',
                          ),
                        ),
                        SizedBox(width: _hGap),
                        item(
                          svgAsset: _categorySvgAssets[2],
                          label: '심신안정',
                          onTap: () => goToCategory(
                            categoryId: '80',
                            categoryName: '심신안정',
                          ),
                        ),
                        SizedBox(width: _hGap),
                        item(
                          svgAsset: _categorySvgAssets[3],
                          label: '건강/면역',
                          onTap: () => goToCategory(
                            categoryId: '50',
                            categoryName: '건강/면역',
                          ),
                        ),
                      ],
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
