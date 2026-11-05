import 'package:flutter/material.dart';

import '../../../../core/navigation/app_action_gate.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../data/models/delivery/delivery_model.dart';
import '../../../../data/models/product/product_option_model.dart';
import '../../../common/widgets/app_network_image.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import 'order_item_subject_groups.dart';
import '../delivery_order_stage.dart';

enum _CardActionStyle { primary, outlinePink, outlineGray }

const Color _kPink = Color(0xFFFF5A8D);
const Color _kBorder = Color(0x7FD2D2D2);
const Color _kMuted = Color(0xFF898686);
const Color _kInk = Color(0xFF1A1A1A);

class DeliveryOrderCard extends StatefulWidget {
  const DeliveryOrderCard({
    super.key,
    required this.order,
    required this.expandedKeys,
    required this.onToggleSupply,
    required this.onOpenDetail,
    required this.onReorder,
    required this.onInquiry,
    required this.onTrackDelivery,
    required this.onWriteReview,
    required this.canWriteReview,
    required this.onConfirmPurchase,
    required this.onChangeAddress,
    required this.onChangeReservation,
    required this.onCancelOrder,
  });

  final OrderListModel order;
  final Set<String> expandedKeys;
  final void Function(String key) onToggleSupply;
  final Future<void> Function(OrderListModel order) onOpenDetail;
  final Future<void> Function(OrderListModel order) onReorder;
  final Future<void> Function(OrderListModel order) onInquiry;
  final Future<void> Function(String odId) onTrackDelivery;
  final Future<void> Function(String odId) onWriteReview;
  final bool Function(OrderListModel order) canWriteReview;
  final Future<void> Function(String odId) onConfirmPurchase;
  final Future<void> Function(OrderListModel order) onChangeAddress;
  final Future<void> Function(OrderListModel order) onChangeReservation;
  final Future<void> Function(OrderListModel order) onCancelOrder;

  @override
  State<DeliveryOrderCard> createState() => _DeliveryOrderCardState();
}

class _DeliveryOrderCardState extends State<DeliveryOrderCard> {
  @override
  Widget build(BuildContext context) {
    return _buildOrderCard(widget.order);
  }
/// 주문 카드 위젯
  Widget _buildOrderCard(OrderListModel order) {
    final statusText = _getOrderStatusText(order);

    return Container(
      margin: EdgeInsets.only(bottom: healthDp(context, 10)),
      padding: EdgeInsets.all(healthDp(context, 20)),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _kBorder),
          borderRadius: BorderRadius.circular(healthDp(context, 15)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        color: _kInk,
                        fontSize: healthSp(context, 14),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: healthDp(context, 10)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '주문일자: ${DateDisplayFormatter.formatOrderDateTime(order.orderDate, withTime: false)}',
                          style: TextStyle(
                            color: _kMuted,
                            fontSize: healthSp(context, 10),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: healthDp(context, 5)),
                        Text(
                          '주문번호: ${order.odId}',
                          style: TextStyle(
                            color: _kMuted,
                            fontSize: healthSp(context, 10),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            height: 1,
                          ),
                        ),
                        if (_scheduleLine(order) != null) ...[
                          SizedBox(height: healthDp(context, 5)),
                          Text(
                            _scheduleLine(order)!,
                            style: TextStyle(
                              color: _kPink,
                              fontSize: healthSp(context, 10),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                              height: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => AppActionGate.protect(
                  () => widget.onOpenDetail(order),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '주문상세',
                      style: TextStyle(
                        color: _kInk,
                        fontSize: healthSp(context, 12),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: healthDp(context, 2)),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: healthDp(context, 16),
                      color: _kInk,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: healthDp(context, 20)),
          ..._buildOrderProductBlocks(order),
          SizedBox(height: healthDp(context, 10)),
          Container(
            width: double.infinity,
            height: healthDp(context, 1),
            color: _kBorder,
          ),
          SizedBox(height: healthDp(context, 10)),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '총 ${PriceFormatter.format(order.totalPrice)}원',
                  style: TextStyle(
                    color: _kInk,
                    fontSize: healthSp(context, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (order.deliveryFee > 0) ...[
                  SizedBox(height: healthDp(context, 5)),
                  Text(
                    '(배송비: ${PriceFormatter.format(order.deliveryFee)}원)',
                    style: TextStyle(
                      color: _kMuted,
                      fontSize: healthSp(context, 12),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ...(() {
            final actions = _buildOrderCardActions(order);
            if (actions == null) return <Widget>[];
            return <Widget>[
              SizedBox(height: healthDp(context, 20)),
              actions,
            ];
          })(),
        ],
      ),
    );
  }

  /// 한 주문의 상품 행들 (`items` 전부, 없으면 `firstProduct*` 요약 1행)
  List<Widget> _buildOrderProductBlocks(OrderListModel order) {
    if (order.items.isNotEmpty) {
      if (!order.isPrescriptionOrder) {
        return _buildGeneralGroupedProductBlocks(order);
      }
      return _buildPrescriptionGroupedProductBlocks(order);
    }

    final qty = order.firstProductQty ?? 1;
    var qtyLine = '수량: $qty';
    final opt = ProductOption.visibleLabel(
      ctOption: order.firstProductOption,
    );
    if (opt.isNotEmpty) {
      qtyLine += 'ㅣ$opt';
    }

    return [
      _buildOrderProductLineInk(
        order,
        image: _buildProductImage(order),
        title: order.firstProductName ?? '상품명 없음',
        qtyLine: qtyLine,
        priceText: '${PriceFormatter.format(order.firstProductPrice ?? 0)}원',
        moreHint:
            order.odCartCount > 1 ? '외 ${order.odCartCount - 1}개 상품' : null,
      ),
    ];
  }

  List<Widget> _buildPrescriptionGroupedProductBlocks(OrderListModel order) {
    final groups = groupOrderItemsWithSupply(order.items);
    final widgets = <Widget>[];
    for (var i = 0; i < groups.length; i++) {
      if (i > 0) widgets.add(SizedBox(height: healthDp(context, 16)));
      final group = groups[i];
      final parent = group.parent;
      final children = group.children;
      final showMoreHint = groups.length == 1 &&
          children.isEmpty &&
          order.odCartCount > 1;
      final key = '${order.odId}:${parent.ctId}';
      final expanded = widget.expandedKeys.contains(key);

      widgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderProductLineInk(
              order,
              image: _buildProductImageFromItem(parent),
              title: orderItemDisplayTitle(parent),
              qtyLine: orderItemQtyOptionLine(parent),
              priceText: '${PriceFormatter.format(parent.totalPrice)}원',
              moreHint:
                  showMoreHint ? '외 ${order.odCartCount - 1}개 상품' : null,
            ),
            if (children.isNotEmpty) ...[
              SizedBox(height: healthDp(context, 10)),
              _buildSupplyExpandChip(
                count: children.length,
                expanded: expanded,
                onTap: () => widget.onToggleSupply(key),
              ),
              if (expanded) ...[
                SizedBox(height: healthDp(context, 10)),
                for (var ci = 0; ci < children.length; ci++) ...[
                  if (ci > 0) SizedBox(height: healthDp(context, 8)),
                  _buildOrderProductLineInk(
                    order,
                    image: _buildProductImageFromItem(children[ci]),
                    title: orderItemDisplayTitle(children[ci]),
                    qtyLine: orderItemQtyOptionLine(children[ci]),
                    priceText:
                        '${PriceFormatter.format(children[ci].totalPrice)}원',
                  ),
                ],
              ],
            ],
          ],
        ),
      );
    }
    return widgets;
  }

  Widget _buildSupplyExpandChip({
    required int count,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(healthDp(context, 8)),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 10),
            vertical: healthDp(context, 7),
          ),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: healthDp(context, 1.11),
                color: const Color(0x3FFF5A8D),
              ),
              borderRadius: BorderRadius.circular(healthDp(context, 8)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: healthDp(context, 5),
                height: healthDp(context, 5),
                decoration: const BoxDecoration(
                  color: _kPink,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: healthDp(context, 6)),
              Text(
                '추가상품 $count개 포함',
                style: TextStyle(
                  color: _kPink,
                  fontSize: healthSp(context, 11),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                expanded ? '접기' : '펼치기',
                style: TextStyle(
                  color: _kPink,
                  fontSize: healthSp(context, 10),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: healthDp(context, 3)),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: healthSp(context, 14),
                color: _kPink,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGeneralGroupedProductBlocks(OrderListModel order) {
    final groups = groupOrderItemsByItSubject(order.items);
    final widgets = <Widget>[];
    for (var gi = 0; gi < groups.length; gi++) {
      if (gi > 0) {
        widgets.add(SizedBox(height: healthDp(context, 10)));
        widgets.add(
          Container(
            width: double.infinity,
            height: 0.5,
            color: const Color(0x7FD2D2D2),
          ),
        );
        widgets.add(SizedBox(height: healthDp(context, 10)));
      }
      final subject = groups[gi].key;
      final items = groups[gi].value;
      widgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subject.isNotEmpty) ...[
              Text(
                subject,
                style: TextStyle(
                  color: _kMuted,
                  fontSize: healthSp(context, 12),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: healthDp(context, 10)),
            ],
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(height: healthDp(context, 10)),
              _buildOrderProductLineInk(
                order,
                image: _buildProductImageFromItem(items[i]),
                title: orderItemDisplayTitle(items[i]),
                qtyLine: orderItemQtyOptionLine(items[i]),
                priceText: '${PriceFormatter.format(items[i].totalPrice)}원',
              ),
            ],
          ],
        ),
      );
    }
    return widgets;
  }

  /// 상품 행 — 주문번호와 동일하게 카드 좌측(패딩 20)에 맞춤
  Widget _buildOrderProductLineInk(
    OrderListModel order, {
    required Widget image,
    required String title,
    required String qtyLine,
    required String priceText,
    String? moreHint,
  }) {
    return InkWell(
      onTap: () => AppActionGate.protect(() => widget.onOpenDetail(order)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          image,
          SizedBox(width: healthDp(context, 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _kInk,
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    letterSpacing: healthDp(context, -1.26),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: healthDp(context, 5)),
                Text(
                  qtyLine,
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: healthSp(context, 10),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.90,
                  ),
                ),
                SizedBox(height: healthDp(context, 5)),
                Text(
                  priceText,
                  style: TextStyle(
                    color: _kInk,
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (moreHint != null)
                  Padding(
                    padding: EdgeInsets.only(top: healthDp(context, 4)),
                    child: Text(
                      moreHint,
                      style: TextStyle(
                        fontSize: healthSp(context, 10),
                        color: _kMuted,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImageFromItem(OrderItem item) {
    final imageUrl = item.imageUrl;
    final normalizedUrl = imageUrl != null && imageUrl.isNotEmpty
        ? ImageUrlHelper.normalizeThumbnailUrl(imageUrl, item.itId)
        : null;

    final thumb = healthDp(context, 72);
    return Container(
      width: thumb,
      height: thumb,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(healthDp(context, 4)),
      ),
      child: normalizedUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(healthDp(context, 4)),
              child: AppNetworkImage(
                url: normalizedUrl,
                width: thumb,
                height: thumb,
                decodeWidthLogical: thumb,
                decodeHeightLogical: thumb,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.image,
                    size: healthDp(context, 40),
                    color: Colors.grey[400],
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: healthDp(context, 2),
                      color: _kPink,
                    ),
                  );
                },
              ),
            )
          : Icon(
              Icons.image,
              size: healthDp(context, 40),
              color: Colors.grey[400],
            ),
    );
  }

  /// 카드 하단 액션 / 안내
  Widget? _buildOrderCardActions(OrderListModel order) {
    final isPrescription = order.isPrescriptionOrder;

    if (isOrderCancelled(order)) {
      return _buildActionRow([
        (
          label: '재주문하기',
          onTap: () => widget.onReorder(order),
          style: _CardActionStyle.outlinePink,
        ),
      ]);
    }

    if (isOrderConsultationDone(order)) {
      return _buildPreparingLockedBanner(
        context,
        withConsultPrefix: true,
      );
    }

    if (isOrderPreparing(order)) {
      return _buildActionRow([
        (
          label: '배송지변경',
          onTap: () => widget.onChangeAddress(order),
          style: _CardActionStyle.primary,
        ),
      ]);
    }

    if (isOrderCompleted(order)) {
      final actions = <({String label, Future<void> Function()? onTap, _CardActionStyle style})>[
        (
          label: '1:1 문의',
          onTap: () => widget.onInquiry(order),
          style: _CardActionStyle.outlinePink,
        ),
        (
          label: '배송조회',
          onTap: () => widget.onTrackDelivery(order.odId),
          style: _CardActionStyle.outlinePink,
        ),
      ];
      if (widget.canWriteReview(order)) {
        actions.add((
          label: '리뷰쓰기',
          onTap: () => widget.onWriteReview(order.odId),
          style: _CardActionStyle.primary,
        ));
      } else {
        actions.add((
          label: '다시 담기',
          onTap: () => widget.onReorder(order),
          style: _CardActionStyle.primary,
        ));
      }
      return _buildActionRow(actions);
    }

    if (isOrderDelivering(order)) {
      return _buildActionRow([
        (
          label: '수령확인',
          onTap: () => widget.onConfirmPurchase(order.odId),
          style: _CardActionStyle.outlinePink,
        ),
        (
          label: '배송조회',
          onTap: () => widget.onTrackDelivery(order.odId),
          style: _CardActionStyle.primary,
        ),
      ]);
    }

    if (isOrderPaymentWaiting(order)) {
      return _buildActionRow([
        (
          label: '주문취소',
          onTap: () => widget.onCancelOrder(order),
          style: _CardActionStyle.outlineGray,
        ),
        (
          label: '배송지변경',
          onTap: () => widget.onChangeAddress(order),
          style: _CardActionStyle.primary,
        ),
      ]);
    }

    if (isOrderPaid(order)) {
      final specs = <({String label, Future<void> Function()? onTap, _CardActionStyle style})>[
        (
          label: '주문취소',
          onTap: () => widget.onCancelOrder(order),
          style: _CardActionStyle.outlineGray,
        ),
      ];
      if (isPrescription) {
        specs.add((
          label: '예약시간변경',
          onTap: () => widget.onChangeReservation(order),
          style: _CardActionStyle.outlinePink,
        ));
      }
      specs.add((
        label: '배송지변경',
        onTap: () => widget.onChangeAddress(order),
        style: _CardActionStyle.primary,
      ));
      return _buildActionRow(specs);
    }

    return null;
  }

  Widget _buildPreparingLockedBanner(
    BuildContext context, {
    required bool withConsultPrefix,
  }) {
    final message = withConsultPrefix
        ? '상담완료 후 배송준비중인 상태로\n배송지 변경 또는 취소가 어렵습니다.'
        : '배송준비중인 상태로\n배송지 변경 또는 취소가 어렵습니다.';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: healthDp(context, 10)),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: const Color(0x19FF5A8D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _kPink,
          fontSize: healthSp(context, 12),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
          height: 1.50,
        ),
      ),
    );
  }

  Widget _buildActionRow(
    List<({String label, Future<void> Function()? onTap, _CardActionStyle style})> specs,
  ) {
    if (specs.isEmpty) return const SizedBox.shrink();
    final gap = healthDp(context, 10);
    return Row(
      children: [
        for (var i = 0; i < specs.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(
            child: _cardActionButton(
              label: specs[i].label,
              style: specs[i].style,
              onTap: specs[i].onTap,
            ),
          ),
        ],
      ],
    );
  }

  ({Color background, Color foreground, Color? border}) _colorsForStyle(
    _CardActionStyle style,
  ) {
    switch (style) {
      case _CardActionStyle.primary:
        return (background: _kPink, foreground: Colors.white, border: null);
      case _CardActionStyle.outlinePink:
        return (background: Colors.white, foreground: _kPink, border: _kPink);
      case _CardActionStyle.outlineGray:
        return (
          background: Colors.white,
          foreground: _kMuted,
          border: const Color(0xFFD2D2D2),
        );
    }
  }

  TextStyle _cardActionTextStyle({required Color color, bool enabled = true}) {
    return TextStyle(
      color: color.withValues(alpha: enabled ? 1 : 0.45),
      fontSize: healthSp(context, 12),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w500,
      height: 1,
    );
  }

  Widget _cardActionButton({
    required String label,
    required _CardActionStyle style,
    Future<void> Function()? onTap,
  }) {
    final enabled = onTap != null;
    final colors = _colorsForStyle(style);
    final bg = enabled
        ? colors.background
        : colors.background.withValues(
            alpha: colors.background == Colors.white ? 1 : 0.45,
          );
    final fg = enabled
        ? colors.foreground
        : colors.foreground.withValues(alpha: 0.45);
    final borderColor = colors.border == null
        ? null
        : (enabled ? colors.border! : colors.border!.withValues(alpha: 0.35));
    final radius = BorderRadius.circular(healthDp(context, 50));

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null ? null : () => AppActionGate.protect(onTap),
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: healthDp(context, 10)),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: bg,
            shape: RoundedRectangleBorder(
              side: borderColor == null
                  ? BorderSide.none
                  : BorderSide(
                      width: healthDp(context, 1),
                      color: borderColor,
                    ),
              borderRadius: radius,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: _cardActionTextStyle(color: fg, enabled: true),
            ),
          ),
        ),
      ),
    );
  }

  String _getOrderStatusText(OrderListModel order) {
    if (isOrderCancelled(order)) return '주문취소';
    if (isOrderCompleted(order)) return '배송완료';
    if (isOrderDelivering(order)) return '배송중';
    if (isOrderConsultationDone(order)) return '상담완료';
    if (isOrderPreparing(order)) return '배송준비중';
    if (isOrderPaid(order)) return '결제완료';
    if (isOrderPaymentWaiting(order)) return '결제대기중';
    final status = order.displayStatus.trim();
    return status.isEmpty ? '주문' : status;
  }

  String? _scheduleLine(OrderListModel order) {
    if (isOrderPaymentWaiting(order)) {
      final deadline =
          DateDisplayFormatter.formatBankDeadlineList(order.odBankAccount);
      if (deadline.isEmpty) return null;
      return '입금기간: $deadline';
    }
    if (!order.isPrescriptionOrder) return null;
    final reservation = _reservationLine(order);
    if (reservation.isEmpty) return null;
    return '예약시간: $reservation';
  }

  String _reservationLine(OrderListModel order) {
    if (isOrderCancelled(order)) return '';
    final dateLabel = _formatReservationDate(order.reservationDate);
    final timeLabel = _formatReservationTimeRange(
      order.reservationTime,
      order.reservationEndTime,
    );
    if (dateLabel.isEmpty && timeLabel.isEmpty) return '';
    if (dateLabel.isEmpty) return timeLabel;
    if (timeLabel.isEmpty) return dateLabel;
    return '$dateLabel $timeLabel';
  }

  String _formatReservationDate(String? raw) {
    final d = DateDisplayFormatter.tryParseYmdFlexible(raw);
    if (d == null) return '';
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$mm.$dd(${weekdays[d.weekday - 1]})';
  }

  String _formatReservationTimeRange(String? start, String? end) {
    final st = start?.trim() ?? '';
    final et = end?.trim() ?? '';
    if (st.isNotEmpty && et.isNotEmpty) return '$st-$et';
    if (st.isNotEmpty) return st;
    return et;
  }
  /// 상품 이미지 위젯
  Widget _buildProductImage(OrderListModel order) {
    // 첫 번째 상품의 이미지 URL 가져오기
    String? imageUrl;
    if (order.items.isNotEmpty && order.items[0].imageUrl != null) {
      imageUrl = order.items[0].imageUrl;
    }
    
    // 이미지 URL 정규화
    final normalizedUrl = imageUrl != null && imageUrl.isNotEmpty
        ? ImageUrlHelper.normalizeThumbnailUrl(imageUrl, order.items.isNotEmpty ? order.items[0].itId : null)
        : null;
    
    final thumb = healthDp(context, 72);
    return Container(
      width: thumb,
      height: thumb,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(healthDp(context, 4)),
      ),
      child: normalizedUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(healthDp(context, 4)),
              child: AppNetworkImage(
                url: normalizedUrl,
                width: thumb,
                height: thumb,
                decodeWidthLogical: thumb,
                decodeHeightLogical: thumb,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.image,
                    size: healthDp(context, 40),
                    color: Colors.grey[400],
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: healthDp(context, 2),
                      color: _kPink,
                    ),
                  );
                },
              ),
            )
          : Icon(
              Icons.image,
              size: healthDp(context, 40),
              color: Colors.grey[400],
            ),
    );
  }


}
