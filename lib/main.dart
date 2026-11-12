import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'presentation/home/screens/home_screen.dart';
import 'core/utils/kcp_pay_session_store.dart';
import 'presentation/common/screens/kcp_pay_resume_splash.dart';
import 'presentation/common/screens/splash_screen.dart';
import 'presentation/auth/screens/login_screen.dart';
import 'presentation/auth/screens/find_account_main_screen.dart';
import 'presentation/auth/screens/find_account_not_found_screen.dart';
import 'presentation/auth/screens/find_account_result_screen.dart';
import 'presentation/auth/screens/find_password_reset_screen.dart';
import 'core/navigation/app_action_gate.dart';
import 'core/navigation/app_navigator_key.dart';
import 'presentation/auth/widgets/kcp_cert.dart';
import 'presentation/auth/screens/signup_screen.dart';
import 'presentation/auth/screens/signup_done_screen.dart';
import 'presentation/auth/screens/social_signup_screen.dart';
import 'data/services/kakao_auth_service.dart';
import 'data/services/naver_auth_service.dart';
import 'data/services/fcm_service_stub.dart'
    if (dart.library.io) 'data/services/fcm_service.dart';
import 'presentation/common/widgets/keyboard_field_lift.dart';
import 'presentation/common/widgets/mobile_layout_wrapper.dart';
import 'presentation/shopping/screens/product_detail_screen.dart';
import 'presentation/shopping/screens/product_detail_general_screen.dart';
import 'presentation/shopping/screens/product_list_screen.dart';
import 'presentation/shopping/screens/bomiora_introduce_screen.dart';
import 'presentation/shopping/screens/kcp_pay_webview_screen.dart';
import 'presentation/shopping/screens/payment_complete_screen.dart';
import 'presentation/shopping/screens/cart_screen.dart';
import 'presentation/shopping/screens/cart_general_screen.dart' as cart_general;
import 'presentation/shopping/screens/cart_integration_screen.dart';
import 'presentation/shopping/wish/screens/wish_list_screen.dart';
import 'data/models/address/shipping_address.dart';
import 'presentation/user/myPage/screens/address_form_screen.dart';
import 'presentation/user/myPage/screens/cancel_member_screen.dart';
import 'presentation/user/myPage/screens/cancel_member_2_screen.dart';
import 'presentation/user/myPage/screens/cancel_member_done_screen.dart';
import 'presentation/customer_service/screens/qa_list_screen.dart';
import 'presentation/customer_service/screens/qa_detail_screen.dart';
import 'presentation/customer_service/screens/qa_write_screen.dart';
import 'presentation/user/point/screens/point_screen.dart';
import 'presentation/user/delivery/delivery_list_review.dart';
import 'presentation/user/delivery/delivery_list_screen.dart';
import 'presentation/user/delivery/delivery_detail_screen.dart';
import 'data/models/delivery/delivery_model.dart';
import 'presentation/user/coupon/screens/coupon_screen.dart';
import 'presentation/user/healthprofile/screens/health_profile_list_screen.dart';
import 'presentation/user/review/my_reviews_screen.dart';
import 'presentation/health/dashboard/screens/health_dashboard_screen.dart';
import 'presentation/community/announcement/screens/announcement_list_screen.dart';
import 'presentation/community/announcement/screens/announcement_detail_screen.dart';
import 'presentation/community/event/screens/event_list_screen.dart';
import 'presentation/community/event/screens/event_detail_screen.dart';
import 'presentation/content/dashboard/screens/content_list_screen.dart';
import 'presentation/content/dashboard/screens/content_detail_screen.dart';
import 'presentation/home/search/search_list_screen.dart';
import 'presentation/review/screens/review_best_screen.dart';
import 'presentation/common/widgets/dropdown_btn.dart';
import 'core/utils/inf_code_tracker.dart';

/// 개발용: 앱 시작 시 로그인 화면을 먼저 표시
const bool kDevForceLoginScreenFirst = false;

Map<String, WidgetBuilder> _appRoutes = {};
Route<dynamic>? Function(RouteSettings settings)? _appOnGenerateRoute;

Widget _rootEntry() {
  if (kDevForceLoginScreenFirst) return const LoginScreen();
  if ((readKcpPayToken() ?? '').isNotEmpty) {
    return const KcpPayResumeSplash();
  }
  return const SplashScreen();
}

bool _isAppHomePath(String name) {
  final path = Uri.tryParse(name)?.path ?? name;
  return path.isEmpty || path == '/' || path == '/home';
}

Route<dynamic> _livingHomeRoute() {
  return MaterialPageRoute<void>(
    settings: const RouteSettings(name: '/home'),
    builder: (_) => _rootEntry(),
  );
}

Route<dynamic>? _routeForName(String name) {
  final generated = _appOnGenerateRoute?.call(RouteSettings(name: name));
  if (generated != null) return generated;
  final path = Uri.tryParse(name)?.path;
  final lookup = (path == null || path.isEmpty) ? name : path;
  final builder = _appRoutes[lookup];
  if (builder == null) return null;
  return MaterialPageRoute<dynamic>(
    settings: RouteSettings(name: name),
    builder: builder,
  );
}

Route<dynamic>? _socialSignupRoute(RouteSettings settings) {
  final uri = Uri.tryParse(settings.name ?? '');
  if (uri?.path != '/social-signup') return null;

  final args = settings.arguments as Map<String, dynamic>?;
  final raw = (args?['provider'] ?? uri?.queryParameters['provider'] ?? 'kakao')
      .toString()
      .trim()
      .toLowerCase();
  final provider = raw == 'naver' || raw == 'apple' ? raw : 'kakao';

  String? queryValue(String key) {
    final fromRoute = uri?.queryParameters[key];
    if (fromRoute != null && fromRoute.isNotEmpty) return fromRoute;
    final fromBase = Uri.base.queryParameters[key];
    if (fromBase != null && fromBase.isNotEmpty) return fromBase;
    return null;
  }

  return MaterialPageRoute<dynamic>(
    settings: RouteSettings(
      name: '/social-signup?provider=$provider',
      arguments: settings.arguments,
    ),
    builder: (context) => SocialSignupScreen(
      provider: provider,
      identifier: (args?['identifier'] ?? '').toString(),
      email: args?['email']?.toString() ??
          (args == null ? queryValue('email') : null),
      nickname: args?['nickname']?.toString(),
      name: args?['name']?.toString(),
      gender: args?['gender']?.toString(),
      birthday: args?['birthday']?.toString(),
      profileImageUrl: args?['profileImageUrl']?.toString(),
      identityToken: args?['identityToken']?.toString(),
      authorizationCode: args?['authorizationCode']?.toString(),
    ),
  );
}

/// `/` 와 `/home` 은 스플래시가 준비하는 같은 홈이다.
/// 그 외 주소는 그 홈 위에 기존과 같이 쌓는다.
List<Route<dynamic>> _appInitialRoutes(String initialRouteName) {
  if (_isAppHomePath(initialRouteName)) return [_livingHomeRoute()];

  final uri = Uri.tryParse(initialRouteName);
  final path = (uri?.path ?? initialRouteName).isEmpty
      ? '/'
      : (uri?.path ?? initialRouteName);
  final fullName = initialRouteName.contains('?') ? initialRouteName : path;
  final full = _routeForName(fullName);
  if (full == null) return [_livingHomeRoute()];

  final routes = <Route<dynamic>>[_livingHomeRoute()];
  final parts = path.split('/').where((part) => part.isNotEmpty).toList();
  var acc = '';
  for (var i = 0; i < parts.length; i++) {
    acc = '$acc/${parts[i]}';
    if (i == parts.length - 1) {
      routes.add(full);
      break;
    }
    final route = _routeForName(acc);
    if (route != null) routes.add(route);
  }
  return routes;
}

/// Flutter web hot restart / WebView 종료 시 엔진이 이미 dispose된
/// EngineFlutterView를 계속 그리면서 window.dart:99 assertion이 매 프레임
/// 반복되는 것을 막는다.
void _installWebDisposedViewErrorGuard() {
  if (!kIsWeb) return;
  FlutterError.onError = (details) {
    final text = '${details.exceptionAsString()}\n${details.stack ?? ''}';
    final disposedView = text.contains('window.dart:99') ||
        text.contains('Trying to render a disposed EngineFlutterView');
    if (disposedView) return;
    FlutterError.presentError(details);
  };
}

void main() async {
  // Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  _installWebDisposedViewErrorGuard();

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
  await loadKcpPaySession();

  runApp(const BomioraApp());
}

class BomioraApp extends StatefulWidget {
  const BomioraApp({super.key});

  @override
  State<BomioraApp> createState() => _BomioraAppState();
}

class _BomioraAppState extends State<BomioraApp> {
  final _singlePagePushObserver = SinglePagePushObserver();
  @override
  void reassemble() {
    super.reassemble();
    // hot reload는 main()을 다시 안 타므로, 예전 로그 핸들러가 남지 않게 재설치
    _installWebDisposedViewErrorGuard();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DropdownBtn.closeMenu();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      navigatorObservers: [_singlePagePushObserver, appRouteObserver],
      title: '보미오라',
      builder: (context, child) {
        final media = MediaQuery.of(context);
        // 키보드가 열리면 viewInsets만큼 화면이 줄고 가운데 문구가 위로 올라간다.
        // 인셋을 없애 모든 페이지가 그 자리에 머물게 한다.
        return MediaQuery(
          data: media.copyWith(viewInsets: EdgeInsets.zero),
          child: KeyboardFieldLift(
          child: LayoutScaffoldMessenger(
            child: ValueListenableBuilder<bool>(
              valueListenable: AppActionGate.splash,
              builder: (context, show, _) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    child ?? const SizedBox.shrink(),
                    if (show) ...[
                      const ModalBarrier(
                        dismissible: false,
                        color: Color(0x33000000),
                      ),
                      const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF5A8D),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          ),
        );
      },
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Gmarket Sans TTF',
        visualDensity: VisualDensity.adaptivePlatformDensity,
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFFFF5A8D),
        ),
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
      routes: _appRoutes = {
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
        // 로그인·가입 직후: 스플래시에서 메인 이미지 준비 후 홈 진입
        '/enter-home': (context) => const SplashScreen(checkSession: false),
        '/favorite': (context) => const WishListScreen(),
        '/address/edit': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return AddressFormScreen(
            address: args is ShippingAddress ? args : null,
          );
        },
        '/my_page': (context) => const MobileLayoutWrapper(initialIndex: 1),
        '/health': (context) => const HealthDashboardScreen(),
        '/cart': (context) => const CartScreen(),
        '/generalCart': (context) => const cart_general.CartScreen(),
        '/interCart': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          final name = ModalRoute.of(context)?.settings.name ?? '';
          final queryTab = int.tryParse(
            Uri.tryParse(name)?.queryParameters['tab'] ?? '',
          );
          final rawTab = args?['initialTabIndex'] ?? queryTab;
          final tab = rawTab is int ? rawTab : int.tryParse('${rawTab ?? ''}');
          return CartIntegrationScreen(
            initialTabIndex: tab ?? 0,
            backToProductId: args?['backToProductId']?.toString(),
          );
        },
        '/bomiora-introduce': (context) => const BomioraIntroduceScreen(),
        '/coupon': (context) => const CouponScreen(),
        '/my_reviews': (context) => const MyReviewsScreen(),
        '/profile': (context) => const HealthProfileListScreen(),
        '/qa': (context) => const QaListScreen(),
        '/qa/write': (context) => const QaWriteScreen(),
        '/cancel-member': (context) => const CancelMemberScreen(),
        '/withdraw': (context) => const CancelMemberScreen(),
        '/withdraw/reason': (context) => const Cancel2MemberScreen(),
        '/withdraw/done': (context) => const CancelMemberDoneScreen(),
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
        // `/order-detail` 를 routes에 두면 새로고침 시
        // `/order-detail/:odId` 보다 먼저 주문번호 없는 화면이 열리고
        // 그 화면이 주문 목록으로 바꿔 버린다. 상세는 onGenerateRoute만 연다.
        '/announcement': (context) => const AnnouncementListScreen(),
        '/event': (context) => const EventListScreen(),
        '/content': (context) => const ContentListScreen(),
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
            bypassCache: args?['fresh'] == true,
          );
        },
        '/signup': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return SignupScreen(certInfo: args);
        },
        '/signup-done': (context) => const SignupDoneScreen(),
      },
      onGenerateInitialRoutes: _appInitialRoutes,
      onGenerateRoute: _appOnGenerateRoute = (settings) {
        // 동적 라우트 처리
        final routeName = settings.name ?? '';
        final uri = Uri.parse(routeName);
        InfCodeTracker.captureFromUri(uri);

        final socialSignup = _socialSignupRoute(settings);
        if (socialSignup != null) return socialSignup;

        // KCP 본인인증: 원래 화면이 비치는 딤 오버레이 스타일로 표시
        if (routeName == '/kcp-cert') {
          final args = settings.arguments as Map<String, dynamic>? ?? const {};
          return PageRouteBuilder(
            settings: settings,
            opaque: false,
            barrierDismissible: false,
            barrierColor: const Color(0x991A1A1A),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
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

        // 주문 상세: /order-detail/:od_id
        if (uri.pathSegments.length == 2 &&
            uri.pathSegments[0] == 'order-detail' &&
            uri.pathSegments[1].trim().isNotEmpty) {
          final orderNumber =
              Uri.decodeComponent(uri.pathSegments[1].trim());
          final args = settings.arguments;
          OrderDetailModel? initialOrder;
          var returnToOrderList = false;
          if (args is Map) {
            final preview = args['initialOrder'];
            if (preview is OrderDetailModel) {
              initialOrder = preview;
            }
            returnToOrderList = args['returnToOrderList'] == true ||
                args['fromPaymentComplete'] == true;
          }
          return MaterialPageRoute(
            builder: (context) => DeliveryDetailScreen(
              orderNumber: orderNumber,
              initialOrder: initialOrder,
              returnToOrderList: returnToOrderList,
            ),
            settings: RouteSettings(
              name: routeName,
              arguments: settings.arguments,
            ),
          );
        }

        // 1:1 문의 상세: /qa/:id
        if (uri.pathSegments.length == 2 &&
            uri.pathSegments[0] == 'qa' &&
            uri.pathSegments[1].trim().isNotEmpty) {
          final id = int.tryParse(uri.pathSegments[1]);
          if (id != null && id > 0) {
            return MaterialPageRoute(
              builder: (context) => QaDetailScreen(wrId: id),
              settings: RouteSettings(
                name: routeName,
                arguments: settings.arguments,
              ),
            );
          }
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

        // 주문 리뷰 작성: /review/write/:od_id
        if (uri.pathSegments.length == 3 &&
            uri.pathSegments[0] == 'review' &&
            uri.pathSegments[1] == 'write' &&
            uri.pathSegments[2].trim().isNotEmpty) {
          final odId = Uri.decodeComponent(uri.pathSegments[2].trim());
          return MaterialPageRoute<bool>(
            builder: (context) => OrderReviewWriteRoute(odId: odId),
            settings: RouteSettings(
              name: routeName,
              arguments: settings.arguments,
            ),
          );
        }

        // 홈 베스트 리뷰: /review/best?mr=리뷰번호
        if (uri.path == '/review/best') {
          final raw = uri.queryParameters['mr'];
          final mrNo = int.tryParse((raw ?? '').trim());
          return MaterialPageRoute(
            builder: (context) => ReviewBestScreen(
              initialMrNo: mrNo != null && mrNo > 0 ? mrNo : null,
            ),
            settings: RouteSettings(
              name: routeName,
              arguments: settings.arguments,
            ),
          );
        }

        // 검색 결과: /search?q=검색어 (새로고침·공유용)
        if (uri.path == '/search') {
          final args = settings.arguments as Map<String, dynamic>?;
          final query = uri.queryParameters['q'] ??
              (args?['query'] ?? '').toString();
          return MaterialPageRoute(
            builder: (context) => SearchListScreen(
              initialQuery: query,
              bypassCache: args?['fresh'] == true,
            ),
            settings: RouteSettings(
              name: routeName,
              arguments: settings.arguments,
            ),
          );
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
      resizeToAvoidBottomInset: false,
      child: HomeScreen(initialIndex: initialIndex),
    );
  }
}
