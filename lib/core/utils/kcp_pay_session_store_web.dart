import 'dart:html' as html;

const String _kcpPayTokenKey = 'bomiora_kcp_pay_token';

void rememberKcpPayToken(String token) {
  final value = token.trim();
  if (value.isEmpty) return;
  html.window.sessionStorage[_kcpPayTokenKey] = value;
}

String? readKcpPayToken() {
  final value = html.window.sessionStorage[_kcpPayTokenKey];
  if (value == null || value.trim().isEmpty) return null;
  return value.trim();
}

void clearKcpPayToken() {
  html.window.sessionStorage.remove(_kcpPayTokenKey);
}
