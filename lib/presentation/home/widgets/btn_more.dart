import 'package:flutter/material.dart';

import '../../common/responsive_scale.dart';
import '../../health/health_common/health_responsive_scale.dart';

/// Figma 375: `padding` 5, `borderRadius` 16, 라벨 `More` (10pt · w500 · 흰색).
class BtnMore extends StatelessWidget {
  const BtnMore({
    super.key,
    this.onTap,
    this.label = '+More',
  });

  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final pad = lerpByWidth375_650(width: w, v375: 5, v650: 6);
    final radius = lerpByWidth375_650(width: w, v375: 16, v650: 20);

    final chip = Container(
      padding: EdgeInsets.all(pad),
      decoration: ShapeDecoration(
        color: const Color(0xFFFF5A8D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: lerpByWidth375_650(width: w, v375: 2, v650: 2),
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: healthSp(context, 10),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    final tap = onTap;
    if (tap == null) return chip;
    return InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(radius),
      child: chip,
    );
  }
}
