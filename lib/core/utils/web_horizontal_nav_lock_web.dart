import 'dart:html' as html;
import 'dart:js_util' as js_util;

int _depth = 0;
String? _htmlOverscrollPrev;
String? _bodyOverscrollPrev;
String? _htmlTouchPrev;
String? _bodyTouchPrev;
Object? _wheelListener;
Object? _wheelOptions;

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
    return;
  }
  if (_depth == 0) return;
  _depth--;
  if (_depth != 0) return;
  _removeWheelBlock();
  _setProp(root, 'overscroll-behavior-x', _htmlOverscrollPrev ?? '');
  _setProp(body, 'overscroll-behavior-x', _bodyOverscrollPrev ?? '');
  _setProp(root, 'touch-action', _htmlTouchPrev ?? '');
  _setProp(body, 'touch-action', _bodyTouchPrev ?? '');
}
