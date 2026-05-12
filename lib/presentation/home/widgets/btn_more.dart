import 'package:bomiora_app/presentation/health/health_common/health_responsive_scale.dart';
import 'package:flutter/material.dart';

/// Figma **375**: 칩 `47.11461 × 22`, `padding` 5, `borderRadius` 16, 내부 간격 2, 라벨 10sp · w500 · 흰색.
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
    final wChip = healthDp(context, 47.11461);
    final hChip = healthDp(context, 22);
    final pad = healthDp(context, 5);
    final radius = healthDp(context, 16);
    final innerGap = healthDp(context, 2);

    final chip = SizedBox(
      width: wChip,
      height: hChip,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: const Color(0xFFFF5A8D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: innerGap,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: healthSp(context, 10),
                    height: 1.0,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final tap = onTap;
    if (tap == null) return chip;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(radius),
        child: chip,
      ),
    );
  }
}
