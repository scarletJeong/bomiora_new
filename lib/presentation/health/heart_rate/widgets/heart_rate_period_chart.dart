import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../common/chart_layout.dart';
import '../../weight/widgets/weight_chart_section.dart';
import 'heart_rate_tooltip.dart';

double _plotLeftPad() => ChartConstants.weightDailyChartInnerPadH;

double _plotRightPad() =>
    ChartConstants.weightDailyChartInnerPadH +
    ChartConstants.weightXAxisUnitReservedWidth;

/// 주·월(캘린더 월) 슬롯 중심 X. 날짜 라벨(7칸 Expanded) 중심과 맞춤: (index+0.5)/7.
double? heartRatePeriodSlotCenterX({
  required Map<String, dynamic> data,
  required String selectedPeriod,
  required double timeOffset,
  required bool useCalendarYearMonths,
  required double chartWidth,
}) {
  final xPosition = data['xPosition'] as double?;
  if (xPosition == null) return null;

  final leftPad = _plotLeftPad();
  final rightPad = _plotRightPad();
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

  final dataIndex = (xPosition * totalDays).round();
  return leftPad + effW * (dataIndex + 0.5) / 7;
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
  final EdgeInsetsGeometry padding;
  final Color? cardBackgroundColor;

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
    this.padding = const EdgeInsets.all(10),
    this.cardBackgroundColor,
  });

  @override
  State<HeartRateChartWidget> createState() =>
      _HeartRateChartWidgetState();
}

class _HeartRateChartWidgetState extends State<HeartRateChartWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.cardBackgroundColor ?? Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final totalH = c.maxHeight;
                final kgBand = widget.yLabels.length > 1 ? totalH / 6.0 : 0.0;

                Widget yLabelsColumn() {
                  final n = widget.yLabels.length;
                  if (n < 2) return const SizedBox.shrink();
                  return LayoutBuilder(
                    builder: (context, lc) {
                      const topPad = 6.0;
                      const botPad = 6.0;
                      final h = lc.maxHeight - topPad - botPad;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: widget.yLabels.asMap().entries.map((e) {
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
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: ChartConstants.weightChartYAxisWidth,
                      child: Column(
                        children: [
                          SizedBox(
                            height: kgBand,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Text(
                                '(bpm)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          Expanded(child: yLabelsColumn()),
                        ],
                      ),
                    ),
                    SizedBox(width: ChartConstants.yAxisSpacing),
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(height: kgBand),
                          Expanded(child: _buildChartArea()),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 43.0, bottom: 0),
            child: buildWeightXAxisLabels(
              selectedPeriod: widget.selectedPeriod,
              selectedDate: widget.selectedDate,
              timeOffset: widget.timeOffset,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartArea() {
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

  void _handleTap(Offset tap, double chartWidth, double chartHeight) {
    if (widget.chartData.isEmpty) return;

    final minValue = widget.yLabels[widget.yAxisCount - 1];
    final maxValue = widget.yLabels[0];
    const topPadding = 20.0;
    const bottomPadding = 20.0;
    const barWidth = 10.0;
    const minBarHeight = 5.0;
    const dotRadius = 6.0;
    const hitSlop = 14.0;

    final plotH = chartHeight - topPadding - bottomPadding;
    if (plotH <= 0 || maxValue == minValue) {
      widget.onTooltipChanged(null, null);
      return;
    }

    // 탭된 x로부터 "가장 가까운 슬롯 인덱스"를 역산해서 후보만 검사 (성능 개선)
    final leftPad = _plotLeftPad();
    final rightPad = _plotRightPad();
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

  _HeartRateChartPainter({
    required this.chartData,
    required this.yLabels,
    required this.timeOffset,
    required this.selectedPeriod,
    this.selectedPointIndex,
    required this.yAxisCount,
    required this.useCalendarYearMonths,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (chartData.isEmpty) return;

    final minValue = yLabels[yAxisCount - 1];
    final maxValue = yLabels[0];

    final leftPad = _plotLeftPad();
    final rightPad = _plotRightPad();
    const topPadding = 20.0;
    const bottomPadding = 20.0;

    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    for (int i = 0; i < yAxisCount; i++) {
      final y = topPadding +
          (size.height - topPadding - bottomPadding) * i / (yAxisCount - 1);
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );
    }

    if (maxValue == minValue) return;

    const barWidth = 10.0;
    const minBarHeight = 5.0;
    const dotOuter = 6.0;
    const dotInner = 4.0;

    final plotH = size.height - topPadding - bottomPadding;
    if (plotH <= 0) return;

    double toY(double bpm) {
      final n = (maxValue - bpm) / (maxValue - minValue);
      return topPadding + plotH * n;
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
          final rOuter = isSelected ? 8.0 : dotOuter;
          final rInner = isSelected ? 5.0 : dotInner;
          canvas.drawCircle(Offset(x, y), rOuter, Paint()..color = color);
          canvas.drawCircle(Offset(x, y), rInner, Paint()..color = Colors.white);
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
