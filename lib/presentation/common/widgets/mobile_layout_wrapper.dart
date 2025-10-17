import 'package:flutter/material.dart';

/// 모바일 앱처럼 600px 고정 너비로 감싸는 공통 위젯
class MobileLayoutWrapper extends StatelessWidget {
  final Widget child;
  final bool showShadow;
  final Color? backgroundColor;

  const MobileLayoutWrapper({
    super.key,
    required this.child,
    this.showShadow = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // 외부 배경색
      body: Center(
        child: Container(
          width: 600, // 모바일 화면 크기로 고정
          height: double.infinity,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white,
            boxShadow: showShadow ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 5,
              ),
            ] : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// AppBar를 포함한 완전한 모바일 레이아웃 래퍼
class MobileAppLayoutWrapper extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;
  final bool showShadow;
  final Color? backgroundColor;

  const MobileAppLayoutWrapper({
    super.key,
    required this.child,
    this.appBar,
    this.showShadow = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // 외부 배경색
      body: Center(
        child: Container(
          width: 600, // 모바일 화면 크기로 고정
          height: double.infinity,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white,
            boxShadow: showShadow ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 5,
              ),
            ] : null,
          ),
          child: Scaffold(
            backgroundColor: Colors.white, // 내부 배경색을 흰색으로
            appBar: appBar,
            body: child,
          ),
        ),
      ),
    );
  }
}
