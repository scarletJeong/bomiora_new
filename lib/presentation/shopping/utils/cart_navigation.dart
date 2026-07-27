import 'package:flutter/material.dart';

import '../../../data/services/prescription_purchase_history_service.dart';
import '../screens/cart_general_screen.dart' as cart_general;
import '../screens/cart_integration_screen.dart';

/// 장바구니 담기 후 바로가기 등 — 구매 이력에 따라 통합/분리 장바구니로 이동.
class CartNavigation {
  CartNavigation._();

  /// [prescriptionTab] true: 비대면 탭(또는 처방 전용 장바구니), false: 일반상품 탭(또는 일반 장바구니)
  static Future<void> openCart(
    BuildContext context, {
    bool prescriptionTab = false,
  }) async {
    final useIntegrated =
        await PrescriptionPurchaseHistoryService.shouldUseIntegratedCart();
    if (!context.mounted) return;

    if (useIntegrated) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CartIntegrationScreen(
            initialTabIndex: prescriptionTab ? 0 : 1,
          ),
        ),
      );
      return;
    }

    if (prescriptionTab) {
      await Navigator.pushNamed(context, '/cart');
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const cart_general.CartScreen(),
      ),
    );
  }
}
