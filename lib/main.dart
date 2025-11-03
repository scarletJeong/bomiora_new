import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'presentation/home/screens/home_screen.dart';
import 'presentation/auth/screens/login_screen.dart';
import 'data/services/auth_service.dart';
import 'presentation/common/widgets/mobile_layout_wrapper.dart';
import 'presentation/shopping/screens/product_detail_screen.dart';
import 'presentation/shopping/screens/product_list_screen.dart';

void main() {
  runApp(const BomioraApp());
}

class BomioraApp extends StatelessWidget {
  const BomioraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
        '/home': (context) => const MobileLayoutWrapper(),
      },
      onGenerateRoute: (settings) {
        // 동적 라우트 처리
        final routeName = settings.name ?? '';
        final uri = Uri.parse(routeName);
        
        // 제품 목록 페이지: /product-list
        if (uri.pathSegments.length == 1 && uri.pathSegments[0] == 'product-list') {
          final arguments = settings.arguments as Map<String, dynamic>? ?? {};
          return MaterialPageRoute(
            builder: (context) => ProductListScreen.fromArguments(arguments),
            settings: RouteSettings(
              name: routeName,
              arguments: settings.arguments,
            ),
          );
        }
        
        // 제품 상세 페이지: /product/:it_id
        if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'product') {
          final productId = uri.pathSegments[1];
          return MaterialPageRoute(
            builder: (context) => ProductDetailScreen(productId: productId),
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
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    setState(() {
      _isLoggedIn = isLoggedIn;
      _isLoading = false;
    });
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

    return _isLoggedIn ? const MobileLayoutWrapper() : const LoginScreen();
  }
}

// 모바일 전용 레이아웃 래퍼 (공통 위젯 사용)
class MobileLayoutWrapper extends StatelessWidget {
  const MobileLayoutWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      child: const HomeScreen(),
    );
  }
}
