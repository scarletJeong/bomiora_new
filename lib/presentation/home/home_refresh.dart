import 'package:flutter/foundation.dart';

/// 하단 홈, 앱바 홈, 메뉴 홈을 눌렀을 때 이미 떠 있는 홈이 다시 불러오게 한다.
class HomeRefresh {
  HomeRefresh._();

  static final ValueNotifier<int> tick = ValueNotifier<int>(0);

  static void request() {
    tick.value = tick.value + 1;
  }
}
