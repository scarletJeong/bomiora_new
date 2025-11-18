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
            color: backgroundColor ?? Colors.white, // 기본값: 하얀색
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
    PreferredSizeWidget? wrappedAppBar = appBar;
    if (appBar != null && appBar is AppBar) {
      final originalAppBar = appBar as AppBar;
      // 항상 AppBar를 재생성하여 스크롤 시 색상 변경 방지
      wrappedAppBar = AppBar(
        key: originalAppBar.key,
        leading: originalAppBar.leading,
        automaticallyImplyLeading: originalAppBar.automaticallyImplyLeading,
        title: originalAppBar.title,
        actions: originalAppBar.actions,
        flexibleSpace: originalAppBar.flexibleSpace,
        bottom: originalAppBar.bottom,
        elevation: originalAppBar.elevation ?? 0,
        scrolledUnderElevation: originalAppBar.scrolledUnderElevation ?? 0,
        shadowColor: originalAppBar.shadowColor,
        surfaceTintColor: originalAppBar.surfaceTintColor ?? Colors.transparent,
        shape: originalAppBar.shape,
        backgroundColor: originalAppBar.backgroundColor ?? Colors.white,
        foregroundColor: originalAppBar.foregroundColor,
        iconTheme: originalAppBar.iconTheme,
        actionsIconTheme: originalAppBar.actionsIconTheme,
        primary: originalAppBar.primary,
        centerTitle: originalAppBar.centerTitle,
        excludeHeaderSemantics: originalAppBar.excludeHeaderSemantics,
        titleSpacing: originalAppBar.titleSpacing,
        toolbarOpacity: originalAppBar.toolbarOpacity,
        bottomOpacity: originalAppBar.bottomOpacity,
        toolbarHeight: originalAppBar.toolbarHeight,
        leadingWidth: originalAppBar.leadingWidth,
        toolbarTextStyle: originalAppBar.toolbarTextStyle,
        titleTextStyle: originalAppBar.titleTextStyle,
        systemOverlayStyle: originalAppBar.systemOverlayStyle,
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.grey[100], // 외부 배경색
      body: Center(
        child: Container(
          width: 600, // 모바일 화면 크기로 고정
          height: double.infinity,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white, // 기본값: 하얀색
            boxShadow: showShadow ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 5,
              ),
            ] : null,
          ),
          child: Scaffold(
            backgroundColor: backgroundColor ?? Colors.white, // 기본값: 하얀색
            appBar: wrappedAppBar ?? appBar,
            body: child,
          ),
        ),
      ),
    );
  }
}
