import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart' show debugPrint;

/// Flutter Web 탭 `window`에서 콜백 팝업이 보내는 [postMessage] 수신.
class KcpWebPostMessageListener {
  StreamSubscription<html.MessageEvent>? _sub;
  StreamSubscription<html.Event>? _blurSub;
  StreamSubscription<html.Event>? _focusSub;
  bool _windowLostFocus = false;

  void start(
    void Function() onKcpDone, {
    void Function()? onWindowReturned,
  }) {
    stop();
    _blurSub = html.window.onBlur.listen((_) {
      _windowLostFocus = true;
    });
    _focusSub = html.window.onFocus.listen((_) {
      if (!_windowLostFocus) return;
      _windowLostFocus = false;
      debugPrint('[KCP] 브라우저 부모 창 포커스 복귀');
      onWindowReturned?.call();
    });
    _sub = html.window.onMessage.listen((html.MessageEvent e) {
      final data = e.data;
      var hit = false;
      if (data is Map) {
        final t = data['type']?.toString();
        if (t == 'KCP_CERT_DONE') {
          hit = true;
        }
      }
      if (!hit && data is String) {
        try {
          final m = jsonDecode(data);
          if (m is Map && m['type'] == 'KCP_CERT_DONE') {
            hit = true;
          }
        } catch (_) {}
      }
      if (hit) {
        debugPrint('[KCP] postMessage: KCP_CERT_DONE (window 수신)');
        onKcpDone();
      }
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _blurSub?.cancel();
    _blurSub = null;
    _focusSub?.cancel();
    _focusSub = null;
    _windowLostFocus = false;
  }
}
