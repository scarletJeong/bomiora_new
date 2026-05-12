import 'package:flutter/material.dart';

/// 모바일 앱처럼 [maxWidth]로 가로를 제한해 가운데 정렬하는 공통 위젯.
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
      backgroundColor: Colors.grey[100],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth > maxWidth
              ? maxWidth
              : constraints.maxWidth;
          return Center(
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.0),
              ),
              child: Container(
                width: contentWidth,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: backgroundColor ?? Colors.white,
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
          );
        },
      ),
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
      backgroundColor: outerBackgroundColor ?? Colors.grey[100],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth > maxWidth
              ? maxWidth
              : constraints.maxWidth;
          return Center(
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.0),
              ),
              child: Container(
                width: contentWidth,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: backgroundColor ?? Colors.white,
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
                  backgroundColor: backgroundColor ?? Colors.white,
                  appBar: wrappedAppBar ?? appBar,
                  drawer: drawer,
                  endDrawer: endDrawer,
                  body: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
