import 'dart:math' as math;

import 'package:flutter/material.dart';

@immutable
class ResponsiveScaleData {
  const ResponsiveScaleData({
    required this.maxWidth,
    required this.width,
    required this.scale,
    required this.textScale,
  });

  /// 디자인 기준 폭 (예: 650px)
  final double maxWidth;

  /// 현재 실제로 사용 중인 레이아웃 폭 (min(screenWidth, maxWidth))
  final double width;

  /// 크기(간격/높이/반경 등)용 스케일
  final double scale;

  /// 텍스트용 스케일 (너무 작아지지 않게 별도로 클램프)
  final double textScale;

  double dp(num value) => (value.toDouble() * scale);
  double sp(num value) => (value.toDouble() * textScale);
}

class ResponsiveScaleScope extends InheritedWidget {
  const ResponsiveScaleScope({
    super.key,
    required this.data,
    required super.child,
  });

  final ResponsiveScaleData data;

  static ResponsiveScaleData of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ResponsiveScaleScope>();
    assert(scope != null, 'ResponsiveScaleScope가 위젯 트리에 없습니다.');
    return scope!.data;
  }

  @override
  bool updateShouldNotify(covariant ResponsiveScaleScope oldWidget) {
    return oldWidget.data.width != data.width ||
        oldWidget.data.scale != data.scale ||
        oldWidget.data.textScale != data.textScale ||
        oldWidget.data.maxWidth != data.maxWidth;
  }
}

extension ResponsiveScaleX on BuildContext {
  ResponsiveScaleData get rs => ResponsiveScaleScope.of(this);
}

ResponsiveScaleData buildResponsiveScale({
  required BoxConstraints constraints,
  double maxWidth = 650,
  double minTextScale = 0.88,
}) {
  final rawW = constraints.maxWidth.isFinite ? constraints.maxWidth : maxWidth;
  final width = math.min(rawW, maxWidth).clamp(0.0, maxWidth);
  final rawScale = maxWidth <= 0 ? 1.0 : (width / maxWidth);

  // 레이아웃(카드 높이/패딩/라운드 등)은 화면이 작아질수록 축소
  final scale = rawScale.clamp(0.75, 1.0);

  // 텍스트는 너무 작아지면 가독성이 급격히 떨어져서 별도로 완만하게 클램프
  final textScale = rawScale.clamp(minTextScale, 1.0);

  return ResponsiveScaleData(
    maxWidth: maxWidth,
    width: width,
    scale: scale,
    textScale: textScale,
  );
}

/// 3개 기준점(375/450/650)에 맞춰 구간별 선형 보간한 값을 반환합니다.
///
/// - width <= 375: v375
/// - 375 < width < 450: lerp(v375, v450)
/// - 450 <= width < 650: lerp(v450, v650)
/// - width >= 650: v650
double lerpByWidth375_450_650({
  required double width,
  required double v375,
  required double v450,
  required double v650,
}) {
  final w = width.isFinite ? width.clamp(0.0, 100000.0) : 375.0;
  if (w <= 375) return v375;
  if (w < 450) {
    final t = (w - 375) / (450 - 375);
    return v375 + (v450 - v375) * t;
  }
  if (w < 650) {
    final t = (w - 450) / (650 - 450);
    return v450 + (v650 - v450) * t;
  }
  return v650;
}

// ---------------------------------------------------------------------------
// 홈 카드(375 / 450 / 650)에서 정리된 공통 규칙 — 필요한 화면에서 그대로 호출
// ---------------------------------------------------------------------------

/// 제목 `letterSpacing` ≈ `-0.1 × fontSize`
double homeCardTitleLetterSpacing(double titleFontSize) => -0.1 * titleFontSize;

/// 본문(보조 설명) `letterSpacing` ≈ `-0.05 × fontSize`
double homeCardBodyLetterSpacing(double bodyFontSize) => -0.05 * bodyFontSize;

/// 설명 폰트 ≈ 제목 × (11.54 / 15) — 카테고리 등 디자인 비율과 동일
const double kHomeCardBodyToTitleFontRatio = 11.54 / 15;

double homeCardBodyFontSizeFromTitle(double titleFontSize) =>
    titleFontSize * kHomeCardBodyToTitleFontRatio;

/// 카드 폭이 375→450, 450→650로 바뀔 때 관측된 대략 비율(참고·문서용)
const double kHomeCategoryCardWidthRatio375To450 = 185.54 / 154.62;
const double kHomeCategoryCardWidthRatio450To650 = 268 / 185.54;

/// `referenceCardWidth`(예: 375에서의 카드 폭)에서 정의한 간격을,
/// `currentCardWidth`에 맞게 비례 스케일 (간격이 폭에 같이 따라갈 때).
double scaleSpacingByCardWidth({
  required double spacingAtReferenceWidth,
  required double referenceCardWidth,
  required double currentCardWidth,
}) {
  if (referenceCardWidth <= 0 || !referenceCardWidth.isFinite) {
    return spacingAtReferenceWidth;
  }
  if (!currentCardWidth.isFinite) return spacingAtReferenceWidth;
  return spacingAtReferenceWidth * (currentCardWidth / referenceCardWidth);
}

