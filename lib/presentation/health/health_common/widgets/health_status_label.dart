import 'package:flutter/material.dart';

import '../health_responsive_scale.dart';
import '../health_vital_status.dart';

/// 혈당/혈압 등 건강 기록의 상태 칩. 색은 [HealthVitalStatus]와 같다.
class HealthStatusLabel extends StatelessWidget {
  final String label;
  final double fontSize;

  final double? chipBorderRadius;
  final EdgeInsetsGeometry? chipPadding;

  const HealthStatusLabel({
    super.key,
    required this.label,
    this.fontSize = 10,
    this.chipBorderRadius,
    this.chipPadding,
  });

  Color get _textColor => HealthVitalStatus.foreground(label);
  Color get _backgroundColor => HealthVitalStatus.background(label);

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = chipBorderRadius != null
        ? BorderRadius.circular(chipBorderRadius!)
        : BorderRadius.circular(999);
    return Container(
      padding: chipPadding ??
          EdgeInsets.symmetric(
            horizontal: healthDp(context, 8),
            vertical: healthDp(context, 4),
          ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: radius,
      ),
      child: Text(
        label,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: _textColor,
          fontSize: fontSize,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
