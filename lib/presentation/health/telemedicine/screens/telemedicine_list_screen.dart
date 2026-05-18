import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../../data/services/auth_service.dart';
import '../../health_common/widgets/health_app_bar.dart';
import 'dart:async';

class TelemedicineWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const TelemedicineWebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<TelemedicineWebViewScreen> createState() => _TelemedicineWebViewScreenState();
}

class _TelemedicineWebViewScreenState extends State<TelemedicineWebViewScreen> {
  InAppWebViewController? _webViewController;
  double _progress = 0;
  bool _isLoading = true;
  String? _authToken;
  StreamSubscription? _messageStream;

  @override
  void initState() {
    super.initState();
    _loadAuthToken();
  }

  Future<void> _loadAuthToken() async {
    final token = await AuthService.getToken();
    final user = await AuthService.getUser();
    setState(() {
      _authToken = token;
    });
    print('🔑 인증 토큰 로드: ${token != null ? "성공" : "없음"}');
    print('👤 사용자 정보: ${user?.name ?? "없음"}');
  }

  // 웹에서는 토큰을 URL 파라미터로 전달
  String _buildUrlWithAuth(String baseUrl) {
    if (kIsWeb && _authToken != null && _authToken!.isNotEmpty) {
      final separator = baseUrl.contains('?') ? '&' : '?';
      return '$baseUrl${separator}flutter_token=$_authToken';
    }
    return baseUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HealthAppBar(
        title: widget.title,
        actions: [
          healthAppBarAction(
            context: context,
            icon: Icons.refresh,
            tooltip: '새로고침',
            onPressed: () => _webViewController?.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_buildUrlWithAuth(widget.url))),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              cacheEnabled: true,
              clearCache: false,
              useHybridComposition: true,
              allowsInlineMediaPlayback: true,
              mediaPlaybackRequiresUserGesture: false,
              // 혼합 콘텐츠 허용
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              // 파일 액세스 허용
              allowFileAccess: true,
              allowContentAccess: true,
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
              
              // JavaScript 핸들러는 웹에서 지원되지 않음
              if (!kIsWeb) {
                // Flutter에서 JavaScript로 데이터를 전달하기 위한 핸들러 등록 (모바일 전용)
                controller.addJavaScriptHandler(
                  handlerName: 'getAuthToken',
                  callback: (args) {
                    print('🌐 웹에서 인증 토큰 요청');
                    return _authToken ?? '';
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: 'getUserInfo',
                  callback: (args) async {
                    print('🌐 웹에서 사용자 정보 요청');
                    final user = await AuthService.getUser();
                    if (user != null) {
                      return {
                        'id': user.id,
                        'name': user.name,
                        'email': user.email,
                        'phone': user.phone,
                      };
                    }
                    return null;
                  },
                );

                // 웹뷰에서 로그아웃이 발생했을 때를 감지하는 핸들러
                controller.addJavaScriptHandler(
                  handlerName: 'handleWebLogout',
                  callback: (args) async {
                    print('🔓 웹뷰에서 로그아웃 요청');
                    // 앱의 로그인 상태도 삭제
                    await AuthService.logout();
                    // 앱 메인 화면으로 이동
                    if (mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                    return {'success': true};
                  },
                );

                // 웹뷰에서 로그인이 발생했을 때를 감지하는 핸들러
                controller.addJavaScriptHandler(
                  handlerName: 'handleWebLogin',
                  callback: (args) async {
                    print('🔐 웹뷰에서 로그인 발생');
                    if (args.isNotEmpty && args[0] is Map) {
                      final loginData = args[0] as Map;
                      final token = loginData['token'] as String?;
                      final userId = loginData['userId'] as String?;
                      // 필요한 경우 앱의 인증 상태 업데이트
                      if (token != null) {
                        await AuthService.updateToken(token);
                        setState(() {
                          _authToken = token;
                        });
                      }
                    }
                    return {'success': true};
                  },
                );

                // 웹뷰에서 장바구니에 상품이 추가되었을 때를 감지
                controller.addJavaScriptHandler(
                  handlerName: 'handleCartUpdate',
                  callback: (args) {
                    print('🛒 웹뷰에서 장바구니 업데이트');
                    if (args.isNotEmpty) {
                      final cartCount = args[0];
                      print('📦 장바구니 아이템 수: $cartCount');
                      // 앱의 장바구니 아이콘에 뱃지 추가하는 등의 UI 업데이트 가능
                    }
                    return {'received': true};
                  },
                );
              }
            },
            onLoadStart: (controller, url) {
              print('📱 페이지 로딩 시작: $url');
              setState(() {
                _isLoading = true;
              });
            },
            onLoadStop: (controller, url) async {
              print('✅ 페이지 로딩 완료: $url');
              setState(() {
                _isLoading = false;
              });

              // 웹이 아닐 때만 JavaScript 주입 및 쿠키 설정 (모바일 전용)
              if (!kIsWeb && _authToken != null && _authToken!.isNotEmpty) {
                final user = await AuthService.getUser();
                
                // 로컬 스토리지에 인증 정보 저장
                try {
                  await controller.evaluateJavascript(source: '''
                    try {
                      // 로컬 스토리지에 토큰 저장
                      localStorage.setItem('auth_token', '$_authToken');
                      
                      // 사용자 정보 저장
                      ${user != null ? '''
                      localStorage.setItem('user_id', '${user.id}');
                      localStorage.setItem('user_name', '${user.name}');
                      localStorage.setItem('user_email', '${user.email}');
                      localStorage.setItem('user_phone', '${user.phone}');
                      ''' : ''}
                      
                      console.log('✅ Flutter에서 인증 정보 주입 완료');
                      
                      // 페이지에 커스텀 이벤트 발생
                      window.dispatchEvent(new CustomEvent('flutterAuthReady', {
                        detail: {
                          token: '$_authToken',
                          userId: '${user?.id ?? ''}',
                          userName: '${user?.name ?? ''}'
                        }
                      }));
                    } catch(e) {
                      console.error('❌ 인증 정보 주입 실패:', e);
                    }
                  ''');
                  
                  print('🔐 인증 정보를 웹페이지에 주입했습니다');
                } catch (e) {
                  print('⚠️ JavaScript 실행 실패: $e');
                }

                // 쿠키 설정 (도메인이 같을 경우에만 작동)
                final cookieManager = CookieManager.instance();
                final uri = WebUri(widget.url);
                
                try {
                  await cookieManager.setCookie(
                    url: uri,
                    name: 'auth_token',
                    value: _authToken!,
                    domain: uri.host,
                    path: '/',
                    maxAge: 86400 * 30, // 30일
                    isSecure: false,
                    isHttpOnly: false,
                  );
                  print('🍪 쿠키 설정 완료');
                } catch (e) {
                  print('⚠️ 쿠키 설정 실패: $e');
                }
              } else if (kIsWeb) {
                // 웹에서는 URL 파라미터로 토큰이 전달됨
                print('🌐 웹 환경: URL 파라미터로 인증 정보 전달됨');
              }
            },
            onProgressChanged: (controller, progress) {
              setState(() {
                _progress = progress / 100;
              });
            },
            onConsoleMessage: (controller, consoleMessage) {
              // 웹 콘솔 로그를 Flutter 콘솔에 출력
              print('🌐 웹 콘솔: ${consoleMessage.message}');
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url.toString();
              
              // 외부 링크 처리 (필요시)
              if (url.startsWith('tel:') || 
                  url.startsWith('mailto:') || 
                  url.startsWith('sms:')) {
                // 전화, 이메일, SMS 링크는 외부 앱으로 처리
                return NavigationActionPolicy.CANCEL;
              }
              
              return NavigationActionPolicy.ALLOW;
            },
          ),
          
          // 로딩 인디케이터
          if (_isLoading)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      '${widget.title} 로딩 중...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // 프로그레스 바
          if (_progress < 1.0 && _progress > 0)
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
}

