import 'dart:math' as math;

/// 걸음수 기반 거리/칼로리 계산 유틸.
///
/// 현재 프로젝트 기준(고정 계수):
/// - 거리(km) = steps × 0.0007
/// - 칼로리(kcal) = steps × 0.04
class StepCalculator {
  static const double kmPerStep = 0.0007;
  static const double kcalPerStep = 0.04;

  static int clampSteps(int steps) => math.max(0, steps);

  static double kmFromSteps(int steps) {
    final s = clampSteps(steps);
    return s * kmPerStep;
  }

  static int kcalFromSteps(int steps) {
    final s = clampSteps(steps);
    return (s * kcalPerStep).round();
  }
}

