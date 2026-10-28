import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/utils/date_formatter.dart';
import '../../../../../data/models/delivery/delivery_model.dart';
import '../../../../health/health_common/health_responsive_scale.dart';
import '../../../../common/widgets/app_toast_overlay.dart';
import 'delivery_detail_section_style.dart';

/// 주문 상태 + 진행 바 카드
class DeliveryDetailStatusCard extends StatelessWidget {
  const DeliveryDetailStatusCard({
    super.key,
    required this.order,
    required this.step,
    required this.labels,
    this.isCancelled = false,
  });

  final OrderDetailModel order;
  final int step;
  final List<String> labels;
  final bool isCancelled;

  /// 주문일자에서 초 단위 제거 (`2025.10.13 11:00:38` → `2025.10.13 11:00`)
  static String formatOrderDateNoSeconds(String raw) {
    return DateDisplayFormatter.formatOrderDateTime(
      raw,
      withSeconds: false,
    );
  }

  static String? _scheduleLine(
    OrderDetailModel order, {
    required bool isCancelled,
  }) {
    final awaiting =
        order.displayStatus == '결제대기중' || order.odStatus == '주문';
    if (awaiting) {
      final deadline =
          DateDisplayFormatter.formatBankDeadlineList(order.odBankAccount);
      if (deadline.isEmpty) return null;
      return '입금기간: $deadline';
    }
    if (isCancelled) return null;
    final reservation = _reservationLine(order);
    if (reservation == null || reservation.isEmpty) return null;
    return '예약시간: $reservation';
  }

  /// 비대면 주문의 예약일·시간. 없으면 null.
  static String? _reservationLine(OrderDetailModel order) {
    final dateLabel = _formatReservationDate(order.reservationDate);
    final timeLabel = _formatReservationTimeRange(
      order.reservationTime,
      order.reservationEndTime,
    );
    if (dateLabel.isEmpty && timeLabel.isEmpty) return null;
    if (dateLabel.isEmpty) return timeLabel;
    if (timeLabel.isEmpty) return dateLabel;
    return '$dateLabel $timeLabel';
  }

  static String _formatReservationDate(String? raw) {
    final d = DateDisplayFormatter.tryParseYmdFlexible(raw);
    if (d == null) return '';
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$mm.$dd(${weekdays[d.weekday - 1]})';
  }

  static String _formatReservationTimeRange(String? start, String? end) {
    final st = start?.trim() ?? '';
    final et = end?.trim() ?? '';
    if (st.isNotEmpty && et.isNotEmpty) return '$st-$et';
    if (st.isNotEmpty) return st;
    return et;
  }

  @override
  Widget build(BuildContext context) {
    final statusTitle = isCancelled
        ? '주문 취소'
        : (step >= 0 && step < labels.length ? labels[step] : labels.first);
    final count = labels.length;
    final orderDateLabel = formatOrderDateNoSeconds(order.orderDate);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 21)),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: const Color(0xFFF1F5F9),
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 12)),
        ),
        shadows: [
          BoxShadow(
            color: const Color(0x0C000000),
            blurRadius: healthDp(context, 2),
            offset: Offset(0, healthDp(context, 1)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  statusTitle,
                  style: TextStyle(
                    color: DeliveryDetailSectionStyle.ink,
                    fontSize: healthSp(context, 16),
                    fontFamily: DeliveryDetailSectionStyle.font,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '주문일자: $orderDateLabel',
                    style: TextStyle(
                      color: DeliveryDetailSectionStyle.muted,
                      fontSize: healthSp(context, 10),
                      fontFamily: DeliveryDetailSectionStyle.font,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 4)),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: order.odId));
                      AppToastOverlay.show(context, '주문번호가 복사되었습니다.');
                    },
                    child: Text(
                      '주문번호: ${order.odId}',
                      style: TextStyle(
                        color: DeliveryDetailSectionStyle.muted,
                        fontSize: healthSp(context, 10),
                        fontFamily: DeliveryDetailSectionStyle.font,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (_scheduleLine(order, isCancelled: isCancelled) != null) ...[
                    SizedBox(height: healthDp(context, 4)),
                    Text(
                      _scheduleLine(order, isCancelled: isCancelled)!,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: DeliveryDetailSectionStyle.pink,
                        fontSize: healthSp(context, 10),
                        fontFamily: DeliveryDetailSectionStyle.font,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (!isCancelled) ...[
            SizedBox(height: healthDp(context, 20)),
            Row(
              children: List.generate(count, (i) {
                final filled = i <= step;
                final active = i == step;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i < count - 1 ? healthDp(context, 2) : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          height: healthDp(context, 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F6F6),
                            borderRadius:
                                BorderRadius.circular(healthDp(context, 9999)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: filled
                              ? Container(
                                  height: healthDp(context, 8),
                                  decoration: BoxDecoration(
                                    color: DeliveryDetailSectionStyle.pink,
                                    borderRadius: BorderRadius.circular(
                                      healthDp(context, 9999),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        SizedBox(height: healthDp(context, 10)),
                        Text(
                          labels[i],
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: active
                                ? DeliveryDetailSectionStyle.pink
                                : (filled
                                    ? DeliveryDetailSectionStyle.ink
                                    : DeliveryDetailSectionStyle.mutedPending),
                            fontSize: healthSp(context, 10),
                            fontFamily: DeliveryDetailSectionStyle.font,
                            fontWeight: FontWeight.w500,
                            height: 1.60,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}
