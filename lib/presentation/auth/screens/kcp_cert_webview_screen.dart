import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../core/network/api_client.dart';
import '../../../data/repositories/auth/auth_repository.dart';
import '../../common/widgets/app_bar.dart';

class KcpCertWebViewScreen extends StatefulWidget {
  const KcpCertWebViewScreen({
    super.key,
    this.flow = 'signup',
    this.email,
  });

  final String flow;
  final String? email;

  @override
  State<KcpCertWebViewScreen> createState() => _KcpCertWebViewScreenState();
}

class _KcpCertWebViewScreenState extends State<KcpCertWebViewScreen> {
  InAppWebViewController? _webViewController;
  Timer? _pollingTimer;

  bool _isLoading = true;
  bool _hasNavigated = false;
  String? _initialHtml;
  String? _requestToken;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeKcpRequest();
  }

  Future<void> _initializeKcpRequest() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _initialHtml = null;
      _requestToken = null;
    });

    try {
      final response = await ApiClient.get('/api/auth/kcp/request');
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 || data['success'] != true) {
        throw Exception(data['message'] ?? 'KCP 요청 데이터 생성에 실패했습니다.');
      }

      final html = (data['html'] ?? '').toString();
      final token = (data['token'] ?? '').toString();

      if (html.isEmpty || token.isEmpty) {
        throw Exception('KCP 요청 응답이 올바르지 않습니다.');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _initialHtml = html;
        _requestToken = token;
        _isLoading = false;
      });

      // 콜백 페이지 감지 실패와 무관하게, 토큰 발급 직후부터 결과를 폴링한다.
      _startPollingResult();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = '본인인증 준비 중 오류가 발생했습니다.\n$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HealthAppBar(
        title: '본인인증',
        onBack: () => Navigator.pop(context),
      ),
      body: Stack(
        children: [
          if (_initialHtml != null)
            InAppWebView(
              initialData: InAppWebViewInitialData(data: _initialHtml!),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                cacheEnabled: true,
                clearCache: false,
                useHybridComposition: true,
                allowsInlineMediaPlayback: true,
                mediaPlaybackRequiresUserGesture: false,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                allowFileAccess: true,
                allowContentAccess: true,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              onLoadStart: (controller, url) {
                debugPrint('🌐 [KCP Cert] 페이지 로드 시작: $url');
                _detectCallbackPage(controller, url);
              },
              onLoadStop: (controller, url) async {
                if (!mounted) {
                  return;
                }

                setState(() {
                  _isLoading = false;
                });

                debugPrint('🌐 [KCP Cert] 페이지 로드 완료: $url');
                await _detectCallbackPage(controller, url);
              },
              onReceivedError: (controller, request, error) {
                debugPrint('❌ [KCP Cert] 에러 발생: ${error.description}');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('본인인증 중 오류가 발생했습니다: ${error.description}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          if (_errorMessage != null) _buildErrorView(),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage ?? '알 수 없는 오류가 발생했습니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeKcpRequest,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _detectCallbackPage(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    if (_hasNavigated) {
      return;
    }

    final urlText = url?.toString() ?? '';
    if (urlText.contains('/api/auth/kcp/callback')) {
      _startPollingResult();
      return;
    }

    try {
      const script = '''
        (function() {
          try {
            var body = document.body;
            return JSON.stringify({
              href: window.location.href,
              token: body ? body.getAttribute('data-kcp-token') : '',
              success: body ? body.getAttribute('data-kcp-success') : '',
              text: body && body.innerText ? body.innerText.substring(0, 500) : ''
            });
          } catch (e) {
            return JSON.stringify({ error: String(e) });
          }
        })();
      ''';

      final result = await controller.evaluateJavascript(source: script);
      final parsed = _parseJavascriptResult(result);
      final token = (parsed['token'] ?? '').toString();

      if (token.isNotEmpty) {
        _requestToken = token;
        _startPollingResult();
      }
    } catch (e) {
      debugPrint('❌ [KCP Cert] callback 감지 실패: $e');
    }
  }

  Map<String, dynamic> _parseJavascriptResult(dynamic result) {
    try {
      if (result is String && result.isNotEmpty) {
        final decoded = jsonDecode(result);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (_) {}

    return <String, dynamic>{};
  }

  void _startPollingResult() {
    if (_requestToken == null || _requestToken!.isEmpty || _hasNavigated) {
      return;
    }

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollKcpResult();
    });
    _pollKcpResult();
  }

  Future<void> _pollKcpResult() async {
    final token = _requestToken;
    if (token == null || token.isEmpty || _hasNavigated || !mounted) {
      return;
    }

    try {
      final response = await ApiClient.get('/api/auth/kcp/result/$token');

      if (response.statusCode == 404) {
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint('📥 [KCP Cert] polling 결과: ${jsonEncode(data)}');

      final status = (data['status'] ?? '').toString();
      final completed = data['cert_completed'] == true;

      if (status == 'pending' && !completed) {
        return;
      }

      _pollingTimer?.cancel();

      if (data['success'] == true && completed) {
        _hasNavigated = true;
        final certInfo = {
          'cert_completed': true,
          'name': data['name'],
          'phone': data['phone'],
          'birthday': data['birthday'],
          'sex_code': data['sex_code'],
          'gender': data['gender'],
          'ci': data['ci'],
          'di': data['di'],
          'kcp_raw': data,
        };

        if (widget.flow == 'find-account') {
          Navigator.pushReplacementNamed(
            context,
            '/find-account-result',
            arguments: certInfo,
          );
          return;
        }

        if (widget.flow == 'find-password') {
          final email = (widget.email ?? '').trim();
          final result = await AuthRepository.forgotPassword(
            email: email,
            name: (data['name'] ?? '').toString(),
            phone: (data['phone'] ?? '').toString(),
          );

          if (!mounted) return;

          if (result['success'] == true) {
            Navigator.pushReplacementNamed(
              context,
              '/find-password-reset',
              arguments: {
                ...certInfo,
                'email': email,
              },
            );
          } else {
            Navigator.pushReplacementNamed(
              context,
              '/find-account-not-found',
              arguments: {
                ...certInfo,
                'email': email,
                'mode': 'password',
              },
            );
          }
          return;
        }

        Navigator.pushReplacementNamed(
          context,
          '/signup',
          arguments: certInfo,
        );
        return;
      }

      final message =
          (data['message'] ?? data['res_msg'] ?? '본인인증에 실패했습니다.').toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      debugPrint('❌ [KCP Cert] polling 오류: $e');
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _webViewController = null;
    super.dispose();
  }
}
