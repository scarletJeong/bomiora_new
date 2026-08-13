import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../core/network/api_client.dart';
import '../../health/health_common/health_responsive_scale.dart';
import 'mobile_layout_wrapper.dart';

const double _kPostcodeDialogMaxWidth = 650;
const String _kPostcodeRouteName = 'daum_postcode_search';

Future<Map<String, dynamic>?> showDaumPostcodeSearchDialog(
  BuildContext context,
) {
  return showGeneralDialog<Map<String, dynamic>>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: '주소 검색',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 200),
    routeSettings: const RouteSettings(name: _kPostcodeRouteName),
    pageBuilder: (dialogContext, _, __) {
      return _DaumPostcodeDialogShell(
        onFinished: (result) {
          _popOnlyThisDialog(dialogContext, result);
        },
      );
    },
    transitionBuilder: (context, animation, _, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

/// 주소검색 라우트만 닫음. 배송지 등록/수정 페이지는 절대 pop 하지 않음.
void _popOnlyThisDialog(
  BuildContext dialogContext,
  Map<String, dynamic>? result,
) {
  void tryPop() {
    if (!dialogContext.mounted) return;
    final nav = Navigator.of(dialogContext, rootNavigator: true);
    final route = ModalRoute.of(dialogContext);
    if (route != null &&
        route.settings.name != null &&
        route.settings.name != _kPostcodeRouteName) {
      return;
    }
    if (!nav.canPop()) return;
    nav.pop(result);
  }

  // WebView 제스처 직후 lock 회피: 다음 프레임 + 짧은 지연 후 1회
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future<void>.delayed(const Duration(milliseconds: 50), tryPop);
  });
}

class _DaumPostcodeDialogShell extends StatelessWidget {
  const _DaumPostcodeDialogShell({required this.onFinished});

  final void Function(Map<String, dynamic>? result) onFinished;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final contentW = MobileLayoutWrapper.contentWidthOf(
      context,
      maxWidth: _kPostcodeDialogMaxWidth,
    );
    final availableH =
        screenSize.height - viewPadding.top - viewPadding.bottom - 16;
    final preferredH = contentW * 1.35;
    final fillScreen = screenSize.width <= 375;
    final dialogW = fillScreen ? screenSize.width : contentW;
    final dialogH = fillScreen
        ? screenSize.height
        : preferredH.clamp(420.0, availableH);

    final dialog = GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.deferToChild,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: Size(dialogW, dialogH),
        ),
        child: _DaumPostcodeDialog(
          width: dialogW,
          height: dialogH,
          fullScreen: fillScreen,
          onClose: onFinished,
        ),
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        width: screenSize.width,
        height: screenSize.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!fillScreen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => onFinished(null),
                  behavior: HitTestBehavior.opaque,
                ),
              ),
            fillScreen ? Positioned.fill(child: dialog) : Center(child: dialog),
          ],
        ),
      ),
    );
  }
}

class _DaumPostcodeDialog extends StatefulWidget {
  const _DaumPostcodeDialog({
    required this.width,
    required this.height,
    required this.onClose,
    this.fullScreen = false,
  });

  final double width;
  final double height;
  final bool fullScreen;
  final void Function(Map<String, dynamic>? result) onClose;

  @override
  State<_DaumPostcodeDialog> createState() => _DaumPostcodeDialogState();
}

class _DaumPostcodeDialogState extends State<_DaumPostcodeDialog> {
  bool _completed = false;
  bool _closing = false;
  String? _errorMessage;
  late final String _token;
  Timer? _pollTimer;
  Map<String, dynamic>? _pendingResult;

  String _bridgeUrlFor({required double width, required double height}) {
    final w = width.round().clamp(1, 4000);
    final h = height.round().clamp(1, 4000);
    return '${ApiClient.baseUrl}/api/address/postcode-bridge'
        '?token=${Uri.encodeQueryComponent(_token)}'
        '&width=$w'
        '&height=$h';
  }

  void _onClosePressed() {
    if (_completed) {
      widget.onClose(_pendingResult);
      return;
    }
    _finishDialog();
  }

  @override
  void initState() {
    super.initState();
    _token = DateTime.now().microsecondsSinceEpoch.toString();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    super.dispose();
  }

  void _finishDialog([Map<String, dynamic>? result]) {
    if (_completed) return;
    _completed = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    _pendingResult = result;

    // Hybrid WebView가 Navigator lock 을 잡는 경우가 있어
    // 먼저 WebView를 제거하고(닫는 중 UI), 그다음 pop
    if (mounted) {
      setState(() => _closing = true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        widget.onClose(result);
        return;
      }
      widget.onClose(result);
    });
  }

  void _applyPayload(Map payload) {
    if (_completed) return;
    if ((payload['closed'] ?? '').toString() == '1') {
      _finishDialog();
      return;
    }
    final postal = (payload['postalCode'] ?? '').toString().trim();
    final road = (payload['roadAddress'] ?? '').toString().trim();
    final jibun = (payload['jibunAddress'] ?? '').toString().trim();
    if (postal.isEmpty && road.isEmpty && jibun.isEmpty) return;
    _finishDialog({
      'postalCode': postal,
      'roadAddress': road,
      'jibunAddress': jibun,
      'extraAddress': (payload['extraAddress'] ?? '').toString().trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.fullScreen ? 0.0 : healthDp(context, 12);
    final errorFs = healthSp(context, 14);
    final closeSize = healthDp(context, 36);
    final headerH = healthDp(context, 44);
    final webH = (widget.height - headerH).clamp(1.0, widget.height);

    return Material(
      color: Colors.white,
      elevation: widget.fullScreen ? 0 : 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Column(
          children: [
            SizedBox(
              height: headerH,
              width: double.infinity,
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _onClosePressed,
                  child: SizedBox(
                    width: closeSize + healthDp(context, 16),
                    height: headerH,
                    child: Icon(
                      Icons.close,
                      size: healthDp(context, 22),
                      color: const Color(0xFF1A1A1E),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _closing
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(healthDp(context, 16)),
                            child: Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: errorFs,
                                fontFamily: 'Gmarket Sans TTF',
                              ),
                            ),
                          ),
                        )
                      : InAppWebView(
                          initialUrlRequest: URLRequest(
                            url: WebUri(
                              _bridgeUrlFor(
                                width: widget.width,
                                height: webH,
                              ),
                            ),
                          ),
                          initialSettings: InAppWebViewSettings(
                            javaScriptEnabled: true,
                            domStorageEnabled: true,
                            databaseEnabled: true,
                            cacheEnabled: false,
                            clearCache: true,
                            useHybridComposition: true,
                            useWideViewPort: true,
                            loadWithOverviewMode: false,
                            textZoom: 100,
                            supportZoom: false,
                            mixedContentMode:
                                MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                          ),
                          onWebViewCreated: (controller) {
                            // 웹은 addJavaScriptHandler 미구현 → 콘솔/폴링으로 결과 수신
                            if (kIsWeb) return;
                            try {
                              controller.addJavaScriptHandler(
                                handlerName: 'postcodeResult',
                                callback: (args) {
                                  if (_completed) return null;
                                  if (args.isEmpty) return null;
                                  final raw = args.first;
                                  if (raw is Map) {
                                    _applyPayload(
                                      Map<String, dynamic>.from(raw),
                                    );
                                  } else if (raw is String) {
                                    try {
                                      final decoded = jsonDecode(raw);
                                      if (decoded is Map) {
                                        _applyPayload(
                                          Map<String, dynamic>.from(decoded),
                                        );
                                      }
                                    } catch (_) {}
                                  }
                                  return null;
                                },
                              );
                            } catch (_) {}
                          },
                          onConsoleMessage: (_, message) {
                            final text = message.message;
                            if (!text.startsWith('POSTCODE_RESULT:')) return;
                            if (_completed) return;
                            final json =
                                text.substring('POSTCODE_RESULT:'.length);
                            try {
                              final decoded = jsonDecode(json);
                              if (decoded is Map) {
                                _applyPayload(
                                  Map<String, dynamic>.from(decoded),
                                );
                              }
                            } catch (_) {}
                          },
                          onReceivedError: (_, __, error) {
                            if (!mounted || _completed) return;
                            setState(() {
                              _errorMessage =
                                  '주소 검색 창 로딩 중 오류가 발생했습니다.\n${error.description}';
                            });
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 350), (_) async {
      if (!mounted || _completed) return;
      try {
        final response = await ApiClient.get(
          '/api/address/postcode-bridge/poll?token=${Uri.encodeQueryComponent(_token)}',
        );
        if (!mounted || _completed) return;
        if (response.statusCode != 200) return;
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) return;
        if ((decoded['status'] ?? '').toString() != 'completed') return;
        _applyPayload(Map<String, dynamic>.from(decoded));
      } catch (_) {}
    });
  }
}
