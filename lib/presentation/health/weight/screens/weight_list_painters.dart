part of 'weight_list_screen.dart';

/// 목표체중 라벨 아래, 차트 쪽을 가리키는 아래방향 삼각형(채움).
class _GoalTargetDownTrianglePainter extends CustomPainter {
  const _GoalTargetDownTrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _GoalTargetDownTrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 목표 체중 원형: 전체 원 = 시작(목표설정 시 체중)~목표 체중 구간, 12시에서 반시계로 채움.
class _WeightGoalRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _WeightGoalRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, track);

    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;

    final sweep = -math.pi * 2 * p;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _WeightGoalRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

// 체중 차트 Painter
class WeightChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> chartData;
  final List<double> yLabels;
  final double timeOffset;
  final String selectedPeriod;
  final int? selectedPointIndex;
  final bool omitOutOfRangeWeights;
  final double topPadding;
  final double bottomPadding;
  final double barWidth;
  final double scale;
  final bool forExpandedChart;

  WeightChartPainter({
    required this.chartData,
    required this.yLabels,
    required this.timeOffset,
    required this.selectedPeriod,
    this.selectedPointIndex,
    this.omitOutOfRangeWeights = false,
    this.topPadding = 20,
    this.bottomPadding = 10,
    this.barWidth = 5,
    this.scale = 1.0,
    this.forExpandedChart = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (chartData.isEmpty || yLabels.length < 2) return;

    final minWeight = yLabels.last; // 최소값 (하단)
    final maxWeight = yLabels.first; // 최대값 (상단)
    final weightRange = maxWeight - minWeight;
    if (weightRange == 0) return;

    final m = HealthChartMetrics(scale);
    const double leftPadding = ChartConstants.weightDailyChartInnerPadH;
    const double rightPadding = ChartConstants.weightDailyChartInnerPadH +
        ChartConstants.weightXAxisUnitReservedWidth;

    // 데이터: 같은 시(hour)에 2건 이상이면 막대, 그 외는 점
    List<Offset> points = [];
    List<int> validIndices = [];
    final maxStartHour = healthDailyMaxStartHour(forExpandedChart);
    final slots = healthDailyHourSlotCount(forExpandedChart);
    final startHour =
        (timeOffset * maxStartHour).clamp(0, maxStartHour).round();
    final endHour = startHour + slots - 1;

    final barFill = Paint()
      ..color = const Color(0xFFFF5A8D)
      ..style = PaintingStyle.fill;

    final drawableTop = topPadding;
    final drawableBottom = size.height - bottomPadding;

    for (int i = 0; i < chartData.length; i++) {
      final data = chartData[i];

      if (selectedPeriod == '일' && data['hourSlotBar'] == true) {
        final minW = (data['minWeight'] as num).toDouble();
        final maxW = (data['maxWeight'] as num).toDouble();
        final recordHour = data['hour'] as int;
        if (omitOutOfRangeWeights && (maxW < minWeight || minW > maxWeight)) {
          continue;
        }
        if (recordHour < startHour || recordHour > endHour) {
          continue;
        }
        final xPosition = (data['xPosition'] as double?) ?? 0.5;
        final xCenter =
            leftPadding + (size.width - leftPadding - rightPadding) * xPosition;
        final yHi = topPadding +
            (size.height - topPadding - bottomPadding) *
                ((maxWeight - maxW) / weightRange);
        final yLo = topPadding +
            (size.height - topPadding - bottomPadding) *
                ((maxWeight - minW) / weightRange);
        var yTop = math.min(yHi, yLo);
        var yBottom = math.max(yHi, yLo);
        yTop = yTop.clamp(drawableTop, drawableBottom);
        yBottom = yBottom.clamp(drawableTop, drawableBottom);
        if (yBottom < yTop) {
          final t = yTop;
          yTop = yBottom;
          yBottom = t;
        }
        final midY = (yTop + yBottom) / 2;
        final barH = math.max(yBottom - yTop, m.minBarHeight);
        final isSel = selectedPointIndex != null && selectedPointIndex == i;
        final wBar = isSel ? barWidth + m.barWidthSelectedExtra : barWidth;
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(xCenter, midY),
            width: wBar,
            height: barH,
          ),
          Radius.circular(wBar / 2),
        );
        canvas.drawRRect(rect, barFill);
        if (isSel) {
          canvas.drawRRect(
            rect,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = m.highlightRingStroke,
          );
        }
        continue;
      }

      final weight = data['weight'];

      if (weight == null) continue; // null 값 스킵

      final w = (weight as num).toDouble();
      if (omitOutOfRangeWeights && (w < minWeight || w > maxWeight)) {
        continue;
      }

      if (selectedPeriod == '일') {
        final recordHour = data['hour'] as int?;
        if (recordHour != null &&
            (recordHour < startHour || recordHour > endHour)) {
          continue;
        }
      }

      double x;
      if (selectedPeriod == '일') {
        final xPosition = (data['xPosition'] as double?) ?? 0.5;
        x = leftPadding + (size.width - leftPadding - rightPadding) * xPosition;
      } else {
        if (data['xPosition'] == null) continue;
        final xPosition = data['xPosition'] as double;
        const visibleDays = 7;
        const totalDays = 30;
        if (selectedPeriod == '월') {
          final maxOffset = (totalDays - visibleDays) / totalDays;
          final currentOffset = timeOffset.clamp(0.0, maxOffset);
          final startIndex = (currentOffset * totalDays).floor();
          final endIndex = startIndex + visibleDays;
          final dataIndex = (xPosition * totalDays).round();
          if (dataIndex < startIndex || dataIndex >= endIndex) continue;
          final relativeIndex = dataIndex - startIndex;
          final adjustedRatio = relativeIndex / (visibleDays - 1);
          x = leftPadding +
              (size.width - leftPadding - rightPadding) * adjustedRatio;
        } else {
          x = leftPadding +
              (size.width - leftPadding - rightPadding) * xPosition;
        }
      }

      // Y 좌표 계산 (상단 [topPadding]/[bottomPadding]과 동일)
      final normalizedWeight = (maxWeight - w) / weightRange;
      final y = topPadding +
          (size.height - topPadding - bottomPadding) * normalizedWeight;

      points.add(Offset(x, y));
      validIndices.add(i);
    }

    // 포인트만 그리기 (선 없음), 점은 꽉 찬 색 - 그래프 점
    final pointPaint = Paint()
      ..color = const Color(0xFFFF5A8D)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final originalIndex = validIndices[i];
      final isSelected =
          selectedPointIndex != null && selectedPointIndex == originalIndex;

      if (isSelected) {
        canvas.drawCircle(point, m.pointRadiusHighlighted, pointPaint);
        canvas.drawCircle(
          point,
          m.pointRadiusHighlighted,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = m.highlightRingStroke,
        );
      } else {
        canvas.drawCircle(point, m.pointRadius, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant WeightChartPainter oldDelegate) {
    return oldDelegate.chartData != chartData ||
        oldDelegate.yLabels != yLabels ||
        oldDelegate.timeOffset != timeOffset ||
        oldDelegate.selectedPeriod != selectedPeriod ||
        oldDelegate.selectedPointIndex != selectedPointIndex ||
        oldDelegate.omitOutOfRangeWeights != omitOutOfRangeWeights ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.bottomPadding != bottomPadding ||
        oldDelegate.barWidth != barWidth ||
        oldDelegate.scale != scale ||
        oldDelegate.forExpandedChart != forExpandedChart;
  }
}
