import '../../../data/models/cart/cart_item_model.dart';

/// 처방 예약 플로우에서 문진표 확인·작성 시 전달
class HealthProfilePrescriptionBookingArgs {
  final String productId;
  final String productName;
  final dynamic selectedOptions;
  final List<int>? cartCtIdsForCheckout;
  final List<CartItem>? checkoutCartItems;
  final int? checkoutShippingCost;

  const HealthProfilePrescriptionBookingArgs({
    required this.productId,
    required this.productName,
    this.selectedOptions,
    this.cartCtIdsForCheckout,
    this.checkoutCartItems,
    this.checkoutShippingCost,
  });
}
