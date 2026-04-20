import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../common/widgets/app_bar.dart';

class KcpPayWebViewScreen extends StatefulWidget {
  const KcpPayWebViewScreen({
    super.key,
    required this.html,
    required this.token,
  });

  final String html;
  final String token;

  @override
  State<KcpPayWebViewScreen> createState() => _KcpPayWebViewScreenState();
}

class _KcpPayWebViewScreenState extends State<KcpPayWebViewScreen> {
  static const String _iosSafariUa =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';
  static const String _androidChromeUa =
      'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36';

  Timer? _pollingTimer;
  bool _completed = false;
  bool _isLoading = true;

  void _returnUserCancelled() {
    if (_completed || !mounted) return;
    _completed = true;
    _pollingTimer?.cancel();
    Navigator.pop(context, {
      'success': false,
      'error_code': 'USER_CANCELLED',
      'message': '사용자가 결제를 취소했습니다. 결제하기 버튼으로 다시 시도해 주세요.',
    });
  }

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollResult();
    });
    _pollResult();
  }

  String _mobileUserAgent() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _iosSafariUa;
    }
    return _androidChromeUa;
  }

  Future<void> _pollResult() async {
    if (_completed || !mounted) return;
    try {
      final response =
          await ApiClient.get(ApiEndpoints.kcpPayResult(widget.token));
      if (response.statusCode == 404) {
        return;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = (data['status'] ?? '').toString();
      if (status == 'pending') {
        return;
      }

      _completed = true;
      _pollingTimer?.cancel();

      if (data['success'] == true) {
        if (!mounted) return;
        Navigator.pop(context, {
          'success': true,
          'order_id': data['order_id'],
          'message': data['message'],
        });
        return;
      }

      if (!mounted) return;
      Navigator.pop(context, {
        'success': false,
        'error_code': data['error_code'],
        'message': (data['message'] ?? '결제가 완료되지 않았습니다.').toString(),
      });
    } catch (_) {
      // no-op
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _returnUserCancelled();
        return false;
      },
      child: Scaffold(
        appBar: HealthAppBar(
          title: 'KCP 결제',
          onBack: _returnUserCancelled,
        ),
        body: Stack(
          children: [
            InAppWebView(
            initialData: InAppWebViewInitialData(
              data: widget.html,
              baseUrl: WebUri('https://pay.kcp.co.kr'),
              historyUrl: WebUri('https://pay.kcp.co.kr'),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              cacheEnabled: false,
              userAgent: _mobileUserAgent(),
              javaScriptCanOpenWindowsAutomatically: true,
              supportMultipleWindows: true,
              thirdPartyCookiesEnabled: true,
              sharedCookiesEnabled: true,
              useHybridComposition: true,
              allowsInlineMediaPlayback: true,
              mediaPlaybackRequiresUserGesture: false,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
            ),
            onLoadStop: (controller, url) {
              if (!mounted) return;
              setState(() {
                _isLoading = false;
              });
            },
            onLoadStart: (controller, url) async {
              final text = url?.toString() ?? '';
              if (text.contains('/api/kcp-pay/callback')) {
                _pollResult();
              }
            },
          ),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
