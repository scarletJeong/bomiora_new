import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../common/chart_layout.dart';
import '../../blood_pressure/widgets/blood_pressure_chart_section.dart';
import '../../health_common/health_chart_axis_style.dart';
import '../../health_common/health_responsive_scale.dart';
import '../../health_common/widgets/health_period_selector.dart';
import 'heart_rate_tooltip.dart';

double _plotLeftPad() => ChartConstants.weightDailyChartInnerPadH;

double _plotRightPad([double? xUnitReservedWidth]) =>
    ChartConstants.weightDailyChartInnerPadH +
    (xUnitReservedWidth ?? ChartConstants.weightXAxisUnitReservedWidth);

/// 주·월(캘린더 월) 슬롯 중심 X. 날짜 라벨(7칸 Expanded) 중심과 맞춤: (index+0.5)/7.
double? heartRatePeriodSlotCenterX({
  required Map<String, dynamic> data,
  required String selectedPeriod,
  required double timeOffset,
  required bool useCalendarYearMonths,
  required double chartWidth,
  double? xUnitReservedWidth,
}) {
  final xPosition = data['xPosition'] as double?;
  if (xPosition == null) return null;

  final leftPad = _plotLeftPad();
  final rightPad = _plotRightPad(xUnitReservedWidth);
  final effW = chartWidth - leftPad - rightPad;
  if (effW <= 0) return null;

  const visibleSlots = 7;
  final totalDays = selectedPeriod == '주' ? 7 : 30;

  if (selectedPeriod == '월' && useCalendarYearMonths) {
    const totalMonths = 12;
    const visibleMonths = 7;
    final maxStart = totalMonths - visibleMonths;
    final startIndex = (timeOffset * maxStart).round().clamp(0, maxStart);
    final endIndex = startIndex + visibleMonths;
    final dataIndex = (xPosition * (totalMonths - 1)).round();
    if (dataIndex < startIndex || dataIndex >= endIndex) return null;
    final relativeIndex = dataIndex - startIndex;
    return leftPad + effW * (relativeIndex + 0.5) / visibleMonths;
  }
  if (selectedPeriod == '월') {
    final maxOffset = (totalDays - visibleSlots) / totalDays;
    final currentOffset = timeOffset.clamp(0.0, maxOffset);
    final startIndex = (currentOffset * totalDays).floor();
    final endIndex = startIndex + visibleSlots;
    final dataIndex = (xPosition * totalDays).round();
    if (dataIndex < startIndex || dataIndex >= endIndex) return null;
    final relativeIndex = dataIndex - startIndex;
    return leftPad + effW * (relativeIndex + 0.5) / visibleSlots;
  }

  // 주간(7칸): xPosition은 0.0~1.0 양끝 포함 정규화로 들어옴을 전제로 함.
  // (tap hit-test 역산 로직과 동일하게) (totalDays-1) 기준으로 인덱스를 복원해야
  // 슬롯 중심((index+0.5)/7)과 정확히 정렬된다.
  final dataIndex = (xPosition * (totalDays - 1)).round().clamp(0, totalDays - 1);
  return leftPad + effW * (dataIndex + 0.5) / 7;
}

Widget buildHeartRateXAxisLabels({
  required BuildContext context,
  required String selectedPeriod,
  required DateTime selectedDate,
  required double timeOffset,
}) {
  if (selectedPeriod == '일') {
    const maxStartHour = 18;
    final startHour = (timeOffset * maxStartHour).clamp(0.0, 18.0).round();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selDay =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final isToday = selDay == today;
    final currentHour = now.hour;

    return _buildHeartRateXAxisWithUnit(
      context: context,
      labelRow: Row(
        children: List.generate(7, (i) {
          final hour = (startHour + i).clamp(0, 24);
          final hourLabel = hour == 24 ? '24' : hour.toString().padLeft(2, '0');
          final isCurrentHour = isToday && hour == currentHour;
          return Expanded(
            child: Text(
              hourLabel,
              textAlign: TextAlign.center,
              style: healthChartAxisTickTextStyle(
                context,
                color: isCurrentHour ? healthChartAxisCurrentHourColor : null,
              ),
            ),
          );
        }),
      ),
      unitText: '(시)',
    );
  }

  if (selectedPeriod == '월') {
    const totalMonths = 12;
    const visibleMonths = 7;
    final maxStart = totalMonths - visibleMonths;
    final startIndex = (timeOffset * maxStart).round().clamp(0, maxStart);

    return _buildHeartRateXAxisWithUnit(
      context: context,
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
    );
  }

  const days = 7;
  final endDate =
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  final startDate = endDate.subtract(Duration(days: days - 1));

  return _buildHeartRateXAxisWithUnit(
    context: context,
    labelRow: Row(
      children: List.generate(days, (i) {
        final date = startDate.add(Duration(days: i));
        return Expanded(
          child: Text(
            '${date.day}',
            textAlign: TextAlign.center,
            style: healthChartAxisTickTextStyle(context),
          ),
        );
      }),
    ),
    unitText: '(일)',
  );
}

Widget _buildHeartRateXAxisWithUnit({
  required BuildContext context,
  required Widget labelRow,
  required String unitText,
}) {
  final unitReserve =
      healthDp(context, ChartConstants.weightXAxisUnitReservedWidth);
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Padding(
        padding: EdgeInsets.only(right: unitReserve),
        child: labelRow,
      ),
      Positioned(
        right: -healthDp(context, 10),
        top: healthDp(context, 1),
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

/// 심박수 주·월(연간 월 축) 전용 차트. [PeriodChartWidget]에 넣지 않음.
class HeartRateChartWidget extends StatefulWidget {
  final List<Map<String, dynamic>> chartData;
  final List<double> yLabels;
  final String selectedPeriod;
  final double timeOffset;
  final void Function(double) onTimeOffsetChanged;
  final void Function(int?, Offset?) onTooltipChanged;
  final int? selectedChartPointIndex;
  final Offset? tooltipPosition;
  final int yAxisCount;
  final DateTime selectedDate;
  final double height;
  final bool useCalendarYearMonths;
  /// null이면 [healthChartCardPadding] 사용
  final EdgeInsetsGeometry? cardPadding;
  final Color? cardBackgroundColor;
  final bool showPeriodSelector;
  final ValueChanged<String>? onPeriodChanged;

  const HeartRateChartWidget({
    super.key,
    required this.chartData,
    required this.yLabels,
    required this.selectedPeriod,
    required this.timeOffset,
    required this.onTimeOffsetChanged,
    required this.onTooltipChanged,
    this.selectedChartPointIndex,
    this.tooltipPosition,
    required this.yAxisCount,
    required this.selectedDate,
    required this.height,
    required this.useCalendarYearMonths,
    this.cardPadding,
    this.cardBackgroundColor,
    this.showPeriodSelector = false,
    this.onPeriodChanged,
  });

  @override
  State<HeartRateChartWidget> createState() =>
      _HeartRateChartWidgetState();
}

class _HeartRateChartWidgetState extends State<HeartRateChartWidget> {
  @override
  Widget build(BuildContext context) {
    final cardPad = widget.cardPadding ?? healthChartCardPadding(context);
    final topPad = healthWeightChartVertPad(context);
    final botPad = healthWeightChartBottomPlotPad(context);
    return Container(
      height: widget.height,
      padding: cardPad,
      decoration: BoxDecoration(
        color: widget.cardBackgroundColor ?? Colors.grey[50],
        borderRadius: BorderRadius.circular(healthDp(context, 12)),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showPeriodSelector) ...[
            HealthPeriodSelector(
              selectedPeriod: widget.selectedPeriod,
              onChanged: widget.onPeriodChanged!,
              plainStyle: true,
            ),
            SizedBox(
                height: healthDp(
                    context, ChartConstants.weightChartTabToPlotGap)),
          ],
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final showYHeader = widget.yLabels.length > 1;
                final headerBand = showYHeader
                    ? bloodPressureYAxisUnitBandHeight(context)
                    : 0.0;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildBloodPressureYAxisStrip(
                      yLabels: widget.yLabels,
                      showYAxisHeader: showYHeader,
                      unitLabel: '(bpm)',
                    ),
                    SizedBox(
                        width: healthDp(
                            context, ChartConstants.weightChartYAxisPlotGap)),
                    Expanded(
                      child: Column(
                        children: [
                          if (showYHeader) SizedBox(height: headerBand),
                          Expanded(
                            child: _buildChartArea(topPad, botPad),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(
            height: healthDp(context, 30),
            child: Padding(
              padding: EdgeInsets.only(
                left: healthDp(
                  context,
                  ChartConstants.weightChartYAxisStripWidth,
                ),
              ),
              child: buildHeartRateXAxisLabels(
                context: context,
                selectedPeriod: widget.selectedPeriod,
                selectedDate: widget.selectedDate,
                timeOffset: widget.timeOffset,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartArea(double topPad, double botPad) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartAreaWidth = constraints.maxWidth;
        final chartAreaHeight = constraints.maxHeight;

        return Stack(
          children: [
            GestureDetector(
              onTapDown: (details) => _handleTap(
                details.localPosition,
                chartAreaWidth,
                chartAreaHeight,
                topPad,
                botPad,
              ),
              onTap: () {
                if (widget.selectedChartPointIndex != null) {
                  widget.onTooltipChanged(null, null);
                }
              },
              onPanUpdate: (details) {
                if (widget.selectedPeriod == '월') {
                  const sensitivity = 3.0;
                  final newOffset =
                      widget.timeOffset - (details.delta.dx / 1000) * sensitivity;
                  widget.onTimeOffsetChanged(newOffset.clamp(0.0, 1.0));
                }
              },
              child: CustomPaint(
                painter: _HeartRateChartPainter(
                  chartData: widget.chartData,
                  yLabels: widget.yLabels,
                  timeOffset: widget.timeOffset,
                  selectedPeriod: widget.selectedPeriod,
                  selectedPointIndex: widget.selectedChartPointIndex,
                  yAxisCount: widget.yAxisCount,
                  useCalendarYearMonths: widget.useCalendarYearMonths,
                  topPlotPad: topPad,
                  bottomPlotPad: botPad,
                  scale: healthTextScaleByWidth(MediaQuery.of(context).size.width),
                  xUnitReservedWidth: healthDp(
                    context,
                    ChartConstants.weightXAxisUnitReservedWidth,
                  ),
                ),
                size: Size(chartAreaWidth, chartAreaHeight),
              ),
            ),
            if (widget.selectedChartPointIndex != null &&
                widget.tooltipPosition != null)
              HeartRateTooltip(
                data: widget.chartData[widget.selectedChartPointIndex!],
                selectedPeriod: widget.selectedPeriod,
                useCalendarYearMonths: widget.useCalendarYearMonths,
                tooltipPosition: widget.tooltipPosition,
                chartWidth: chartAreaWidth,
                chartHeight: chartAreaHeight,
              ),
          ],
        );
      },
    );
  }

  void _handleTap(
    Offset tap,
    double chartWidth,
    double chartHeight,
    double topPadding,
    double bottomPadding,
  ) {
    if (widget.chartData.isEmpty) return;

    final minValue = widget.yLabels[widget.yAxisCount - 1];
    final maxValue = widget.yLabels[0];
    final scale = healthTextScaleByWidth(MediaQuery.of(context).size.width);
    final barWidth = 10.0 * scale;
    final minBarHeight = 5.0 * scale;
    final dotRadius = 6.0 * scale;
    const hitSlop = 14.0;

    final plotH = chartHeight - topPadding - bottomPadding;
    if (plotH <= 0 || maxValue == minValue) {
      widget.onTooltipChanged(null, null);
      return;
    }

    // 탭된 x로부터 "가장 가까운 슬롯 인덱스"를 역산해서 후보만 검사 (성능 개선)
    final unitReserve =
        healthDp(context, ChartConstants.weightXAxisUnitReservedWidth);
    final leftPad = _plotLeftPad();
    final rightPad = _plotRightPad(unitReserve);
    final effW = chartWidth - leftPad - rightPad;
    if (effW <= 0) {
      widget.onTooltipChanged(null, null);
      return;
    }

    int? candidateDataIndex;
    int? startIndex;
    int? endIndexExclusive;
    int slots = 7;

    if (widget.selectedPeriod == '주') {
      // 항상 7칸 고정
      final rel = ((tap.dx - leftPad) / effW) * 7 - 0.5;
      candidateDataIndex = rel.round().clamp(0, 6);
      startIndex = 0;
      endIndexExclusive = 7;
      slots = 7;
    } else if (widget.selectedPeriod == '월' && widget.useCalendarYearMonths) {
      const totalMonths = 12;
      const visibleMonths = 7;
      final maxStart = totalMonths - visibleMonths;
      final s = (widget.timeOffset * maxStart).round().clamp(0, maxStart);
      final rel = ((tap.dx - leftPad) / effW) * visibleMonths - 0.5;
      candidateDataIndex =
          (s + rel.round()).clamp(s, s + visibleMonths - 1);
      startIndex = s;
      endIndexExclusive = s + visibleMonths;
      slots = visibleMonths;
    } else if (widget.selectedPeriod == '월') {
      // 캘린더 월(30일) 중 7칸만 노출
      const totalDays = 30;
      const visibleSlots = 7;
      final maxOffset = (totalDays - visibleSlots) / totalDays;
      final currentOffset = widget.timeOffset.clamp(0.0, maxOffset);
      final s = (currentOffset * totalDays).floor().clamp(0, totalDays - 1);
      final rel = ((tap.dx - leftPad) / effW) * visibleSlots - 0.5;
      candidateDataIndex = (s + rel.round()).clamp(s, s + visibleSlots - 1);
      startIndex = s;
      endIndexExclusive = s + visibleSlots;
      slots = visibleSlots;
    }

    double toY(double bpm) {
      final n = (maxValue - bpm) / (maxValue - minValue);
      return topPadding + plotH * n;
    }

    int? bestIndex;
    Offset? bestPoint;
    var bestDist = double.infinity;

    // 후보 인덱스: candidateDataIndex 근처(-1..+1)만 검사
    for (int i = 0; i < widget.chartData.length; i++) {
      final data = widget.chartData[i];
      final series = data['hrSeries'] as List<dynamic>?;
      if (series == null || series.isEmpty) continue;

      final xPosition = data['xPosition'] as double?;
      if (xPosition == null) continue;

      double? x;
      int? dataIndex;

      if (widget.selectedPeriod == '주') {
        const totalDays = 7;
        dataIndex = (xPosition * (totalDays - 1)).round().clamp(0, 6);
        if (candidateDataIndex != null &&
            (dataIndex - candidateDataIndex).abs() > 1) continue;
        x = leftPad + effW * (dataIndex + 0.5) / 7;
      } else if (widget.selectedPeriod == '월' && widget.useCalendarYearMonths) {
        const totalMonths = 12;
        dataIndex = (xPosition * (totalMonths - 1)).round().clamp(0, 11);
        if (startIndex != null &&
            endIndexExclusive != null &&
            (dataIndex < startIndex || dataIndex >= endIndexExclusive)) continue;
        if (candidateDataIndex != null &&
            (dataIndex - candidateDataIndex).abs() > 1) continue;
        final rel = dataIndex - (startIndex ?? 0);
        x = leftPad + effW * (rel + 0.5) / slots;
      } else if (widget.selectedPeriod == '월') {
        const totalDays = 30;
        dataIndex = (xPosition * totalDays).round().clamp(0, totalDays - 1);
        if (startIndex != null &&
            endIndexExclusive != null &&
            (dataIndex < startIndex || dataIndex >= endIndexExclusive)) continue;
        if (candidateDataIndex != null &&
            (dataIndex - candidateDataIndex).abs() > 1) continue;
        final rel = dataIndex - (startIndex ?? 0);
        x = leftPad + effW * (rel + 0.5) / slots;
      } else {
        // 혹시 다른 period면 기존 방식으로 처리
        x = heartRatePeriodSlotCenterX(
          data: data,
          selectedPeriod: widget.selectedPeriod,
          timeOffset: widget.timeOffset,
          useCalendarYearMonths: widget.useCalendarYearMonths,
          chartWidth: chartWidth,
          xUnitReservedWidth: unitReserve,
        );
      }

      if (x == null) continue;

      for (int j = series.length - 1; j >= 0; j--) {
        final seg = series[j] as Map<String, dynamic>;
        final kind = seg['kind'] as String?;
        if (kind == 'bar') {
          final minB = seg['minBpm'] as int;
          final maxB = seg['maxBpm'] as int;
          var yHigh = toY(maxB.toDouble());
          var yLow = toY(minB.toDouble());
          if (yHigh > yLow) {
            final t = yHigh;
            yHigh = yLow;
            yLow = t;
          }
          var barH = yLow - yHigh;
          if (barH < minBarHeight) {
            final mid = (yHigh + yLow) / 2;
            yHigh = mid - minBarHeight / 2;
            barH = minBarHeight;
          }
          final rect = Rect.fromLTRB(
            x - barWidth / 2 - hitSlop,
            yHigh - hitSlop,
            x + barWidth / 2 + hitSlop,
            yHigh + barH + hitSlop,
          );
          if (rect.contains(tap)) {
            final cy = yHigh + barH / 2;
            final d = (tap - Offset(x, cy)).distanceSquared;
            if (d < bestDist) {
              bestDist = d;
              bestIndex = i;
              bestPoint = Offset(x, cy);
            }
          }
        } else if (kind == 'dot') {
          final bpm = seg['bpm'] as int;
          final y = toY(bpm.toDouble());
          final d = (tap - Offset(x, y)).distanceSquared;
          final maxD = (dotRadius + hitSlop) * (dotRadius + hitSlop);
          if (d <= maxD && d < bestDist) {
            bestDist = d;
            bestIndex = i;
            bestPoint = Offset(x, y);
          }
        }
      }
    }

    if (bestIndex != null && bestDist < 4000) {
      widget.onTooltipChanged(bestIndex, bestPoint);
    } else {
      widget.onTooltipChanged(null, null);
    }
  }
}

class _HeartRateChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> chartData;
  final List<double> yLabels;
  final double timeOffset;
  final String selectedPeriod;
  final int? selectedPointIndex;
  final int yAxisCount;
  final bool useCalendarYearMonths;
  final double topPlotPad;
  final double bottomPlotPad;

  /// 375 기준 1.0 — healthTextScaleByWidth 값을 넘긴다.
  final double scale;
  final double? xUnitReservedWidth;

  _HeartRateChartPainter({
    required this.chartData,
    required this.yLabels,
    required this.timeOffset,
    required this.selectedPeriod,
    this.selectedPointIndex,
    required this.yAxisCount,
    required this.useCalendarYearMonths,
    required this.topPlotPad,
    required this.bottomPlotPad,
    this.scale = 1.0,
    this.xUnitReservedWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (chartData.isEmpty) return;

    final minValue = yLabels[yAxisCount - 1];
    final maxValue = yLabels[0];

    final leftPad = _plotLeftPad();
    final rightPad = _plotRightPad(xUnitReservedWidth);

    if (maxValue == minValue) return;

    final barWidth = 10.0 * scale;
    final minBarHeight = 5.0 * scale;
    final dotOuter = 6.0 * scale;
    final dotInner = 4.0 * scale;

    final plotH = size.height - topPlotPad - bottomPlotPad;
    if (plotH <= 0) return;

    double toY(double bpm) {
      final n = (maxValue - bpm) / (maxValue - minValue);
      return topPlotPad + plotH * n;
    }

    for (int i = 0; i < chartData.length; i++) {
      final data = chartData[i];
      final series = data['hrSeries'] as List<dynamic>?;
      if (series == null || series.isEmpty) continue;

      final x = heartRatePeriodSlotCenterX(
        data: data,
        selectedPeriod: selectedPeriod,
        timeOffset: timeOffset,
        useCalendarYearMonths: useCalendarYearMonths,
        chartWidth: size.width,
        xUnitReservedWidth: xUnitReservedWidth,
      );
      if (x == null) continue;

      final isSelected = selectedPointIndex == i;

      for (final raw in series) {
        if (raw is! Map<String, dynamic>) continue;
        final seg = raw;
        final exercise = seg['exercise'] == true;
        final color =
            exercise ? heartRateTooltipExerciseColor : heartRateTooltipDailyColor;
        final kind = seg['kind'] as String?;

        if (kind == 'bar') {
          final minB = seg['minBpm'] as int;
          final maxB = seg['maxBpm'] as int;
          var yHigh = toY(maxB.toDouble());
          var yLow = toY(minB.toDouble());
          if (yHigh > yLow) {
            final t = yHigh;
            yHigh = yLow;
            yLow = t;
          }
          var barH = yLow - yHigh;
          if (barH < minBarHeight) {
            final mid = (yHigh + yLow) / 2;
            yHigh = mid - minBarHeight / 2;
            barH = minBarHeight;
          }
          final w = isSelected ? barWidth + 3 : barWidth;
          final barRect = Rect.fromLTWH(x - w / 2, yHigh, w, barH);
          final cornerR = math.min(w / 2, barH / 2);
          final fill = Paint()
            ..color = color
            ..style = PaintingStyle.fill;
          canvas.drawRRect(
            RRect.fromRectAndRadius(barRect, Radius.circular(cornerR)),
            fill,
          );
          if (isSelected) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(barRect, Radius.circular(cornerR)),
              Paint()
                ..color = Colors.white
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2,
            );
          }
        } else if (kind == 'dot') {
          final bpm = seg['bpm'] as int;
          final y = toY(bpm.toDouble());
          final rOuter = isSelected ? 8.0 * scale : dotOuter;
          final rInner = isSelected ? 5.0 * scale : dotInner;
          if (exercise) {
            canvas.drawCircle(Offset(x, y), rOuter, Paint()..color = color);
            canvas.drawCircle(Offset(x, y), rInner, Paint()..color = Colors.white);
          } else {
            // 일상: 안이 비지 않은 꽉 찬 점
            canvas.drawCircle(Offset(x, y), rOuter, Paint()..color = color);
          }
          if (isSelected) {
            canvas.drawCircle(
              Offset(x, y),
              rOuter,
              Paint()
                ..color = Colors.white
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeartRateChartPainter oldDelegate) {
    return oldDelegate.chartData != chartData ||
        oldDelegate.yLabels != yLabels ||
        oldDelegate.timeOffset != timeOffset ||
        oldDelegate.selectedPeriod != selectedPeriod ||
        oldDelegate.selectedPointIndex != selectedPointIndex ||
        oldDelegate.yAxisCount != yAxisCount ||
        oldDelegate.useCalendarYearMonths != useCalendarYearMonths ||
        oldDelegate.topPlotPad != topPlotPad ||
        oldDelegate.bottomPlotPad != bottomPlotPad ||
        oldDelegate.scale != scale ||
        oldDelegate.xUnitReservedWidth != xUnitReservedWidth;
  }
}
