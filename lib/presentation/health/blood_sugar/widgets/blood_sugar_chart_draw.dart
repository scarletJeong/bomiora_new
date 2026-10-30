part of 'blood_sugar_chart_section.dart';

Map<String, dynamic> _tooltipRowForChartIndex(
  List<Map<String, dynamic>> chartData,
  int index,
  double chartWidth,
  double chartHeight,
  double minValue,
  double maxValue,
  double plotTop,
  double plotBottom, {
  double scale = 1.0,
  double? xUnitReservedWidth,
}) {
  if (index < 0) {
    final ci = -index - 1;
    final clusters = bloodSugarComputeWeekMonthOverlapClusters(
      chartData,
      Size(chartWidth, chartHeight),
      minValue,
      maxValue,
      plotTop: plotTop,
      plotBottom: plotBottom,
      scale: scale,
      xUnitReservedWidth: xUnitReservedWidth,
    );
    if (ci < 0 || ci >= clusters.length) {
      return chartData.isNotEmpty ? chartData[0] : {};
    }
    final raw = clusters[ci].dataIndices.map((di) {
      final row = chartData[di];
      return <String, dynamic>{
        'measurementType': row['measurementType']?.toString() ?? '',
        'bloodSugar': row['bloodSugar'],
        'record': row['record'],
        'date': row['date']?.toString() ?? '',
      };
    }).toList();
    raw.sort((a, b) => _tooltipMeasurementTypeOrder(
          a['measurementType'] as String?,
        ).compareTo(
          _tooltipMeasurementTypeOrder(b['measurementType'] as String?),
        ));
    final firstDi = clusters[ci].dataIndices.first;
    final firstRow = chartData[firstDi];
    final slotDate = raw.isNotEmpty ? (raw.first['date'] as String? ?? '') : '';
    return {
      'bloodSugarOverlapCluster': true,
      'overlapEntries': raw,
      'date': slotDate,
      'chartYear': firstRow['chartYear'],
      'record': firstRow['record'],
    };
  }
  if (index >= 0 && index < chartData.length) return chartData[index];
  return chartData.isNotEmpty ? chartData[0] : {};
}

const double _bloodSugarChartBorderWidth = 0.5;
const double _bloodSugarChartPointRadius = 4.0;
// X축 라벨 inset은 위젯에서 scale 반영 후 동적으로 계산한다.

Widget buildBloodSugarXAxisLabels(
  BuildContext context, {
  required String selectedPeriod,
  required DateTime selectedDate,
  required double timeOffset,
  required bool chartIsToday,
  bool forExpandedChart = false,
}) {
  if (selectedPeriod != '일') {
    return _buildBloodSugarPeriodXAxisLabels(
      context,
      selectedPeriod: selectedPeriod,
      selectedDate: selectedDate,
      timeOffset: timeOffset,
      forExpandedChart: forExpandedChart,
    );
  }

  final maxStartHour = healthDailyMaxStartHour(forExpandedChart);
  final slots = healthDailyHourSlotCount(forExpandedChart);
  final startHour =
      (timeOffset * maxStartHour).clamp(0.0, maxStartHour.toDouble()).round();

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final selDay =
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  final isToday = chartIsToday && selDay == today;
  final currentHour = now.hour;

  final hourLabels = <Widget>[];
  for (int i = 0; i < slots; i++) {
    final hour = (startHour + i).clamp(0, 24);
    final hourLabel = hour == 24 ? '24' : hour.toString().padLeft(2, '0');
    final isCurrentHour = isToday && hour == currentHour;
    hourLabels.add(
      Expanded(
        child: Text(
          hourLabel,
          textAlign: TextAlign.center,
          style: healthChartAxisTickTextStyle(
            context,
            color: isCurrentHour ? healthChartAxisCurrentHourColor : null,
          ),
        ),
      ),
    );
  }

  return _buildBloodSugarXAxisWithUnit(
    context,
    labelRow: Row(children: hourLabels),
    unitText: '(시)',
    forExpandedChart: forExpandedChart,
  );
}

Widget _buildBloodSugarPeriodXAxisLabels(
  BuildContext context, {
  required String selectedPeriod,
  required DateTime selectedDate,
  required double timeOffset,
  bool forExpandedChart = false,
}) {
  if (selectedPeriod == '월') {
    final visibleMonths = healthMonthlySlotCount(forExpandedChart);
    final maxStart = healthMonthlyMaxStartIndex(forExpandedChart);
    final startIndex = (timeOffset * maxStart).round().clamp(0, maxStart);

    return _buildBloodSugarXAxisWithUnit(
      context,
      labelRow: Row(
        children: List.generate(visibleMonths, (i) {
          final m = startIndex + i + 1;
          return Expanded(
            child: Text(
              '$m',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: healthChartAxisTickTextStyle(context),
            ),
          );
        }),
      ),
      unitText: '(월)',
      forExpandedChart: forExpandedChart,
    );
  }

  const days = 7;
  final endDate =
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  final startDate = endDate.subtract(Duration(days: days - 1));

  final allDateLabels = <String>[];
  for (int i = 0; i < days; i++) {
    final date = startDate.add(Duration(days: i));
    allDateLabels.add('${date.day}');
  }

  final dateRow = Row(
    children: allDateLabels.map((label) {
      return Expanded(
        child: Text(
          label,
          style: healthChartAxisTickTextStyle(context),
          textAlign: TextAlign.center,
        ),
      );
    }).toList(),
  );

  return _buildBloodSugarXAxisWithUnit(
    context,
    labelRow: dateRow,
    unitText: '(일)',
    forExpandedChart: forExpandedChart,
  );
}

Widget _buildBloodSugarXAxisWithUnit(
  BuildContext context, {
  required Widget labelRow,
  required String unitText,
  bool forExpandedChart = false,
}) {
  final unitReserve =
      healthDp(context, ChartConstants.weightXAxisUnitReservedWidth);
  final plotInset = _bloodSugarChartBorderWidth +
      healthDp(context, _bloodSugarChartPointRadius);
  // 확대: 12칸 월 라벨 + 점 inset 때문에 (월)이 밖으로 밀리기 쉬움 → 여유·안쪽 배치
  final unitRight = forExpandedChart ? healthDp(context, 1) : -healthDp(context, 10);
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Padding(
        // 점이 그려지는 플롯과 동일한 좌우 inset — scale 반영
        padding: EdgeInsets.only(
          left: plotInset,
          right: unitReserve + plotInset,
        ),
        child: labelRow,
      ),
      Positioned(
        right: unitRight,
        top: forExpandedChart ? 0 : healthDp(context, 3),
        bottom: forExpandedChart ? 0 : null,
        child: Align(
          alignment: Alignment.center,
          child: Text(
            unitText,
            style: healthChartAxisUnitTextStyle(context),
          ),
        ),
      ),
    ],
  );
}

class _GlucoseSeriesLegend extends StatelessWidget {
  final Color color;
  final String label;
  final bool compact;

  const _GlucoseSeriesLegend({
    required this.color,
    required this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final dot = compact ? healthDp(context, 8) : healthDp(context, 12);
    final gap = compact ? healthDp(context, 3) : healthDp(context, 5);
    final fontSize = compact ? 9.0 : 12.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dot,
          height: dot,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: gap),
        Text(
          label,
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class BloodSugarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double minValue;
  final double maxValue;
  final List<double>? yLabels;
  final int? highlightedIndex;
  final bool isToday;
  final double timeOffset;
  final String selectedPeriod;
  final double topPlotPad;
  final double bottomPlotPad;

  /// 375 기준 1.0, 650 기준 ≈1.73 — healthTextScaleByWidth 값을 넘긴다.
  final double scale;

  /// 위젯 라벨 row의 (시)/(일)/(월) 오른쪽 여백과 동일하게 painter에도 전달.
  final double? xUnitReservedWidth;

  BloodSugarChartPainter(
    this.data,
    this.minValue,
    this.maxValue, {
    this.yLabels,
    this.highlightedIndex,
    required this.isToday,
    required this.timeOffset,
    required this.selectedPeriod,
    required this.topPlotPad,
    required this.bottomPlotPad,
    this.scale = 1.0,
    this.xUnitReservedWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const double borderWidth = _bloodSugarChartBorderWidth;
    final double pointRadius = _bloodSugarChartPointRadius * scale;
    final double unitReserve =
        xUnitReservedWidth ?? ChartConstants.weightXAxisUnitReservedWidth;
    final x0 = borderWidth + pointRadius;
    final chartWidth =
        size.width - (borderWidth * 2) - (pointRadius * 2) - unitReserve;

    if (selectedPeriod == '일') {
      _paintDailySeries(canvas, size, x0, chartWidth);
    } else {
      _paintWeekMonthSeries(canvas, size, x0, chartWidth);
    }
  }

  void _paintDailySeries(
    Canvas canvas,
    Size size,
    double x0,
    double chartWidth,
  ) {
    const maxStartHour = 18;
    final startHour =
        (timeOffset * maxStartHour).clamp(0, maxStartHour).round();
    final endHour = startHour + 6;
    final m = HealthChartMetrics(scale);
    final points = <Offset>[];
    final pointIndices = <int>[];
    final barPaint = Paint()..style = PaintingStyle.fill;
    final barWidth = m.barWidth;

    for (int i = 0; i < data.length; i++) {
      if (data[i]['hourSlotBar'] == true) {
        final minSugar = data[i]['minBloodSugar'] as int?;
        final maxSugar = data[i]['maxBloodSugar'] as int?;
        final recordHour = data[i]['hour'] as int?;
        if (minSugar == null || maxSugar == null || recordHour == null)
          continue;
        if (recordHour < startHour || recordHour > endHour) continue;
        final xPosition = (data[i]['xPosition'] as double?) ?? 0.5;
        final xCenter = x0 + (chartWidth * xPosition);
        final clampedMin =
            minSugar.clamp(minValue.toInt(), maxValue.toInt()).toDouble();
        final clampedMax =
            maxSugar.clamp(minValue.toInt(), maxValue.toInt()).toDouble();
        final minNorm = (maxValue - clampedMin) / (maxValue - minValue);
        final maxNorm = (maxValue - clampedMax) / (maxValue - minValue);
        final yMin =
            topPlotPad + (size.height - topPlotPad - bottomPlotPad) * minNorm;
        final yMax =
            topPlotPad + (size.height - topPlotPad - bottomPlotPad) * maxNorm;
        final yTop = math.min(yMin, yMax);
        final yBottom = math.max(yMin, yMax);
        final centerY = (yTop + yBottom) / 2;
        final barHeight = math.max(yBottom - yTop, m.minBarHeight);
        final isHighlighted = highlightedIndex != null && highlightedIndex == i;
        final barColor = data[i]['barColor'] is Color
            ? data[i]['barColor'] as Color
            : const Color(0xFFFF5A8D);
        barPaint.color = barColor;
        final w = isHighlighted
            ? barWidth + m.barWidthSelectedExtra
            : barWidth;
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(xCenter, centerY),
            width: w,
            height: barHeight,
          ),
          Radius.circular(w / 2),
        );
        canvas.drawRRect(rect, barPaint);
        if (isHighlighted) {
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
      if (data[i]['bloodSugar'] == null) continue;
      final recordHour = data[i]['hour'] as int?;
      if (recordHour != null &&
          (recordHour < startHour || recordHour > endHour)) {
        continue;
      }

      double x;
      if (data[i]['xPosition'] != null) {
        final xPosition = data[i]['xPosition'] as double;
        x = x0 + (chartWidth * xPosition);
      } else {
        x = data.length == 1
            ? x0 + chartWidth / 2
            : x0 + (chartWidth * i / (data.length - 1));
      }

      final bloodSugar = data[i]['bloodSugar'] as int;
      final clamped =
          bloodSugar.clamp(minValue.toInt(), maxValue.toInt()).toDouble();
      final normalized = (maxValue - clamped) / (maxValue - minValue);
      final y =
          topPlotPad + (size.height - topPlotPad - bottomPlotPad) * normalized;

      points.add(Offset(x, y));
      pointIndices.add(i);
    }

    for (int i = 0; i < points.length; i++) {
      final originalIndex = pointIndices[i];
      final isHighlighted =
          highlightedIndex != null && highlightedIndex == originalIndex;
      final pointPaint = Paint()
        ..color = _seriesColorForDataIndex(originalIndex)
        ..style = PaintingStyle.fill;
      if (isHighlighted) {
        canvas.drawCircle(points[i], m.pointRadiusHighlighted, pointPaint);
        canvas.drawCircle(
          points[i],
          m.pointRadiusHighlighted,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = m.highlightRingStroke,
        );
      } else {
        canvas.drawCircle(points[i], m.pointRadius, pointPaint);
      }
    }
  }

  /// 주/월: 측정유형별로 같은 유형의 점만 연결.
  /// 서로 다른 측정유형인데 점(반지름 5)이 원 면적 기준 1/3 이상 겹치면 흰 원+핑크 테두리+플러스 1개.
  void _paintWeekMonthSeries(
    Canvas canvas,
    Size size,
    double x0,
    double chartWidth,
  ) {
    final indices = <int>[];
    for (int i = 0; i < data.length; i++) {
      if (data[i]['bloodSugar'] != null) indices.add(i);
    }
    if (indices.isEmpty) return;

    final overlapRender = bloodSugarComputeWeekMonthOverlapClusters(
      data,
      size,
      minValue,
      maxValue,
      plotTop: topPlotPad,
      plotBottom: bottomPlotPad,
      scale: scale,
      xUnitReservedWidth: xUnitReservedWidth,
    );

    double yForValue(int v) {
      final clamped = v.clamp(minValue.toInt(), maxValue.toInt()).toDouble();
      final normalized = (maxValue - clamped) / (maxValue - minValue);
      return topPlotPad +
          (size.height - topPlotPad - bottomPlotPad) * normalized;
    }

    Offset offsetForIndex(int i) {
      final xPosition = data[i]['xPosition'] as double;
      final x = x0 + chartWidth * xPosition;
      final y = yForValue(data[i]['bloodSugar'] as int);
      return Offset(x, y);
    }

    final inOverlap = <int>{};
    for (final c in overlapRender) {
      for (final di in c.dataIndices) {
        inOverlap.add(di);
      }
    }

    final m = HealthChartMetrics(scale);
    final byType = <String, List<int>>{};
    for (final i in indices) {
      final t = data[i]['measurementType']?.toString() ?? '';
      byType.putIfAbsent(t, () => []).add(i);
    }

    final lineBase = Paint()
      ..strokeWidth = m.seriesLineStroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final type in byType.keys) {
      final idxs = List<int>.from(byType[type]!);
      idxs.sort((a, b) {
        final sa = data[a]['slotIndex'];
        final sb = data[b]['slotIndex'];
        if (sa is int && sb is int && sa != sb) return sa.compareTo(sb);
        return a.compareTo(b);
      });
      if (idxs.length <= 1) continue;
      final c = _seriesColorForType(type);
      lineBase.color = c;
      for (int k = 0; k < idxs.length - 1; k++) {
        canvas.drawLine(
          offsetForIndex(idxs[k]),
          offsetForIndex(idxs[k + 1]),
          lineBase,
        );
      }
    }

    for (final i in indices) {
      if (inOverlap.contains(i)) continue;
      final o = offsetForIndex(i);
      final isHighlighted = highlightedIndex != null && highlightedIndex == i;
      final pointPaint = Paint()
        ..color = _seriesColorForDataIndex(i)
        ..style = PaintingStyle.fill;
      if (isHighlighted) {
        canvas.drawCircle(o, m.pointRadiusHighlighted, pointPaint);
        canvas.drawCircle(
          o,
          m.pointRadiusHighlighted,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = m.highlightRingStroke,
        );
      } else {
        canvas.drawCircle(o, m.pointRadius, pointPaint);
      }
    }

    for (var ci = 0; ci < overlapRender.length; ci++) {
      final cluster = overlapRender[ci];
      final o = cluster.centroid;
      final clusterTapIndex = -(ci + 1);
      final highlighted = highlightedIndex != null &&
          (highlightedIndex == clusterTapIndex ||
              cluster.dataIndices.contains(highlightedIndex));
      final r = highlighted
          ? m.overlapClusterRadiusHighlighted
          : m.overlapClusterRadius;
      canvas.drawCircle(
        o,
        r,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        o,
        r,
        Paint()
          ..color = bloodSugarOverlapAccentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = m.highlightRingStroke,
      );
      final arm = r * 0.45;
      final plus = Paint()
        ..color = bloodSugarOverlapAccentColor
        ..strokeWidth = m.plusArmStroke
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(o + Offset(-arm, 0), o + Offset(arm, 0), plus);
      canvas.drawLine(o + Offset(0, -arm), o + Offset(0, arm), plus);
    }
  }

  @override
  bool shouldRepaint(covariant BloodSugarChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.yLabels != yLabels ||
        oldDelegate.highlightedIndex != highlightedIndex ||
        oldDelegate.isToday != isToday ||
        oldDelegate.timeOffset != timeOffset ||
        oldDelegate.selectedPeriod != selectedPeriod ||
        oldDelegate.topPlotPad != topPlotPad ||
        oldDelegate.bottomPlotPad != bottomPlotPad ||
        oldDelegate.scale != scale ||
        oldDelegate.xUnitReservedWidth != xUnitReservedWidth;
  }

  Color _seriesColorForDataIndex(int index) {
    if (index < 0 || index >= data.length) {
      return const Color(0xFFE91E63);
    }
    return _seriesColorForType(
        data[index]['measurementType']?.toString() ?? '');
  }

  Color _seriesColorForType(String type) {
    switch (type) {
      case '공복':
        return const Color(0xFF4F82E0);
      case '식전':
        return const Color(0xFFFC8B3A);
      case '식후':
        return const Color(0xFF38B769);
      case '취침전':
        return const Color(0xFF4FD1E0);
      case '평상시':
        return const Color(0xFFB24FE0);
      default:
        return const Color(0xFFE91E63);
    }
  }
}

class EmptyBloodSugarChartGridPainter extends CustomPainter {
  final List<double>? yLabels;
  final double minValue;
  final double maxValue;
  final double topPlotPad;
  final double bottomPlotPad;
  final double scale;

  EmptyBloodSugarChartGridPainter({
    this.yLabels,
    this.minValue = 20,
    this.maxValue = 200,
    required this.topPlotPad,
    required this.bottomPlotPad,
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final m = HealthChartMetrics(scale);
    final x0 = m.emptyGridLeftInset;
    final plotRight =
        size.width - ChartConstants.weightXAxisUnitReservedWidth - x0;
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = m.gridStroke;
    final dashedGridPaint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = m.gridStroke;
    final yValues = (yLabels != null && yLabels!.length >= 2)
        ? yLabels!
        : [maxValue, minValue];

    for (int i = 0; i < yValues.length; i++) {
      final y = topPlotPad +
          (size.height - topPlotPad - bottomPlotPad) * i / (yValues.length - 1);
      canvas.drawLine(Offset(x0, y), Offset(x0 + plotRight, y), gridPaint);
    }

    for (int i = 0; i < yValues.length - 1; i++) {
      final normalizedY = (i + 0.5) / (yValues.length - 1);
      final y =
          topPlotPad + (size.height - topPlotPad - bottomPlotPad) * normalizedY;
      for (double x = x0; x < x0 + plotRight; x += 4) {
        canvas.drawLine(Offset(x, y), Offset(x + 2, y), dashedGridPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant EmptyBloodSugarChartGridPainter oldDelegate) =>
      oldDelegate.yLabels != yLabels ||
      oldDelegate.minValue != minValue ||
      oldDelegate.maxValue != maxValue ||
      oldDelegate.topPlotPad != topPlotPad ||
      oldDelegate.bottomPlotPad != bottomPlotPad ||
      oldDelegate.scale != scale;
}
