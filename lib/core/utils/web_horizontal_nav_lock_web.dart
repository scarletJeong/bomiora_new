import 'dart:html' as html;
import 'dart:js_util' as js_util;

int _depth = 0;
String? _htmlOverscrollPrev;
String? _bodyOverscrollPrev;
String? _htmlTouchPrev;
String? _bodyTouchPrev;
Object? _wheelListener;
Object? _wheelOptions;
Object? _touchStartListener;
Object? _touchMoveListener;
Object? _touchEndListener;
Object? _touchPassiveOptions;
Object? _touchBlockOptions;
double? _touchX;
double? _touchY;
bool _blockHistoryForTouch = false;

void _setProp(html.CssStyleDeclaration? style, String name, String value) {
  style?.setProperty(name, value);
}

String? _prop(html.CssStyleDeclaration? style, String name) {
  return style?.getPropertyValue(name);
}

void _onHorizontalWheel(Object event) {
  if (event is html.WheelEvent) {
    if (event.deltaX.abs() <= event.deltaY.abs()) return;
    event.preventDefault();
    return;
  }
  final dx = (js_util.getProperty(event, 'deltaX') as num?)?.abs() ?? 0;
  final dy = (js_util.getProperty(event, 'deltaY') as num?)?.abs() ?? 0;
  if (dx <= dy) return;
  js_util.callMethod(event, 'preventDefault', const []);
}

void _installWheelBlock() {
  _wheelOptions ??= js_util.jsify({'capture': true, 'passive': false});
  _wheelListener ??= js_util.allowInterop(_onHorizontalWheel);
  js_util.callMethod(html.document, 'addEventListener', [
    'wheel',
    _wheelListener,
    _wheelOptions,
  ]);
}

void _removeWheelBlock() {
  if (_wheelListener == null) return;
  js_util.callMethod(html.document, 'removeEventListener', [
    'wheel',
    _wheelListener,
    _wheelOptions,
  ]);
}

void _resetTouchTracking() {
  _touchX = null;
  _touchY = null;
  _blockHistoryForTouch = false;
}

html.Touch? _primaryTouch(html.TouchEvent event) {
  final touches = event.touches;
  if (touches == null || touches.isEmpty) return null;
  return touches.first;
}

void _onTouchStart(html.Event event) {
  if (event is! html.TouchEvent) return;
  final touch = _primaryTouch(event);
  if (touch == null) return;
  _touchX = touch.client.x.toDouble();
  _touchY = touch.client.y.toDouble();
  _blockHistoryForTouch = false;
}

void _onTouchMove(html.Event event) {
  if (event is! html.TouchEvent) return;
  final touch = _primaryTouch(event);
  final originX = _touchX;
  final originY = _touchY;
  if (touch == null || originX == null || originY == null) return;
  final dx = (touch.client.x - originX).abs();
  final dy = (touch.client.y - originY).abs();
  if (!_blockHistoryForTouch && dx >= 8 && dx > dy) {
    _blockHistoryForTouch = true;
  }
  if (_blockHistoryForTouch) {
    event.preventDefault();
  }
}

void _onTouchEnd(html.Event event) {
  _resetTouchTracking();
}

void _installTouchBlock() {
  _touchPassiveOptions ??= js_util.jsify({'capture': true, 'passive': true});
  _touchBlockOptions ??= js_util.jsify({'capture': true, 'passive': false});
  _touchStartListener ??= js_util.allowInterop(_onTouchStart);
  _touchMoveListener ??= js_util.allowInterop(_onTouchMove);
  _touchEndListener ??= js_util.allowInterop(_onTouchEnd);
  js_util.callMethod(html.document, 'addEventListener', [
    'touchstart',
    _touchStartListener,
    _touchPassiveOptions,
  ]);
  js_util.callMethod(html.document, 'addEventListener', [
    'touchmove',
    _touchMoveListener,
    _touchBlockOptions,
  ]);
  js_util.callMethod(html.document, 'addEventListener', [
    'touchend',
    _touchEndListener,
    _touchPassiveOptions,
  ]);
  js_util.callMethod(html.document, 'addEventListener', [
    'touchcancel',
    _touchEndListener,
    _touchPassiveOptions,
  ]);
}

void _removeTouchBlock() {
  if (_touchStartListener == null) return;
  js_util.callMethod(html.document, 'removeEventListener', [
    'touchstart',
    _touchStartListener,
    _touchPassiveOptions,
  ]);
  js_util.callMethod(html.document, 'removeEventListener', [
    'touchmove',
    _touchMoveListener,
    _touchBlockOptions,
  ]);
  js_util.callMethod(html.document, 'removeEventListener', [
    'touchend',
    _touchEndListener,
    _touchPassiveOptions,
  ]);
  js_util.callMethod(html.document, 'removeEventListener', [
    'touchcancel',
    _touchEndListener,
    _touchPassiveOptions,
  ]);
  _resetTouchTracking();
}

/// 가로 스와이프가 브라우저 뒤로가기로 나가 이전 화면으로 떨어지는 것을 막는다.
void setBlockBrowserBackSwipe(bool block) {
  final root = html.document.documentElement?.style;
  final body = html.document.body?.style;
  if (block) {
    _depth++;
    if (_depth != 1) return;
    _htmlOverscrollPrev = _prop(root, 'overscroll-behavior-x');
    _bodyOverscrollPrev = _prop(body, 'overscroll-behavior-x');
    _htmlTouchPrev = _prop(root, 'touch-action');
    _bodyTouchPrev = _prop(body, 'touch-action');
    _setProp(root, 'overscroll-behavior-x', 'none');
    _setProp(body, 'overscroll-behavior-x', 'none');
    _setProp(root, 'touch-action', 'pan-y');
    _setProp(body, 'touch-action', 'pan-y');
    _installWheelBlock();
    _installTouchBlock();
    return;
  }
  if (_depth == 0) return;
  _depth--;
  if (_depth != 0) return;
  _removeWheelBlock();
  _removeTouchBlock();
  _setProp(root, 'overscroll-behavior-x', _htmlOverscrollPrev ?? '');
  _setProp(body, 'overscroll-behavior-x', _bodyOverscrollPrev ?? '');
  _setProp(root, 'touch-action', _htmlTouchPrev ?? '');
  _setProp(body, 'touch-action', _bodyTouchPrev ?? '');
}
