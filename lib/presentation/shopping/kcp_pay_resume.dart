import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/kcp_pay_session_store.dart';

/// 새로고침으로 결제 화면이 사라져도, 진행 중이던 결제 토큰으로 결과를 이어서 확인한다.
/// WebView는 다시 열지 않고 결과 API만 폴링한다.
class KcpPayResume {
  static const _pollInterval = Duration(milliseconds: 800);
  static const _pollTimeout = Duration(seconds: 90);

  static Future<void> tryResume(BuildContext context) async {
    if (!kIsWeb) return;
    final token = readKcpPayToken();
    if (token == null || token.isEmpty || !context.mounted) return;

    final data = await _fetchResult(token);
    if (!context.mounted) return;
    if (data == null) return;

    if (_isGone(data)) {
      clearKcpPayToken();
      return;
    }

    if (await _handleTerminalResult(context, data)) return;

    final status = (data['status'] ?? '').toString();
    if (status == 'pending') {
      await _awaitPendingResult(context, token);
    }
  }

  static bool _isGone(Map<String, dynamic> data) => data['_gone'] == true;

  /// 결과 API 한 번. 404는 `{_gone: true}`, 네트워크 오류는 null.
  static Future<Map<String, dynamic>?> _fetchResult(String token) async {
    try {
      final response = await ApiClient.get(ApiEndpoints.kcpPayResult(token));
      if (response.statusCode == 404) {
        return <String, dynamic>{'_gone': true};
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  /// success / failed / expired / 가상계좌 pending 완료를 처리하면 true.
  static Future<bool> _handleTerminalResult(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final status = (data['status'] ?? '').toString();
    if (data['success'] == true || status == 'success') {
      _openComplete(context, (data['order_id'] ?? '').toString());
      return true;
    }

    // 웹뷰와 동일: pending 이어도 가상계좌 발급 완료면 성공으로 본다.
    if (status == 'pending') {
      final resCd = (data['res_cd'] ?? '').toString().trim();
      final orderId = (data['order_id'] ?? '').toString().trim();
      if (resCd == '0000' && orderId.isNotEmpty) {
        _openComplete(context, orderId);
        return true;
      }
    }

    if (status == 'failed' || status == 'expired') {
      clearKcpPayToken();
      if (status == 'failed' && context.mounted) {
        final message = (data['message'] ?? '').toString().trim();
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(
              message.isEmpty ? '결제가 완료되지 않았습니다.' : message,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
      return true;
    }
    return false;
  }

  /// pending: 토큰 유지 + 결과 폴링. WebView 재오픈 없음.
  static Future<void> _awaitPendingResult(
    BuildContext context,
    String token,
  ) async {
    final started = DateTime.now();
    while (context.mounted &&
        DateTime.now().difference(started) < _pollTimeout) {
      await Future<void>.delayed(_pollInterval);
      if (!context.mounted) return;

      final data = await _fetchResult(token);
      if (!context.mounted) return;
      if (data == null) continue;
      if (_isGone(data)) {
        clearKcpPayToken();
        return;
      }
      if (await _handleTerminalResult(context, data)) return;
    }

    // 시간 초과: 토큰은 남겨 다음 진입에서 다시 확인. 주문내역으로 안내.
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text(
          '결제 결과를 아직 확인하지 못했습니다.\n주문내역에서 상태를 확인해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/order',
      (route) => route.isFirst,
    );
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
