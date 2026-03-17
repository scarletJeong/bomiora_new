import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/chart_layout.dart';
import '../../health_common/widgets/health_period_selector.dart';
import 'blood_sugar_tooltip.dart';

class BloodSugarPeriodSelector extends StatelessWidget {
  final String selectedPeriod;
  final ValueChanged<String> onChanged;

  const BloodSugarPeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return HealthPeriodSelector(
      selectedPeriod: selectedPeriod,
      onChanged: onChanged,
    );
  }
}

class BloodSugarChartSection extends StatefulWidget {
  final String selectedPeriod;
  final DateTime selectedDate;
  final double timeOffset;
  final int? selectedChartPointIndex;
  final Offset? tooltipPosition;
  final bool isToday;
  final bool showPeriodSelector;
  final bool showLegend;
  final bool showExpandButton;
  final double chartHeight;
  final List<Map<String, dynamic>> chartData;
  final List<double> yLabels;
  final bool hasActualDailyData;
  final VoidCallback? onExpand;
  final ValueChanged<String>? onPeriodChanged;
  final void Function(double deltaX, double chartWidth) onDragUpdate;
  final void Function(int? index, Offset? position) onSelectionChanged;

  const BloodSugarChartSection({
    super.key,
    required this.selectedPeriod,
    required this.selectedDate,
    required this.timeOffset,
    required this.selectedChartPointIndex,
    required this.tooltipPosition,
    required this.isToday,
    required this.chartData,
    required this.yLabels,
    required this.hasActualDailyData,
    required this.onDragUpdate,
    required this.onSelectionChanged,
    this.showPeriodSelector = true,
    this.showLegend = true,
    this.showExpandButton = true,
    this.chartHeight = 350,
    this.onExpand,
    this.onPeriodChanged,
  });

  @override
  State<BloodSugarChartSection> createState() => _BloodSugarChartSectionState();
}

class _BloodSugarChartSectionState extends State<BloodSugarChartSection> {
  double? _dragStartX;

  @override
  Widget build(BuildContext context) {
    final chart = _buildChart(
      showExpandButton: widget.showExpandButton,
      chartHeight: widget.chartHeight,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showPeriodSelector) ...[
          BloodSugarPeriodSelector(
            selectedPeriod: widget.selectedPeriod,
            onChanged: (period) => widget.onPeriodChanged?.call(period),
          ),
          const SizedBox(height: 12),
        ],
        chart,
        if (widget.showLegend) ...[
          const SizedBox(height: 14),
          const Row(
            children: [
              _GlucoseSeriesLegend(color: Color(0xFF4F82E0), label: '공복'),
              SizedBox(width: 10),
              _GlucoseSeriesLegend(color: Color(0xFFFC8B3A), label: '식전'),
              SizedBox(width: 10),
              _GlucoseSeriesLegend(color: Color(0xFF38B769), label: '식후'),
              SizedBox(width: 10),
              _GlucoseSeriesLegend(color: Color(0xFF4FD1E0), label: '취침전'),
              SizedBox(width: 10),
              _GlucoseSeriesLegend(color: Color(0xFFB24FE0), label: '평상시'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildChart({bool showExpandButton = true, double chartHeight = 350}) {
    Widget chartBody;
    if (widget.selectedPeriod == '일' && !widget.hasActualDailyData) {
      chartBody = _buildNoDataMessage(chartHeight: chartHeight);
    } else if (widget.chartData.isEmpty) {
      chartBody = _buildDraggableChart(
        [],
        widget.yLabels,
        isEmpty: true,
        chartHeight: chartHeight,
      );
    } else {
      chartBody = _buildDraggableChart(
        widget.chartData,
        widget.yLabels,
        isEmpty: false,
        chartHeight: chartHeight,
      );
    }

    if (!showExpandButton) return chartBody;

    return Stack(
      children: [
        chartBody,
        Positioned(
          right: 8,
          top: 8,
          child: GestureDetector(
            onTap: widget.onExpand,
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

  Widget _buildNoDataMessage({double chartHeight = 350}) {
    return Container(
      height: chartHeight,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Text(
              '해당 기간에 혈당 기록이 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '혈당을 측정해보세요',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableChart(
    List<Map<String, dynamic>> chartData,
    List<double> yLabels, {
    required bool isEmpty,
    double chartHeight = 350,
  }) {
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
                            top: y - 10,
                            right: 0,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (index == 0)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '(mg/dl)',
                                      style: TextStyle(
                                        fontSize: 6,
                                        color: Color(0xFF898383),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                Text(
                                  '${label.round()}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1A1A1A),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(width: ChartConstants.yAxisSpacing),
                    Expanded(
                      child: _buildChartArea(chartData, constraints, isEmpty),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.only(left: ChartConstants.yAxisTotalWidth),
            child: buildBloodSugarXAxisLabels(
              selectedPeriod: widget.selectedPeriod,
              selectedDate: widget.selectedDate,
              timeOffset: widget.timeOffset,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartArea(List<Map<String, dynamic>> chartData,
      BoxConstraints constraints, bool isEmpty) {
    return GestureDetector(
      onPanStart: (widget.selectedPeriod == '일' || widget.selectedPeriod == '월')
          ? (details) => _dragStartX = details.localPosition.dx
          : null,
      onPanUpdate:
          (widget.selectedPeriod == '일' || widget.selectedPeriod == '월')
              ? (details) {
                  if (_dragStartX != null) {
                    final deltaX = details.localPosition.dx - _dragStartX!;
                    final chartWidth =
                        constraints.maxWidth - ChartConstants.yAxisTotalWidth;
                    widget.onDragUpdate(deltaX, chartWidth);
                    _dragStartX = details.localPosition.dx;
                  }
                }
              : null,
      onPanEnd: (widget.selectedPeriod == '일' || widget.selectedPeriod == '월')
          ? (details) => _dragStartX = null
          : null,
      onTapDown: isEmpty
          ? null
          : (details) {
              _handleChartTapToggle(
                details.localPosition,
                chartData,
                constraints.maxWidth - ChartConstants.yAxisTotalWidth,
                constraints.maxHeight,
              );
            },
      child: Stack(
        children: [
          Positioned.fill(
            child: isEmpty
                ? CustomPaint(painter: EmptyBloodSugarChartGridPainter())
                : CustomPaint(
                    painter: BloodSugarChartPainter(
                      chartData,
                      50,
                      300,
                      highlightedIndex: widget.selectedChartPointIndex,
                      isToday: widget.isToday,
                      timeOffset: widget.timeOffset,
                      selectedPeriod: widget.selectedPeriod,
                    ),
                  ),
          ),
          if (!isEmpty &&
              widget.selectedChartPointIndex != null &&
              widget.tooltipPosition != null)
            BloodSugarTooltip(
              data: chartData[widget.selectedChartPointIndex!],
              tooltipPosition: widget.tooltipPosition,
              chartWidth: constraints.maxWidth - ChartConstants.yAxisTotalWidth,
              chartHeight: constraints.maxHeight,
            ),
        ],
      ),
    );
  }

  void _handleChartTapToggle(
    Offset tapPosition,
    List<Map<String, dynamic>> chartData,
    double chartWidth,
    double chartHeight,
  ) {
    if (chartData.isEmpty) return;

    const double leftPadding = 0.0;
    final double effectiveWidth = chartWidth - leftPadding;

    int? closestIndex;
    double minDistance = double.infinity;
    Offset? closestPoint;

    for (int i = 0; i < chartData.length; i++) {
      if (chartData[i]['bloodSugar'] == null) continue;

      double x;
      if (chartData[i]['xPosition'] != null) {
        final xPosition = chartData[i]['xPosition'] as double;

        if (widget.selectedPeriod == '월') {
          const visibleDays = 7;
          const totalDays = 30;
          final maxOffset = (totalDays - visibleDays) / totalDays;
          final currentOffset = widget.timeOffset.clamp(0.0, maxOffset);
          final startIndex = (currentOffset * totalDays).floor();
          final endIndex = startIndex + visibleDays;
          final dataIndex = (xPosition * totalDays).round();
          if (dataIndex < startIndex || dataIndex >= endIndex) continue;

          final relativeIndex = dataIndex - startIndex;
          final adjustedRatio = relativeIndex / (visibleDays - 1);
          x = leftPadding + (effectiveWidth * adjustedRatio);
        } else {
          x = leftPadding + (effectiveWidth * xPosition);
        }
      } else if (chartData.length == 1) {
        x = leftPadding + effectiveWidth / 2;
      } else {
        x = leftPadding + (effectiveWidth * i / (chartData.length - 1));
      }

      final int bloodSugar = chartData[i]['bloodSugar'];
      final double normalizedValue = (300 - bloodSugar) / (300 - 50);
      final double y = chartHeight * normalizedValue;

      final dx = tapPosition.dx - x;
      final dy = tapPosition.dy - y;
      final distance = (dx * dx + dy * dy);

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
        closestPoint = Offset(x, y);
      }
    }

    if (closestIndex != null && minDistance < 1000) {
      if (widget.selectedChartPointIndex == closestIndex) {
        widget.onSelectionChanged(null, null);
      } else {
        widget.onSelectionChanged(closestIndex, closestPoint);
      }
    } else {
      widget.onSelectionChanged(null, null);
    }
  }
}

Widget buildBloodSugarXAxisLabels({
  required String selectedPeriod,
  required DateTime selectedDate,
  required double timeOffset,
}) {
  if (selectedPeriod != '일') {
    return _buildBloodSugarPeriodXAxisLabels(
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
      Text(hourLabel, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
    );
  }

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: hourLabels,
  );
}

Widget _buildBloodSugarPeriodXAxisLabels({
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
        return Expanded(
          child: Text(
            allDateLabels[actualIndex],
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        );
      }
      return const Expanded(child: SizedBox.shrink());
    }),
  );
}

class _GlucoseSeriesLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _GlucoseSeriesLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
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
  final int? highlightedIndex;
  final bool isToday;
  final double timeOffset;
  final String selectedPeriod;

  BloodSugarChartPainter(
    this.data,
    this.minValue,
    this.maxValue, {
    this.highlightedIndex,
    required this.isToday,
    required this.timeOffset,
    required this.selectedPeriod,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const double borderWidth = 0.5;
    const double pointRadius = 8;
    final chartWidth = size.width - (borderWidth * 2) - (pointRadius * 2);

    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;
    final dashedGridPaint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 0.5;
    final yValues = [300, 250, 200, 150, 100, 50];
    final dashedYValues = [275, 225, 175, 125, 75];

    for (int i = 0; i < yValues.length; i++) {
      const topPadding = 20.0;
      const bottomPadding = 20.0;
      final y = topPadding + (size.height - topPadding - bottomPadding) * i / 5;
      canvas.drawLine(
        Offset(borderWidth + pointRadius, y),
        Offset(chartWidth + borderWidth + pointRadius, y),
        gridPaint,
      );
    }

    for (final dashedValue in dashedYValues) {
      final normalizedY = (300 - dashedValue) / (300 - 50);
      const topPadding = 20.0;
      const bottomPadding = 20.0;
      final y =
          topPadding + (size.height - topPadding - bottomPadding) * normalizedY;
      for (double x = borderWidth + pointRadius;
          x < chartWidth + borderWidth + pointRadius;
          x += 4) {
        canvas.drawLine(Offset(x, y), Offset(x + 2, y), dashedGridPaint);
      }
    }

    final segments = <List<Offset>>[];
    final indexSegments = <List<int>>[];
    final currentPoints = <Offset>[];
    final currentIndices = <int>[];

    const maxStartHour = 18;
    final startHour =
        (timeOffset * maxStartHour).clamp(0, maxStartHour).round();
    final endHour = startHour + 6;

    for (int i = 0; i < data.length; i++) {
      if (data[i]['bloodSugar'] == null) continue;
      final recordHour = data[i]['hour'] as int?;
      if (recordHour != null &&
          (recordHour < startHour || recordHour > endHour)) {
        if (currentPoints.isNotEmpty) {
          segments.add(List.from(currentPoints));
          indexSegments.add(List.from(currentIndices));
          currentPoints.clear();
          currentIndices.clear();
        }
        continue;
      }

      if (data[i]['xPosition'] != null && data.length > 7) {
        final xPosition = data[i]['xPosition'] as double;
        const visibleDays = 7;
        const totalDays = 30;
        final maxOffset = (totalDays - visibleDays) / totalDays;
        final currentOffset = timeOffset.clamp(0.0, maxOffset);
        final startRatio = currentOffset;
        final endRatio =
            (currentOffset + (visibleDays / totalDays)).clamp(0.0, 1.0);
        if (xPosition < startRatio || xPosition > endRatio) {
          if (currentPoints.isNotEmpty) {
            segments.add(List.from(currentPoints));
            indexSegments.add(List.from(currentIndices));
            currentPoints.clear();
            currentIndices.clear();
          }
          continue;
        }
      }

      double x;
      if (data[i]['xPosition'] != null) {
        final xPosition = data[i]['xPosition'] as double;
        if (data.length > 7) {
          const visibleDays = 7;
          const totalDays = 30;
          final maxOffset = (totalDays - visibleDays) / totalDays;
          final currentOffset = timeOffset.clamp(0.0, maxOffset);
          final startIndex = (currentOffset * totalDays).floor();
          final endIndex = startIndex + visibleDays;
          final dataIndex = (xPosition * totalDays).round();
          if (dataIndex < startIndex || dataIndex >= endIndex) continue;
          final relativeIndex = dataIndex - startIndex;
          final adjustedRatio = relativeIndex / (visibleDays - 1);
          x = borderWidth + pointRadius + (chartWidth * adjustedRatio);
        } else {
          x = borderWidth + pointRadius + (chartWidth * xPosition);
        }
      } else {
        x = data.length == 1
            ? borderWidth + pointRadius + chartWidth / 2
            : borderWidth + pointRadius + (chartWidth * i / (data.length - 1));
      }

      final bloodSugar = data[i]['bloodSugar'] as int;
      const topPadding = 20.0;
      const bottomPadding = 20.0;
      final normalized = (300 - bloodSugar) / (300 - 50);
      final y =
          topPadding + (size.height - topPadding - bottomPadding) * normalized;

      currentPoints.add(Offset(x, y));
      currentIndices.add(i);
    }

    if (currentPoints.isNotEmpty) {
      segments.add(currentPoints);
      indexSegments.add(currentIndices);
    }

    // 시간대별(일)에서는 점 연결선을 그리지 않음
    if (selectedPeriod != '일') {
      for (int segIdx = 0; segIdx < segments.length; segIdx++) {
        final segment = segments[segIdx];
        final indices = indexSegments[segIdx];
        if (segment.length <= 1) continue;

        for (int i = 0; i < segment.length - 1; i++) {
          final from = segment[i];
          final to = segment[i + 1];
          final originalIndex = indices[i];
          final seriesColor = _seriesColorForDataIndex(originalIndex);
          final linePaint = Paint()
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..color = seriesColor;
          canvas.drawLine(from, to, linePaint);
        }
      }
    }

    for (int segIdx = 0; segIdx < segments.length; segIdx++) {
      final points = segments[segIdx];
      final indices = indexSegments[segIdx];
      for (int i = 0; i < points.length; i++) {
        final originalIndex = indices[i];
        final isHighlighted =
            highlightedIndex != null && highlightedIndex == originalIndex;
        final pointPaint = Paint()
          ..color = _seriesColorForDataIndex(originalIndex)
          ..style = PaintingStyle.fill;
        if (isHighlighted) {
          canvas.drawCircle(points[i], 8, pointPaint);
          canvas.drawCircle(
            points[i],
            8,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        } else {
          canvas.drawCircle(points[i], 5, pointPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  Color _seriesColorForDataIndex(int index) {
    if (index < 0 || index >= data.length) {
      return const Color(0xFFE91E63);
    }
    final type = data[index]['measurementType']?.toString() ?? '';
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
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;
    final dashedGridPaint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 0.5;
    final yValues = [300, 250, 200, 150, 100, 50];
    final dashedYValues = [275, 225, 175, 125, 75];

    for (int i = 0; i < yValues.length; i++) {
      const topPadding = 20.0;
      const bottomPadding = 20.0;
      final y = topPadding + (size.height - topPadding - bottomPadding) * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (final dashedValue in dashedYValues) {
      final normalizedY = (300 - dashedValue) / (300 - 50);
      const topPadding = 20.0;
      const bottomPadding = 20.0;
      final y =
          topPadding + (size.height - topPadding - bottomPadding) * normalizedY;
      for (double x = 0; x < size.width; x += 4) {
        canvas.drawLine(Offset(x, y), Offset(x + 2, y), dashedGridPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
