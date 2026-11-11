import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';
import '../utils/get_product.dart';

/// 장바구니 비어 있을 때 — 상품 목록(카테고리)으로 이동
class CartEmptyShopButton extends StatelessWidget {
  final bool prescriptionTab;

  const CartEmptyShopButton({
    super.key,
    required this.prescriptionTab,
  });

  void _onTap(BuildContext context) {
    if (prescriptionTab) {
      final cat = productPrescriptionCategoryListFallback.firstWhere(
        (e) => e.categoryId == '10',
        orElse: () => productPrescriptionCategoryListFallback.first,
      );
      Navigator.pushNamed(
        context,
        '/product/',
        arguments: {
          'categoryId': cat.categoryId,
          'categoryName': cat.label,
          'productKind': 'prescription',
        },
      );
      return;
    }

    final cat = productGeneralCategoryListFallback.first;
    Navigator.pushNamed(
      context,
      '/product-general/',
      arguments: {
        'categoryId': cat.categoryId,
        'categoryName': cat.label,
        'productKind': 'general',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTap(context),
          borderRadius: BorderRadius.circular(healthDp(context, 50)),
          child: Container(
            height: healthDp(context, 40),
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 18),
            ),
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: const Color(0xFFFF5A8D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 50)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '상품 보러 가기',
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: healthSp(context, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
