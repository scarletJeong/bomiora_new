import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;
import '../widgets/mobile_layout_wrapper.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const WebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  bool _useIframe = true;
  late String _iframeId;

  @override
  void initState() {
    super.initState();
    _iframeId = 'iframe-${widget.url.hashCode}';
    _registerIframe();
  }

  void _registerIframe() {
    // iframe 뷰 팩토리 등록
    ui_web.platformViewRegistry.registerViewFactory(
      _iframeId,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src = widget.url
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allowFullscreen = true
          ..allow = 'camera; microphone; geolocation';
        
        // iframe 로드 완료 후 처리
        iframe.onLoad.listen((_) {
          print('iframe 로드 완료: ${widget.url}');
          
          // CSS 스타일 주입으로 헤더 숨기기 시도
          try {
            // iframe 내부에 스타일 주입
            final script = html.ScriptElement()
              ..text = '''
                try {
                  var style = document.createElement('style');
                  style.textContent = \`
                    .header, .gnb, .top_menu, .mobile_header, 
                    .shop_header, .shop_gnb, .shop_top_menu,
                    .header_area, .gnb_area, .top_menu_area {
                      display: none !important;
                    }
                    body {
                      padding-top: 0 !important;
                      margin-top: 0 !important;
                    }
                    .container, .content {
                      margin-top: 0 !important;
                      padding-top: 0 !important;
                    }
                  \`;
                  document.head.appendChild(style);
                } catch(e) {
                  console.log('스타일 적용 실패:', e);
                }
              ''';
            // CORS 정책으로 인해 직접 접근이 제한될 수 있음
            print('iframe 스타일 주입 시도: ${widget.url}');
          } catch (e) {
            print('iframe 스타일 주입 실패: $e');
          }
        });
        
        return iframe;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // 이전 페이지로 돌아가기
          },
        ),
        actions: [
          IconButton(
            icon: Icon(_useIframe ? Icons.open_in_new : Icons.web),
            onPressed: () {
              setState(() {
                _useIframe = !_useIframe;
              });
            },
            tooltip: _useIframe ? '외부 브라우저로 열기' : '앱 내에서 보기',
          ),
        ],
      ),
      child: _useIframe ? _buildIframeView() : _buildExternalView(),
    );
  }

  Widget _buildIframeView() {
    return HtmlElementView(
      viewType: _iframeId,
    );
  }

  Widget _buildExternalView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.open_in_browser,
            size: 64,
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          Text(
            '외부 브라우저에서 열기',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final Uri uri = Uri.parse(widget.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('링크를 열 수 없습니다: ${widget.url}')),
                );
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('브라우저에서 열기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'URL: ${widget.url}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
