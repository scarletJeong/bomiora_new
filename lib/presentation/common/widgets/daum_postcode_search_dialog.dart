import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../core/network/api_client.dart';

Future<Map<String, dynamic>?> showDaumPostcodeSearchDialog(
  BuildContext context,
) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _DaumPostcodeDialog(),
  );
}

class _DaumPostcodeDialog extends StatefulWidget {
  const _DaumPostcodeDialog();

  @override
  State<_DaumPostcodeDialog> createState() => _DaumPostcodeDialogState();
}

class _DaumPostcodeDialogState extends State<_DaumPostcodeDialog> {
  bool _completed = false;
  String? _errorMessage;
  late final String _token;
  Timer? _pollTimer;
  String get _bridgeUrl =>
      '${ApiClient.baseUrl}/api/address/postcode-bridge?token=${Uri.encodeQueryComponent(_token)}';

  @override
  void initState() {
    super.initState();
    _token = DateTime.now().microsecondsSinceEpoch.toString();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final screenH = MediaQuery.sizeOf(context).height;
    final dialogW = (screenW * 0.95).clamp(420.0, 560.0);
    final dialogH = (screenH * 0.82).clamp(520.0, 680.0);
    final webW = (dialogW - 32).clamp(360.0, 520.0);
    final webH = (dialogH - 90).clamp(430.0, 620.0);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: dialogW,
        height: dialogH,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '주소 검색',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: webW,
                  height: webH,
                  child: _errorMessage != null
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: InAppWebView(
                            initialUrlRequest:
                                URLRequest(url: WebUri(_bridgeUrl)),
                            initialSettings: InAppWebViewSettings(
                              javaScriptEnabled: true,
                              domStorageEnabled: true,
                              databaseEnabled: true,
                              cacheEnabled: true,
                              useHybridComposition: true,
                              mixedContentMode:
                                  MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                            ),
                            onWebViewCreated: (_) {},
                            onReceivedError: (_, __, error) {
                              if (!mounted) return;
                              setState(() {
                                _errorMessage =
                                    '주소 검색 창 로딩 중 오류가 발생했습니다.\n${error.description}';
                              });
                            },
                            onConsoleMessage: (_, message) {
                              final text = message.message;
                              if (text.startsWith('POSTCODE_RESULT:')) {
                                final json =
                                    text.substring('POSTCODE_RESULT:'.length);
                                _handleConsolePayload(json);
                              }
                            },
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 400), (_) async {
      if (!mounted || _completed) {
        return;
      }
      try {
        final response = await ApiClient.get(
          '/api/address/postcode-bridge/poll?token=${Uri.encodeQueryComponent(_token)}',
        );
        if (response.statusCode != 200) {
          return;
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) {
          return;
        }
        if ((decoded['status'] ?? '').toString() != 'completed') {
          return;
        }
        _completed = true;
        _pollTimer?.cancel();
        if ((decoded['closed'] ?? '').toString() == '1') {
          if (mounted) Navigator.of(context).pop();
          return;
        }
        if (mounted) {
          Navigator.of(context).pop({
            'postalCode': (decoded['postalCode'] ?? '').toString().trim(),
            'roadAddress': (decoded['roadAddress'] ?? '').toString().trim(),
            'jibunAddress': (decoded['jibunAddress'] ?? '').toString().trim(),
            'extraAddress': (decoded['extraAddress'] ?? '').toString().trim(),
          });
        }
      } catch (_) {
        // polling 실패는 무시하고 다음 틱에서 재시도
      }
    });
  }

  void _handleConsolePayload(String jsonText) {
    if (!mounted || _completed) {
      return;
    }

    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map) {
        return;
      }
      final payload = Map<String, dynamic>.from(decoded);
      if ((payload['closed'] ?? '').toString() == '1') {
        _completed = true;
        Navigator.of(context).pop();
        return;
      }

      _completed = true;
      Navigator.of(context).pop({
        'postalCode': (payload['postalCode'] ?? '').toString().trim(),
        'roadAddress': (payload['roadAddress'] ?? '').toString().trim(),
        'jibunAddress': (payload['jibunAddress'] ?? '').toString().trim(),
        'extraAddress': (payload['extraAddress'] ?? '').toString().trim(),
      });
    } catch (_) {
      // ignore malformed payload
    }
  }
}
