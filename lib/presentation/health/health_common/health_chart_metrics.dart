import 'package:flutter/widgets.dart';

import 'health_responsive_scale.dart';

/// 건강 그래프 막대·원형·선 두께 (375 기준 × [scale]).
///
/// CustomPainter는 [scale]만 받고, 위젯에서는 [HealthChartMetrics.of]로 생성해
/// [barWidth] 등을 painter에 넘긴다.
class HealthChartMetrics {
  const HealthChartMetrics(this.scale);

  final double scale;

  factory HealthChartMetrics.of(BuildContext context) {
    return HealthChartMetrics(
      healthTextScaleByWidth(MediaQuery.sizeOf(context).width),
    );
  }

  factory HealthChartMetrics.ofWidth(double layoutWidth) {
    return HealthChartMetrics(healthTextScaleByWidth(layoutWidth));
  }

  // 막대(채움/둥근 막대)
  double get barWidth => 5 * scale;
  double get barWidthSelectedExtra => 3 * scale;

  // 막대(선 스트로크 — 혈압·체중 주/월)
  double get barStroke => 5 * scale;
  double get barStrokeSelected => 8 * scale;
  double get barStrokeWeightRange => 10 * scale;
  double get barStrokeWeightRangeSelected => 12 * scale;

  // 점
  double get pointRadius => 4 * scale;
  double get pointRadiusHighlighted => 6 * scale;
  double get pointRadiusBpHighlight => 6 * scale;
  double get pointRadiusWeightDot => 5 * scale;
  double get pointRadiusWeightDotSelected => 6.5 * scale;
  double get dotOuter => 4 * scale;
  double get dotInner => 3 * scale;

  // 원형 링·테두리
  double get highlightRingStroke => 2 * scale;
  double get seriesLineStroke => 2.5 * scale;
  double get plusArmStroke => 1.6 * scale;
  double get gridStroke => 0.5 * scale;
  double get borderStroke => 0.5 * scale;

  // 막대 최소 높이·히트
  double get minBarHeight => 4 * scale;
  double get minBarHeightHeart => 5 * scale;
  double get hitSlop => 14 * scale;
  double get slotHitHalfWidthFallback => 24 * scale;

  // 혈당 겹침 클러스터
  double get overlapClusterRadius => 5 * scale;
  double get overlapClusterRadiusHighlighted => 8 * scale;

  // 빈 차트 격자 좌측 inset (375 기준 8.5)
  double get emptyGridLeftInset => 8.5 * scale;
}
