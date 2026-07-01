/// 생리주기 계산 공용 유틸
///
/// 이미지 기준 규칙:
/// - 배란기: [cycleLength] - 14일차
/// - 가임기: 배란기 기준 -3일 ~ +1일
/// - 생리 중: 1일 ~ [periodLength]일
/// - 생리 후: 생리 중 다음날 ~ 배란기 전날
/// - 배란기: 배란기
/// - 생리 전: 배란기 다음날 ~ 주기 마지막날
class MenstrualCycleCalculator {
  const MenstrualCycleCalculator._();

  static int cycleDayForDate({
    required DateTime date,
    required DateTime cycleStartDate,
    required int cycleLength,
  }) {
    if (cycleLength <= 0) return 1;
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedStart =
        DateTime(cycleStartDate.year, cycleStartDate.month, cycleStartDate.day);
    final daysSinceStart = normalizedDate.difference(normalizedStart).inDays;
    return (daysSinceStart % cycleLength) + 1;
  }

  static int ovulationDay(int cycleLength) {
    if (cycleLength <= 0) return 1;
    return (cycleLength - 14).clamp(1, cycleLength).toInt();
  }

  static int fertileWindowStartDay(int cycleLength) {
    final ovulation = ovulationDay(cycleLength);
    return (ovulation - 3).clamp(1, cycleLength).toInt();
  }

  static int fertileWindowEndDay(int cycleLength) {
    final ovulation = ovulationDay(cycleLength);
    return (ovulation + 1).clamp(1, cycleLength).toInt();
  }

}
