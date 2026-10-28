import 'package:bomiora_app/core/utils/web_keyboard_overlap.dart';

export 'package:bomiora_app/core/utils/web_keyboard_overlap.dart';

WebKeyboardOverlap currentWebKeyboardOverlap() => WebKeyboardOverlap.none;

void Function() subscribeWebKeyboardOverlap(void Function() onChange) => () {};

void resetWebFirstInput() {}

void Function() subscribeWebFirstInput(void Function() onFirstInput) => () {};

void pinWebDocumentScroll() {}

void stickWebVisualViewport() {}

void clearWebVisualViewportStick() {}

bool webEditingElementFocused() => false;

void setWebInputScrollLock(bool lock) {}
