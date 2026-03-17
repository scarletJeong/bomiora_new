import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:async';

class KcpCertWebViewScreen extends StatefulWidget {
  const KcpCertWebViewScreen({super.key});

  @override
  State<KcpCertWebViewScreen> createState() => _KcpCertWebViewScreenState();
}

class _KcpCertWebViewScreenState extends State<KcpCertWebViewScreen> {
  InAppWebViewController? _webViewController;
  double _progress = 0;
  bool _isLoading = true;

  // KCP 본인인증 URL 생성
  String _getKcpCertUrl() {
    // 개발 환경에 따라 URL 변경
    if (kIsWeb) {
      final currentHost = Uri.base.host;
      if (currentHost == 'localhost' || currentHost == '127.0.0.1' || currentHost.isEmpty) {
        return 'http://localhost/bomiora/www/plugin/kcpcert/kcpcert_form.php?pageType=register';
      } else {
        // 프로덕션 환경에서는 실제 도메인 사용
        return 'https://bomiora.kr/plugin/kcpcert/kcpcert_form.php?pageType=register';
      }
    } else {
      // 모바일 환경에서는 개발 서버 또는 프로덕션 서버 사용
      return 'https://bomiora.net/plugin/kcpcert/kcpcert_form.php?pageType=register';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('본인인증'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_getKcpCertUrl())),
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
              print('🌐 [KCP Cert] 페이지 로드 시작: $url');
              
              // 결과 페이지로 이동했는지 확인
              if (url.toString().contains('kcpcert_result.php')) {
                print('✅ [KCP Cert] 결과 페이지 감지');
                // JavaScript로 인증 정보 추출 시도
                _extractCertInfo(controller);
              }
            },
            onLoadStop: (controller, url) async {
              setState(() {
                _isLoading = false;
              });
              print('🌐 [KCP Cert] 페이지 로드 완료: $url');
              
              // 결과 페이지에서 인증 정보 추출
              if (url.toString().contains('kcpcert_result.php')) {
                print('✅ [KCP Cert] 결과 페이지 로드 완료');
                // 약간의 지연 후 정보 추출 (페이지 렌더링 대기)
                await Future.delayed(const Duration(milliseconds: 500));
                await _extractCertInfo(controller);
              }
            },
            onProgressChanged: (controller, progress) {
              setState(() {
                _progress = progress / 100;
              });
            },
            onReceivedError: (controller, request, error) {
              print('❌ [KCP Cert] 에러 발생: ${error.description}');
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
          if (_isLoading || _progress < 1.0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
        ],
      ),
    );
  }

  // JavaScript로 인증 정보 추출
  Future<void> _extractCertInfo(InAppWebViewController controller) async {
    try {
      // 결과 페이지에서 인증 정보를 추출하는 JavaScript 실행
      // PHP 결과 페이지는 부모 창에 데이터를 전달하는 방식이므로,
      // 여기서는 URL 파라미터나 페이지 내용을 분석해야 함
      
      // 방법 1: 페이지 내용에서 데이터 추출 시도
      final script = '''
        (function() {
          try {
            // form_auth 폼에서 데이터 추출
            var form = document.querySelector('form[name="form_auth"]');
            if (!form) return null;
            
            var data = {};
            var inputs = form.querySelectorAll('input[type="hidden"]');
            inputs.forEach(function(input) {
              data[input.name] = input.value;
            });
            
            // 인증 성공 여부 확인 (res_cd가 "0000"이면 성공)
            if (data.res_cd === "0000" && data.cert_enc_use === "Y") {
              return JSON.stringify({
                success: true,
                cert_no: data.cert_no || '',
                res_cd: data.res_cd || '',
                site_cd: data.site_cd || '',
                ordr_idxx: data.ordr_idxx || ''
              });
            }
            return null;
          } catch(e) {
            console.error('인증 정보 추출 오류:', e);
            return null;
          }
        })();
      ''';
      
      final result = await controller.evaluateJavascript(source: script);
      print('📋 [KCP Cert] JavaScript 실행 결과: $result');
      
      if (result != null && result.toString().contains('success')) {
        // 인증 성공 - 회원가입 화면으로 이동
        // 실제 사용자 정보는 서버에서 복호화해야 하므로, 
        // 일단 인증 완료 플래그만 전달하고 회원가입 화면으로 이동
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/signup',
            arguments: {'cert_completed': true},
          );
        }
      }
    } catch (e) {
      print('❌ [KCP Cert] 인증 정보 추출 실패: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
