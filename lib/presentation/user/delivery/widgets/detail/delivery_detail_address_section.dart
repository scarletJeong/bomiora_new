import 'package:flutter/material.dart';

import '../../../../../data/models/delivery/delivery_model.dart';
import '../../../../common/widgets/dropdown_btn.dart';
import '../../../../health/health_common/health_responsive_scale.dart';
import 'delivery_detail_section_style.dart';

/// 배송지 섹션
class DeliveryDetailAddressSection extends StatelessWidget {
  const DeliveryDetailAddressSection({
    super.key,
    required this.order,
    required this.deliveryMemo,
    required this.memoPresets,
    this.onMemoChanged,
    this.showChangeButton = false,
    this.changeButtonPink = true,
    this.onChangeTap,
    this.showSameDayShipNote = false,
    this.memoEditable = true,
  });

  final OrderDetailModel order;
  final String deliveryMemo;
  final List<String> memoPresets;
  final ValueChanged<String>? onMemoChanged;
  final bool showChangeButton;
  final bool changeButtonPink;
  final VoidCallback? onChangeTap;
  final bool showSameDayShipNote;
  final bool memoEditable;

  static String formatPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    }
    if (digits.length == 10) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final name = order.recipientName.isNotEmpty
        ? order.recipientName
        : order.ordererName;
    final phoneRaw = order.recipientPhone.isNotEmpty
        ? order.recipientPhone
        : order.ordererPhone;
    final phone = phoneRaw.isEmpty ? '-' : formatPhone(phoneRaw);
    final addr =
        '${order.recipientAddress} ${order.recipientAddressDetail}'.trim();
    final memo = deliveryMemo.trim();
    final memoItems = [
      ...memoPresets,
      if (memo.isNotEmpty && !memoPresets.contains(memo)) memo,
    ];

    return Container(
      width: double.infinity,
      padding: DeliveryDetailSectionStyle.cardPadding(context),
      decoration: DeliveryDetailSectionStyle.cardDecoration(
        context,
        radius: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name.isEmpty ? '배송지' : name,
                  style: TextStyle(
                    color: const Color(0xFF333333),
                    fontSize: healthSp(context, 16),
                    fontFamily: DeliveryDetailSectionStyle.font,
                    fontWeight: FontWeight.w500,
                    height: 1.75,
                  ),
                ),
              ),
              if (showChangeButton)
                InkWell(
                  onTap: onChangeTap,
                  borderRadius:
                      BorderRadius.circular(healthDp(context, 9999)),
                  child: Container(
                    width: healthDp(context, 94),
                    height: healthDp(context, 30),
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          width: healthDp(context, 1),
                          color: changeButtonPink
                              ? DeliveryDetailSectionStyle.pink
                              : const Color(0xFFE5E7EB),
                        ),
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 9999)),
                      ),
                    ),
                    child: Text(
                      '배송지 변경',
                      style: TextStyle(
                        color: changeButtonPink
                            ? DeliveryDetailSectionStyle.pink
                            : DeliveryDetailSectionStyle.muted,
                        fontSize: healthSp(context, 12),
                        fontFamily: DeliveryDetailSectionStyle.font,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: healthDp(context, 5)),
          Text(
            phone,
            style: TextStyle(
              color: DeliveryDetailSectionStyle.ink,
              fontSize: healthSp(context, 12),
              fontFamily: DeliveryDetailSectionStyle.font,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 4)),
          Text(
            addr.isEmpty ? '-' : addr,
            style: TextStyle(
              color: DeliveryDetailSectionStyle.ink,
              fontSize: healthSp(context, 12),
              fontFamily: DeliveryDetailSectionStyle.font,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          Text(
            '배송 요청 사항',
            style: TextStyle(
              color: DeliveryDetailSectionStyle.muted,
              fontSize: healthSp(context, 12),
              fontFamily: DeliveryDetailSectionStyle.font,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 5)),
          if (memoEditable && onMemoChanged != null)
            DropdownBtn(
              buttonHeight: healthDp(context, 45),
              items: memoItems,
              value: memo,
              emptyText: '배송메모를 선택해주세요',
              emptyTextColor: DeliveryDetailSectionStyle.muted,
              valueTextColor: DeliveryDetailSectionStyle.ink,
              borderColor: const Color(0xFFD2D2D2),
              itemFontSizeBase: 12,
              itemTextAlign: TextAlign.left,
              onChanged: onMemoChanged!,
            )
          else
            Container(
              width: double.infinity,
              height: healthDp(context, 45),
              padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
              alignment: Alignment.centerLeft,
              decoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    width: healthDp(context, 1),
                    color: const Color(0xFFD2D2D2),
                  ),
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                ),
              ),
              child: Text(
                memo.isEmpty ? '-' : memo,
                style: TextStyle(
                  color: DeliveryDetailSectionStyle.ink,
                  fontSize: healthSp(context, 12),
                  fontFamily: DeliveryDetailSectionStyle.font,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (showSameDayShipNote) ...[
            SizedBox(height: healthDp(context, 5)),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '※ 영업일 기준 오후 2시 이전 처방완료 시 당일 발송',
                style: TextStyle(
                  color: DeliveryDetailSectionStyle.muted,
                  fontSize: healthSp(context, 10),
                  fontFamily: DeliveryDetailSectionStyle.font,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -0.40,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
