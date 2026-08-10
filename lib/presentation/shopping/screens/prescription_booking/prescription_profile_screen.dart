import 'package:flutter/material.dart';
import '../../../../data/models/cart/cart_item_model.dart';
import '../../../user/healthprofile/screens/health_profile_list_screen.dart';

/// 처방 예약 — 문진표 확인 (마이페이지 문진표 리스트와 동일 UI)
class PrescriptionProfileScreen extends StatelessWidget {
  final String productId;
  final String productName;
  final dynamic selectedOptions;
  final List<int>? cartCtIdsForCheckout;
  final List<CartItem>? checkoutCartItems;
  final int? checkoutShippingCost;

  const PrescriptionProfileScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.selectedOptions,
    this.cartCtIdsForCheckout,
    this.checkoutCartItems,
    this.checkoutShippingCost,
  });

  @override
  Widget build(BuildContext context) {
    return HealthProfileListScreen(
      appBarTitle: '진료 예약 중 _ 01 문진표',
      appBarCenterTitle: false,
      prescriptionBooking: HealthProfilePrescriptionBookingArgs(
        productId: productId,
        productName: productName,
        selectedOptions: selectedOptions,
        cartCtIdsForCheckout: cartCtIdsForCheckout,
        checkoutCartItems: checkoutCartItems,
        checkoutShippingCost: checkoutShippingCost,
      ),
    );
  }
}
