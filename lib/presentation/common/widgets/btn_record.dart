import 'package:flutter/material.dart';

import 'package:bomiora_app/presentation/health/health_common/health_responsive_scale.dart';

class BtnRecord extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final double? elevation;
  final bool isLoading;
  /// null이면 [healthSp] 16 + Gmarket 미적용 기본. 화면에서 [TextStyle] 넘길 때 사용.
  final TextStyle? textStyle;
  /// null이면 [TextScaler.noScaling] — [healthSp]와 이중 스케일 방지. 시스템 스케일 쓰려면 명시 전달.
  final TextScaler? labelTextScaler;
  /// null이면 375 기준 40 ([healthDp]).
  final double? minimumHeight;

  const BtnRecord({
    super.key,
    this.text = '+ 기록하기',
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.padding,
    this.borderRadius,
    this.elevation,
    this.isLoading = false,
    this.textStyle,
    this.labelTextScaler,
    this.minimumHeight,
  });

  @override
  Widget build(BuildContext context) {
    final minH = minimumHeight ?? healthDp(context, 40);
    final defaultPad = EdgeInsets.symmetric(vertical: healthDp(context, 13));
    final defaultRadius = healthDp(context, 12);
    final effectiveTextScaler = labelTextScaler ?? TextScaler.noScaling;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? const Color(0xFFFF5A8D),
          foregroundColor: textColor ?? Colors.white,
          padding: padding ?? defaultPad,
          minimumSize: Size(0, minH),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              borderRadius ?? defaultRadius,
            ),
          ),
          elevation: elevation ?? 0,
        ),
        child: isLoading
            ? SizedBox(
                height: healthDp(context, 20),
                width: healthDp(context, 20),
                child: CircularProgressIndicator(
                  strokeWidth: healthDp(context, 2),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                text,
                textScaler: effectiveTextScaler,
                style: textStyle ??
                    TextStyle(
                      fontSize: healthSp(context, 16),
                      fontWeight: FontWeight.w500,
                    ),
              ),
      ),
    );
  }
}
