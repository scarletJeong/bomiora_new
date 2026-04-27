import 'menstrual_cycle_model.dart';

/// 여러 생리 기록 중, 달력에서 고른 날짜에 대응하는 **한 행**을 고른다.
///
/// 1) [displayPeriodStart, displayPeriodEnd] 안에 들어가는 행이 있으면
///    그중 `lastPeriodStart`가 **가장 늦은** 행(최근 생리)을 사용한다.
///    → 4/27 생리가 있으면, 이전 행의 28일 주기 안에 4/27이 있어도 4/27 행이 선택된다.
/// 2) 없으면 예전처럼 [lastPeriodStart, lastPeriodStart + cycleLength - 1] 안에서
///    마찬가지로 가장 최근 행부터 매칭한다.
/// 3) 그래도 없으면 전체 중 `lastPeriodStart`가 가장 늦은 행.
class MenstrualCycleRecordSelector {
  static DateTime _dateOnly(DateTime t) =>
      DateTime(t.year, t.month, t.day);

  static bool _inRange(DateTime d, DateTime start, DateTime end) {
    final dd = _dateOnly(d);
    final s = _dateOnly(start);
    final e = _dateOnly(end);
    return !dd.isBefore(s) && !dd.isAfter(e);
  }

  static MenstrualCycleRecord? pickForDay(
    List<MenstrualCycleRecord> records,
    DateTime selectedDay,
  ) {
    if (records.isEmpty) return null;
    final sorted = [...records]
      ..sort((a, b) => b.lastPeriodStart.compareTo(a.lastPeriodStart));

    final d = _dateOnly(selectedDay);

    for (final r in sorted) {
      if (_inRange(d, r.displayPeriodStart, r.displayPeriodEnd)) {
        return r;
      }
    }

    for (final r in sorted) {
      final start = _dateOnly(r.lastPeriodStart);
      final end = start.add(Duration(days: r.cycleLength - 1));
      if (_inRange(d, start, end)) {
        return r;
      }
    }

    return sorted.first;
  }
}
