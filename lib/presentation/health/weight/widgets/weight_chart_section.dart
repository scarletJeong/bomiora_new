import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../common/chart_layout.dart';
import '../../health_common/health_chart_axis_style.dart';
import '../../health_common/health_chart_metrics.dart';
import '../../health_common/health_responsive_scale.dart';
import '../../health_common/widgets/health_chart_expand_control.dart';
part 'weight_chart_monthly.dart';
part 'weight_chart_weekly.dart';

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
    final chartBody = _buildChartBody(context);

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

  Widget _buildChartBody(BuildContext context) {
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
  bool forExpandedChart = false,
}) {
  if (selectedPeriod == '월') {
    final visibleMonths = healthMonthlySlotCount(forExpandedChart);
    final maxStart = healthMonthlyMaxStartIndex(forExpandedChart);
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
            child: Padding(
              padding: EdgeInsets.only(
                bottom: forExpandedChart ? healthDp(context, 4) : 0,
              ),
              child: buildWeightXAxisLabels(
                context: context,
                selectedPeriod: selectedPeriod,
                selectedDate: selectedDate,
                timeOffset: timeOffset,
                forExpandedChart: forExpandedChart,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
