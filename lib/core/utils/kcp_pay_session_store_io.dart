import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kcpPayTokenKey = 'bomiora_kcp_pay_token';
const String _kcpPayCartKey = 'bomiora_kcp_pay_cart';

String? _token;
bool _prescriptionCart = false;

Future<void> loadKcpPaySession() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_kcpPayTokenKey);
    _token = (value == null || value.trim().isEmpty) ? null : value.trim();
    _prescriptionCart = prefs.getString(_kcpPayCartKey) == 'rx';
  } catch (e) {
    debugPrint('[KcpPay] 결제 이어보기 저장을 읽지 못했습니다: $e');
  }
}

String? readKcpPayToken() => _token;

bool readKcpPayCartPrescription() => _prescriptionCart;

Future<void> rememberKcpPayToken(String token) async {
  final value = token.trim();
  if (value.isEmpty) return;
  _token = value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kcpPayTokenKey, value);
}

Future<void> rememberKcpPayCart({required bool prescriptionTab}) async {
  _prescriptionCart = prescriptionTab;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kcpPayCartKey, prescriptionTab ? 'rx' : 'general');
}

Future<void> clearKcpPayToken() async {
  _token = null;
  _prescriptionCart = false;
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kcpPayTokenKey);
  await prefs.remove(_kcpPayCartKey);
}
