import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/price_formatter.dart';
import '../../../../../data/models/delivery/delivery_model.dart';
import '../../../../health/health_common/health_responsive_scale.dart';
import 'delivery_detail_section_style.dart';

/// 결제대기 가상계좌 입금 안내 카드
class DeliveryDetailDepositCard extends StatelessWidget {
  const DeliveryDetailDepositCard({super.key, required this.order});

  final OrderDetailModel order;

  static ({
    String bankName,
    String accountNo,
    String bankLine,
    String? holder,
    String deadline,
    String copyText,
  }) parseVirtualBankAccount(OrderDetailModel order) {
    final raw = (order.odBankAccount ?? order.paymentMethodDetail ?? '').trim();
    final parts = raw
        .split('/')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final bankName = parts.isNotEmpty ? parts[0] : '';
    final accountNo = parts.length >= 2 ? parts[1] : '';
    final deadlineRaw = parts.length >= 3 ? parts[2] : '';
    final holderFromBank = parts.length >= 4 ? parts[3] : null;
    final depositName = (order.odDepositName ?? '').trim();
    final holder = depositName.isNotEmpty
        ? depositName
        : ((holderFromBank ?? '').trim().isEmpty ? null : holderFromBank);
    final bankLine = [
      if (bankName.isNotEmpty) bankName,
      if (accountNo.isNotEmpty) accountNo,
    ].join(' ');

    const untilDeposit = '까지 입금';
    String deadline;
    if (deadlineRaw.isEmpty) {
      deadline = '기한 내 입금';
    } else {
      final compact =
          DateDisplayFormatter.formatBankDeadlineCompact14(deadlineRaw);
      deadline =
          compact.endsWith(untilDeposit) ? compact : '$compact$untilDeposit';
    }

    return (
      bankName: bankName.isEmpty ? '-' : bankName,
      accountNo: accountNo,
      bankLine: bankLine.isEmpty ? raw : bankLine,
      holder: holder,
      deadline: deadline,
      copyText: accountNo.isNotEmpty
          ? accountNo
          : (bankLine.isEmpty ? raw : bankLine),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bank = parseVirtualBankAccount(order);
    final holder = (bank.holder ?? '').trim();

    return Container(
      width: double.infinity,
      padding: DeliveryDetailSectionStyle.cardPadding(context),
      decoration: ShapeDecoration(
        color: const Color(0x0CFF5A8D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 15)),
        ),
      ),
      child: Column(
        children: [
          Text(
            '입금을 기다리고 있어요',
            style: TextStyle(
              color: const Color(0xFF1A1A1A),
              fontSize: healthSp(context, 14),
              fontFamily: DeliveryDetailSectionStyle.font,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 4)),
          Text(
            '기한 내 입금 시 주문이 완료됩니다',
            style: TextStyle(
              color: DeliveryDetailSectionStyle.pink,
              fontSize: healthSp(context, 12),
              fontFamily: DeliveryDetailSectionStyle.font,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(healthDp(context, 14)),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 15)),
              ),
              shadows: const [
                BoxShadow(
                  color: Color(0x19000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        bank.bankName,
                        style: TextStyle(
                          color: DeliveryDetailSectionStyle.muted,
                          fontSize: healthSp(context, 12),
                          fontFamily: DeliveryDetailSectionStyle.font,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final text = bank.copyText.trim();
                        if (text.isEmpty) return;
                        await Clipboard.setData(ClipboardData(text: text));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('계좌번호가 복사되었습니다.'),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(healthDp(context, 8)),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: healthDp(context, 12),
                          vertical: healthDp(context, 4),
                        ),
                        decoration: ShapeDecoration(
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(
                              width: 1,
                              color: Color(0xFFFF5C8D),
                            ),
                            borderRadius:
                                BorderRadius.circular(healthDp(context, 8)),
                          ),
                        ),
                        child: Text(
                          '복사',
                          style: TextStyle(
                            color: const Color(0xFFFF5C8D),
                            fontSize: healthSp(context, 12),
                            fontFamily: DeliveryDetailSectionStyle.font,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: healthDp(context, 10)),
                Text(
                  bank.accountNo.isEmpty ? bank.bankLine : bank.accountNo,
                  style: TextStyle(
                    color: const Color(0xFF1F2937),
                    fontSize: healthSp(context, 16),
                    fontFamily: DeliveryDetailSectionStyle.font,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: healthDp(context, 10)),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        holder.isEmpty ? '예금주 : -' : '예금주 : $holder',
                        style: TextStyle(
                          color: DeliveryDetailSectionStyle.muted,
                          fontSize: healthSp(context, 12),
                          fontFamily: DeliveryDetailSectionStyle.font,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -1.08,
                        ),
                      ),
                    ),
                    Text(
                      '${PriceFormatter.format(order.totalPrice)}원',
                      style: TextStyle(
                        color: DeliveryDetailSectionStyle.pink,
                        fontSize: healthSp(context, 16),
                        fontFamily: DeliveryDetailSectionStyle.font,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.access_time,
                size: healthDp(context, 14),
                color: DeliveryDetailSectionStyle.pink,
              ),
              SizedBox(width: healthDp(context, 5)),
              Text(
                bank.deadline,
                style: TextStyle(
                  color: DeliveryDetailSectionStyle.pink,
                  fontSize: healthSp(context, 12),
                  fontFamily: DeliveryDetailSectionStyle.font,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
