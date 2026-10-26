import 'package:flutter/material.dart';

/// 화면 이동·제출처럼 한 번만 실행해야 하는 동작.
/// 진행 중에는 다른 터치를 막고, 새 화면이 열리면 그 화면은 다시 누를 수 있다.
class AppActionGate {
  AppActionGate._();

  static final ValueNotifier<bool> splash = ValueNotifier(false);

  static bool _locked = false;
  static int _token = 0;

  static bool get locked => _locked;

  static int _begin() {
    if (_locked) return 0;
    _locked = true;
    _token += 1;
    splash.value = true;
    return _token;
  }

  static void end(int token) {
    if (token == 0 || token != _token) return;
    _token += 1;
    _locked = false;
    splash.value = false;
  }

  /// 다이얼로그·바텀시트처럼 위에 뜨는 화면이 열리면 가림막만 내린다.
  /// 잠금은 동작이 끝날 때까지 유지한다.
  static void reveal() {
    if (!splash.value) return;
    splash.value = false;
  }

  /// 새 페이지가 올라온 뒤 그 페이지의 버튼이 동작하도록 잠금을 푼다.
  static void onPageOpened() {
    reveal();
    if (!_locked) return;
    _token += 1;
    _locked = false;
  }

  static Future<T?> protect<T>(Future<T> Function() action) async {
    final token = _begin();
    if (token == 0) return null;
    try {
      return await action();
    } finally {
      end(token);
    }
  }
}

/// 새 페이지가 열리면 이동 중 가림막을 내리고, 그 페이지의 버튼은 다시 누를 수 있게 한다.
class SinglePagePushObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) {
      AppActionGate.reveal();
      return;
    }
    if (route is! PageRoute) return;
    AppActionGate.onPageOpened();
  }
}
