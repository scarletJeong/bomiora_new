import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/chart_layout.dart';

const double _weightYAxisUnitBandHeight = 16.0;

/// 주·월 그래프와 동일: 상단 `(kg)` 밴드 + 숫자 눈금 Stack(가운데 정렬, 11pt)
Widget _buildWeightYAxisStripLikePeriodChart({
  required List<double> yLabels,
  required bool showYAxisKgHeader,
  String unitLabel = '(kg)',
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final totalH = constraints.maxHeight;
      final kgBand =
          showYAxisKgHeader && yLabels.length > 1 ? _weightYAxisUnitBandHeight : 0.0;

      Widget numericLabels(double forHeight) {
        final n = yLabels.length;
        if (n < 2) return const SizedBox.shrink();
        return SizedBox(
          height: forHeight,
          child: LayoutBuilder(
            builder: (context, lc) {
              // 차트 그리드의 상하 여백(20)과 동일하게 맞춰 라벨/선 정렬
              const topPad = 20.0;
              const botPad = 20.0;
              final h = lc.maxHeight - topPad - botPad;
              return Stack(
                clipBehavior: Clip.none,
                children: yLabels.asMap().entries.map((e) {
                  final i = e.key;
                  final label = e.value;
                  final y = topPad + h * i / (n - 1);
                  return Positioned(
                    top: y - 8,
                    left: 0,
                    right: 0,
                    child: Text(
                      label.toStringAsFixed(0),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        );
      }

      return SizedBox(
        width: ChartConstants.weightChartYAxisWidth,
        child: showYAxisKgHeader && yLabels.length > 1
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: kgBand,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Text(
                        unitLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, inner) {
                        return numericLabels(inner.maxHeight);
                      },
                    ),
                  ),
                ],
              )
            : numericLabels(totalH),
      );
    },
  );
}

typedef WeightChartAreaBuilder = Widget Function(
  List<Map<String, dynamic>> chartData,
  List<double> yLabels,
  BoxConstraints constraints,
  bool omitOutOfRangeWeights,
);

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
        const SizedBox(height: 25),
        periodSelector,
        // 그래프와 기간 선택(일자별/월별) 카드 간격
        const SizedBox(height: 3),
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
    this.chartHeight = ChartConstants.healthChartHeight,
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
        padding: ChartConstants.weightChartCardPadding,
        decoration: BoxDecoration(
          color: Colors.white,
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

  return _buildXAxisLabelWithUnit(
    labelRow: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: hourLabels,
    ),
    unitText: '(시)',
  );
}

Widget _buildWeightPeriodXAxisLabels({
  required String selectedPeriod,
  required DateTime selectedDate,
  required double timeOffset,
}) {
  if (selectedPeriod == '월') {
    const totalMonths = 12;
    const visibleMonths = 7;
    final maxStart = totalMonths - visibleMonths;
    final startIndex = (timeOffset * maxStart).round().clamp(0, maxStart);

    return _buildXAxisLabelWithUnit(
      labelRow: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(visibleMonths, (i) {
          final m = startIndex + i + 1;
          return Expanded(
            child: Text(
              '$m',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          );
        }),
      ),
      unitText: '(월)',
    );
  }

  const days = 7;
  final endDate =
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  final startDate = endDate.subtract(Duration(days: days - 1));

  final allDateLabels = <String>[];
  for (int i = 0; i < days; i++) {
    final date = startDate.add(Duration(days: i));
    allDateLabels.add(DateFormat('M.d').format(date));
  }

  final dateRow = Row(
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

  return _buildXAxisLabelWithUnit(
    labelRow: dateRow,
    unitText: '(일)',
  );
}

Widget _buildXAxisLabelWithUnit({
  required Widget labelRow,
  required String unitText,
}) {
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Padding(
        padding: const EdgeInsets.only(
          right: ChartConstants.weightXAxisUnitReservedWidth,
        ),
        child: labelRow,
      ),
      Positioned(
        right: -10,
        top: 1,
        bottom: 0,
        child: Align(
          alignment: Alignment.center,
          child: Text(
            unitText,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    ],
  );
}

class WeightEmptyChart extends StatelessWidget {
  final double chartHeight;
  final String selectedPeriod;
  final DateTime selectedDate;
  final double timeOffset;
  final List<double> yLabels;
  final bool showYAxisKgHeader;

  const WeightEmptyChart({
    super.key,
    required this.chartHeight,
    required this.selectedPeriod,
    required this.selectedDate,
    required this.timeOffset,
    this.yLabels = const [67, 66, 65, 64, 63],
    this.showYAxisKgHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final segments = yLabels.length > 1 ? yLabels.length - 1 : 4;

    const outerPadding = ChartConstants.weightChartCardPadding;

    return Container(
      height: chartHeight,
      padding: outerPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalH = constraints.maxHeight;
                final kgBand = showYAxisKgHeader && yLabels.length > 1
                    ? _weightYAxisUnitBandHeight
                    : 0.0;
                final zoneH = totalH - kgBand;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildWeightYAxisStripLikePeriodChart(
                      yLabels: yLabels,
                      showYAxisKgHeader: showYAxisKgHeader,
                    ),
                    SizedBox(width: ChartConstants.yAxisSpacing),
                    Expanded(
                      child: Column(
                        children: [
                          if (showYAxisKgHeader) SizedBox(height: kgBand),
                          Expanded(
                            child: CustomPaint(
                              painter: _WeightEmptyChartGridPainter(
                                horizontalSegments: segments,
                              ),
                              size: Size(
                                constraints.maxWidth -
                                    ChartConstants.weightChartYAxisStripWidth,
                                zoneH > 0 ? zoneH : totalH,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 43.0),
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

class _WeightEmptyChartGridPainter extends CustomPainter {
  final int horizontalSegments;

  _WeightEmptyChartGridPainter({this.horizontalSegments = 4});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    final n = horizontalSegments < 1 ? 1 : horizontalSegments;
    for (int i = 0; i <= n; i++) {
      final y = size.height * i / n;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightEmptyChartGridPainter oldDelegate) =>
      oldDelegate.horizontalSegments != horizontalSegments;
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
  /// 메인 그래프: Y축 맨 위 행에 단위 `(kg)` 표시
  final bool showYAxisKgHeader;
  /// 메인 그래프: Y축 숫자 범위 밖 체중은 점/막대 미표시
  final bool omitOutOfRangeWeights;
  final ValueChanged<double> onTimeOffsetChanged;
  final void Function(int?, Offset?) onTooltipChanged;
  final WeightChartAreaBuilder chartAreaBuilder;
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
    this.showYAxisKgHeader = false,
    this.omitOutOfRangeWeights = false,
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
        showYAxisKgHeader: showYAxisKgHeader,
        omitOutOfRangeWeights: omitOutOfRangeWeights,
        onTooltipChanged: onTooltipChanged,
      );
    }

    if (selectedPeriod == '월') {
      return _WeightMonthlyRangeChart(
        chartData: chartData,
        yLabels: yLabels,
        chartHeight: chartHeight,
        selectedPeriod: selectedPeriod,
        selectedDate: selectedDate,
        timeOffset: timeOffset,
        selectedChartPointIndex: selectedChartPointIndex,
        tooltipPosition: tooltipPosition,
        showYAxisKgHeader: showYAxisKgHeader,
        omitOutOfRangeWeights: omitOutOfRangeWeights,
        onTimeOffsetChanged: onTimeOffsetChanged,
        onTooltipChanged: onTooltipChanged,
      );
    }

    return Container(
      height: chartHeight,
      padding: ChartConstants.weightChartCardPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final totalH = constraints.maxHeight;
              final kgBand =
                  showYAxisKgHeader && yLabels.length > 1 ? _weightYAxisUnitBandHeight : 0.0;
              final zoneH = totalH - kgBand;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildWeightYAxisStripLikePeriodChart(
                    yLabels: yLabels,
                    showYAxisKgHeader: showYAxisKgHeader,
                  ),
                  SizedBox(width: ChartConstants.yAxisSpacing),
                  Expanded(
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            if (showYAxisKgHeader) SizedBox(height: kgBand),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, inner) {
                                  return chartAreaBuilder(
                                    chartData,
                                    yLabels,
                                    inner,
                                    omitOutOfRangeWeights,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        if (selectedChartPointIndex != null &&
                            tooltipPosition != null)
                          Positioned(
                            left: tooltipPosition!.dx,
                            top: tooltipPosition!.dy + kgBand,
                            child: tooltipBuilder(
                              chartData[selectedChartPointIndex!],
                              constraints.maxWidth -
                                  ChartConstants.weightChartYAxisStripWidth,
                              zoneH,
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
            padding: const EdgeInsets.only(left: 43.0),
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
  });

  static const int _totalMonths = 12;
  static const int _visibleMonths = 7;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: chartHeight,
      padding: ChartConstants.weightChartCardPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final totalH = constraints.maxHeight;
              final kgBand =
                  showYAxisKgHeader && yLabels.length > 1 ? _weightYAxisUnitBandHeight : 0.0;
              final zoneH = totalH - kgBand;
              final chartW =
                  constraints.maxWidth -
                  ChartConstants.weightChartYAxisStripWidth;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildWeightYAxisStripLikePeriodChart(
                    yLabels: yLabels,
                    showYAxisKgHeader: showYAxisKgHeader,
                  ),
                  SizedBox(width: ChartConstants.yAxisSpacing),
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
                                        selectedIndex:
                                            selectedChartPointIndex,
                                        omitOutOfRangeWeights:
                                            omitOutOfRangeWeights,
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
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 43.0),
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

  _WeeklyHit? _findMonthlyHit({
    required Offset tap,
    required Size chartSize,
    required List<Map<String, dynamic>> chartData,
    required double timeOffset,
    required List<double> yLabels,
    required bool omitOutOfRangeWeights,
  }) {
    if (chartData.length < _totalMonths || yLabels.length < 2) return null;

    final minYWeight = yLabels.last;
    final maxYWeight = yLabels.first;
    final range = (maxYWeight - minYWeight).abs();
    if (range == 0) return null;

    const double leftPadding = 0.0;
    const double rightPadding = ChartConstants.weightXAxisUnitReservedWidth;
    const double topPadding = 20.0;
    const double bottomPadding = 20.0;
    final chartWidth = chartSize.width - leftPadding - rightPadding;
    final drawableHeight = chartSize.height - topPadding - bottomPadding;

    final maxStart = _totalMonths - _visibleMonths;
    final startIndex =
        (timeOffset * maxStart).round().clamp(0, maxStart);

    double toY(double weight) {
      final normalized = (maxYWeight - weight) / range;
      return topPadding + drawableHeight * normalized;
    }

    int? bestIndex;
    double bestDistance = double.infinity;
    Offset? bestTooltipPosition;

    for (int v = 0; v < _visibleMonths; v++) {
      final dataIndex = startIndex + v;
      if (dataIndex < 0 || dataIndex >= chartData.length) continue;

      final data = chartData[dataIndex];
      final weight = data['weight'] as double?;
      final minWeight = (data['minWeight'] as double?) ?? weight;
      final maxWeight = (data['maxWeight'] as double?) ?? weight;
      final count = (data['count'] as int?) ?? (weight != null ? 1 : 0);
      if (minWeight == null || maxWeight == null || count <= 0) continue;

      if (omitOutOfRangeWeights &&
          (maxWeight > maxYWeight || minWeight < minYWeight)) {
        continue;
      }

      final slotWidth = chartWidth / _visibleMonths;
      final x = leftPadding + slotWidth * (v + 0.5);
      final yMin = toY(minWeight);
      final yMax = toY(maxWeight);
      final yCenter = (yMin + yMax) / 2;

      final dx = (tap.dx - x).abs();
      final inYBand = tap.dy >= (yMax - 12) && tap.dy <= (yMin + 12);
      final bandDistance = dx + (inYBand ? 0 : (tap.dy - yCenter).abs());

      if (bandDistance < bestDistance) {
        bestDistance = bandDistance;
        bestIndex = dataIndex;
        bestTooltipPosition = Offset(x - 60, yMax - 48);
      }
    }

    if (bestIndex == null) return null;
    return _WeeklyHit(index: bestIndex, tooltipPosition: bestTooltipPosition!);
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
    // 임시 목쵸 체중
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
  final int? selectedIndex;
  final bool omitOutOfRangeWeights;

  _WeightMonthlyRangePainter({
    required this.chartData,
    required this.yLabels,
    required this.timeOffset,
    this.selectedIndex,
    required this.omitOutOfRangeWeights,
  });

  static const int _totalMonths = 12;
  static const int _visibleMonths = 7;

  @override
  void paint(Canvas canvas, Size size) {
    if (chartData.length < _totalMonths || yLabels.length < 2) return;

    final minYWeight = yLabels.last;
    final maxYWeight = yLabels.first;
    final range = (maxYWeight - minYWeight).abs();
    if (range == 0) return;

    const double leftPadding = 0.0;
    const double rightPadding = ChartConstants.weightXAxisUnitReservedWidth;
    const double topPadding = 20.0;
    const double bottomPadding = 20.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;
    final gridSegments = yLabels.length - 1;
    for (int i = 0; i <= gridSegments; i++) {
      final y = topPadding + chartHeight * i / gridSegments;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
    }

    final maxStart = _totalMonths - _visibleMonths;
    final startIndex =
        (timeOffset * maxStart).round().clamp(0, maxStart);

    final singlePointPaint = Paint()
      ..color = const Color(0xFFFF5A8D)
      ..style = PaintingStyle.fill;

    double toY(double weight) {
      final normalized = (maxYWeight - weight) / range;
      return topPadding + chartHeight * normalized;
    }

    for (int v = 0; v < _visibleMonths; v++) {
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

      if (omitOutOfRangeWeights &&
          (maxWeight > maxYWeight || minWeight < minYWeight)) {
        continue;
      }

      final slotWidth = chartWidth / _visibleMonths;
      final x = leftPadding + slotWidth * (v + 0.5);

      final yMin = toY(minWeight);
      final yMax = toY(maxWeight);

      // 월별은 "해당 월 측정 2건 이상"이면 높이가 작아도 막대로 유지
      if (count == 1) {
        final radius = selectedIndex == dataIndex ? 6.5 : 5.0;
        canvas.drawCircle(
            Offset(x, (yMin + yMax) / 2), radius, singlePointPaint);
      } else {
        final effectivePaint = Paint()
          ..color = const Color(0xFFFF5A8D)
          ..strokeWidth = selectedIndex == dataIndex ? 12 : 10
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
        oldDelegate.omitOutOfRangeWeights != omitOutOfRangeWeights;
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
  final bool showYAxisKgHeader;
  final bool omitOutOfRangeWeights;
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
    required this.showYAxisKgHeader,
    required this.omitOutOfRangeWeights,
    required this.onTooltipChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: chartHeight,
      padding: ChartConstants.weightChartCardPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final totalH = constraints.maxHeight;
              final kgBand =
                  showYAxisKgHeader && yLabels.length > 1 ? _weightYAxisUnitBandHeight : 0.0;
              final zoneH = totalH - kgBand;
              final chartW =
                  constraints.maxWidth -
                  ChartConstants.weightChartYAxisStripWidth;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildWeightYAxisStripLikePeriodChart(
                    yLabels: yLabels,
                    showYAxisKgHeader: showYAxisKgHeader,
                  ),
                  SizedBox(width: ChartConstants.yAxisSpacing),
                  Expanded(
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            if (showYAxisKgHeader) SizedBox(height: kgBand),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (details) {
                                  final hit = _findWeeklyHit(
                                    tap: details.localPosition,
                                    chartSize: Size(chartW, zoneH),
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
                                      painter: _WeightWeeklyRangePainter(
                                        chartData: chartData,
                                        yLabels: yLabels,
                                        selectedIndex: selectedChartPointIndex,
                                        omitOutOfRangeWeights:
                                            omitOutOfRangeWeights,
                                      ),
                                      size: Size(chartW, zoneH),
                                    ),
                                    if (selectedChartPointIndex != null &&
                                        tooltipPosition != null &&
                                        selectedChartPointIndex! <
                                            chartData.length)
                                      Positioned(
                                        left: tooltipPosition!.dx,
                                        top: tooltipPosition!.dy,
                                        child: _buildWeeklyRangeTooltip(
                                          chartData[selectedChartPointIndex!],
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
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 43.0),
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
    if (chartData.isEmpty || yLabels.length < 2) return null;

    final minYWeight = yLabels.last;
    final maxYWeight = yLabels.first;
    final range = (maxYWeight - minYWeight).abs();
    if (range == 0) return null;

    const double leftPadding = 0.0;
    const double rightPadding = ChartConstants.weightXAxisUnitReservedWidth;
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

      if (omitOutOfRangeWeights &&
          (maxWeight > maxYWeight || minWeight < minYWeight)) {
        continue;
      }

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
    const tooltipHeight = 52.0;

    if (x < 0) x = 0;
    if (x > chartWidth - tooltipWidth) x = chartWidth - tooltipWidth;
    if (y < 0) y = 0;
    if (y > chartHeight - tooltipHeight) y = chartHeight - tooltipHeight;

    return Transform.translate(
      offset: Offset(x - tooltipPosition!.dx, y - tooltipPosition!.dy),
      child: Container(
        width: tooltipWidth,
        height: tooltipHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              dateLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
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

  const _WeightWeeklyRangePainter({
    required this.chartData,
    required this.yLabels,
    this.selectedIndex,
    this.omitOutOfRangeWeights = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (chartData.isEmpty || yLabels.length < 2) return;

    final minYWeight = yLabels.last;
    final maxYWeight = yLabels.first;
    final range = (maxYWeight - minYWeight).abs();
    if (range == 0) return;

    const double leftPadding = 0.0;
    const double rightPadding = ChartConstants.weightXAxisUnitReservedWidth;
    const double topPadding = 20.0;
    const double bottomPadding = 20.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;
    final gridSegments = yLabels.length - 1;
    for (int i = 0; i <= gridSegments; i++) {
      final y = topPadding + chartHeight * i / gridSegments;
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

      if (omitOutOfRangeWeights &&
          (maxWeight > maxYWeight || minWeight < minYWeight)) {
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
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.omitOutOfRangeWeights != omitOutOfRangeWeights;
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
