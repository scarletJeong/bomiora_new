import 'package:flutter/material.dart';

import 'navi_bar.dart';

/// [MobileAppLayoutWrapper] 패널 가로 폭 안에 스낵바를 표시합니다.
class LayoutScaffoldMessenger extends ScaffoldMessenger {
  const LayoutScaffoldMessenger({
    super.key,
    required super.child,
    this.maxWidth = 650,
  });

  final double maxWidth;

  @override
  ScaffoldMessengerState createState() => _LayoutScaffoldMessengerState();
}

class _LayoutScaffoldMessengerState extends ScaffoldMessengerState {
  double get _maxWidth {
    final messenger = context.findAncestorWidgetOfExactType<LayoutScaffoldMessenger>();
    return messenger?.maxWidth ?? 650;
  }

  SnackBar _constrainSnackBar(SnackBar snackBar) {
    final screenW = MediaQuery.sizeOf(context).width;
    final panelW = MobileAppLayoutWrapper.contentWidthOf(
      context,
      maxWidth: _maxWidth,
    );
    final sideMargin = ((screenW - panelW) / 2).clamp(0.0, double.infinity);
    const inset = 16.0;
    final barWidth = (panelW - inset * 2).clamp(0.0, panelW);

    return SnackBar(
      key: snackBar.key,
      content: snackBar.content,
      backgroundColor: snackBar.backgroundColor,
      elevation: snackBar.elevation,
      margin: EdgeInsets.fromLTRB(
        sideMargin + inset,
        0,
        sideMargin + inset,
        16,
      ),
      padding: snackBar.padding,
      width: barWidth,
      shape: snackBar.shape,
      behavior: SnackBarBehavior.floating,
      duration: snackBar.duration,
      action: snackBar.action,
      actionOverflowThreshold: snackBar.actionOverflowThreshold,
      showCloseIcon: snackBar.showCloseIcon,
      closeIconColor: snackBar.closeIconColor,
      dismissDirection: snackBar.dismissDirection,
      onVisible: snackBar.onVisible,
      clipBehavior: snackBar.clipBehavior,
    );
  }

  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    SnackBar snackBar, {
    AnimationStyle? snackBarAnimationStyle,
  }) {
    return super.showSnackBar(
      _constrainSnackBar(snackBar),
      snackBarAnimationStyle: snackBarAnimationStyle,
    );
  }
}

/// 모바일 앱처럼 [maxWidth]로 가로를 제한해 가운데 정렬하는 공통 위젯.
class MobileLayoutWrapper extends StatelessWidget {
  final Widget child;
  final bool showShadow;
  final bool showSideNav;
  final Color? backgroundColor;
  final double maxWidth;

  const MobileLayoutWrapper({
    super.key,
    required this.child,
    this.showShadow = true,
    this.showSideNav = true,
    this.backgroundColor,
    this.maxWidth = 650,
  });

  /// 앱 콘텐츠 패널 가로 폭 (다이얼로그·오버레이 정렬용)
  static double contentWidthOf(BuildContext context, {double maxWidth = 650}) {
    final screenW = MediaQuery.sizeOf(context).width;
    return screenW > maxWidth ? maxWidth : screenW;
  }

  static const double _sideNavGap = 16;

  Widget _contentPanel({
    required BuildContext context,
    required double contentWidth,
    required Widget child,
  }) {
    return MediaQuery(
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
    );
  }

  /// 바깥 래퍼에서만 세로 네비를 그린다 (안쪽 중첩 래퍼 중복 방지).
  bool _shouldShowSideNav(BoxConstraints constraints, double screenWidth) {
    if (!showSideNav) return false;
    if (screenWidth < kFooterBarWideBreakpoint) return false;
    return !(constraints.maxWidth <= maxWidth && screenWidth > maxWidth);
  }

  Widget _wideLayout({
    required BuildContext context,
    required BoxConstraints constraints,
    required double contentWidth,
    required Widget child,
  }) {
    final panel = _contentPanel(
      context: context,
      contentWidth: contentWidth,
      child: child,
    );
    final panelLeft = (constraints.maxWidth - contentWidth) / 2;
    final navLeft = panelLeft + contentWidth + _sideNavGap;
    const navReserve = 100.0;
    final fitsBesidePanel = navLeft + navReserve <= constraints.maxWidth;

    return Stack(
      children: [
        Center(child: panel),
        Positioned(
          left: fitsBesidePanel ? navLeft : null,
          right: fitsBesidePanel ? null : 8,
          top: 0,
          bottom: 0,
          child: const Center(child: SideNaviBar()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = MediaQuery.sizeOf(context).width;
          final contentWidth = constraints.maxWidth > maxWidth
              ? maxWidth
              : constraints.maxWidth;

          if (_shouldShowSideNav(constraints, screenWidth)) {
            return _wideLayout(
              context: context,
              constraints: constraints,
              contentWidth: contentWidth,
              child: child,
            );
          }

          return Center(
            child: _contentPanel(
              context: context,
              contentWidth: contentWidth,
              child: child,
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
  final Widget? bottomNavigationBar;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final bool showShadow;
  final bool showSideNav;
  final Color? backgroundColor;
  final Color? outerBackgroundColor;
  final double maxWidth;

  const MobileAppLayoutWrapper({
    super.key,
    required this.child,
    this.appBar,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.scaffoldKey,
    this.showShadow = true,
    this.showSideNav = true,
    this.backgroundColor,
    this.outerBackgroundColor,
    this.maxWidth = 650,
  });

  /// 앱 콘텐츠 패널 가로 폭 (다이얼로그·오버레이 정렬용)
  static double contentWidthOf(BuildContext context, {double maxWidth = 650}) {
    final screenW = MediaQuery.sizeOf(context).width;
    return screenW > maxWidth ? maxWidth : screenW;
  }

  static const double _sideNavGap = 16;

  Widget _innerScaffold({
    required PreferredSizeWidget? wrappedAppBar,
    required PreferredSizeWidget? appBar,
  }) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: backgroundColor ?? Colors.white,
      appBar: wrappedAppBar ?? appBar,
      drawer: drawer,
      endDrawer: endDrawer,
      bottomNavigationBar: bottomNavigationBar,
      body: child,
    );
  }

  Widget _contentPanel({
    required BuildContext context,
    required double contentWidth,
    required PreferredSizeWidget? wrappedAppBar,
    required PreferredSizeWidget? appBar,
  }) {
    return MediaQuery(
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
        child: LayoutScaffoldMessenger(
          maxWidth: maxWidth,
          child: _innerScaffold(
            wrappedAppBar: wrappedAppBar,
            appBar: appBar,
          ),
        ),
      ),
    );
  }

  /// 바깥 래퍼에서만 세로 네비를 그린다 (안쪽 중첩 래퍼 중복 방지).
  bool _shouldShowSideNav(BoxConstraints constraints, double screenWidth) {
    if (!showSideNav) return false;
    if (screenWidth < kFooterBarWideBreakpoint) return false;
    return !(constraints.maxWidth <= maxWidth && screenWidth > maxWidth);
  }

  Widget _wideLayout({
    required BuildContext context,
    required BoxConstraints constraints,
    required double contentWidth,
    required PreferredSizeWidget? wrappedAppBar,
    required PreferredSizeWidget? appBar,
  }) {
    final panel = _contentPanel(
      context: context,
      contentWidth: contentWidth,
      wrappedAppBar: wrappedAppBar,
      appBar: appBar,
    );
    final panelLeft = (constraints.maxWidth - contentWidth) / 2;
    final navLeft = panelLeft + contentWidth + _sideNavGap;
    const navReserve = 100.0;
    final fitsBesidePanel = navLeft + navReserve <= constraints.maxWidth;

    return Stack(
      children: [
        Center(child: panel),
        Positioned(
          left: fitsBesidePanel ? navLeft : null,
          right: fitsBesidePanel ? null : 8,
          top: 0,
          bottom: 0,
          child: const Center(child: SideNaviBar()),
        ),
      ],
    );
  }

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
          final screenWidth = MediaQuery.sizeOf(context).width;
          final contentWidth = constraints.maxWidth > maxWidth
              ? maxWidth
              : constraints.maxWidth;

          if (_shouldShowSideNav(constraints, screenWidth)) {
            return _wideLayout(
              context: context,
              constraints: constraints,
              contentWidth: contentWidth,
              wrappedAppBar: wrappedAppBar,
              appBar: appBar,
            );
          }

          return Center(
            child: _contentPanel(
              context: context,
              contentWidth: contentWidth,
              wrappedAppBar: wrappedAppBar,
              appBar: appBar,
            ),
          );
        },
      ),
    );
  }
}
