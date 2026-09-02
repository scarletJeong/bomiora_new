import 'package:flutter/material.dart';

import '../../health_common/health_responsive_scale.dart';

const String _kHeartRateTooltipFont = 'Gmarket Sans TTF';

/// [heart_rate_period_chart.dart] 범례와 동일 색.
const Color heartRateTooltipDailyColor = Color(0xFF86B0FF);
const Color heartRateTooltipExerciseColor = Color(0xFFFF8686);

/// 혈압 차트 툴팁 [buildBloodPressureChartTooltip]과 동일 타이포·배지·카드·정렬.
/// 시간대별(일) 차트 툴팁에서도 동일 배지 UI로 재사용.
Widget heartRateTooltipValueRowWithBadge({
  required BuildContext context,
  required String badgeLabel,
  required Color badgeColor,
  required String value,
  TextStyle? valueStyle,
  /// null이면 상위 [MediaQuery.textScaler] (목록·툴팁에서 이중 스케일 방지 시 [TextScaler.noScaling]).
  TextScaler? valueTextScaler,
}) {
  return FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.center,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: healthDp(context, 16),
          padding: EdgeInsets.symmetric(vertical: healthDp(context, 2)),
          decoration: ShapeDecoration(
            color: badgeColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(healthDp(context, 19)),
            ),
          ),
          child: Center(
            child: Text(
              badgeLabel,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: Colors.white,
                fontSize: healthSp(context, 10),
                fontFamily: _kHeartRateTooltipFont,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        SizedBox(width: healthDp(context, 5)),
        Text(
          value,
          textScaler: valueTextScaler ?? TextScaler.noScaling,
          style: valueStyle ??
              TextStyle(
                color: Colors.black87,
                fontSize: healthSp(context, 14),
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

  TextStyle _subHeaderStyle(BuildContext context) => TextStyle(
        color: Colors.grey[700],
        fontSize: healthSp(context, 12),
        fontWeight: FontWeight.w400,
        fontFamily: _kHeartRateTooltipFont,
      );

  TextStyle _headerStyle(BuildContext context) {
    if (selectedPeriod == '월' && useCalendarYearMonths) {
      return TextStyle(
        color: Colors.black87,
        fontSize: healthSp(context, 12),
        fontWeight: FontWeight.w400,
        fontFamily: _kHeartRateTooltipFont,
      );
    }
    return _subHeaderStyle(context);
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
            context: context,
            badgeLabel: '일',
            badgeColor: heartRateTooltipDailyColor,
            value: rangeText(segDaily),
          ),
        ),
      );
    }
    if (segDaily != null && segExercise != null) {
      bodyChildren.add(SizedBox(height: healthDp(context, 6)));
    }
    if (segExercise != null) {
      bodyChildren.add(
        Center(
          child: heartRateTooltipValueRowWithBadge(
            context: context,
            badgeLabel: '운',
            badgeColor: heartRateTooltipExerciseColor,
            value: rangeText(segExercise),
          ),
        ),
      );
    }

    if (bodyChildren.isEmpty) return const SizedBox.shrink();

    final double tooltipH = healthDp(context, 82);
    final estimatedHeight =
        tooltipH + (segDaily != null && segExercise != null ? healthDp(context, 6) : 0.0);

    return _positionedCard(
      context: context,
      estimatedHeight: estimatedHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header.isNotEmpty)
            Text(
              header,
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: _headerStyle(context),
            ),
          if (header.isNotEmpty) SizedBox(height: healthDp(context, 8)),
          ...bodyChildren,
        ],
      ),
    );
  }

  Widget _positionedCard({
    required BuildContext context,
    required Widget child,
    required double estimatedHeight,
  }) {
    final margin = healthDp(context, 6);
    final bool isWeekly = selectedPeriod == '주';
    final minTooltipWidth = healthDp(context, isWeekly ? 74 : 124);
    final minCardWidth = healthDp(context, isWeekly ? 74 : 88);

    double tooltipX = tooltipPosition!.dx;
    double tooltipY = tooltipPosition!.dy - healthDp(context, 60);

    if (tooltipX + minTooltipWidth + margin > chartWidth) {
      tooltipX = chartWidth - minTooltipWidth - margin;
    }
    if (tooltipX < margin) tooltipX = margin;

    var maxTooltipWidth = chartWidth - tooltipX - margin;
    maxTooltipWidth = maxTooltipWidth.clamp(minCardWidth, healthDp(context, 240));

    if (tooltipY < 0) tooltipY = tooltipPosition!.dy + healthDp(context, 20);
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
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 8),
            vertical: healthDp(context, 7),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: child,
        ),
      ),
    );
  }
}
