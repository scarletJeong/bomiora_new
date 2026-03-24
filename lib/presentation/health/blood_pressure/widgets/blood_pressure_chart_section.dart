import 'package:flutter/material.dart';

import '../../../common/chart_layout.dart';

/// 체중 그래프 Y축 스트립과 동일 레이아웃: 상단 단위 밴드 + 숫자 눈금
Widget buildBloodPressureYAxisStrip({
  required List<double> yLabels,
  required bool showYAxisHeader,
  String unitLabel = '(mmHg)',
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final totalH = constraints.maxHeight;
      final unitBand =
          showYAxisHeader && yLabels.length > 1 ? totalH / 6.0 : 0.0;

      Widget numericLabels(double forHeight) {
        final n = yLabels.length;
        if (n < 2) return const SizedBox.shrink();
        return SizedBox(
          height: forHeight,
          child: LayoutBuilder(
            builder: (context, lc) {
              const topPad = 6.0;
              const botPad = 6.0;
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
        child: showYAxisHeader && yLabels.length > 1
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: unitBand,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Text(
                        unitLabel,
                        style: TextStyle(
                          // 그래프 mmHg 단위 표시
                          fontSize: 8,
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
  final int? highlightedIndex;
  final bool isToday;
  final double timeOffset;

  /// 일(시간대별): X축 `spaceBetween` — 끝점 분포. 주/월: `Expanded` 칸 중앙.
  final bool cellCenterXSlots;

  BloodPressureChartPainter(
    this.data,
    this.minValue,
    this.maxValue, {
    this.highlightedIndex,
    required this.isToday,
    required this.timeOffset,
    this.cellCenterXSlots = false,
  });

  static const double _borderWidth = 0.5;
  static const double _pointRadius = 5.0;

  /// X축 라벨 Row의 `weightXAxisUnitReservedWidth`와 동일하게 오른쪽 여백 제외
  static double _contentWidth(double plotWidth) {
    return plotWidth -
        (_borderWidth * 2) -
        (_pointRadius * 2) -
        ChartConstants.weightXAxisUnitReservedWidth;
  }

  /// 탭 히트 영역과 동일한 슬롯 중심 X
  static double slotCenterX(
    int index,
    int slotCount,
    double plotWidth, {
    required bool cellCenterXSlots,
  }) {
    final left = _borderWidth + _pointRadius;
    final cw = _contentWidth(plotWidth);
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
  }) {
    final cw = _contentWidth(plotWidth);
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
    const double highlightRadius = 8.0;
    const double barStrokeWidth = 10.0;
    final left = _borderWidth + _pointRadius;
    final contentW = _contentWidth(size.width);
    final plotRight = left + contentW;

    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    final dashedGridPaint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 0.5;

    final yValues = [250, 200, 150, 100, 50];
    final dashedYValues = [225, 175, 125, 75];

    for (int i = 0; i < yValues.length; i++) {
      const double topPadding = 20.0;
      const double bottomPadding = 20.0;
      double y = topPadding +
          (size.height - topPadding - bottomPadding) * i / (yValues.length - 1);
      canvas.drawLine(
        Offset(left, y),
        Offset(plotRight, y),
        gridPaint,
      );
    }

    for (int dashedValue in dashedYValues) {
      double normalizedY = (250 - dashedValue) / (250 - 50);
      const double topPadding = 20.0;
      const double bottomPadding = 20.0;
      double y =
          topPadding + (size.height - topPadding - bottomPadding) * normalizedY;

      for (double x = left; x < plotRight; x += 4) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x + 2, y),
          dashedGridPaint,
        );
      }
    }

    for (int i = 0; i < data.length; i++) {
      final recordCount = (data[i]['recordCount'] as int?) ?? 0;
      if (recordCount <= 0) continue;

      final x = slotCenterX(
        i,
        data.length,
        size.width,
        cellCenterXSlots: cellCenterXSlots,
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
        const double topPadding = 20.0;
        const double bottomPadding = 20.0;
        final normalized = (250 - value) / (250 - 50);
        return topPadding + (size.height - topPadding - bottomPadding) * normalized;
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
        final strokeW = isHighlighted ? 12.0 : barStrokeWidth;

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
            Offset(x, yDia), isHighlighted ? highlightRadius : _pointRadius, diaPaint);
        canvas.drawCircle(
            Offset(x, ySys), isHighlighted ? highlightRadius : _pointRadius, sysPaint);

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
        oldDelegate.highlightedIndex != highlightedIndex ||
        oldDelegate.timeOffset != timeOffset ||
        oldDelegate.isToday != isToday;
  }
}

/// 빈 차트용 그리드 페인터
class EmptyChartGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    final dashedGridPaint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 0.5;

    final yValues = [250, 200, 150, 100, 50];
    final dashedYValues = [225, 175, 125, 75];

    for (int i = 0; i < yValues.length; i++) {
      const double topPadding = 20.0;
      const double bottomPadding = 20.0;
      double y = topPadding +
          (size.height - topPadding - bottomPadding) * i / (yValues.length - 1);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    for (int dashedValue in dashedYValues) {
      double normalizedY = (250 - dashedValue) / (250 - 50);
      const double topPadding = 20.0;
      const double bottomPadding = 20.0;
      double y =
          topPadding + (size.height - topPadding - bottomPadding) * normalizedY;

      for (double x = 0; x < size.width; x += 4) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x + 2, y),
          dashedGridPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
