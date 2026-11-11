import 'package:flutter/material.dart';

import '../../../core/logging/failure_log.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/delivery_service.dart';
import '../../../data/services/order_cart_add.dart';
import '../../common/widgets/app_toast_overlay.dart';
import '../../shopping/utils/cart_navigation.dart';

/// 목록의 재주문하기·다시 담기.
Future<void> reorderFromOrderList(
  BuildContext context,
  OrderListModel order,
) async {
  final user = await AuthService.getUser();
  if (user == null) {
    if (!context.mounted) return;
    AppToastOverlay.show(context, '로그인이 필요합니다.');
    return;
  }

  late final List<OrderItem> products;
  try {
    final detailResult = await OrderService.getOrderDetail(
      odId: order.odId,
      mbId: user.id,
    );
    if (detailResult['success'] != true ||
        detailResult['order'] is! OrderDetailModel) {
      await _reportOrderProductsFailure(
        context,
        mbId: user.id,
        odId: order.odId,
        cause: detailResult['message']?.toString() ??
            '주문 상품을 불러오지 못했습니다.',
      );
      return;
    }
    products = (detailResult['order'] as OrderDetailModel).products;
  } catch (e) {
    await _reportOrderProductsFailure(
      context,
      mbId: user.id,
      odId: order.odId,
      cause: e.toString(),
    );
    return;
  }

  if (products.isEmpty) {
    if (!context.mounted) return;
    AppToastOverlay.show(context, '재주문할 상품 정보를 찾을 수 없습니다.');
    return;
  }

  final added = await OrderCartAdd.addProducts(
    products: products,
    prescription: order.isPrescriptionOrder,
  );
  if (!context.mounted) return;
  if (!_showReorderResult(context, added)) return;
  await CartNavigation.openCart(
    context,
    prescriptionTab: order.isPrescriptionOrder,
  );
}

Future<void> _reportOrderProductsFailure(
  BuildContext context, {
  required String mbId,
  required String odId,
  required String cause,
}) async {
  const message = '주문 상품을 불러오지 못했습니다.';
  await FailureLog.record(
    code: 'order.products',
    mbId: mbId,
    reason: message,
    detail: {
      'odId': odId,
      if (cause.isNotEmpty && cause != message) 'cause': cause,
    },
  );
  if (!context.mounted) return;
  AppToastOverlay.show(context, message);
}

bool _showReorderResult(BuildContext context, OrderCartAddResult result) {
  switch (result.status) {
    case OrderCartAddStatus.needsLogin:
      AppToastOverlay.show(context, '로그인이 필요합니다.');
      return false;
    case OrderCartAddStatus.failed:
      AppToastOverlay.show(context, '장바구니 담기에 실패했습니다.');
      return false;
    case OrderCartAddStatus.partialLeft:
      AppToastOverlay.show(context, '일부 상품이 장바구니에 남아 있습니다.');
      return false;
    case OrderCartAddStatus.success:
      AppToastOverlay.show(context, '장바구니에 담았습니다.');
      return true;
  }
}
