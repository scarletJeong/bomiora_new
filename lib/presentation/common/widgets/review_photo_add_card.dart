import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../health/health_common/health_responsive_scale.dart';

/// 리뷰·문의 사진 추가 칸. 점선 테두리, 375 기준 76.
class ReviewPhotoAddCard extends StatelessWidget {
  const ReviewPhotoAddCard({
    super.key,
    this.label = '사진추가하기',
  });

  final String label;

  static const String _font = 'Gmarket Sans TTF';

  @override
  Widget build(BuildContext context) {
    final size = healthDp(context, 76);
    final radius = healthDp(context, 8);
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: const Color(0xFFD2D2D2),
        radius: radius,
        strokeWidth: healthDp(context, 1),
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              AppAssets.addPhotoIcon,
              width: healthDp(context, 28),
              height: healthDp(context, 28),
              fit: BoxFit.contain,
            ),
            SizedBox(height: healthDp(context, 4)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: healthDp(context, 4)),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF898986),
                  fontSize: healthSp(context, 10),
                  fontFamily: _font,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    const dash = 4.0;
    const gap = 3.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
