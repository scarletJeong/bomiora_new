import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/logging/failure_log.dart';
import '../../../../../core/navigation/app_action_gate.dart';
import '../../../../../core/utils/image_url_helper.dart';
import '../../../../../core/utils/price_formatter.dart';
import '../../../../../data/models/cart/cart_item_model.dart';
import '../../../../../data/models/cart/cart_line_group.dart';
import '../../../../../data/models/delivery/delivery_model.dart';
import '../../../../../data/services/auth_service.dart';
import '../../../../common/widgets/app_network_image.dart';
import '../../../../health/health_common/health_responsive_scale.dart';
import '../../../../shopping/widgets/cart_add_group_card.dart';
import '../../../../shopping/widgets/payment_product_card.dart';
import '../order_item_subject_groups.dart';
import 'delivery_detail_section_style.dart';

enum DeliveryDetailProductActionStyle { primary, outlinePink, outlineGray }

/// 주문상품 섹션 — 본품 + 추가상품(supply_add)은 [CartAddGroupCard]와 동일 묶음 UI
class DeliveryDetailProductsSection extends StatelessWidget {
  const DeliveryDetailProductsSection({
    super.key,
    required this.order,
    this.actions = const [],
    this.asCard = true,
    this.reportImageFailure = false,
    this.imageFailureCode,
    this.imageFailureReason,
  });

  final OrderDetailModel order;
  final List<
      ({
        String label,
        Future<void> Function()? onTap,
        DeliveryDetailProductActionStyle style,
      })> actions;

  /// 상품 사진 실패 로그. 없으면 [reportImageFailure]일 때만 결제완료 문구로 남긴다.
  final String? imageFailureCode;
  final String? imageFailureReason;

  /// false면 바깥 카드 없이 내용만 렌더 (합쳐진 카드용)
  final bool asCard;

  /// 결제완료 상품 사진 실패를 로그에 남긴다.
  final bool reportImageFailure;

  @override
  Widget build(BuildContext context) {
    final cartItems = cartItemsFromOrderItems(
      order.products,
      odId: order.odId,
    );
    final displayGroups = CartLineGroup.groupItems(cartItems)
        .where((g) => !g.parent.isSupplyAdd)
        .toList(growable: false);
    final totalCount = displayGroups.fold<int>(
      0,
      (sum, g) => sum + g.allItems.length,
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '주문상품 ( $totalCount )',
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
            height: healthDp(context, 0.5),
            color: const Color(0xFFD2D2D2),
          ),
          SizedBox(height: healthDp(context, 10)),
        ],
        for (var i = 0; i < displayGroups.length; i++) ...[
          if (i > 0) SizedBox(height: healthDp(context, 10)),
          CartAddGroupCard(
            group: displayGroups[i],
            selectedItems: const {},
            supplyInitiallyExpanded: true,
            supplyInteractive: false,
            showBundleTotal: false,
            reportImageFailure: reportImageFailure,
            imageFailureCode: reportImageFailure
                ? paymentCompleteProductImageCode
                : null,
            imageFailureReason: reportImageFailure
                ? paymentCompleteProductImageReason
                : null,
            imageFallbackReason: reportImageFailure
                ? paymentCompleteProductImageFallbackReason
                : null,
            onToggleSelect: (_, __) {},
            buildParentOrMainCard: (item, {required isChild, footer}) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _productRow(context, item),
                  if (footer != null) footer,
                ],
              );
            },
          ),
        ],
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

  OrderItem _asOrderItem(CartItem item) {
    return OrderItem(
      ctId: item.ctId,
      itId: item.itId,
      itName: item.itName,
      itKind: item.itKind,
      itSubject: item.itSubject ?? '',
      ctOption: item.ctOption,
      ctQty: item.ctQty,
      ctPrice: item.ctPrice,
      ioPrice: item.ioPrice ?? 0,
      totalPrice: item.lineAmount,
      ctStatus: item.ctStatus,
      imageUrl: item.imageUrl,
      ioId: item.ioId,
      ctKind: item.ctKind,
      parent: item.parentItId,
      ioType: item.ioType,
    );
  }

  Widget _productRow(BuildContext context, CartItem item) {
    final thumb = healthDp(context, 72);
    final normalizedUrl = item.imageUrl != null && item.imageUrl!.isNotEmpty
        ? ImageUrlHelper.normalizeThumbnailUrl(item.imageUrl, item.itId)
        : null;
    final asOrder = _asOrderItem(item);
    final title = orderItemDisplayTitle(asOrder);
    final qtyOptionLine = orderItemQtyOptionLine(asOrder);

    final titleStyle = TextStyle(
      color: DeliveryDetailSectionStyle.ink,
      fontSize: healthSp(context, 14),
      fontFamily: DeliveryDetailSectionStyle.font,
      fontWeight: FontWeight.w500,
      letterSpacing: -1.26,
    );
    final optionStyle = TextStyle(
      color: DeliveryDetailSectionStyle.mutedLabel,
      fontSize: healthSp(context, 10),
      fontFamily: DeliveryDetailSectionStyle.font,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.90,
    );

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
              : AppNetworkImage(
                  url: normalizedUrl,
                  width: thumb,
                  height: thumb,
                  decodeWidthLogical: thumb,
                  decodeHeightLogical: thumb,
                  fit: BoxFit.cover,
                  preferHtmlElementOnWeb: false,
                  errorBuilder: (_, error, __) {
                    _logDetailProductImage(
                      reportImageFailure: reportImageFailure,
                      imageFailureCode: imageFailureCode,
                      imageFailureReason: imageFailureReason,
                      url: normalizedUrl,
                      itId: item.itId,
                      error: error,
                    );
                    return Icon(
                      Icons.image,
                      color: DeliveryDetailSectionStyle.muted,
                      size: healthDp(context, 28),
                    );
                  },
                ),
        ),
        SizedBox(width: healthDp(context, 10)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OrderItemTitleOptionBlock(
                title: title,
                qtyOptionLine: qtyOptionLine,
                titleStyle: titleStyle,
                optionStyle: optionStyle,
              ),
              SizedBox(height: healthDp(context, 5)),
              Text(
                '${PriceFormatter.format(item.lineAmount)}원',
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
        onTap: actions.first.onTap == null
            ? null
            : () => AppActionGate.protect(actions.first.onTap!),
        borderRadius: BorderRadius.circular(healthDp(context, 9999)),
        child: Container(
          width: double.infinity,
          height: healthDp(context, 34),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: healthDp(context, 1),
                color: const Color(0xFFD2D2D2),
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
      Future<void> Function()? onTap,
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
        border = const Color(0xFFD2D2D2);
    }

    return InkWell(
      onTap: spec.onTap == null ? null : () => AppActionGate.protect(spec.onTap!),
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

const orderDetailProductImageCode = 'order.detail.image';
const orderDetailProductImageReason = '주문상세 상품 사진을 불러오지 못했습니다.';

const paymentCompleteProductImageCode = 'payment.complete.image';
const paymentCompleteProductImageReason = '결제완료 상품 사진을 불러오지 못했습니다.';
const paymentCompleteProductImageFallbackReason =
    '결제완료 상품 사진을 다시 불러오지 못했습니다.';

final Set<String> _loggedProductImageFailures = {};

void logProductImageFailure({
  required String code,
  required String reason,
  required String url,
  required String itId,
  required Object error,
}) {
  if (!_loggedProductImageFailures.add('$code|$url')) return;
  unawaited(
    FailureLog.record(
      code: code,
      mbId: AuthService.currentUser?.id ?? '',
      reason: reason,
      detail: {
        'url': url,
        'itId': itId,
        'error': error.toString(),
      },
    ),
  );
}

void logPaymentCompleteProductImageFailure({
  required String url,
  required String itId,
  required Object error,
}) {
  logProductImageFailure(
    code: paymentCompleteProductImageCode,
    reason: paymentCompleteProductImageReason,
    url: url,
    itId: itId,
    error: error,
  );
}

void _logDetailProductImage({
  required bool reportImageFailure,
  required String? imageFailureCode,
  required String? imageFailureReason,
  required String url,
  required String itId,
  required Object error,
}) {
  final code = imageFailureCode ??
      (reportImageFailure ? paymentCompleteProductImageCode : null);
  if (code == null) return;
  logProductImageFailure(
    code: code,
    reason: imageFailureReason ??
        (code == orderDetailProductImageCode
            ? orderDetailProductImageReason
            : paymentCompleteProductImageReason),
    url: url,
    itId: itId,
    error: error,
  );
}
