import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/chart_layout.dart';
import '../../../common/widgets/period_chart_widget.dart';

class WeightChartSection extends StatelessWidget {
  final Widget periodSelector;
  final Widget chartContent;

  const WeightChartSection({
    super.key,
    required this.periodSelector,
    required this.chartContent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        periodSelector,
        const SizedBox(height: 24),
        chartContent,
      ],
    );
  }
}

class WeightChartContent extends StatelessWidget {
  final String selectedPeriod;
  final List<Map<String, dynamic>> chartData;
  final List<double> yLabels;
  final double chartHeight;
  final bool showExpandButton;
  final VoidCallback? onExpand;
  final Widget Function(double chartHeight) dataChartBuilder;
  final Widget Function(double chartHeight) emptyChartBuilder;

  const WeightChartContent({
    super.key,
    required this.selectedPeriod,
    required this.chartData,
    required this.yLabels,
    required this.dataChartBuilder,
    required this.emptyChartBuilder,
    this.chartHeight = 250,
    this.showExpandButton = true,
    this.onExpand,
  });

  @override
  Widget build(BuildContext context) => _buildChart();

  Widget _buildChart() {
    final chartBody = _buildChartBody();

    if (!showExpandButton) return chartBody;

    return Stack(
      children: [
        chartBody,
        Positioned(
          right: 8,
          top: 8,
          child: GestureDetector(
            onTap: onExpand,
            child: Container(
              width: 16,
              height: 16,
              decoration: ShapeDecoration(
                color: const Color(0x7FD2D2D2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              child: const Icon(
                Icons.open_in_full,
                size: 12,
                color: Color(0xFF4B5563),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartBody() {
    if (selectedPeriod != '일' && chartData.isEmpty) {
      return emptyChartBuilder(chartHeight);
    }

    if (selectedPeriod == '일' && chartData.isEmpty) {
      return Container(
        height: chartHeight,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: Text(
            '해당 기간에 체중 기록이 없습니다',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ),
      );
    }

    return dataChartBuilder(chartHeight);
  }
}

Widget buildWeightXAxisLabels({
  required String selectedPeriod,
  required DateTime selectedDate,
  required double timeOffset,
}) {
  if (selectedPeriod != '일') {
    return _buildWeightPeriodXAxisLabels(
      selectedPeriod: selectedPeriod,
      selectedDate: selectedDate,
      timeOffset: timeOffset,
    );
  }

  const maxStartHour = 18;
  final startHour = (timeOffset * maxStartHour).clamp(0.0, 18.0).round();

  final hourLabels = <Widget>[];
  for (int i = 0; i < 7; i++) {
    final hour = (startHour + i).clamp(0, 24);
    final hourLabel = hour == 24 ? '24' : hour.toString().padLeft(2, '0');
    hourLabels.add(
      Text(
        hourLabel,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
    );
  }

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: hourLabels,
  );
}

Widget _buildWeightPeriodXAxisLabels({
  required String selectedPeriod,
  required DateTime selectedDate,
  required double timeOffset,
}) {
  final days = selectedPeriod == '주' ? 7 : 30;
  final endDate =
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  final startDate = endDate.subtract(Duration(days: days - 1));

  final allDateLabels = <String>[];
  for (int i = 0; i < days; i++) {
    final date = startDate.add(Duration(days: i));
    allDateLabels.add(DateFormat('M.d').format(date));
  }

  if (selectedPeriod == '주') {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: allDateLabels.map((label) {
        return Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        );
      }).toList(),
    );
  }

  const visibleDays = 7;
  final maxOffset = (days - visibleDays) / days;
  final currentOffset = timeOffset.clamp(0.0, maxOffset);
  final startIndex = (currentOffset * days).floor();
  final endIndex = (startIndex + visibleDays).clamp(0, allDateLabels.length);

  return Row(
    children: List.generate(visibleDays, (index) {
      final actualIndex = startIndex + index;
      if (actualIndex < endIndex && actualIndex < allDateLabels.length) {
        final label = allDateLabels[actualIndex];
        return Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        );
      }
      return const Expanded(child: SizedBox.shrink());
    }),
  );
}

class WeightEmptyChart extends StatelessWidget {
  final double chartHeight;
  final String selectedPeriod;
  final DateTime selectedDate;
  final double timeOffset;

  const WeightEmptyChart({
    super.key,
    required this.chartHeight,
    required this.selectedPeriod,
    required this.selectedDate,
    required this.timeOffset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: chartHeight,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: ChartConstants.yAxisLabelWidth,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [60.0, 65.0, 70.0, 75.0].map((label) {
                          return Text(
                            '${label.round()}kg',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[600]),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CustomPaint(
                        painter: _WeightEmptyChartGridPainter(),
                        size: Size(
                          constraints.maxWidth - ChartConstants.yAxisTotalWidth,
                          constraints.maxHeight,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          buildWeightXAxisLabels(
            selectedPeriod: selectedPeriod,
            selectedDate: selectedDate,
            timeOffset: timeOffset,
          ),
        ],
      ),
    );
  }
}

class _WeightEmptyChartGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WeightDataChart extends StatelessWidget {
  final String selectedPeriod;
  final List<Map<String, dynamic>> chartData;
  final List<double> yLabels;
  final int? selectedChartPointIndex;
  final Offset? tooltipPosition;
  final double chartHeight;
  final double timeOffset;
  final DateTime selectedDate;
  final ValueChanged<double> onTimeOffsetChanged;
  final void Function(int?, Offset?) onTooltipChanged;
  final Widget Function(
    List<Map<String, dynamic>> chartData,
    List<double> yLabels,
    BoxConstraints constraints,
  ) chartAreaBuilder;
  final Widget Function(
    Map<String, dynamic> data,
    double chartWidth,
    double chartHeight,
  ) tooltipBuilder;

  const WeightDataChart({
    super.key,
    required this.selectedPeriod,
    required this.chartData,
    required this.yLabels,
    required this.selectedChartPointIndex,
    required this.tooltipPosition,
    required this.chartHeight,
    required this.timeOffset,
    required this.selectedDate,
    required this.onTimeOffsetChanged,
    required this.onTooltipChanged,
    required this.chartAreaBuilder,
    required this.tooltipBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedPeriod == '주') {
      return _WeightWeeklyRangeChart(
        chartData: chartData,
        yLabels: yLabels,
        chartHeight: chartHeight,
        selectedPeriod: selectedPeriod,
        selectedDate: selectedDate,
        timeOffset: timeOffset,
        selectedChartPointIndex: selectedChartPointIndex,
        tooltipPosition: tooltipPosition,
        onTooltipChanged: onTooltipChanged,
      );
    }

    if (selectedPeriod == '월') {
      return PeriodChartWidget(
        chartData: chartData,
        yLabels: yLabels,
        selectedPeriod: selectedPeriod,
        timeOffset: timeOffset,
        onTimeOffsetChanged: onTimeOffsetChanged,
        onTooltipChanged: (index, position) =>
            onTooltipChanged(index, position),
        selectedChartPointIndex: selectedChartPointIndex,
        tooltipPosition: tooltipPosition,
        dataType: 'weight',
        yAxisCount: yLabels.length,
        selectedDate: selectedDate,
        height: chartHeight,
      );
    }

    return Container(
      height: chartHeight,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: ChartConstants.yAxisLabelWidth,
                    child: Stack(
                      children: yLabels.asMap().entries.map((entry) {
                        final index = entry.key;
                        final label = entry.value;
                        const double topPadding = 20.0;
                        const double bottomPadding = 20.0;
                        final double y = topPadding +
                            (constraints.maxHeight -
                                    topPadding -
                                    bottomPadding) *
                                index /
                                (yLabels.length - 1);
                        return Positioned(
                          top: y - 11,
                          right: 0,
                          child: Text(
                            '${label.round()}',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        chartAreaBuilder(chartData, yLabels, constraints),
                        if (selectedChartPointIndex != null &&
                            tooltipPosition != null)
                          Positioned(
                            left: tooltipPosition!.dx,
                            top: tooltipPosition!.dy,
                            child: tooltipBuilder(
                              chartData[selectedChartPointIndex!],
                              constraints.maxWidth -
                                  ChartConstants.yAxisTotalWidth,
                              constraints.maxHeight,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 33.0),
            child: buildWeightXAxisLabels(
              selectedPeriod: selectedPeriod,
              selectedDate: selectedDate,
              timeOffset: timeOffset,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightWeeklyRangeChart extends StatelessWidget {
  final List<Map<String, dynamic>> chartData;
  final List<double> yLabels;
  final double chartHeight;
  final String selectedPeriod;
  final DateTime selectedDate;
  final double timeOffset;
  final int? selectedChartPointIndex;
  final Offset? tooltipPosition;
  final void Function(int?, Offset?) onTooltipChanged;

  const _WeightWeeklyRangeChart({
    required this.chartData,
    required this.yLabels,
    required this.chartHeight,
    required this.selectedPeriod,
    required this.selectedDate,
    required this.timeOffset,
    required this.selectedChartPointIndex,
    required this.tooltipPosition,
    required this.onTooltipChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: chartHeight,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: ChartConstants.yAxisLabelWidth,
                    child: Stack(
                      children: yLabels.asMap().entries.map((entry) {
                        final index = entry.key;
                        final label = entry.value;
                        const double topPadding = 20.0;
                        const double bottomPadding = 20.0;
                        final double y = topPadding +
                            (constraints.maxHeight -
                                    topPadding -
                                    bottomPadding) *
                                index /
                                (yLabels.length - 1);
                        return Positioned(
                          top: y - 11,
                          right: 0,
                          child: Text(
                            '${label.round()}',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        final hit = _findWeeklyHit(
                          tap: details.localPosition,
                          chartSize: Size(
                            constraints.maxWidth -
                                ChartConstants.yAxisTotalWidth,
                            constraints.maxHeight,
                          ),
                        );
                        if (hit == null) {
                          onTooltipChanged(null, null);
                          return;
                        }
                        onTooltipChanged(hit.index, hit.tooltipPosition);
                      },
                      child: Stack(
                        children: [
                          CustomPaint(
                            painter: _WeightWeeklyRangePainter(
                              chartData: chartData,
                              yLabels: yLabels,
                              selectedIndex: selectedChartPointIndex,
                            ),
                            size: Size(
                              constraints.maxWidth -
                                  ChartConstants.yAxisTotalWidth,
                              constraints.maxHeight,
                            ),
                          ),
                          if (selectedChartPointIndex != null &&
                              tooltipPosition != null &&
                              selectedChartPointIndex! < chartData.length)
                            Positioned(
                              left: tooltipPosition!.dx,
                              top: tooltipPosition!.dy,
                              child: _buildWeeklyRangeTooltip(
                                chartData[selectedChartPointIndex!],
                                constraints.maxWidth -
                                    ChartConstants.yAxisTotalWidth,
                                constraints.maxHeight,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 33.0),
            child: buildWeightXAxisLabels(
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
  }) {
    if (chartData.isEmpty || yLabels.length < 4) return null;

    final minYWeight = yLabels[3];
    final maxYWeight = yLabels[0];
    final range = (maxYWeight - minYWeight).abs();
    if (range == 0) return null;

    const double leftPadding = 0.0;
    const double rightPadding = 0.0;
    const double topPadding = 20.0;
    const double bottomPadding = 20.0;
    final chartWidth = chartSize.width - leftPadding - rightPadding;
    final drawableHeight = chartSize.height - topPadding - bottomPadding;
    final count = chartData.length;
    if (count == 0) return null;

    double toY(double weight) {
      final normalized = (maxYWeight - weight) / range;
      return topPadding + drawableHeight * normalized;
    }

    int? bestIndex;
    double bestDistance = double.infinity;
    Offset? bestTooltipPosition;

    for (int i = 0; i < count; i++) {
      final data = chartData[i];
      final weight = data['weight'] as double?;
      final minWeight = (data['minWeight'] as double?) ?? weight;
      final maxWeight = (data['maxWeight'] as double?) ?? weight;
      final dayCount = (data['count'] as int?) ?? (weight != null ? 1 : 0);
      if (minWeight == null || maxWeight == null || dayCount <= 0) continue;

      final slotWidth = count > 0 ? chartWidth / count : chartWidth;
      final x = leftPadding + slotWidth * (i + 0.5);
      final yMin = toY(minWeight);
      final yMax = toY(maxWeight);
      final yCenter = (yMin + yMax) / 2;

      final dx = (tap.dx - x).abs();
      final inYBand = tap.dy >= (yMax - 12) && tap.dy <= (yMin + 12);
      final bandDistance = dx + (inYBand ? 0 : (tap.dy - yCenter).abs());

      if (bandDistance < bestDistance) {
        bestDistance = bandDistance;
        bestIndex = i;
        bestTooltipPosition = Offset(x - 60, yMax - 48);
      }
    }

    if (bestIndex == null) return null;
    return _WeeklyHit(index: bestIndex, tooltipPosition: bestTooltipPosition!);
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

    double x = tooltipPosition!.dx;
    double y = tooltipPosition!.dy;
    const tooltipWidth = 150.0;
    const tooltipHeight = 34.0;

    if (x < 0) x = 0;
    if (x > chartWidth - tooltipWidth) x = chartWidth - tooltipWidth;
    if (y < 0) y = 0;
    if (y > chartHeight - tooltipHeight) y = chartHeight - tooltipHeight;

    return Transform.translate(
      offset: Offset(x - tooltipPosition!.dx, y - tooltipPosition!.dy),
      child: Container(
        width: tooltipWidth,
        height: tooltipHeight,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _WeightWeeklyRangePainter extends CustomPainter {
  final List<Map<String, dynamic>> chartData;
  final List<double> yLabels;
  final int? selectedIndex;

  const _WeightWeeklyRangePainter({
    required this.chartData,
    required this.yLabels,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (chartData.isEmpty || yLabels.length < 4) return;

    final minYWeight = yLabels[3];
    final maxYWeight = yLabels[0];
    final range = (maxYWeight - minYWeight).abs();
    if (range == 0) return;

    const double leftPadding = 0.0;
    const double rightPadding = 0.0;
    const double topPadding = 20.0;
    const double bottomPadding = 20.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 3; i++) {
      final y = topPadding + chartHeight * i / 3;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
    }

    final rangePaint = Paint()
      ..color = const Color(0xFFFF5A8D)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final singlePointPaint = Paint()
      ..color = const Color(0xFFFF5A8D)
      ..style = PaintingStyle.fill;

    final count = chartData.length;
    if (count == 0) return;

    double toY(double weight) {
      final normalized = (maxYWeight - weight) / range;
      return topPadding + chartHeight * normalized;
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

      final slotWidth = count > 0 ? chartWidth / count : chartWidth;
      final x = leftPadding + slotWidth * (i + 0.5);

      final yMin = toY(minWeight);
      final yMax = toY(maxWeight);

      if (dayCount == 1 || (yMin - yMax).abs() < 2) {
        final radius = selectedIndex == i ? 6.5 : 5.0;
        canvas.drawCircle(
            Offset(x, (yMin + yMax) / 2), radius, singlePointPaint);
      } else {
        final effectivePaint = Paint()
          ..color = const Color(0xFFFF5A8D)
          ..strokeWidth = selectedIndex == i ? 12 : 10
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(x, yMax), Offset(x, yMin), effectivePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeightWeeklyRangePainter oldDelegate) {
    return oldDelegate.chartData != chartData ||
        oldDelegate.yLabels != yLabels ||
        oldDelegate.selectedIndex != selectedIndex;
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
