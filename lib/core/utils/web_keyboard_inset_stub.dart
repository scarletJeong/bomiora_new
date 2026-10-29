import 'package:bomiora_app/core/utils/web_keyboard_overlap.dart';

export 'package:bomiora_app/core/utils/web_keyboard_overlap.dart';

WebKeyboardOverlap currentWebKeyboardOverlap() => WebKeyboardOverlap.none;

void Function() subscribeWebKeyboardOverlap(void Function() onChange) => () {};

void ensureWebKeyboardOverlayMode() {}

void pinWebDocumentScroll() {}

void stickWebVisualViewport() {}

void clearWebVisualViewportStick() {}

bool webEditingElementFocused() => false;

/// 휴대폰 브라우저(iOS Safari 자동완성 바 등)에서만 입력칸을 더 올린다.
bool webPreferKeyboardAccessory() => false;

void setWebInputScrollLock(bool lock) {}
