/// 웹에서 키보드가 화면 아래를 덮은 정도.
///
/// [bottom]은 아래에서 가려진 높이.
/// [visibleTop], [visibleHeight]는 visualViewport 위치. 없으면 0.
class WebKeyboardOverlap {
  const WebKeyboardOverlap({
    this.bottom = 0,
    this.visibleTop = 0,
    this.visibleHeight = 0,
  });

  final double bottom;
  final double visibleTop;
  final double visibleHeight;

  static const none = WebKeyboardOverlap();
}
