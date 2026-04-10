import 'package:flutter/material.dart';

/// 비대면 처방 메인 — 카테고리(다이어트/디톡스/심신안정/건강·면역) 바로가기
class ProductMainCategoryIconRow extends StatelessWidget {
  const ProductMainCategoryIconRow({super.key});

  static const _iconSize = 42.0;
  static const _hGap = 25.0;
  static const _lineColor = Color(0xFFD9D9D9);

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
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: _iconSize,
              height: _iconSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _lineColor),
                color: Colors.white,
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF676767)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF676767),
              fontSize: 11,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        // 아이콘 묶음 너비에 맞춘 짧은 회색선
        final grayLineWidth =
            ((maxW * 3 / 4 + _iconSize) * 0.58).clamp(140.0, maxW);

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
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        item(
                          icon: Icons.local_fire_department_outlined,
                          label: '다이어트',
                          onTap: () => goToCategory(
                              categoryId: '10', categoryName: '다이어트'),
                        ),
                        SizedBox(width: _hGap),
                        item(
                          icon: Icons.water_drop_outlined,
                          label: '디톡스',
                          onTap: () => goToCategory(
                              categoryId: '20', categoryName: '디톡스'),
                        ),
                        SizedBox(width: _hGap),
                        item(
                          icon: Icons.self_improvement_outlined,
                          label: '심신안정',
                          onTap: () => goToCategory(
                              categoryId: '80', categoryName: '심신안정'),
                        ),
                        SizedBox(width: _hGap),
                        item(
                          icon: Icons.favorite_border,
                          label: '건강/면역',
                          onTap: () => goToCategory(
                              categoryId: '50', categoryName: '건강/면역'),
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
