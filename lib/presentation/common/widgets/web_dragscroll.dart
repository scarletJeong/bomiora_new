import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// 웹에서만: 마우스 드래그로 스크롤 가능하게 하는 ScrollConfiguration 래퍼.
class WebDragScrollConfiguration extends StatelessWidget {
  const WebDragScrollConfiguration({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    final base = ScrollConfiguration.of(context);
    // 웹 기본 dragDevices에 mouse가 빠져 있으면 가로 리스트를 드래그로 못 밈.
    return ScrollConfiguration(
      behavior: base.copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.unknown,
        },
      ),
      child: child,
    );
  }
}

