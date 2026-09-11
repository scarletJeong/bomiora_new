import 'package:flutter/material.dart';

/// 회색 스플래시/하이라이트 없이 탭하고, 웹에서는 손 모양 커서를 씁니다.
class AppClickable extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final HitTestBehavior behavior;

  const AppClickable({
    super.key,
    required this.onTap,
    required this.child,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: behavior,
        child: child,
      ),
    );
  }
}
