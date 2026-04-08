import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../data/models/health/blood_pressure/blood_pressure_record_model.dart';
import '../../../common/chart_layout.dart';
import 'blood_pressure_chart_section.dart';

/// 차트 슬롯 탭 시 선택될 인덱스와 툴팁 앵커(막대 상단 근처).
class BloodPressureChartHit {
  const BloodPressureChartHit({
    required this.index,
    required this.anchor,
  });

  final int index;
  final Offset anchor;
}

/// 혈압 차트 막대 영역 히트 테스트. `null`이면 선택 해제(탭 미스 또는 거리 초과).
BloodPressureChartHit? hitTestBloodPressureChartSlot({
  required Offset tapPosition,
  required List<Map<String, dynamic>> chartData,
  required double minValue,
  required double maxValue,
  required double chartWidth,
  required double chartHeight,
  required bool cellCenterXSlots,
  double maxPickDistance = 220,
}) {
  if (chartData.isEmpty) return null;

  final halfHitW = BloodPressureChartPainter.slotHitHalfWidth(
    chartWidth,
    chartData.length,
    cellCenterXSlots: cellCenterXSlots,
  );

  int? closestIndex;
  double minDistance = double.infinity;
  Offset? closestPoint;

  const double topPadding = 20.0;
  const double bottomPadding = 20.0;
  double toY(int value) {
    final clampedValue = value.clamp(minValue.toInt(), maxValue.toInt());
    final nv = (maxValue - clampedValue) / (maxValue - minValue);
    return topPadding +
        (chartHeight - topPadding - bottomPadding) * nv;
  }

  for (int i = 0; i < chartData.length; i++) {
    if ((chartData[i]['recordCount'] as int? ?? 0) == 0) {
      continue;
    }

    final x = BloodPressureChartPainter.slotCenterX(
      i,
      chartData.length,
      chartWidth,
      cellCenterXSlots: cellCenterXSlots,
    );

    final dx = (tapPosition.dx - x).abs();
    if (dx > halfHitW * 1.35) {
      continue;
    }

    final systolicMin = chartData[i]['systolicMin'] as int;
    final systolicMax = chartData[i]['systolicMax'] as int;
    final diastolicMin = chartData[i]['diastolicMin'] as int;
    final diastolicMax = chartData[i]['diastolicMax'] as int;
    final recordCount = chartData[i]['recordCount'] as int? ?? 0;

    final ySysMin = toY(systolicMin);
    final ySysMax = toY(systolicMax);
    final yDiaMin = toY(diastolicMin);
    final yDiaMax = toY(diastolicMax);

    double bandDistance;
    Offset tooltipAnchor;

    if (recordCount >= 2) {
      final colTop = math.min(ySysMax, yDiaMax);
      final colBottom = math.max(ySysMin, yDiaMin);
      const yMargin = 14.0;
      final inYBand = tapPosition.dy >= colTop - yMargin &&
          tapPosition.dy <= colBottom + yMargin;
      final yCenter = (colTop + colBottom) / 2;
      bandDistance =
          dx + (inYBand ? 0 : (tapPosition.dy - yCenter).abs());
      tooltipAnchor = Offset(x, colTop);
    } else {
      final ySys = toY(systolicMax);
      final yDia = toY(diastolicMax);
      final yTop = math.min(ySys, yDia);
      final yBot = math.max(ySys, yDia);
      const yMargin = 18.0;
      final inYBand = tapPosition.dy >= yTop - yMargin &&
          tapPosition.dy <= yBot + yMargin;
      final yCenter = (yTop + yBot) / 2;
      bandDistance =
          dx + (inYBand ? 0 : (tapPosition.dy - yCenter).abs());
      tooltipAnchor = Offset(x, yTop);
    }

    if (bandDistance < minDistance) {
      minDistance = bandDistance;
      closestIndex = i;
      closestPoint = tooltipAnchor;
    }
  }

  if (closestIndex != null &&
      closestPoint != null &&
      minDistance < maxPickDistance) {
    return BloodPressureChartHit(
      index: closestIndex,
      anchor: closestPoint,
    );
  }
  return null;
}

Widget _valueRowWithBadge({
  required String badgeLabel,
  required Color badgeColor,
  required String value,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 16,
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: ShapeDecoration(
          color: badgeColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(19),
          ),
        ),
        child: Center(
          child: Text(
            badgeLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
      const SizedBox(width: 5),
      Text(
        value,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

/// 차트 툴팁 (흰 배경, 수·이 배지는 수정 바텀시트와 동일 스타일).
Widget buildBloodPressureChartTooltip({
  required Map<String, dynamic> data,
  required Offset tooltipAnchor,
  required double chartWidth,
  required double chartHeight,
  required String selectedPeriod,
  required DateTime selectedDate,
}) {
  if ((data['recordCount'] as int? ?? 0) == 0) {
    return const SizedBox.shrink();
  }

  final systolicMin = data['systolicMin'] as int;
  final systolicMax = data['systolicMax'] as int;
  final diastolicMin = data['diastolicMin'] as int;
  final diastolicMax = data['diastolicMax'] as int;
  final recordCount = data['recordCount'] as int? ?? 0;
  final record = data['record'] as BloodPressureRecord?;

  final bool isRange = recordCount >= 2;
  final String sysText =
      isRange ? '$systolicMin~$systolicMax' : '$systolicMax';
  final String diaText =
      isRange ? '$diastolicMin~$diastolicMax' : '$diastolicMax';

  String headerText;
  if (selectedPeriod == '일') {
    if (record != null) {
      final d = record.measuredAt;
      headerText = '${d.hour}시 ${d.minute}분';
    } else {
      final slot = data['date']?.toString() ?? '';
      final h = int.tryParse(slot) ?? 0;
      headerText = '$h시 0분';
    }
  } else if (selectedPeriod == '주') {
    if (record != null) {
      final d = record.measuredAt;
      headerText = '${d.month}월 ${d.day}일';
    } else {
      headerText = data['date']?.toString() ?? '';
    }
  } else {
    final month = int.tryParse(data['date']?.toString() ?? '') ??
        selectedDate.month;
    headerText = '${selectedDate.year}년 $month월';
  }

  const double tooltipW = 88.0;
  const double tooltipH = 82.0;

  final calculatedTooltipPosition = ChartConstants.calculateTooltipPosition(
    tooltipAnchor,
    tooltipW,
    tooltipH,
    chartWidth,
    chartHeight,
  );

  final maxTooltipWidth = math.min(
    142.0,
    math.max(96.0, chartWidth - calculatedTooltipPosition.dx - 8),
  );

  return Transform.translate(
    offset: Offset(
      calculatedTooltipPosition.dx - tooltipAnchor.dx,
      calculatedTooltipPosition.dy - tooltipAnchor.dy,
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: 88,
        maxWidth: maxTooltipWidth,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              headerText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w400,
                fontFamily: 'Gmarket Sans TTF',
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: _valueRowWithBadge(
                badgeLabel: '수',
                badgeColor: const Color(0xFF85B0FF),
                value: sysText,
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: _valueRowWithBadge(
                badgeLabel: '이',
                badgeColor: const Color(0xFFFFBC71),
                value: diaText,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
