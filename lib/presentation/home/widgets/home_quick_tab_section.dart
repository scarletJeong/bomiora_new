import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_assets.dart';
import '../../health/health_common/health_responsive_scale.dart';

class HomeQuickTabSection extends StatelessWidget {
  const HomeQuickTabSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 20),
              vertical: healthDp(context, 14),
            ),
            child: Row(
              children: const [
                Expanded(
                  child: _QuickTabItem(
                    iconAsset: AppAssets.quickTabIcon1,
                    label: '비대면 진료',
                  ),
                ),
                _QuickDivider(),
                Expanded(
                  child: _QuickTabItem(
                    iconAsset: AppAssets.quickTabIcon2,
                    label: '문진표',
                  ),
                ),
                _QuickDivider(),
                Expanded(
                  child: _QuickTabItem(
                    iconAsset: AppAssets.quickTabIcon3,
                    label: '건강대시보드',
                  ),
                ),
                _QuickDivider(),
                Expanded(
                  child: _QuickTabItem(
                    iconAsset: AppAssets.quickTabIcon4,
                    label: '스토어',
                  ),
                ),
              ],
            ),
          ),
          // 가로선: 가운데 직선, 좌·우 끝만 살짝 위로 말림
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: healthDp(context, 20)),
            child: SizedBox(
              height: healthDp(context, 8),
              width: double.infinity,
              child: CustomPaint(
                painter: _QuickTabBottomCurvePainter(
                  color: const Color(0xFFFF5A8D),
                  strokeWidth: healthDp(context, 1),
                  endLift: healthDp(context, 2.2),
                  capLength: healthDp(context, 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTabItem extends StatelessWidget {
  final String iconAsset;
  final String label;

  const _QuickTabItem({
    required this.iconAsset,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: healthDp(context, 24),
          height: healthDp(context, 24),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  iconAsset,
                  width: healthDp(context, 22),
                  height: healthDp(context, 22),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: healthDp(context, 6)),
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF666666),
            fontSize: healthSp(context, 10),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _QuickDivider extends StatelessWidget {
  const _QuickDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: healthDp(context, 1),
      height: healthDp(context, 26),
      color: const Color(0xFFE5E5E5),
    );
  }
}

/// 하단 핑크 라인: **가운데 수평 직선**, 좌·우 [capLength] 구간만 [endLift]만큼 위로 말림.
class _QuickTabBottomCurvePainter extends CustomPainter {
  _QuickTabBottomCurvePainter({
    required this.color,
    required this.strokeWidth,
    required this.endLift,
    required this.capLength,
  });

  final Color color;
  final double strokeWidth;
  final double endLift;
  final double capLength;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final midY = size.height * 0.5;
    final yBase = midY;
    final yTip = midY - endLift;
    final cap = capLength.clamp(6.0, w * 0.42);

    final path = Path()
      ..moveTo(0, yTip)
      ..cubicTo(
        cap * 0.35,
        yTip,
        cap * 0.92,
        yBase,
        cap,
        yBase,
      )
      ..lineTo(w - cap, yBase)
      ..cubicTo(
        w - cap * 0.92,
        yBase,
        w - cap * 0.35,
        yTip,
        w,
        yTip,
      );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _QuickTabBottomCurvePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.endLift != endLift ||
        oldDelegate.capLength != capLength;
  }
}
