import '../../../../data/models/cart/cart_item_model.dart';

/// 처방 예약 플로우에서 문진표 확인·작성 시 전달
class HealthProfilePrescriptionBookingArgs {
  final String productId;
  final String productName;
  final dynamic selectedOptions;
  final List<int>? cartCtIdsForCheckout;
  final List<CartItem>? checkoutCartItems;
  final int? checkoutShippingCost;

  /// 문진표 화면을 먼저 연 뒤, 장바구니 반영 결과를 나중에 받는다.
  final Future<List<CartItem>>? checkoutItemsFuture;

  const HealthProfilePrescriptionBookingArgs({
    required this.productId,
    required this.productName,
    this.selectedOptions,
    this.cartCtIdsForCheckout,
    this.checkoutCartItems,
    this.checkoutShippingCost,
    this.checkoutItemsFuture,
  });

  Future<List<CartItem>> resolveCheckoutItems() async {
    final ready = checkoutCartItems;
    if (ready != null && ready.isNotEmpty) return ready;
    final pending = checkoutItemsFuture;
    if (pending == null) return const [];
    try {
      return await pending;
    } catch (_) {
      return const [];
    }
  }

  /// 담기가 이미 끝났으면 그 결과, 아직이면 null.
  Future<List<CartItem>?> peekCheckoutItems() async {
    final ready = checkoutCartItems;
    if (ready != null && ready.isNotEmpty) return ready;
    final pending = checkoutItemsFuture;
    if (pending == null) return const [];

    List<CartItem>? value;
    var settled = false;
    pending.then((items) {
      value = items;
      settled = true;
    }, onError: (Object _, StackTrace __) {
      value = const [];
      settled = true;
    });
    await Future<void>.delayed(Duration.zero);
    if (!settled) return null;
    return value ?? const [];
  }

  static List<Map<String, dynamic>> optionMapsFromItems(List<CartItem> items) {
    return items
        .map(
          (item) => <String, dynamic>{
            'it_id': item.itId,
            'it_name': item.itName,
            'id': item.ioId ?? '',
            'name': item.displayOptionText.isNotEmpty
                ? item.displayOptionText
                : item.itName,
            'price': item.ioPrice ?? 0,
            'quantity': item.ctQty,
            'totalPrice': item.ctPrice,
            'ct_kind': item.ctKind,
          },
        )
        .toList();
  }
}
