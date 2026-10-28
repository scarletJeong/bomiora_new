import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:bomiora_app/core/utils/web_keyboard_overlap.dart';

export 'package:bomiora_app/core/utils/web_keyboard_overlap.dart';

void Function()? _onChange;
html.EventListener? _resizeListener;
html.EventListener? _scrollListener;
JSFunction? _geometryListener;
bool _listening = false;
bool _pinning = false;
bool _scrollLocked = false;

WebKeyboardOverlap currentWebKeyboardOverlap() {
  final innerHeight = _px(html.window.innerHeight);
  final viewport = html.window.visualViewport;
  final visibleTop = _px(viewport?.offsetTop);
  final visibleHeight = _px(viewport?.height);

  var bottom = 0.0;
  if (innerHeight > 0 && visibleHeight > 0) {
    final covered = innerHeight - visibleTop - visibleHeight;
    if (covered > 1) bottom = covered;
  }

  final keyboard = _virtualKeyboardHeight();
  if (keyboard > bottom) bottom = keyboard;

  return WebKeyboardOverlap(
    bottom: bottom,
    visibleTop: visibleTop,
    visibleHeight: visibleHeight,
  );
}

void Function() subscribeWebKeyboardOverlap(void Function() onChange) {
  _onChange = onChange;
  _ensureListening();
  return () {
    if (_onChange == onChange) _onChange = null;
  };
}

void pinWebDocumentScroll() {
  if (_pinning) return;
  _pinning = true;
  try {
    final view = html.window;
    if (view.scrollY != 0) {
      view.scrollTo(0, 0);
    }
    final root = html.document.documentElement;
    if (root != null && root.scrollTop != 0) {
      root.scrollTop = 0;
    }
    final body = html.document.body;
    if (body != null && body.scrollTop != 0) {
      body.scrollTop = 0;
    }
  } finally {
    _pinning = false;
  }
}

bool webEditingElementFocused() {
  final active = html.document.activeElement;
  if (active == null) return false;
  final tag = active.tagName.toLowerCase();
  return tag == 'input' || tag == 'textarea' || active.isContentEditable == true;
}

void setWebInputScrollLock(bool lock) {
  if (lock) {
    if (_scrollLocked) return;
    _scrollLocked = true;
    pinWebDocumentScroll();
    return;
  }
  _scrollLocked = false;
}

void _ensureListening() {
  if (_listening) return;
  _listening = true;

  _resizeListener = (_) => _onChange?.call();
  _scrollListener = (_) => pinWebDocumentScroll();
  final viewport = html.window.visualViewport;
  viewport?.addEventListener('resize', _resizeListener);
  viewport?.addEventListener('scroll', _scrollListener);
  html.window.addEventListener('resize', _resizeListener);
  html.window.addEventListener('scroll', _scrollListener);

  final keyboard = _virtualKeyboard();
  if (keyboard == null) return;
  keyboard['overlaysContent'] = true.toJS;
  _geometryListener = ((JSAny? _) {
    _onChange?.call();
  }).toJS;
  keyboard.callMethod(
    'addEventListener'.toJS,
    'geometrychange'.toJS,
    _geometryListener,
  );
}

JSObject? _virtualKeyboard() {
  final navigator = globalContext['navigator'];
  if (navigator is! JSObject || !navigator.has('virtualKeyboard')) return null;
  final keyboard = navigator['virtualKeyboard'];
  if (keyboard is! JSObject) return null;
  return keyboard;
}

double _virtualKeyboardHeight() {
  final keyboard = _virtualKeyboard();
  if (keyboard == null || !keyboard.has('boundingRect')) return 0;
  final rect = keyboard['boundingRect'];
  if (rect is! JSObject || !rect.has('height')) return 0;
  final height = rect['height'];
  if (height is! JSNumber) return 0;
  final value = height.toDartDouble;
  if (!value.isFinite || value < 1) return 0;
  return value;
}

double _px(num? value) {
  if (value == null) return 0;
  final number = value.toDouble();
  if (!number.isFinite || number < 0) return 0;
  return number;
}
