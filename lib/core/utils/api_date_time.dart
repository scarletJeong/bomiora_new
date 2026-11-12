/// Node 건강 API와 맞춘 날짜·시각.
///
/// 조회·저장에 보내는 연·월·일·시는 한국시간(UTC+9) 벽시계 하나다.
/// `toIso8601String`의 UTC 날짜는 자정과 오전 9시 이전에 하루 밀린다.
/// 서버는 타임존 없는 `yyyy-MM-dd HH:mm:ss`를 한국시간으로 읽는다.
/// 응답의 UTC ISO는 [parseInstant]로 같은 시각의 로컬 [DateTime]이 된다.
class ApiDateTime {
  ApiDateTime._();

  static const Duration _kstOffset = Duration(hours: 9);

  /// [date] instant의 한국시간 벽시계. 반환값의 UTC 필드가 연·월·일·시다.
  static DateTime kstWallClock(DateTime date) {
    final shifted = date.toUtc().add(_kstOffset);
    return DateTime.utc(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
      shifted.millisecond,
    );
  }

  /// 한국시간 `yyyy-MM-dd`.
  static String kstDateYmd(DateTime date) {
    final k = kstWallClock(date);
    final m = k.month.toString().padLeft(2, '0');
    final d = k.day.toString().padLeft(2, '0');
    return '${k.year}-$m-$d';
  }

  /// 한국시간 `yyyy-MM-dd HH:mm:ss`.
  static String kstDateTimeText(DateTime date) {
    final k = kstWallClock(date);
    final h = k.hour.toString().padLeft(2, '0');
    final mi = k.minute.toString().padLeft(2, '0');
    final s = k.second.toString().padLeft(2, '0');
    return '${kstDateYmd(date)} $h:$mi:$s';
  }

  /// API instant → 로컬 [DateTime] (동일 시각, 사용자 타임존).
  static DateTime? parseInstant(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) {
      return value.isUtc ? value.toLocal() : value;
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    if (raw.contains('0000-00-00') || raw.contains('1900-01-01')) {
      return null;
    }
    try {
      final parsed = DateTime.parse(raw);
      return parsed.isUtc ? parsed.toLocal() : parsed;
    } catch (_) {
      return null;
    }
  }

  /// `record_date` 등 **날짜만** 오는 경우 달력 키용(로컬 정오, DST 경계 완화).
  /// 전체 ISO instant가 오면 [parseInstant]와 동일하게 로컬로 변환.
  static DateTime parseRecordDate(dynamic value) {
    if (value == null) return DateTime.now();
    final s = value.toString().trim();
    if (s.isEmpty) return DateTime.now();
    try {
      if (s.length == 10 && s.contains('-')) {
        return DateTime.parse('${s}T12:00:00');
      }
      final parsed = DateTime.parse(s);
      return parsed.isUtc ? parsed.toLocal() : parsed;
    } catch (_) {
      return DateTime.now();
    }
  }
}
