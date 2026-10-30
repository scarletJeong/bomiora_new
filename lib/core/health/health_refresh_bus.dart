import 'package:flutter/foundation.dart';

import '../../data/repositories/health/dashboard/health_dashboard_repository.dart';

/// 건강 기록 갱신 영역. 값을 비우면 구독 화면 전체를 다시 읽는다.
abstract final class HealthRefreshDomain {
  static const weight = 'weight';
  static const food = 'food';
  static const bloodPressure = 'blood_pressure';
  static const bloodSugar = 'blood_sugar';
  static const menstrual = 'menstrual';
  static const heartRate = 'heart_rate';
  static const steps = 'steps';
}

/// [domain]이 비어 있거나 이 화면의 영역과 같으면 다시 읽는다.
bool healthRefreshIncludes(String domain) {
  final current = HealthRefreshBus.instance.domain;
  return current == null || current == domain;
}

/// 건강 기록(체중·혈압·식단 등) 저장/삭제 시 구독 화면에 새로고침을 알립니다.
class HealthRefreshBus extends ChangeNotifier {
  HealthRefreshBus._();

  static final HealthRefreshBus instance = HealthRefreshBus._();

  /// 마지막으로 바뀐 영역. null이면 전체.
  String? domain;

  void notifyChanged([String? domain]) {
    this.domain = domain;
    notifyListeners();
  }
}

void notifyHealthDataChanged([String? domain]) {
  HealthDashboardRepository.applyDomainCaches();
  HealthRefreshBus.instance.notifyChanged(domain);
}
