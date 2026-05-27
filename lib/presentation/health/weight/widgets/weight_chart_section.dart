import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../common/chart_layout.dart';
import '../../health_common/health_chart_axis_style.dart';
import '../../health_common/health_chart_metrics.dart';
import '../../health_common/health_responsive_scale.dart';
import '../../health_common/widgets/health_chart_expand_control.dart';

const String _weightPageFontFamily = 'Gmarket Sans TTF';

/// Y축 숫자 열(35) + 플롯과의 간격([ChartConstants.weightChartYAxisPlotGap]) — X축 들여쓰기·폭 계산에 동일 사용.
double _weightYAxisStripPlusGap(BuildContext context) => healthDp(
      context,
      ChartConstants.weightChartYAxisWidth +
          ChartConstants.weightChartYAxisPlotGap,
    );

/// 주·월 그래프와 동일: 상단 `(kg)` 밴드 + 숫자 눈금 Stack(가운데 정렬)
Widget _buildWeightYAxisStripLikePeriodChart({
  required BuildContext chartContext,
  required List<double> yLabels,
  required bool showYAxisKgHeader,
  String unitLabel = '(kg)',
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final totalH = constraints.maxHeight;
      final kgBand = showYAxisKgHeader && yLabels.length > 1
          ? healthWeightChartKgBandHeight(chartContext)
          : 0.0;

      Widget numericLabels(double forHeight) {
        final n = yLabels.length;
        if (n < 2) return const SizedBox.shrink();
        final topPad = healthWeightChartVertPad(chartContext);
        final botPad = healthWeightChartBottomPlotPad(chartContext);
        return SizedBox(
          height: forHeight,
          child: LayoutBuilder(
            builder: (context, lc) {
              final h = lc.maxHeight - topPad - botPad;
              return Stack(
                clipBehavior: Clip.none,
                children: yLabels.asMap().entries.map((e) {
                  final i = e.key;
                  final label = e.value;
                  final y = topPad + h * i / (n - 1);
                  return Positioned(
                    top: y - healthDp(chartContext, 8),
                    left: 0,
                    right: 0,
                    child: Text(
                      label.toStringAsFixed(0),
                      textAlign: TextAlign.center,
                      style: healthChartAxisTickTextStyle(chartContext),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        );
      }

      return SizedBox(
        width: healthDp(chartContext, ChartConstants.weightChartYAxisWidth),
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
                        style: healthChartAxisUnitTextStyle(chartContext),
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

typedef WeightChartBodyBuilder = Widget Function(
  double chartHeight,
  Widget periodSelector,
);

/// 체중 목록: 그래프 블록(기간 탭은 카드 안으로 포함)
class WeightChartSection extends StatelessWidget {
  final Widget chartContent;

  const WeightChartSection({
    super.key,
    required this.chartContent,
  });

  @override
  Widget build(BuildContext context) => chartContent;
}

class WeightChartContent extends StatelessWidget {
  final String selectedPeriod;
  final List<Map<String, dynamic>> chartData;
  final List<double> yLabels;
  final double chartHeight;
  /// 시간대별(일)에서 선택일에 기록이 하나라도 있으면 true (혈당 hasActualDailyData와 동일)
  final bool hasActualDailyData;
  final bool showExpandButton;
  final VoidCallback? onExpand;
  final Widget periodSelector;
  final WeightChartBodyBuilder dataChartBuilder;
  final WeightChartBodyBuilder emptyChartBuilder;

  const WeightChartContent({
    super.key,
    required this.selectedPeriod,
    required this.chartData,
    required this.yLabels,
    required this.hasActualDailyData,
    required this.periodSelector,
    required this.dataChartBuilder,
    required this.emptyChartBuilder,
    this.chartHeight = ChartConstants.weightChartHeight,
    this.showExpandButton = true,
    this.onExpand,
  });

  @override
  Widget build(BuildContext context) => _buildChart(context);

  Widget _buildChart(BuildContext context) {
    final chartBody = _buildChartBody();

    if (!showExpandButton) return chartBody;

    final padTop = healthChartCardPadding(context).top;
    final tabH =
        healthDp(context, ChartConstants.weightChartPeriodTabBarHeight);
    final gap = ChartConstants.weightChartTabToPlotGap;
    final kgBand = yLabels.length > 1
        ? healthWeightChartKgBandHeight(context)
        : 0.0;
    final iconSize = healthDp(context, 20);
    final expandH = HealthChartExpandControl.blockHeight(context, iconSize);
    final topExpand = padTop + tabH + gap + kgBand / 2 - expandH / 2;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        chartBody,
        Positioned(
          right: healthChartCardPadding(context).right,
          top: topExpand,
          child: HealthChartExpandControl(
            onTap: onExpand!,
            iconSize: iconSize,
          ),
        ),
      ],
    );
  }

  Widget _buildChartBody() {
    if (selectedPeriod == '일' && !hasActualDailyData) {
      return HealthDailyNoDataChartCard(
        chartHeight: chartHeight,
        title: '해당 기간에 체중 기록이 없습니다',
        subtitle: '체중을 측정해보세요',
        header: periodSelector,
        showBorder: showExpandButton,
      );
    }

    if (selectedPeriod != '일' && chartData.isEmpty) {
      return emptyChartBuilder(chartHeight, periodSelector);
    }

    return dataChartBuilder(chartHeight, periodSelector);
  }
}

Widget buildWeightXAxisLabels({
  required BuildContext context,
  required String selectedPeriod,
  required DateTime selectedDate,
  required double timeOffset,
  bool forExpandedChart = false,
}) {
  if (selectedPeriod != '일') {
    return _buildWeightPeriodXAxisLabels(
      context: context,
      selectedPeriod: selectedPeriod,
      selectedDate: selectedDate,
      timeOffset: timeOffset,
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
  final isToday = selDay == today;
  final currentHour = now.hour;

  final hourWidgets = <Widget>[];
  for (int i = 0; i < slots; i++) {
    final hour = (startHour + i).clamp(0, 24);
    final hourLabel = hour == 24 ? '24' : hour.toString().padLeft(2, '0');
    final isCurrentHour = isToday && hour == currentHour;
    hourWidgets.add(
      Expanded(
        child: Text(
          hourLabel,
          textAlign: TextAlign.center,
          style: healthChartAxisTickTextStyle(
            context,
            color: isCurrentHour
                ? healthChartAxisCurrentHourColor
                : null,
          ),
        ),
      ),
    );
  }

  return _buildXAxisLabelWithUnit(
    context: context,
    labelRow: Row(
      children: hourWidgets,
    ),
    unitText: '(시)',
  );
}

Widget _buildWeightPeriodXAxisLabels({
  required BuildContext context,
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
      context: context,
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
              style: healthChartAxisTickTextStyle(context),
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
    allDateLabels.add('${date.day}');
  }

  final dateRow = Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

  return _buildXAxisLabelWithUnit(
    context: context,
    labelRow: dateRow,
    unitText: '(일)',
  );
}

Widget _buildXAxisLabelWithUnit({
  required BuildContext context,
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
            style: healthChartAxisUnitTextStyle(context),
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
  final Widget periodSelector;

  const WeightEmptyChart({
    super.key,
    required this.chartHeight,
    required this.selectedPeriod,
    required this.selectedDate,
    required this.timeOffset,
    required this.periodSelector,
    this.yLabels = const [67, 66, 65, 64, 63],
    this.showYAxisKgHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final segments = yLabels.length > 1 ? yLabels.length - 1 : 4;

    final outerPadding = healthChartCardPadding(context);

    return Container(
      height: chartHeight,
      padding: outerPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          periodSelector,
          SizedBox(height: healthDp(context, ChartConstants.weightChartTabToPlotGap)),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalH = constraints.maxHeight;
                final kgBand = showYAxisKgHeader && yLabels.length > 1
                    ? healthWeightChartKgBandHeight(context)
                    : 0.0;
                final zoneH = totalH - kgBand;

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
                                    _weightYAxisStripPlusGap(context),
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
}

class _WeightEmptyChartGridPainter extends CustomPainter {
  final int horizontalSegments;

  _WeightEmptyChartGridPainter({this.horizontalSegments = 4});

  @override
  void paint(Canvas canvas, Size size) {
    // 빈 차트도 데이터 영역의 배경 라인을 표시하지 않는다.
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
  final Widget periodSelector;
  final bool forExpandedChart;

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
    required this.periodSelector,
    this.forExpandedChart = false,
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
        periodSelector: periodSelector,
        forExpandedChart: forExpandedChart,
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
        periodSelector: periodSelector,
        forExpandedChart: forExpandedChart,
      );
    }

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
                                  _weightYAxisStripPlusGap(context),
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

  static const int _totalMonths = 12;
  static const int _visibleMonths = 7;

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
  }) {
    if (chartData.length < _totalMonths || yLabels.length < 2) return null;

    final minYWeight = yLabels.last;
    final maxYWeight = yLabels.first;
    final range = (maxYWeight - minYWeight).abs();
    if (range == 0) return null;

    const double leftPadding = 0.0;
    const double rightPadding = ChartConstants.weightXAxisUnitReservedWidth;
    final chartWidth = chartSize.width - leftPadding - rightPadding;
    final drawableHeight =
        chartSize.height - topPlotPad - bottomPlotPad;

    final maxStart = _totalMonths - _visibleMonths;
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

    final slotWidth = chartWidth / _visibleMonths;
    final relX = tap.dx - leftPadding;
    final v = (relX / slotWidth).floor().clamp(0, _visibleMonths - 1);
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
  final int? selectedIndex;
  final bool omitOutOfRangeWeights;
  final double topPlotPad;
  final double bottomPlotPad;
  final double scale;

  _WeightMonthlyRangePainter({
    required this.chartData,
    required this.yLabels,
    required this.timeOffset,
    this.selectedIndex,
    required this.omitOutOfRangeWeights,
    required this.topPlotPad,
    required this.bottomPlotPad,
    this.scale = 1.0,
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
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPlotPad - bottomPlotPad;

    final maxStart = _totalMonths - _visibleMonths;
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

      final visibleMin = omitOutOfRangeWeights
          ? minWeight.clamp(minYWeight, maxYWeight).toDouble()
          : minWeight;
      final visibleMax = omitOutOfRangeWeights
          ? maxWeight.clamp(minYWeight, maxYWeight).toDouble()
          : maxWeight;

      final slotWidth = chartWidth / _visibleMonths;
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
