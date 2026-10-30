part of 'weight_chart_section.dart';

// 주간 = 일자별 그래프
class _WeightWeeklyRangeChart extends StatelessWidget {
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
  final void Function(int?, Offset?) onTooltipChanged;
  final Widget periodSelector;
  final bool forExpandedChart;

  const _WeightWeeklyRangeChart({
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
    required this.onTooltipChanged,
    required this.periodSelector,
    this.forExpandedChart = false,
  });

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
              final kgBand = showYAxisKgHeader && yLabels.length > 1
                  ? healthWeightChartKgBandHeight(context)
                  : 0.0;

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
                              child: LayoutBuilder(
                                builder: (context, plotConstraints) {
                                  final plotW = plotConstraints.maxWidth;
                                  final plotH = plotConstraints.maxHeight;
                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapDown: (details) {
                                      final hit = _findWeeklyHit(
                                        tap: details.localPosition,
                                        chartSize: Size(plotW, plotH),
                                        topPlotPad:
                                            healthWeightChartVertPad(context),
                                        bottomPlotPad:
                                            healthWeightChartBottomPlotPad(
                                                context),
                                      );
                                      if (hit == null) {
                                        onTooltipChanged(null, null);
                                        return;
                                      }
                                      onTooltipChanged(
                                          hit.index, hit.tooltipPosition);
                                    },
                                    child: Stack(
                                      clipBehavior: Clip.hardEdge,
                                      children: [
                                          ClipRect(
                                            child: CustomPaint(
                                              painter:
                                                  _WeightWeeklyRangePainter(
                                                chartData: chartData,
                                                yLabels: yLabels,
                                                selectedIndex:
                                                    selectedChartPointIndex,
                                                omitOutOfRangeWeights:
                                                    omitOutOfRangeWeights,
                                                topPlotPad:
                                                    healthWeightChartVertPad(
                                                        context),
                                                bottomPlotPad:
                                                    healthWeightChartBottomPlotPad(
                                                        context),
                                                scale: healthTextScaleByWidth(
                                                    MediaQuery.of(context)
                                                        .size
                                                        .width),
                                              ),
                                              size: Size(plotW, plotH),
                                            ),
                                          ),
                                          if (selectedChartPointIndex !=
                                                  null &&
                                              tooltipPosition != null &&
                                              selectedChartPointIndex! <
                                                  chartData.length)
                                            Positioned(
                                              left: tooltipPosition!.dx,
                                              top: tooltipPosition!.dy,
                                              child: GestureDetector(
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                onTap: () =>
                                                    onTooltipChanged(
                                                        null, null),
                                                child: _buildWeeklyRangeTooltip(
                                                  chartData[
                                                      selectedChartPointIndex!],
                                                  plotW,
                                                  plotH,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                  );
                                },
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
            ),
          ),
        ],
      ),
    );
  }

  _WeeklyHit? _findWeeklyHit({
    required Offset tap,
    required Size chartSize,
    required double topPlotPad,
    required double bottomPlotPad,
  }) {
    if (chartData.isEmpty || yLabels.length < 2) return null;

    final minYWeight = yLabels.last;
    final maxYWeight = yLabels.first;
    final range = (maxYWeight - minYWeight).abs();
    if (range == 0) return null;

    const double leftPadding = 0.0;
    const double rightPadding = ChartConstants.weightXAxisUnitReservedWidth;
    final chartWidth = chartSize.width - leftPadding - rightPadding;
    final drawableHeight =
        chartSize.height - topPlotPad - bottomPlotPad;
    final count = chartData.length;
    if (count == 0) return null;

    final drawableTop = topPlotPad;
    final drawableBottom = chartSize.height - bottomPlotPad;

    // 플롯 그리드 밖(패딩 영역) 탭 → 툴팁 닫기
    if (tap.dx < leftPadding ||
        tap.dx > chartSize.width - rightPadding ||
        tap.dy < drawableTop ||
        tap.dy > drawableBottom) {
      return null;
    }

    double toY(double weight) {
      final normalized = (maxYWeight - weight) / range;
      return topPlotPad + drawableHeight * normalized;
    }

    final slotWidth = chartWidth / count;
    final relX = tap.dx - leftPadding;
    final columnIndex =
        (relX / slotWidth).floor().clamp(0, count - 1);

    final data = chartData[columnIndex];
    final weight = data['weight'] as double?;
    final minWeight = (data['minWeight'] as double?) ?? weight;
    final maxWeight = (data['maxWeight'] as double?) ?? weight;
    final dayCount = (data['count'] as int?) ?? (weight != null ? 1 : 0);
    if (minWeight == null || maxWeight == null || dayCount <= 0) {
      return null;
    }

    final visibleMin = omitOutOfRangeWeights
        ? minWeight.clamp(minYWeight, maxYWeight).toDouble()
        : minWeight;
    final visibleMax = omitOutOfRangeWeights
        ? maxWeight.clamp(minYWeight, maxYWeight).toDouble()
        : maxWeight;

    final x = leftPadding + slotWidth * (columnIndex + 0.5);
    final yMinScreen = toY(visibleMin);
    final yMaxScreen = toY(visibleMax);
    // 무거운 쪽이 Y축 위(작은 dy) — 기존과 동일하게 그 구간 위쪽에 툴팁
    final anchorY = math.min(yMinScreen, yMaxScreen);

    return _WeeklyHit(
      index: columnIndex,
      tooltipPosition: Offset(x - 60, anchorY - 48),
    );
  }

  Widget _buildWeeklyRangeTooltip(
    Map<String, dynamic> data,
    double chartWidth,
    double chartHeight,
  ) {
    final weight = data['weight'] as double?;
    final minWeight = (data['minWeight'] as double?) ?? weight;
    final maxWeight = (data['maxWeight'] as double?) ?? weight;
    final dayCount = (data['count'] as int?) ?? (weight != null ? 1 : 0);
    if (minWeight == null || maxWeight == null || dayCount <= 0) {
      return const SizedBox.shrink();
    }

    final isSinglePoint = dayCount <= 1 || (maxWeight - minWeight).abs() < 0.01;
    final text = isSinglePoint
        ? '${(weight ?? minWeight).toStringAsFixed(1)}kg'
        : '${minWeight.toStringAsFixed(1)}kg ~ ${maxWeight.toStringAsFixed(1)}kg';
    final rawDate = (data['date'] ?? '').toString();
    String dateLabel = rawDate;
    if (rawDate.contains('.')) {
      final parts = rawDate.split('.');
      if (parts.length == 2) {
        dateLabel = '${parts[0]}월 ${parts[1]}일';
      }
    }

    double x = tooltipPosition!.dx;
    double y = tooltipPosition!.dy;
    const tooltipWidth = 150.0;
    /// 패딩·두 줄 텍스트·글자 스케일까지 고려한 클램프용 높이
    const tooltipLayoutHeight = 72.0;

    if (x < 0) x = 0;
    if (x > chartWidth - tooltipWidth) x = chartWidth - tooltipWidth;
    if (y < 0) y = 0;
    if (y > chartHeight - tooltipLayoutHeight) {
      y = chartHeight - tooltipLayoutHeight;
    }

    return Transform.translate(
      offset: Offset(x - tooltipPosition!.dx, y - tooltipPosition!.dy),
      child: Container(
        width: tooltipWidth,
        constraints: const BoxConstraints(minHeight: 52, maxHeight: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              dateLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _weightPageFontFamily,
                color: Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
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

class _WeightWeeklyRangePainter extends CustomPainter {
  final List<Map<String, dynamic>> chartData;
  final List<double> yLabels;
  final int? selectedIndex;
  final bool omitOutOfRangeWeights;
  final double topPlotPad;
  final double bottomPlotPad;
  final double scale;

  _WeightWeeklyRangePainter({
    required this.chartData,
    required this.yLabels,
    this.selectedIndex,
    this.omitOutOfRangeWeights = false,
    required this.topPlotPad,
    required this.bottomPlotPad,
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (chartData.isEmpty || yLabels.length < 2) return;

    final minYWeight = yLabels.last;
    final maxYWeight = yLabels.first;
    final range = (maxYWeight - minYWeight).abs();
    if (range == 0) return;

    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    const double leftPadding = 0.0;
    const double rightPadding = ChartConstants.weightXAxisUnitReservedWidth;
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPlotPad - bottomPlotPad;

    final m = HealthChartMetrics(scale);
    final singlePointPaint = Paint()
      ..color = const Color(0xFFFF5A8D)
      ..style = PaintingStyle.fill;

    final count = chartData.length;
    if (count == 0) return;

    double toY(double weight) {
      final normalized = (maxYWeight - weight) / range;
      return topPlotPad + chartHeight * normalized;
    }

    for (int i = 0; i < count; i++) {
      final data = chartData[i];
      final weight = data['weight'] as double?;
      final minWeight = (data['minWeight'] as double?) ?? weight;
      final maxWeight = (data['maxWeight'] as double?) ?? weight;
      final dayCount = (data['count'] as int?) ?? (weight != null ? 1 : 0);

      if (minWeight == null || maxWeight == null || dayCount <= 0) {
        continue;
      }

      final visibleMin = omitOutOfRangeWeights
          ? minWeight.clamp(minYWeight, maxYWeight).toDouble()
          : minWeight;
      final visibleMax = omitOutOfRangeWeights
          ? maxWeight.clamp(minYWeight, maxYWeight).toDouble()
          : maxWeight;

      final slotWidth = count > 0 ? chartWidth / count : chartWidth;
      final x = leftPadding + slotWidth * (i + 0.5);

      final yLo = toY(visibleMin);
      final yHi = toY(visibleMax);
      final drawableTop = topPlotPad;
      final drawableBottom = size.height - bottomPlotPad;

      final isHighlighted = selectedIndex == i;
      if (dayCount == 1 || (yLo - yHi).abs() < 2) {
        final radius =
            isHighlighted ? m.pointRadiusHighlighted : m.pointRadius;
        final cy = ((yLo + yHi) / 2).clamp(drawableTop, drawableBottom);
        final center = Offset(x, cy);
        canvas.drawCircle(center, radius, singlePointPaint);
        if (isHighlighted) {
          canvas.drawCircle(
            center,
            radius,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = m.highlightRingStroke,
          );
        }
      } else {
        final topY = math.min(yLo, yHi);
        final botY = math.max(yLo, yHi);
        final ct = topY.clamp(drawableTop, drawableBottom);
        final cb = botY.clamp(drawableTop, drawableBottom);
        if ((cb - ct).abs() < 0.5) {
          final radius =
              isHighlighted ? m.pointRadiusHighlighted : m.pointRadius;
          final center = Offset(
            x,
            ((ct + cb) / 2).clamp(drawableTop, drawableBottom),
          );
          canvas.drawCircle(center, radius, singlePointPaint);
          if (isHighlighted) {
            canvas.drawCircle(
              center,
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
          canvas.drawLine(Offset(x, ct), Offset(x, cb), effectivePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeightWeeklyRangePainter oldDelegate) {
    return oldDelegate.chartData != chartData ||
        oldDelegate.yLabels != yLabels ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.omitOutOfRangeWeights != omitOutOfRangeWeights ||
        oldDelegate.topPlotPad != topPlotPad ||
        oldDelegate.bottomPlotPad != bottomPlotPad ||
        oldDelegate.scale != scale;
  }
}

class _WeeklyHit {
  final int index;
  final Offset tooltipPosition;

  const _WeeklyHit({
    required this.index,
    required this.tooltipPosition,
  });
}
