import 'dart:html' as html;

bool openKcpHtmlPopup(String htmlText) {
  return openKcpHtmlPopupWindow(htmlText) != null;
}

Object? openKcpHtmlPopupWindow(String htmlText) {
  try {
    // about:blank + document.write 는 빈 화면·타입 이슈가 잦아 Blob URL만 사용한다.
    // KCP가 window.open 으로 빈 창을 더 띄우지 않도록 스크립트를 <head> 직후에 주입한다.
    var base = htmlText
        .replaceAll('target="_blank"', 'target="_self"')
        .replaceAll("target='_blank'", "target='_self'");

    const blockScript = r'''
<script>
(function(){
  var _orig = window.open;
  window.open = function(u, name, feat) {
    if (u && String(u) !== 'about:blank') {
      window.location.href = u;
      return window;
    }
    return _orig ? _orig.call(window, u, name, feat) : window;
  };
})();
</script>''';

    final String injected;
    final lower = base.toLowerCase();
    final headIdx = lower.indexOf('<head');
    if (headIdx >= 0) {
      final headEnd = base.indexOf('>', headIdx);
      if (headEnd >= 0) {
        injected =
            base.substring(0, headEnd + 1) + blockScript + base.substring(headEnd + 1);
      } else {
        injected = blockScript + base;
      }
    } else {
      injected = blockScript + base;
    }

    final blob = html.Blob([injected], 'text/html; charset=utf-8');
    final objectUrl = html.Url.createObjectUrlFromBlob(blob);
    // 고정 이름: 이전에 남은 빈 팝업이 있으면 같은 창을 재사용해 빈 탭이 쌓이지 않게 한다.
    final w = html.window.open(
      objectUrl,
      'kcp_cert_popup',
      'popup=yes,width=520,height=760',
    );
    return w;
  } catch (_) {
    return null;
  }
}

Object? openPendingKcpPopup() {
  try {
    final w = html.window.open(
      'about:blank',
      'kcp_cert_popup',
      'popup=yes,width=520,height=760',
    );
    return w;
  } catch (_) {
    return null;
  }
}

bool loadKcpHtmlToPopup(Object? popup, String htmlText) {
  if (popup is! html.WindowBase) {
    return false;
  }
  try {
    final blob = html.Blob([htmlText], 'text/html; charset=utf-8');
    final objectUrl = html.Url.createObjectUrlFromBlob(blob);
    popup.location.href = objectUrl;
    return true;
  } catch (_) {
    return false;
  }
}

bool loadKcpUrlToPopup(Object? popup, String url) {
  if (popup is! html.WindowBase) {
    return false;
  }
  try {
    popup.location.href = url;
  } catch (_) {
    return false;
  }
  return true;
}

bool openKcpUrlInNewTab(String url) {
  try {
    // ignore: unnecessary_null_comparison
    return html.window.open(url, '_blank') != null;
  } catch (_) {
    return false;
  }
}

bool isKcpPopupClosed(Object? popup) {
  if (popup is! html.WindowBase) {
    return true;
  }
  try {
    return popup.closed ?? true;
  } catch (_) {
    return true;
  }
}

bool closeKcpPopup(Object? popup) {
  if (popup is! html.WindowBase) return false;
  try {
    popup.close();
    return true;
  } catch (_) {
    return false;
  }
}
