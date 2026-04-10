import 'package:flutter/material.dart';

/// 비대면 처방 메인 — 카테고리(다이어트/디톡스/심신안정/건강·면역) 바로가기
class ProductMainCategoryIconRow extends StatelessWidget {
  const ProductMainCategoryIconRow({super.key});

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
      return SizedBox(
        width: 78,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD9D9D9)),
                  color: Colors.white,
                ),
                child: Icon(icon, size: 20, color: const Color(0xFF676767)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF676767),
                fontSize: 11,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        item(
          icon: Icons.local_fire_department_outlined,
          label: '다이어트',
          onTap: () => goToCategory(categoryId: '10', categoryName: '다이어트'),
        ),
        item(
          icon: Icons.water_drop_outlined,
          label: '디톡스',
          onTap: () => goToCategory(categoryId: '20', categoryName: '디톡스'),
        ),
        item(
          icon: Icons.self_improvement_outlined,
          label: '심신안정',
          onTap: () => goToCategory(categoryId: '80', categoryName: '심신안정'),
        ),
        item(
          icon: Icons.favorite_border,
          label: '건강/면역',
          onTap: () => goToCategory(categoryId: '50', categoryName: '건강/면역'),
        ),
      ],
    );
  }
}
