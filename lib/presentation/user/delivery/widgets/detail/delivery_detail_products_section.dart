import 'package:flutter/material.dart';

import '../../../../../core/utils/image_url_helper.dart';
import '../../../../../core/utils/price_formatter.dart';
import '../../../../../data/models/delivery/delivery_model.dart';
import '../../../../health/health_common/health_responsive_scale.dart';
import 'delivery_detail_section_style.dart';

enum DeliveryDetailProductActionStyle { primary, outlinePink, outlineGray }

/// 주문상품 섹션
class DeliveryDetailProductsSection extends StatelessWidget {
  const DeliveryDetailProductsSection({
    super.key,
    required this.order,
    this.actions = const [],
    this.asCard = true,
  });

  final OrderDetailModel order;
  final List<
      ({
        String label,
        VoidCallback? onTap,
        DeliveryDetailProductActionStyle style,
      })> actions;
  /// false면 바깥 카드 없이 내용만 렌더 (합쳐진 카드용)
  final bool asCard;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '주문상품 ( ${order.products.length} )',
          style: TextStyle(
            color: DeliveryDetailSectionStyle.ink,
            fontSize: healthSp(context, asCard ? 16 : 12),
            fontFamily: DeliveryDetailSectionStyle.font,
            fontWeight: FontWeight.w500,
            letterSpacing: asCard ? -1.44 : -1.08,
          ),
        ),
        SizedBox(height: healthDp(context, 10)),
        if (asCard) ...[
          Container(
            width: double.infinity,
            height: 0.5,
            color: const Color(0x7FD2D2D2),
          ),
          SizedBox(height: healthDp(context, 10)),
        ],
        ...order.products.asMap().entries.map((entry) {
          final index = entry.key;
          final product = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < order.products.length - 1
                  ? healthDp(context, 10)
                  : 0,
            ),
            child: _productRow(context, product),
          );
        }),
        if (actions.isNotEmpty) ...[
          SizedBox(height: healthDp(context, 10)),
          _actionRow(context),
        ],
      ],
    );

    if (!asCard) return content;

    return Container(
      width: double.infinity,
      padding: DeliveryDetailSectionStyle.cardPadding(context),
      decoration: DeliveryDetailSectionStyle.cardDecoration(context),
      child: content,
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
    final option = (product.ctOption ?? '').trim();
    final optionLine = option.isEmpty
        ? '수량: ${product.ctQty}'
        : '수량: ${product.ctQty}ㅣ$option';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              Text(
                product.itName,
                style: TextStyle(
                  color: DeliveryDetailSectionStyle.ink,
                  fontSize: healthSp(context, 14),
                  fontFamily: DeliveryDetailSectionStyle.font,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -1.26,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: healthDp(context, 5)),
              Text(
                optionLine,
                style: TextStyle(
                  color: DeliveryDetailSectionStyle.mutedLabel,
                  fontSize: healthSp(context, 10),
                  fontFamily: DeliveryDetailSectionStyle.font,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.90,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
              side: const BorderSide(width: 1, color: Color(0xFFE5E7EB)),
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
                : BorderSide(width: 1, color: border),
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
