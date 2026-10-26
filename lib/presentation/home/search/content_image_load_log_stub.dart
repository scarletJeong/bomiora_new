import 'package:flutter/painting.dart';

/// 이미지 요청을 시작하고, 끝나거나 취소할 때 호출할 함수를 돌려준다.
void Function() watchContentImageLoad({
  required String url,
  required void Function(int elapsedMs, bool ok) onDone,
}) {
  final started = Stopwatch()..start();
  final stream = NetworkImage(url).resolve(const ImageConfiguration());
  var finished = false;
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (image, synchronousCall) {
      if (finished) return;
      finished = true;
      stream.removeListener(listener);
      onDone(started.elapsedMilliseconds, true);
    },
    onError: (exception, stackTrace) {
      if (finished) return;
      finished = true;
      stream.removeListener(listener);
      onDone(started.elapsedMilliseconds, false);
    },
  );
  stream.addListener(listener);
  return () {
    if (finished) return;
    finished = true;
    stream.removeListener(listener);
  };
}
