import 'package:flutter/material.dart';

import '../../../../../data/models/delivery/delivery_model.dart';
import '../../../../health/health_common/health_responsive_scale.dart';
import 'delivery_detail_products_section.dart';
import 'delivery_detail_reservation_section.dart';
import 'delivery_detail_section_style.dart';

/// 진료 예약 일정 + 주문상품이 합쳐진 카드 (결제완료 등)
class DeliveryDetailReservationProductsCard extends StatelessWidget {
  const DeliveryDetailReservationProductsCard({
    super.key,
    required this.order,
    this.showChangeButton = false,
    this.onChangeTap,
    this.asConsultDone = false,
    this.actions = const [],
  });

  final OrderDetailModel order;
  final bool showChangeButton;
  final VoidCallback? onChangeTap;
  /// 상담완료 시 제목을 「진료 완료」로 표시
  final bool asConsultDone;
  final List<
      ({
        String label,
        VoidCallback? onTap,
        DeliveryDetailProductActionStyle style,
      })> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: DeliveryDetailSectionStyle.cardPadding(context),
      decoration: DeliveryDetailSectionStyle.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DeliveryDetailReservationSection(
            order: order,
            showChangeButton: showChangeButton,
            onChangeTap: onChangeTap,
            asCard: false,
            iconColor: DeliveryDetailSectionStyle.muted,
            titleText: asConsultDone ? '진료 완료' : null,
          ),
          SizedBox(height: healthDp(context, 20)),
          Container(
            width: double.infinity,
            height: 1,
            color: const Color(0xFFE8E8E8),
          ),
          SizedBox(height: healthDp(context, 20)),
          DeliveryDetailProductsSection(
            order: order,
            actions: actions,
            asCard: false,
          ),
        ],
      ),
    );
  }
}
