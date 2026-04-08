import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const String _kStepsTooltipFont = 'Gmarket Sans TTF';

Widget stepsTooltipValueText({
  required String value,
  TextStyle? style,
}) {
  return FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.center,
    child: Text(
      value,
      style: style ??
          const TextStyle(
            color: Colors.black87,
            fontSize: 14,
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

  TextStyle get _headerStyle => TextStyle(
        color: Colors.grey[700],
        fontSize: 12,
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
      estimatedHeight: header.isNotEmpty ? 82 : 60,
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
          Center(
            child: stepsTooltipValueText(value: '${fmt.format(stepsInt)} 보'),
          ),
        ],
      ),
    );
  }

  Widget _positionedCard({
    required Widget child,
    required double estimatedHeight,
  }) {
    const margin = 6.0;
    const minTooltipWidth = 72.0;

    double tooltipX = tooltipPosition!.dx;
    double tooltipY = tooltipPosition!.dy - 60;

    if (tooltipX + minTooltipWidth + margin > chartWidth) {
      tooltipX = chartWidth - minTooltipWidth - margin;
    }
    if (tooltipX < margin) tooltipX = margin;

    var maxTooltipWidth = chartWidth - tooltipX - margin;
    maxTooltipWidth = maxTooltipWidth.clamp(88.0, 240.0);

    if (tooltipY < 0) tooltipY = tooltipPosition!.dy + 20;
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

