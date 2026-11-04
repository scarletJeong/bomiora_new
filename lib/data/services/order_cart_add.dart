import '../models/cart/cart_item_model.dart';
import '../models/delivery/delivery_model.dart';
import '../../core/logging/failure_log.dart';
import 'auth_service.dart';
import 'cart_service.dart';

enum OrderCartAddStatus { success, needsLogin, failed, partialLeft }

class OrderCartAddResult {
  const OrderCartAddResult._({
    required this.status,
    this.items = const [],
    this.ctIds = const [],
  });

  final OrderCartAddStatus status;
  final List<CartItem> items;
  final List<int> ctIds;

  static const needsLogin = OrderCartAddResult._(
    status: OrderCartAddStatus.needsLogin,
  );
  static const failed = OrderCartAddResult._(
    status: OrderCartAddStatus.failed,
  );

  const OrderCartAddResult.success({
    required List<CartItem> items,
    required List<int> ctIds,
  }) : this._(
          status: OrderCartAddStatus.success,
          items: items,
          ctIds: ctIds,
        );

  static const partialLeft = OrderCartAddResult._(
    status: OrderCartAddStatus.partialLeft,
  );
}

/// 주문 다시 담기. 목록과 상세가 같은 규칙으로 장바구니에 넣는다.
class OrderCartAdd {
  OrderCartAdd._();

  static Future<OrderCartAddResult> addProducts({
    required List<OrderItem> products,
    required bool prescription,
  }) async {
    final user = await AuthService.getUser();
    if (user == null) return OrderCartAddResult.needsLogin;

    final defaultKind = prescription ? 'prescription' : 'general';
    final addedItems = <CartItem>[];
    final addedCtIds = <int>[];
    var missingId = false;
    String? sharedOdId;

    try {
      for (final product in products) {
        if (product.itId.trim().isEmpty) continue;

        final qty = product.ctQty > 0 ? product.ctQty : 1;
        var kind = (product.ctKind ?? product.itKind ?? defaultKind).trim();
        if (kind.toLowerCase().startsWith('supply_add|')) {
          kind = defaultKind;
        }
        if (kind.isEmpty) kind = defaultKind;

        final price = product.ctPrice > 0
            ? product.ctPrice
            : (product.totalPrice > 0 ? product.totalPrice : 0);
        final optionText = (product.ctOption ?? '').trim();
        final optionId = (product.ioId ?? '').trim();
        final parentItId = (product.parent ?? '').trim();

        final result = await CartService.addToCart(
          productId: product.itId,
          quantity: qty,
          price: price,
          optionId: optionId.isEmpty ? null : optionId,
          optionText: optionText.isEmpty ? null : optionText,
          optionPrice: product.ioPrice,
          ioType: product.ioType,
          odId: sharedOdId,
          ctKind: kind,
          parentItId: parentItId.isEmpty ? null : parentItId,
          ctStatus: '쇼핑',
          mbId: user.id,
        );

        if (result['success'] != true) {
          return _fail(
            mbId: user.id,
            reason: result['message']?.toString() ?? '장바구니 담기에 실패했습니다.',
            ctIds: addedCtIds,
            missingId: missingId,
          );
        }

        final data = result['data'];
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final ctId = CartService.ctIdFromCartResponseData(map);
          if (ctId != null && ctId > 0) {
            addedCtIds.add(ctId);
          } else {
            missingId = true;
          }
          sharedOdId ??= (map['od_id'] ?? map['odId'])?.toString();
          addedItems.add(CartItem.fromJson(map));
        } else {
          missingId = true;
        }
      }
    } catch (e) {
      return _fail(
        mbId: user.id,
        reason: e.toString(),
        ctIds: addedCtIds,
        missingId: missingId,
      );
    }

    if (addedItems.isEmpty) {
      await FailureLog.record(
        code: 'order.reorder',
        mbId: user.id,
        reason: '담을 상품이 없습니다.',
      );
      return OrderCartAddResult.failed;
    }

    return OrderCartAddResult.success(items: addedItems, ctIds: addedCtIds);
  }

  static Future<OrderCartAddResult> _fail({
    required String mbId,
    required String reason,
    required List<int> ctIds,
    required bool missingId,
  }) async {
    await FailureLog.record(
      code: 'order.reorder',
      mbId: mbId,
      reason: reason,
    );
    if (ctIds.isEmpty && !missingId) return OrderCartAddResult.failed;

    if (ctIds.isNotEmpty) {
      final removed = await CartService.removeCartItems(ctIds);
      if (removed['success'] != true || missingId) {
        await FailureLog.record(
          code: 'order.reorder.rollback',
          mbId: mbId,
          reason: missingId
              ? '담은 줄의 장바구니 번호를 찾지 못했습니다.'
              : (removed['message']?.toString() ?? '장바구니에서 되돌리지 못했습니다.'),
        );
        return OrderCartAddResult.partialLeft;
      }
      return OrderCartAddResult.failed;
    }

    await FailureLog.record(
      code: 'order.reorder.rollback',
      mbId: mbId,
      reason: '담은 줄의 장바구니 번호를 찾지 못했습니다.',
    );
    return OrderCartAddResult.partialLeft;
  }
}
