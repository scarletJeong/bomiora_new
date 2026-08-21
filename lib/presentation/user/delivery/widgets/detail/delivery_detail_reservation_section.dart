import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/constants/app_assets.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../data/models/delivery/delivery_model.dart';
import '../../../../health/health_common/health_responsive_scale.dart';
import 'delivery_detail_section_style.dart';

/// 진료 예약 일정 / 예약 내역 섹션
class DeliveryDetailReservationSection extends StatelessWidget {
  const DeliveryDetailReservationSection({
    super.key,
    required this.order,
    this.showChangeButton = false,
    this.onChangeTap,
    this.asHistory = false,
    this.showConsultDoneBadge = false,
    this.badgeLabel = '상담완료',
    this.titleText,
    this.doctorName = '정대진 한의사',
    this.asCard = true,
    this.iconColor = DeliveryDetailSectionStyle.pink,
    this.titleAlign = TextAlign.center,
  });

  final OrderDetailModel order;
  final bool showChangeButton;
  final VoidCallback? onChangeTap;
  final bool asHistory;
  final bool showConsultDoneBadge;
  final String badgeLabel;
  /// null이면 asHistory에 따라 기본 문구 사용
  final String? titleText;
  final String doctorName;
  /// false면 바깥 카드 없이 내용만 렌더 (합쳐진 카드용)
  final bool asCard;
  final Color iconColor;
  final TextAlign titleAlign;

  static String formatDateCompact(String? raw) {
    final d = DateDisplayFormatter.tryParseYmdFlexible(raw);
    if (d == null) {
      final fallback =
          DateDisplayFormatter.formatReservationDateWithWeekday(raw);
      return fallback.isEmpty ? '-' : fallback;
    }
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$mm월$dd일(${weekdays[d.weekday - 1]})';
  }

  static String formatTimeRange(OrderDetailModel order) {
    final st = order.reservationTime?.trim();
    final et = order.reservationEndTime?.trim();
    if (st != null && st.isNotEmpty && et != null && et.isNotEmpty) {
      return '$st - $et';
    }
    if (st != null && st.isNotEmpty) return st;
    if (et != null && et.isNotEmpty) return et;
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    final crossAlign = titleAlign == TextAlign.left
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.center;
    final resolvedTitle = titleText ??
        (asHistory ? '진료 예약 내역' : '진료 예약 일정');

    final titleBlock = Column(
      crossAxisAlignment: crossAlign,
      children: [
        Text(
          '보미오라 한의원',
          textAlign: titleAlign,
          style: TextStyle(
            color: DeliveryDetailSectionStyle.muted,
            fontSize: healthSp(context, 12),
            fontFamily: DeliveryDetailSectionStyle.font,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: healthDp(context, 4)),
        Text(
          resolvedTitle,
          textAlign: titleAlign,
          style: TextStyle(
            color: DeliveryDetailSectionStyle.ink,
            fontSize: healthSp(context, 16),
            fontFamily: DeliveryDetailSectionStyle.font,
            fontWeight: FontWeight.w500,
            letterSpacing: -1.44,
          ),
        ),
      ],
    );

    Widget header;
    if (showConsultDoneBadge) {
      header = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: titleBlock),
          SizedBox(width: healthDp(context, 8)),
          Container(
            padding: EdgeInsets.all(healthDp(context, 5)),
            decoration: ShapeDecoration(
              color: const Color(0x7FD2D2D2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 50)),
              ),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(
                color: DeliveryDetailSectionStyle.muted,
                fontSize: healthSp(context, 10),
                fontFamily: DeliveryDetailSectionStyle.font,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    } else {
      header = titleBlock;
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        SizedBox(height: healthDp(context, 10)),
        Container(
          width: double.infinity,
          height: healthDp(context, 1),
          color: const Color(0xFFE8E8E8),
        ),
        SizedBox(height: healthDp(context, 20)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _meta(
              context,
              asset: AppAssets.paymentCompleteReservationDateIcon,
              label: formatDateCompact(order.reservationDate),
            ),
            _meta(
              context,
              asset: AppAssets.paymentCompleteReservationTimeIcon,
              label: formatTimeRange(order),
            ),
            _meta(
              context,
              asset: AppAssets.paymentCompleteReservationDoctorIcon,
              label: doctorName,
            ),
          ],
        ),
        if (showChangeButton) ...[
          SizedBox(height: healthDp(context, 20)),
          InkWell(
            onTap: onChangeTap,
            borderRadius: BorderRadius.circular(healthDp(context, 9999)),
            child: Container(
              width: double.infinity,
              height: healthDp(context, 34),
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    width: healthDp(context, 1),
                    color: DeliveryDetailSectionStyle.pink,
                  ),
                  borderRadius:
                      BorderRadius.circular(healthDp(context, 9999)),
                ),
              ),
              child: Text(
                '예약 시간 변경',
                style: TextStyle(
                  color: DeliveryDetailSectionStyle.pink,
                  fontSize: healthSp(context, 12),
                  fontFamily: DeliveryDetailSectionStyle.font,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
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

  Widget _meta(
    BuildContext context, {
    required String asset,
    required String label,
  }) {
    final iconSize = healthDp(context, 16);
    return Expanded(
      child: Column(
        children: [
          SvgPicture.asset(
            asset,
            width: iconSize,
            height: iconSize,
            colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          ),
          SizedBox(height: healthDp(context, 3)),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF333333),
              fontSize: healthSp(context, 10),
              fontFamily: DeliveryDetailSectionStyle.font,
              fontWeight: FontWeight.w500,
              height: 1.38,
            ),
          ),
        ],
      ),
    );
  }
}
