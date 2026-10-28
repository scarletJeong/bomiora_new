import 'dart:html' as html;

import 'package:bomiora_app/core/utils/web_keyboard_overlap.dart';

export 'package:bomiora_app/core/utils/web_keyboard_overlap.dart';

void Function()? _onChange;
void Function()? _onFirstInput;
html.EventListener? _resizeListener;
html.EventListener? _scrollListener;
html.EventListener? _inputListener;
bool _listening = false;
bool _pinning = false;
bool _scrollLocked = false;
bool _firstInputFired = false;
double _lastNotifiedBottom = 0;

WebKeyboardOverlap currentWebKeyboardOverlap() {
  try {
    final innerHeight = _px(html.window.innerHeight);
    final viewport = html.window.visualViewport;
    final visibleTop = _px(viewport?.offsetTop);
    final visibleHeight = _px(viewport?.height);

    var bottom = 0.0;
    if (innerHeight > 0 && visibleHeight > 0) {
      final covered = innerHeight - visibleTop - visibleHeight;
      if (covered > 1) bottom = covered;
    }

    return WebKeyboardOverlap(
      bottom: bottom,
      visibleTop: visibleTop,
      visibleHeight: visibleHeight,
    );
  } catch (_) {
    return WebKeyboardOverlap.none;
  }
}

void Function() subscribeWebKeyboardOverlap(void Function() onChange) {
  _onChange = onChange;
  try {
    _ensureListening();
  } catch (_) {}
  return () {
    if (_onChange == onChange) _onChange = null;
  };
}

void resetWebFirstInput() {
  _firstInputFired = false;
}

void Function() subscribeWebFirstInput(void Function() onFirstInput) {
  _onFirstInput = onFirstInput;
  try {
    _ensureListening();
  } catch (_) {}
  return () {
    if (_onFirstInput == onFirstInput) _onFirstInput = null;
  };
}

void pinWebDocumentScroll() {
  if (_pinning) return;
  _pinning = true;
  try {
    if (html.window.scrollY != 0) {
      html.window.scrollTo(0, 0);
    }
  } catch (_) {
  } finally {
    _pinning = false;
  }
}

void stickWebVisualViewport() {
  if (!_scrollLocked) return;
  pinWebDocumentScroll();
}

void clearWebVisualViewportStick() {}

bool webEditingElementFocused() {
  try {
    final active = html.document.activeElement;
    if (active == null) return false;
    final tag = active.tagName.toLowerCase();
    return tag == 'input' ||
        tag == 'textarea' ||
        active.isContentEditable == true;
  } catch (_) {
    return false;
  }
}

void setWebInputScrollLock(bool lock) {
  if (lock) {
    if (_scrollLocked) {
      pinWebDocumentScroll();
      return;
    }
    _scrollLocked = true;
    _firstInputFired = false;
    _bindFirstInput();
    pinWebDocumentScroll();
    return;
  }
  if (!_scrollLocked) return;
  _scrollLocked = false;
  _firstInputFired = false;
  _unbindFirstInput();
  clearWebVisualViewportStick();
}

void _bindFirstInput() {
  if (_inputListener != null) return;
  _inputListener = (_) {
    if (!_scrollLocked || _firstInputFired) return;
    _firstInputFired = true;
    try {
      _onFirstInput?.call();
    } catch (_) {}
  };
  html.document.addEventListener('input', _inputListener, true);
}

void _unbindFirstInput() {
  final listener = _inputListener;
  if (listener == null) return;
  html.document.removeEventListener('input', listener, true);
  _inputListener = null;
}

void _ensureListening() {
  if (_listening) return;
  _listening = true;

  _resizeListener = (_) {
    try {
      stickWebVisualViewport();
      _notifyKeyboardGeometryChange();
    } catch (_) {}
  };
  _scrollListener = (_) {
    try {
      stickWebVisualViewport();
    } catch (_) {}
  };
  final viewport = html.window.visualViewport;
  viewport?.addEventListener('resize', _resizeListener);
  viewport?.addEventListener('scroll', _scrollListener);
  html.window.addEventListener('resize', _resizeListener);
  html.window.addEventListener('scroll', _scrollListener);
}

void _notifyKeyboardGeometryChange() {
  final bottom = currentWebKeyboardOverlap().bottom;
  final openedOrClosed = (bottom > 1) != (_lastNotifiedBottom > 1);
  final heightChanged = (bottom - _lastNotifiedBottom).abs() >= 24;
  if (!openedOrClosed && !heightChanged) return;
  _lastNotifiedBottom = bottom;
  try {
    _onChange?.call();
  } catch (_) {}
}

double _px(num? value) {
  if (value == null) return 0;
  final number = value.toDouble();
  if (!number.isFinite || number < 0) return 0;
  return number;
}
