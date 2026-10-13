import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// KCP 결제 HTML을 https 주소 iframe으로 연다.
/// data:/blob: 주소는 네이버 앱이 파일 다운로드 확인창으로 처리한다.
class KcpLaunchFrame extends StatefulWidget {
  const KcpLaunchFrame({super.key, required this.url});

  final String url;

  @override
  State<KcpLaunchFrame> createState() => _KcpLaunchFrameState();
}

class _KcpLaunchFrameState extends State<KcpLaunchFrame> {
  static final Set<String> _registered = <String>{};
  late final String _viewType = 'kcp-launch-${widget.url.hashCode}';

  @override
  void initState() {
    super.initState();
    if (_registered.add(_viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        final iframe = html.IFrameElement()
          ..src = widget.url
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allow = 'payment *';
        iframe.removeAttribute('sandbox');
        return iframe;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
