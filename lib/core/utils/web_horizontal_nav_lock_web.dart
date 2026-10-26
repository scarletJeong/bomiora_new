import 'dart:html' as html;

int _depth = 0;
String? _htmlPrev;
String? _bodyPrev;

void _setOverscrollX(html.CssStyleDeclaration? style, String value) {
  style?.setProperty('overscroll-behavior-x', value);
}

String? _overscrollX(html.CssStyleDeclaration? style) {
  return style?.getPropertyValue('overscroll-behavior-x');
}

/// 가로 스와이프가 브라우저 뒤로가기로 나가 이전 화면으로 떨어지는 것을 막는다.
void setBlockBrowserBackSwipe(bool block) {
  final root = html.document.documentElement?.style;
  final body = html.document.body?.style;
  if (block) {
    _depth++;
    if (_depth != 1) return;
    _htmlPrev = _overscrollX(root);
    _bodyPrev = _overscrollX(body);
    _setOverscrollX(root, 'none');
    _setOverscrollX(body, 'none');
    return;
  }
  if (_depth == 0) return;
  _depth--;
  if (_depth != 0) return;
  _setOverscrollX(root, _htmlPrev ?? '');
  _setOverscrollX(body, _bodyPrev ?? '');
}
