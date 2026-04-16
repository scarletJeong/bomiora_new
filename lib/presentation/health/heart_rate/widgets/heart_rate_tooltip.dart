import 'package:flutter/material.dart';

const String _kHeartRateTooltipFont = 'Gmarket Sans TTF';

/// [heart_rate_period_chart.dart] 범례와 동일 색.
const Color heartRateTooltipDailyColor = Color(0xFF86B0FF);
const Color heartRateTooltipExerciseColor = Color(0xFFFF8686);

/// 혈압 차트 툴팁 [buildBloodPressureChartTooltip]과 동일 타이포·배지·카드·정렬.
/// 시간대별(일) 차트 툴팁에서도 동일 배지 UI로 재사용.
Widget heartRateTooltipValueRowWithBadge({
  required String badgeLabel,
  required Color badgeColor,
  required String value,
  TextStyle? valueStyle,
}) {
  return FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.center,
    child: Row(
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
                fontFamily: _kHeartRateTooltipFont,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          value,
          style: valueStyle ??
              const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontFamily: _kHeartRateTooltipFont,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    ),
  );
}

class HeartRateTooltip extends StatelessWidget {
  final Map<String, dynamic> data;
  final String selectedPeriod;
  final bool useCalendarYearMonths;
  final Offset? tooltipPosition;
  final double chartWidth;
  final double chartHeight;

  const HeartRateTooltip({
    super.key,
    required this.data,
    required this.selectedPeriod,
    required this.useCalendarYearMonths,
    required this.tooltipPosition,
    required this.chartWidth,
    required this.chartHeight,
  });

  TextStyle get _subHeaderStyle => TextStyle(
        color: Colors.grey[700],
        fontSize: 12,
        fontWeight: FontWeight.w400,
        fontFamily: _kHeartRateTooltipFont,
      );

  TextStyle get _headerStyle {
    if (selectedPeriod == '월' && useCalendarYearMonths) {
      return const TextStyle(
        color: Colors.black87,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        fontFamily: _kHeartRateTooltipFont,
      );
    }
    return _subHeaderStyle;
  }

  String _headerLine() {
    if (selectedPeriod == '주') {
      final d = data['slotDate'] as DateTime?;
      if (d != null) return '${d.month}월 ${d.day}일';
      return data['date']?.toString() ?? '';
    }
    if (selectedPeriod == '월' && useCalendarYearMonths) {
      final y = data['slotYear'] as int?;
      final m = data['slotMonth'] as int?;
      if (y != null && m != null) return '$y년 $m월';
    }
    return data['date']?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (tooltipPosition == null) return const SizedBox.shrink();

    final series = data['hrSeries'] as List<dynamic>?;
    if (series == null || series.isEmpty) {
      return const SizedBox.shrink();
    }

    Map<String, dynamic>? segExercise;
    Map<String, dynamic>? segDaily;
    for (final raw in series) {
      if (raw is! Map<String, dynamic>) continue;
      if (raw['exercise'] == true) {
        segExercise = raw;
      } else {
        segDaily = raw;
      }
    }

    final header = _headerLine();

    String rangeText(Map<String, dynamic> seg) {
      final kind = seg['kind'] as String?;
      if (kind == 'bar') {
        final a = seg['minBpm'] as int;
        final b = seg['maxBpm'] as int;
        return a == b ? '$a' : '$a ~ $b';
      }
      return '${seg['bpm']}';
    }

    final bodyChildren = <Widget>[];
    if (segDaily != null) {
      bodyChildren.add(
        Center(
          child: heartRateTooltipValueRowWithBadge(
            badgeLabel: '일',
            badgeColor: heartRateTooltipDailyColor,
            value: rangeText(segDaily),
          ),
        ),
      );
    }
    if (segDaily != null && segExercise != null) {
      bodyChildren.add(const SizedBox(height: 6));
    }
    if (segExercise != null) {
      bodyChildren.add(
        Center(
          child: heartRateTooltipValueRowWithBadge(
            badgeLabel: '운',
            badgeColor: heartRateTooltipExerciseColor,
            value: rangeText(segExercise),
          ),
        ),
      );
    }

    if (bodyChildren.isEmpty) return const SizedBox.shrink();

    const double tooltipH = 82.0;
    final estimatedHeight =
        tooltipH + (segDaily != null && segExercise != null ? 6.0 : 0.0);

    return _positionedCard(
      estimatedHeight: estimatedHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header.isNotEmpty)
            Text(
              header,
              textAlign: TextAlign.center,
              style: _headerStyle,
            ),
          if (header.isNotEmpty) const SizedBox(height: 8),
          ...bodyChildren,
        ],
      ),
    );
  }

  Widget _positionedCard({
    required Widget child,
    required double estimatedHeight,
  }) {
    const margin = 6.0;
    final bool isWeekly = selectedPeriod == '주';
    final minTooltipWidth = isWeekly ? 74.0 : 124.0;
    final minCardWidth = isWeekly ? 74.0 : 88.0;

    double tooltipX = tooltipPosition!.dx;
    double tooltipY = tooltipPosition!.dy - 60;

    if (tooltipX + minTooltipWidth + margin > chartWidth) {
      tooltipX = chartWidth - minTooltipWidth - margin;
    }
    if (tooltipX < margin) tooltipX = margin;

    var maxTooltipWidth = chartWidth - tooltipX - margin;
    maxTooltipWidth = maxTooltipWidth.clamp(minCardWidth, 240.0);

    if (tooltipY < 0) tooltipY = tooltipPosition!.dy + 20;
    if (tooltipY > chartHeight - estimatedHeight) {
      tooltipY = chartHeight - estimatedHeight;
    }

    return Positioned(
      left: tooltipX,
      top: tooltipY,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minCardWidth,
          maxWidth: maxTooltipWidth,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: child,
        ),
      ),
    );
  }
}
