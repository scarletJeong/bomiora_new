import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../core/navigation/app_navigator_key.dart';
import '../../../core/network/api_client.dart';
import '../../../data/repositories/auth/auth_repository.dart';
import '../../common/widgets/app_bar.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import 'kcp_cert_postmessage.dart';

bool _isTruthy(dynamic value) {
  if (value == true) return true;
  if (value is num && value != 0) return true;
  final s = value?.toString().trim().toLowerCase() ?? '';
  return s == 'true' || s == '1' || s == 'y' || s == 'yes';
}

/// 서버별로 [cert_completed] / [completed] / [status] 만 내려주는 경우가 있어 폴링 완료 판정을 넓힌다.
bool _kcpResultIndicatesCertDone(Map<String, dynamic> data) {
  if (_isTruthy(data['cert_completed'])) return true;
  if (_isTruthy(data['certCompleted'])) return true;
  if (_isTruthy(data['completed'])) return true;
  final s = (data['status'] ?? '').toString().trim().toLowerCase();
  return s == 'completed' || s == 'success' || s == 'ok' || s == 'done';
}

String _extractMbDupinfo(Map<String, dynamic> data) {
  for (final k in ['mb_dupinfo', 'mbDupinfo', 'dupinfo', 'dupInfo', 'DI', 'di']) {
    final v = data[k]?.toString().trim();
    if (v != null && v.isNotEmpty) return v;
  }
  final raw = data['kcp_raw'];
  if (raw is Map) {
    return _extractMbDupinfo(Map<String, dynamic>.from(raw));
  }
  return '';
}

/// KCP가 `window.open` / `target=_blank|_top|_parent` 로 탭·탑 창을 띄울 때
/// Flutter Web iframe 밖으로 나가지 않도록 막는다.
const String _kcpSingleWindowUserScriptSource = r'''
(function () {
  try {
    window.open = function (u, name, features) {
      try {
        if (u != null && u !== '') {
          var s = (typeof u === 'string') ? u : String(u);
          if (s !== 'about:blank') {
            window.location.href = s;
            return window;
          }
        }
      } catch (e) {}
      return window;
    };
  } catch (e) {}
  function kcpNormalizeFrameTargets() {
    try {
      var els = document.querySelectorAll('a[target], form[target]');
      for (var i = 0; i < els.length; i++) {
        var el = els[i];
        var t = (el.getAttribute('target') || '').toString().toLowerCase().trim();
        if (t === '_top' || t === '_parent' || t === '_blank') {
          el.setAttribute('target', '_self');
        }
      }
    } catch (e) {}
  }
  try {
    kcpNormalizeFrameTargets();
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', kcpNormalizeFrameTargets);
    }
    try {
      var mo = new MutationObserver(function () {
        kcpNormalizeFrameTargets();
      });
      mo.observe(document.documentElement, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ['target']
      });
    } catch (e2) {}
  } catch (e3) {}
})();
''';

UnmodifiableListView<UserScript> get _kcpSingleWindowUserScripts =>
    UnmodifiableListView<UserScript>([
      UserScript(
        source: _kcpSingleWindowUserScriptSource,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: false,
      ),
    ]);

String _hardenKcpHtmlForSingleWindow(String html) {
  // 최초 요청 HTML에도 동일 스크립트를 넣어, 첫 로드부터 새 창을 막는다.
  const injected = '<script>$_kcpSingleWindowUserScriptSource</script>';

  // 1) 흔한 target 을 정적으로 우선 치환(iframe 이탈·새 탭 방지)
  var out = html
      .replaceAll('target="_blank"', 'target="_self"')
      .replaceAll("target='_blank'", "target='_self'")
      .replaceAll('target="_top"', 'target="_self"')
      .replaceAll("target='_top'", "target='_self'")
      .replaceAll('target="_parent"', 'target="_self"')
      .replaceAll("target='_parent'", "target='_self'");

  // 2) <head> 바로 뒤에 주입(없으면 맨 앞에 프리펜드)
  final headIdx = out.toLowerCase().indexOf('<head');
  if (headIdx >= 0) {
    final headEnd = out.indexOf('>', headIdx);
    if (headEnd >= 0) {
      out = out.substring(0, headEnd + 1) + injected + out.substring(headEnd + 1);
      debugPrint('[KCP] hardenKcpHtml: script injected after <head>');
      return out;
    }
    debugPrint('[KCP] hardenKcpHtml: <head> without closing >, prepend script');
  } else {
    debugPrint('[KCP] hardenKcpHtml: no <head>, prepend script');
  }
  return injected + out;
}

class KcpCertWebViewScreen extends StatefulWidget {
  const KcpCertWebViewScreen({
    super.key,
    this.flow = 'signup',
    this.email,
    /// true: 회원가입 부모 위에 뜬 모달 — 성공 시 [Navigator.pop]으로 [certInfo] 전달, 취소 시 `null`
    this.popResultToParent = false,
    /// true: 하얀 배경 대신 반투명 딤 + 카드(원래 화면이 비치도록)
    this.overlayStyle = false,
  });

  final String flow;
  final String? email;
  final bool popResultToParent;
  final bool overlayStyle;

  @override
  State<KcpCertWebViewScreen> createState() => _KcpCertWebViewScreenState();
}

class _KcpCertWebViewScreenState extends State<KcpCertWebViewScreen> {
  Timer? _pollingTimer;
  Timer? _kcpCallbackCloseTimer;

  bool _hasNavigated = false;
  bool _blockBack = false;
  bool _obscureWebViewAfterKcpCallback = false;
  bool _kcpCallbackCloseScheduled = false;
  Map<String, dynamic>? _lastCertInfo;
  String? _initialHtml;
  String? _requestToken;
  String? _errorMessage;
  /// 웹: 콜백 URL에 대해 shouldOverride→loadUrl이 중복 호출되는 것 방지
  String? _lastWebCallbackHandledUrl;

  /// 웹: KCP 콜백 팝업이 `window.opener.postMessage`로 알림을 보낼 때 상위 탭에서 수신
  final KcpWebPostMessageListener _webPostMessage = KcpWebPostMessageListener();

  static const Duration _kcpCallbackAutoCloseDelay = Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    if (kIsWeb && widget.popResultToParent) {
      debugPrint('[KCP] init: web overlay → PopScope 생략');
    } else {
      debugPrint(
        '[KCP] init: kIsWeb=$kIsWeb popResultToParent=${widget.popResultToParent} '
        'flow=${widget.flow} overlayStyle=${widget.overlayStyle}',
      );
    }
    if (kIsWeb) {
      _webPostMessage.start(_onKcpWebPostMessage);
      debugPrint('[KCP] init: window postMessage 리스너 등록 (KCP_CERT_DONE)');
    }
    _initializeKcpRequest();
  }

  /// 콜백 HTML이 `opener.postMessage({ type: KCP_CERT_DONE })` 를내면 폴링을 즉시 한 번 돌린다.
  void _onKcpWebPostMessage() {
    if (!mounted) return;
    debugPrint('[KCP] postMessage: KCP_CERT_DONE 수신');
    final token = _requestToken;
    if (token == null || token.isEmpty) {
      debugPrint('[KCP] postMessage: requestToken 없음 → poll 스킵');
      return;
    }
    if (_hasNavigated) {
      debugPrint('[KCP] postMessage: 이미 완료 처리됨 → 스킵');
      return;
    }
    unawaited(_pollKcpResult());
  }

  Future<void> _initializeKcpRequest() async {
    debugPrint('[KCP] _initializeKcpRequest: start');
    _kcpCallbackCloseTimer?.cancel();
    _kcpCallbackCloseTimer = null;
    _kcpCallbackCloseScheduled = false;
    setState(() {
      _errorMessage = null;
      _initialHtml = null;
      _requestToken = null;
      _obscureWebViewAfterKcpCallback = false;
      _lastWebCallbackHandledUrl = null;
    });

    try {
      final response = await ApiClient.get('/api/auth/kcp/request');
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 || data['success'] != true) {
        debugPrint(
          '[KCP] _initializeKcpRequest: API 실패 status=${response.statusCode} success=${data['success']}',
        );
        throw Exception(data['message'] ?? 'KCP 요청 데이터 생성에 실패했습니다.');
      }

      final html = (data['html'] ?? '').toString();
      final token = (data['token'] ?? '').toString();

      if (html.isEmpty || token.isEmpty) {
        debugPrint(
          '[KCP] _initializeKcpRequest: 빈 html/token (htmlLen=${html.length} tokenLen=${token.length})',
        );
        throw Exception('KCP 요청 응답이 올바르지 않습니다.');
      }

      if (!mounted) {
        debugPrint('[KCP] _initializeKcpRequest: 성공 응답 후 unmounted → 스킵');
        return;
      }

      debugPrint('[KCP] request ok. token=$token');
      final hardenedHtml = _hardenKcpHtmlForSingleWindow(html);

      // 웹도 별도 브라우저 팝업을 쓰지 않는다. 팝업은 첫 창만 추적되어 telcomSelect 두 번째 창을
      // 닫을 수 없고, cert.kcp 도메인에는 주입 스크립트를 넣을 수 없어 이중 창이 생긴다.
      // InAppWebView + UserScript 로 동일 창에서만 진행한다.
      if (mounted) {
        setState(() {
          _initialHtml = hardenedHtml;
          _requestToken = token;
        });
        debugPrint('[KCP] _initializeKcpRequest: setState html+token 완료');
      } else {
        debugPrint('[KCP] _initializeKcpRequest: mounted=false setState 스킵');
      }

      _startPollingResult();
    } catch (e) {
      debugPrint('[KCP] _initializeKcpRequest: catch $e');
      if (!mounted) {
        debugPrint('[KCP] _initializeKcpRequest: catch 후 unmounted → 에러 UI 스킵');
        return;
      }

      setState(() {
        _errorMessage = '본인인증 준비 중 오류가 발생했습니다.\n$e';
      });
      debugPrint('[KCP] _initializeKcpRequest: 에러 메시지 표시');
    }
  }

  void _onLeadingBack() {
    if (_blockBack) {
      debugPrint('[KCP] _onLeadingBack: _blockBack=true → 무시');
      return;
    }
    if (widget.popResultToParent) {
      debugPrint('[KCP] _onLeadingBack: Navigator.pop(null) (오버레이 취소)');
      Navigator.pop(context, null);
    } else {
      debugPrint('[KCP] _onLeadingBack: Navigator.maybePop');
      Navigator.maybePop(context);
    }
  }

  /// 회원가입 오버레이 등 [popResultToParent] 라우트를 웹에서도 확실히 닫는다.
  /// 아이디/비번 찾기 등: 오버레이·웹뷰 콜백 직후 [context] 네비게이션이 누락되는 경우를 줄이기 위해
  /// [appNavigatorKey] + post-frame 으로 [pushReplacementNamed] 한다.
  void _pushReplacementNamedAfterFrame(String routeName, [Object? arguments]) {
    void go() {
      if (!mounted) return;
      final keyNav = appNavigatorKey.currentState;
      if (keyNav != null) {
        keyNav.pushReplacementNamed(routeName, arguments: arguments);
      } else {
        Navigator.of(context).pushReplacementNamed(routeName, arguments: arguments);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      go();
    });
  }

  void _popKcpCertOverlay(Object? result) {
    if (!mounted) {
      debugPrint('[KCP] _popKcpCertOverlay: unmounted → 스킵');
      return;
    }

    void attemptPop() {
      if (!mounted) {
        debugPrint('[KCP] _popKcpCertOverlay.attemptPop: unmounted → 스킵');
        return;
      }
      debugPrint('[KCP] overlay pop begin (kIsWeb=$kIsWeb)');
      var popped = false;
      void tryPop(String label, NavigatorState nav) {
        if (popped) return;
        if (nav.canPop()) {
          nav.pop(result);
          popped = true;
          debugPrint('[KCP] overlay pop ok ($label)');
        } else {
          debugPrint('[KCP] overlay pop skip ($label): canPop=false');
        }
      }

      try {
        tryPop('default', Navigator.of(context));
        tryPop('root', Navigator.of(context, rootNavigator: true));
        final keyNav = appNavigatorKey.currentState;
        if (!popped && keyNav != null && keyNav.canPop()) {
          keyNav.pop(result);
          popped = true;
          debugPrint('[KCP] overlay pop ok (appNavigatorKey)');
        } else if (!popped && keyNav == null) {
          debugPrint('[KCP] overlay pop skip (appNavigatorKey): keyNav=null');
        } else if (!popped && keyNav != null && !keyNav.canPop()) {
          debugPrint('[KCP] overlay pop skip (appNavigatorKey): canPop=false');
        }
        if (!popped) {
          debugPrint(
            '[KCP] overlay pop: canPop=false (default/root/key) — route may not be on stack',
          );
        }
      } catch (e, st) {
        debugPrint('[KCP] overlay pop failed: $e\n$st');
      }
    }

    // 웹: 다음 프레임까지 미루면 pop이 먹지 않는 경우가 있어 동기 시도.
    if (kIsWeb) {
      debugPrint('[KCP] _popKcpCertOverlay: 웹 → attemptPop 동기 호출');
      attemptPop();
      return;
    }

    debugPrint('[KCP] _popKcpCertOverlay: 네이티브 → postFrame attemptPop');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      attemptPop();
    });
  }

  Widget _buildWebViewOrError() {
    if (_errorMessage != null) {
      debugPrint('[KCP] _buildWebViewOrError: 분기 errorView');
      return _buildErrorView();
    }
    if (_initialHtml == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF5A8D)),
      );
    }
    if (_obscureWebViewAfterKcpCallback) {
      debugPrint('[KCP] _buildWebViewOrError: 분기 완료 안내(웹뷰 가림)');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFFFF5A8D)),
              const SizedBox(height: 16),
              Text(
                '본인인증이 완료되었습니다.\n화면을 닫는 중입니다…',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return InAppWebView(
      initialData: InAppWebViewInitialData(data: _initialHtml!),
      initialUserScripts: _kcpSingleWindowUserScripts,
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        // false면 KCP 일부 단계에서 window.open 이 막혀 인증 완료·콜백이 안 되는 경우가 있음.
        // 새 창 요청은 [onCreateWindow] + 위 UserScript로 같은 WebView에 흡수한다.
        javaScriptCanOpenWindowsAutomatically: true,
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
        // KCP가 window.open으로 새 창을 띄우는 경우가 있어, 새 WebView가 남아 빈 화면이 되는 것을 방지한다.
        supportMultipleWindows: true,
        // iOS 등에서 targetFrame 없이 새 창으로 열리려는 http(s) 내비게이션을 같은 WebView로 당긴다.
        useShouldOverrideUrlLoading: true,
      ),
      onWebViewCreated: (_) {
        debugPrint('[KCP] onWebViewCreated');
      },
      onCreateWindow: (controller, createWindowRequest) async {
        // 새 창을 만들지 않고, 현재 WebView에서 URL을 연다. (POST body 등은 request 전체 유지)
        final req = createWindowRequest.request;
        debugPrint('[KCP] onCreateWindow url=${req.url}');
        if (req.url != null) {
          await controller.loadUrl(urlRequest: req);
          debugPrint('[KCP] onCreateWindow: loadUrl 완료');
        } else {
          debugPrint('[KCP] onCreateWindow: url=null → loadUrl 스킵');
        }
        return false;
      },
      onCloseWindow: (controller) {
        debugPrint('[KCP] onCloseWindow (window.close 등)');
        if (!mounted || _hasNavigated) return;
        if (_requestToken != null && _requestToken!.isNotEmpty) {
          unawaited(_pollKcpResult());
        }
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final url = navigationAction.request.url;
        // Flutter Web: 콜백이 탑 창이 아닌 동일 iframe에서만 열리도록 강제
        if (kIsWeb && url != null) {
          final s = url.toString();
          if (s.contains('/api/auth/kcp/callback')) {
            if (_lastWebCallbackHandledUrl == s) {
              debugPrint(
                '[KCP] shouldOverrideUrlLoading(web): callback 중복 URL → ALLOW',
              );
              return NavigationActionPolicy.ALLOW;
            }
            _lastWebCallbackHandledUrl = s;
            debugPrint('[KCP] shouldOverrideUrlLoading(web): callback → loadUrl 동일 WebView');
            await controller.loadUrl(urlRequest: URLRequest(url: url));
            return NavigationActionPolicy.CANCEL;
          }
        }
        // Android 포함: targetFrame 없는 http(s) 내비는 새 WebView/외부창으로 새는 경우가 많아
        // 동일 WebView로 당긴다(iOS·macOS만 하던 제한 제거).
        if (url != null && !kIsWeb) {
          final tf = navigationAction.targetFrame;
          if (tf == null) {
            final s = url.toString();
            if (s.startsWith('http://') || s.startsWith('https://')) {
              debugPrint(
                '[KCP] shouldOverrideUrlLoading: new-window nav -> same WebView url=$s',
              );
              await controller.loadUrl(urlRequest: navigationAction.request);
              return NavigationActionPolicy.CANCEL;
            }
          }
        }
        if (url != null) {
          final scheme = url.scheme.toLowerCase();
          if (scheme == 'tel' || scheme == 'mailto' || scheme == 'sms') {
            debugPrint('[KCP] shouldOverrideUrlLoading: CANCEL (scheme=$scheme)');
            return NavigationActionPolicy.CANCEL;
          }
        }
        return NavigationActionPolicy.ALLOW;
      },
      onJsAlert: (controller, jsAlertRequest) async {
        final msg = (jsAlertRequest.message ?? '').toString();
        if (msg.contains('팝업창 차단')) {
          debugPrint('[KCP] onJsAlert: 팝업 차단 분기 msg=$msg');
          // 팝업 차단 안내가 뜨면 더 진행해봐야 실패 화면만 남는 케이스가 있어 즉시 종료한다.
          if (widget.popResultToParent) {
            if (mounted) {
              debugPrint('[KCP] onJsAlert: Navigator.pop(popupBlocked)');
              Navigator.pop(context, {'popupBlocked': true});
            } else {
              debugPrint('[KCP] onJsAlert: unmounted → pop 스킵');
            }
          } else {
            if (mounted) {
              debugPrint('[KCP] onJsAlert: maybePop');
              Navigator.maybePop(context);
            } else {
              debugPrint('[KCP] onJsAlert: maybePop unmounted 스킵');
            }
          }
          return JsAlertResponse(
            handledByClient: true,
            action: JsAlertResponseAction.CONFIRM,
          );
        }
        debugPrint('[KCP] onJsAlert: 기본 처리(미차단) msg=${msg.length > 80 ? "${msg.substring(0, 80)}…" : msg}');
        return JsAlertResponse(
          handledByClient: false,
          action: JsAlertResponseAction.CONFIRM,
        );
      },
      onLoadStart: (controller, url) {
        debugPrint('[KCP] loadStart url=$url');
        _detectCallbackPage(controller, url);
      },
      onLoadStop: (controller, url) async {
        if (!mounted) {
          debugPrint('[KCP] onLoadStop: unmounted → 스킵 url=$url');
          return;
        }

        // KCP 페이지에서 window.open을 호출해 새창을 띄우는 경우가 있어,
        // 동일 WebView에서 열리도록 window.open을 덮어쓴다.
        try {
          await controller.evaluateJavascript(source: _kcpSingleWindowUserScriptSource);
          debugPrint('[KCP] onLoadStop: window.open 주입 스크립트 실행 OK');
        } catch (e) {
          debugPrint('[KCP] onLoadStop: 주입 스크립트 실패(무시): $e');
        }

        debugPrint('[KCP] loadStop url=$url');
        await _detectCallbackPage(controller, url);
      },
      onReceivedError: (controller, request, error) {
        debugPrint('[KCP] onReceivedError: ${error.description} url=${request.url}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('본인인증 중 오류가 발생했습니다: ${error.description}'),
              backgroundColor: Colors.red,
            ),
          );
          debugPrint('[KCP] onReceivedError: SnackBar 표시');
        } else {
          debugPrint('[KCP] onReceivedError: unmounted → SnackBar 스킵');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOverlay = widget.popResultToParent || widget.overlayStyle;

    final page = MobileAppLayoutWrapper(
      appBar: HealthAppBar(
        title: '본인인증',
        onBack: _onLeadingBack,
      ),
      // 오버레이 모드에서는 wrapper의 바깥 배경(기본 grey[100])이 불투명이라,
      // 투명으로 바꿔 기존 화면 위 딤이 보이게 한다.
      outerBackgroundColor: isOverlay ? Colors.transparent : null,
      backgroundColor: isOverlay ? Colors.transparent : null,
      showShadow: !isOverlay,
      child: isOverlay
          ? Stack(
              children: [
                // 오버레이 모드: 카드 UI 없이 WebView를 그대로 표시
                // (KCP 창이 같은 WebView에서 열리므로, 숨기면 아무것도 안 뜸)
                Positioned.fill(child: _buildWebViewOrError()),
              ],
            )
          : _buildWebViewOrError(),
    );

    if (!widget.popResultToParent) {
      return page;
    }

    // 웹: PopScope + 내비게이션 조합에서 pop이 호출돼도 라우트가 안 빠지는 경우가 있어
    // 회원가입 오버레이는 PopScope 없이 둔다(앱바 뒤로가기로 취소는 그대로 동작).
    if (kIsWeb) {
      return page;
    }

    // 앱: 완료 안내 구간에서 시스템 뒤로가기만 막고, 완료 후에는 pop 허용.
    return PopScope(
      canPop: !_blockBack || _hasNavigated,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          debugPrint('[KCP] PopScope onPopInvoked: didPop=true (이미 pop됨)');
          return;
        }
        debugPrint(
          '[KCP] PopScope: pop 미완료(didPop=false). '
          'canPop=${!_blockBack || _hasNavigated} _blockBack=$_blockBack _hasNavigated=$_hasNavigated — fallback pop 시도',
        );
        try {
          debugPrint('[KCP] PopScope: fallback Navigator.pop(null)');
          Navigator.pop(context, null);
        } catch (e, st) {
          debugPrint('[KCP] PopScope: fallback Navigator.pop 실패: $e\n$st');
        }
      },
      child: page,
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

  /// 콜백 URL 쿼리의 token(폴링용) — 초기 요청에서 토큰을 못 받은 경우에만 채움
  void _syncRequestTokenFromCallbackUrl(String callbackUrlFull) {
    try {
      final u = Uri.parse(callbackUrlFull);
      final t = u.queryParameters['token'] ??
          u.queryParameters['request_token'] ??
          '';
      if (t.isEmpty) return;
      if (_requestToken != null && _requestToken!.isNotEmpty) return;
      _requestToken = t;
      debugPrint('[KCP] requestToken filled from callback URL query');
    } catch (e) {
      debugPrint('[KCP] sync token from callback url failed: $e');
    }
  }

  void _onKcpCallbackUrlSeen(
    InAppWebViewController controller,
    String callbackUrlFull,
  ) {
    _syncRequestTokenFromCallbackUrl(callbackUrlFull);
    _startPollingResult();
    _scheduleKcpCallbackPageAutoClose(controller);
  }

  Future<void> _detectCallbackPage(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    if (_hasNavigated) {
      debugPrint('[KCP] _detectCallbackPage: _hasNavigated=true → 스킵');
      return;
    }

    final urlText = url?.toString() ?? '';
    if (urlText.isNotEmpty) {
      debugPrint('[KCP] detect url=$urlText');
    } else {
      debugPrint('[KCP] _detectCallbackPage: url 비어 있음(JS 분기만 시도)');
    }
    if (urlText.contains('/api/auth/kcp/callback')) {
      debugPrint('[KCP] _detectCallbackPage: 콜백 URL 매칭(network url)');
      _onKcpCallbackUrlSeen(controller, urlText);
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
      final text = (parsed['text'] ?? '').toString();
      if (token.isNotEmpty || text.isNotEmpty) {
        debugPrint(
          '[KCP] js token=${token.isEmpty ? "-" : token} text="${text.replaceAll("\n", " ")}"',
        );
      } else {
        debugPrint('[KCP] _detectCallbackPage: JS에서 token/text 둘 다 비어 있음');
      }

      final href = (parsed['href'] ?? '').toString();
      if (href.contains('/api/auth/kcp/callback') &&
          !urlText.contains('/api/auth/kcp/callback')) {
        debugPrint('[KCP] _detectCallbackPage: 콜백 URL(JS location.href만 일치)');
        _onKcpCallbackUrlSeen(controller, href);
        return;
      }

      // KCP 완료 안내(“앱으로 돌아가 주세요”) 화면에서는 뒤로가기를 막는다.
      final isCompletionNotice = !_blockBack &&
          (text.contains('앱으로 돌아가') ||
              text.contains('인증결과가 저장') ||
              text.contains('본인인증이 완료') ||
              text.contains('인증이 완료') ||
              text.contains('본인확인이 완료') ||
              text.contains('휴대폰 본인인증이 완료'));
      if (isCompletionNotice) {
        debugPrint('[KCP] completion notice detected. auto-close try.');
        if (mounted) {
          setState(() => _blockBack = true);
        } else {
          _blockBack = true;
        }

        // 이미 인증 결과가 있으면 [_pollKcpResult]가 1.2초 대기 후 닫는다(이중 pop 방지).
        if (_lastCertInfo != null) {
          debugPrint('[KCP] completion notice: certInfo 이미 있음 → poll이 닫음');
          return;
        }

        // 아직 결과가 없으면 즉시 1회 폴링을 트리거하고, 짧게 기다렸다가 결과가 생기면 자동 종료한다.
        await _pollKcpResult();
        if (!mounted) {
          debugPrint('[KCP] completion notice: poll 후 unmounted');
          return;
        }
        await Future.delayed(const Duration(milliseconds: 350));
        if (!mounted) {
          debugPrint('[KCP] completion notice: delay 후 unmounted');
          return;
        }
        if (_lastCertInfo != null) {
          debugPrint('[KCP] certInfo after notice/poll; poll branch handles close.');
          return;
        }
        debugPrint('[KCP] still no certInfo after notice; ensure polling continues.');
        _startPollingResult();
      } else {
        debugPrint('[KCP] _detectCallbackPage: completion notice 아님');
      }

      if (token.isNotEmpty) {
        debugPrint('[KCP] _detectCallbackPage: body data-kcp-token → 폴링 시작');
        _requestToken = token;
        _startPollingResult();
      }
    } catch (e) {
      debugPrint('[KCP] detectCallbackPage js failed: $e');
      // no-op
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
        debugPrint('[KCP] _parseJavascriptResult: decoded 타입 비Map → 빈맵');
      } else {
        debugPrint(
          '[KCP] _parseJavascriptResult: result 비문자열/빈문자열 type=${result.runtimeType}',
        );
      }
    } catch (e) {
      debugPrint('[KCP] _parseJavascriptResult: jsonDecode 실패 $e');
    }

    return <String, dynamic>{};
  }

  /// 서버 콜백 URL(`…/api/auth/kcp/callback?token=…`)이 새 창/탭 또는 WebView에 뜬 뒤
  /// 1초 뒤 `window.close()` 시도 + 인앱에서는 WebView를 가려 폴링만 진행한다.
  void _scheduleKcpCallbackPageAutoClose(InAppWebViewController controller) {
    if (_kcpCallbackCloseScheduled) {
      debugPrint('[KCP] _scheduleKcpCallbackPageAutoClose: 이미 예약됨 → 스킵');
      return;
    }
    debugPrint('[KCP] _scheduleKcpCallbackPageAutoClose: 예약');
    _kcpCallbackCloseScheduled = true;
    _kcpCallbackCloseTimer?.cancel();
    // 스크립트로 연 창·팝업: 1초 뒤 브라우저가 허용하면 닫힘. Timer 등록보다 먼저 주입(onLoadStop 직후 타이밍).
    try {
      unawaited(
        controller.evaluateJavascript(source: r'''
          (function () {
            try {
              setTimeout(function () {
                try { window.close(); } catch (e) {}
              }, 1000);
            } catch (e) {}
          })();
        '''),
      );
      debugPrint('[KCP] _scheduleKcpCallbackPageAutoClose: window.close 주입(unawaited)');
    } catch (e) {
      debugPrint('[KCP] _scheduleKcpCallbackPageAutoClose: 주입 실패 $e');
    }
    // 인앱 WebView: 콜백 HTML이 보이지 않도록 1초 뒤 로딩 UI로 전환(폴링은 계속).
    _kcpCallbackCloseTimer = Timer(_kcpCallbackAutoCloseDelay, () {
      _kcpCallbackCloseTimer = null;
      if (!mounted || _hasNavigated) {
        debugPrint(
          '[KCP] _scheduleKcpCallback timer: 스킵 mounted=$mounted hasNav=$_hasNavigated',
        );
        return;
      }
      debugPrint('[KCP] _scheduleKcpCallback timer: obscureWebView=true');
      setState(() => _obscureWebViewAfterKcpCallback = true);
    });
  }

  void _startPollingResult() {
    if (_requestToken == null || _requestToken!.isEmpty || _hasNavigated) {
      debugPrint(
        '[KCP] startPolling skipped. token=${_requestToken ?? "-"} hasNavigated=$_hasNavigated',
      );
      return;
    }

    debugPrint('[KCP] startPolling token=$_requestToken');
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _pollKcpResult();
    });
    _pollKcpResult();
  }

  Future<void> _pollKcpResult() async {
    final token = _requestToken;
    if (token == null || token.isEmpty || _hasNavigated || !mounted) {
      // 폴링 타이머가 1초마다 호출되므로 여기서 매번 로그하면 콘솔이 너무 지저분해짐
      return;
    }

    try {
      // 일부 환경에서 304(Not Modified)로 응답이 비어 상태 갱신을 못 받는 경우가 있어 캐시를 우회한다.
      final ts = DateTime.now().millisecondsSinceEpoch;
      final response = await ApiClient.get(
        '/api/auth/kcp/result/$token?ts=$ts',
        additionalHeaders: const {
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      );

      if (response.statusCode == 404) {
        debugPrint('[KCP] poll 404 pending. token=$token');
        return;
      }

      if (response.statusCode == 304) {
        debugPrint('[KCP] poll 304 not-modified. token=$token');
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final status = (data['status'] ?? '').toString();
      final statusNorm = status.trim().toLowerCase();
      final certDone = _kcpResultIndicatesCertDone(data);
      final success = _isTruthy(data['success']);
      debugPrint('[KCP] poll status=$status certDone=$certDone success=$success');

      final stillPending =
          (statusNorm == 'pending' || statusNorm == 'processing') && !certDone;
      if (stillPending) {
        debugPrint('[KCP] _pollKcpResult: 아직 pending → return');
        return;
      }

      debugPrint('[KCP] _pollKcpResult: pending 아님 → 타이머 취소 후 분기 처리');
      _pollingTimer?.cancel();

      final explicitCertFlags = _isTruthy(data['cert_completed']) ||
          _isTruthy(data['certCompleted']) ||
          _isTruthy(data['completed']);
      final doneOk = (success && certDone) ||
          (certDone && explicitCertFlags) ||
          (certDone &&
              (statusNorm == 'completed' ||
                  statusNorm == 'success' ||
                  statusNorm == 'ok' ||
                  statusNorm == 'done'));

      if (doneOk) {
        debugPrint('[KCP] _pollKcpResult: 인증 완료 분기 (doneOk)');
        _hasNavigated = true;
        final mbDup = _extractMbDupinfo(data);

        final certInfo = <String, dynamic>{
          'cert_completed': true,
          'name': data['name'],
          'phone': data['phone'],
          'birthday': data['birthday'],
          'sex_code': data['sex_code'],
          'gender': data['gender'],
          'ci': data['ci'],
          'di': data['di'],
          'mb_dupinfo': mbDup.isNotEmpty ? mbDup : data['mb_dupinfo'],
          'kcp_raw': data,
        };
        _lastCertInfo = certInfo;
        debugPrint('[KCP] cert completed. mb_dupinfo=${mbDup.isEmpty ? "-" : mbDup}');

        if (widget.popResultToParent && mounted) {
          // WebView/iframe을 즉시 가려 사용자에게는 곧 닫힘으로 보이게 한다.
          setState(() => _obscureWebViewAfterKcpCallback = true);
          debugPrint('[KCP] _pollKcpResult: obscureWebView (popToParent)');
        } else {
          debugPrint(
            '[KCP] _pollKcpResult: obscure 스킵 popToParent=${widget.popResultToParent} mounted=$mounted',
          );
        }

        // 짧은 대기 후 오버레이 닫기(웹에서 Navigator 타이밍 이슈 완화).
        await Future.delayed(const Duration(milliseconds: 350));
        if (!mounted) {
          debugPrint('[KCP] _pollKcpResult: delay 후 unmounted');
          return;
        }

        if (widget.popResultToParent) {
          debugPrint('[KCP] _pollKcpResult: popResultToParent 처리');
          if (mbDup.isNotEmpty) {
            Map<String, dynamic> dup;
            try {
              debugPrint('[KCP] checkDupInfo start (mb_dupinfo len=${mbDup.length})');
              dup = await AuthRepository.checkDupInfo(mbDupinfo: mbDup).timeout(
                const Duration(seconds: 8),
                onTimeout: () {
                  debugPrint('[KCP] checkDupInfo timeout (8s) — treat as not duplicate');
                  return <String, dynamic>{
                    'success': true,
                    'exists': false,
                  };
                },
              );
              debugPrint(
                '[KCP] checkDupInfo done exists=${dup['exists']} success=${dup['success']}',
              );
            } catch (_) {
              dup = {'success': true, 'exists': false};
              debugPrint('[KCP] checkDupInfo error — treat as not duplicate');
            }
            if (!mounted) {
              debugPrint('[KCP] _pollKcpResult: dup 체크 전 unmounted');
              return;
            }
            if (dup['exists'] == true) {
              debugPrint('[KCP] _pollKcpResult: 중복 가입 분기 → overlay duplicate');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      dup['error']?.toString() ?? '이미 가입된 본인인증 정보입니다.',
                    ),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    width: 568, // 600px - 32px (양쪽 16px 여백)
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
              if (!mounted) return;
              _popKcpCertOverlay(<String, dynamic>{'duplicate': true});
              return;
            }
            debugPrint('[KCP] _pollKcpResult: dup 없음 → 정상 cert overlay pop');
          } else {
            debugPrint('[KCP] _pollKcpResult: mbDup 비어 있음 → checkDupInfo 스킵');
          }
          if (!mounted) {
            debugPrint('[KCP] _pollKcpResult: overlay pop 직전 unmounted');
            return;
          }
          debugPrint('[KCP] _pollKcpResult: _popKcpCertOverlay(certInfo)');
          _popKcpCertOverlay(certInfo);
          return;
        }

        if (widget.flow == 'find-account') {
          debugPrint('[KCP] _pollKcpResult: flow find-account → replacement');
          if (!mounted) return;
          _pushReplacementNamedAfterFrame(
            '/find-account-result',
            certInfo,
          );
          return;
        }

        if (widget.flow == 'find-password') {
          debugPrint('[KCP] _pollKcpResult: flow find-password');
          final email = (widget.email ?? '').trim();
          final certName = (data['name'] ?? certInfo['name'] ?? '').toString().trim();
          final certPhone = (data['phone'] ?? certInfo['phone'] ?? '').toString().trim();
          final mbDup = (certInfo['mb_dupinfo'] ?? certInfo['mbDupinfo'] ?? '').toString().trim();

          final result = await AuthRepository.forgotPassword(
            name: certName,
            phone: certPhone,
            identifier: email,
            fromKcp: true,
            mbDupinfo: mbDup.isNotEmpty ? mbDup : null,
          );

          if (!mounted) return;

          if (result['success'] == true) {
            debugPrint('[KCP] _pollKcpResult: find-password → reset 화면');
            _pushReplacementNamedAfterFrame(
              '/find-password-reset',
              {
                ...certInfo,
                'email': email,
                'identifier': email,
                'name': certName,
                'phone': certPhone,
                'from_kcp': true,
                'fromKcp': true,
              },
            );
          } else {
            debugPrint('[KCP] _pollKcpResult: find-password 실패 → not-found');
            _pushReplacementNamedAfterFrame(
              '/find-account-not-found',
              {
                ...certInfo,
                'email': email,
                'mode': 'password',
              },
            );
          }
          return;
        }

        if (!mounted) {
          debugPrint('[KCP] _pollKcpResult: signup replacement 전 unmounted');
          return;
        }
        debugPrint('[KCP] _pollKcpResult: flow 기본 → /signup replacement');
        Navigator.pushReplacementNamed(
          context,
          '/signup',
          arguments: certInfo,
        );
        return;
      }

      debugPrint('[KCP] _pollKcpResult: 인증 실패/미완료 분기 → SnackBar');
      final message =
          (data['message'] ?? data['res_msg'] ?? '본인인증에 실패했습니다.').toString();
      if (mounted) {
        final compact =
            message.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        final suppressKcpLibrarySnack = compact.contains('kcp') &&
            compact.contains('라이브러리') &&
            compact.contains('찾을수없');
        if (!suppressKcpLibrarySnack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
            ),
          );
          debugPrint('[KCP] _pollKcpResult: SnackBar 표시 msg=$message');
        } else {
          debugPrint(
            '[KCP] _pollKcpResult: KCP 라이브러리 미설치류 메시지 → SnackBar 생략 msg=$message',
          );
        }
      } else {
        debugPrint('[KCP] _pollKcpResult: 실패인데 unmounted → SnackBar 스킵');
      }
    } catch (e, st) {
      debugPrint('[KCP] poll error: $e\n$st');
    }
  }

  @override
  void dispose() {
    debugPrint('[KCP] dispose: 타이머 정리');
    _webPostMessage.stop();
    _pollingTimer?.cancel();
    _kcpCallbackCloseTimer?.cancel();
    super.dispose();
  }
}
