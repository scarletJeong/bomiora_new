import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:bomiora_app/core/utils/web_keyboard_inset.dart';

/// 모바일 웹 키보드 위 자동완성 바. visualViewport 높이에는 안 잡힌다.
const double _kWebAccessoryBar = 56;

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
  Timer? _releaseTimer;
  ScrollPosition? _lastPosition;
  double _latchedKeyboard = 0;
  double? _pinnedPixels;
  bool _restoringPin = false;
  late final void Function() _unsubscribeWebKeyboard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_onFocusChanged);
    ensureWebKeyboardOverlayMode();
    _unsubscribeWebKeyboard = subscribeWebKeyboardOverlap(_scheduleLift);
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    _detachPinnedPosition();
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
      setWebInputScrollLock(true);
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
      _releaseTimer ??= Timer(const Duration(milliseconds: 400), () {
        _releaseTimer = null;
        if (!mounted) return;
        final stillEditing = _editableContext(
                  FocusManager.instance.primaryFocus?.context,
                ) !=
                null ||
            webEditingElementFocused();
        if (stillEditing) return;
        _latchedKeyboard = 0;
        _pinnedPixels = null;
        _extra
          ..hold = false
          ..bottom = 0;
        setWebInputScrollLock(false);
        _settleIfPastEnd();
      });
      return;
    }
    _releaseTimer?.cancel();
    _releaseTimer = null;

    _extra.hold = true;
    setWebInputScrollLock(true);
    if (keyboard > 0) {
      _extra.bottom = math.max(
        _extra.bottom,
        keyboard + (kIsWeb ? _kWebAccessoryBar : 0),
      );
    }
    if (keyboard <= 0 || fieldContext == null) {
      return;
    }

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
    const accessory = kIsWeb ? _kWebAccessoryBar : 0.0;
    final visibleTop = view.padding.top / dpr + gap;
    final overlap = currentWebKeyboardOverlap();
    // Flutter 좌표는 레이아웃 화면. 브라우저가 민 화면(visibleTop)과 섞지 않는다.
    // 글자 입력 때 칸을 키보드에 붙이는 쪽은 web_keyboard_inset_web 에서 되돌린다.
    final viewBottom = overlap.visibleHeight > 1
        ? overlap.visibleHeight
        : screenHeight - keyboard;
    final visibleBottom = viewBottom - gap - accessory;

    final topLeft = fieldBox.localToGlobal(Offset.zero);
    final fieldTop = topLeft.dy;
    final fieldBottom = fieldTop + fieldBox.size.height;

    var delta = 0.0;
    if (fieldBottom > visibleBottom) {
      delta = fieldBottom - visibleBottom;
    }
    final roomAbove = fieldTop - visibleTop;
    if (roomAbove < delta) delta = math.max(0, roomAbove);

    final position = scrollable.position;
    _attachPinnedPosition(position);

    if (delta < 16) {
      _pinnedPixels = position.pixels;
      return;
    }

    final slack = math.max(keyboard + gap + accessory, delta);
    _extra.bottom = slack;
    _lastPosition = position;
    final max = position.maxScrollExtent + slack;
    final target =
        (position.pixels + delta).clamp(position.minScrollExtent, max);
    if ((target - position.pixels).abs() < 16) {
      _pinnedPixels = position.pixels;
      return;
    }
    position.jumpTo(target);
    _pinnedPixels = target;
  }

  void _attachPinnedPosition(ScrollPosition position) {
    if (_lastPosition == position) return;
    _detachPinnedPosition();
    _lastPosition = position;
    position.addListener(_restorePinnedPixels);
  }

  void _detachPinnedPosition() {
    _lastPosition?.removeListener(_restorePinnedPixels);
  }

  void _clearPinnedPosition() {
    _detachPinnedPosition();
    _lastPosition = null;
  }

  void _restorePinnedPixels() {
    if (_restoringPin || !_extra.hold) return;
    final position = _lastPosition;
    final pinned = _pinnedPixels;
    if (position == null || pinned == null || !position.hasPixels) return;
    if (position.pixels >= pinned - 0.5) {
      if (position.pixels > pinned + 0.5) {
        _pinnedPixels = position.pixels;
      }
      return;
    }
    _restoringPin = true;
    try {
      position.jumpTo(pinned);
    } finally {
      _restoringPin = false;
    }
  }

  void _settleIfPastEnd() {
    final position = _lastPosition;
    _clearPinnedPosition();
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
    if (extra.hold &&
        position.axis == Axis.vertical &&
        value < position.pixels) {
      return value - position.pixels;
    }
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
    if (extra.hold && position.axis == Axis.vertical && velocity < 0) {
      return null;
    }
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

/// 포커스가 들어온 입력칸을 키보드(·자동완성 바) 위로 한 번 올린다.
void liftContextAboveKeyboard(BuildContext context) {
  if (!context.mounted) return;
  final render = context.findRenderObject();
  if (render is! RenderBox || !render.attached || !render.hasSize) return;

  var box = render;
  context.visitAncestorElements((element) {
    if (element is StatefulElement && element.state is ScrollableState) {
      return false;
    }
    final ancestor = element.renderObject;
    if (ancestor is RenderBox && ancestor.attached && ancestor.hasSize) {
      final height = ancestor.size.height;
      if (height + 0.5 >= box.size.height && height <= 160) {
        box = ancestor;
      }
      if (height > 280) return false;
    }
    return true;
  });

  ScrollableState? scrollable =
      context.findAncestorStateOfType<ScrollableState>();
  while (scrollable != null) {
    if (scrollable.position.axis == Axis.vertical) break;
    scrollable = scrollable.context.findAncestorStateOfType<ScrollableState>();
  }
  if (scrollable == null || !scrollable.position.hasPixels) return;

  final view = View.of(context);
  final dpr = view.devicePixelRatio;
  final screenHeight = view.physicalSize.height / dpr;
  var keyboard = view.viewInsets.bottom / dpr;
  final web = currentWebKeyboardOverlap();
  if (web.bottom > keyboard) keyboard = web.bottom;
  if (keyboard < 1) return;

  const gap = 16.0;
  const accessory = kIsWeb ? _kWebAccessoryBar : 0.0;
  final viewBottom = web.visibleHeight > 1
      ? web.visibleHeight
      : screenHeight - keyboard;
  final visibleBottom = viewBottom - gap - accessory;
  final fieldBottom = box.localToGlobal(Offset.zero).dy + box.size.height;
  if (fieldBottom <= visibleBottom + 1) return;

  final delta = fieldBottom - visibleBottom;
  final position = scrollable.position;
  final max = position.maxScrollExtent + keyboard + gap + accessory;
  final next = (position.pixels + delta).clamp(position.minScrollExtent, max);
  if ((next - position.pixels).abs() < 4) return;
  position.jumpTo(next);
}

/// 자식 입력칸에 포커스가 가면 키보드 위로 올린다.
class KeyboardLiftOnFocus extends StatelessWidget {
  const KeyboardLiftOnFocus({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) {
        if (!focused) return;
        _run(context);
        for (final delay in const [80, 240, 520]) {
          Future<void>.delayed(Duration(milliseconds: delay), () {
            if (!context.mounted) return;
            liftContextAboveKeyboard(context);
          });
        }
      },
      child: child,
    );
  }

  static void _run(BuildContext context) {
    if (context.mounted) liftContextAboveKeyboard(context);
  }
}
