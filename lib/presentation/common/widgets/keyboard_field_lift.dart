import 'package:flutter/material.dart';

/// 키보드가 열려도 페이지 높이는 줄이지 않는다.
/// 입력칸에 포커스가 가면, 그 칸이 키보드에 가려질 때만 스크롤을 올려 칸을 키보드 위로 둔다.
class KeyboardFieldLift extends StatefulWidget {
  const KeyboardFieldLift({super.key, required this.child});

  final Widget child;

  @override
  State<KeyboardFieldLift> createState() => _KeyboardFieldLiftState();
}

class _KeyboardLiftExtra {
  double bottom = 0;
}

class _KeyboardFieldLiftState extends State<KeyboardFieldLift>
    with WidgetsBindingObserver {
  final _KeyboardLiftExtra _extra = _KeyboardLiftExtra();
  int _liftGeneration = 0;
  ScrollPosition? _lastPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_scheduleLift);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_scheduleLift);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _scheduleLift();
  }

  void _scheduleLift() {
    final generation = ++_liftGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _liftGeneration) return;
      _liftFocusedField();
    });
  }

  void _liftFocusedField() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    final fieldContext = _editableContext(focusContext);
    final keyboard = _keyboardHeight(fieldContext ?? context);

    if (fieldContext == null || keyboard <= 0) {
      _extra.bottom = 0;
      _settleIfPastEnd();
      return;
    }

    final fieldBox = fieldContext.findRenderObject();
    if (fieldBox is! RenderBox || !fieldBox.attached || !fieldBox.hasSize) {
      return;
    }

    final scrollable = _pageScrollable(fieldContext);
    if (scrollable == null || !scrollable.position.hasPixels) return;

    final view = View.of(fieldContext);
    final dpr = view.devicePixelRatio;
    final screenHeight = view.physicalSize.height / dpr;
    const gap = 16.0;
    final visibleTop = view.padding.top / dpr + gap;
    final visibleBottom = screenHeight - keyboard - gap;

    final topLeft = fieldBox.localToGlobal(Offset.zero);
    final fieldTop = topLeft.dy;
    final fieldBottom = fieldTop + fieldBox.size.height;

    var delta = 0.0;
    if (fieldBottom > visibleBottom) {
      delta = fieldBottom - visibleBottom;
    }
    if (fieldTop - delta < visibleTop) {
      delta = fieldTop - visibleTop;
    }
    if (delta.abs() < 1) return;

    final position = scrollable.position;
    _extra.bottom = keyboard;
    _lastPosition = position;
    final max = position.maxScrollExtent + keyboard;
    final target = (position.pixels + delta).clamp(position.minScrollExtent, max);
    if ((target - position.pixels).abs() < 1) return;
    position.jumpTo(target);
  }

  void _settleIfPastEnd() {
    final position = _lastPosition;
    _lastPosition = null;
    if (position == null || !position.hasPixels) return;
    if (position.pixels <= position.maxScrollExtent) return;
    position.animateTo(
      position.maxScrollExtent,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  double _keyboardHeight(BuildContext context) {
    final view = View.maybeOf(context);
    if (view == null) return 0;
    final height = view.viewInsets.bottom / view.devicePixelRatio;
    if (!height.isFinite || height < 1) return 0;
    return height;
  }

  BuildContext? _editableContext(BuildContext? focusContext) {
    if (focusContext == null || !focusContext.mounted) return null;
    final state = focusContext.findAncestorStateOfType<EditableTextState>();
    final editableContext = state?.context;
    if (editableContext == null || !editableContext.mounted) return null;
    return editableContext;
  }

  /// 입력칸 안의 가로 스크롤은 건너뛰고, 페이지를 올리는 세로 스크롤만 고른다.
  ScrollableState? _pageScrollable(BuildContext fieldContext) {
    ScrollableState? current =
        fieldContext.findAncestorStateOfType<ScrollableState>();
    while (current != null) {
      if (current.position.axis == Axis.vertical) return current;
      current = current.context.findAncestorStateOfType<ScrollableState>();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: _KeyboardLiftScrollBehavior(_extra),
      child: widget.child,
    );
  }
}

class _KeyboardLiftScrollBehavior extends MaterialScrollBehavior {
  _KeyboardLiftScrollBehavior(this.extra);

  final _KeyboardLiftExtra extra;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return _KeyboardLiftScrollPhysics(
      extra: extra,
      parent: super.getScrollPhysics(context),
    );
  }
}

/// 본문이 짧아도 입력칸을 키보드 위로 올릴 수 있게, 키보드 높이만큼 더 스크롤되게 한다.
class _KeyboardLiftScrollPhysics extends ScrollPhysics {
  const _KeyboardLiftScrollPhysics({required this.extra, super.parent});

  final _KeyboardLiftExtra extra;

  @override
  _KeyboardLiftScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _KeyboardLiftScrollPhysics(extra: extra, parent: buildParent(ancestor));
  }

  double _max(ScrollMetrics position) => position.maxScrollExtent + extra.bottom;

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (position.axis != Axis.vertical || extra.bottom <= 0) {
      return super.applyBoundaryConditions(position, value);
    }
    final max = _max(position);
    if (value < position.pixels && position.pixels <= position.minScrollExtent) {
      return value - position.pixels;
    }
    if (max <= position.pixels && position.pixels < value) {
      return value - position.pixels;
    }
    if (value < position.minScrollExtent && position.minScrollExtent < position.pixels) {
      return value - position.minScrollExtent;
    }
    if (position.pixels < max && max < value) {
      return value - max;
    }
    return 0.0;
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if (position.axis != Axis.vertical || extra.bottom <= 0) {
      return super.createBallisticSimulation(position, velocity);
    }
    final max = _max(position);
    final tolerance = toleranceFor(position);
    if (position.pixels > max || position.pixels < position.minScrollExtent) {
      return super.createBallisticSimulation(position, velocity);
    }
    if (velocity.abs() < tolerance.velocity) return null;
    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      tolerance: tolerance,
    );
  }
}
