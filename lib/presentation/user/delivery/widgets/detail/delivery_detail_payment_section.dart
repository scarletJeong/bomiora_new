import 'package:flutter/material.dart';

import '../../../../../core/utils/price_formatter.dart';
import '../../../../../data/models/delivery/delivery_model.dart';
import '../../../../health/health_common/health_responsive_scale.dart';
import 'delivery_detail_deposit_card.dart';
import 'delivery_detail_section_style.dart';

/// 총 결제비용 / 결제 정보 섹션
class DeliveryDetailPaymentSection extends StatefulWidget {
  const DeliveryDetailPaymentSection({
    super.key,
    required this.order,
    this.initiallyExpanded = false,
    this.compact = false,
    this.cancelled = false,
  });

  final OrderDetailModel order;
  final bool initiallyExpanded;
  final bool compact;
  /// 주문취소 전용 레이아웃
  final bool cancelled;

  @override
  State<DeliveryDetailPaymentSection> createState() =>
      _DeliveryDetailPaymentSectionState();
}

class _DeliveryDetailPaymentSectionState
    extends State<DeliveryDetailPaymentSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  bool get _isVirtual => widget.order.paymentMethod.contains('가상');
  bool get _isCash =>
      _isVirtual || widget.order.paymentMethod.contains('계좌이체');

  bool get _isAwaitingPayment =>
      widget.order.displayStatus == '결제대기중' ||
      widget.order.odStatus == '주문';

  int get _coupon {
    if (widget.order.couponDiscount > 0) return widget.order.couponDiscount;
    final leftover =
        widget.order.discountAmount - widget.order.pointDiscount;
    return leftover > 0 ? leftover : 0;
  }

  int get _point {
    if (widget.order.pointDiscount > 0) return widget.order.pointDiscount;
    return widget.order.discountAmount;
  }

  int get _expectedPoint => (widget.order.totalPrice * 0.01).floor();

  /// `2026.01.01 10:16:00` (초 포함, 콜론 뒤 공백 없음)
  String get _paymentDateLabel {
    final raw = widget.order.orderDate.trim();
    if (raw.isEmpty) return '-';
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 14) {
      return '${digits.substring(0, 4)}.${digits.substring(4, 6)}.${digits.substring(6, 8)} '
          '${digits.substring(8, 10)}:${digits.substring(10, 12)}:${digits.substring(12, 14)}';
    }
    if (digits.length >= 12) {
      return '${digits.substring(0, 4)}.${digits.substring(4, 6)}.${digits.substring(6, 8)} '
          '${digits.substring(8, 10)}:${digits.substring(10, 12)}:00';
    }
    if (digits.length >= 8) {
      return '${digits.substring(0, 4)}.${digits.substring(4, 6)}.${digits.substring(6, 8)}';
    }
    return raw;
  }

  String _depositHolder(String? bankHolder) {
    final depositName = (widget.order.odDepositName ?? '').trim();
    if (depositName.isNotEmpty) return depositName;
    return (bankHolder ?? '').trim();
  }

  String get _cancelReasonLabel {
    final label = (widget.order.cancelReasonLabel ?? '').trim();
    if (label.isNotEmpty) return label;
    final type = (widget.order.cancelType ?? '').trim();
    if (type == '고객직접') return '고객 요청';
    if (type == '시스템자동') return '입금기한만료';
    if (type == '관리자') return '기타';
    final reason = (widget.order.cancelReason ?? '').trim();
    if (reason.contains('고객') || reason.contains('직접')) return '고객 요청';
    if (reason.contains('입금')) return '입금기한만료';
    if (reason.contains('관리자')) return '기타';
    // 메모/타입이 비어 있는 과거 앱 취소 건 → 고객 요청
    return '고객 요청';
  }

  String get _cancelDateLabel {
    final raw = (widget.order.cancelDate ?? '').trim();
    if (raw.isEmpty) return '-';
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 14) {
      return '${digits.substring(0, 4)}.${digits.substring(4, 6)}.${digits.substring(6, 8)} '
          '${digits.substring(8, 10)}:${digits.substring(10, 12)}:${digits.substring(12, 14)}';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cancelled) {
      return _buildCancelled(context);
    }
    return _buildNormal(context);
  }

  Widget _buildCancelled(BuildContext context) {
    final order = widget.order;
    final bank = DeliveryDetailDepositCard.parseVirtualBankAccount(order);
    final holder = _depositHolder(bank.holder);
    final showDeposit = _isCash && bank.bankLine.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: DeliveryDetailSectionStyle.cardPadding(context),
      decoration: DeliveryDetailSectionStyle.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Text(
                  '결제 정보',
                  style: TextStyle(
                    color: DeliveryDetailSectionStyle.ink,
                    fontSize: healthSp(context, 16),
                    fontFamily: DeliveryDetailSectionStyle.font,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -1.44,
                  ),
                ),
                SizedBox(width: healthDp(context, 4)),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: healthDp(context, 16),
                    color: DeliveryDetailSectionStyle.ink,
                  ),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            SizedBox(height: healthDp(context, 10)),
            _infoRow(
              context,
              label: '취소일시',
              value: _cancelDateLabel,
            ),
            SizedBox(height: healthDp(context, 10)),
            _infoRow(
              context,
              label: '취소 사유',
              value: _cancelReasonLabel,
            ),
            SizedBox(height: healthDp(context, 10)),
            Container(
              width: double.infinity,
              height: 1,
              color: const Color(0xFFE8E8E8),
            ),
            SizedBox(height: healthDp(context, 10)),
            _breakdownRow(
              context,
              label: '상품금액',
              value: '${PriceFormatter.format(order.productPrice)} 원',
              pink: false,
            ),
            if (_coupon > 0) ...[
              SizedBox(height: healthDp(context, 10)),
              _breakdownRow(
                context,
                label: '쿠폰할인',
                value: '-${PriceFormatter.format(_coupon)} 원',
                pink: true,
              ),
            ],
            if (_point > 0) ...[
              SizedBox(height: healthDp(context, 10)),
              _breakdownRow(
                context,
                label: '포인트할인',
                value: '-${PriceFormatter.format(_point)} 원',
                pink: true,
              ),
            ],
            if (order.deliveryFee > 0) ...[
              SizedBox(height: healthDp(context, 10)),
              _breakdownRow(
                context,
                label: '배송비',
                value: '${PriceFormatter.format(order.deliveryFee)} 원',
                pink: false,
              ),
            ],
            SizedBox(height: healthDp(context, 10)),
            _infoRow(
              context,
              label: '결제 방식',
              value: order.paymentMethod.isEmpty ? '-' : order.paymentMethod,
            ),
            SizedBox(height: healthDp(context, 10)),
            _infoRow(
              context,
              label: '결제 일시',
              value: _paymentDateLabel,
              valueStyle: TextStyle(
                color: const Color(0xFF374151),
                fontSize: healthSp(context, 14),
                fontFamily: DeliveryDetailSectionStyle.font,
                fontWeight: FontWeight.w500,
                height: 1.43,
              ),
            ),
            if (showDeposit) ...[
              SizedBox(height: healthDp(context, 10)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '입금정보',
                    style: TextStyle(
                      color: DeliveryDetailSectionStyle.muted,
                      fontSize: healthSp(context, 12),
                      fontFamily: DeliveryDetailSectionStyle.font,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -1.08,
                    ),
                  ),
                  SizedBox(width: healthDp(context, 8)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            bank.bankLine,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              color: DeliveryDetailSectionStyle.ink,
                              fontSize: healthSp(context, 14),
                              fontFamily: DeliveryDetailSectionStyle.font,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          holder.isEmpty ? '(예금주 : -)' : '(예금주 : $holder)',
                          textAlign: TextAlign.right,
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
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildNormal(BuildContext context) {
    final order = widget.order;
    final bank = DeliveryDetailDepositCard.parseVirtualBankAccount(order);
    final holder = _depositHolder(bank.holder);
    final showDeposit = _isCash && bank.bankLine.trim().isNotEmpty;
    final showPaymentDate = !_isAwaitingPayment || !_isVirtual;
    final showBreakdown = _expanded;

    return Container(
      width: double.infinity,
      padding: DeliveryDetailSectionStyle.cardPadding(context),
      decoration: DeliveryDetailSectionStyle.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Text(
                          '총 결제비용',
                          style: TextStyle(
                            color: DeliveryDetailSectionStyle.ink,
                            fontSize: healthSp(context, 16),
                            fontFamily: DeliveryDetailSectionStyle.font,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -1.44,
                          ),
                        ),
                        SizedBox(width: healthDp(context, 4)),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            size: healthDp(context, 16),
                            color: DeliveryDetailSectionStyle.ink,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      '${PriceFormatter.format(order.totalPrice)}원',
                      style: TextStyle(
                        color: DeliveryDetailSectionStyle.pink,
                        fontSize: healthSp(context, 16),
                        fontFamily: DeliveryDetailSectionStyle.font,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (_expectedPoint > 0) ...[
                  SizedBox(height: healthDp(context, 2)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '예상 적립 포인트 ${PriceFormatter.format(_expectedPoint)} 점',
                      style: TextStyle(
                        color: DeliveryDetailSectionStyle.muted,
                        fontSize: healthSp(context, 8),
                        fontFamily: DeliveryDetailSectionStyle.font,
                        fontWeight: FontWeight.w300,
                        letterSpacing: -0.32,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          _infoRow(
            context,
            label: '결제방식',
            value: order.paymentMethod.isEmpty ? '-' : order.paymentMethod,
          ),
          if (showPaymentDate) ...[
            SizedBox(height: healthDp(context, 10)),
            _infoRow(
              context,
              label: '결제일시',
              value: _paymentDateLabel,
              valueStyle: TextStyle(
                color: const Color(0xFF374151),
                fontSize: healthSp(context, 14),
                fontFamily: DeliveryDetailSectionStyle.font,
                fontWeight: FontWeight.w500,
                height: 1.43,
              ),
            ),
          ],
          if (showDeposit && !widget.compact) ...[
            SizedBox(height: healthDp(context, 10)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '입금정보',
                  style: TextStyle(
                    color: DeliveryDetailSectionStyle.muted,
                    fontSize: healthSp(context, 12),
                    fontFamily: DeliveryDetailSectionStyle.font,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -1.08,
                  ),
                ),
                SizedBox(width: healthDp(context, 8)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          bank.bankLine,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: DeliveryDetailSectionStyle.ink,
                            fontSize: healthSp(context, 14),
                            fontFamily: DeliveryDetailSectionStyle.font,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        holder.isEmpty ? '(예금주 : -)' : '(예금주 : $holder)',
                        textAlign: TextAlign.right,
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
            ),
          ],
          if (showBreakdown) ...[
            SizedBox(height: healthDp(context, 10)),
            Container(
              width: double.infinity,
              height: 1,
              color: const Color(0xFFE8E8E8),
            ),
            SizedBox(height: healthDp(context, 10)),
            Column(
              children: [
                _breakdownRow(
                  context,
                  label: '상품금액',
                  value: '${PriceFormatter.format(order.productPrice)} 원',
                  pink: false,
                ),
                if (_coupon > 0) ...[
                  SizedBox(height: healthDp(context, 10)),
                  _breakdownRow(
                    context,
                    label: '쿠폰할인',
                    value: '-${PriceFormatter.format(_coupon)} 원',
                    pink: true,
                  ),
                ],
                if (_point > 0) ...[
                  SizedBox(height: healthDp(context, 10)),
                  _breakdownRow(
                    context,
                    label: '포인트할인',
                    value: '-${PriceFormatter.format(_point)} 원',
                    pink: true,
                  ),
                ],
                if (order.deliveryFee > 0) ...[
                  SizedBox(height: healthDp(context, 10)),
                  _breakdownRow(
                    context,
                    label: '배송비',
                    value: '${PriceFormatter.format(order.deliveryFee)} 원',
                    pink: false,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(
    BuildContext context, {
    required String label,
    required String value,
    TextStyle? valueStyle,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            color: DeliveryDetailSectionStyle.muted,
            fontSize: healthSp(context, 12),
            fontFamily: DeliveryDetailSectionStyle.font,
            fontWeight: FontWeight.w500,
            letterSpacing: -1.08,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: valueStyle ??
                TextStyle(
                  color: DeliveryDetailSectionStyle.ink,
                  fontSize: healthSp(context, 14),
                  fontFamily: DeliveryDetailSectionStyle.font,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }

  Widget _breakdownRow(
    BuildContext context, {
    required String label,
    required String value,
    required bool pink,
    bool mutedValue = false,
  }) {
    final color = pink
        ? DeliveryDetailSectionStyle.pink
        : (mutedValue
            ? DeliveryDetailSectionStyle.muted
            : DeliveryDetailSectionStyle.ink);
    final labelColor =
        pink ? DeliveryDetailSectionStyle.pink : DeliveryDetailSectionStyle.muted;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: healthSp(context, 12),
            fontFamily: DeliveryDetailSectionStyle.font,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: healthSp(context, mutedValue ? 12 : 14),
            fontFamily: DeliveryDetailSectionStyle.font,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
