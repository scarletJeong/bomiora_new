/// Node 건강 API와 맞춘 날짜·시각 파싱.
///
/// 서버는 시각을 UTC ISO-8601(`...Z` 또는 오프셋)로 통일해 내려주고,
/// 클라이언트는 화면 표시를 위해 [parseInstant]로 **기기 로컬** [DateTime]으로 맞춘다.
class ApiDateTime {
  ApiDateTime._();

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
