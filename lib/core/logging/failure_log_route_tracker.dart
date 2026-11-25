import 'package:flutter/widgets.dart';

/// 지금 화면의 라우트 이름. 이름 없는 다이얼로그는 아래 화면 이름을 유지한다.
class FailureLogRouteTracker extends NavigatorObserver {
  static String page = '';

  void _remember(Route<dynamic>? route) {
    final name = route?.settings.name?.trim() ?? '';
    if (name.isEmpty) return;
    page = name;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _remember(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _remember(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _remember(previousRoute);
  }
}
