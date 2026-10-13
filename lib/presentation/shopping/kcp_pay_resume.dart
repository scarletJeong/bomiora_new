import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/kcp_pay_session_store.dart';
import 'screens/kcp_pay_webview_screen.dart';

/// 새로고침으로 결제 화면이 사라져도, 진행 중이던 결제 토큰으로 결과를 이어서 확인한다.
class KcpPayResume {
  static Future<void> tryResume(BuildContext context) async {
    if (!kIsWeb) return;
    final token = readKcpPayToken();
    if (token == null || token.isEmpty || !context.mounted) return;

    Map<String, dynamic>? data;
    try {
      final response = await ApiClient.get(ApiEndpoints.kcpPayResult(token));
      if (!context.mounted) return;
      if (response.statusCode == 404) {
        clearKcpPayToken();
        return;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return;
    }
    if (data == null || !context.mounted) return;

    final status = (data['status'] ?? '').toString();
    if (data['success'] == true || status == 'success') {
      _openComplete(context, (data['order_id'] ?? '').toString());
      return;
    }
    if (status == 'failed' || status == 'expired') {
      clearKcpPayToken();
      return;
    }

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      PageRouteBuilder(
        opaque: true,
        fullscreenDialog: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return KcpPayWebViewScreen(token: token);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    if (!context.mounted || result == null) return;
    if (result['success'] == true) {
      _openComplete(context, (result['order_id'] ?? '').toString());
    }
  }

  static void _openComplete(BuildContext context, String orderId) {
    clearKcpPayToken();
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/payment-complete',
      (route) => route.isFirst,
      arguments: {'orderId': orderId.trim()},
    );
  }
}
