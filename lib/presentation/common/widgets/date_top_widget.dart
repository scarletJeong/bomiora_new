import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_assets.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_date_selector.dart';

class DateTopWidget extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateChanged;
  final Map<String, dynamic>? recordsMap; // 날짜별 데이터가 있는지 확인용
  final String? recordKey; // 데이터 확인용 키 (예: 'blood_pressure', 'weight' 등)
  final Color? primaryColor;
  final Color? secondaryColor;
  final Color? monthTextColor;
  final Color? iconColor;

  const DateTopWidget({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    this.recordsMap,
    this.recordKey,
    this.primaryColor,
    this.secondaryColor,
    this.monthTextColor,
    this.iconColor,
  });

  // 표시할 3개의 날짜
  List<DateTime> get displayDates {
    return [
      selectedDate.subtract(const Duration(days: 1)),
      selectedDate,
      selectedDate.add(const Duration(days: 1)),
    ];
  }

  // 오늘인지 확인
  bool _isToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;
  }

  // 특정 날짜에 데이터가 있는지 확인
  bool _hasRecord(DateTime date) {
    if (recordsMap == null) return false;

    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    return recordsMap!.containsKey(dateKey);
  }

  Future<void> _openCalendarPicker(BuildContext context) async {
    final picked = await showHealthDateOnlyPicker(
      context,
      initialDate: selectedDate,
    );
    if (picked != null) {
      onDateChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday();
    // 375 기준 값 (모두 healthDp / healthSp 로 스케일)
    final appBarToMonthGap = healthDp(context, 20);
    final monthFontSize = healthSp(context, 12);
    final iconSize = healthDp(context, 12);
    final monthToDateGap = healthDp(context, 5);
    final dateRowH = healthDp(context, 70);
    final dateRowVPad = healthDp(context, 10);
    final dateRowHPad = healthDp(context, 9);
    final todayPadH = healthDp(context, 6);
    final todayPadV = healthDp(context, 2);
    final todayRadius = healthDp(context, 12);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: appBarToMonthGap),
        InkWell(
          borderRadius: BorderRadius.circular(healthDp(context, 20)),
          splashFactory: NoSplash.splashFactory,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          focusColor: Colors.transparent,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          onTap: () => _openCalendarPicker(context),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 4),
              vertical: healthDp(context, 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  DateFormat('yyyy년 M월').format(selectedDate),
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: monthTextColor ?? const Color(0xFF898686),
                    fontSize: monthFontSize,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
                ),
                SizedBox(width: healthDp(context, 3)),
                SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: SvgPicture.asset(
                    AppAssets.calendarIcon,
                    width: iconSize,
                    height: iconSize,
                    fit: BoxFit.contain,
                    colorFilter: ColorFilter.mode(
                      iconColor ?? const Color(0xFF898686),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: monthToDateGap),
        Container(
          height: dateRowH,
          padding: EdgeInsets.symmetric(
            vertical: dateRowVPad,
            horizontal: dateRowHPad,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDateItem(context, displayDates[0], false),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDateItem(context, displayDates[1], true),
                  if (isToday)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: todayPadH,
                        vertical: todayPadV,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor ?? Colors.black,
                        borderRadius: BorderRadius.circular(todayRadius),
                      ),
                      child: Text(
                        '오늘',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: healthSp(context, 12),
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              _buildDateItem(context, displayDates[2], false),
            ],
          ),
        ),
      ],
    );
  }

  // 날짜 아이템 위젯
  Widget _buildDateItem(BuildContext context, DateTime date, bool isCenter) {
    final hasRecord = _hasRecord(date);
    final dateStr = DateFormat('M.d').format(date);

    return GestureDetector(
      onTap: () {
        onDateChanged(date);
      },
      child: SizedBox(
        width: healthDp(context, isCenter ? 80 : 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dateStr,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: healthSp(context, isCenter ? 18 : 14),
                fontWeight: isCenter ? FontWeight.bold : FontWeight.normal,
                color: isCenter
                    ? (primaryColor ?? Colors.black)
                    : (secondaryColor ?? Colors.grey[400]),
              ),
            ),
            if (hasRecord)
              Container(
                margin: EdgeInsets.only(top: healthDp(context, 8)),
                width: healthDp(context, 6),
                height: healthDp(context, 6),
                decoration: BoxDecoration(
                  color: isCenter
                      ? (primaryColor ?? Colors.black)
                      : (secondaryColor ?? Colors.grey[400]),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
