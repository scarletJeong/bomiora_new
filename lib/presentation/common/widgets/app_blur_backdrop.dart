import 'dart:ui';

import 'package:flutter/material.dart';

/// 검색 팝업과 동일한 딤 + 블러 배경.
/// 뒤 화면을 누르면 [onDismiss]가 호출됩니다.
class AppBlurBackdrop extends StatelessWidget {
  static const Color overlayColor = Color(0x331A1A1A);
  static const double blurSigma = 4;

  const AppBlurBackdrop({
    super.key,
    this.child,
    this.onDismiss,
    this.sigma = blurSigma,
    this.color = overlayColor,
  });

  final Widget? child;
  final VoidCallback? onDismiss;
  final double sigma;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: onDismiss,
          behavior: HitTestBehavior.opaque,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: ColoredBox(color: color),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}

/// 블러는 제자리에서 페이드되고, [child]만 [slideFrom]에서 들어옵니다.
Future<T?> showAppBlurSheet<T>({
  required BuildContext context,
  required Widget child,
  Alignment alignment = Alignment.bottomCenter,
  Offset slideFrom = const Offset(0, 1),
  Duration duration = const Duration(milliseconds: 280),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: duration,
    transitionBuilder: (context, animation, secondaryAnimation, dialogChild) {
      return dialogChild;
    },
    pageBuilder: (ctx, animation, secondaryAnimation) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
      final slide = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(
            opacity: fade,
            child: AppBlurBackdrop(
              onDismiss: () => Navigator.of(ctx).maybePop(),
            ),
          ),
          SlideTransition(
            position: Tween<Offset>(
              begin: slideFrom,
              end: Offset.zero,
            ).animate(slide),
            child: Align(alignment: alignment, child: child),
          ),
        ],
      );
    },
  );
}
