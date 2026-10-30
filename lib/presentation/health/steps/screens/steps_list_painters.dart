part of 'steps_list_screen.dart';

class _StepsGoalRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double trackStrokeWidth;
  final double progressStrokeWidth;

  _StepsGoalRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required double strokeWidth,
    double? progressStrokeWidth,
  })  : trackStrokeWidth = strokeWidth,
        progressStrokeWidth = progressStrokeWidth ?? strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final trackW = trackStrokeWidth;
    final progressW = progressStrokeWidth;
    final maxW = math.max(trackW, progressW);
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - maxW / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackW
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = progressW
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, track);

    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;

    /// 12시 방향에서 **반시계** 방향으로 채움
    final sweep = -math.pi * 2 * p;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _StepsGoalRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackStrokeWidth != trackStrokeWidth ||
        oldDelegate.progressStrokeWidth != progressStrokeWidth;
  }
}

class _StepsBarData {
  final String label;
  final int value;

  const _StepsBarData({
    required this.label,
    required this.value,
  });
}

/// 혈압·체중 차트와 동일: (시)/(일)/(월) 단위 여백 + 좌측 inset 반영한 플롯 폭
double _stepsChartContentWidth(
  double plotWidth, {
  required double scale,
  required double xUnitReservedWidth,
}) {
  final m = HealthChartMetrics(scale);
  return plotWidth -
      BloodPressureChartPainter.borderWidth * 2 -
      m.pointRadius * 2 -
      xUnitReservedWidth;
}

double _stepsDailyRelHalfFromLocalX(
  double localX,
  double plotWidth, {
  required double scale,
  required double xUnitReservedWidth,
}) {
  final m = HealthChartMetrics(scale);
  final left = BloodPressureChartPainter.borderWidth + m.pointRadius;
  final cw = _stepsChartContentWidth(
    plotWidth,
    scale: scale,
    xUnitReservedWidth: xUnitReservedWidth,
  );
  if (cw <= 1) return 0;
  return ((localX - left) / cw * 7.0 - 0.5) * 2.0;
}

/// 주·월 플롯 폭 — 체중 주간 차트와 동일(좌 inset 없음, 우 (일)/(월) 여백만 제외)
double _stepsWeekMonthPlotWidth(
  double plotWidth, {
  required double xUnitReservedWidth,
}) {
  return math.max(plotWidth - xUnitReservedWidth, 1.0);
}

double _stepsWeekMonthSlotCenterX({
  required int index,
  required int slotCount,
  required double plotContentWidth,
}) {
  return plotContentWidth * (index + 0.5) / slotCount;
}

double _stepsBarSlotCenterX({
  required int index,
  required int slotCount,
  required double plotWidth,
  required double scale,
  required double xUnitReservedWidth,
  required bool isDailyHalfHour,
  required int dailyStartSlot,
}) {
  if (isDailyHalfHour) {
    final relHalf = (dailyStartSlot.isOdd ? 1 : 0) + index;
    final m = HealthChartMetrics(scale);
    final left = BloodPressureChartPainter.borderWidth + m.pointRadius;
    final cw = _stepsChartContentWidth(
      plotWidth,
      scale: scale,
      xUnitReservedWidth: xUnitReservedWidth,
    );
    return left + cw * (0.5 + relHalf / 2.0) / 7.0;
  }
  return _stepsWeekMonthSlotCenterX(
    index: index,
    slotCount: slotCount,
    plotContentWidth: _stepsWeekMonthPlotWidth(
      plotWidth,
      xUnitReservedWidth: xUnitReservedWidth,
    ),
  );
}

class _StepsBarChartPainter extends CustomPainter {
  /// 375 기준 막대 width (일·주·월 공통, × scale → 650pt 폭에서 8.67)
  static const double barWidthBase = 5.0;

  static double barWidthFor({required double scale}) => barWidthBase * scale;

  final List<_StepsBarData> data;
  final int maxValue;
  final int yTickCount;
  final double scale;
  final double xUnitReservedWidth;
  final double topPadding;
  final double bottomPadding;
  final bool isDailyHalfHour;
  final int dailyStartSlot;
  final double barCornerRadius;
  final double gridStrokeWidth;

  _StepsBarChartPainter({
    required this.data,
    required this.maxValue,
    required this.yTickCount,
    this.scale = 1.0,
    required this.xUnitReservedWidth,
    this.topPadding = 20,
    this.bottomPadding = 20,
    required this.isDailyHalfHour,
    this.dailyStartSlot = 0,
    this.barCornerRadius = 10,
    this.gridStrokeWidth = 0.5,
  });

  double get _barWidth => barWidthFor(scale: scale);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final chartHeight = size.height - topPadding - bottomPadding;

    final barPaint = Paint()
      ..color = const Color(0xFFFF5A8D)
      ..style = PaintingStyle.fill;

    final scaleMax = maxValue <= 0 ? 1 : maxValue;
    final corner = Radius.circular(barCornerRadius);
    for (int i = 0; i < data.length; i++) {
      if (data[i].value <= 0) continue;
      final factor = (data[i].value / scaleMax).clamp(0.0, 1.0);
      final barHeight = chartHeight * factor;
      if (barHeight <= 0) continue;

      final xCenter = _stepsBarSlotCenterX(
        index: i,
        slotCount: data.length,
        plotWidth: size.width,
        scale: scale,
        xUnitReservedWidth: xUnitReservedWidth,
        isDailyHalfHour: isDailyHalfHour,
        dailyStartSlot: dailyStartSlot,
      );
      final w = _barWidth;
      final x = xCenter - (w / 2);
      final y = topPadding + chartHeight - barHeight;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, w, barHeight),
        topLeft: corner,
        topRight: corner,
        bottomLeft: Radius.zero,
        bottomRight: Radius.zero,
      );
      canvas.drawRRect(rect, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StepsBarChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.yTickCount != yTickCount ||
        oldDelegate.scale != scale ||
        oldDelegate.isDailyHalfHour != isDailyHalfHour ||
        oldDelegate.xUnitReservedWidth != xUnitReservedWidth ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.bottomPadding != bottomPadding ||
        oldDelegate.dailyStartSlot != dailyStartSlot ||
        oldDelegate.barCornerRadius != barCornerRadius ||
        oldDelegate.gridStrokeWidth != gridStrokeWidth;
  }
}
