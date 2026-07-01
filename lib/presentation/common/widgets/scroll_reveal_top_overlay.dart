import 'package:flutter/material.dart';

/// 스크롤을 위로 올리면 상단에 [topBar]를 표시하고, 아래로 내리면 숨깁니다.
/// [scrollChild]는 [ScrollController]가 연결된 스크롤 위젯이어야 합니다.
class ScrollRevealTopOverlay extends StatefulWidget {
  final ScrollController controller;
  final Widget scrollChild;
  final Widget topBar;
  final double revealAfterOffset;
  final EdgeInsetsGeometry? barPadding;

  const ScrollRevealTopOverlay({
    super.key,
    required this.controller,
    required this.scrollChild,
    required this.topBar,
    this.revealAfterOffset = 48,
    this.barPadding,
  });

  @override
  State<ScrollRevealTopOverlay> createState() => _ScrollRevealTopOverlayState();
}

class _ScrollRevealTopOverlayState extends State<ScrollRevealTopOverlay> {
  bool _visible = false;
  double _lastOffset = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ScrollRevealTopOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
      _lastOffset = widget.controller.hasClients ? widget.controller.offset : 0;
      _visible = false;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;

    final offset = widget.controller.offset;
    final delta = offset - _lastOffset;
    var next = _visible;

    if (offset <= widget.revealAfterOffset) {
      next = false;
    } else if (delta < -4) {
      next = true;
    } else if (delta > 4) {
      next = false;
    }

    _lastOffset = offset;
    if (next != _visible && mounted) {
      setState(() => _visible = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.scrollChild,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !_visible,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              offset: _visible ? Offset.zero : const Offset(0, -1),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _visible ? 1 : 0,
                child: Material(
                  color: Colors.white,
                  elevation: _visible ? 2 : 0,
                  child: Padding(
                    padding: widget.barPadding ?? EdgeInsets.zero,
                    child: widget.topBar,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
