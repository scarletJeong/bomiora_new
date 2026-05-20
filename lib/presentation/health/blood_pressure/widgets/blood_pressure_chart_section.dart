import 'package:flutter/material.dart';

import '../../../common/chart_layout.dart';
import '../../health_common/health_chart_axis_style.dart';
import '../../health_common/health_responsive_scale.dart';

/// `(mmHg)` 상단 밴드 높이 (375 기준 16).
double bloodPressureYAxisUnitBandHeight(BuildContext context) =>
    healthDp(context, 16);

/// 체중 그래프 Y축 스트립과 동일 레이아웃: 상단 단위 밴드 + 숫자 눈금
Widget buildBloodPressureYAxisStrip({
  required List<double> yLabels,
  required bool showYAxisHeader,
  String unitLabel = '(mmHg)',
  double tickFontSize = 12,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final totalH = constraints.maxHeight;
      final unitBand = showYAxisHeader && yLabels.length > 1
          ? bloodPressureYAxisUnitBandHeight(context)
          : 0.0;

      Widget numericLabels(double forHeight) {
        final n = yLabels.length;
        if (n < 2) return const SizedBox.shrink();
        return SizedBox(
          height: forHeight,
          child: LayoutBuilder(
            builder: (context, lc) {
              // 플롯 그리드와 Y축 숫자 위치를 일치시킨다.
              final plotTopPad = healthWeightChartVertPad(context);
              final plotBottomPad = healthWeightChartBottomPlotPad(context);
              final labelHalf = healthDp(context, 8);
              final h = lc.maxHeight - plotTopPad - plotBottomPad;
              return Stack(
                clipBehavior: Clip.none,
                children: yLabels.asMap().entries.map((e) {
                  final i = e.key;
                  final label = e.value;
                  final y = plotTopPad + h * i / (n - 1);
                  return Positioned(
                    top: y - labelHalf,
                    left: 0,
                    right: 0,
                    child: Text(
                      label.toStringAsFixed(0),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: healthChartAxisTickTextStyle(
                        context,
                        fontSize: tickFontSize,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        );
      }

      final yAxisW = healthDp(
        context,
        ChartConstants.weightChartYAxisWidth,
      );
      return SizedBox(
        width: yAxisW,
        child: showYAxisHeader && yLabels.length > 1
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: unitBand,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          unitLabel,
                          maxLines: 1,
                          softWrap: false,
                          style: healthChartAxisUnitTextStyle(context),
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

/// 수축기 색상 (레전드와 동일)
const Color _systolicColor = Color(0xFF86B0FF);

/// 이완기 색상 (레전드와 동일)
const Color _diastolicColor = Color(0xFFFFC686);

/// 혈압 차트 Painter
/// - 슬롯 내 측정 1건: 점
/// - 슬롯 내 측정 2건 이상: 최저~최고 막대
/// - 수축기·이완기는 동일 X축 위에 겹침 (겹칠 때 이완기 먼저, 수축기가 위)
class BloodPressureChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double minValue;
  final double maxValue;
  final List<double>? yLabels;
  final int? highlightedIndex;
  final bool isToday;
  final double timeOffset;

  /// 일(시간대별): X축 `spaceBetween` — 끝점 분포. 주/월: `Expanded` 칸 중앙.
  final bool cellCenterXSlots;
  final double topPlotPad;
  final double bottomPlotPad;

  /// 375 기준 1.0 — healthTextScaleByWidth 값을 넘긴다.
  final double scale;
  /// 위젯 라벨 row의 (시)/(일)/(월) 오른쪽 여백과 동일하게 painter에도 전달.
  final double? xUnitReservedWidth;

  BloodPressureChartPainter(
    this.data,
    this.minValue,
    this.maxValue, {
    this.yLabels,
    this.highlightedIndex,
    required this.isToday,
    required this.timeOffset,
    this.cellCenterXSlots = false,
    this.topPlotPad = 20,
    this.bottomPlotPad = 10,
    this.scale = 1.0,
    this.xUnitReservedWidth,
  });

  static const double borderWidth = 0.5;
  static const double basePointRadius = 5.0;

  /// X축 라벨 행에 적용할 좌우 inset (375 기준). 위젯에서 scale 반영 후 사용.
  static const double baseXInset = borderWidth + basePointRadius;

  /// X축 라벨 Row의 `weightXAxisUnitReservedWidth`와 동일하게 오른쪽 여백 제외
  static double _contentWidth(
    double plotWidth, {
    double pointRadius = basePointRadius,
    double? xUnitReservedWidth,
  }) {
    final unit =
        xUnitReservedWidth ?? ChartConstants.weightXAxisUnitReservedWidth;
    return plotWidth -
        (borderWidth * 2) -
        (pointRadius * 2) -
        unit;
  }

  /// 탭 히트 영역과 동일한 슬롯 중심 X
  static double slotCenterX(
    int index,
    int slotCount,
    double plotWidth, {
    required bool cellCenterXSlots,
    double pointRadius = basePointRadius,
    double? xUnitReservedWidth,
  }) {
    final left = borderWidth + pointRadius;
    final cw = _contentWidth(
      plotWidth,
      pointRadius: pointRadius,
      xUnitReservedWidth: xUnitReservedWidth,
    );
    if (cw <= 1) {
      return plotWidth / 2;
    }
    if (slotCount <= 1) {
      return left + cw / 2;
    }
    if (cellCenterXSlots) {
      return left + cw * (index + 0.5) / slotCount;
    }
    return left + cw * index / (slotCount - 1);
  }

  /// 탭 판정: 슬롯 가로 허용 반폭 (체중 주간 막대와 유사)
  static double slotHitHalfWidth(
    double plotWidth,
    int slotCount, {
    required bool cellCenterXSlots,
    double pointRadius = basePointRadius,
    double? xUnitReservedWidth,
  }) {
    final cw = _contentWidth(
      plotWidth,
      pointRadius: pointRadius,
      xUnitReservedWidth: xUnitReservedWidth,
    );
    if (cw <= 1 || slotCount < 1) return 24.0;
    if (slotCount == 1) return cw * 0.48;
    if (cellCenterXSlots) {
      return cw / (2 * slotCount) * 1.05;
    }
    return cw / (2 * (slotCount - 1)) * 1.05;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // 막대 두께는 체중 주/월 막대와 동일(10 / 선택 12). 단일 점은 체중 일별과 같이 5 / 선택 8
    final double pointRadius = basePointRadius * scale;
    final double highlightRadius = 8.0 * scale;
    final double barStrokeWidth = 10.0 * scale;
    final left = borderWidth + pointRadius;
    final contentW = _contentWidth(
      size.width,
      pointRadius: pointRadius,
      xUnitReservedWidth: xUnitReservedWidth,
    );
    final plotRight = left + contentW;

    for (int i = 0; i < data.length; i++) {
      final recordCount = (data[i]['recordCount'] as int?) ?? 0;
      if (recordCount <= 0) continue;

      final x = slotCenterX(
        i,
        data.length,
        size.width,
        cellCenterXSlots: cellCenterXSlots,
        pointRadius: pointRadius,
        xUnitReservedWidth: xUnitReservedWidth,
      );
      final isHighlighted = highlightedIndex != null && highlightedIndex == i;

      final systolicMin = data[i]['systolicMin'] as int?;
      final systolicMax = data[i]['systolicMax'] as int?;
      final diastolicMin = data[i]['diastolicMin'] as int?;
      final diastolicMax = data[i]['diastolicMax'] as int?;
      if (systolicMin == null ||
          systolicMax == null ||
          diastolicMin == null ||
          diastolicMax == null) {
        continue;
      }

      double toY(int value) {
        final clampedValue = value.clamp(minValue.toInt(), maxValue.toInt());
        final normalized = (maxValue - clampedValue) / (maxValue - minValue);
        return topPlotPad +
            (size.height - topPlotPad - bottomPlotPad) * normalized;
      }

      final ySysMin = toY(systolicMin);
      final ySysMax = toY(systolicMax);
      final yDiaMin = toY(diastolicMin);
      final yDiaMax = toY(diastolicMax);

      final sysPaint = Paint()
        ..color = _systolicColor
        ..style = PaintingStyle.fill;
      final diaPaint = Paint()
        ..color = _diastolicColor
        ..style = PaintingStyle.fill;

      if (recordCount >= 2) {
        final strokeW = isHighlighted ? 12.0 * scale : barStrokeWidth;

        final barPaintSys = Paint()
          ..color = _systolicColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round;
        final barPaintDia = Paint()
          ..color = _diastolicColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round;

        // 이완기 먼저, 수축기를 위에 겹침 (선택 시 막대 전체 두께↑ — 체중 주/월과 동일 개념)
        canvas.drawLine(Offset(x, yDiaMax), Offset(x, yDiaMin), barPaintDia);
        canvas.drawLine(Offset(x, ySysMax), Offset(x, ySysMin), barPaintSys);
      } else {
        final ySys = toY(systolicMax);
        final yDia = toY(diastolicMax);
        // 점도 동일 X (세로 위치만 다름)
        canvas.drawCircle(
            Offset(x, yDia), isHighlighted ? highlightRadius : pointRadius, diaPaint);
        canvas.drawCircle(
            Offset(x, ySys), isHighlighted ? highlightRadius : pointRadius, sysPaint);

        if (isHighlighted) {
          canvas.drawCircle(
            Offset(x, yDia),
            highlightRadius,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
          canvas.drawCircle(
            Offset(x, ySys),
            highlightRadius,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant BloodPressureChartPainter oldDelegate) {
    return oldDelegate.cellCenterXSlots != cellCenterXSlots ||
        oldDelegate.data != data ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.yLabels != yLabels ||
        oldDelegate.highlightedIndex != highlightedIndex ||
        oldDelegate.timeOffset != timeOffset ||
        oldDelegate.isToday != isToday ||
        oldDelegate.topPlotPad != topPlotPad ||
        oldDelegate.bottomPlotPad != bottomPlotPad ||
        oldDelegate.scale != scale ||
        oldDelegate.xUnitReservedWidth != xUnitReservedWidth;
  }
}

/// 빈 차트용 그리드 페인터
class EmptyChartGridPainter extends CustomPainter {
  final List<double> yLabels;
  final double topPlotPad;
  final double bottomPlotPad;

  EmptyChartGridPainter({
    required this.yLabels,
    this.topPlotPad = 20,
    this.bottomPlotPad = 10,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 빈 차트도 배경 그리드를 그리지 않는다.
  }

  @override
  bool shouldRepaint(covariant EmptyChartGridPainter oldDelegate) =>
      oldDelegate.yLabels != yLabels ||
      oldDelegate.topPlotPad != topPlotPad ||
      oldDelegate.bottomPlotPad != bottomPlotPad;
}
