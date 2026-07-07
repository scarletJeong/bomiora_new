import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'presentation/home/screens/home_screen.dart';
import 'presentation/auth/screens/login_screen.dart';
import 'presentation/auth/screens/find_account_main_screen.dart';
import 'presentation/auth/screens/find_account_not_found_screen.dart';
import 'presentation/auth/screens/find_account_result_screen.dart';
import 'presentation/auth/screens/find_password_reset_screen.dart';
import 'core/navigation/app_navigator_key.dart';
import 'presentation/auth/widgets/kcp_cert.dart';
import 'presentation/auth/screens/signup_screen.dart';
import 'presentation/auth/screens/social_signup_screen.dart';
import 'data/services/auth_service.dart';
import 'data/services/kakao_auth_service.dart';
import 'data/services/naver_auth_service.dart';
import 'data/services/fcm_service_stub.dart'
    if (dart.library.io) 'data/services/fcm_service.dart';
import 'presentation/common/widgets/mobile_layout_wrapper.dart';
import 'presentation/shopping/screens/product_detail_screen.dart';
import 'presentation/shopping/screens/product_detail_general_screen.dart';
import 'presentation/shopping/screens/product_list_screen.dart';
import 'presentation/shopping/screens/product_main_general_screen.dart';
import 'presentation/shopping/screens/bomiora_introduce_screen.dart';
import 'presentation/shopping/screens/kcp_pay_webview_screen.dart';
import 'presentation/shopping/screens/payment_complete_screen.dart';
import 'presentation/shopping/screens/cart_screen.dart';
import 'presentation/shopping/screens/temp_cart_screen.dart';
import 'presentation/shopping/wish/screens/wish_list_screen.dart';
import 'presentation/user/myPage/screens/cancel_member_screen.dart';
import 'presentation/customer_service/screens/contact_list_screen.dart';
import 'presentation/customer_service/screens/contact_detail_screen.dart';
import 'presentation/user/point/screens/point_screen.dart';
import 'presentation/user/delivery/delivery_list_screen.dart';
import 'presentation/user/delivery/delivery_detail_screen.dart';
import 'presentation/user/delivery/refund/refund_apply_general_screen.dart';
import 'presentation/user/delivery/refund/refund_apply_prescription_screen.dart';
import 'presentation/user/coupon/screens/coupon_screen.dart';
import 'presentation/user/healthprofile/screens/health_profile_list_screen.dart';
import 'presentation/user/review/my_reviews_screen.dart';
import 'presentation/health/dashboard/screens/health_dashboard_screen.dart';
import 'presentation/community/announcement/screens/announcement_list_screen.dart';
import 'presentation/community/announcement/screens/announcement_detail_screen.dart';
import 'presentation/community/event/screens/event_list_screen.dart';
import 'presentation/community/event/screens/event_detail_screen.dart';
import 'presentation/community/faq/screens/faq_list_screen.dart';
import 'presentation/content/dashboard/screens/content_dashboard_screen.dart';
import 'presentation/content/dashboard/screens/content_list_screen.dart';
import 'presentation/content/dashboard/screens/content_detail_screen.dart';
import 'presentation/home/search/search_list_screen.dart';
import 'presentation/common/widgets/dropdown_btn.dart';
import 'core/utils/inf_code_tracker.dart';

/// 개발용: 앱 시작 시 로그인 화면을 먼저 표시
const bool kDevForceLoginScreenFirst = false;

void main() async {
  // Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      await FCMService().initialize();
    } catch (e) {
      debugPrint('[FCM] Firebase 초기화 실패(google-services.json 확인): $e');
    }
  }

  // 카카오·네이버 SDK 초기화
  await KakaoAuthService.initialize();
  await NaverAuthService.initialize();
  await InfCodeTracker.init();

  runApp(const BomioraApp());
}

class BomioraApp extends StatefulWidget {
  const BomioraApp({super.key});

  @override
  State<BomioraApp> createState() => _BomioraAppState();
}

class _BomioraAppState extends State<BomioraApp> {
  @override
  void reassemble() {
    super.reassemble();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DropdownBtn.closeMenu();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: '보미오라1',
      builder: (context, child) {
        return LayoutScaffoldMessenger(
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Gmarket Sans TTF',
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
      home: kDevForceLoginScreenFirst
          ? const LoginScreen()
          : const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/find-account': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return FindAccountScreen(
            initialTab: (args?['tab'] ?? 'id').toString(),
            prefillEmail: args?['prefillEmail']?.toString(),
          );
        },
        '/find-account-result': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return FindAccountResultScreen(
            certInfo: Map<String, dynamic>.from(args ?? const {}),
          );
        },
        '/find-account-not-found': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return FindAccountNotFoundScreen(findAccountInfo: args);
        },
        '/find-password-reset': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return FindPasswordResetScreen(resetInfo: args);
        },
        '/home': (context) => const MobileLayoutWrapper(initialIndex: 0),
        // (임시) 카테고리 페이지 접근 차단
        
        '/favorite': (context) => const WishListScreen(),
        '/my_page': (context) => const MobileLayoutWrapper(initialIndex: 1),
        '/health': (context) => const HealthDashboardScreen(),
        // (임시) 장바구니 페이지 접근 차단
        '/cart': (context) => const CartScreen(),
        '/temp-cart': (context) => const TempCartScreen(),
        '/bomiora-introduce': (context) => const BomioraIntroduceScreen(),
        '/healthcare-store': (context) => const ProductMainGeneralScreen(),
        '/coupon': (context) => const CouponScreen(),
        '/my_reviews': (context) => const MyReviewsScreen(),
        '/profile': (context) => const HealthProfileListScreen(),
        '/qna': (context) => const ContactListScreen(),
        '/qna-detail': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          final wrId = int.tryParse(args?['wrId']?.toString() ?? '') ?? 0;
          return ContactDetailScreen(wrId: wrId);
        },
        '/cancel-member': (context) => const CancelMemberScreen(),
        '/customer-service': (context) => const ContactListScreen(),
        '/kcp-pay': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return KcpPayWebViewScreen(
            html: (args?['html'] ?? '').toString(),
            token: (args?['token'] ?? '').toString(),
          );
        },
        '/payment-complete': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return PaymentCompleteScreen(
            orderId: (args?['orderId'] ?? '').toString(),
          );
        },
        '/point': (context) => const PointScreen(),
        '/order': (context) => const DeliveryListScreen(),
        '/order-detail': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          var orderNumber = '';
          if (args is Map) {
            orderNumber =
                (args['orderNumber'] ?? args['odId'] ?? '').toString();
          }
          return DeliveryDetailScreen(orderNumber: orderNumber);
        },
        '/refund': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          var orderNumber = '';
          if (args is Map) {
            orderNumber =
                (args['orderNumber'] ?? args['odId'] ?? '').toString();
          }
          return RefundApplyPrescriptionScreen(orderNumber: orderNumber);
        },
        '/refund-general': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          var orderNumber = '';
          if (args is Map) {
            orderNumber =
                (args['orderNumber'] ?? args['odId'] ?? '').toString();
          }
          return RefundApplyGeneralScreen(orderNumber: orderNumber);
        },
        '/announcement': (context) => const AnnouncementListScreen(),
        '/event': (context) => const EventListScreen(),
        '/faq': (context) => const FaqListScreen(),
        '/content': (context) => const ContentDashboardScreen(),
        '/content/list': (context) => const ContentListScreen(),
        '/content/detail': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return ContentDetailScreen.fromArgs(args);
        },
        '/search': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return SearchListScreen(
            initialQuery: (args?['query'] ?? '').toString(),
          );
        },
        '/signup': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return SignupScreen(certInfo: args);
        },
        '/social-signup': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return SocialSignupScreen(
            provider: (args?['provider'] ?? 'kakao').toString(),
            identifier: (args?['identifier'] ?? '').toString(),
            email: args?['email']?.toString(),
            nickname: args?['nickname']?.toString(),
            name: args?['name']?.toString(),
            gender: args?['gender']?.toString(),
            birthday: args?['birthday']?.toString(),
            profileImageUrl: args?['profileImageUrl']?.toString(),
          );
        },
      },
      onGenerateRoute: (settings) {
        // 동적 라우트 처리
        final routeName = settings.name ?? '';
        final uri = Uri.parse(routeName);
        InfCodeTracker.captureFromUri(uri);

        // KCP 본인인증: 원래 화면이 비치는 딤 오버레이 스타일로 표시
        if (routeName == '/kcp-cert') {
          final args = settings.arguments as Map<String, dynamic>? ?? const {};
          return PageRouteBuilder(
            settings: settings,
            opaque: false,
            barrierDismissible: false,
            barrierColor: const Color(0x991A1A1A),
            pageBuilder: (context, animation, secondaryAnimation) {
              return KcpCertWebViewScreen(
                flow: (args['flow'] ?? 'signup').toString(),
                email: args['email']?.toString(),
                popResultToParent: args['popResultToParent'] == true,
                overlayStyle: true,
              );
            },
          );
        }

        // 제품 목록 페이지: /product-list (레거시)
        if (uri.pathSegments.length == 1 &&
            uri.pathSegments[0] == 'product-list') {
          // (임시) 상품 목록 페이지 접근 차단
          final arguments = settings.arguments as Map<String, dynamic>? ?? {};
          return MaterialPageRoute(
            builder: (context) => ProductListScreen.fromArguments(arguments),
            settings: RouteSettings(
              name: routeName,
              arguments: settings.arguments,
            ),
          );
        }

        // 제품 목록 페이지: /product/, /product/
        final isProductListRoute = uri.pathSegments.isNotEmpty &&
            uri.pathSegments[0] == 'product' &&
            (uri.pathSegments.length == 1 ||
                (uri.pathSegments.length == 2 &&
                    uri.pathSegments[1].trim().isEmpty));
        if (isProductListRoute) {
          final rawArguments =
              settings.arguments as Map<String, dynamic>? ?? {};
          final arguments = <String, dynamic>{
            'categoryId': '10',
            'categoryName': '다이어트',
            'productKind': 'prescription',
            ...rawArguments,
          };
          return MaterialPageRoute(
            builder: (context) => ProductListScreen.fromArguments(arguments),
            settings: RouteSettings(
              name: routeName,
              arguments: settings.arguments,
            ),
          );
        }

        // 제품 목록 페이지: /product-general/, /product-general/
        final isProductGeneralListRoute = uri.pathSegments.isNotEmpty &&
            uri.pathSegments[0] == 'product-general' &&
            (uri.pathSegments.length == 1 ||
                (uri.pathSegments.length == 2 &&
                    uri.pathSegments[1].trim().isEmpty));
        if (isProductGeneralListRoute) {
          final rawArguments =
              settings.arguments as Map<String, dynamic>? ?? {};
          final arguments = <String, dynamic>{
            'categoryId': '11',
            'categoryName': '다이어트 제품',
            'productKind': 'general',
            ...rawArguments,
          };
          return MaterialPageRoute(
            builder: (context) => ProductListScreen.fromArguments(arguments),
            settings: RouteSettings(
              name: routeName,
              arguments: settings.arguments,
            ),
          );
        }

        // 제품 상세 페이지: /product/:it_id, /product-general/:it_id
        if (uri.pathSegments.length == 2 &&
            uri.pathSegments[0] == 'product' &&
            uri.pathSegments[1].trim().isNotEmpty) {
          // (임시) 상품 상세 페이지 접근 차단
          final productId = uri.pathSegments[1];
          return MaterialPageRoute(
            builder: (context) => ProductDetailScreen(productId: productId),
            settings: RouteSettings(
              name:
                  routeName, // URL 업데이트를 위해 route name 설정 (예: /product/1691479590)
              arguments: settings.arguments,
            ),
          );
        }
        if (uri.pathSegments.length == 2 &&
            uri.pathSegments[0] == 'product-general' &&
            uri.pathSegments[1].trim().isNotEmpty) {
          final productId = uri.pathSegments[1];
          return MaterialPageRoute(
            builder: (context) =>
                ProductDetailGeneralScreen(productId: productId),
            settings: RouteSettings(
              name: routeName,
              arguments: settings.arguments,
            ),
          );
        }

        // 공지 상세: /announcement/:id
        if (uri.pathSegments.length == 2 &&
            uri.pathSegments[0] == 'announcement' &&
            uri.pathSegments[1].trim().isNotEmpty) {
          final id = int.tryParse(uri.pathSegments[1]);
          if (id != null && id > 0) {
            return MaterialPageRoute(
              builder: (context) =>
                  AnnouncementDetailScreen(announcementId: id),
              settings: RouteSettings(
                name: routeName,
                arguments: settings.arguments,
              ),
            );
          }
        }

        // 이벤트 상세: /event/:id
        if (uri.pathSegments.length == 2 &&
            uri.pathSegments[0] == 'event' &&
            uri.pathSegments[1].trim().isNotEmpty) {
          final id = int.tryParse(uri.pathSegments[1]);
          if (id != null && id > 0) {
            return MaterialPageRoute(
              builder: (context) => EventDetailScreen(wrId: id),
              settings: RouteSettings(
                name: routeName,
                arguments: settings.arguments,
              ),
            );
          }
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
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    var loggedIn = await AuthService.isLoggedIn();
    // 탈퇴/차단 시 다른 탭/세션도 다음 진입에서 강제 로그아웃
    if (loggedIn) {
      final active = await AuthService.isSessionActive();
      if (!active) {
        await AuthService.logout();
        loggedIn = false;
      }
    }

    if (mounted) {
      setState(() {
        _isLoggedIn = loggedIn;
        _isLoading = false;
      });
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

    return const MobileLayoutWrapper(initialIndex: 0);
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
