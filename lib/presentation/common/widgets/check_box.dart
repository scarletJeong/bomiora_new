import 'package:flutter/material.dart';

import 'app_clickable.dart';

/// 공통 체크박스. 체크 여부에 따라 20×20 박스 안에 16 체크가 보입니다.
class CheckBox extends StatelessWidget {
  const CheckBox({
    super.key,
    required this.value,
    this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const double _size = 20;
  static const double _iconSize = 16;
  static const Color _border = Color(0xFFD2D2D2);
  static const Color _check = Color(0xFFFF5A8D);

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: _size,
      height: _size,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(
            width: 1,
            color: _border,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      child: value
          ? const Center(
              child: SizedBox(
                width: _iconSize,
                height: _iconSize,
                child: CustomPaint(
                  painter: _CheckBoxTickPainter(color: _check),
                ),
              ),
            )
          : null,
    );

    if (onChanged == null) return box;

    return AppClickable(
      onTap: () => onChanged!(!value),
      child: box,
    );
  }
}

class _CheckBoxTickPainter extends CustomPainter {
  const _CheckBoxTickPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.52)
      ..lineTo(size.width * 0.40, size.height * 0.74)
      ..lineTo(size.width * 0.82, size.height * 0.26);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckBoxTickPainter oldDelegate) =>
      oldDelegate.color != color;
}
