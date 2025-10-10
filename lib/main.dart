import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth/auth_manager.dart';
import 'widgets/mobile_layout_wrapper.dart';

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
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MobileLayoutWrapper(),
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
    final isLoggedIn = await AuthManager.isLoggedIn();
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
