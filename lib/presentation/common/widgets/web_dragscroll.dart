import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// 웹에서만: 마우스 드래그로 스크롤 가능하게 하는 ScrollConfiguration 래퍼.
///
/// [controller]가 있으면 그 가로 스크롤에 마우스 휠도 연결한다.
/// 목록이 더 움직일 수 있을 때만 휠을 가로채고, 끝에서는 페이지 스크롤에 넘긴다.
class WebDragScrollConfiguration extends StatelessWidget {
  const WebDragScrollConfiguration({
    super.key,
    required this.child,
    this.controller,
  });

  final Widget child;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    Widget current = child;
    final scrollController = controller;
    if (kIsWeb && scrollController != null) {
      current = _WebWheelToHorizontal(
        controller: scrollController,
        child: current,
      );
    }
    if (!kIsWeb) return current;

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
      child: current,
    );
  }
}

/// 가로 목록마다 [ScrollController]를 만들어 웹 휠·드래그에 연결한다.
class WebHorizontalScrollHost extends StatefulWidget {
  const WebHorizontalScrollHost({super.key, required this.builder});

  final Widget Function(BuildContext context, ScrollController controller)
      builder;

  @override
  State<WebHorizontalScrollHost> createState() => _WebHorizontalScrollHostState();
}

class _WebHorizontalScrollHostState extends State<WebHorizontalScrollHost> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WebDragScrollConfiguration(
      controller: _controller,
      child: widget.builder(context, _controller),
    );
  }
}

class _WebWheelToHorizontal extends StatelessWidget {
  const _WebWheelToHorizontal({
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        if (!controller.hasClients) return;
        final position = controller.position;
        if (!position.hasContentDimensions) return;
        final dx = event.scrollDelta.dx;
        final dy = event.scrollDelta.dy;
        final delta = dx.abs() >= dy.abs() ? dx : dy;
        if (delta == 0) return;
        final target = (position.pixels + delta).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        if (target == position.pixels) return;
        GestureBinding.instance.pointerSignalResolver.register(event, (_) {
          if (!controller.hasClients) return;
          final current = controller.position;
          if (!current.hasContentDimensions) return;
          current.pointerScroll(delta);
        });
      },
      child: child,
    );
  }
}

