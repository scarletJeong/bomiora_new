import 'package:flutter/material.dart';

import '../../../health/health_common/health_responsive_scale.dart';
import 'health_profile_questionnaire_options.dart';

/// 문진표 작성 1~4페이지 공통 상수·헬퍼.
abstract final class HealthProfileFormCommon {
  HealthProfileFormCommon._();

  static const Color pink = Color(0xFFFF3787);
  static const Color pinkSoft = Color(0x0CFF3787);
  static const Color border = Color(0x7FD2D2D2);
  static const Color ink = Color(0xFF1A1A1E);
  static const Color muted = Color(0xFF898686);
  static const Color hint = Color(0xFF898383);
  static const Color fieldFill = Color(0xFFF8FAFC);
  static const String font = 'Gmarket Sans TTF';

  static const List<String> stepLabels = [
    '기본 정보',
    '식습관',
    '운동습관',
    '건강 정보',
  ];

  static const String formRouteName = 'health_profile_form';
  static const List<String> formPageRouteNames = [
    'health_profile_form1',
    'health_profile_form2',
    'health_profile_form3',
    'health_profile_form4',
  ];

  static bool isFormRouteName(String? name) =>
      name == formRouteName || formPageRouteNames.contains(name);

  static int startPageIndex({
    List<int>? initialSectionIndices,
    int? initialWizardIndex,
  }) {
    if (initialSectionIndices != null && initialSectionIndices.isNotEmpty) {
      return initialSectionIndices.first.clamp(0, 3);
    }
    return (initialWizardIndex ?? 0).clamp(0, 3);
  }

  static const List<String> mealTimeKeys = [
    'meal_1',
    'meal_2',
    'meal_3',
    'meal_other',
  ];

  static const List<String> mealTimeLabels = [
    '아침',
    '점심',
    '저녁',
    '기타',
  ];

  static double labeledControlHeight(BuildContext context) =>
      healthDp(context, 45);

  static TextStyle fieldTextStyle(BuildContext context) => TextStyle(
        color: const Color(0xFF1A1A1A),
        fontSize: healthSp(context, 14),
        fontFamily: font,
        fontWeight: FontWeight.w500,
        height: 1.2,
      );

  static TextStyle multiHintStyle(BuildContext context) => TextStyle(
        color: hint,
        fontSize: healthSp(context, 12),
        fontFamily: font,
        fontWeight: FontWeight.w300,
      );

  static bool isRealMealTime(dynamic raw) {
    final t = (raw?.toString() ?? '').trim();
    if (t.isEmpty || t == '-') return false;
    return true;
  }

  /// `1회`→1, `2회`→2, `3회`→3, `3회 이상`→4
  static int expectedMealSlotCount(String? mealsPerDay) {
    switch ((mealsPerDay ?? '').trim()) {
      case '1회':
      case '하루 1식':
        return 1;
      case '2회':
      case '하루 2식':
        return 2;
      case '3회':
      case '하루 3식':
        return 3;
      case '3회 이상':
      case '하루 3식 이상':
      case '하루 4식':
        return 4;
      default:
        return 0;
    }
  }

  static String normalizeMealsPerDay(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    const legacy = {
      '하루 1식': '1회',
      '하루 2식': '2회',
      '하루 3식': '3회',
      '하루 3식 이상': '3회 이상',
      '하루 4식': '3회 이상',
    };
    if (legacy.containsKey(t)) return legacy[t]!;
    if (HealthProfileQuestionnaireOptions.mealsPerDay.contains(t)) return t;
    return t;
  }

  /// 칩 라벨 공백/개행·오타(다이터트) 정규화
  static String normalizeChipOptionLabel(String raw) {
    var s = raw.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.contains('샐러드') && (s.contains('다이어트') || s.contains('다이터트'))) {
      return '샐러드/다이어트식단';
    }
    return s;
  }

  /// API/DB 값이 선택지와 약간 다를 때(공백·개행 등) 목표 기간 드롭다운과 맞춤
  static String normalizeDietPeriodOption(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    const options = HealthProfileQuestionnaireOptions.dietPeriod;
    for (final o in options) {
      if (o == t) return o;
    }
    for (final o in options) {
      if (o.replaceAll(RegExp(r'\s'), '') == t.replaceAll(RegExp(r'\s'), '')) {
        return o;
      }
    }
    return t;
  }

  static String canonicalHealthNoneGridOption(String questionId, String opt) {
    if (questionId != 'answer_8' &&
        questionId != 'answer_9' &&
        questionId != 'answer_11' &&
        questionId != 'answer_12') {
      return opt;
    }
    final o = (questionId == 'answer_8' || questionId == 'answer_9')
        ? normalizeChipOptionLabel(opt)
        : opt.trim();
    if (o == '해당없음' || o == '없음' || o == '해당 없음') {
      if (questionId == 'answer_8' || questionId == 'answer_11') {
        return '해당없음';
      }
      return '해당 없음';
    }
    return o;
  }

  /// 하루 식사 횟수 칩을 누르면 식사시간을 모두 `-`로 리셋.
  static void resetMealTimes(Map<String, dynamic> formData) {
    for (final key in mealTimeKeys) {
      formData[key] = '-';
    }
  }

  /// 선택한 횟수만큼 시간이 채워지면 나머지는 `-`.
  /// [justSetKey]를 우선 유지하고, 횟수를 넘긴 칸은 `-`로 돌린다.
  static void applyUnusedMealDash(
    Map<String, dynamic> formData, {
    String? justSetKey,
  }) {
    final expected = expectedMealSlotCount(formData['answer_7']?.toString());
    if (expected <= 0) return;

    final filled =
        mealTimeKeys.where((key) => isRealMealTime(formData[key])).toList();
    if (filled.length > expected) {
      var kept = 0;
      for (final key in mealTimeKeys) {
        if (!isRealMealTime(formData[key])) continue;
        if (key == justSetKey) continue;
        if (kept <
            expected -
                (justSetKey != null && isRealMealTime(formData[justSetKey])
                    ? 1
                    : 0)) {
          kept++;
        } else {
          formData[key] = '-';
        }
      }
    }

    final nowFilled =
        mealTimeKeys.where((key) => isRealMealTime(formData[key])).length;
    if (nowFilled >= expected) {
      for (final key in mealTimeKeys) {
        if (!isRealMealTime(formData[key])) {
          formData[key] = '-';
        }
      }
    }
  }
}
