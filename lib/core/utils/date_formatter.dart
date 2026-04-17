class DateDisplayFormatter {
  static String formatYmd(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  static String formatYmdDash(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String formatYmdFromString(String? raw, {String fallback = '-'}) {
    if (raw == null || raw.isEmpty) return fallback;
    final flexible = tryParseYmdFlexible(raw);
    if (flexible != null) return formatYmd(flexible);
    try {
      return formatYmd(DateTime.parse(raw));
    } catch (_) {
      return fallback;
    }
  }

  static String formatKoreanDateFromString(String? raw,
      {String fallback = '-'}) {
    if (raw == null || raw.isEmpty) return fallback;
    try {
      final date = DateTime.parse(raw);
      return '${date.year}년 ${date.month}월 ${date.day}일';
    } catch (_) {
      return fallback;
    }
  }

  static String formatYmdWeekdayShort(DateTime? date, {String fallback = '-'}) {
    if (date == null) return fallback;
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final wd = weekdays[date.weekday - 1];
    return '${formatYmd(date)} $wd';
  }

  static String formatYmdWeekdayLong(DateTime? date, {String fallback = '-'}) {
    if (date == null) return fallback;
    const weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    final wd = weekdays[date.weekday - 1];
    return '${formatYmd(date)} $wd';
  }

  /// JS `Date.toString()` / 일부 API가 넘기는 로캘 문자열
  /// 예: `Fri Apr 17 2026 11:07:38 GMT+0900 (대한민국 표준시)`
  /// 날짜만 필요하므로 문자열에 나온 연·월·일을 그대로 사용한다.
  static DateTime? tryParseJavaScriptLocaleDateString(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;
    s = s.replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '');

    const months = <String, int>{
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };

    final m = RegExp(
      r'^[A-Za-z]{3}\s+([A-Za-z]{3})\s+(\d{1,2})\s+(\d{4})\s+'
      r'\d{1,2}:\d{2}:\d{2}\s+GMT',
      caseSensitive: false,
    ).firstMatch(s);
    if (m == null) return null;

    final mon = months[m.group(1)!.toLowerCase()];
    if (mon == null) return null;
    final day = int.tryParse(m.group(2)!);
    final year = int.tryParse(m.group(3)!);
    if (day == null || year == null) return null;
    if (day < 1 || day > 31) return null;

    return DateTime.utc(year, mon, day);
  }

  static DateTime? tryParseYmdFlexible(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;
    final js = tryParseJavaScriptLocaleDateString(t);
    if (js != null) return js;
    final dot = RegExp(r'^(\d{4})\.(\d{1,2})\.(\d{1,2})').firstMatch(t);
    if (dot != null) {
      return DateTime(
        int.parse(dot.group(1)!),
        int.parse(dot.group(2)!),
        int.parse(dot.group(3)!),
      );
    }
    try {
      final head =
          t.contains('T') ? t : t.replaceAll('.', '-').split(' ').first;
      if (head.length >= 10) {
        return DateTime.parse(head.substring(0, 10));
      }
      return DateTime.parse(head);
    } catch (_) {
      return null;
    }
  }

  static String formatYmdRange(String? start, String? end,
      {String fallback = '-'}) {
    if (start == null || end == null || start.isEmpty || end.isEmpty) {
      return fallback;
    }
    final s = tryParseYmdFlexible(start);
    final e = tryParseYmdFlexible(end);
    if (s == null || e == null) return fallback;
    return '${formatYmd(s)} ~ ${formatYmd(e)}';
  }

  /// 예약일자 표시 형식으로 변환
  /// - 예: `Wed Jan 21 2026` -> `2026.01.21 수`
  /// - 예: `2026-01-21` -> `2026.01.21 수`
  static String formatReservationDateWithWeekday(String? raw) {
    if (raw == null || raw.isEmpty || raw == '-') return '-';

    int? parseMonth(String abbr) {
      const months = {
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };
      return months[abbr.toLowerCase()];
    }

    String format(DateTime d) {
      const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
      final wd = weekdays[d.weekday - 1];
      return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} $wd';
    }

    try {
      if (raw.contains('T') || raw.contains('-')) {
        return format(DateTime.parse(raw));
      }

      final cleaned = raw.trim().replaceAll(',', ' ');
      final match = RegExp(
        r'^(?:[A-Za-z]{3}\s+)?([A-Za-z]{3})\s+(\d{1,2})(?:\s+(\d{4}))?$',
      ).firstMatch(cleaned);

      if (match != null) {
        final month = parseMonth(match.group(1)!);
        final day = int.tryParse(match.group(2)!);
        final year = int.tryParse(match.group(3) ?? '') ?? DateTime.now().year;
        if (month != null && day != null) {
          return format(DateTime(year, month, day));
        }
      }

      return '-';
    } catch (_) {
      return '-';
    }
  }
}
