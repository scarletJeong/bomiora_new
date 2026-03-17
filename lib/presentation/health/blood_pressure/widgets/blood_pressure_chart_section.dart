import 'package:flutter/material.dart';

/// 수축기 색상 (레전드와 동일)
const Color _systolicColor = Color(0xFF86B0FF);

/// 이완기 색상 (레전드와 동일)
const Color _diastolicColor = Color(0xFFFFC686);

/// 혈압 차트 Painter (수축기/이완기 라인 + 꽉 찬 점)
class BloodPressureChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double minValue;
  final double maxValue;
  final int? highlightedIndex;
  final bool isToday;
  final double timeOffset;

  BloodPressureChartPainter(this.data, this.minValue, this.maxValue,
      {this.highlightedIndex, required this.isToday, required this.timeOffset});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const double borderWidth = 0.5;
    const double pointRadius = 8;
    final chartWidth =
        size.width - (borderWidth * 2) - (pointRadius * 2);

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
        Offset(borderWidth + pointRadius, y),
        Offset(chartWidth + borderWidth + pointRadius, y),
        gridPaint,
      );
    }

    for (int dashedValue in dashedYValues) {
      double normalizedY = (250 - dashedValue) / (250 - 50);
      const double topPadding = 20.0;
      const double bottomPadding = 20.0;
      double y =
          topPadding + (size.height - topPadding - bottomPadding) * normalizedY;

      for (double x = borderWidth + pointRadius;
          x < chartWidth + borderWidth + pointRadius;
          x += 4) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x + 2, y),
          dashedGridPaint,
        );
      }
    }

    List<List<Offset>> systolicSegments = [];
    List<List<Offset>> diastolicSegments = [];
    List<List<int>> indexSegments = [];

    List<Offset> currentSystolic = [];
    List<Offset> currentDiastolic = [];
    List<int> currentIndices = [];

    const maxStartHour = 18;
    final startHour =
        (timeOffset * maxStartHour).clamp(0, maxStartHour).round();
    final endHour = startHour + 6;

    for (int i = 0; i < data.length; i++) {
      if (data[i]['systolic'] == null || data[i]['diastolic'] == null) continue;

      final recordHour = data[i]['hour'] as int?;
      if (recordHour != null) {
        if (recordHour < startHour || recordHour > endHour) {
          if (currentSystolic.isNotEmpty) {
            systolicSegments.add(List.from(currentSystolic));
            diastolicSegments.add(List.from(currentDiastolic));
            indexSegments.add(List.from(currentIndices));
            currentSystolic.clear();
            currentDiastolic.clear();
            currentIndices.clear();
          }
          continue;
        }
      }

      if (data[i]['xPosition'] != null && data.length > 7) {
        final xPosition = data[i]['xPosition'] as double;
        final visibleDays = 7;
        final totalDays = 30;
        final maxOffset = (totalDays - visibleDays) / totalDays;
        final currentOffset = timeOffset.clamp(0.0, maxOffset);
        final startRatio = currentOffset;
        final endRatio =
            (currentOffset + (visibleDays / totalDays)).clamp(0.0, 1.0);

        if (xPosition < startRatio || xPosition > endRatio) {
          if (currentSystolic.isNotEmpty) {
            systolicSegments.add(List.from(currentSystolic));
            diastolicSegments.add(List.from(currentDiastolic));
            indexSegments.add(List.from(currentIndices));
            currentSystolic.clear();
            currentDiastolic.clear();
            currentIndices.clear();
          }
          continue;
        }
      }

      double x;
      if (data[i]['xPosition'] != null) {
        final xPosition = data[i]['xPosition'] as double;

        if (data.length > 7) {
          final visibleDays = 7;
          final totalDays = 30;
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

      int systolic = data[i]['systolic'];
      int diastolic = data[i]['diastolic'];

      const double topPadding = 20.0;
      const double bottomPadding = 20.0;
      double normalizedSystolic = (250 - systolic) / (250 - 50);
      double ySystolic = topPadding +
          (size.height - topPadding - bottomPadding) * normalizedSystolic;

      double normalizedDiastolic = (250 - diastolic) / (250 - 50);
      double yDiastolic = topPadding +
          (size.height - topPadding - bottomPadding) * normalizedDiastolic;

      currentSystolic.add(Offset(x, ySystolic));
      currentDiastolic.add(Offset(x, yDiastolic));
      currentIndices.add(i);
    }

    if (currentSystolic.isNotEmpty) {
      systolicSegments.add(currentSystolic);
      diastolicSegments.add(currentDiastolic);
      indexSegments.add(currentIndices);
    }

    final linePaint = Paint()
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // 수축기 곡선 (#86B0FF)
    linePaint.color = _systolicColor;
    for (var segment in systolicSegments) {
      if (segment.length == 1) continue;

      final path = Path();
      path.moveTo(segment[0].dx, segment[0].dy);

      if (segment.length == 2) {
        path.lineTo(segment[1].dx, segment[1].dy);
      } else {
        for (int i = 0; i < segment.length - 1; i++) {
          final p0 = i > 0 ? segment[i - 1] : segment[i];
          final p1 = segment[i];
          final p2 = segment[i + 1];
          final p3 = i < segment.length - 2 ? segment[i + 2] : segment[i + 1];

          final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
          final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
          final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
          final cp2y = p2.dy - (p3.dy - p1.dy) / 6;

          path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
        }
      }

      canvas.drawPath(path, linePaint);
    }

    // 이완기 곡선 (#FFC686)
    linePaint.color = _diastolicColor;
    for (var segment in diastolicSegments) {
      if (segment.length == 1) continue;

      final path = Path();
      path.moveTo(segment[0].dx, segment[0].dy);

      if (segment.length == 2) {
        path.lineTo(segment[1].dx, segment[1].dy);
      } else {
        for (int i = 0; i < segment.length - 1; i++) {
          final p0 = i > 0 ? segment[i - 1] : segment[i];
          final p1 = segment[i];
          final p2 = segment[i + 1];
          final p3 = i < segment.length - 2 ? segment[i + 2] : segment[i + 1];

          final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
          final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
          final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
          final cp2y = p2.dy - (p3.dy - p1.dy) / 6;

          path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
        }
      }

      canvas.drawPath(path, linePaint);
    }

    // 포인트 그리기 (꽉 찬 원 + 선택 시 흰색 외곽선만)
    for (int segIdx = 0; segIdx < systolicSegments.length; segIdx++) {
      final systolicPoints = systolicSegments[segIdx];
      final diastolicPoints = diastolicSegments[segIdx];
      final dataIndices = indexSegments[segIdx];

      for (int i = 0; i < systolicPoints.length; i++) {
        final originalIndex = dataIndices[i];
        final isHighlighted =
            highlightedIndex != null && highlightedIndex == originalIndex;

        final systolicPaint = Paint()
          ..color = _systolicColor
          ..style = PaintingStyle.fill;

        if (isHighlighted) {
          canvas.drawCircle(systolicPoints[i], 8, systolicPaint);
          canvas.drawCircle(
            systolicPoints[i],
            8,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        } else {
          canvas.drawCircle(systolicPoints[i], 5, systolicPaint);
        }

        final diastolicPaint = Paint()
          ..color = _diastolicColor
          ..style = PaintingStyle.fill;

        if (isHighlighted) {
          canvas.drawCircle(diastolicPoints[i], 8, diastolicPaint);
          canvas.drawCircle(
            diastolicPoints[i],
            8,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        } else {
          canvas.drawCircle(diastolicPoints[i], 5, diastolicPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
