import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class KcpPayWebViewScreen extends StatefulWidget {
  const KcpPayWebViewScreen({
    super.key,
    required this.html,
    required this.token,
    this.usePcLayout = false,
  });

  final String html;
  final String token;
  final bool usePcLayout;

  @override
  State<KcpPayWebViewScreen> createState() => _KcpPayWebViewScreenState();
}

class _KcpPayWebViewScreenState extends State<KcpPayWebViewScreen> {
  static const String _iosSafariUa =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';
  static const String _androidChromeUa =
      'Mozilla/5.0 (Linux; Android 14; Mobile; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36';

  /// payplus / Chromium 이 PC로 분기하지 않도록 UA·userAgentData·touch 강제
  static String get _forceMobileUaScript {
    final ua = defaultTargetPlatform == TargetPlatform.iOS
        ? _iosSafariUa
        : _androidChromeUa;
    final platform =
        defaultTargetPlatform == TargetPlatform.iOS ? 'iPhone' : 'Android';
    return '''
(function () {
  var MOBILE_UA = ${jsonEncode(ua)};
  var PLATFORM = ${jsonEncode(platform)};
  function spoof(obj, prop, value) {
    try {
      Object.defineProperty(obj, prop, {
        configurable: true,
        get: function () { return value; }
      });
    } catch (e) {}
  }
  try {
    spoof(Navigator.prototype, 'userAgent', MOBILE_UA);
    spoof(Navigator.prototype, 'appVersion', MOBILE_UA);
    spoof(Navigator.prototype, 'platform', PLATFORM === 'iPhone' ? 'iPhone' : 'Linux armv8l');
    spoof(Navigator.prototype, 'vendor', 'Google Inc.');
    spoof(Navigator.prototype, 'maxTouchPoints', 5);
    spoof(Navigator.prototype, 'userAgentData', {
      mobile: true,
      platform: PLATFORM,
      brands: [
        { brand: 'Chromium', version: '123' },
        { brand: 'Google Chrome', version: '123' }
      ],
      getHighEntropyValues: function () {
        return Promise.resolve({
          mobile: true,
          platform: PLATFORM,
          model: 'Pixel 7',
          uaFullVersion: '123.0.0.0'
        });
      }
    });
  } catch (e) {}
  try {
    var mm = window.matchMedia;
    window.matchMedia = function (q) {
      try {
        if (String(q).indexOf('pointer: fine') >= 0) {
          return { matches: false, media: q, addListener: function(){}, removeListener: function(){}, addEventListener: function(){}, removeEventListener: function(){}, onchange: null, dispatchEvent: function(){ return false; } };
        }
        if (String(q).indexOf('pointer: coarse') >= 0 || String(q).indexOf('hover: none') >= 0) {
          return { matches: true, media: q, addListener: function(){}, removeListener: function(){}, addEventListener: function(){}, removeEventListener: function(){}, onchange: null, dispatchEvent: function(){ return false; } };
        }
      } catch (e2) {}
      return mm ? mm.call(window, q) : { matches: false, media: q };
    };
  } catch (e3) {}
})();
''';
  }

  /// PC 결제 레이어가 뜨면 화면 폭에 맞게 확대
  static const String _fitPaymentLayerScript = r'''
(function () {
  function fit() {
    try {
      var meta = document.querySelector('meta[name="viewport"]');
      if (!meta) {
        meta = document.createElement('meta');
        meta.name = 'viewport';
        document.head.appendChild(meta);
      }
      meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
      document.documentElement.style.width = '100%';
      document.body.style.width = '100%';
      document.body.style.margin = '0';
      document.body.style.padding = '0';
      document.body.style.overflowX = 'hidden';

      var nodes = document.querySelectorAll(
        'iframe, [id*="kcp"], [class*="kcp"], [id*="pay"], [class*="pay"], [id*="layer"], [class*="layer"]'
      );
      for (var i = 0; i < nodes.length; i++) {
        var el = nodes[i];
        if (!el || !el.style) continue;
        el.style.maxWidth = '100vw';
        el.style.width = '100%';
        if (el.tagName === 'IFRAME') {
          el.style.minHeight = '80vh';
          el.setAttribute('width', '100%');
        }
      }
    } catch (e) {}
  }
  fit();
  setInterval(fit, 700);
})();
''';

  Timer? _pollingTimer;
  bool _completed = false;

  String get _launchUrl =>
      '${ApiClient.baseUrl}/api/kcp-pay/launch/${Uri.encodeComponent(widget.token)}';

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
        final resCd = (data['res_cd'] ?? '').toString().trim();
        final orderId = (data['order_id'] ?? '').toString().trim();
        if (resCd == '0000' && orderId.isNotEmpty) {
          _completed = true;
          _pollingTimer?.cancel();
          if (!mounted) return;
          Navigator.pop(context, {
            'success': true,
            'order_id': orderId,
            'message': (data['message'] ?? '가상계좌 발급이 완료되었습니다.').toString(),
          });
        }
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

  Future<void> _injectHelpers(InAppWebViewController controller) async {
    try {
      await controller.evaluateJavascript(source: _forceMobileUaScript);
      await controller.evaluateJavascript(source: _fitPaymentLayerScript);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final usePc = widget.usePcLayout || kIsWeb;
    final ua = usePc ? null : _mobileUserAgent();
    final size = MediaQuery.sizeOf(context);
    final sheetWidth = usePc ? size.width.clamp(360.0, 720.0) : size.width;
    final sheetHeight = usePc ? size.height * 0.92 : size.height;
    final inlineHtml = widget.html.trim();
    final useInlineHtml = inlineHtml.isNotEmpty;

    final webView = InAppWebView(
              initialData: useInlineHtml
                  ? InAppWebViewInitialData(
                      data: inlineHtml,
                      baseUrl: WebUri('${ApiClient.baseUrl}/'),
                      mimeType: 'text/html',
                      encoding: 'utf-8',
                    )
                  : null,
              initialUrlRequest: useInlineHtml
                  ? null
                  : URLRequest(
                      url: WebUri(_launchUrl),
                      headers: ua != null ? {'User-Agent': ua} : null,
                    ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                cacheEnabled: false,
                clearCache: true,
                userAgent: ua,
                preferredContentMode: usePc
                    ? UserPreferredContentMode.RECOMMENDED
                    : UserPreferredContentMode.MOBILE,
                javaScriptCanOpenWindowsAutomatically: true,
                supportMultipleWindows: !usePc,
                thirdPartyCookiesEnabled: true,
                sharedCookiesEnabled: true,
                useHybridComposition: true,
                useWideViewPort: true,
                loadWithOverviewMode: true,
                builtInZoomControls: false,
                displayZoomControls: false,
                supportZoom: false,
                allowsInlineMediaPlayback: true,
                mediaPlaybackRequiresUserGesture: false,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              ),
              initialUserScripts: usePc
                  ? null
                  : UnmodifiableListView<UserScript>([
                      UserScript(
                        source: _forceMobileUaScript,
                        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                        forMainFrameOnly: false,
                      ),
                      UserScript(
                        source: _fitPaymentLayerScript,
                        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
                        forMainFrameOnly: false,
                      ),
                    ]),
              onWebViewCreated: (controller) async {
                if (ua == null) return;
                try {
                  await controller.setSettings(
                    settings: InAppWebViewSettings(
                      userAgent: ua,
                      preferredContentMode: UserPreferredContentMode.MOBILE,
                    ),
                  );
                } catch (_) {}
              },
              onCreateWindow: usePc
                  ? null
                  : (controller, createWindowAction) async {
                await showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) {
                    return Scaffold(
                      body: InAppWebView(
                        windowId: createWindowAction.windowId,
                        initialSettings: InAppWebViewSettings(
                          javaScriptEnabled: true,
                          userAgent: ua,
                          preferredContentMode:
                              UserPreferredContentMode.MOBILE,
                          javaScriptCanOpenWindowsAutomatically: true,
                          supportMultipleWindows: true,
                          thirdPartyCookiesEnabled: true,
                          sharedCookiesEnabled: true,
                          useHybridComposition: true,
                          useWideViewPort: true,
                          loadWithOverviewMode: true,
                        ),
                        initialUserScripts: UnmodifiableListView<UserScript>([
                          UserScript(
                            source: _forceMobileUaScript,
                            injectionTime:
                                UserScriptInjectionTime.AT_DOCUMENT_START,
                            forMainFrameOnly: false,
                          ),
                        ]),
                        onCloseWindow: (c) {
                          if (Navigator.of(dialogContext).canPop()) {
                            Navigator.pop(dialogContext);
                          }
                        },
                      ),
                    );
                  },
                );
                return true;
              },
              onLoadStop: (controller, url) async {
                if (!mounted) return;
                if (!usePc) {
                  await _injectHelpers(controller);
                }
                final text = url?.toString() ?? '';
                if (text.contains('/api/kcp-pay/callback')) {
                  await _pollResult();
                }
              },
              onLoadStart: (controller, url) async {
                final text = url?.toString() ?? '';
                if (text.contains('/api/kcp-pay/callback')) {
                  _pollResult();
                }
              },
            );

    return WillPopScope(
      onWillPop: () async {
        _returnUserCancelled();
        return false;
      },
      child: usePc
          ? Material(
              color: Colors.transparent,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: sheetWidth,
                    height: sheetHeight,
                    child: Scaffold(
                      body: SafeArea(
                        bottom: false,
                        child: webView,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : Scaffold(
              body: SafeArea(
                bottom: false,
                child: webView,
              ),
            ),
    );
  }
}
