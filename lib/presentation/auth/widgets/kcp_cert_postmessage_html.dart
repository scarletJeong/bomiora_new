import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart' show debugPrint;

/// Flutter Web 탭 `window`에서 콜백 팝업이 보내는 [postMessage] 수신.
class KcpWebPostMessageListener {
  StreamSubscription<html.MessageEvent>? _sub;

  void start(void Function() onKcpDone) {
    stop();
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
  }
}
