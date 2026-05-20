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
