import 'dart:math' as math;

/// 목표 체중까지의 진행률(0~1). 측정 체중([cur])이 목표([tgt]) 쪽으로 얼마나 왔는지.
/// [goalAnchor]는 목표 설정 당시 저장된 현재 체중(시작점).
///
/// 감량: anchor 60, tgt 52 → 전체 구간 8kg. cur 55이면 (60-55)/8 = 5/8.
/// cur ≤ tgt 이면 1.0(목표 달성·초과).
double weightTowardGoalRatio(double cur, double tgt, double? goalAnchor) {
  if (tgt <= 0 || cur <= 0) return 0.0;
  if ((cur - tgt).abs() < 0.05) return 1.0;
  final anchor = goalAnchor;
  if (anchor == null || (anchor - tgt).abs() < 0.05) {
    final d = (cur - tgt).abs();
    final scale = math.max(math.max(cur, tgt), 30.0) * 0.2;
    return (1.0 - (d / scale)).clamp(0.0, 1.0);
  }
  if (anchor > tgt) {
    if (cur >= anchor) return 0.0;
    if (cur <= tgt) return 1.0;
    return ((anchor - cur) / (anchor - tgt)).clamp(0.0, 1.0);
  }
  if (anchor < tgt) {
    if (cur <= anchor) return 0.0;
    if (cur >= tgt) return 1.0;
    return ((cur - anchor) / (tgt - anchor)).clamp(0.0, 1.0);
  }
  return 1.0;
}
