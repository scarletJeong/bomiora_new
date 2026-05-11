import 'package:flutter/material.dart';
import '../responsive_scale.dart';

/// 모바일 앱처럼 600px 고정 너비로 감싸는 공통 위젯
class MobileLayoutWrapper extends StatelessWidget {
  final Widget child;
  final bool showShadow;
  final Color? backgroundColor;
  final double maxWidth;

  const MobileLayoutWrapper({
    super.key,
    required this.child,
    this.showShadow = true,
    this.backgroundColor,
    this.maxWidth = 650,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // 외부 배경색
      body: LayoutBuilder(builder: (context, constraints) {
        final rs = buildResponsiveScale(
          constraints: constraints,
          maxWidth: maxWidth,
        );
        return Center(
          child: ResponsiveScaleScope(
            data: rs,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                // 전역 텍스트 스케일은 고정. (폰트 반응형은 rs.sp()로만 제어)
                textScaler: const TextScaler.linear(1.0),
              ),
              child: Container(
                width: rs.width, // 최대 maxWidth, 작아지면 화면폭에 맞춤
                height: double.infinity,
                decoration: BoxDecoration(
                  color: backgroundColor ?? Colors.white, // 기본값: 하얀색
                  boxShadow: showShadow
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            spreadRadius: 5,
                          ),
                        ]
                      : null,
                ),
                child: child,
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// AppBar를 포함한 완전한 모바일 레이아웃 래퍼
class MobileAppLayoutWrapper extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final Widget? endDrawer;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final bool showShadow;
  final Color? backgroundColor;
  final Color? outerBackgroundColor;
  final double maxWidth;

  const MobileAppLayoutWrapper({
    super.key,
    required this.child,
    this.appBar,
    this.drawer,
    this.endDrawer,
    this.scaffoldKey,
    this.showShadow = true,
    this.backgroundColor,
    this.outerBackgroundColor,
    this.maxWidth = 650,
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
      backgroundColor: outerBackgroundColor ?? Colors.grey[100], // 외부 배경색
      body: LayoutBuilder(builder: (context, constraints) {
        final rs = buildResponsiveScale(
          constraints: constraints,
          maxWidth: maxWidth,
        );
        return Center(
          child: ResponsiveScaleScope(
            data: rs,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                // 전역 텍스트 스케일은 고정. (폰트 반응형은 rs.sp()로만 제어)
                textScaler: const TextScaler.linear(1.0),
              ),
              child: Container(
                width: rs.width, // 최대 maxWidth, 작아지면 화면폭에 맞춤
                height: double.infinity,
                decoration: BoxDecoration(
                  color: backgroundColor ?? Colors.white, // 기본값: 하얀색
                  boxShadow: showShadow
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            spreadRadius: 5,
                          ),
                        ]
                      : null,
                ),
                child: Scaffold(
                  key: scaffoldKey,
                  backgroundColor:
                      backgroundColor ?? Colors.white, // 기본값: 하얀색
                  appBar: wrappedAppBar ?? appBar,
                  drawer: drawer,
                  endDrawer: endDrawer,
                  body: child,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
