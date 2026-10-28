import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:bomiora_app/core/utils/web_keyboard_inset.dart';

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

  /// 입력칸에 포커스가 있는 동안에는 칸을 화면 아래로 되돌리지 않는다.
  bool hold = false;
}

class _KeyboardFieldLiftState extends State<KeyboardFieldLift>
    with WidgetsBindingObserver {
  final _KeyboardLiftExtra _extra = _KeyboardLiftExtra();
  int _liftGeneration = 0;
  int _focusGeneration = 0;
  bool _liftQueued = false;
  Timer? _zeroInsetTimer;
  ScrollPosition? _lastPosition;
  double _latchedKeyboard = 0;
  late final void Function() _unsubscribeWebKeyboard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_onFocusChanged);
    _unsubscribeWebKeyboard = subscribeWebKeyboardOverlap(_scheduleLift);
  }

  @override
  void dispose() {
    _zeroInsetTimer?.cancel();
    _unsubscribeWebKeyboard();
    FocusManager.instance.removeListener(_onFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _scheduleLift();
  }

  void _onFocusChanged() {
    final field = _editableContext(FocusManager.instance.primaryFocus?.context);
    if (field != null || webEditingElementFocused()) {
      _extra.hold = true;
    }
    final generation = ++_focusGeneration;
    _scheduleLift();
    for (final delay in const [80, 240, 520]) {
      Future<void>.delayed(Duration(milliseconds: delay), () {
        if (!mounted || generation != _focusGeneration) return;
        _liftFocusedField();
      });
    }
  }

  void _scheduleLift() {
    if (_liftQueued) return;
    _liftQueued = true;
    final generation = ++_liftGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _liftQueued = false;
      if (!mounted || generation != _liftGeneration) return;
      _liftFocusedField();
    });
  }

  void _liftFocusedField() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    final fieldContext = _editableContext(focusContext);
    final editing = fieldContext != null || webEditingElementFocused();
    final measured = _keyboardHeight(fieldContext ?? context);
    if (measured > _latchedKeyboard) _latchedKeyboard = measured;
    final keyboard = measured > 0
        ? measured
        : (editing ? _latchedKeyboard : 0.0);

    if (!editing) {
      _zeroInsetTimer?.cancel();
      _zeroInsetTimer = null;
      _latchedKeyboard = 0;
      _extra
        ..hold = false
        ..bottom = 0;
      setWebInputScrollLock(false);
      _settleIfPastEnd();
      return;
    }

    _extra.hold = true;
    if (keyboard > 0) {
      _extra.bottom = math.max(_extra.bottom, keyboard);
      setWebInputScrollLock(true);
    }
    if (keyboard <= 0 || fieldContext == null) {
      return;
    }
    _zeroInsetTimer?.cancel();
    _zeroInsetTimer = null;

    final fieldRender = fieldContext.findRenderObject();
    if (fieldRender is! RenderBox ||
        !fieldRender.attached ||
        !fieldRender.hasSize) {
      return;
    }
    final fieldBox = _revealBox(fieldContext, fieldRender);

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

    // 키보드가 열린 뒤에는 칸을 아래로 내리지 않는다.
    // 글자를 치면 입력칸을 화면 맨 아래로 되돌리는데, 그 자리가 키보드 아래다.
    var delta = 0.0;
    if (fieldBottom > visibleBottom) {
      delta = fieldBottom - visibleBottom;
    }
    final roomAbove = fieldTop - visibleTop;
    if (roomAbove < delta) delta = math.max(0, roomAbove);
    // 글자 입력마다 1~2px 다시 맞추면 화면이 깜빡인다. 가려진 만큼만 올린다.
    if (delta < 12) return;

    final position = scrollable.position;
    final slack = math.max(keyboard + gap, delta);
    _extra.bottom = slack;
    _lastPosition = position;
    final max = position.maxScrollExtent + slack;
    final target =
        (position.pixels + delta).clamp(position.minScrollExtent, max);
    if ((target - position.pixels).abs() < 12) return;
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
    var height = 0.0;
    if (view != null) {
      final inset = view.viewInsets.bottom / view.devicePixelRatio;
      if (inset.isFinite && inset > height) height = inset;
    }
    final web = currentWebKeyboardOverlap().bottom;
    if (web > height) height = web;
    if (height < 1) return 0;
    return height;
  }

  BuildContext? _editableContext(BuildContext? focusContext) {
    if (focusContext == null || !focusContext.mounted) return null;
    EditableTextState? state;
    if (focusContext is StatefulElement &&
        focusContext.state is EditableTextState) {
      state = focusContext.state as EditableTextState;
    } else {
      state = focusContext.findAncestorStateOfType<EditableTextState>();
    }
    final editableContext = state?.context;
    if (editableContext == null || !editableContext.mounted) return null;
    return editableContext;
  }

  /// 글자 칸만이 아니라, 그 글자를 감싼 입력 상자까지 키보드 위로 올린다.
  RenderBox _revealBox(BuildContext start, RenderBox fallback) {
    var best = fallback;
    start.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        return false;
      }
      final render = element.renderObject;
      if (render is RenderBox && render.attached && render.hasSize) {
        final height = render.size.height;
        if (height + 0.5 >= best.size.height && height <= 160) {
          best = render;
        }
        if (height > 280) return false;
      }
      return true;
    });
    return best;
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

  /// 글자를 치는 동안 입력칸을 화면 맨 아래(키보드 밑)로 되돌리지 않는다.
  @override
  bool get allowImplicitScrolling => !extra.hold;

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
