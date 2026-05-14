import 'package:flutter/material.dart';

import 'health_responsive_scale.dart';

/// 건강 목록 그래프 축·단위 공통 (체중·혈압·혈당·심박수·걸음수 동일)
const String healthChartAxisFontFamily = 'Gmarket Sans TTF';

const Color healthChartAxisUnitColor = Color(0xFF898383);
const Color healthChartAxisLabelColor = Color(0xFF1A1A1A);
const Color healthChartAxisCurrentHourColor = Color(0xFFFF5A8D);

TextStyle healthChartAxisUnitTextStyle(BuildContext context) => TextStyle(
      fontFamily: healthChartAxisFontFamily,
      fontSize: healthSp(context, 10),
      color: healthChartAxisUnitColor,
      fontWeight: FontWeight.w700,
    );

TextStyle healthChartAxisTickTextStyle(
  BuildContext context, {
  Color? color,
}) =>
    TextStyle(
      fontFamily: healthChartAxisFontFamily,
      fontSize: healthSp(context, 12),
      color: color ?? healthChartAxisLabelColor,
      fontWeight: FontWeight.w400,
    );
