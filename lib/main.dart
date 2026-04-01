import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// import 'package:firebase_core/firebase_core.dart';
import 'presentation/home/screens/home_screen.dart';
import 'presentation/auth/screens/login_screen.dart';
import 'presentation/auth/screens/find_account_screen.dart';
import 'presentation/auth/screens/kcp_cert_webview_screen.dart';
import 'presentation/auth/screens/signup_screen.dart';
import 'data/services/auth_service.dart';
import 'data/repositories/auth/auth_repository.dart';
import 'data/models/user/user_model.dart';
import 'core/utils/node_value_parser.dart';
import 'data/services/kakao_auth_service.dart';
// 조건부 임포트: 웹과 모바일에서 다른 FCM 서비스 사용
// import 'data/services/fcm_service_stub.dart'
//   if (dart.library.io) 'data/services/fcm_service.dart';
import 'presentation/common/widgets/mobile_layout_wrapper.dart';
import 'presentation/shopping/screens/product_detail_screen.dart';
import 'presentation/shopping/screens/product_list_screen.dart';
import 'presentation/shopping/screens/cart_screen.dart';
import 'presentation/shopping/showcase/screens/showcase_screen.dart';
import 'presentation/shopping/wish/screens/wish_list_screen.dart';
import 'presentation/user/myPage/screens/cancel_member_screen.dart';
import 'presentation/customer_service/screens/contact_list_screen.dart';
import 'presentation/user/point/screens/point_screen.dart';
import 'presentation/user/delivery/delivery_list_screen.dart';
import 'presentation/user/coupon/screens/coupon_screen.dart';
import 'presentation/review/screens/all_reviews_screen.dart';
import 'presentation/user/healthprofile/screens/health_profile_list_screen.dart';
import 'presentation/user/review/my_reviews_screen.dart';

void main() async {
  // Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();
  
  // TODO: 웹 개발 완료 후 Firebase 주석 해제 필요
  // 웹이 아닌 환경에서만 Firebase 초기화
  // if (!kIsWeb) {
  //   try {
  //     // Firebase 초기화
  //     await Firebase.initializeApp();
  //     print('✅ Firebase 초기화 완료');
  //     
  //     // FCM 서비스 초기화
  //     await FCMService().initialize();
  //     print('✅ FCM 서비스 초기화 완료');
  //   } catch (e) {
  //     print('❌ Firebase/FCM 초기화 실패: $e');
  //     // 에러가 발생해도 앱은 실행되도록 함
  //   }
  // } else {
  //   print('⚠️ 웹 환경에서는 Firebase를 초기화하지 않습니다.');
  // }
  
  print('⚠️ Firebase/FCM은 현재 비활성화되어 있습니다. (웹 개발 중)');
  
  // 카카오 SDK 초기화
  await KakaoAuthService.initialize();
  
  runApp(const BomioraApp());
}

// 전역 NavigatorKey (context 없이 네비게이션 가능)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class BomioraApp extends StatelessWidget {
  const BomioraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: '보미오라1',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'NotoSans',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // 한국어 로케일 설정
      locale: const Locale('ko', 'KR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/find-account': (context) => const FindAccountScreen(),
        '/home': (context) => const MobileLayoutWrapper(initialIndex: 0),
        // (임시) 카테고리 페이지 접근 차단
        '/category': (context) => const _TemporaryBlockedScreen(featureLabel: '카테고리'),
        '/favorite': (context) => const WishListScreen(),
        '/my_page': (context) => const MobileLayoutWrapper(initialIndex: 1),
        // (임시) 장바구니 페이지 접근 차단
        '/cart': (context) => const _TemporaryBlockedScreen(featureLabel: '장바구니'),
        '/coupon': (context) => const CouponScreen(),
        '/review': (context) => const AllReviewsScreen(),
        '/my_reviews': (context) => const MyReviewsScreen(),
        '/profile': (context) => const HealthProfileListScreen(),
        '/qna': (context) => const ContactListScreen(),
        '/cancel-member': (context) => const CancelMemberScreen(),
        '/customer-service': (context) => const ContactListScreen(),
        '/kcp-cert': (context) => const KcpCertWebViewScreen(),
        '/point': (context) => const PointScreen(),
        '/order': (context) => const DeliveryListScreen(),
        '/signup': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return SignupScreen(certInfo: args);
        },
      },
      onGenerateRoute: (settings) {
        // 동적 라우트 처리
        final routeName = settings.name ?? '';
        final uri = Uri.parse(routeName);
        
        // 제품 목록 페이지: /product-list 여리
        if (uri.pathSegments.length == 1 && uri.pathSegments[0] == 'product-list') {
          // (임시) 상품 목록 페이지 접근 차단
          return MaterialPageRoute(
            builder: (context) => const _TemporaryBlockedScreen(featureLabel: '카테고리/상품목록'),
            settings: RouteSettings(
              name: routeName,
              arguments: settings.arguments,
            ),
          );
        }
        
        // 제품 상세 페이지: /product/:it_id
        if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'product') {
          // (임시) 상품 상세 페이지 접근 차단
          return MaterialPageRoute(
            builder: (context) => const _TemporaryBlockedScreen(featureLabel: '상품 페이지'),
            settings: RouteSettings(
              name: routeName, // URL 업데이트를 위해 route name 설정 (예: /product/1691479590)
              arguments: settings.arguments,
            ),
          );
        }
        
        return null;
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await AuthService.isLoggedIn();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 디버그 모드 전용: test@naver.com / testtest 로 자동 로그인
  static const String _debugEmail = 'test@naver.com';
  static const String _debugPassword = 'testtest';

  Future<bool> _tryDebugAutoLogin() async {
    try {
      final result = await AuthRepository.login(
        email: _debugEmail,
        password: _debugPassword,
      );
      if (result['success'] != true) return false;

      final resultData = result['data'];
      if (resultData is! Map) return false;

      final userData = NodeValueParser.normalizeMap(
        Map<String, dynamic>.from(resultData as Map),
      );
      final userRaw = userData['user'];
      final userJson = NodeValueParser.normalizeMap(
        userRaw is Map
            ? Map<String, dynamic>.from(userRaw)
            : Map<String, dynamic>.from(userData),
      );
      final userId = NodeValueParser.asString(userJson['mb_id']) ??
          NodeValueParser.asString(userJson['id']) ??
          '';
      userJson['id'] = userId;
      userJson['password'] = _debugPassword;
      final user = UserModel.fromJson(userJson);
      final token = NodeValueParser.asString(userData['token']);
      await AuthService.saveLoginData(user: user, token: token);
      return true;
    } catch (e) {
      debugPrint('⚠️ [DEBUG AUTO LOGIN] 실패: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return const MobileLayoutWrapper();
  }
}

// 모바일 전용 레이아웃 래퍼 (공통 위젯 사용)
class MobileLayoutWrapper extends StatelessWidget {
  final int initialIndex;

  const MobileLayoutWrapper({
    super.key,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      child: HomeScreen(initialIndex: initialIndex),
    );
  }
}

class _TemporaryBlockedScreen extends StatelessWidget {
  const _TemporaryBlockedScreen({required this.featureLabel});

  final String featureLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text(featureLabel),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.block_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                '$featureLabel 화면 없음.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
