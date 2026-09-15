import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../data/models/user/user_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/health_profile_service.dart';
import '../../../../data/services/shop_default_service.dart';
import '../models/health_profile_model.dart';
import 'health_profile_common.dart';
import 'health_profile_payload.dart';
import 'health_profile_prescription_booking_args.dart';
import 'health_profile_questionnaire_options.dart';

/// 문진표 1~4화면이 공유하는 작성 세션 (폼 값 · 로드/저장 · 예약 연동).
class HealthProfileFormSession extends ChangeNotifier {
  HealthProfileFormSession({
    this.existingProfile,
    this.prescriptionBooking,
  }) {
    exerciseOtherDraftFocus.addListener(_onExerciseOtherDraftFocusChange);
    medicationOtherDraftFocus.addListener(_onMedicationOtherDraftFocusChange);
  }

  void _onExerciseOtherDraftFocusChange() {
    if (exerciseOtherDraftFocus.hasFocus) return;
    commitExerciseOtherDraft();
  }

  void _onMedicationOtherDraftFocusChange() {
    if (medicationOtherDraftFocus.hasFocus) return;
    commitMedicationOtherDraft();
  }

  HealthProfileModel? existingProfile;
  final HealthProfilePrescriptionBookingArgs? prescriptionBooking;

  UserModel? currentUser;
  bool isLoading = false;
  bool _disposed = false;

  final Map<String, dynamic> formData = {};
  final Map<String, String> backupAnswer13Fields = {};
  int dietDetailResetTick = 0;
  int wizardBirthFieldKeySeed = 0;

  final List<String> exerciseOthers = [];
  bool exerciseOtherDraftOpen = false;
  final TextEditingController exerciseOtherDraftCtrl = TextEditingController();
  final FocusNode exerciseOtherDraftFocus = FocusNode();

  final List<String> medicationOthers = [];
  bool medicationOtherDraftOpen = false;
  final TextEditingController medicationOtherDraftCtrl =
      TextEditingController();
  final FocusNode medicationOtherDraftFocus = FocusNode();

  late final List<HealthProfileSection> sections = buildSections();

  static List<HealthProfileSection> buildSections() {
    return [
      HealthProfileSection(
        title: '기본정보',
        description: '',
        questions: [
          HealthProfileQuestion(
            id: 'wizard_basic',
            question: '기본정보',
            type: 'wizard_basic',
          ),
        ],
      ),
      HealthProfileSection(
        title: '식습관',
        description: '',
        questions: [
          HealthProfileQuestion(
            id: 'answer_7',
            question: '하루 식사 횟수',
            type: 'grid',
            options: HealthProfileQuestionnaireOptions.mealsPerDay,
            columns: 4,
          ),
          HealthProfileQuestion(
            id: 'answer_7_1',
            question: '식사시간',
            type: 'mealtime',
          ),
          HealthProfileQuestion(
            id: 'answer_8',
            question: '식습관',
            type: 'grid',
            options: HealthProfileQuestionnaireOptions.eatingHabits,
            columns: 2,
            allowMultiple: true,
          ),
          HealthProfileQuestion(
            id: 'answer_9',
            question: '자주 먹는 음식',
            type: 'grid',
            options: HealthProfileQuestionnaireOptions.foodPreference,
            columns: 2,
            allowMultiple: true,
          ),
        ],
      ),
      HealthProfileSection(
        title: '운동습관',
        description: '',
        questions: [
          HealthProfileQuestion(
            id: 'answer_10',
            question: '운동습관',
            type: 'grid',
            options: HealthProfileQuestionnaireOptions.exerciseFrequency,
            columns: 2,
          ),
          HealthProfileQuestion(
            id: 'answer_10_types',
            question: '주로 하는 운동',
            type: 'grid',
            options: HealthProfileQuestionnaireOptions.exerciseTypes,
            columns: 2,
            allowMultiple: true,
          ),
        ],
      ),
      HealthProfileSection(
        title: '건강 정보',
        description: '',
        questions: [
          HealthProfileQuestion(
            id: 'answer_11',
            question: '질병',
            type: 'grid',
            options: HealthProfileQuestionnaireOptions.diseases,
            columns: 2,
            allowMultiple: true,
          ),
          HealthProfileQuestion(
            id: 'answer_12',
            question: '복용중인 약',
            type: 'grid',
            options: HealthProfileQuestionnaireOptions.medications,
            columns: 2,
            allowMultiple: true,
          ),
          HealthProfileQuestion(
            id: 'answer_12_other',
            question: '기타 약 정보',
            type: 'text',
            hint: '복용중인 약 이름을 입력해주세요',
            isRequired: false,
          ),
          HealthProfileQuestion(
            id: 'answer_13',
            question: '다이어트약 복용 경험',
            type: 'radio',
            options: ['있음', '없음'],
          ),
        ],
      ),
    ];
  }

  Future<void> load() async {
    if (prescriptionBooking != null) {
      unawaited(ShopDefaultService.getReservationSettings());
    }
    final user = await AuthService.getUser();
    if (_disposed) return;
    currentUser = user;
    notifyListeners();

    if (existingProfile != null) {
      loadExistingData(existingProfile!);
      return;
    }
    if (user != null) {
      await _checkExistingProfile();
    }
  }

  Future<void> _checkExistingProfile() async {
    try {
      final profile =
          await HealthProfileService.getHealthProfile(currentUser!.id);
      if (_disposed) return;
      if (profile != null) {
        existingProfile = profile;
        loadExistingData(profile);
      } else {
        _prefillMemberBasicsFromUser(currentUser!);
      }
    } catch (_) {
      // 프로필 로드 실패 시 무시
    }
  }

  void _prefillMemberBasicsFromUser(UserModel user) {
    final hasBirth =
        (formData['answer_1']?.toString().trim().isNotEmpty == true) ||
            ((formData['birth_year']?.toString().length ?? 0) == 4 &&
                (formData['birth_month']?.toString().length ?? 0) == 2 &&
                (formData['birth_day']?.toString().length ?? 0) == 2);
    final g = formData['answer_2']?.toString().trim() ?? '';
    final hasGender = g == 'M' || g == 'F';

    var changed = false;
    var birthPrefilled = false;

    if (!hasBirth) {
      final raw = (user.birthDate ?? '').trim().replaceAll(RegExp(r'\D'), '');
      if (raw.length >= 8) {
        final ymd = raw.substring(0, 8);
        formData['answer_1'] = ymd;
        formData['birth_year'] = ymd.substring(0, 4);
        formData['birth_month'] = ymd.substring(4, 6);
        formData['birth_day'] = ymd.substring(6, 8);
        changed = true;
        birthPrefilled = true;
      }
    }

    if (!hasGender) {
      final rawSex = (user.sex ?? '').trim();
      if (rawSex.isNotEmpty) {
        final upper = rawSex.toUpperCase();
        if (upper == 'M' || rawSex == '남' || rawSex == '남성') {
          formData['answer_2'] = 'M';
          changed = true;
        } else if (upper == 'F' || rawSex == '여' || rawSex == '여성') {
          formData['answer_2'] = 'F';
          changed = true;
        } else if (rawSex == '1' || rawSex == '01') {
          formData['answer_2'] = 'M';
          changed = true;
        } else if (rawSex == '2' || rawSex == '02') {
          formData['answer_2'] = 'F';
          changed = true;
        }
      }
    }

    if (changed) {
      if (birthPrefilled) wizardBirthFieldKeySeed++;
      notifyListeners();
    }
  }

  void loadExistingData(HealthProfileModel profile) {
    if (profile.answer1.isNotEmpty && profile.answer1.length >= 8) {
      formData['birth_year'] = profile.answer1.substring(0, 4);
      formData['birth_month'] = profile.answer1.substring(4, 6);
      formData['birth_day'] = profile.answer1.substring(6, 8);
    }
    formData['answer_1'] = profile.answer1;

    final rawGender = profile.answer2.trim();
    final upper = rawGender.toUpperCase();
    if (upper == 'M' || rawGender == '남성' || rawGender == '남') {
      formData['answer_2'] = 'M';
    } else if (upper == 'F' || rawGender == '여성' || rawGender == '여') {
      formData['answer_2'] = 'F';
    } else {
      formData['answer_2'] = rawGender;
    }

    final rawGoalOrLoss = profile.answer3.trim();
    final a3 = double.tryParse(rawGoalOrLoss.replaceAll(',', ''));
    final w = double.tryParse(profile.answer5.trim().replaceAll(',', ''));
    if (a3 != null && w != null && a3 > 0 && a3 < 30) {
      final goal = w - a3;
      formData['answer_3'] = goal == goal.roundToDouble()
          ? goal.toStringAsFixed(0)
          : goal.toStringAsFixed(1);
    } else {
      formData['answer_3'] = profile.answer3;
    }
    formData['answer_4'] = profile.answer4;
    formData['answer_5'] = profile.answer5;
    formData['answer_6'] =
        HealthProfileFormCommon.normalizeDietPeriodOption(profile.answer6);
    formData['answer_7'] =
        HealthProfileFormCommon.normalizeMealsPerDay(profile.answer7);

    if (profile.answer71.isNotEmpty) {
      final parts = profile.answer71.split('|');
      formData['meal_1'] = parts.isNotEmpty ? parts[0] : '';
      formData['meal_2'] = parts.length > 1 ? parts[1] : '';
      formData['meal_3'] = parts.length > 2 ? parts[2] : '';
      formData['meal_other'] = parts.length > 3 ? parts[3] : '';
    }
    formData['answer_7_1'] = profile.answer71;

    if (profile.answer8.isNotEmpty) {
      formData['answer_8'] = profile.answer8
          .split('|')
          .map(HealthProfileFormCommon.normalizeChipOptionLabel)
          .where((e) => e.isNotEmpty)
          .toList();
    } else {
      formData['answer_8'] = [];
    }

    if (profile.answer9.isNotEmpty) {
      formData['answer_9'] = profile.answer9
          .split('|')
          .map(HealthProfileFormCommon.normalizeChipOptionLabel)
          .where((e) => e.isNotEmpty)
          .toList();
    } else {
      formData['answer_9'] = [];
    }

    HealthProfilePayload.parseAnswer10IntoFormData(
      profile.answer10,
      answer10TypesRaw: profile.answer102,
      setFrequency: (f) => formData['answer_10'] = f,
      setTypes: applyLoadedExerciseTypes,
    );

    bool rawMeansNoHealth(String raw) {
      final t = raw.trim();
      if (t.isEmpty) return true;
      const noneTokens = {'없음', '해당없음', '해당 없음'};
      if (noneTokens.contains(t)) return true;
      final parts =
          t.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      return parts.isNotEmpty && parts.every(noneTokens.contains);
    }

    List<String> normalizeDiseaseMedicationParts(Iterable<String> parts) {
      return parts.map((e) => e.trim()).where((e) => e.isNotEmpty).map((e) {
        if (e == '없음' || e == '해당없음') return '해당 없음';
        if (e == '심혈관') return '심혈증';
        if (e.contains('내분비') &&
            (e.contains('신장') || e.contains('대사') || e.contains('영양'))) {
          return '내분비, 영양, 대사질환';
        }
        return e;
      }).toList();
    }

    if (rawMeansNoHealth(profile.answer11)) {
      formData['answer_11'] = <String>['해당없음'];
    } else if (profile.answer11.isNotEmpty) {
      formData['answer_11'] = normalizeDiseaseMedicationParts(
        profile.answer11.split('|'),
      ).map((e) => e == '해당 없음' ? '해당없음' : e).toList();
    } else {
      formData['answer_11'] = <String>['해당없음'];
    }

    if (profile.answer12.isNotEmpty) {
      if (profile.answer12.contains('|') || profile.answer12.contains('기타:')) {
        final parts = profile.answer12.contains('|')
            ? profile.answer12.split('|')
            : [profile.answer12];
        final answer12List = <String>[];
        final otherValues = <String>[];

        for (final part in parts) {
          final trimmed = part.trim();
          if (trimmed.startsWith('기타:')) {
            final rawOther = trimmed.substring(3).trim();
            for (final o in rawOther.split(RegExp(r'[,|]'))) {
              final t = o.trim();
              if (t.isNotEmpty && !otherValues.contains(t)) otherValues.add(t);
            }
            if (!answer12List.contains('기타')) answer12List.add('기타');
          } else if (trimmed.isNotEmpty) {
            answer12List.add(trimmed);
          }
        }

        final normalized = normalizeDiseaseMedicationParts(answer12List);
        if (normalized.isEmpty ||
            (normalized.length == 1 && normalized.first == '해당 없음')) {
          formData['answer_12'] = <String>['해당 없음'];
          formData.remove('answer_12_other');
          medicationOthers.clear();
          medicationOtherDraftOpen = false;
        } else {
          formData['answer_12'] = normalized;
          medicationOthers
            ..clear()
            ..addAll(otherValues);
          medicationOtherDraftOpen =
              normalized.contains('기타') && otherValues.isEmpty;
          formData['answer_12_other'] = otherValues.join(', ');
        }
      } else {
        if (profile.answer12 == '기타') {
          formData['answer_12'] = ['기타'];
          medicationOthers.clear();
          medicationOtherDraftOpen = true;
        } else if (rawMeansNoHealth(profile.answer12)) {
          formData['answer_12'] = <String>['해당 없음'];
        } else {
          final v = profile.answer12 == '없음' ? '해당 없음' : profile.answer12;
          formData['answer_12'] = [v];
        }
      }
    } else {
      formData['answer_12'] = <String>['해당 없음'];
    }

    if (profile.answer13 == '1') {
      formData['answer_13'] = '없음';
    } else if (profile.answer13 == '2') {
      formData['answer_13'] = '있음';
    } else {
      formData['answer_13'] = profile.answer13;
    }

    formData['answer_13_medicine'] = profile.answer13Medicine;
    formData['answer_13_period'] = profile.answer13Period;
    formData['answer_13_dosage'] = profile.answer13Dosage;
    formData['answer_13_sideeffect'] = profile.answer13Sideeffect;

    backupAnswer13Fields['answer_13_medicine'] = profile.answer13Medicine;
    backupAnswer13Fields['answer_13_period'] = profile.answer13Period;
    backupAnswer13Fields['answer_13_dosage'] = profile.answer13Dosage;
    backupAnswer13Fields['answer_13_sideeffect'] = profile.answer13Sideeffect;

    wizardBirthFieldKeySeed++;
    notifyListeners();
  }

  String birthYyyymmddDisplay() {
    final a1 = (formData['answer_1']?.toString().trim() ?? '');
    if (a1.length == 8 && RegExp(r'^\d{8}$').hasMatch(a1)) return a1;
    final y = (formData['birth_year']?.toString().trim() ?? '');
    final m = (formData['birth_month']?.toString().trim() ?? '');
    final d = (formData['birth_day']?.toString().trim() ?? '');
    if (y.length != 4 || m.isEmpty || d.isEmpty) return '';
    final mm = m.padLeft(2, '0');
    final dd = d.padLeft(2, '0');
    if (mm.length != 2 || dd.length != 2) return '';
    return '$y$mm$dd';
  }

  void applyLoadedExerciseTypes(List<String> loaded) {
    final known = HealthProfileQuestionnaireOptions.exerciseTypes.toSet();
    final selected = <String>[];
    final others = <String>[];
    for (final raw in loaded) {
      final t = raw.trim();
      if (t.isEmpty) continue;
      if (t == '기타') {
        if (!selected.contains('기타')) selected.add('기타');
        continue;
      }
      if (known.contains(t)) {
        if (!selected.contains(t)) selected.add(t);
      } else {
        if (!others.contains(t)) others.add(t);
      }
    }
    if (others.isNotEmpty && !selected.contains('기타')) {
      selected.add('기타');
    }
    formData['answer_10_types'] = selected;
    exerciseOthers
      ..clear()
      ..addAll(others);
    exerciseOtherDraftOpen = selected.contains('기타') && others.isEmpty;
    exerciseOtherDraftCtrl.clear();
  }

  bool isExerciseOtherSelected() {
    final raw = formData['answer_10_types'];
    if (raw is List) return raw.map((e) => e.toString()).contains('기타');
    return raw?.toString() == '기타';
  }

  void clearExerciseOthers() {
    exerciseOthers.clear();
    exerciseOtherDraftOpen = false;
    exerciseOtherDraftCtrl.clear();
  }

  void commitExerciseOtherDraft() {
    final text = exerciseOtherDraftCtrl.text.trim();
    if (text.isEmpty) return;
    if (exerciseOthers.contains(text)) {
      exerciseOtherDraftCtrl.clear();
      exerciseOtherDraftOpen = false;
      notifyListeners();
      return;
    }
    exerciseOthers.add(text);
    exerciseOtherDraftCtrl.clear();
    exerciseOtherDraftOpen = false;
    notifyListeners();
  }

  void removeExerciseOtherAt(int index) {
    if (index < 0 || index >= exerciseOthers.length) return;
    exerciseOthers.removeAt(index);
    if (exerciseOthers.isEmpty && isExerciseOtherSelected()) {
      exerciseOtherDraftOpen = true;
    }
    notifyListeners();
  }

  void openExerciseOtherDraft() {
    final text = exerciseOtherDraftCtrl.text.trim();
    if (text.isNotEmpty && !exerciseOthers.contains(text)) {
      exerciseOthers.add(text);
      exerciseOtherDraftCtrl.clear();
    }
    exerciseOtherDraftOpen = true;
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) exerciseOtherDraftFocus.requestFocus();
    });
  }

  void syncMedicationOtherFormData() {
    formData['answer_12_other'] = [
      ...medicationOthers,
      if (medicationOtherDraftCtrl.text.trim().isNotEmpty)
        medicationOtherDraftCtrl.text.trim(),
    ].join(', ');
  }

  void clearMedicationOthers() {
    medicationOthers.clear();
    medicationOtherDraftOpen = false;
    medicationOtherDraftCtrl.clear();
    formData['answer_12_other'] = '';
  }

  void commitMedicationOtherDraft() {
    final text = medicationOtherDraftCtrl.text.trim();
    if (text.isEmpty) return;
    if (medicationOthers.contains(text)) {
      medicationOtherDraftCtrl.clear();
      medicationOtherDraftOpen = false;
      syncMedicationOtherFormData();
      notifyListeners();
      return;
    }
    medicationOthers.add(text);
    medicationOtherDraftCtrl.clear();
    medicationOtherDraftOpen = false;
    syncMedicationOtherFormData();
    notifyListeners();
  }

  void removeMedicationOtherAt(int index) {
    if (index < 0 || index >= medicationOthers.length) return;
    medicationOthers.removeAt(index);
    if (medicationOthers.isEmpty && isMedicationOtherSelected()) {
      medicationOtherDraftOpen = true;
    }
    syncMedicationOtherFormData();
    notifyListeners();
  }

  bool isMedicationOtherSelected() {
    final raw = formData['answer_12'];
    if (raw is List) return raw.map((e) => e.toString()).contains('기타');
    return raw?.toString() == '기타';
  }

  void openMedicationOtherDraft() {
    final text = medicationOtherDraftCtrl.text.trim();
    if (text.isNotEmpty && !medicationOthers.contains(text)) {
      medicationOthers.add(text);
      medicationOtherDraftCtrl.clear();
    }
    medicationOtherDraftOpen = true;
    syncMedicationOtherFormData();
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) medicationOtherDraftFocus.requestFocus();
    });
  }

  bool isGoalWeightTooHigh() {
    final current = double.tryParse(
      (formData['answer_5']?.toString() ?? '').replaceAll(',', ''),
    );
    final goal = double.tryParse(
      (formData['answer_3']?.toString() ?? '').replaceAll(',', ''),
    );
    if (current == null || goal == null) return false;
    return goal >= current;
  }

  bool shouldShowQuestion(HealthProfileQuestion question) {
    if (question.id.startsWith('answer_13') && question.id != 'answer_13') {
      final answer13 = formData['answer_13'];
      return answer13 == '있음' || answer13 == '2';
    }
    if (question.id == 'answer_12_other') {
      final answer12 = formData['answer_12'];
      if (answer12 is List) {
        return answer12.contains('기타');
      }
      return answer12 == '기타';
    }
    return true;
  }

  void toggleGridOption(HealthProfileQuestion question, String opt) {
    final isMulti = question.allowMultiple;
    List<String> selected = [];
    final raw = formData[question.id];
    if (isMulti) {
      selected =
          raw is List ? List<String>.from(raw.map((e) => e.toString())) : [];
    } else {
      if (raw != null) selected = [raw.toString()];
    }
    if (isMulti &&
        (question.id == 'answer_8' ||
            question.id == 'answer_9' ||
            question.id == 'answer_11' ||
            question.id == 'answer_12')) {
      selected = selected
          .map((e) => HealthProfileFormCommon.canonicalHealthNoneGridOption(
              question.id, e))
          .toList();
    }

    final optC =
        HealthProfileFormCommon.canonicalHealthNoneGridOption(question.id, opt);
    if (question.id == 'answer_8') {
      if (optC == '해당없음') {
        formData[question.id] = isMulti ? <String>['해당없음'] : '해당없음';
        notifyListeners();
        return;
      }
      if (isMulti) {
        final list = selected
            .map((e) => HealthProfileFormCommon.canonicalHealthNoneGridOption(
                question.id, e))
            .toList();
        list.remove('해당없음');
        list.remove('해당 없음');
        if (list.contains(optC)) {
          list.remove(optC);
        } else {
          list.add(optC);
        }
        formData[question.id] = list;
        notifyListeners();
        return;
      }
    }
    if (question.id == 'answer_11' || question.id == 'answer_12') {
      final noneLabel = question.id == 'answer_11' ? '해당없음' : '해당 없음';
      if (optC == noneLabel || optC == '해당 없음' || optC == '해당없음') {
        formData[question.id] = isMulti ? <String>[noneLabel] : noneLabel;
        if (question.id == 'answer_12') {
          clearMedicationOthers();
        }
        notifyListeners();
        return;
      }
      if (isMulti) {
        final list = selected
            .map((e) => HealthProfileFormCommon.canonicalHealthNoneGridOption(
                question.id, e))
            .toList();
        list.remove('해당 없음');
        list.remove('해당없음');
        if (list.contains(optC)) {
          list.remove(optC);
          if (question.id == 'answer_12' && optC == '기타') {
            clearMedicationOthers();
          }
        } else {
          list.add(optC);
          if (question.id == 'answer_12' && optC == '기타') {
            medicationOtherDraftOpen = medicationOthers.isEmpty;
            if (medicationOtherDraftOpen) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_disposed) medicationOtherDraftFocus.requestFocus();
              });
            }
          }
        }
        formData[question.id] = list;
        notifyListeners();
        return;
      }
    }
    if (question.id == 'answer_10_types' && isMulti) {
      final list = List<String>.from(selected);
      if (list.contains(opt)) {
        list.remove(opt);
        if (opt == '기타') clearExerciseOthers();
      } else {
        list.add(opt);
        if (opt == '기타') {
          exerciseOtherDraftOpen = exerciseOthers.isEmpty;
          if (exerciseOtherDraftOpen) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_disposed) exerciseOtherDraftFocus.requestFocus();
            });
          }
        }
      }
      formData[question.id] = list;
      notifyListeners();
      return;
    }
    if (isMulti) {
      final list = List<String>.from(selected);
      if (list.contains(opt)) {
        list.remove(opt);
      } else {
        list.add(opt);
      }
      formData[question.id] = list;
    } else {
      formData[question.id] = opt;
      if (question.id == 'answer_7') {
        HealthProfileFormCommon.resetMealTimes(formData);
      }
    }
    notifyListeners();
  }

  bool isGridOptionSelected(HealthProfileQuestion question, String label) {
    final isMulti = question.allowMultiple;
    List<String> selected = [];
    final raw = formData[question.id];
    if (isMulti) {
      selected =
          raw is List ? List<String>.from(raw.map((e) => e.toString())) : [];
    } else {
      if (raw != null) selected = [raw.toString()];
    }
    final c = HealthProfileFormCommon.canonicalHealthNoneGridOption(
        question.id, label);
    if (isMulti) {
      return selected
          .map((e) => HealthProfileFormCommon.canonicalHealthNoneGridOption(
              question.id, e))
          .contains(c);
    }
    return selected.isNotEmpty &&
        HealthProfileFormCommon.canonicalHealthNoneGridOption(
                question.id, selected.first) ==
            c;
  }

  bool _nonEmptyString(dynamic v) => (v?.toString().trim().isNotEmpty ?? false);

  bool _nonEmptyList(dynamic v) =>
      v is List && v.map((e) => e.toString().trim()).any((e) => e.isNotEmpty);

  bool _isYmdValid(int y, int m, int d) {
    try {
      final dt = DateTime(y, m, d);
      return !dt.isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  bool isBirthValid() {
    final a1 = (formData['answer_1']?.toString().trim() ?? '');
    if (a1.length == 8) {
      final y = int.tryParse(a1.substring(0, 4));
      final m = int.tryParse(a1.substring(4, 6));
      final d = int.tryParse(a1.substring(6, 8));
      if (y == null || m == null || d == null) return false;
      return _isYmdValid(y, m, d);
    }

    final ys = formData['birth_year']?.toString().trim() ?? '';
    final ms = formData['birth_month']?.toString().trim() ?? '';
    final ds = formData['birth_day']?.toString().trim() ?? '';
    if (ys.length != 4 || ms.length != 2 || ds.length != 2) return false;
    final y = int.tryParse(ys);
    final m = int.tryParse(ms);
    final d = int.tryParse(ds);
    if (y == null || m == null || d == null) return false;
    return _isYmdValid(y, m, d);
  }

  bool isWizardStepFilled(int stepIndex) {
    if (stepIndex < 0 || stepIndex >= sections.length) return false;
    final section = sections[stepIndex];

    if (stepIndex == 0) {
      if (!_nonEmptyString(formData['answer_1']) &&
          !(((formData['birth_year']?.toString().length ?? 0) == 4) &&
              ((formData['birth_month']?.toString().length ?? 0) == 2) &&
              ((formData['birth_day']?.toString().length ?? 0) == 2))) {
        return false;
      }
      if (!isBirthValid()) return false;

      final g = formData['answer_2']?.toString().trim() ?? '';
      if (g != 'M' && g != 'F') return false;

      if (!_nonEmptyString(formData['answer_4'])) return false;
      if (!_nonEmptyString(formData['answer_5'])) return false;
      if (!_nonEmptyString(formData['answer_3'])) return false;
      if (isGoalWeightTooHigh()) return false;
      if (!_nonEmptyString(formData['answer_6'])) return false;
      return true;
    }

    for (final q in section.questions) {
      if (!shouldShowQuestion(q)) continue;
      if (q.type == 'mealtime') continue;

      switch (q.type) {
        case 'grid':
          final raw = formData[q.id];
          if (q.allowMultiple == true) {
            if (!_nonEmptyList(raw)) return false;
          } else {
            if (!_nonEmptyString(raw)) return false;
          }
          if (q.id == 'answer_10') {
            if (!_nonEmptyList(formData['answer_10_types'])) return false;
            if (isExerciseOtherSelected()) {
              final hasCommitted =
                  exerciseOthers.any((e) => e.trim().isNotEmpty);
              final hasDraft = exerciseOtherDraftCtrl.text.trim().isNotEmpty;
              if (!hasCommitted && !hasDraft) return false;
            }
          }
          if (q.id == 'answer_12' && isMedicationOtherSelected()) {
            final hasCommitted =
                medicationOthers.any((e) => e.trim().isNotEmpty);
            final hasDraft = medicationOtherDraftCtrl.text.trim().isNotEmpty;
            if (!hasCommitted && !hasDraft) return false;
          }
          break;
        case 'radio':
          if (!_nonEmptyString(formData[q.id])) return false;
          break;
        case 'text':
          if (q.isRequired && !_nonEmptyString(formData[q.id])) return false;
          break;
        default:
          break;
      }
    }

    final a13 = formData['answer_13']?.toString().trim() ?? '';
    if (stepIndex == 3 && (a13 == '있음' || a13 == '2')) {
      if (!_nonEmptyString(formData['answer_13_medicine'])) return false;
      if (!_nonEmptyString(formData['answer_13_period'])) return false;
      if (!_nonEmptyString(formData['answer_13_dosage'])) return false;
      if (!_nonEmptyString(formData['answer_13_sideeffect'])) return false;
    }

    return true;
  }

  bool isAllWizardStepsFilled() {
    for (var i = 0; i < sections.length; i++) {
      if (!isWizardStepFilled(i)) return false;
    }
    return true;
  }

  String composeAnswer10Frequency() {
    return HealthProfilePayload.composeAnswer10FrequencyOnly(
      (formData['answer_10'] ?? '').toString(),
    );
  }

  String composeAnswer10Types() {
    final raw = formData['answer_10_types'];
    final list = <String>[];
    if (raw is List) {
      for (final e in raw) {
        final s = e.toString().trim();
        if (s.isEmpty || s == '기타') continue;
        list.add(s);
      }
    }
    for (final o in exerciseOthers) {
      final t = o.trim();
      if (t.isNotEmpty && !list.contains(t)) list.add(t);
    }
    final draft = exerciseOtherDraftCtrl.text.trim();
    if (draft.isNotEmpty && !list.contains(draft)) list.add(draft);
    return list.join('|');
  }

  Future<void> saveHealthProfile() async {
    final birthYear = formData['birth_year'] ?? '';
    final birthMonth = formData['birth_month'] ?? '';
    final birthDay = formData['birth_day'] ?? '';
    final birthDate =
        birthYear.length == 4 && birthMonth.length == 2 && birthDay.length == 2
            ? '$birthYear$birthMonth$birthDay'
            : formData['answer_1'] ?? '';

    final meal1 = formData['meal_1'] ?? '';
    final meal2 = formData['meal_2'] ?? '';
    final meal3 = formData['meal_3'] ?? '';
    final mealOther = formData['meal_other'] ?? '';
    final mealtime = '$meal1|$meal2|$meal3|$mealOther';

    final profile = HealthProfileModel(
      pfNo: existingProfile?.pfNo,
      mbId: currentUser!.id,
      answer1: birthDate,
      answer2: formData['answer_2'] ?? '',
      answer3: formData['answer_3'] ?? '',
      answer4: formData['answer_4'] ?? '',
      answer5: formData['answer_5'] ?? '',
      answer6: formData['answer_6'] ?? '',
      answer7: formData['answer_7'] ?? '',
      answer8: HealthProfilePayload.formatListToString(formData['answer_8']),
      answer9: HealthProfilePayload.formatListToString(formData['answer_9']),
      answer10: composeAnswer10Frequency(),
      answer102: composeAnswer10Types(),
      answer11: HealthProfilePayload.formatListToString(formData['answer_11']),
      answer12: HealthProfilePayload.formatAnswer12(
        formData['answer_12'],
        null,
        otherValues: [
          ...medicationOthers,
          if (medicationOtherDraftCtrl.text.trim().isNotEmpty)
            medicationOtherDraftCtrl.text.trim(),
        ],
      ),
      answer13: HealthProfilePayload.encodeAnswer13ForApi(
        formData['answer_13']?.toString(),
      ),
      answer13Period: formData['answer_13_period'] ?? '',
      answer13Dosage: formData['answer_13_dosage'] ?? '',
      answer13Medicine: formData['answer_13_medicine'] ?? '',
      answer71: mealtime,
      answer13Sideeffect: formData['answer_13_sideeffect'] ?? '',
      pfWdatetime: existingProfile?.pfWdatetime ?? DateTime.now(),
      pfMdatetime: DateTime.now(),
      pfIp: '',
      pfMemo: '',
    );

    if (existingProfile != null && existingProfile!.pfNo != null) {
      await HealthProfileService.updateHealthProfile(profile);
    } else {
      await HealthProfileService.saveHealthProfile(profile);
    }
  }

  void touch() => notifyListeners();

  @override
  void dispose() {
    _disposed = true;
    exerciseOtherDraftFocus.removeListener(_onExerciseOtherDraftFocusChange);
    medicationOtherDraftFocus
        .removeListener(_onMedicationOtherDraftFocusChange);
    exerciseOtherDraftFocus.dispose();
    exerciseOtherDraftCtrl.dispose();
    medicationOtherDraftFocus.dispose();
    medicationOtherDraftCtrl.dispose();
    super.dispose();
  }
}
