import 'dart:html' as html;

const String _kcpPayTokenKey = 'bomiora_kcp_pay_token';
const String _kcpPayCartKey = 'bomiora_kcp_pay_cart';

void rememberKcpPayToken(String token) {
  final value = token.trim();
  if (value.isEmpty) return;
  html.window.sessionStorage[_kcpPayTokenKey] = value;
}

void rememberKcpPayCart({required bool prescriptionTab}) {
  html.window.sessionStorage[_kcpPayCartKey] = prescriptionTab ? 'rx' : 'general';
}

String? readKcpPayToken() {
  final value = html.window.sessionStorage[_kcpPayTokenKey];
  if (value == null || value.trim().isEmpty) return null;
  return value.trim();
}

bool readKcpPayCartPrescription() {
  return html.window.sessionStorage[_kcpPayCartKey] == 'rx';
}

void clearKcpPayToken() {
  html.window.sessionStorage.remove(_kcpPayTokenKey);
  html.window.sessionStorage.remove(_kcpPayCartKey);
}
