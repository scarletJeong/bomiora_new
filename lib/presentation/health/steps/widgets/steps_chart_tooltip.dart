import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../health_common/health_responsive_scale.dart';

const String _kStepsTooltipFont = 'Gmarket Sans TTF';

Widget stepsTooltipValueText({
  required BuildContext context,
  required String value,
  TextStyle? style,
}) {
  return FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.center,
    child: Text(
      value,
      textScaler: TextScaler.noScaling,
      style: style ??
          TextStyle(
            color: Colors.black87,
            fontSize: healthSp(context, 14),
            fontFamily: _kStepsTooltipFont,
            fontWeight: FontWeight.w700,
          ),
    ),
  );
}

class StepsChartTooltip extends StatelessWidget {
  final Map<String, dynamic> data;
  final String selectedPeriod;
  final Offset? tooltipPosition;
  final double chartWidth;
  final double chartHeight;

  const StepsChartTooltip({
    super.key,
    required this.data,
    required this.selectedPeriod,
    required this.tooltipPosition,
    required this.chartWidth,
    required this.chartHeight,
  });

  TextStyle _headerStyle(BuildContext context) => TextStyle(
        color: Colors.grey[700],
        fontSize: healthSp(context, 12),
        fontWeight: FontWeight.w400,
        fontFamily: _kStepsTooltipFont,
      );

  String _headerLine() {
    if (selectedPeriod == '일') {
      final h = data['slotHour'] as int?;
      final m = data['slotMinute'] as int?;
      if (h != null && m != null) return '$h시 ${m.toString().padLeft(2, '0')}분';
      return '';
    }
    if (selectedPeriod == '주') {
      final d = data['slotDate'] as DateTime?;
      if (d != null) return '${d.month}월 ${d.day}일';
      return '';
    }
    if (selectedPeriod == '월') {
      final y = data['slotYear'] as int?;
      final m = data['slotMonth'] as int?;
      if (y != null && m != null) return '$y년 $m월';
      return '';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (tooltipPosition == null) return const SizedBox.shrink();
    if (data.isEmpty) return const SizedBox.shrink();

    final steps = data['steps'];
    final int stepsInt =
        steps is num ? steps.round() : int.tryParse(steps?.toString() ?? '') ?? 0;

    final header = _headerLine();
    final fmt = NumberFormat('#,###');

    return _positionedCard(
      context: context,
      estimatedHeight: header.isNotEmpty ? healthDp(context, 82) : healthDp(context, 60),
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
          Center(
            child: stepsTooltipValueText(
              context: context,
              value: '${fmt.format(stepsInt)} 보',
            ),
          ),
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
    final minTooltipWidth = healthDp(context, 72);

    double tooltipX = tooltipPosition!.dx;
    double tooltipY = tooltipPosition!.dy - healthDp(context, 60);

    if (tooltipX + minTooltipWidth + margin > chartWidth) {
      tooltipX = chartWidth - minTooltipWidth - margin;
    }
    if (tooltipX < margin) tooltipX = margin;

    var maxTooltipWidth = chartWidth - tooltipX - margin;
    maxTooltipWidth = maxTooltipWidth.clamp(
      healthDp(context, 88),
      healthDp(context, 240),
    );

    if (tooltipY < 0) tooltipY = tooltipPosition!.dy + healthDp(context, 20);
    if (tooltipY > chartHeight - estimatedHeight) {
      tooltipY = chartHeight - estimatedHeight;
    }

    return Positioned(
      left: tooltipX,
      top: tooltipY,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxTooltipWidth),
        child: IntrinsicWidth(
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
      ),
    );
  }
}
