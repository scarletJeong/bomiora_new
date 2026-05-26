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

/// 건강 AppBar 상단 여백 (375 기준 10).
double healthAppBarTopGap(BuildContext context) => healthDp(context, 10);

/// 건강 AppBar 툴바 행 높이 (375 기준 28).
double healthAppBarHeight(BuildContext context) => healthDp(context, 28);

/// 건강 AppBar 제목 위·아래 패딩 (375 기준 5).
double healthAppBarTitlePaddingV(BuildContext context) => healthDp(context, 5);

/// AppBar 전체 높이 = 상단 10 + 툴바 28 (375 기준 38).
double healthAppBarTotalHeight(BuildContext context) =>
    healthAppBarTopGap(context) + healthAppBarHeight(context);

/// [PreferredSize] 등 context 없이 전체 높이 (폭 클램프 규칙 동일).
double healthAppBarTotalHeightForWidth(double layoutWidth) =>
    (10 + 28) * healthTextScaleByWidth(layoutWidth);

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

/// 「수정할 시간 선택」 바텀시트 — 외곽 패딩 (375 기준 LTRB 30,20,30,30).
EdgeInsets healthEditSheetOuterPadding(BuildContext context) =>
    EdgeInsets.fromLTRB(
      healthDp(context, 30),
      healthDp(context, 20),
      healthDp(context, 30),
      healthDp(context, 30),
    );

/// 바텀시트 제목 행 좌우 패딩 (375 기준 4).
double healthEditSheetTitleHorizontalPad(BuildContext context) =>
    healthDp(context, 4);

/// 제목 ↔ 구분선 (375 기준 10).
double healthEditSheetTitleToDividerGap(BuildContext context) =>
    healthDp(context, 10);

/// 구분선 ↔ 목록 (375 기준 20).
double healthEditSheetDividerToListGap(BuildContext context) =>
    healthDp(context, 20);

/// 시간 항목 사이 간격 (375 기준 20).
double healthEditSheetListItemGap(BuildContext context) =>
    healthDp(context, 20);

/// 시간 항목 카드 내부 패딩 (375 기준 10).
EdgeInsets healthEditSheetItemPadding(BuildContext context) =>
    EdgeInsets.all(healthDp(context, 10));

/// 시간 아이콘 ↔ 시각 텍스트 (375 기준 15).
double healthEditSheetTimeIconGap(BuildContext context) => healthDp(context, 15);

/// trailing ↔ chevron (375 기준 10).
double healthEditSheetTrailingChevronGap(BuildContext context) =>
    healthDp(context, 10);

