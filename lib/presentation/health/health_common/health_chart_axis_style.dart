import 'package:flutter/material.dart';

/// 건강 목록 그래프 축·단위 공통 (체중·혈압·혈당·심박수·걸음수 동일)
///
/// 글자 크기는 **논리 픽셀(375 기준)** 로 두고, 상위 [MediaQuery]의
/// `textScaler`(예: `TextScaler.linear(healthTextScaleByWidth)`)로만 확대한다.
const String healthChartAxisFontFamily = 'Gmarket Sans TTF';

const Color healthChartAxisUnitColor = Color(0xFF898383);
const Color healthChartAxisLabelColor = Color(0xFF1A1A1A);
const Color healthChartAxisCurrentHourColor = Color(0xFFFF5A8D);

TextStyle healthChartAxisUnitTextStyle(BuildContext context) => TextStyle(
      fontFamily: healthChartAxisFontFamily,
      fontSize: 10,
      color: healthChartAxisUnitColor,
      fontWeight: FontWeight.w700,
    );

TextStyle healthChartAxisTickTextStyle(
  BuildContext context, {
  Color? color,
  double fontSize = 12,
}) =>
    TextStyle(
      fontFamily: healthChartAxisFontFamily,
      fontSize: fontSize,
      color: color ?? healthChartAxisLabelColor,
      fontWeight: FontWeight.w400,
    );

/// 시간대별(일) X축: 카드 7시간 / 확대 12시간 (+ `(시)` 단위 = 13)
const int healthDailyHourSlotsCard = 7;
const int healthDailyHourSlotsExpanded = 12;

int healthDailyHourSlotCount(bool forExpandedChart) =>
    forExpandedChart ? healthDailyHourSlotsExpanded : healthDailyHourSlotsCard;

int healthDailyMaxStartHour(bool forExpandedChart) =>
    24 - healthDailyHourSlotCount(forExpandedChart);

/// 오늘 차트에서 현재 시각이 창 안쪽에 오도록 하는 시작 시
int healthDailyTargetStartHour(
  int currentHour, {
  bool forExpandedChart = false,
}) {
  final maxStart = healthDailyMaxStartHour(forExpandedChart);
  final slots = healthDailyHourSlotCount(forExpandedChart);
  return (currentHour - (slots - 2)).clamp(0, maxStart);
}

double healthDailyTimeOffsetForToday({bool forExpandedChart = false}) {
  final maxStart = healthDailyMaxStartHour(forExpandedChart);
  if (maxStart <= 0) return 0.0;
  return healthDailyTargetStartHour(
        DateTime.now().hour,
        forExpandedChart: forExpandedChart,
      ) /
      maxStart;
}

/// 월별 X축: 카드 7개월 / 확대 12개월 (+ `(월)` 단위 = 13)
const int healthMonthlySlotsCard = 7;
const int healthMonthlySlotsExpanded = 12;
const int healthCalendarYearMonthCount = 12;

int healthMonthlySlotCount(bool forExpandedChart) =>
    forExpandedChart ? healthMonthlySlotsExpanded : healthMonthlySlotsCard;

int healthMonthlyMaxStartIndex(bool forExpandedChart) =>
    healthCalendarYearMonthCount - healthMonthlySlotCount(forExpandedChart);

/// 선택 월이 창에 보이도록 timeOffset (확대 12개월이면 0)
double healthMonthlyTimeOffsetForSelectedMonth(
  int selectedMonth, {
  bool forExpandedChart = false,
}) {
  final maxStart = healthMonthlyMaxStartIndex(forExpandedChart);
  if (maxStart <= 0) return 0.0;
  final slots = healthMonthlySlotCount(forExpandedChart);
  final targetStart = (selectedMonth - slots).clamp(0, maxStart);
  return targetStart / maxStart;
}
