import 'package:flutter/foundation.dart';

/// 건강 기록(체중·혈압·식단 등) 저장/삭제 시 구독 화면에 새로고침을 알립니다.
class HealthRefreshBus extends ChangeNotifier {
  HealthRefreshBus._();

  static final HealthRefreshBus instance = HealthRefreshBus._();

  void notifyChanged() {
    notifyListeners();
  }
}

void notifyHealthDataChanged() {
  HealthRefreshBus.instance.notifyChanged();
}
