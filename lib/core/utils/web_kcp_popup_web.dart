import 'dart:html' as html;

bool openKcpHtmlPopup(String htmlText) {
  final popup = openPendingKcpPopup();
  if (popup == null) {
    return false;
  }
  return loadKcpHtmlToPopup(popup, htmlText);
}

Object? openPendingKcpPopup() {
  return html.window.open('about:blank', '_blank');
}

bool loadKcpHtmlToPopup(Object? popup, String htmlText) {
  if (popup is! html.WindowBase) {
    return false;
  }

  // 최상위 프레임을 data: URL로 이동하는 것은 Chrome 등에서 차단됨.
  // Blob URL은 동일 목적에 대체로 허용되며, 가능하면 백엔드 launch URL 사용을 권장.
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
    // 브라우저에 따라 차단 시 null — SDK 타입은 nullable이 아닐 수 있음
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
