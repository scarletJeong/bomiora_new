import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BloodSugarTooltip extends StatelessWidget {
  final Map<String, dynamic> data;
  final Offset? tooltipPosition;
  final double chartWidth;
  final double chartHeight;

  const BloodSugarTooltip({
    super.key,
    required this.data,
    required this.tooltipPosition,
    required this.chartWidth,
    required this.chartHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (tooltipPosition == null) return const SizedBox.shrink();

    final bloodSugar = data['bloodSugar'];
    if (bloodSugar == null) return const SizedBox.shrink();

    String timeLabel = data['date']?.toString() ?? '';
    final record = data['record'];
    if (record != null) {
      try {
        final measuredAt = record.measuredAt;
        if (measuredAt is DateTime) {
          timeLabel = DateFormat('HH:mm').format(measuredAt);
        } else {
          final parsed = DateTime.tryParse(measuredAt.toString());
          if (parsed != null) {
            timeLabel = DateFormat('HH:mm').format(parsed);
          }
        }
      } catch (_) {}
    }

    double tooltipX = tooltipPosition!.dx;
    double tooltipY = tooltipPosition!.dy - 60;

    if (tooltipX < 0) tooltipX = 0;
    if (tooltipX > chartWidth - 100) tooltipX = chartWidth - 100;
    if (tooltipY < 0) tooltipY = tooltipPosition!.dy + 20;
    if (tooltipY > chartHeight - 50) tooltipY = chartHeight - 50;

    return Positioned(
      left: tooltipX,
      top: tooltipY,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$bloodSugar mg/dL',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              timeLabel,
              style: TextStyle(color: Colors.grey[300], fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
