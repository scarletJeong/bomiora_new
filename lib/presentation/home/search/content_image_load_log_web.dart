import 'dart:html' as html;

/// 브라우저 `<img>` 로드 시간. 화면에 그리는 이미지와 같은 주소라 요청은 한 번이다.
void Function() watchContentImageLoad({
  required String url,
  required void Function(int elapsedMs, bool ok) onDone,
}) {
  final started = Stopwatch()..start();
  final image = html.ImageElement(src: url);
  var finished = false;
  void finish(bool ok) {
    if (finished) return;
    finished = true;
    onDone(started.elapsedMilliseconds, ok);
  }

  final loadSub = image.onLoad.listen((_) => finish(true));
  final errorSub = image.onError.listen((_) => finish(false));
  return () {
    finished = true;
    loadSub.cancel();
    errorSub.cancel();
  };
}
