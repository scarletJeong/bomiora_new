import 'models/health_profile_model.dart';

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

  static String formatAnswer12(
    dynamic answer12,
    String? otherValue, {
    List<String>? otherValues,
  }) {
    if (answer12 == null) return '';

    final others = <String>[];
    if (otherValues != null) {
      for (final e in otherValues) {
        final t = e.trim();
        if (t.isNotEmpty && !others.contains(t)) others.add(t);
      }
    }
    if (others.isEmpty && otherValue != null && otherValue.trim().isNotEmpty) {
      final v = otherValue.trim();
      for (final part in v.split(RegExp(r'[,|]'))) {
        final t = part.trim();
        if (t.isNotEmpty && !others.contains(t)) others.add(t);
      }
    }

    if (answer12 is List) {
      final result = <String>[];
      var otherEmitted = false;
      for (final item in answer12) {
        if (item == '기타') {
          if (otherEmitted) continue;
          otherEmitted = true;
          if (others.isEmpty) {
            result.add('기타');
          } else {
            for (final o in others) {
              result.add('기타: $o');
            }
          }
        } else {
          result.add(item.toString());
        }
      }
      return result.join('|');
    }

    final answer12Str = answer12.toString();
    if (answer12Str == '기타') {
      if (others.isEmpty) return '기타';
      return others.map((o) => '기타: $o').join('|');
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
      if (freq == '일주일 2~3회' || freq == '일주일 2~ 3회') {
        freq = '일주일 2회 ~ 3회';
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
      if (freq == '일주일 2~3회' || freq == '일주일 2~ 3회') {
        freq = '일주일 2회 ~ 3회';
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
      if (freq == '일주일 2~3회' || freq == '일주일 2~ 3회') {
        freq = '일주일 2회 ~ 3회';
      }
      setFrequency(freq);
      setTypes(<String>[]);
    }
  }

  /// 처방 플로우(연락처/예약)로 넘길 formData 맵 — 기존 문진 저장본 기준
  static Map<String, dynamic> formDataFromProfile(HealthProfileModel p) {
    final map = <String, dynamic>{
      'eatingHabits': <String>[],
      'foodPreference': <String>[],
      'exerciseTypes': <String>[],
      'diseases': <String>[],
      'medications': <String>[],
    };

    final a1 = p.answer1.trim().replaceAll(RegExp(r'\D'), '');
    if (a1.length >= 8) {
      map['birthDate'] = a1.substring(0, 8);
    } else if (a1.isNotEmpty) {
      map['birthDate'] = a1;
    }

    final g = p.answer2.trim();
    if (g == '여' || g == '여성' || g == 'F' || g.toUpperCase() == 'F') {
      map['gender'] = 'F';
    } else if (g == '남' || g == '남성' || g == 'M' || g.toUpperCase() == 'M') {
      map['gender'] = 'M';
    } else if (g.isNotEmpty) {
      map['gender'] = g;
    }

    map['height'] = p.answer4.trim();
    map['currentWeight'] = p.answer5.trim();
    map['targetWeight'] = p.answer3.trim();
    map['dietPeriod'] = p.answer6.isEmpty ? null : p.answer6;
    map['mealsPerDay'] = p.answer7.isEmpty ? null : p.answer7;
    map['mealTimes'] = p.answer71;

    List<String> splitPipe(String raw) => raw
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    map['eatingHabits'] = splitPipe(p.answer8);
    map['foodPreference'] = splitPipe(p.answer9);

    parseAnswer10IntoFormData(
      p.answer10,
      answer10TypesRaw: p.answer102,
      setFrequency: (freq) => map['exerciseFrequency'] = freq,
      setTypes: (types) => map['exerciseTypes'] = types,
    );

    map['diseases'] = splitPipe(p.answer11);

    final meds = <String>[];
    final etcParts = <String>[];
    for (final part in splitPipe(p.answer12)) {
      if (part.startsWith('기타:')) {
        final name = part.substring(3).trim();
        if (name.isNotEmpty) etcParts.add(name);
        if (!meds.contains('기타')) meds.add('기타');
      } else {
        meds.add(part);
      }
    }
    map['medications'] = meds;
    map['medicationsEtc'] = etcParts.join(',');

    final a13 = p.answer13.trim();
    if (a13 == '1' || a13 == '없음') {
      map['dietExperience'] = '없음';
    } else if (a13 == '2' || a13 == '있음') {
      map['dietExperience'] = '있음';
    } else if (a13.isNotEmpty) {
      map['dietExperience'] = a13;
    }

    map['dietMedicine'] = p.answer13Medicine.trim();
    map['dietPeriodMonths'] = p.answer13Period.trim();
    map['dietDosage'] = p.answer13Dosage.trim();
    map['dietSideEffect'] = p.answer13Sideeffect.trim();

    return map;
  }
}
