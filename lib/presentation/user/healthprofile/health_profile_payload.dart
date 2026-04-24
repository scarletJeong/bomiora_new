/// 건강프로필 API 페이로드 조합 (문진표 화면과 처방 플로우 공통).
abstract final class HealthProfilePayload {
  HealthProfilePayload._();

  static String formatListToString(dynamic value) {
    if (value == null) return '';
    if (value is List) {
      return value.map((e) => e.toString()).join('|');
    }
    return value.toString();
  }

  static String formatAnswer12(dynamic answer12, String? otherValue) {
    if (answer12 == null) return '';

    if (answer12 is List) {
      final result = <String>[];
      for (final item in answer12) {
        if (item == '기타' && otherValue != null && otherValue.isNotEmpty) {
          result.add('기타: $otherValue');
        } else {
          result.add(item.toString());
        }
      }
      return result.join('|');
    }

    final answer12Str = answer12.toString();
    if (answer12Str == '기타' && otherValue != null && otherValue.isNotEmpty) {
      return '기타: $otherValue';
    }
    return answer12Str;
  }

  /// `HealthProfileFormScreen`과 동일: 빈도 + (선택) `###` + `종목1|종목2`
  static String composeAnswer10(String? frequency, dynamic types) {
    final freq = frequency?.trim() ?? '';
    if (types is List && types.isNotEmpty) {
      final t = types
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .join('|');
      if (t.isNotEmpty) {
        return freq.isEmpty ? '###$t' : '$freq###$t';
      }
    }
    return freq;
  }

  /// DB 분리 저장용: `answer_10` = 운동 빈도, `answer_10_2` = 주로 하는 운동(파이프)
  static String composeAnswer10FrequencyOnly(String? frequency) =>
      (frequency ?? '').trim();

  static String composeAnswer10TypesOnly(dynamic types) {
    if (types is List && types.isNotEmpty) {
      return types
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .join('|');
    }
    return '';
  }

  /// 서버/DB에 맞춘 다이어트 약 코드 (`1` = 없음, `2` = 있음)
  static String encodeAnswer13ForApi(String? value) {
    final s = value?.trim() ?? '';
    if (s == '2' || s == '있음') return '2';
    return '1';
  }

  static void parseAnswer10IntoFormData(
    String raw, {
    String? answer10TypesRaw,
    required void Function(String frequency) setFrequency,
    required void Function(List<String> types) setTypes,
  }) {
    final typesFromColumn = (answer10TypesRaw ?? '').trim();
    if (typesFromColumn.isNotEmpty) {
      var freq = raw.trim();
      if (freq.contains('###')) {
        freq = freq.split('###').first.trim();
      }
      if (freq == '일주일 4회 이상') {
        freq = '일주일 4회 ~ 6회';
      }
      setFrequency(freq);
      setTypes(
        typesFromColumn
            .split('|')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
      );
      return;
    }

    if (raw.contains('###')) {
      final p = raw.split('###');
      var freq = p[0].trim();
      if (freq == '일주일 4회 이상') {
        freq = '일주일 4회 ~ 6회';
      }
      setFrequency(freq);
      final rest = p.length > 1 ? p[1].trim() : '';
      setTypes(
        rest.isEmpty
            ? <String>[]
            : rest.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      );
    } else {
      var freq = raw;
      if (freq == '일주일 4회 이상') {
        freq = '일주일 4회 ~ 6회';
      }
      setFrequency(freq);
      setTypes(<String>[]);
    }
  }
}
