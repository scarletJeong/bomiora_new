import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class CheckoutWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const CheckoutWebViewScreen({
    super.key,
    required this.url,
    this.title = '결제 페이지',
  });

  @override
  State<CheckoutWebViewScreen> createState() => _CheckoutWebViewScreenState();
}

class _CheckoutWebViewScreenState extends State<CheckoutWebViewScreen> {
  double _progress = 0;
  bool _didReturnToApp = false;

  String _mobileUserAgent() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';
    }
    return 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              useHybridComposition: true,
              userAgent: _mobileUserAgent(),
              preferredContentMode: UserPreferredContentMode.MOBILE,
              allowsInlineMediaPlayback: true,
              mediaPlaybackRequiresUserGesture: false,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
            ),
            onLoadStart: (_, url) {
              _handlePaymentCompleteUrl(url);
            },
            onLoadStop: (controller, url) async {
              _handlePaymentCompleteUrl(url);
              await controller.evaluateJavascript(source: '''
                (function() {
                  var viewport = document.querySelector('meta[name="viewport"]');
                  if (!viewport) {
                    viewport = document.createElement('meta');
                    viewport.name = 'viewport';
                    document.head.appendChild(viewport);
                  }
                  viewport.setAttribute('content', 'width=device-width, initial-scale=1, maximum-scale=1');
                })();
              ''');
            },
            onProgressChanged: (_, progress) {
              setState(() {
                _progress = progress / 100;
              });
            },
          ),
          if (_progress < 1.0)
            LinearProgressIndicator(
              value: _progress,
              minHeight: 2,
              backgroundColor: Colors.grey.shade200,
            ),
        ],
      ),
    );
  }

  void _handlePaymentCompleteUrl(WebUri? url) {
    if (_didReturnToApp || url == null || !mounted) return;
    final current = url.toString();
    final isOrderComplete = current.contains('/shop/orderinquiryview.php') ||
        current.contains('/shop/orderresult.php');
    if (!isOrderComplete) return;

    _didReturnToApp = true;
    Navigator.of(context).pop(true);
  }
}
