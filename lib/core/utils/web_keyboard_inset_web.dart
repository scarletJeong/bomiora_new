import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'package:bomiora_app/core/utils/web_keyboard_overlap.dart';

export 'package:bomiora_app/core/utils/web_keyboard_overlap.dart';

const _kOverlayToken = 'interactive-widget=overlays-content';
const _kGap = 20.0;
/// iOS Safari 키보드 위 자동완성 바. visualViewport 높이에는 포함되지 않는다.
const _kAccessory = 88.0;
/// HTML input 은 글자 줄만 재므로, 그 아래 입력 상자 테두리까지 같이 올린다.
const _kFieldChrome = 28.0;
const _kMaxShift = 420.0;

void Function()? _onChange;
html.EventListener? _resizeListener;
html.EventListener? _scrollListener;
html.EventListener? _inputListener;
html.MutationObserver? _viewportObserver;
bool _listening = false;
bool _pinning = false;
bool _scrollLocked = false;
bool _compensateQueued = false;
double _lastNotifiedBottom = 0;
double _appliedShift = 0;
String? _kbLast;
int _kbLastMs = 0;

void _kb(String message) {
  final now = DateTime.now().millisecondsSinceEpoch;
  if (message == _kbLast && now - _kbLastMs < 250) return;
  _kbLast = message;
  _kbLastMs = now;
  try {
    js_util.callMethod(html.window.console, 'log', ['[kb] $message']);
  } catch (_) {}
}

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
    ensureWebKeyboardOverlayMode();
  } catch (_) {}
  return () {
    if (_onChange == onChange) _onChange = null;
  };
}

/// 키보드가 페이지를 줄이거나 밀어 올리지 않고 위에 겹치게 한다.
void ensureWebKeyboardOverlayMode() {
  _setVirtualKeyboardOverlays(true);
  _ensureOverlayViewport();
  _observeViewportMeta();
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
  _queueCompensate();
}

void clearWebVisualViewportStick() {
  _applyShift(0);
}

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

bool webPreferKeyboardAccessory() {
  try {
    final ua = html.window.navigator.userAgent.toLowerCase();
    return ua.contains('iphone') ||
        ua.contains('ipad') ||
        ua.contains('ipod') ||
        ua.contains('android');
  } catch (_) {
    return false;
  }
}

void setWebInputScrollLock(bool lock) {
  if (lock) {
    ensureWebKeyboardOverlayMode();
    _scrollLocked = true;
    pinWebDocumentScroll();
    _queueCompensate();
    return;
  }
  if (!_scrollLocked) return;
  _scrollLocked = false;
  clearWebVisualViewportStick();
}

void _ensureListening() {
  if (_listening) return;
  _listening = true;

  _resizeListener = (_) {
    try {
      _logViewport('resize');
      stickWebVisualViewport();
      _notifyKeyboardHeightChange();
    } catch (_) {}
  };
  _scrollListener = (_) {
    try {
      _logViewport('scroll');
      stickWebVisualViewport();
    } catch (_) {}
  };
  _inputListener = (_) {
    try {
      _logViewport('input');
      stickWebVisualViewport();
    } catch (_) {}
  };
  final viewport = html.window.visualViewport;
  viewport?.addEventListener('resize', _resizeListener);
  viewport?.addEventListener('scroll', _scrollListener);
  html.window.addEventListener('resize', _resizeListener);
  html.window.addEventListener('scroll', _scrollListener);
  html.document.addEventListener('input', _inputListener, true);
}

void _notifyKeyboardHeightChange() {
  final bottom = currentWebKeyboardOverlap().bottom;
  final openedOrClosed = (bottom > 1) != (_lastNotifiedBottom > 1);
  final heightChanged = (bottom - _lastNotifiedBottom).abs() >= 16;
  if (!openedOrClosed && !heightChanged) return;
  _lastNotifiedBottom = bottom;
  try {
    _onChange?.call();
  } catch (_) {}
}

void _queueCompensate() {
  if (_compensateQueued || !_scrollLocked) return;
  _compensateQueued = true;
  html.window.requestAnimationFrame((_) {
    _compensateQueued = false;
    if (!_scrollLocked) return;
    _compensateFocusedInput();
  });
}

/// 브라우저가 실제 &lt;input&gt;을 키보드에 붙였으면, 그림과 입력창만 같이 올린다.
/// flutter-view / body 는 건드리지 않는다.
void _compensateFocusedInput() {
  final input = _focusedInput();
  final viewport = html.window.visualViewport;
  if (input == null || viewport == null) {
    _applyShift(0);
    return;
  }

  final rect = input.getBoundingClientRect();
  final visibleHeight = _px(viewport.height);
  if (visibleHeight < 1) return;
  // 포커스 직후 iOS 가 입력창을 화면 밖에 두는 동안에는 밀지 않는다.
  if (rect.top < -200 || rect.height < 1 || rect.width < 1) {
    _kb(
      'compensate skip offscreen top=${rect.top.toStringAsFixed(0)} '
      'h=${rect.height.toStringAsFixed(0)} shift=${_appliedShift.toStringAsFixed(0)}',
    );
    return;
  }

  // rect 는 이미 적용된 이동을 포함한다. 이동 전 위치로 필요한 양을 다시 계산한다.
  final unshiftedBottom = rect.bottom + _appliedShift;
  final distLayout =
      (_px(viewport.offsetTop) + visibleHeight) - unshiftedBottom;
  final distVisual = visibleHeight - unshiftedBottom;
  final dist = distLayout < distVisual ? distLayout : distVisual;
  final needed = (_kGap + _kAccessory + _kFieldChrome) - dist;
  final before = _appliedShift;
  _applyShift(needed > 0 ? needed : 0);
  if ((before - _appliedShift).abs() >= 1 || (needed <= 0 && before > 0)) {
    _kb(
      'compensate shift ${before.toStringAsFixed(0)}->${_appliedShift.toStringAsFixed(0)} '
      'needed=${needed.toStringAsFixed(0)} dist=${dist.toStringAsFixed(0)} '
      'rect.bottom=${rect.bottom.toStringAsFixed(0)} '
      'visibleH=${visibleHeight.toStringAsFixed(0)} '
      'offsetTop=${_px(viewport.offsetTop).toStringAsFixed(0)}',
    );
  }
}

void _logViewport(String reason) {
  final viewport = html.window.visualViewport;
  final input = _focusedInput();
  final rect = input?.getBoundingClientRect();
  _kb(
    '$reason inner=${_px(html.window.innerHeight).toStringAsFixed(0)} '
    'vvH=${_px(viewport?.height).toStringAsFixed(0)} '
    'offsetTop=${_px(viewport?.offsetTop).toStringAsFixed(0)} '
    'scrollY=${_px(html.window.scrollY).toStringAsFixed(0)} '
    'shift=${_appliedShift.toStringAsFixed(0)} '
    'inputBottom=${rect == null ? '-' : rect.bottom.toStringAsFixed(0)} '
    'lock=$_scrollLocked',
  );
}

void _applyShift(double shift) {
  if (shift < 0) shift = 0;
  if (shift > _kMaxShift) shift = _kMaxShift;
  if ((shift - _appliedShift).abs() < 1) {
    _appliedShift = shift;
    return;
  }
  _appliedShift = shift;
  final value = shift > 0 ? 'translate3d(0px, ${-shift}px, 0px)' : '';
  _setPaneTransform('flt-glass-pane', value);
  _setPaneTransform('flt-text-editing-host', value);
}

void _setPaneTransform(String tag, String value) {
  try {
    final nodes = html.document.getElementsByTagName(tag);
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node is! html.Element) continue;
      if (value.isEmpty) {
        node.style.removeProperty('transform');
      } else {
        node.style.setProperty('transform', value);
      }
    }
  } catch (_) {}
}

html.Element? _focusedInput() {
  try {
    final active = html.document.activeElement;
    if (active == null) return null;
    final tag = active.tagName.toLowerCase();
    if (tag == 'input' || tag == 'textarea') return active;
    return null;
  } catch (_) {
    return null;
  }
}

void _setVirtualKeyboardOverlays(bool overlays) {
  try {
    final keyboard =
        js_util.getProperty(html.window.navigator, 'virtualKeyboard');
    if (keyboard != null) {
      js_util.setProperty(keyboard, 'overlaysContent', overlays);
    }
  } catch (_) {}
}

void _ensureOverlayViewport() {
  try {
    final head = html.document.head;
    if (head == null) return;
    final metas = head.querySelectorAll('meta[name="viewport"]');
    if (metas.isEmpty) return;
    for (final node in metas) {
      if (node is! html.MetaElement) continue;
      final content = node.content;
      if (content.contains(_kOverlayToken)) return;
      if (content.contains('interactive-widget=')) {
        node.content = content.replaceFirst(
          RegExp(r'interactive-widget\s*=\s*[^,]+'),
          _kOverlayToken,
        );
        return;
      }
      node.content = '$content, $_kOverlayToken';
      return;
    }
  } catch (_) {}
}

void _observeViewportMeta() {
  if (_viewportObserver != null) return;
  final head = html.document.head;
  if (head == null) return;
  try {
    _viewportObserver = html.MutationObserver((mutations, observer) {
      _ensureOverlayViewport();
    });
    _viewportObserver!.observe(
      head,
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['content'],
    );
  } catch (_) {}
}

double _px(num? value) {
  if (value == null) return 0;
  final number = value.toDouble();
  if (!number.isFinite || number < 0) return 0;
  return number;
}
