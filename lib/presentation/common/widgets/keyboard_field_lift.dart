import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FlutterView;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:bomiora_app/core/utils/web_keyboard_inset.dart';

/// 모바일 웹 키보드 위 자동완성 바. visualViewport·viewInsets 에는 안 잡힌다.
const double _kWebAccessoryBar = 88;

const double _kFieldGap = 20;

/// 포커스 중 스크롤이 키보드 아래로 되돌아가지 않게 하는 표시.
/// 화면별 포커스 콜백과 [KeyboardFieldLift]가 같이 쓴다.
bool _keyboardLiftHold = false;
double _keyboardLiftSlack = 0;

String? _kbLast;
DateTime? _kbLastAt;

/// 릴리즈 웹에서도 브라우저 콘솔에 남긴다. 같은 문장은 0.25초만 한 번.
void _kb(String message) {
  final now = DateTime.now();
  if (message == _kbLast &&
      _kbLastAt != null &&
      now.difference(_kbLastAt!).inMilliseconds < 250) {
    return;
  }
  _kbLast = message;
  _kbLastAt = now;
  // ignore: avoid_print
  print('[kb] $message');
}

String _n(double v) => v.isFinite ? v.toStringAsFixed(0) : 'nan';

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
  bool _applyingLift = false;
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
    for (final delay in const [80, 240, 520, 900]) {
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
        _kb('release hold cleared');
        _latchedKeyboard = 0;
        _pinnedPixels = null;
        _keyboardLiftHold = false;
        _keyboardLiftSlack = 0;
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

    _keyboardLiftHold = true;
    _extra.hold = true;
    setWebInputScrollLock(true);
    if (fieldContext == null) {
      _kb(
        'lift abort no-field webFocus=${webEditingElementFocused()} '
        'latched=${_n(_latchedKeyboard)}',
      );
      return;
    }

    final fieldRender = fieldContext.findRenderObject();
    if (fieldRender is! RenderBox ||
        !fieldRender.attached ||
        !fieldRender.hasSize) {
      _kb('lift abort no-box');
      return;
    }
    final fieldBox = _revealBox(fieldContext, fieldRender);

    final scrollable = _pageScrollable(fieldContext);
    if (scrollable == null || !scrollable.position.hasPixels) {
      _kb('lift abort no-scroll boxH=${_n(fieldBox.size.height)}');
      return;
    }

    final view = View.of(fieldContext);
    final cover = _keyboardCoverOf(
      view,
      editing: true,
      hintedKeyboard: _latchedKeyboard,
    );
    final visibleTop = view.padding.top / view.devicePixelRatio + _kFieldGap;
    final visibleBottom = cover.visibleBottom;
    final overlap = currentWebKeyboardOverlap();
    final screen = view.physicalSize.height / view.devicePixelRatio;
    final inset = view.viewInsets.bottom / view.devicePixelRatio;

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

    if (delta <= 0.5) {
      _pinnedPixels = position.pixels;
      _kb(
        'lift skip covered=no fieldBottom=${_n(fieldBottom)} '
        'visibleBottom=${_n(visibleBottom)} kb=${_n(cover.keyboard)} '
        'reserve=${_n(cover.reserve)} px=${_n(position.pixels)} '
        'max=${_n(position.maxScrollExtent)} boxH=${_n(fieldBox.size.height)} '
        'screen=${_n(screen)} visibleH=${_n(overlap.visibleHeight)} '
        'inset=${_n(inset)} webBottom=${_n(overlap.bottom)} '
        'mobileAcc=${webPreferKeyboardAccessory()}',
      );
      return;
    }

    final reserve = math.max(cover.keyboard + cover.reserve, delta);
    _extra.bottom = math.max(_extra.bottom, reserve);
    _keyboardLiftSlack = math.max(_keyboardLiftSlack, reserve);
    _lastPosition = position;
    final target = math.max(
      position.minScrollExtent,
      position.pixels + delta,
    );
    if ((target - position.pixels).abs() <= 0.5) {
      _pinnedPixels = position.pixels;
      return;
    }
    _applyingLift = true;
    position.jumpTo(target);
    _applyingLift = false;
    _pinnedPixels = target;
    final after = position.pixels;
    _kb(
      'lift jump delta=${_n(delta)} fieldBottom=${_n(fieldBottom)} '
      'visibleBottom=${_n(visibleBottom)} kb=${_n(cover.keyboard)} '
      'reserve=${_n(cover.reserve)} px ${_n(target)}->${_n(after)} '
      'max=${_n(position.maxScrollExtent)} slack=${_n(_extra.bottom)} '
      'boxH=${_n(fieldBox.size.height)} '
      'screen=${_n(screen)} visibleH=${_n(overlap.visibleHeight)} '
      'inset=${_n(inset)} webBottom=${_n(overlap.bottom)} '
      'mobileAcc=${webPreferKeyboardAccessory()}',
    );
    if ((after - target).abs() > 1) {
      _kb(
        'lift JUMP REVERTED target=${_n(target)} after=${_n(after)} '
        'max=${_n(position.maxScrollExtent)} hold=${_extra.hold}',
      );
    }
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
    if (_restoringPin || _applyingLift) return;
    final position = _lastPosition;
    final pinned = _pinnedPixels;
    if (position == null || pinned == null || !position.hasPixels) return;
    if (position.pixels >= pinned - 0.5) {
      if (position.pixels > pinned + 0.5) {
        _pinnedPixels = position.pixels;
      }
      return;
    }
    _kb(
      'scroll DROP px ${_n(position.pixels)} pinned=${_n(pinned)} '
      'hold=${_extra.hold} flagHold=$_keyboardLiftHold '
      'max=${_n(position.maxScrollExtent)}',
    );
    if (!_extra.hold) return;
    _restoringPin = true;
    try {
      position.jumpTo(pinned);
      _kb('scroll RESTORE -> ${_n(position.pixels)}');
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

  bool get _holding => extra.hold || _keyboardLiftHold;

  double get _slack => math.max(extra.bottom, _keyboardLiftSlack);

  double _max(ScrollMetrics position) => position.maxScrollExtent + _slack;

  /// 글자를 치는 동안 입력칸을 화면 맨 아래(키보드 밑)로 되돌리지 않는다.
  @override
  bool get allowImplicitScrolling => !_holding;

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (_holding &&
        position.axis == Axis.vertical &&
        value < position.pixels) {
      return value - position.pixels;
    }
    if (position.axis != Axis.vertical || _slack <= 0) {
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
    // jumpTo 가 본문 끝을 넘기면 velocity 0 으로 되감기 시뮬레이션이 붙는다.
    // 입력 중에는 그 되감기를 막아야 칸이 키보드 아래로 돌아가지 않는다.
    if (_holding && position.axis == Axis.vertical && velocity <= 0) {
      return null;
    }
    if (position.axis != Axis.vertical || _slack <= 0) {
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
  if (scrollable == null || !scrollable.position.hasPixels) {
    _kb('focus-lift abort no-scroll');
    return;
  }

  final view = View.of(context);
  final cover = _keyboardCoverOf(view, editing: true);
  final fieldBottom = box.localToGlobal(Offset.zero).dy + box.size.height;
  if (cover.keyboard < 1 && cover.reserve < 1) {
    _kb(
      'focus-lift abort no-cover fieldBottom=${_n(fieldBottom)} '
      'boxH=${_n(box.size.height)}',
    );
    return;
  }

  final visibleBottom = cover.visibleBottom;
  if (fieldBottom <= visibleBottom + 0.5) {
    _kb(
      'focus-lift skip fieldBottom=${_n(fieldBottom)} '
      'visibleBottom=${_n(visibleBottom)} kb=${_n(cover.keyboard)} '
      'reserve=${_n(cover.reserve)}',
    );
    return;
  }

  final delta = fieldBottom - visibleBottom;
  final position = scrollable.position;
  final reserve = math.max(cover.keyboard + cover.reserve, delta);
  _keyboardLiftHold = true;
  _keyboardLiftSlack = math.max(_keyboardLiftSlack, reserve);
  final before = position.pixels;
  final next = math.max(position.minScrollExtent, position.pixels + delta);
  if ((next - position.pixels).abs() <= 0.5) return;
  position.jumpTo(next);
  _kb(
    'focus-lift jump delta=${_n(delta)} px ${_n(before)}->${_n(position.pixels)} '
    'target=${_n(next)} fieldBottom=${_n(fieldBottom)} '
    'visibleBottom=${_n(visibleBottom)}',
  );
  if ((position.pixels - next).abs() > 1) {
    _kb(
      'focus-lift JUMP REVERTED target=${_n(next)} '
      'after=${_n(position.pixels)} max=${_n(position.maxScrollExtent)}',
    );
  }
}

/// 키보드가 가리는 높이만큼 스크롤 본문 아래에 빈 칸을 넣어, 맨 아래 입력칸도 키보드 위로 올릴 수 있게 한다.
class KeyboardInsetSpacer extends StatefulWidget {
  const KeyboardInsetSpacer({super.key});

  @override
  State<KeyboardInsetSpacer> createState() => _KeyboardInsetSpacerState();
}

class _KeyboardInsetSpacerState extends State<KeyboardInsetSpacer>
    with WidgetsBindingObserver {
  late final void Function() _unsubscribe;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _unsubscribe = subscribeWebKeyboardOverlap(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _unsubscribe();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final height = _keyboardScrollSlack(context);
    if (height < 1) return const SizedBox.shrink();
    return SizedBox(height: height);
  }
}

class _KeyboardCover {
  const _KeyboardCover({
    required this.keyboard,
    required this.reserve,
    required this.visibleBottom,
  });

  /// Flutter 화면에서 키보드가 덮은 높이.
  final double keyboard;

  /// 키보드 위로 더 비워 둘 간격(자동완성 바 + 여백).
  final double reserve;

  /// 입력 상자 바닥이 이 y 보다 위에 있어야 한다.
  final double visibleBottom;
}

_KeyboardCover _keyboardCoverOf(
  FlutterView view, {
  required bool editing,
  double hintedKeyboard = 0,
}) {
  final dpr = view.devicePixelRatio;
  final screenHeight = view.physicalSize.height / dpr;
  final overlap = currentWebKeyboardOverlap();
  final visible =
      overlap.visibleHeight > 1 ? overlap.visibleHeight : screenHeight;
  final flutterHidden = math.max(0.0, screenHeight - visible);

  var keyboard = view.viewInsets.bottom / dpr;
  if (!keyboard.isFinite || keyboard < 0) keyboard = 0;
  if (overlap.bottom > keyboard) keyboard = overlap.bottom;
  if (hintedKeyboard > keyboard) keyboard = hintedKeyboard;
  if (flutterHidden > keyboard) keyboard = flutterHidden;

  // 화면 높이가 이미 보이는 영역과 같으면 키보드는 레이아웃 밖에 있다.
  // 그때 키보드 높이를 한 번 더 빼면 입력칸이 화면 위로 올라간다.
  final hasVisible = overlap.visibleHeight > 1;
  final viewAlreadyFits =
      hasVisible && (screenHeight - visible).abs() < 48;
  final keyboardForLayout = viewAlreadyFits ? 0.0 : keyboard;

  final accessory = kIsWeb &&
          webPreferKeyboardAccessory() &&
          (editing || keyboard > 1)
      ? _kWebAccessoryBar
      : 0.0;
  final reserve = (keyboardForLayout > 1 || accessory > 0)
      ? _kFieldGap + accessory
      : 0.0;

  var viewBottom = screenHeight - (keyboardForLayout > 1 ? keyboardForLayout : 0);
  if (hasVisible) {
    viewBottom = math.min(viewBottom, overlap.visibleHeight);
  }
  return _KeyboardCover(
    keyboard: keyboardForLayout,
    reserve: reserve,
    visibleBottom: viewBottom - reserve,
  );
}

double _keyboardScrollSlack(BuildContext context) {
  final view = View.maybeOf(context);
  if (view == null) return 0;
  final editing = webEditingElementFocused();
  final cover = _keyboardCoverOf(view, editing: editing);
  if (!editing && cover.keyboard < 1) return 0;
  return cover.keyboard + cover.reserve;
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
        for (final delay in const [80, 240, 520, 900]) {
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
