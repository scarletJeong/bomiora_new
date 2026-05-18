import 'package:flutter/material.dart';

/// Health 화면 전용 텍스트 스케일.
///
/// - 375 기준: 1.0
/// - 650 기준: 650/375
/// - 화면 폭은 375~650으로 클램프
double healthTextScaleByWidth(double width) {
  final clamped = width.clamp(375.0, 650.0);
  return clamped / 375.0;
}

/// 375 기준 폰트 크기를 Health 레이아웃 폭 기준으로 스케일합니다.
double healthSp(BuildContext context, double base) {
  final width = MediaQuery.of(context).size.width;
  return base * healthTextScaleByWidth(width);
}

/// 375 기준 길이(패딩/높이/반경 등)를 Health 레이아웃 폭 기준으로 스케일합니다.
double healthDp(BuildContext context, double base) {
  final width = MediaQuery.of(context).size.width;
  return base * healthTextScaleByWidth(width);
}

/// 건강 AppBar 상단 여백 (375 기준 20).
double healthAppBarTopGap(BuildContext context) => healthDp(context, 20);

/// 건강 AppBar 툴바 행 높이 (375 기준 28).
double healthAppBarHeight(BuildContext context) => healthDp(context, 28);

/// 건강 AppBar 제목 위·아래 패딩 (375 기준 5).
double healthAppBarTitlePaddingV(BuildContext context) => healthDp(context, 5);

/// AppBar 전체 높이 = 상단 20 + 툴바 28 (375 기준 48).
double healthAppBarTotalHeight(BuildContext context) =>
    healthAppBarTopGap(context) + healthAppBarHeight(context);

/// [PreferredSize] 등 context 없이 전체 높이 (폭 클램프 규칙 동일).
double healthAppBarTotalHeightForWidth(double layoutWidth) =>
    (20 + 28) * healthTextScaleByWidth(layoutWidth);

/// 체중 일간 그래프 그리드 **상단** 패딩 (375 기준 20).
double healthWeightChartVertPad(BuildContext context) =>
    healthDp(context, 20);

/// 격자·Y눈금 하단 ~ X축 라벨까지 **플롯 내부** 하단 여백 (375 기준 10).
double healthWeightChartBottomPlotPad(BuildContext context) =>
    healthDp(context, 10);

/// 체중 그래프 Y축 상단 `(kg)` 밴드 높이 (375 기준 16).
double healthWeightChartKgBandHeight(BuildContext context) =>
    healthDp(context, 16);

/// 건강 그래프 카드 패딩 — 체중·혈압·혈당·심박수·걸음수 공통 (375 기준 LTRB 4,6,15,6 → [healthDp]로 통일).
EdgeInsets healthChartCardPadding(BuildContext context) =>
    EdgeInsets.fromLTRB(
      healthDp(context, 4),
      healthDp(context, 6),
      healthDp(context, 15),
      healthDp(context, 6),
    );

