import 'package:flutter/material.dart';

import '../../../../../core/utils/image_url_helper.dart';
import '../../../../../core/utils/price_formatter.dart';
import '../../../../../data/models/delivery/delivery_model.dart';
import '../../../../health/health_common/health_responsive_scale.dart';
import '../order_item_subject_groups.dart';
import 'delivery_detail_products_section.dart';
import 'delivery_detail_section_style.dart';

/// 일반상품 주문상세 — `it_subject` 묶음배송 주문상품 섹션
class DeliveryDetailGeneralProductsSection extends StatelessWidget {
  const DeliveryDetailGeneralProductsSection({
    super.key,
    required this.order,
    this.onCancelTap,
    this.actions = const [],
  });

  final OrderDetailModel order;
  /// 헤더 우측 밑줄 '주문취소'
  final VoidCallback? onCancelTap;
  final List<
      ({
        String label,
        VoidCallback? onTap,
        DeliveryDetailProductActionStyle style,
      })> actions;

  @override
  Widget build(BuildContext context) {
    final products = order.products;
    final groups = groupOrderItemsByItSubject(products);

    return Container(
      width: double.infinity,
      padding: DeliveryDetailSectionStyle.cardPadding(context),
      decoration: DeliveryDetailSectionStyle.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '주문상품 (${products.length})',
                  style: TextStyle(
                    color: DeliveryDetailSectionStyle.ink,
                    fontSize: healthSp(context, 16),
                    fontFamily: DeliveryDetailSectionStyle.font,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -1.44,
                  ),
                ),
              ),
              if (onCancelTap != null)
                GestureDetector(
                  onTap: onCancelTap,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    '주문취소',
                    style: TextStyle(
                      color: DeliveryDetailSectionStyle.muted,
                      fontSize: healthSp(context, 12),
                      fontFamily: DeliveryDetailSectionStyle.font,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor: DeliveryDetailSectionStyle.muted,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: healthDp(context, 10)),
          Container(
            width: double.infinity,
            height: healthDp(context, 0.5),
            color: const Color(0x7FD2D2D2),
          ),
          SizedBox(height: healthDp(context, 10)),
          for (var gi = 0; gi < groups.length; gi++) ...[
            if (gi > 0) ...[
              SizedBox(height: healthDp(context, 10)),
              Container(
                width: double.infinity,
                height: healthDp(context, 0.5),
                color: const Color(0x7FD2D2D2),
              ),
              SizedBox(height: healthDp(context, 10)),
            ],
            _subjectGroup(
              context,
              subject: groups[gi].key,
              items: groups[gi].value,
            ),
          ],
          if (actions.isNotEmpty) ...[
            SizedBox(height: healthDp(context, 10)),
            Container(
              width: double.infinity,
              height: healthDp(context, 1),
              color: const Color(0xFFE8E8E8),
            ),
            SizedBox(height: healthDp(context, 10)),
            _actionRow(context),
          ],
        ],
      ),
    );
  }

  Widget _subjectGroup(
    BuildContext context, {
    required String subject,
    required List<OrderItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (subject.isNotEmpty)
          Text(
            subject,
            style: TextStyle(
              color: DeliveryDetailSectionStyle.muted,
              fontSize: healthSp(context, 12),
              fontFamily: DeliveryDetailSectionStyle.font,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (subject.isNotEmpty) SizedBox(height: healthDp(context, 10)),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(height: healthDp(context, 10)),
          _productRow(context, items[i]),
        ],
      ],
    );
  }

  Widget _productRow(BuildContext context, OrderItem product) {
    final thumb = healthDp(context, 72);
    final normalizedUrl =
        product.imageUrl != null && product.imageUrl!.isNotEmpty
            ? ImageUrlHelper.normalizeThumbnailUrl(
                product.imageUrl,
                product.itId,
              )
            : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: thumb,
          height: thumb,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F3F3),
            borderRadius: BorderRadius.circular(healthDp(context, 4)),
          ),
          clipBehavior: Clip.antiAlias,
          child: normalizedUrl == null
              ? Icon(
                  Icons.image,
                  color: DeliveryDetailSectionStyle.muted,
                  size: healthDp(context, 28),
                )
              : Image.network(
                  normalizedUrl,
                  width: thumb,
                  height: thumb,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.image,
                    color: DeliveryDetailSectionStyle.muted,
                    size: healthDp(context, 28),
                  ),
                ),
        ),
        SizedBox(width: healthDp(context, 10)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OrderItemTitleOptionBlock(
                title: orderItemDisplayTitle(product),
                qtyOptionLine: orderItemQtyOptionLine(product),
                titleStyle: TextStyle(
                  color: DeliveryDetailSectionStyle.ink,
                  fontSize: healthSp(context, 14),
                  fontFamily: DeliveryDetailSectionStyle.font,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -1.26,
                ),
                optionStyle: TextStyle(
                  color: DeliveryDetailSectionStyle.mutedLabel,
                  fontSize: healthSp(context, 10),
                  fontFamily: DeliveryDetailSectionStyle.font,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.90,
                ),
              ),
              SizedBox(height: healthDp(context, 5)),
              Text(
                '${PriceFormatter.format(product.totalPrice)}원',
                style: TextStyle(
                  color: DeliveryDetailSectionStyle.ink,
                  fontSize: healthSp(context, 14),
                  fontFamily: DeliveryDetailSectionStyle.font,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionRow(BuildContext context) {
    final gap = healthDp(context, 10);
    if (actions.length == 1 &&
        actions.first.style == DeliveryDetailProductActionStyle.outlineGray) {
      return InkWell(
        onTap: actions.first.onTap,
        borderRadius: BorderRadius.circular(healthDp(context, 9999)),
        child: Container(
          width: double.infinity,
          height: healthDp(context, 34),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: healthDp(context, 1),
                color: const Color(0xFFE5E7EB),
              ),
              borderRadius: BorderRadius.circular(healthDp(context, 9999)),
            ),
          ),
          child: Text(
            actions.first.label,
            style: TextStyle(
              color: DeliveryDetailSectionStyle.muted,
              fontSize: healthSp(context, 12),
              fontFamily: DeliveryDetailSectionStyle.font,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(child: _actionButton(context, actions[i])),
        ],
      ],
    );
  }

  Widget _actionButton(
    BuildContext context,
    ({
      String label,
      VoidCallback? onTap,
      DeliveryDetailProductActionStyle style,
    }) spec,
  ) {
    late final Color bg;
    late final Color fg;
    Color? border;

    switch (spec.style) {
      case DeliveryDetailProductActionStyle.primary:
        bg = DeliveryDetailSectionStyle.pink;
        fg = Colors.white;
        border = null;
      case DeliveryDetailProductActionStyle.outlinePink:
        bg = Colors.white;
        fg = DeliveryDetailSectionStyle.pink;
        border = DeliveryDetailSectionStyle.pink;
      case DeliveryDetailProductActionStyle.outlineGray:
        bg = Colors.white;
        fg = DeliveryDetailSectionStyle.muted;
        border = const Color(0xFFE5E7EB);
    }

    return InkWell(
      onTap: spec.onTap,
      borderRadius: BorderRadius.circular(healthDp(context, 50)),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: healthDp(context, 10)),
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: bg,
          shape: RoundedRectangleBorder(
            side: border == null
                ? BorderSide.none
                : BorderSide(width: healthDp(context, 1), color: border),
            borderRadius: BorderRadius.circular(healthDp(context, 50)),
          ),
        ),
        child: Text(
          spec.label,
          style: TextStyle(
            color: fg,
            fontSize: healthSp(context, 12),
            fontFamily: DeliveryDetailSectionStyle.font,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
