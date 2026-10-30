part of 'weight_chart_section.dart';

/// 연간 12개월 중 7개월 슬라이드, 월 단위 최소·최대 막대(주간 그래프와 동일 스타일)
class _WeightMonthlyRangeChart extends StatelessWidget {
  final List<Map<String, dynamic>> chartData;
  final List<double> yLabels;
  final double chartHeight;
  final String selectedPeriod;
  final DateTime selectedDate;
  final double timeOffset;
  final int? selectedChartPointIndex;
  final Offset? tooltipPosition;
  final bool showYAxisKgHeader;
  final bool omitOutOfRangeWeights;
  final ValueChanged<double> onTimeOffsetChanged;
  final void Function(int?, Offset?) onTooltipChanged;
  final Widget periodSelector;
  final bool forExpandedChart;

  const _WeightMonthlyRangeChart({
    required this.chartData,
    required this.yLabels,
    required this.chartHeight,
    required this.selectedPeriod,
    required this.selectedDate,
    required this.timeOffset,
    required this.selectedChartPointIndex,
    required this.tooltipPosition,
    required this.showYAxisKgHeader,
    required this.omitOutOfRangeWeights,
    required this.onTimeOffsetChanged,
    required this.onTooltipChanged,
    required this.periodSelector,
    this.forExpandedChart = false,
  });

  int get _visibleMonths => healthMonthlySlotCount(forExpandedChart);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: chartHeight,
      padding: forExpandedChart
          ? EdgeInsets.zero
          : healthChartCardPadding(context),
      decoration: forExpandedChart
          ? null
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!forExpandedChart) ...[
            periodSelector,
            SizedBox(
                height: healthDp(
                    context, ChartConstants.weightChartTabToPlotGap)),
          ],
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final totalH = constraints.maxHeight;
              final kgBand = showYAxisKgHeader && yLabels.length > 1
                  ? healthWeightChartKgBandHeight(context)
                  : 0.0;
              final zoneH = totalH - kgBand;
              final chartW =
                  constraints.maxWidth -
                  _weightYAxisStripPlusGap(context);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildWeightYAxisStripLikePeriodChart(
                    chartContext: context,
                    yLabels: yLabels,
                    showYAxisKgHeader: showYAxisKgHeader,
                  ),
                  SizedBox(width: healthDp(context, ChartConstants.weightChartYAxisPlotGap)),
                  Expanded(
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            if (showYAxisKgHeader) SizedBox(height: kgBand),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanStart: (_) {
                                  onTooltipChanged(null, null);
                                },
                                onPanUpdate: (details) {
                                  const sensitivity = 3.0;
                                  final next = timeOffset -
                                      (details.delta.dx / 1000) * sensitivity;
                                  onTimeOffsetChanged(next.clamp(0.0, 1.0));
                                },
                                onTapDown: (details) {
                                  final hit = _findMonthlyHit(
                                    tap: details.localPosition,
                                    chartSize: Size(chartW, zoneH),
                                    chartData: chartData,
                                    timeOffset: timeOffset,
                                    yLabels: yLabels,
                                    omitOutOfRangeWeights:
                                        omitOutOfRangeWeights,
                                    topPlotPad:
                                        healthWeightChartVertPad(context),
                                    bottomPlotPad:
                                        healthWeightChartBottomPlotPad(
                                            context),
                                    visibleMonths: _visibleMonths,
                                  );
                                  if (hit == null) {
                                    onTooltipChanged(null, null);
                                    return;
                                  }
                                  onTooltipChanged(
                                      hit.index, hit.tooltipPosition);
                                },
                                child: Stack(
                                  children: [
                                    CustomPaint(
                                      painter: _WeightMonthlyRangePainter(
                                        chartData: chartData,
                                        yLabels: yLabels,
                                        timeOffset: timeOffset,
                                        visibleMonths: _visibleMonths,
                                        selectedIndex:
                                            selectedChartPointIndex,
                                        omitOutOfRangeWeights:
                                            omitOutOfRangeWeights,
                                        topPlotPad:
                                            healthWeightChartVertPad(context),
                                        bottomPlotPad:
                                            healthWeightChartBottomPlotPad(
                                                context),
                                        scale: healthTextScaleByWidth(
                                            MediaQuery.of(context).size.width),
                                      ),
                                      size: Size(chartW, zoneH),
                                    ),
                                    if (selectedChartPointIndex != null &&
                                        tooltipPosition != null &&
                                        selectedChartPointIndex! >= 0 &&
                                        selectedChartPointIndex! <
                                            chartData.length)
                                      Positioned(
                                        left: tooltipPosition!.dx,
                                        top: tooltipPosition!.dy,
                                        child: _buildMonthlyRangeTooltip(
                                          chartData[
                                              selectedChartPointIndex!],
                                          chartW,
                                          zoneH,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
          Padding(
            padding: EdgeInsets.only(left: _weightYAxisStripPlusGap(context)),
            child: buildWeightXAxisLabels(
              context: context,
              selectedPeriod: selectedPeriod,
              selectedDate: selectedDate,
              timeOffset: timeOffset,
              forExpandedChart: forExpandedChart,
            ),
          ),
        ],
      ),
    );
  }

  _WeeklyHit? _findMonthlyHit({
    required Offset tap,
    required Size chartSize,
    required List<Map<String, dynamic>> chartData,
    required double timeOffset,
    required List<double> yLabels,
    required bool omitOutOfRangeWeights,
    required double topPlotPad,
    required double bottomPlotPad,
    required int visibleMonths,
  }) {
    if (chartData.length < healthCalendarYearMonthCount ||
        yLabels.length < 2) {
      return null;
    }

    final minYWeight = yLabels.last;
    final maxYWeight = yLabels.first;
    final range = (maxYWeight - minYWeight).abs();
    if (range == 0) return null;

    const double leftPadding = 0.0;
    const double rightPadding = ChartConstants.weightXAxisUnitReservedWidth;
    final chartWidth = chartSize.width - leftPadding - rightPadding;
    final drawableHeight =
        chartSize.height - topPlotPad - bottomPlotPad;

    final maxStart = healthCalendarYearMonthCount - visibleMonths;
    final startIndex =
        (timeOffset * maxStart).round().clamp(0, maxStart);

    // 플롯 그리드 밖 탭 → 툴팁 닫기 (_findWeeklyHit와 동일)
    if (tap.dx < leftPadding ||
        tap.dx > chartSize.width - rightPadding ||
        tap.dy < topPlotPad ||
        tap.dy > chartSize.height - bottomPlotPad) {
      return null;
    }

    double toY(double weight) {
      final normalized = (maxYWeight - weight) / range;
      return topPlotPad + drawableHeight * normalized;
    }

    final slotWidth = chartWidth / visibleMonths;
    final relX = tap.dx - leftPadding;
    final v = (relX / slotWidth).floor().clamp(0, visibleMonths - 1);
    final dataIndex = startIndex + v;
    if (dataIndex < 0 || dataIndex >= chartData.length) return null;

    final data = chartData[dataIndex];
    final weight = data['weight'] as double?;
    final minWeight = (data['minWeight'] as double?) ?? weight;
    final maxWeight = (data['maxWeight'] as double?) ?? weight;
    final count = (data['count'] as int?) ?? (weight != null ? 1 : 0);
    if (minWeight == null || maxWeight == null || count <= 0) return null;

    final visibleMax = omitOutOfRangeWeights
        ? maxWeight.clamp(minYWeight, maxYWeight).toDouble()
        : maxWeight;

    final x = leftPadding + slotWidth * (v + 0.5);
    final yMax = toY(visibleMax);

    return _WeeklyHit(
      index: dataIndex,
      tooltipPosition: Offset(x - 60, yMax - 48),
    );
  }

  Widget _buildMonthlyRangeTooltip(
    Map<String, dynamic> data,
    double chartWidth,
    double chartHeight,
  ) {
    final year = data['year'] as int? ?? selectedDate.year;
    final month = data['month'] as int?;
    final w = data['weight'] as double?;
    final minWeight = (data['minWeight'] as double?) ?? w;
    final maxWeight = (data['maxWeight'] as double?) ?? w;
    final count = (data['count'] as int?) ?? (w != null ? 1 : 0);
    if (month == null ||
        minWeight == null ||
        maxWeight == null ||
        count <= 0) {
      return const SizedBox.shrink();
    }

    final line2 =
        '${minWeight.toStringAsFixed(1)}~${maxWeight.toStringAsFixed(1)}kg';

    double x = tooltipPosition!.dx;
    double y = tooltipPosition!.dy;
    const tooltipWidth = 120.0;
    const tooltipHeight = 52.0;

    if (x < 0) x = 0;
    if (x > chartWidth - tooltipWidth) x = chartWidth - tooltipWidth;
    if (y < 0) y = 0;
    if (y > chartHeight - tooltipHeight) y = chartHeight - tooltipHeight;

    return Transform.translate(
      offset: Offset(x - tooltipPosition!.dx, y - tooltipPosition!.dy),
      child: Container(
        width: tooltipWidth,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '$year년 $month월',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: _weightPageFontFamily,
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              line2,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _weightPageFontFamily,
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightMonthlyRangePainter extends CustomPainter {
  final List<Map<String, dynamic>> chartData;
  final List<double> yLabels;
  final double timeOffset;
  final int visibleMonths;
  final int? selectedIndex;
  final bool omitOutOfRangeWeights;
  final double topPlotPad;
  final double bottomPlotPad;
  final double scale;

  _WeightMonthlyRangePainter({
    required this.chartData,
    required this.yLabels,
    required this.timeOffset,
    required this.visibleMonths,
    this.selectedIndex,
    required this.omitOutOfRangeWeights,
    required this.topPlotPad,
    required this.bottomPlotPad,
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (chartData.length < healthCalendarYearMonthCount ||
        yLabels.length < 2) {
      return;
    }

    final minYWeight = yLabels.last;
    final maxYWeight = yLabels.first;
    final range = (maxYWeight - minYWeight).abs();
    if (range == 0) return;

    const double leftPadding = 0.0;
    const double rightPadding = ChartConstants.weightXAxisUnitReservedWidth;
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPlotPad - bottomPlotPad;

    final maxStart = healthCalendarYearMonthCount - visibleMonths;
    final startIndex =
        (timeOffset * maxStart).round().clamp(0, maxStart);

    final m = HealthChartMetrics(scale);
    final singlePointPaint = Paint()
      ..color = const Color(0xFFFF5A8D)
      ..style = PaintingStyle.fill;

    double toY(double weight) {
      final normalized = (maxYWeight - weight) / range;
      return topPlotPad + chartHeight * normalized;
    }

    for (int v = 0; v < visibleMonths; v++) {
      final dataIndex = startIndex + v;
      if (dataIndex < 0 || dataIndex >= chartData.length) continue;

      final data = chartData[dataIndex];
      final weight = data['weight'] as double?;
      final minWeight = (data['minWeight'] as double?) ?? weight;
      final maxWeight = (data['maxWeight'] as double?) ?? weight;
      final count = (data['count'] as int?) ?? (weight != null ? 1 : 0);

      if (minWeight == null || maxWeight == null || count <= 0) {
        continue;
      }

      final visibleMin = omitOutOfRangeWeights
          ? minWeight.clamp(minYWeight, maxYWeight).toDouble()
          : minWeight;
      final visibleMax = omitOutOfRangeWeights
          ? maxWeight.clamp(minYWeight, maxYWeight).toDouble()
          : maxWeight;

      final slotWidth = chartWidth / visibleMonths;
      final x = leftPadding + slotWidth * (v + 0.5);

      final yMin = toY(visibleMin);
      final yMax = toY(visibleMax);

      // 월별은 "해당 월 측정 2건 이상"이면 높이가 작아도 막대로 유지 (두께: 혈압 막대/원과 동일)
      final isHighlighted = selectedIndex == dataIndex;
      if (count == 1) {
        final radius =
            isHighlighted ? m.pointRadiusHighlighted : m.pointRadius;
        final cy = Offset(x, (yMin + yMax) / 2);
        canvas.drawCircle(cy, radius, singlePointPaint);
        if (isHighlighted) {
          canvas.drawCircle(
            cy,
            radius,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = m.highlightRingStroke,
          );
        }
      } else {
        final strokeW =
            isHighlighted ? m.barStrokeSelected : m.barStroke;
        final effectivePaint = Paint()
          ..color = const Color(0xFFFF5A8D)
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(x, yMax), Offset(x, yMin), effectivePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeightMonthlyRangePainter oldDelegate) {
    return oldDelegate.chartData != chartData ||
        oldDelegate.yLabels != yLabels ||
        oldDelegate.timeOffset != timeOffset ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.omitOutOfRangeWeights != omitOutOfRangeWeights ||
        oldDelegate.topPlotPad != topPlotPad ||
        oldDelegate.bottomPlotPad != bottomPlotPad ||
        oldDelegate.scale != scale;
  }
}
