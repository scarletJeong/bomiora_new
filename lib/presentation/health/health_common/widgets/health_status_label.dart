import 'package:flutter/material.dart';

/// 혈당/혈압 등 건강 기록의 상태 칩 (정상, 주의, 고혈압, 의심, 모름, 전단계)
class HealthStatusLabel extends StatelessWidget {
  final String label;
  final double fontSize;

  static const Map<String, Color> _textColors = {
    '정상': Colors.white,
    '주의': Colors.white,
    '고혈압': Colors.white,
    '의심': Colors.white,
    '모름': Colors.white,
    '전단계': Colors.white,
  };

  /// 흰 글씨 상태는 칩 배경이 필요함
  static const Map<String, Color> _backgroundColors = {
    '정상': Color(0xFF71D375),
    '주의': Color(0xFFFFE78B),
    '고혈압': Color(0xFFFF6161),
    '의심': Color(0xFFFF6161),
    '모름': Color(0xFFEBECED),
    '전단계': Color(0xFFFEAF8E),
  };

  const HealthStatusLabel({
    super.key,
    required this.label,
    this.fontSize = 10,
  });

  Color get _textColor => _textColors[label] ?? const Color(0xFF666E75);
  Color get _backgroundColor =>
      _backgroundColors[label] ?? const Color(0xFFEEEEEE);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
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
