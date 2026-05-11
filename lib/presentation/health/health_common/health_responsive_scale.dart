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

/// 체중 일간 그래프 그리드 상·하 패딩 (375 기준 20).
double healthWeightChartVertPad(BuildContext context) =>
    healthDp(context, 20);

/// 체중 그래프 Y축 상단 `(kg)` 밴드 높이 (375 기준 16).
double healthWeightChartKgBandHeight(BuildContext context) =>
    healthDp(context, 16);

