import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// KCP 결제 HTML을 https 주소 iframe으로 연다.
/// data:/blob: 주소는 네이버 앱이 파일 다운로드 확인창으로 처리한다.
class KcpLaunchFrame extends StatefulWidget {
  const KcpLaunchFrame({
    super.key,
    required this.url,
    this.replaceTop = false,
  });

  final String url;

  /// 모바일 결제창은 iframe 이 아니라 현재 탭 전체 이동이어야 한다.
  final bool replaceTop;

  @override
  State<KcpLaunchFrame> createState() => _KcpLaunchFrameState();
}

class _KcpLaunchFrameState extends State<KcpLaunchFrame> {
  static final Set<String> _registered = <String>{};
  late final String _viewType = 'kcp-launch-${widget.url.hashCode}';

  @override
  void initState() {
    super.initState();
    if (widget.replaceTop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        html.window.location.assign(widget.url);
      });
      return;
    }
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
    if (widget.replaceTop) {
      return const SizedBox.expand();
    }
    return SizedBox.expand(
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
