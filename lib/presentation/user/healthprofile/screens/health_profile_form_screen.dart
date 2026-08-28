import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../health_profile_questionnaire_options.dart';
import '../health_profile_payload.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/health_profile_service.dart';
import '../../../../data/services/shop_default_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../models/health_profile_model.dart';
import '../health_profile_prescription_booking_args.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_toast_overlay.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../../../shopping/screens/prescription_booking/prescription_time_screen.dart';
import '../../../shopping/widgets/prescription_booking_progress_bar.dart';

class HealthProfileFormScreen extends StatefulWidget {
  /// [HealthProfileListScreen] 등에서 push 시 `RouteSettings.name`으로 넣어야 함.
  /// 뒤로가기 한 번에 연속으로 쌓인 문진표 라우트를 모두 닫을 때 사용.
  static const String routeName = 'health_profile_form';

  final HealthProfileModel? existingProfile;

  /// 목록 등에서 특정 섹션만 수정할 때. 길이 1이면 해당 섹션만, 2 이상이면 해당 섹션들만 PageView(스와이프) + 하단 `수정하기`만 표시.
  final List<int>? initialSectionIndices;

  /// 앱바 제목용 (예: 카드 제목이 `건강 정보`와 다를 때 별도 제목). null이면 해당 섹션의 `title` 사용.
  final String? editScreenTitle;

  /// 전체 문진표 모드에서 처음 열 페이지 (0~3). `initialSectionIndices`가 있으면 무시됩니다.
  final int? initialWizardIndex;

  /// 처방 예약 플로우: 4장 작성 진행률 표시 + 완료 시 날짜/시간 선택으로 이동
  final HealthProfilePrescriptionBookingArgs? prescriptionBooking;

  const HealthProfileFormScreen({
    super.key,
    this.existingProfile,
    this.initialSectionIndices,
    this.editScreenTitle,
    this.initialWizardIndex,
    this.prescriptionBooking,
  });

  @override
  State<HealthProfileFormScreen> createState() =>
      _HealthProfileFormScreenState();
}

class _Answer6MenuLine extends StatelessWidget {
  const _Answer6MenuLine({
    required this.label,
    required this.showBottomDivider,
    required this.onTap,
  });

  final String label;
  final bool showBottomDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(healthDp(context, 4)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: healthDp(context, 10)),
        decoration: BoxDecoration(
          border: showBottomDivider
              ? Border(
                  bottom: BorderSide(
                    width: healthDp(context, 0.3),
                    color: const Color(0x7FD2D2D2),
                  ),
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: healthSp(context, 16),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthProfileFormScreenState extends State<HealthProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final PageController _pageController;

  UserModel? _currentUser;
  HealthProfileModel? _existingProfile; // 기존 건강프로필 정보 저장
  int _currentPage = 0;
  bool _isLoading = false;

  // 폼 데이터
  final Map<String, dynamic> _formData = {};

  // 다이어트 경험 관련 필드 백업 (있음 → 없음 → 있음 선택 시 복원용)
  final Map<String, String> _backupAnswer13Fields = {};
  int _dietDetailResetTick = 0;
  final GlobalKey _answer6FieldKey = GlobalKey();
  OverlayEntry? _answer6MenuOverlay;
  ScrollController? _answer6MenuScrollController;

  /// BMI 안내 팝업 (현재 체중 라벨 아이콘)
  final GlobalKey _bmiGuideIconKey = GlobalKey();
  OverlayEntry? _bmiGuideOverlay;

  /// 목표 체중 ≥ 현재 체중일 때 핑크 테두리 + 일시 안내 문구
  bool _goalWeightInvalid = false;
  bool _goalWeightHintVisible = false;
  Timer? _goalWeightHintTimer;

  /// 주로 하는 운동 > 기타 커스텀 종목
  final List<String> _exerciseOthers = [];
  bool _exerciseOtherDraftOpen = false;
  final TextEditingController _exerciseOtherDraftCtrl = TextEditingController();
  final FocusNode _exerciseOtherDraftFocus = FocusNode();

  /// 복용중인 약 > 기타 약명
  final List<String> _medicationOthers = [];
  bool _medicationOtherDraftOpen = false;
  final TextEditingController _medicationOtherDraftCtrl =
      TextEditingController();
  final FocusNode _medicationOtherDraftFocus = FocusNode();

  /// 생년월일 `TextFormField` 재마운트용(프리필/기존 데이터 로드 시만 증가). 입력마다 바꾸면 포커스가 끊김.
  int _wizardBirthFieldKeySeed = 0;

  // 건강 프로필 섹션들
  late List<HealthProfileSection> _sections;

  static const Color _pfPink = Color(0xFFFF3787);
  static const Color _pfPinkSoft = Color(0x0CFF3787);
  static const Color _pfBorder = Color(0x7FD2D2D2);
  static const int _answer6MenuMaxVisibleRows = 4;
  static const List<String> _stepLabels = [
    '기본 정보',
    '식습관',
    '운동습관',
    '건강 정보',
  ];

  static const List<String> _wizardStepIconAssets = [
    AppAssets.profile1,
    AppAssets.profile2,
    AppAssets.profile3,
    AppAssets.profile4,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.prescriptionBooking != null) {
      unawaited(ShopDefaultService.getReservationSettings());
    }
    if (widget.initialSectionIndices != null &&
        widget.initialSectionIndices!.isNotEmpty) {
      final subs = widget.initialSectionIndices!;
      final mergeDietExercise =
          subs.length == 2 && subs[0] == 1 && subs[1] == 2;
      if (mergeDietExercise) {
        _currentPage = 1;
        _pageController = PageController();
      } else {
        _currentPage = subs.first;
        _pageController = subs.length == 1
            ? PageController()
            : PageController(initialPage: 0);
      }
    } else {
      final initialPage = widget.initialWizardIndex?.clamp(0, 4) ?? 0;
      _pageController = PageController(initialPage: initialPage);
      _currentPage = initialPage;
    }

    _loadUser();
    _initializeSections();
    _exerciseOtherDraftFocus.addListener(_onExerciseOtherDraftFocusChange);
    _medicationOtherDraftFocus.addListener(_onMedicationOtherDraftFocusChange);
  }

  void _onExerciseOtherDraftFocusChange() {
    if (_exerciseOtherDraftFocus.hasFocus) return;
    _commitExerciseOtherDraft();
  }

  void _onMedicationOtherDraftFocusChange() {
    if (_medicationOtherDraftFocus.hasFocus) return;
    _commitMedicationOtherDraft();
  }

  void _loadUser() async {
    final user = await AuthService.getUser();
    if (!mounted) return;
    setState(() {
      _currentUser = user;
    });

    // 전달받은 기존 건강프로필가 있으면 우선 사용
    if (widget.existingProfile != null) {
      if (!mounted) return;
      setState(() {
        _existingProfile = widget.existingProfile;
      });
      _loadExistingData(widget.existingProfile!);
    } else if (user != null) {
      // 전달받은 건강프로필가 없으면 API에서 확인
      _checkExistingProfile();
    }
  }

  void _checkExistingProfile() async {
    try {
      final existingProfile =
          await HealthProfileService.getHealthProfile(_currentUser!.id);

      if (!mounted) return;

      if (existingProfile != null) {
        // 기존 건강프로필 정보 저장
        setState(() {
          _existingProfile = existingProfile;
        });

        _loadExistingData(existingProfile);
      } else {
        final u = _currentUser!;
        // 최초 작성: 회원 테이블(bomiora_member) 값은 "프리필"만 (저장 시 member 테이블은 갱신하지 않음)
        _prefillMemberBasicsFromUser(u);
      }
    } catch (e) {
      // 프로필 로드 실패 시 무시
    }
  }

  void _prefillMemberBasicsFromUser(UserModel user) {
    // 이미 프로필/폼에 값이 있으면 덮어쓰지 않음
    final hasBirth =
        (_formData['answer_1']?.toString().trim().isNotEmpty == true) ||
            ((_formData['birth_year']?.toString().length ?? 0) == 4 &&
                (_formData['birth_month']?.toString().length ?? 0) == 2 &&
                (_formData['birth_day']?.toString().length ?? 0) == 2);
    final g = _formData['answer_2']?.toString().trim() ?? '';
    final hasGender = g == 'M' || g == 'F';

    var changed = false;
    var birthPrefilled = false;

    if (!hasBirth) {
      final raw = (user.birthDate ?? '').trim().replaceAll(RegExp(r'\D'), '');
      if (raw.length >= 8) {
        final ymd = raw.substring(0, 8);
        _formData['answer_1'] = ymd;
        _formData['birth_year'] = ymd.substring(0, 4);
        _formData['birth_month'] = ymd.substring(4, 6);
        _formData['birth_day'] = ymd.substring(6, 8);
        changed = true;
        birthPrefilled = true;
      }
    }

    if (!hasGender) {
      final rawSex = (user.sex ?? '').trim();
      if (rawSex.isNotEmpty) {
        final upper = rawSex.toUpperCase();
        if (upper == 'M' || rawSex == '남' || rawSex == '남성') {
          _formData['answer_2'] = 'M';
          changed = true;
        } else if (upper == 'F' || rawSex == '여' || rawSex == '여성') {
          _formData['answer_2'] = 'F';
          changed = true;
        } else if (rawSex == '1' || rawSex == '01') {
          _formData['answer_2'] = 'M';
          changed = true;
        } else if (rawSex == '2' || rawSex == '02') {
          _formData['answer_2'] = 'F';
          changed = true;
        }
      }
    }

    if (changed && mounted) {
      if (birthPrefilled) _wizardBirthFieldKeySeed++;
      setState(() {});
    }
  }

  void _initializeSections() {
    _sections = [
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
              id: 'answer_7_1', question: '식사시간', type: 'mealtime'),
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

  void _loadExistingData(HealthProfileModel profile) {
    // 생년월일 파싱 (YYYYMMDD 형식)
    if (profile.answer1.isNotEmpty && profile.answer1.length >= 8) {
      _formData['birth_year'] = profile.answer1.substring(0, 4);
      _formData['birth_month'] = profile.answer1.substring(4, 6);
      _formData['birth_day'] = profile.answer1.substring(6, 8);
    }
    _formData['answer_1'] = profile.answer1;

    // API·저장값은 M/F. 피그마 칩(selected)도 M/F와 비교하므로 로드 시 그대로 M/F 유지.
    final rawGender = profile.answer2.trim();
    final upper = rawGender.toUpperCase();
    if (upper == 'M' || rawGender == '남성' || rawGender == '남') {
      _formData['answer_2'] = 'M';
    } else if (upper == 'F' || rawGender == '여성' || rawGender == '여') {
      _formData['answer_2'] = 'F';
    } else {
      _formData['answer_2'] = rawGender;
    }
    // answer3: 신규 UI는 목표 체중. 레거시(감량량)면 현재체중−감량으로 변환해 표시.
    final rawGoalOrLoss = profile.answer3.trim();
    final a3 = double.tryParse(rawGoalOrLoss.replaceAll(',', ''));
    final w = double.tryParse(profile.answer5.trim().replaceAll(',', ''));
    if (a3 != null && w != null && a3 > 0 && a3 < 30) {
      final goal = w - a3;
      _formData['answer_3'] = goal == goal.roundToDouble()
          ? goal.toStringAsFixed(0)
          : goal.toStringAsFixed(1);
    } else {
      _formData['answer_3'] = profile.answer3;
    }
    _formData['answer_4'] = profile.answer4;
    _formData['answer_5'] = profile.answer5;
    _formData['answer_6'] = _normalizeDietPeriodOption(profile.answer6);
    _formData['answer_7'] = _normalizeMealsPerDay(profile.answer7);

    // 식사시간 파싱 (| 기준으로 분리)
    // 예: 122||222|555,666,777 -> 1식: 122, 2식: (없음), 3식: 222, 기타: 555,666,777
    if (profile.answer71.isNotEmpty) {
      final parts = profile.answer71.split('|');
      // 각 부분을 순서대로 할당 (빈 문자열도 유지)
      _formData['meal_1'] = parts.length > 0 ? parts[0] : '';
      _formData['meal_2'] = parts.length > 1 ? parts[1] : '';
      _formData['meal_3'] = parts.length > 2 ? parts[2] : '';
      _formData['meal_other'] = parts.length > 3 ? parts[3] : '';
    }
    _formData['answer_7_1'] = profile.answer71;

    // answer_8 (식습관) - 파이프(|)로 구분된 문자열을 List로 변환
    if (profile.answer8.isNotEmpty) {
      _formData['answer_8'] = profile.answer8
          .split('|')
          .map(_normalizeChipOptionLabel)
          .where((e) => e.isNotEmpty)
          .toList();
    } else {
      _formData['answer_8'] = [];
    }

    // answer_9 (자주 먹는 음식) - 파이프(|)로 구분된 문자열을 List로 변환
    if (profile.answer9.isNotEmpty) {
      _formData['answer_9'] = profile.answer9
          .split('|')
          .map(_normalizeChipOptionLabel)
          .where((e) => e.isNotEmpty)
          .toList();
    } else {
      _formData['answer_9'] = [];
    }

    HealthProfilePayload.parseAnswer10IntoFormData(
      profile.answer10,
      answer10TypesRaw: profile.answer102,
      setFrequency: (f) => _formData['answer_10'] = f,
      setTypes: (t) => _applyLoadedExerciseTypes(t),
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

    // answer_11 (질병)
    if (rawMeansNoHealth(profile.answer11)) {
      _formData['answer_11'] = <String>['해당없음'];
    } else if (profile.answer11.isNotEmpty) {
      _formData['answer_11'] = normalizeDiseaseMedicationParts(
        profile.answer11.split('|'),
      ).map((e) => e == '해당 없음' ? '해당없음' : e).toList();
    } else {
      _formData['answer_11'] = <String>['해당없음'];
    }

    // 복용중인 약 (기타 파싱 유지)
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
          _formData['answer_12'] = <String>['해당 없음'];
          _formData.remove('answer_12_other');
          _medicationOthers.clear();
          _medicationOtherDraftOpen = false;
        } else {
          _formData['answer_12'] = normalized;
          _medicationOthers
            ..clear()
            ..addAll(otherValues);
          _medicationOtherDraftOpen =
              normalized.contains('기타') && otherValues.isEmpty;
          _formData['answer_12_other'] = otherValues.join(', ');
        }
      } else {
        if (profile.answer12 == '기타') {
          _formData['answer_12'] = ['기타'];
          _medicationOthers.clear();
          _medicationOtherDraftOpen = true;
        } else if (rawMeansNoHealth(profile.answer12)) {
          _formData['answer_12'] = <String>['해당 없음'];
        } else {
          final v = profile.answer12 == '없음' ? '해당 없음' : profile.answer12;
          _formData['answer_12'] = [v];
        }
      }
    } else {
      _formData['answer_12'] = <String>['해당 없음'];
    }

    // 다이어트 약 변환 (1 = 없음, 2 = 있음)
    if (profile.answer13 == '1') {
      _formData['answer_13'] = '없음';
    } else if (profile.answer13 == '2') {
      _formData['answer_13'] = '있음';
    } else {
      _formData['answer_13'] = profile.answer13;
    }

    _formData['answer_13_medicine'] = profile.answer13Medicine;
    _formData['answer_13_period'] = profile.answer13Period;
    _formData['answer_13_dosage'] = profile.answer13Dosage;
    _formData['answer_13_sideeffect'] = profile.answer13Sideeffect;

    // 기존 데이터 백업 (있음 → 없음 → 있음 선택 시 복원용)
    _backupAnswer13Fields['answer_13_medicine'] = profile.answer13Medicine;
    _backupAnswer13Fields['answer_13_period'] = profile.answer13Period;
    _backupAnswer13Fields['answer_13_dosage'] = profile.answer13Dosage;
    _backupAnswer13Fields['answer_13_sideeffect'] = profile.answer13Sideeffect;

    // UI 업데이트 (생년월일 필드 initialValue 반영)
    if (mounted) {
      _wizardBirthFieldKeySeed++;
      setState(() {});
    }
  }

  /// API/DB 값이 선택지와 약간 다를 때(공백·개행 등) 목표 기간 드롭다운과 맞춤
  /// 기본정보(YYYYMMDD 한 칸) 표시·TextFormField 재생성용 — `initialValue`는 첫 마운트만 적용되므로 Key와 함께 사용
  String _birthYyyymmddDisplayForWizardField() {
    final a1 = (_formData['answer_1']?.toString().trim() ?? '');
    if (a1.length == 8 && RegExp(r'^\d{8}$').hasMatch(a1)) return a1;
    final y = (_formData['birth_year']?.toString().trim() ?? '');
    final m = (_formData['birth_month']?.toString().trim() ?? '');
    final d = (_formData['birth_day']?.toString().trim() ?? '');
    if (y.length != 4 || m.isEmpty || d.isEmpty) return '';
    final mm = m.padLeft(2, '0');
    final dd = d.padLeft(2, '0');
    if (mm.length != 2 || dd.length != 2) return '';
    return '$y$mm$dd';
  }

  String _normalizeDietPeriodOption(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    final options = HealthProfileQuestionnaireOptions.dietPeriod;
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

  String _normalizeMealsPerDay(String raw) {
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
    final options = HealthProfileQuestionnaireOptions.mealsPerDay;
    if (options.contains(t)) return t;
    return t;
  }

  /// 칩 라벨 공백/개행·오타(다이터트) 정규화
  String _normalizeChipOptionLabel(String raw) {
    var s = raw.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.contains('샐러드') && (s.contains('다이어트') || s.contains('다이터트'))) {
      return '샐러드/다이어트식단';
    }
    return s;
  }

  void _applyLoadedExerciseTypes(List<String> loaded) {
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
    _formData['answer_10_types'] = selected;
    _exerciseOthers
      ..clear()
      ..addAll(others);
    _exerciseOtherDraftOpen = selected.contains('기타') && others.isEmpty;
    _exerciseOtherDraftCtrl.clear();
  }

  bool _isExerciseOtherSelected() {
    final raw = _formData['answer_10_types'];
    if (raw is List) return raw.map((e) => e.toString()).contains('기타');
    return raw?.toString() == '기타';
  }

  void _clearExerciseOthers() {
    _exerciseOthers.clear();
    _exerciseOtherDraftOpen = false;
    _exerciseOtherDraftCtrl.clear();
  }

  void _commitExerciseOtherDraft() {
    final text = _exerciseOtherDraftCtrl.text.trim();
    if (text.isEmpty) return;
    if (_exerciseOthers.contains(text)) {
      _exerciseOtherDraftCtrl.clear();
      setState(() => _exerciseOtherDraftOpen = false);
      return;
    }
    setState(() {
      _exerciseOthers.add(text);
      _exerciseOtherDraftCtrl.clear();
      _exerciseOtherDraftOpen = false;
    });
  }

  void _removeExerciseOtherAt(int index) {
    setState(() {
      if (index < 0 || index >= _exerciseOthers.length) return;
      _exerciseOthers.removeAt(index);
      if (_exerciseOthers.isEmpty && _isExerciseOtherSelected()) {
        _exerciseOtherDraftOpen = true;
      }
    });
  }

  void _openExerciseOtherDraft() {
    final text = _exerciseOtherDraftCtrl.text.trim();
    if (text.isNotEmpty && !_exerciseOthers.contains(text)) {
      _exerciseOthers.add(text);
      _exerciseOtherDraftCtrl.clear();
    }
    setState(() {
      _exerciseOtherDraftOpen = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _exerciseOtherDraftFocus.requestFocus();
    });
  }

  void _syncMedicationOtherFormData() {
    _formData['answer_12_other'] = [
      ..._medicationOthers,
      if (_medicationOtherDraftCtrl.text.trim().isNotEmpty)
        _medicationOtherDraftCtrl.text.trim(),
    ].join(', ');
  }

  void _clearMedicationOthers() {
    _medicationOthers.clear();
    _medicationOtherDraftOpen = false;
    _medicationOtherDraftCtrl.clear();
    _formData['answer_12_other'] = '';
  }

  void _commitMedicationOtherDraft() {
    final text = _medicationOtherDraftCtrl.text.trim();
    if (text.isEmpty) return;
    if (_medicationOthers.contains(text)) {
      _medicationOtherDraftCtrl.clear();
      setState(() {
        _medicationOtherDraftOpen = false;
        _syncMedicationOtherFormData();
      });
      return;
    }
    setState(() {
      _medicationOthers.add(text);
      _medicationOtherDraftCtrl.clear();
      _medicationOtherDraftOpen = false;
      _syncMedicationOtherFormData();
    });
  }

  void _removeMedicationOtherAt(int index) {
    setState(() {
      if (index < 0 || index >= _medicationOthers.length) return;
      _medicationOthers.removeAt(index);
      if (_medicationOthers.isEmpty && _isMedicationOtherSelected()) {
        _medicationOtherDraftOpen = true;
      }
      _syncMedicationOtherFormData();
    });
  }

  bool _isMedicationOtherSelected() {
    final raw = _formData['answer_12'];
    if (raw is List) return raw.map((e) => e.toString()).contains('기타');
    return raw?.toString() == '기타';
  }

  void _openMedicationOtherDraft() {
    final text = _medicationOtherDraftCtrl.text.trim();
    if (text.isNotEmpty && !_medicationOthers.contains(text)) {
      _medicationOthers.add(text);
      _medicationOtherDraftCtrl.clear();
    }
    setState(() {
      _medicationOtherDraftOpen = true;
      _syncMedicationOtherFormData();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _medicationOtherDraftFocus.requestFocus();
    });
  }

  void _hideBmiGuideOverlay() {
    _bmiGuideOverlay?.remove();
    _bmiGuideOverlay = null;
  }

  void _toggleBmiGuideOverlay() {
    if (_bmiGuideOverlay != null) {
      _hideBmiGuideOverlay();
      return;
    }
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final iconCtx = _bmiGuideIconKey.currentContext;
    if (iconCtx == null) return;
    final box = iconCtx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (overlayBox == null) return;

    final iconTopLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final iconSize = box.size;
    // 라벨 아래·아이콘 왼쪽 정렬에 가깝게 배치
    final left = (iconTopLeft.dx - healthDp(context, 8))
        .clamp(healthDp(context, 16), double.infinity);
    final top = iconTopLeft.dy + iconSize.height + healthDp(context, 8);

    _bmiGuideOverlay = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _hideBmiGuideOverlay,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: Material(
                color: Colors.transparent,
                child: _buildBmiGuidePopup(),
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_bmiGuideOverlay!);
  }

  Widget _buildBmiGuidePopup() {
    Widget row(Color color, String text) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: healthDp(context, 8),
            height: healthDp(context, 8),
            decoration: ShapeDecoration(
              color: color,
              shape: const OvalBorder(),
            ),
          ),
          SizedBox(width: healthDp(context, 4)),
          Text(
            text,
            style: TextStyle(
              color: const Color(0xFF898686),
              fontSize: healthSp(context, 14),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.all(healthDp(context, 14)),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _pfBorder),
          borderRadius: BorderRadius.circular(healthDp(context, 15)),
        ),
        shadows: [
          BoxShadow(
            color: const Color(0x0C000000),
            blurRadius: healthDp(context, 10),
            offset: Offset(healthDp(context, 4), healthDp(context, 4)),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BMI 상태 안내',
            style: TextStyle(
              color: const Color(0xFF1A1A1E),
              fontSize: healthSp(context, 14),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          row(const Color(0xFF60A5FA), '저체중 (18.5 미만)'),
          SizedBox(height: healthDp(context, 10)),
          row(const Color(0xFF4ADE80), '정상 (18.5 ~ 22.9)'),
          SizedBox(height: healthDp(context, 10)),
          row(const Color(0xFFFACC15), '과체중 (23 ~ 24.9)'),
          SizedBox(height: healthDp(context, 10)),
          row(const Color(0xFFFB923C), '비만 (25 ~ 29.9)'),
          SizedBox(height: healthDp(context, 10)),
          row(const Color(0xFFF87171), '고도비만 (30 이상)'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subs = widget.initialSectionIndices;
    final isSubsetEdit = subs != null && subs.isNotEmpty;
    final isSingleSectionMode = isSubsetEdit && subs.length == 1;
    final isMultiSubsetMode = isSubsetEdit && subs.length > 1;
    final appBarEditTitle = widget.editScreenTitle ??
        (_sections.isNotEmpty && _currentPage < _sections.length
            ? _sections[_currentPage].title
            : '');

    final isPrescriptionBooking = widget.prescriptionBooking != null;
    final stepCount = _sections.isEmpty ? _stepLabels.length : _sections.length;
    // 장(페이지)을 넘길 때마다 1/4씩 채움 (0장→0, 1장 완료→0.25 … 3장 완료→0.75)
    final wizardStepProgress =
        stepCount <= 0 ? 0.0 : (_currentPage / stepCount).clamp(0.0, 1.0);

    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _popAllHealthProfileFormRoutes(context);
      },
      child: Theme(
        data: gmarketTheme,
        child: MobileAppLayoutWrapper(
          appBar: HealthAppBar(
            title: isPrescriptionBooking
                ? '진료 예약 중 _ 01 문진표'
                : (isSubsetEdit ? '$appBarEditTitle 수정' : '문진표'),
            titleFontSize: healthSp(context, isPrescriptionBooking ? 16 : 18),
            centerTitle: false,
            leadingIconSize: healthDp(context, 24),
            onBack: () => _popAllHealthProfileFormRoutes(context),
            bottom: isPrescriptionBooking
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(
                      PrescriptionBookingProgressBar.preferredHeight,
                    ),
                    child: PrescriptionBookingProgressBar(
                      currentStep: PrescriptionBookingSteps.questionnaire,
                      stepProgress: wizardStepProgress,
                    ),
                  )
                : null,
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
            child: _currentUser == null
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF3787)),
                  )
                : isMultiSubsetMode
                    ? _buildMultiSubsetFormMode()
                    : isSingleSectionMode
                        ? _buildSingleSectionMode()
                        : _buildFullFormMode(),
          ),
        ),
      ),
    );
  }

  /// 카드별 수정마다 push되어 스택이 여러 겹일 때, 한 번에 문진표 바깥(예: 프로필 목록)으로 나감.
  void _popAllHealthProfileFormRoutes(BuildContext context) {
    Navigator.of(context).popUntil(
      (route) => route.settings.name != HealthProfileFormScreen.routeName,
    );
  }

  /// 식습관+운동처럼 여러 단계를 스와이프로 넘기되, 이전/다음 바는 숨기고 `수정하기`만 표시
  Widget _buildMultiSubsetFormMode() {
    final subs = widget.initialSectionIndices!;
    final mergeDietExercise = subs.length == 2 && subs[0] == 1 && subs[1] == 2;

    Widget body;
    if (mergeDietExercise) {
      body = SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            healthDp(context, 27),
            healthDp(context, 20),
            healthDp(context, 27),
            healthDp(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _wizardStepQuestionsColumn(_sections[1], 1),
            SizedBox(height: healthDp(context, 20)),
            _wizardStepQuestionsColumn(_sections[2], 2),
          ],
        ),
      );
    } else {
      body = PageView.builder(
        controller: _pageController,
        clipBehavior: Clip.hardEdge,
        onPageChanged: (page) {
          setState(() {
            _currentPage = subs[page];
          });
        },
        itemCount: subs.length,
        itemBuilder: (context, i) {
          final secIndex = subs[i];
          return RepaintBoundary(
            child: _buildWizardStepScrollable(
              _sections[secIndex],
              secIndex,
            ),
          );
        },
      );
    }

    return ColoredBox(
      color: Colors.white,
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: body,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    healthDp(context, 27),
                    healthDp(context, 4),
                    healthDp(context, 27),
                    healthDp(context, 20)),
                child: SizedBox(
                  width: double.infinity,
                  height: healthDp(context, 40),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3787),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      minimumSize: Size(double.infinity, healthDp(context, 40)),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 10)),
                      ),
                    ),
                    child: Text(
                      '수정하기',
                      style: TextStyle(
                        fontSize: healthSp(context, 16),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF3787)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFullFormMode() {
    return ColoredBox(
      color: Colors.white,
      child: Stack(
        children: [
          Form(
            key: _formKey,
            child: PageView.builder(
              controller: _pageController,
              clipBehavior: Clip.hardEdge,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (page) {
                setState(() => _currentPage = page);
              },
              itemCount: _sections.length,
              itemBuilder: (context, index) {
                return RepaintBoundary(
                  child: _buildWizardStepScrollable(
                    _sections[index],
                    index,
                    showBottomBar: true,
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF3787)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWizardStepIndicator() {
    final tabH = healthDp(context, 45);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_sections.length, (i) {
        // 현재 탭만 살짝 더 넓게(나머지는 동일 비율로 조금씩 줄어듦)
        return Flexible(
          flex: i == _currentPage ? 15 : 8,
          child: Padding(
            padding: EdgeInsets.only(
              right: i < _sections.length - 1 ? healthDp(context, 6) : 0,
            ),
            child: i == _currentPage
                ? Container(
                    height: tabH,
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 4),
                    ),
                    decoration: BoxDecoration(
                      color: _pfPink,
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 10)),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _stepLabels[i],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: healthSp(context, 14),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                        ),
                      ),
                    ),
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _jumpToWizardStep(i),
                    child: Container(
                      height: tabH,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _pfPink, width: healthDp(context, 1)),
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 10)),
                      ),
                      alignment: Alignment.center,
                      padding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 2),
                      ),
                      child: Semantics(
                        label: _stepLabels[i],
                        button: true,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              i < _wizardStepIconAssets.length
                                  ? _wizardStepIconAssets[i]
                                  : AppAssets.profile1,
                              width: healthDp(context, 20),
                              height: healthDp(context, 20),
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        );
      }),
    );
  }

  Future<void> _jumpToWizardStep(int i) async {
    if (i == _currentPage || i < 0 || i >= _sections.length) return;
    if (i > _currentPage) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      _formKey.currentState?.save();
    }
    await _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
  }

  Widget _wizardStepQuestionsColumn(
    HealthProfileSection section,
    int stepIndex,
  ) {
    final visible =
        section.questions.where((q) => _shouldShowQuestion(q)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          _buildFigmaQuestionBlock(visible[i], stepIndex),
          if (i < visible.length - 1) SizedBox(height: healthDp(context, 20)),
        ],
      ],
    );
  }

  Widget _buildWizardStepScrollable(
    HealthProfileSection section,
    int stepIndex, {
    bool showBottomBar = false,
  }) {
    final isFullWizard = widget.initialSectionIndices == null ||
        widget.initialSectionIndices!.isEmpty;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 27),
        healthDp(context, 10),
        healthDp(context, 27),
        healthDp(context, 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isFullWizard) ...[
            _buildWizardStepHero(stepIndex),
            SizedBox(height: healthDp(context, 30)),
          ],
          _wizardStepQuestionsColumn(section, stepIndex),
          if (showBottomBar) ...[
            SizedBox(height: healthDp(context, 24)),
            _buildWizardBottomBar(),
            SizedBox(height: healthDp(context, 8)),
          ],
        ],
      ),
    );
  }

  /// Figma: `1/4` 배지 + "OOO님의 …" 헤드라인
  Widget _buildWizardStepHero(int stepIndex) {
    final name = (_currentUser?.name.trim().isNotEmpty ?? false)
        ? _currentUser!.name.trim()
        : '회원';
    final total = _sections.length;
    final step = stepIndex + 1;

    final (String emphasis, String prefix, String suffix) = switch (stepIndex) {
      0 => ('기본정보', '님의 맞춤 처방을 위해\n', '를 입력해 주세요'),
      1 => ('식습관', '님의 ', '을 체크해볼게요.'),
      2 => ('운동습관', '님의 ', '을 체크해볼게요.'),
      _ => ('건강상태', '님의 ', '를 체크해볼게요.'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 14),
            vertical: healthDp(context, 4),
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(healthDp(context, 9999)),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$step',
                  style: TextStyle(
                    color: const Color(0xFF0F172A),
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1.43,
                  ),
                ),
                TextSpan(
                  text: '/$total',
                  style: TextStyle(
                    color: const Color(0xFF898686),
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1.43,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: healthDp(context, 10)),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: name,
                style: TextStyle(
                  color: const Color(0xFF0F172A),
                  fontSize: healthSp(context, 22),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  letterSpacing: healthSp(context, -2),
                ),
              ),
              TextSpan(
                text: prefix,
                style: TextStyle(
                  color: const Color(0xFF0F172A),
                  fontSize: healthSp(context, 22),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                  letterSpacing: healthSp(context, -2),
                ),
              ),
              TextSpan(
                text: emphasis,
                style: TextStyle(
                  color: const Color(0xFF0F172A),
                  fontSize: healthSp(context, 22),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  letterSpacing: healthSp(context, -2),
                ),
              ),
              TextSpan(
                text: suffix,
                style: TextStyle(
                  color: const Color(0xFF0F172A),
                  fontSize: healthSp(context, 22),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                  letterSpacing: healthSp(context, -2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWizardBottomBar() {
    final last = _currentPage >= _sections.length - 1;
    final stepFilled = _isWizardStepFilled(_currentPage);
    final canProceed = last ? _isAllWizardStepsFilled() : stepFilled;
    return Row(
      children: [
        if (_currentPage > 0) ...[
          SizedBox(
            width: healthDp(context, 45),
            height: healthDp(context, 45),
            child: OutlinedButton(
              onPressed: _isLoading ? null : _previousPage,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                side: BorderSide(
                    width: healthDp(context, 1),
                    color: const Color(0x7FD2D2D2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 8)),
                ),
              ),
              child: Icon(
                Icons.chevron_left,
                color: const Color(0xFF898686),
                size: healthDp(context, 22),
              ),
            ),
          ),
          SizedBox(width: healthDp(context, 10)),
        ],
        Expanded(
          child: SizedBox(
            height: healthDp(context, 45),
            child: FilledButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      if (!canProceed) {
                        AppToastOverlay.show(
                          context,
                          '모든 문진표를 작성해야합니다',
                        );
                        return;
                      }
                      if (last) {
                        _submitForm();
                      } else {
                        _nextPage();
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: canProceed
                    ? const Color(0xFFFF5A8D)
                    : const Color(0xFFD2D2D2),
                disabledBackgroundColor: const Color(0xFFD2D2D2),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                ),
              ),
              child: Text(
                last ? '완료' : '다음',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: healthSp(context, 16),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
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

  bool _isBirthValid() {
    final a1 = (_formData['answer_1']?.toString().trim() ?? '');
    if (a1.length == 8) {
      final y = int.tryParse(a1.substring(0, 4));
      final m = int.tryParse(a1.substring(4, 6));
      final d = int.tryParse(a1.substring(6, 8));
      if (y == null || m == null || d == null) return false;
      return _isYmdValid(y, m, d);
    }

    final ys = _formData['birth_year']?.toString().trim() ?? '';
    final ms = _formData['birth_month']?.toString().trim() ?? '';
    final ds = _formData['birth_day']?.toString().trim() ?? '';
    if (ys.length != 4 || ms.length != 2 || ds.length != 2) return false;
    final y = int.tryParse(ys);
    final m = int.tryParse(ms);
    final d = int.tryParse(ds);
    if (y == null || m == null || d == null) return false;
    return _isYmdValid(y, m, d);
  }

  bool _isWizardStepFilled(int stepIndex) {
    if (stepIndex < 0 || stepIndex >= _sections.length) return false;
    final section = _sections[stepIndex];

    if (stepIndex == 0) {
      if (!_nonEmptyString(_formData['answer_1']) &&
          !(((_formData['birth_year']?.toString().length ?? 0) == 4) &&
              ((_formData['birth_month']?.toString().length ?? 0) == 2) &&
              ((_formData['birth_day']?.toString().length ?? 0) == 2))) {
        return false;
      }
      if (!_isBirthValid()) return false;

      final g = _formData['answer_2']?.toString().trim() ?? '';
      if (g != 'M' && g != 'F') return false;

      if (!_nonEmptyString(_formData['answer_4'])) return false;
      if (!_nonEmptyString(_formData['answer_5'])) return false;
      if (!_nonEmptyString(_formData['answer_3'])) return false;
      if (_isGoalWeightTooHigh()) return false;
      if (!_nonEmptyString(_formData['answer_6'])) return false;
      return true;
    }

    for (final q in section.questions) {
      if (!_shouldShowQuestion(q)) continue;
      if (q.type == 'mealtime') continue; // 식사시간은 필수 제외

      switch (q.type) {
        case 'grid':
          final raw = _formData[q.id];
          if (q.allowMultiple == true) {
            if (!_nonEmptyList(raw)) return false;
          } else {
            if (!_nonEmptyString(raw)) return false;
          }
          if (q.id == 'answer_10') {
            if (!_nonEmptyList(_formData['answer_10_types'])) return false;
            if (_isExerciseOtherSelected()) {
              final hasCommitted =
                  _exerciseOthers.any((e) => e.trim().isNotEmpty);
              final hasDraft = _exerciseOtherDraftCtrl.text.trim().isNotEmpty;
              if (!hasCommitted && !hasDraft) return false;
            }
          }
          if (q.id == 'answer_12' && _isMedicationOtherSelected()) {
            final hasCommitted =
                _medicationOthers.any((e) => e.trim().isNotEmpty);
            final hasDraft = _medicationOtherDraftCtrl.text.trim().isNotEmpty;
            if (!hasCommitted && !hasDraft) return false;
          }
          break;
        case 'radio':
          if (!_nonEmptyString(_formData[q.id])) return false;
          break;
        case 'text':
          if (q.isRequired && !_nonEmptyString(_formData[q.id])) return false;
          break;
        default:
          break;
      }
    }

    // 다이어트약 상세(있음) 필수값 — 건강정보(3/4)에 포함
    final a13 = _formData['answer_13']?.toString().trim() ?? '';
    if (stepIndex == 3 && (a13 == '있음' || a13 == '2')) {
      if (!_nonEmptyString(_formData['answer_13_medicine'])) return false;
      if (!_nonEmptyString(_formData['answer_13_period'])) return false;
      if (!_nonEmptyString(_formData['answer_13_dosage'])) return false;
      if (!_nonEmptyString(_formData['answer_13_sideeffect'])) return false;
    }

    return true;
  }

  bool _isAllWizardStepsFilled() {
    for (var i = 0; i < _sections.length; i++) {
      if (!_isWizardStepFilled(i)) return false;
    }
    return true;
  }

  bool _isFirstVisibleInStep(int stepIndex, String questionId) {
    for (final q in _sections[stepIndex].questions) {
      if (!_shouldShowQuestion(q)) continue;
      return q.id == questionId;
    }
    return false;
  }

  bool _showPerQuestionCaption(HealthProfileQuestion q, int stepIndex) {
    if (q.type == 'wizard_basic') return false;
    // 기타 약 정보는 전용 카드 헤더를 쓰므로 바깥 캡션 생략
    if (q.id == 'answer_12_other') return false;
    return true;
  }

  Widget _buildFigmaQuestionBlock(
      HealthProfileQuestion question, int stepIndex) {
    final hintInlineIds = const <String>{
      'answer_12',
      'answer_10_types',
      'answer_8',
      'answer_9',
      'answer_11',
    };
    final showInlineMultipleHint =
        question.allowMultiple && hintInlineIds.contains(question.id);

    return Padding(
      padding: EdgeInsets.only(bottom: healthDp(context, 4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showPerQuestionCaption(question, stepIndex) &&
              question.type != 'mealtime') ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  question.question,
                  style: TextStyle(
                    color: const Color(0xFF1A1A1E),
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (showInlineMultipleHint) ...[
                  SizedBox(width: healthDp(context, 10)),
                  Text(
                    '*중복선택가능',
                    style: _figmaMultiHintStyle(context),
                  ),
                ],
              ],
            ),
            SizedBox(height: healthDp(context, 10)),
          ],
          if (question.type == 'mealtime') ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '식사시간',
                  style: TextStyle(
                    color: const Color(0xFF1A1A1E),
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: healthDp(context, 10)),
                Text(
                  '*해당되는 입력란에만 입력하세요',
                  style: _figmaMultiHintStyle(context),
                ),
              ],
            ),
            SizedBox(height: healthDp(context, 10)),
          ],
          _buildFigmaInput(question),
        ],
      ),
    );
  }

  Widget _buildFigmaStepHeading(int stepIndex) {
    final title = switch (stepIndex) {
      0 => '기본정보',
      1 => '하루 끼니',
      2 => '운동 빈도',
      3 => '현재 질환',
      _ => '다이어트 약',
    };
    return _figmaTitleLeadingBarRow(
      crossAxisAlignment: CrossAxisAlignment.center,
      child: stepIndex == 3
          ? Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: healthDp(context, 5),
              runSpacing: healthDp(context, 4),
              children: [
                Text(
                  title,
                  style: _figmaSectionTitleStyle(),
                ),
                Text(
                  '*중복선택가능',
                  style: _figmaMultiHintStyle(context),
                ),
              ],
            )
          : Text(
              title,
              style: _figmaSectionTitleStyle(),
            ),
    );
  }

  TextStyle _figmaSectionTitleStyle() {
    // 섹션 타이틀("|" 뒤 텍스트): 375 기준 18 / w500
    return TextStyle(
      color: const Color(0xFF1A1A1A),
      fontSize: healthSp(context, 18),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w500,
      height: 1.25,
    );
  }

  /// 식사 시간 등 섹션 제목 앞 세로 바 (Figma `|`)
  Widget _figmaTitleLeadingBarRow({
    required Widget child,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
  }) {
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Container(
          width: healthDp(context, 2),
          height: healthDp(context, 18),
          color: Colors.black,
        ),
        SizedBox(width: healthDp(context, 10)),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildFigmaInput(HealthProfileQuestion question) {
    switch (question.type) {
      case 'wizard_basic':
        return _buildFigmaBirthAndGender();
      case 'birthdate':
        return _buildFigmaBirthAndGender();
      case 'radio':
        if (question.id == 'answer_2') {
          return const SizedBox.shrink();
        }
        if (question.id == 'answer_13') {
          return _buildFigmaYesNoChips();
        }
        return _buildInputWidget(question);
      case 'mealtime':
        return _buildFigmaMealtimeTable();
      case 'grid':
        return _buildFigmaGrid(question);
      case 'text':
        if (question.id == 'answer_12_other') {
          return _buildOtherMedicationCard();
        }
        return _buildFigmaLabeledField(question);
      default:
        return _buildFigmaLabeledField(question);
    }
  }

  Widget _buildOtherMedicationCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 14)),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _pfBorder),
          borderRadius: BorderRadius.circular(healthDp(context, 15)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '기타 약 정보',
                  style: TextStyle(
                    color: const Color(0xFF1A1A1E),
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openMedicationOtherDraft,
                  borderRadius: BorderRadius.circular(healthDp(context, 50)),
                  child: Container(
                    height: healthDp(context, 28),
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 10),
                    ),
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                            width: healthDp(context, 1), color: _pfBorder),
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 50)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          size: healthDp(context, 14),
                          color: const Color(0xFF898686),
                        ),
                        SizedBox(width: healthDp(context, 2)),
                        Text(
                          '추가',
                          style: TextStyle(
                            color: const Color(0xFF898686),
                            fontSize: healthSp(context, 12),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: healthDp(context, 14)),
          Container(height: healthDp(context, 1), color: _pfBorder),
          SizedBox(height: healthDp(context, 20)),
          if (_medicationOthers.isNotEmpty)
            Wrap(
              spacing: healthDp(context, 8),
              runSpacing: healthDp(context, 8),
              children: [
                for (var i = 0; i < _medicationOthers.length; i++)
                  _buildMedicationOtherChip(_medicationOthers[i], i),
              ],
            ),
          if (_medicationOtherDraftOpen || _medicationOthers.isEmpty) ...[
            if (_medicationOthers.isNotEmpty)
              SizedBox(height: healthDp(context, 8)),
            _buildMedicationOtherDraftField(),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicationOtherChip(String label, int index) {
    return Container(
      height: healthDp(context, 45),
      padding: EdgeInsets.only(
        left: healthDp(context, 14),
        right: healthDp(context, 8),
      ),
      decoration: ShapeDecoration(
        color: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _pfBorder),
          borderRadius: BorderRadius.circular(healthDp(context, 50)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF1A1A1E),
              fontSize: healthSp(context, 14),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: healthDp(context, 4)),
          GestureDetector(
            onTap: () => _removeMedicationOtherAt(index),
            behavior: HitTestBehavior.opaque,
            child: Icon(
              Icons.close,
              size: healthSp(context, 16),
              color: const Color(0xFF898686),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationOtherDraftField() {
    return SizedBox(
      width: double.infinity,
      height: healthDp(context, 45),
      child: TextField(
        controller: _medicationOtherDraftCtrl,
        focusNode: _medicationOtherDraftFocus,
        textInputAction: TextInputAction.done,
        textAlignVertical: TextAlignVertical.center,
        onSubmitted: (_) => _commitMedicationOtherDraft(),
        onChanged: (_) {
          _syncMedicationOtherFormData();
          setState(() {});
        },
        style: TextStyle(
          color: const Color(0xFF1A1A1E),
          fontSize: healthSp(context, 14),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: '복용중인 약 이름을 입력해주세요',
          hintStyle: TextStyle(
            color: const Color(0xFF898686),
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 14),
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 50)),
            borderSide:
                BorderSide(width: healthDp(context, 1), color: _pfBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 50)),
            borderSide:
                BorderSide(width: healthDp(context, 1), color: _pfBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 50)),
            borderSide: BorderSide(
                width: healthDp(context, 1), color: const Color(0xFFFF5A8D)),
          ),
        ),
      ),
    );
  }

  double _figmaLabeledControlHeight(BuildContext context) =>
      healthDp(context, 45);

  Widget _buildFigmaBirthAndGender() {
    final height = double.tryParse(
      (_formData['answer_4']?.toString() ?? '').replaceAll(',', ''),
    );
    final weight = double.tryParse(
      (_formData['answer_5']?.toString() ?? '').replaceAll(',', ''),
    );
    final goal = double.tryParse(
      (_formData['answer_3']?.toString() ?? '').replaceAll(',', ''),
    );
    final remaining = (weight != null && goal != null) ? weight - goal : null;
    final bmi = (height != null && height > 0 && weight != null)
        ? weight / ((height / 100) * (height / 100))
        : null;
    final bmiCat = _formBmiCategory(bmi);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 생년월일 | 성별
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _figmaStackField(
                label: '생년월일',
                child: SizedBox(
                  height: _figmaLabeledControlHeight(context),
                  child: TextFormField(
                    key: ValueKey<int>(_wizardBirthFieldKeySeed),
                    initialValue: _birthYyyymmddDisplayForWizardField(),
                    textAlignVertical: TextAlignVertical.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    style: _figmaFieldTextStyle(context),
                    decoration:
                        _figmaInputDecoration(context, hint: 'YYYYMMDD'),
                    onChanged: (v) {
                      final s = v.trim();
                      if (!mounted) return;
                      setState(() {
                        _formData['answer_1'] = s;
                        if (s.length == 8) {
                          _formData['birth_year'] = s.substring(0, 4);
                          _formData['birth_month'] = s.substring(4, 6);
                          _formData['birth_day'] = s.substring(6, 8);
                        } else {
                          _formData['birth_year'] = '';
                          _formData['birth_month'] = '';
                          _formData['birth_day'] = '';
                        }
                      });
                    },
                    validator: (v) {
                      if (v == null || v.length != 8) {
                        return '생년월일 8자리를 입력해주세요';
                      }
                      final y = int.tryParse(v.substring(0, 4));
                      final m = int.tryParse(v.substring(4, 6));
                      final d = int.tryParse(v.substring(6, 8));
                      if (y == null || m == null || d == null) {
                        return '올바른 날짜를 입력해주세요';
                      }
                      try {
                        final dt = DateTime(y, m, d);
                        if (dt.isAfter(DateTime.now())) {
                          return '미래 날짜는 입력할 수 없습니다';
                        }
                      } catch (_) {
                        return '올바른 날짜를 입력해주세요';
                      }
                      return null;
                    },
                    onSaved: (v) {
                      final s = (v ?? '').trim();
                      if (s.length == 8) {
                        _formData['answer_1'] = s;
                        _formData['birth_year'] = s.substring(0, 4);
                        _formData['birth_month'] = s.substring(4, 6);
                        _formData['birth_day'] = s.substring(6, 8);
                      }
                    },
                  ),
                ),
              ),
            ),
            SizedBox(width: healthDp(context, 8)),
            Expanded(
              child: _figmaStackField(
                label: '성별',
                child: FormField<String>(
                  initialValue: _formData['answer_2']?.toString(),
                  validator: (v) {
                    final g =
                        (v ?? _formData['answer_2']?.toString() ?? '').trim();
                    if (g != 'M' && g != 'F') return '성별을 선택해주세요';
                    return null;
                  },
                  onSaved: (_) {},
                  builder: (state) {
                    return Row(
                      children: [
                        Expanded(
                          child: _genderChip(
                            label: '여',
                            selected: _formData['answer_2'] == 'F',
                            onTap: () {
                              setState(() => _formData['answer_2'] = 'F');
                              state.didChange('F');
                            },
                          ),
                        ),
                        SizedBox(width: healthDp(context, 8)),
                        Expanded(
                          child: _genderChip(
                            label: '남',
                            selected: _formData['answer_2'] == 'M',
                            onTap: () {
                              setState(() => _formData['answer_2'] = 'M');
                              state.didChange('M');
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: healthDp(context, 20)),
        // 키
        _figmaStackField(
          label: '키',
          child: _suffixField(
            questionId: 'answer_4',
            hint: '키',
            suffix: 'cm',
            requiredMsg: '키를 입력해주세요',
            allowDecimal: true,
          ),
        ),
        if (bmi != null && bmiCat != null) ...[
          SizedBox(height: healthDp(context, 10)),
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: healthDp(context, 14),
                vertical: healthDp(context, 10),
              ),
              decoration: ShapeDecoration(
                color: const Color(0xFFFAFAFA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 50)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'BMI',
                          style: TextStyle(
                            color: const Color(0xFF898686),
                            fontSize: healthSp(context, 12),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: ' ',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: healthSp(context, 12),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: bmi.toStringAsFixed(1),
                          style: TextStyle(
                            color: const Color(0xFF1A1A1E),
                            fontSize: healthSp(context, 12),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: healthDp(context, 4)),
                  Container(
                    width: healthDp(context, 1),
                    height: healthDp(context, 14),
                    color: const Color(0x7FD2D2D2),
                  ),
                  SizedBox(width: healthDp(context, 4)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 14),
                      vertical: healthDp(context, 4),
                    ),
                    decoration: ShapeDecoration(
                      color: bmiCat.$2,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 50)),
                      ),
                    ),
                    child: Text(
                      bmiCat.$1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: healthSp(context, 11),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        SizedBox(height: healthDp(context, 20)),
        // 현재 체중 | 목표 체중
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _figmaStackField(
                label: '현재 체중',
                labelTrailing: GestureDetector(
                  key: _bmiGuideIconKey,
                  onTap: _toggleBmiGuideOverlay,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.only(left: healthDp(context, 4)),
                    child: SvgPicture.asset(
                      AppAssets.guideIcon,
                      width: healthSp(context, 12),
                      height: healthSp(context, 12),
                    ),
                  ),
                ),
                child: _suffixField(
                  questionId: 'answer_5',
                  hint: '체중',
                  suffix: 'kg',
                  requiredMsg: '현재 체중을 입력해주세요',
                  allowDecimal: true,
                  onAfterChanged: _checkGoalWeightAgainstCurrent,
                ),
              ),
            ),
            SizedBox(width: healthDp(context, 8)),
            Expanded(
              child: _figmaStackField(
                label: '목표 체중',
                child: _suffixField(
                  questionId: 'answer_3',
                  hint: '목표',
                  suffix: 'kg',
                  requiredMsg: '목표 체중을 입력해주세요',
                  allowDecimal: true,
                  forcePinkBorder: _goalWeightInvalid,
                  transientErrorText:
                      _goalWeightHintVisible ? '현재 체중보다 낮게만 입력해주세요' : null,
                  onAfterChanged: _checkGoalWeightAgainstCurrent,
                ),
              ),
            ),
          ],
        ),
        if (remaining != null) ...[
          SizedBox(height: healthDp(context, 10)),
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: healthDp(context, 14),
                vertical: healthDp(context, 10),
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(healthDp(context, 50)),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '목표 체중까지',
                      style: TextStyle(
                        color: const Color(0xFF898686),
                        fontSize: healthSp(context, 12),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextSpan(
                      text: ' - ',
                      style: TextStyle(
                        color: _pfPink,
                        fontSize: healthSp(context, 12),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextSpan(
                      text:
                          '${remaining.abs() == remaining.abs().roundToDouble() ? remaining.abs().toStringAsFixed(0) : remaining.abs().toStringAsFixed(1)} kg ',
                      style: TextStyle(
                        color: _pfPink,
                        fontSize: healthSp(context, 12),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: remaining >= 0 ? '남았어요' : '초과했어요',
                      style: TextStyle(
                        color: const Color(0xFF898686),
                        fontSize: healthSp(context, 12),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
        SizedBox(height: healthDp(context, 20)),
        _figmaStackField(
          label: '다이어트 목표 기간',
          child: _buildAnswer6Dropdown(),
        ),
      ],
    );
  }

  Widget _figmaStackField({
    required String label,
    required Widget child,
    Widget? labelTrailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF898686),
                fontSize: healthSp(context, 12),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
            if (labelTrailing != null) labelTrailing,
          ],
        ),
        SizedBox(height: healthDp(context, 10)),
        child,
      ],
    );
  }

  (String, Color)? _formBmiCategory(double? bmi) {
    if (bmi == null) return null;
    if (bmi < 18.5) return ('저체중', const Color(0xFF60A5FA));
    if (bmi < 23) return ('정상', const Color(0xFF4ADE80));
    if (bmi < 25) return ('과체중', const Color(0xFFFACC15));
    if (bmi < 30) return ('비만', const Color(0xFFFB923C));
    return ('고도비만', const Color(0xFFEF4444));
  }

  TextStyle _figmaFieldTextStyle(BuildContext context) => TextStyle(
        color: const Color(0xFF1A1A1A),
        fontSize: healthSp(context, 14),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w500,
      );

  TextStyle _figmaMultiHintStyle(BuildContext context) => TextStyle(
        color: const Color(0xFF898383),
        fontSize: healthSp(context, 10),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w300,
      );

  InputDecoration _figmaInputDecoration(BuildContext context, {String? hint}) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      hintText: hint,
      hintStyle: TextStyle(
        color: const Color(0xFF898686),
        fontSize: healthSp(context, 14),
        fontFamily: 'Gmarket Sans TTF',
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 14),
        vertical: healthDp(context, 14),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(healthDp(context, 15)),
        borderSide: BorderSide(
          width: healthDp(context, 1),
          color: _pfBorder,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(healthDp(context, 15)),
        borderSide: BorderSide(
          width: healthDp(context, 1),
          color: _pfBorder,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(healthDp(context, 15)),
        borderSide: BorderSide(
          width: healthDp(context, 1),
          color: _pfPink,
        ),
      ),
    );
  }

  Widget _genderChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: _figmaLabeledControlHeight(context),
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: selected ? const Color(0x0CFF5A8D) : Colors.transparent,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: healthDp(context, 1),
              color: selected ? const Color(0xFFFF5A8D) : _pfBorder,
            ),
            borderRadius: BorderRadius.circular(healthDp(context, 15)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF1A1A1E) : const Color(0xFF898383),
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  bool _isGoalWeightTooHigh() {
    final weight = double.tryParse(
      (_formData['answer_5']?.toString() ?? '').replaceAll(',', ''),
    );
    final goal = double.tryParse(
      (_formData['answer_3']?.toString() ?? '').replaceAll(',', ''),
    );
    if (weight == null || goal == null) return false;
    return goal >= weight;
  }

  void _checkGoalWeightAgainstCurrent() {
    final tooHigh = _isGoalWeightTooHigh();
    if (tooHigh) {
      _goalWeightHintTimer?.cancel();
      setState(() {
        _goalWeightInvalid = true;
        _goalWeightHintVisible = true;
      });
      _goalWeightHintTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() => _goalWeightHintVisible = false);
      });
      return;
    }
    _goalWeightHintTimer?.cancel();
    if (_goalWeightInvalid || _goalWeightHintVisible) {
      setState(() {
        _goalWeightInvalid = false;
        _goalWeightHintVisible = false;
      });
    }
  }

  Widget _suffixField({
    required String questionId,
    required String hint,
    required String suffix,
    required String requiredMsg,
    bool allowDecimal = false,
    bool forcePinkBorder = false,
    String? transientErrorText,
    VoidCallback? onAfterChanged,
  }) {
    final pinkBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(healthDp(context, 15)),
      borderSide: BorderSide(
        width: healthDp(context, 1),
        color: _pfPink,
      ),
    );
    return FormField<String>(
      initialValue: (_formData[questionId]?.toString() ?? '').trim(),
      validator: (v) {
        final s = (v ?? '').trim();
        if (s.isEmpty) return requiredMsg;
        if (questionId == 'answer_3' && _isGoalWeightTooHigh()) {
          return '현재 체중보다 낮게만 입력해주세요';
        }
        return null;
      },
      onSaved: (v) => _formData[questionId] = (v ?? '').trim(),
      builder: (state) {
        final showTransient =
            transientErrorText != null && transientErrorText.isNotEmpty;
        final showFormError = state.hasError && !showTransient;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              initialValue: state.value,
              keyboardType: allowDecimal
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.number,
              inputFormatters: [
                if (allowDecimal)
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                else
                  FilteringTextInputFormatter.digitsOnly,
              ],
              style: _figmaFieldTextStyle(context),
              decoration: _figmaInputDecoration(context, hint: hint).copyWith(
                suffixText: suffix,
                suffixStyle: _figmaFieldTextStyle(context),
                errorStyle: const TextStyle(height: 0, fontSize: 0),
                border: forcePinkBorder ? pinkBorder : null,
                enabledBorder: forcePinkBorder ? pinkBorder : null,
                focusedBorder: forcePinkBorder ? pinkBorder : null,
              ),
              onChanged: (v) {
                state.didChange(v);
                if (!mounted) return;
                setState(() {
                  _formData[questionId] = v.trim();
                });
                onAfterChanged?.call();
              },
              validator: (_) => null,
              onSaved: (_) {},
            ),
            if (showTransient || showFormError) ...[
              SizedBox(height: healthDp(context, 4)),
              SizedBox(
                height: healthDp(context, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    showTransient
                        ? transientErrorText
                        : (state.errorText ?? ''),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: forcePinkBorder || showTransient
                          ? _pfPink
                          : Theme.of(context).colorScheme.error,
                      fontSize: healthSp(context, 10),
                      fontFamily: 'Gmarket Sans TTF',
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAnswer6Dropdown() {
    final options = HealthProfileQuestionnaireOptions.dietPeriod;
    final current = _formData['answer_6']?.toString().trim() ?? '';
    final selected =
        current.isEmpty || !options.contains(current) ? null : current;
    return FormField<String>(
      // initialValue는 첫 마운트에만 적용되므로, 값이 바뀔 때마다 필드를 재생성해 표시·검증이 _formData와 일치하게 함
      key: ValueKey<String>('answer6|${selected ?? ''}'),
      initialValue: selected,
      validator: (v) {
        final val = (v ?? _formData['answer_6']?.toString() ?? '').trim();
        if (val.isEmpty) return '기간을 선택해주세요';
        return null;
      },
      onSaved: (v) {
        final s = (v ?? _formData['answer_6']?.toString() ?? '').trim();
        if (s.isNotEmpty) _formData['answer_6'] = s;
      },
      builder: (state) {
        final label = selected ?? '선택';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              key: _answer6FieldKey,
              height: healthDp(context, 50),
              padding: EdgeInsets.symmetric(horizontal: healthDp(context, 14)),
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    width: healthDp(context, 1),
                    color: _pfBorder,
                  ),
                  borderRadius: BorderRadius.circular(healthDp(context, 15)),
                ),
              ),
              alignment: Alignment.center,
              child: InkWell(
                borderRadius: BorderRadius.circular(healthDp(context, 15)),
                onTap: () => _openAnswer6BottomSheet(
                  options: options,
                  onSelected: (v) {
                    if (!mounted) return;
                    setState(() {
                      _formData['answer_6'] = v;
                    });
                    state.didChange(v);
                  },
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected == null
                              ? const Color(0xFF898686)
                              : const Color(0xFF1A1A1E),
                          fontSize: healthSp(context, 14),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Transform.rotate(
                      angle: 4.71, // ~270deg chevron
                      child: Icon(
                        Icons.chevron_right,
                        size: healthDp(context, 18),
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: EdgeInsets.only(
                  top: healthDp(context, 4),
                  left: healthDp(context, 4),
                ),
                child: Text(
                  state.errorText ?? '',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: healthSp(context, 12),
                    fontFamily: 'Gmarket Sans TTF',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _removeAnswer6MenuOverlay() {
    _answer6MenuOverlay?.remove();
    _answer6MenuOverlay = null;
    _answer6MenuScrollController?.dispose();
    _answer6MenuScrollController = null;
  }

  Future<void> _openAnswer6BottomSheet({
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) async {
    _removeAnswer6MenuOverlay();
    final contentW = MobileLayoutWrapper.contentWidthOf(context);
    final current = _formData['answer_6']?.toString().trim() ?? '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(maxWidth: contentW),
      builder: (ctx) {
        return Container(
          width: contentW,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
          ),
          padding: EdgeInsets.fromLTRB(
            healthDp(ctx, 27),
            healthDp(ctx, 12),
            healthDp(ctx, 27),
            healthDp(ctx, 24) + MediaQuery.paddingOf(ctx).bottom,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(healthDp(ctx, 50)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: healthDp(ctx, 45),
                height: healthDp(ctx, 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD2D2D2),
                  borderRadius: BorderRadius.circular(healthDp(ctx, 10)),
                ),
              ),
              SizedBox(height: healthDp(ctx, 16)),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, __) => Divider(
                    height: healthDp(ctx, 1),
                    color: const Color(0x7FD2D2D2),
                  ),
                  itemBuilder: (_, i) {
                    final opt = options[i];
                    final selected = opt == current;
                    return InkWell(
                      onTap: () {
                        onSelected(opt);
                        Navigator.of(ctx).pop();
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: healthDp(ctx, 14),
                        ),
                        child: Text(
                          opt,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected
                                ? const Color(0xFFFF5A8D)
                                : const Color(0xFF1A1A1E),
                            fontSize: healthSp(ctx, 16),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight:
                                selected ? FontWeight.w500 : FontWeight.w300,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ignore: unused_element
  void _openAnswer6Menu({
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    _openAnswer6BottomSheet(options: options, onSelected: onSelected);
  }

  Widget _figmaLabeledRow({
    required String label,
    required Widget field,
    TextAlign labelAlign = TextAlign.left,

    /// 라벨–필드 사이 간격 (375 기준 20)
    bool includeLabelToFieldGap = true,

    /// 라벨을 입력칸 높이 중앙에 맞추기 위한 고정 박스 높이 (ex: 생년월일/성별)
    double? labelBoxHeight,

    /// 라벨 영역 안쪽 여백 (ex: 생년월일만 살짝 오른쪽)
    EdgeInsets? labelPadding,
  }) {
    final labelStyle = TextStyle(
      color: const Color(0xFF1A1A1A),
      fontSize: healthSp(context, 14),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w500,
      height: 1,
    );

    Widget labelChild = labelBoxHeight == null
        ? Text(label, textAlign: labelAlign, style: labelStyle)
        : SizedBox(
            height: labelBoxHeight,
            child: Align(
              alignment: labelAlign == TextAlign.right
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Text(label, textAlign: labelAlign, style: labelStyle),
            ),
          );
    if (labelPadding != null) {
      labelChild = Padding(padding: labelPadding, child: labelChild);
    }

    // 오류 문구로 필드 열 높이가 늘어나도 라벨이 세로 중앙으로 밀리지 않도록 상단 정렬
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: healthDp(context, 72),
          child: labelChild,
        ),
        if (includeLabelToFieldGap) SizedBox(width: healthDp(context, 20)),
        Expanded(child: field),
      ],
    );
  }

  Widget _buildFigmaYesNoChips() {
    final v = _formData['answer_13'];
    final isYes = v == '2' || v == '있음';
    final isNo = v == '1' || v == '없음';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    final oldValue = _formData['answer_13']?.toString();
                    _formData['answer_13'] = '2';
                    final wasNoOrUnset = oldValue == null ||
                        oldValue.isEmpty ||
                        oldValue == '1' ||
                        oldValue == '없음';
                    if (wasNoOrUnset) {
                      _formData['answer_13_medicine'] =
                          _backupAnswer13Fields['answer_13_medicine'] ?? '';
                      _formData['answer_13_period'] =
                          _backupAnswer13Fields['answer_13_period'] ?? '';
                      _formData['answer_13_dosage'] =
                          _backupAnswer13Fields['answer_13_dosage'] ?? '';
                      _formData['answer_13_sideeffect'] =
                          _backupAnswer13Fields['answer_13_sideeffect'] ?? '';
                      _dietDetailResetTick++;
                    }
                  });
                },
                child: Container(
                  height: healthDp(context, 40),
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: isYes ? _pfPinkSoft : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: healthDp(context, 1),
                        color: isYes ? _pfPink : _pfBorder,
                      ),
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 15)),
                    ),
                  ),
                  child: Text(
                    '있음',
                    style: TextStyle(
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: healthDp(context, 10)),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _formData['answer_13'] = '1';
                  });
                },
                child: Container(
                  height: healthDp(context, 40),
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: isNo ? _pfPinkSoft : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: healthDp(context, 1),
                        color: isNo ? _pfPink : _pfBorder,
                      ),
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 15)),
                    ),
                  ),
                  child: Text(
                    '없음',
                    style: TextStyle(
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                      color: isNo
                          ? const Color(0xFF1A1A1A)
                          : const Color(0xFF898383),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_shouldShowQuestion(
          HealthProfileQuestion(
            id: 'answer_13_medicine',
            question: '',
            type: 'text',
            isRequired: false,
          ),
        )) ...[
          SizedBox(height: healthDp(context, 20)),
          _buildDietDrugDetailCard(),
        ],
      ],
    );
  }

  Widget _buildDietDrugDetailCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 14)),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _pfBorder),
          borderRadius: BorderRadius.circular(healthDp(context, 15)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '다이어트약 상세 정보',
                  style: TextStyle(
                    color: const Color(0xFF1A1A1E),
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _formData['answer_13_medicine'] = '';
                      _formData['answer_13_period'] = '';
                      _formData['answer_13_dosage'] = '';
                      _formData['answer_13_sideeffect'] = '';
                      _dietDetailResetTick++;
                    });
                  },
                  borderRadius: BorderRadius.circular(healthDp(context, 50)),
                  child: Container(
                    height: healthDp(context, 28),
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                            width: healthDp(context, 1), color: _pfBorder),
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 50)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh,
                          size: healthDp(context, 14),
                          color: const Color(0xFF898686),
                        ),
                        SizedBox(width: healthDp(context, 2)),
                        Text(
                          '초기화',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF898686),
                            fontSize: healthSp(context, 12),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: healthDp(context, 14)),
          Container(height: healthDp(context, 1), color: _pfBorder),
          SizedBox(height: healthDp(context, 20)),
          _detailRow('복용 약명', 'answer_13_medicine', '약명'),
          SizedBox(height: healthDp(context, 20)),
          _detailRow('복용 기간', 'answer_13_period', '예: 1주'),
          SizedBox(height: healthDp(context, 20)),
          _detailRow('복용 횟수', 'answer_13_dosage', '예: 하루 1-2회'),
          SizedBox(height: healthDp(context, 20)),
          _detailRow('부작용', 'answer_13_sideeffect', '예: 잠이 안와요'),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String id, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF898686),
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: healthDp(context, 10)),
        SizedBox(
          height: healthDp(context, 45),
          child: TextFormField(
            key: ValueKey<String>('diet_$id:$_dietDetailResetTick'),
            initialValue: _formData[id]?.toString() ?? '',
            textAlignVertical: TextAlignVertical.center,
            style: TextStyle(
              color: const Color(0xFF1A1A1E),
              fontSize: healthSp(context, 14),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: const Color(0xFF898686),
                fontSize: healthSp(context, 14),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: EdgeInsets.symmetric(
                horizontal: healthDp(context, 10),
                vertical: 0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 15)),
                borderSide:
                    BorderSide(width: healthDp(context, 1), color: _pfBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 15)),
                borderSide:
                    BorderSide(width: healthDp(context, 1), color: _pfBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 15)),
                borderSide: BorderSide(
                    width: healthDp(context, 1),
                    color: const Color(0xFFFF5A8D)),
              ),
            ),
            onChanged: (v) {
              _formData[id] = v;
              setState(() {});
            },
            onSaved: (v) => _formData[id] = v ?? '',
          ),
        ),
      ],
    );
  }

  Widget _buildFigmaMealtimeTable() {
    final slots = <({String label, String key})>[
      (label: '아침', key: 'meal_1'),
      (label: '점심', key: 'meal_2'),
      (label: '저녁', key: 'meal_3'),
      (label: '기타', key: 'meal_other'),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(healthDp(context, 15)),
        border: Border.all(color: _pfBorder, width: healthDp(context, 1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < slots.length; i++) ...[
              if (i > 0)
                Container(width: healthDp(context, 1), color: _pfBorder),
              Expanded(
                child: _mealTimeSlotRow(
                  label: slots[i].label,
                  fieldKey: slots[i].key,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mealTimeSlotRow({
    required String label,
    required String fieldKey,
  }) {
    final raw = (_formData[fieldKey]?.toString() ?? '').trim();
    final display = raw.isEmpty ? '-' : raw;
    final empty = raw.isEmpty || raw == '-';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showMealTimePickerBottomSheet(fieldKey),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 6),
            vertical: healthDp(context, 14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF898686),
                  fontSize: healthSp(context, 12),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: healthDp(context, 4)),
              Text(
                display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      empty ? const Color(0xFF898686) : const Color(0xFF1A1A1E),
                  fontSize: healthSp(context, 14),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMealTimePickerBottomSheet(String fieldKey) async {
    final raw = (_formData[fieldKey]?.toString() ?? '').trim();
    var hour = 12;
    var minute = 0;
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw);
    if (m != null) {
      hour = (int.tryParse(m.group(1)!) ?? 12).clamp(0, 23);
      minute = (int.tryParse(m.group(2)!) ?? 0).clamp(0, 59);
    }

    final contentW = MobileLayoutWrapper.contentWidthOf(context);
    final hourCtrl = FixedExtentScrollController(initialItem: hour);
    final minuteCtrl = FixedExtentScrollController(initialItem: minute);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(maxWidth: contentW),
      builder: (ctx) {
        var selH = hour;
        var selM = minute;
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Container(
              width: contentW,
              padding: EdgeInsets.fromLTRB(
                healthDp(ctx, 30),
                healthDp(ctx, 20),
                healthDp(ctx, 30),
                healthDp(ctx, 20) + MediaQuery.paddingOf(ctx).bottom,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(healthDp(ctx, 50)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: healthDp(ctx, 45),
                    height: healthDp(ctx, 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD2D2D2),
                      borderRadius: BorderRadius.circular(healthDp(ctx, 10)),
                    ),
                  ),
                  SizedBox(height: healthDp(ctx, 20)),
                  SizedBox(
                    height: healthDp(ctx, 180),
                    child: Row(
                      children: [
                        Expanded(
                          child: ListWheelScrollView.useDelegate(
                            controller: hourCtrl,
                            itemExtent: healthDp(ctx, 40),
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (i) {
                              setModal(() => selH = i);
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 24,
                              builder: (_, i) => Center(
                                child: Text(
                                  i.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    color: i == selH
                                        ? const Color(0xFF1A1A1A)
                                        : const Color(0xFF898686),
                                    fontSize: healthSp(
                                      ctx,
                                      i == selH ? 22 : 16,
                                    ),
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: i == selH
                                        ? FontWeight.w500
                                        : FontWeight.w300,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: healthDp(ctx, 4),
                          ),
                          child: Text(
                            ':',
                            style: TextStyle(
                              fontSize: healthSp(ctx, 22),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListWheelScrollView.useDelegate(
                            controller: minuteCtrl,
                            itemExtent: healthDp(ctx, 40),
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (i) {
                              setModal(() => selM = i);
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 60,
                              builder: (_, i) => Center(
                                child: Text(
                                  i.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    color: i == selM
                                        ? const Color(0xFF1A1A1A)
                                        : const Color(0xFF898686),
                                    fontSize: healthSp(
                                      ctx,
                                      i == selM ? 22 : 16,
                                    ),
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: i == selM
                                        ? FontWeight.w500
                                        : FontWeight.w300,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: healthDp(ctx, 16)),
                  SizedBox(
                    width: double.infinity,
                    height: healthDp(ctx, 45),
                    child: FilledButton(
                      onPressed: () {
                        final value =
                            '${selH.toString().padLeft(2, '0')}:${selM.toString().padLeft(2, '0')}';
                        Navigator.of(ctx).pop();
                        if (!mounted) return;
                        setState(() => _formData[fieldKey] = value);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5A8D),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(healthDp(ctx, 10)),
                        ),
                      ),
                      child: Text(
                        '등록',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: healthSp(ctx, 16),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    hourCtrl.dispose();
    minuteCtrl.dispose();
  }

  String _canonicalHealthNoneGridOption(String questionId, String opt) {
    if (questionId != 'answer_8' &&
        questionId != 'answer_9' &&
        questionId != 'answer_11' &&
        questionId != 'answer_12') {
      return opt;
    }
    final o = (questionId == 'answer_8' || questionId == 'answer_9')
        ? _normalizeChipOptionLabel(opt)
        : opt.trim();
    if (o == '해당없음' || o == '없음' || o == '해당 없음') {
      if (questionId == 'answer_8' || questionId == 'answer_11') {
        return '해당없음';
      }
      return '해당 없음';
    }
    return o;
  }

  Widget _buildFigmaGrid(HealthProfileQuestion question) {
    final options = question.options ?? [];
    final isMulti = question.allowMultiple;
    List<String> selected = [];
    final raw = _formData[question.id];
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
          .map((e) => _canonicalHealthNoneGridOption(question.id, e))
          .toList();
    }

    bool cellSelected(String label) {
      final c = _canonicalHealthNoneGridOption(question.id, label);
      if (isMulti) {
        return selected
            .map((e) => _canonicalHealthNoneGridOption(question.id, e))
            .contains(c);
      }
      return selected.isNotEmpty &&
          _canonicalHealthNoneGridOption(question.id, selected.first) == c;
    }

    void toggle(String opt) {
      setState(() {
        final optC = _canonicalHealthNoneGridOption(question.id, opt);
        if (question.id == 'answer_8') {
          if (optC == '해당없음') {
            _formData[question.id] = isMulti ? <String>['해당없음'] : '해당없음';
            return;
          }
          if (isMulti) {
            final list = selected
                .map((e) => _canonicalHealthNoneGridOption(question.id, e))
                .toList();
            list.remove('해당없음');
            list.remove('해당 없음');
            if (list.contains(optC)) {
              list.remove(optC);
            } else {
              list.add(optC);
            }
            _formData[question.id] = list;
            return;
          }
        }
        if (question.id == 'answer_11' || question.id == 'answer_12') {
          final noneLabel = question.id == 'answer_11' ? '해당없음' : '해당 없음';
          if (optC == noneLabel || optC == '해당 없음' || optC == '해당없음') {
            _formData[question.id] = isMulti ? <String>[noneLabel] : noneLabel;
            if (question.id == 'answer_12') {
              _clearMedicationOthers();
            }
            return;
          }
          if (isMulti) {
            final list = selected
                .map((e) => _canonicalHealthNoneGridOption(question.id, e))
                .toList();
            list.remove('해당 없음');
            list.remove('해당없음');
            if (list.contains(optC)) {
              list.remove(optC);
              if (question.id == 'answer_12' && optC == '기타') {
                _clearMedicationOthers();
              }
            } else {
              list.add(optC);
              if (question.id == 'answer_12' && optC == '기타') {
                _medicationOtherDraftOpen = _medicationOthers.isEmpty;
                if (_medicationOtherDraftOpen) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _medicationOtherDraftFocus.requestFocus();
                  });
                }
              }
            }
            _formData[question.id] = list;
            return;
          }
        }
        if (question.id == 'answer_10_types' && isMulti) {
          final list = List<String>.from(selected);
          if (list.contains(opt)) {
            list.remove(opt);
            if (opt == '기타') _clearExerciseOthers();
          } else {
            list.add(opt);
            if (opt == '기타') {
              _exerciseOtherDraftOpen = _exerciseOthers.isEmpty;
              if (_exerciseOtherDraftOpen) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _exerciseOtherDraftFocus.requestFocus();
                });
              }
            }
          }
          _formData[question.id] = list;
          return;
        }
        if (isMulti) {
          final list = List<String>.from(selected);
          if (list.contains(opt)) {
            list.remove(opt);
          } else {
            list.add(opt);
          }
          _formData[question.id] = list;
        } else {
          _formData[question.id] = opt;
        }
      });
    }

    var gridOptions = List<String>.from(options);
    String? fullWidthNoneLabel;
    for (final candidate in const ['해당 없음', '해당없음', '없음']) {
      final hit = gridOptions.firstWhere(
        (e) => e.trim() == candidate,
        orElse: () => '',
      );
      if (hit.isNotEmpty) {
        fullWidthNoneLabel = hit;
        gridOptions.remove(hit);
        break;
      }
    }

    Widget pairedChipRows() {
      final rows = <Widget>[];
      for (var i = 0; i < gridOptions.length; i += 2) {
        if (i > 0) rows.add(SizedBox(height: healthDp(context, 8)));
        final left = gridOptions[i];
        final hasRight = i + 1 < gridOptions.length;
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: _figmaOptionCell(
                  left,
                  cellSelected(left),
                  () => toggle(left),
                  stretchWidth: true,
                ),
              ),
              if (hasRight) ...[
                SizedBox(width: healthDp(context, 6)),
                Flexible(
                  child: _figmaOptionCell(
                    gridOptions[i + 1],
                    cellSelected(gridOptions[i + 1]),
                    () => toggle(gridOptions[i + 1]),
                    stretchWidth: true,
                  ),
                ),
              ],
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      );
    }

    List<List<String>>? presetRows;
    if (question.id == 'answer_9') {
      presetRows = HealthProfileQuestionnaireOptions.foodPreferenceRows;
    } else if (question.id == 'answer_10') {
      presetRows = HealthProfileQuestionnaireOptions.exerciseFrequencyRows;
    } else if (question.id == 'answer_10_types') {
      presetRows = HealthProfileQuestionnaireOptions.exerciseTypeRows;
    } else if (question.id == 'answer_11') {
      presetRows = HealthProfileQuestionnaireOptions.diseaseRows;
    } else if (question.id == 'answer_12') {
      presetRows = HealthProfileQuestionnaireOptions.medicationRows;
    }

    // 피그마처럼 칩은 내용 너비. Row로 한 줄 유지(Wrap이면 긴 칩이 아래로 떨어짐).
    Widget buildPresetChipRows(List<List<String>> rows) {
      final available = gridOptions.toSet();
      final widgets = <Widget>[];
      for (final row in rows) {
        final opts = row.where(available.contains).toList();
        if (opts.isEmpty) continue;
        if (widgets.isNotEmpty) {
          widgets.add(SizedBox(height: healthDp(context, 8)));
        }
        widgets.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < opts.length; i++) ...[
                if (i > 0) SizedBox(width: healthDp(context, 8)),
                _figmaOptionCell(
                  opts[i],
                  cellSelected(opts[i]),
                  () => toggle(opts[i]),
                ),
              ],
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (question.id == 'answer_7')
          Row(
            children: [
              for (var i = 0; i < gridOptions.length; i++) ...[
                if (i > 0) SizedBox(width: healthDp(context, 8)),
                Expanded(
                  child: _figmaOptionCell(
                    gridOptions[i],
                    cellSelected(gridOptions[i]),
                    () => toggle(gridOptions[i]),
                    stretchWidth: true,
                  ),
                ),
              ],
            ],
          )
        else if (question.id == 'answer_8')
          pairedChipRows()
        else if (presetRows != null)
          buildPresetChipRows(presetRows)
        else
          Wrap(
            spacing: healthDp(context, 8),
            runSpacing: healthDp(context, 8),
            children: [
              for (final opt in gridOptions)
                _figmaOptionCell(
                  opt,
                  cellSelected(opt),
                  () => toggle(opt),
                ),
            ],
          ),
        if (fullWidthNoneLabel != null) ...[
          SizedBox(height: healthDp(context, 8)),
          _figmaOptionCell(
            fullWidthNoneLabel,
            cellSelected(fullWidthNoneLabel),
            () => toggle(fullWidthNoneLabel!),
            stretchWidth: true,
          ),
        ],
        if (question.id == 'answer_10_types' && _isExerciseOtherSelected()) ...[
          SizedBox(height: healthDp(context, 10)),
          _buildOtherExerciseCard(),
        ],
      ],
    );
  }

  Widget _buildOtherExerciseCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 14)),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _pfBorder),
          borderRadius: BorderRadius.circular(healthDp(context, 15)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '기타 운동',
                  style: TextStyle(
                    color: const Color(0xFF1A1A1E),
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openExerciseOtherDraft,
                  borderRadius: BorderRadius.circular(healthDp(context, 50)),
                  child: Container(
                    height: healthDp(context, 28),
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 10),
                    ),
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                            width: healthDp(context, 1), color: _pfBorder),
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 50)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          size: healthDp(context, 14),
                          color: const Color(0xFF898686),
                        ),
                        SizedBox(width: healthDp(context, 2)),
                        Text(
                          '추가',
                          style: TextStyle(
                            color: const Color(0xFF898686),
                            fontSize: healthSp(context, 12),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: healthDp(context, 14)),
          Container(height: healthDp(context, 1), color: _pfBorder),
          SizedBox(height: healthDp(context, 20)),
          if (_exerciseOthers.isNotEmpty)
            Wrap(
              spacing: healthDp(context, 8),
              runSpacing: healthDp(context, 8),
              children: [
                for (var i = 0; i < _exerciseOthers.length; i++)
                  _buildExerciseOtherChip(_exerciseOthers[i], i),
              ],
            ),
          if (_exerciseOtherDraftOpen || _exerciseOthers.isEmpty) ...[
            if (_exerciseOthers.isNotEmpty)
              SizedBox(height: healthDp(context, 8)),
            _buildExerciseOtherDraftField(),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseOtherChip(String label, int index) {
    return Container(
      height: healthDp(context, 45),
      padding: EdgeInsets.only(
        left: healthDp(context, 14),
        right: healthDp(context, 8),
      ),
      decoration: ShapeDecoration(
        color: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _pfBorder),
          borderRadius: BorderRadius.circular(healthDp(context, 50)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF1A1A1E),
              fontSize: healthSp(context, 14),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: healthDp(context, 4)),
          GestureDetector(
            onTap: () => _removeExerciseOtherAt(index),
            behavior: HitTestBehavior.opaque,
            child: Icon(
              Icons.close,
              size: healthSp(context, 16),
              color: const Color(0xFF898686),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseOtherDraftField() {
    return SizedBox(
      width: double.infinity,
      height: healthDp(context, 45),
      child: TextField(
        controller: _exerciseOtherDraftCtrl,
        focusNode: _exerciseOtherDraftFocus,
        textInputAction: TextInputAction.done,
        textAlignVertical: TextAlignVertical.center,
        onSubmitted: (_) => _commitExerciseOtherDraft(),
        onChanged: (_) => setState(() {}),
        style: TextStyle(
          color: const Color(0xFF1A1A1E),
          fontSize: healthSp(context, 14),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: '운동을 입력해주세요',
          hintStyle: TextStyle(
            color: const Color(0xFF898686),
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 14),
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 50)),
            borderSide:
                BorderSide(width: healthDp(context, 1), color: _pfBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 50)),
            borderSide:
                BorderSide(width: healthDp(context, 1), color: _pfBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 50)),
            borderSide: BorderSide(
                width: healthDp(context, 1), color: const Color(0xFFFF5A8D)),
          ),
        ),
      ),
    );
  }

  int _chipCharCount(String label) =>
      label.replaceAll(RegExp(r'\s'), '').replaceAll('\n', '').length;

  /// 3글자 이하(한식·해산물·유제품 등)는 피그마처럼 71 고정.
  bool _isFixedShortChip(String label) => _chipCharCount(label) <= 3;

  /// 4글자(호흡계통 등)는 82 고정.
  bool _isFixedFourChip(String label) => _chipCharCount(label) == 4;

  Widget _figmaOptionCell(
    String label,
    bool selected,
    VoidCallback onTap, {
    bool stretchWidth = false,
  }) {
    final display = _normalizeChipOptionLabel(label);
    final isSaladDiet = display == '샐러드/다이어트식단';
    final isLateNight = display.contains('야식');
    final isCaffeine = display.contains('카페인');
    final chars = _chipCharCount(display);
    final fixedShort =
        !stretchWidth && !isSaladDiet && _isFixedShortChip(display);
    final fixedFour =
        !stretchWidth && !isSaladDiet && _isFixedFourChip(display);
    final fixedWidth = fixedShort || fixedFour;
    // 야식 패딩 더 축소, 카페인은 조금 더 여유
    final hPad = healthDp(
      context,
      isSaladDiet
          ? 14
          : (fixedWidth
              ? 6
              : (isLateNight
                  ? 2
                  : (isCaffeine
                      ? 6
                      : (stretchWidth
                          ? 4
                          : (chars == 5 ? 14 : (chars < 5 ? 6 : 14)))))),
    );

    final text = Text(
      display,
      textAlign: TextAlign.center,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        color: selected ? const Color(0xFF1A1A1E) : const Color(0xFF898383),
        fontSize: healthSp(context, 14),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w500,
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: stretchWidth
            ? double.infinity
            : (fixedShort
                ? healthDp(context, 71)
                : (fixedFour ? healthDp(context, 82) : null)),
        height: healthDp(context, 45),
        padding: EdgeInsets.symmetric(horizontal: hPad),
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: selected ? const Color(0x0CFF5A8D) : Colors.transparent,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: healthDp(context, 1),
              color: selected ? const Color(0xFFFF5A8D) : _pfBorder,
            ),
            borderRadius: BorderRadius.circular(
              healthDp(context, selected ? 36 : 50),
            ),
          ),
        ),
        // FittedBox는 부모를 꽉 채우므로 샐러드(내용 너비)에는 쓰지 않음
        child: stretchWidth || fixedWidth
            ? FittedBox(fit: BoxFit.scaleDown, child: text)
            : text,
      ),
    );
  }

  Widget _buildFigmaLabeledField(HealthProfileQuestion question) {
    return _buildInputWidget(question);
  }

  // 단일 섹션 수정 모드 — 전체 마법사와 동일한 Figma UI
  Widget _buildSingleSectionMode() {
    if (_currentPage >= _sections.length) {
      return const Center(child: Text('섹션을 찾을 수 없습니다'));
    }

    final section = _sections[_currentPage];

    return ColoredBox(
      color: Colors.white,
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: _buildWizardStepScrollable(section, _currentPage),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  healthDp(context, 27),
                  healthDp(context, 4),
                  healthDp(context, 27),
                  healthDp(context, 20),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: healthDp(context, 40),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3787),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      minimumSize: Size(double.infinity, healthDp(context, 40)),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 10)),
                      ),
                    ),
                    child: Text(
                      '수정하기',
                      style: TextStyle(
                        fontSize: healthSp(context, 16),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF3787)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionPage(HealthProfileSection section) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(healthDp(context, 27), healthDp(context, 16),
          healthDp(context, 27), healthDp(context, 20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...section.questions
              .where((question) => _shouldShowQuestion(question))
              .map((question) => _buildQuestionWidget(question)),
        ],
      ),
    );
  }

  bool _shouldShowQuestion(HealthProfileQuestion question) {
    // 다이어트약 관련 필드들은 answer_13이 "있음" 또는 "2"일 때만 표시
    if (question.id.startsWith('answer_13') && question.id != 'answer_13') {
      final answer13 = _formData['answer_13'];
      return answer13 == '있음' || answer13 == '2';
    }
    // 복용중인 약 "기타" 입력 필드
    if (question.id == 'answer_12_other') {
      final answer12 = _formData['answer_12'];
      if (answer12 is List) {
        return answer12.contains('기타');
      }
      return answer12 == '기타';
    }
    return true;
  }

  Widget _buildQuestionWidget(HealthProfileQuestion question) {
    final showBlockTitle = question.type != 'wizard_basic';

    return Container(
      margin: EdgeInsets.only(bottom: healthDp(context, 24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBlockTitle) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    question.question,
                    style: TextStyle(
                      fontSize: healthSp(context, 18),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (question.allowMultiple == true)
                  Padding(
                    padding: EdgeInsets.only(left: healthDp(context, 4)),
                    child: Text(
                      '*중복 선택 가능',
                      style: TextStyle(
                        fontSize: healthSp(context, 11),
                        fontFamily: 'Gmarket Sans TTF',
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
              ],
            ),
            if (question.hint != null) ...[
              SizedBox(height: healthDp(context, 4)),
              Text(
                question.hint!,
                style: TextStyle(
                  fontSize: healthSp(context, 14),
                  fontFamily: 'Gmarket Sans TTF',
                  color: Colors.grey[600],
                ),
              ),
            ],
            SizedBox(height: healthDp(context, 12)),
          ],
          _buildInputWidget(question),
        ],
      ),
    );
  }

  Widget _buildInputWidget(HealthProfileQuestion question) {
    switch (question.type) {
      case 'wizard_basic':
        return _buildFigmaBirthAndGender();
      case 'birthdate':
        return _buildBirthdateInput();

      case 'mealtime':
        return _buildMealtimeInput();

      case 'text':
        return TextFormField(
          initialValue: _formData[question.id] ?? '',
          decoration: InputDecoration(
            hintText: question.placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(healthDp(context, 8)),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 16),
              vertical: healthDp(context, 12),
            ),
          ),
          validator: question.isRequired
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return '${question.question}을(를) 입력해주세요';
                  }
                  return null;
                }
              : null,
          onSaved: (value) {
            final savedValue = value ?? '';
            _formData[question.id] = savedValue;

            // 다이어트 경험 관련 필드 입력 시 백업 업데이트
            if (question.id.startsWith('answer_13') &&
                question.id != 'answer_13') {
              _backupAnswer13Fields[question.id] = savedValue;
            }
          },
        );

      case 'number':
        return TextFormField(
          initialValue: _formData[question.id] ?? '',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: question.placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(healthDp(context, 8)),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 16),
              vertical: healthDp(context, 12),
            ),
          ),
          validator: question.isRequired
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return '${question.question}을(를) 입력해주세요';
                  }
                  return null;
                }
              : null,
          onSaved: (value) {
            final savedValue = value ?? '';
            _formData[question.id] = savedValue;

            // 다이어트 경험 관련 필드 입력 시 백업 업데이트
            if (question.id.startsWith('answer_13') &&
                question.id != 'answer_13') {
              _backupAnswer13Fields[question.id] = savedValue;
            }
          },
        );

      case 'radio':
        if (question.id == 'answer_13') {
          return _buildFigmaYesNoChips();
        }
        return Column(
          children: question.options!.map((option) {
            // 성별 변환 (M/F -> 남/여)
            // 다이어트 약 변환 (1 -> 없음, 2 -> 있음)
            String? groupValue = _formData[question.id];
            if (question.id == 'answer_2') {
              if (groupValue == 'M') groupValue = '남';
              if (groupValue == 'F') groupValue = '여';
            } else if (question.id == 'answer_13') {
              if (groupValue == '1') groupValue = '없음';
              if (groupValue == '2') groupValue = '있음';
            }

            return RadioListTile<String>(
              title: Text(option),
              value: option,
              groupValue: groupValue,
              onChanged: (value) {
                setState(() {
                  // 성별 저장 시 M/F로 변환
                  if (question.id == 'answer_2') {
                    _formData[question.id] =
                        value == '남' ? 'M' : (value == '여' ? 'F' : value ?? '');
                  } else if (question.id == 'answer_13') {
                    // 다이어트 약 저장 시 1/2로 변환 (없음=1, 있음=2)
                    final newValue = value == '없음'
                        ? '1'
                        : (value == '있음' ? '2' : value ?? '');
                    final oldValue = _formData[question.id]?.toString();
                    _formData[question.id] = newValue;

                    if (value == '없음') {
                      // answer_13만 1(없음)으로 저장하고 상세 필드는 유지한다.
                    } else if (value == '있음') {
                      final wasNoOrUnset = oldValue == null ||
                          oldValue.isEmpty ||
                          oldValue == '1' ||
                          oldValue == '없음';
                      if (wasNoOrUnset) {
                        _formData['answer_13_medicine'] =
                            _backupAnswer13Fields['answer_13_medicine'] ?? '';
                        _formData['answer_13_period'] =
                            _backupAnswer13Fields['answer_13_period'] ?? '';
                        _formData['answer_13_dosage'] =
                            _backupAnswer13Fields['answer_13_dosage'] ?? '';
                        _formData['answer_13_sideeffect'] =
                            _backupAnswer13Fields['answer_13_sideeffect'] ?? '';
                        _dietDetailResetTick++;
                      }
                    }

                    // UI 업데이트를 위해 강제 리빌드
                    Future.microtask(() {
                      if (mounted) {
                        setState(() {});
                      }
                    });
                  } else {
                    _formData[question.id] = value;
                  }
                });
              },
            );
          }).toList(),
        );

      case 'grid':
        return _buildFigmaGrid(question);

      default:
        return const SizedBox();
    }
  }

  Widget _buildGridWidget(HealthProfileQuestion question) {
    final columns = question.columns ?? 2;
    final options = question.options ?? [];
    final selectedValues = _formData[question.id] is List
        ? List<String>.from(_formData[question.id])
        : (_formData[question.id] != null ? [_formData[question.id]] : [])
            .cast<String>();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: healthDp(context, 8),
        mainAxisSpacing: healthDp(context, 8),
        childAspectRatio: 2.5,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        final isSelected = question.allowMultiple
            ? selectedValues.contains(option)
            : _formData[question.id] == option;

        return GestureDetector(
          onTap: () {
            setState(() {
              if (question.allowMultiple) {
                final currentList = List<String>.from(selectedValues);
                if (currentList.contains(option)) {
                  currentList.remove(option);
                  // "기타" 선택 해제 시 입력 필드 초기화
                  if (question.id == 'answer_12' && option == '기타') {
                    _clearMedicationOthers();
                  }
                } else {
                  currentList.add(option);
                }
                _formData[question.id] = currentList;
              } else {
                _formData[question.id] = option;
              }
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFFE5EE) : Colors.white,
              border: Border.all(
                color:
                    isSelected ? const Color(0xFFFF3787) : Colors.grey.shade300,
                width: healthDp(context, isSelected ? 2 : 1),
              ),
              borderRadius: BorderRadius.circular(healthDp(context, 8)),
            ),
            child: Center(
              child: Text(
                option,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFFF3787) : Colors.black87,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: healthSp(context, 14),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }

  void _selectDate(String questionId) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (!mounted) return;
    if (picked != null) {
      setState(() {
        _formData[questionId] =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _nextPage() {
    if (!_isWizardStepFilled(_currentPage)) {
      AppToastOverlay.show(context, '모든 문진표를 작성해야합니다');
      _formKey.currentState?.validate();
      return;
    }
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _submitForm() async {
    if (!_isAllWizardStepsFilled()) {
      AppToastOverlay.show(context, '모든 문진표를 작성해야합니다');
      _formKey.currentState?.validate();
      return;
    }
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      setState(() {
        _isLoading = true;
      });

      try {
        await _saveHealthProfile();

        if (!mounted) return;

        final booking = widget.prescriptionBooking;
        if (booking != null) {
          final profile = await HealthProfileService.getHealthProfile(
            _currentUser!.id,
          );
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (context) => PrescriptionTimeScreen(
                productId: booking.productId,
                productName: booking.productName,
                selectedOptions: booking.selectedOptions,
                formData: profile != null
                    ? HealthProfilePayload.formDataFromProfile(profile)
                    : Map<String, dynamic>.from(_formData),
                existingProfile: profile,
                cartCtIdsForCheckout: booking.cartCtIdsForCheckout,
                checkoutCartItems: booking.checkoutCartItems,
                checkoutShippingCost: booking.checkoutShippingCost,
              ),
            ),
          );
          return;
        }

        AppToastOverlay.show(context, '문진표 수정 완료하였습니다');
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/profile',
            (route) => false,
          );
        }
      } catch (e) {
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  /// 운동 빈도(`answer_10`) + 주로 하는 운동(`answer_10_2`) — DB 컬럼 분리 저장
  String _composeAnswer10Frequency() {
    return HealthProfilePayload.composeAnswer10FrequencyOnly(
      (_formData['answer_10'] ?? '').toString(),
    );
  }

  String _composeAnswer10Types() {
    final raw = _formData['answer_10_types'];
    final list = <String>[];
    if (raw is List) {
      for (final e in raw) {
        final s = e.toString().trim();
        if (s.isEmpty || s == '기타') continue;
        list.add(s);
      }
    }
    for (final o in _exerciseOthers) {
      final t = o.trim();
      if (t.isNotEmpty && !list.contains(t)) list.add(t);
    }
    final draft = _exerciseOtherDraftCtrl.text.trim();
    if (draft.isNotEmpty && !list.contains(draft)) list.add(draft);
    return list.join('|');
  }

  Future<void> _saveHealthProfile() async {
    // 생년월일 합치기 (YYYYMMDD 형식)
    final birthYear = _formData['birth_year'] ?? '';
    final birthMonth = _formData['birth_month'] ?? '';
    final birthDay = _formData['birth_day'] ?? '';
    final birthDate =
        birthYear.length == 4 && birthMonth.length == 2 && birthDay.length == 2
            ? '$birthYear$birthMonth$birthDay'
            : _formData['answer_1'] ?? '';

    // 식사시간 합치기 (| 기준으로 연결)
    final meal1 = _formData['meal_1'] ?? '';
    final meal2 = _formData['meal_2'] ?? '';
    final meal3 = _formData['meal_3'] ?? '';
    final mealOther = _formData['meal_other'] ?? '';
    final mealtime = '$meal1|$meal2|$meal3|$mealOther';

    final profile = HealthProfileModel(
      pfNo: _existingProfile?.pfNo, // 기존 프로필의 번호 포함
      mbId: _currentUser!.id,
      answer1: birthDate,
      answer2: _formData['answer_2'] ?? '',
      answer3: _formData['answer_3'] ?? '',
      answer4: _formData['answer_4'] ?? '',
      answer5: _formData['answer_5'] ?? '',
      answer6: _formData['answer_6'] ?? '',
      answer7: _formData['answer_7'] ?? '',
      answer8: HealthProfilePayload.formatListToString(_formData['answer_8']),
      answer9: HealthProfilePayload.formatListToString(_formData['answer_9']),
      answer10: _composeAnswer10Frequency(),
      answer102: _composeAnswer10Types(),
      answer11: HealthProfilePayload.formatListToString(_formData['answer_11']),
      answer12: HealthProfilePayload.formatAnswer12(
        _formData['answer_12'],
        null,
        otherValues: [
          ..._medicationOthers,
          if (_medicationOtherDraftCtrl.text.trim().isNotEmpty)
            _medicationOtherDraftCtrl.text.trim(),
        ],
      ),
      answer13: HealthProfilePayload.encodeAnswer13ForApi(
        _formData['answer_13']?.toString(),
      ),
      answer13Period: _formData['answer_13_period'] ?? '',
      answer13Dosage: _formData['answer_13_dosage'] ?? '',
      answer13Medicine: _formData['answer_13_medicine'] ?? '',
      answer71: mealtime,
      answer13Sideeffect: _formData['answer_13_sideeffect'] ?? '',
      pfWdatetime: _existingProfile?.pfWdatetime ?? DateTime.now(),
      pfMdatetime: DateTime.now(),
      pfIp: '', // 서버에서 처리
      pfMemo: '',
    );

    if (_existingProfile != null && _existingProfile!.pfNo != null) {
      // 수정
      await HealthProfileService.updateHealthProfile(profile);
    } else {
      // 새로 생성
      await HealthProfileService.saveHealthProfile(profile);
    }
  }

  /// 생년월일 입력 위젯 (년/월/일 3칸)
  Widget _buildBirthdateInput() {
    final y = _formData['birth_year']?.toString() ?? '';
    final m = _formData['birth_month']?.toString() ?? '';
    final d = _formData['birth_day']?.toString() ?? '';
    return Column(
      key: ValueKey<String>('birth3|$y|$m|$d'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: y,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: InputDecoration(
                  labelText: '년',
                  hintText: '1990',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 8)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 16),
                    vertical: healthDp(context, 12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '년을 입력해주세요';
                  }
                  if (value.length != 4) {
                    return '4자리 숫자를 입력해주세요';
                  }
                  final year = int.tryParse(value);
                  if (year == null) {
                    return '올바른 숫자를 입력해주세요';
                  }
                  if (year < 1900 || year > DateTime.now().year) {
                    return '1900년부터 ${DateTime.now().year}년까지 입력 가능합니다';
                  }
                  return null;
                },
                onSaved: (value) {
                  _formData['birth_year'] = value ?? '';
                },
              ),
            ),
            SizedBox(width: healthDp(context, 8)),
            Expanded(
              child: TextFormField(
                initialValue: m,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: InputDecoration(
                  labelText: '월',
                  hintText: '01',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 8)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 16),
                    vertical: healthDp(context, 12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '월을 입력해주세요';
                  }
                  final month = int.tryParse(value);
                  if (month == null || month < 1 || month > 12) {
                    return '1월부터 12월까지 입력 가능합니다';
                  }
                  return null;
                },
                onSaved: (value) {
                  _formData['birth_month'] = (value ?? '').padLeft(2, '0');
                },
              ),
            ),
            SizedBox(width: healthDp(context, 8)),
            Expanded(
              child: TextFormField(
                initialValue: d,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: InputDecoration(
                  labelText: '일',
                  hintText: '01',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 8)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 16),
                    vertical: healthDp(context, 12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '일을 입력해주세요';
                  }
                  final day = int.tryParse(value);
                  if (day == null || day < 1 || day > 31) {
                    return '1일부터 31일까지 입력 가능합니다';
                  }
                  // 년/월 정보로 실제 날짜 유효성 검증
                  final year = int.tryParse(_formData['birth_year'] ?? '');
                  final month = int.tryParse(_formData['birth_month'] ?? '');
                  if (year != null && month != null) {
                    try {
                      final date = DateTime(year, month, day);
                      if (date.year != year ||
                          date.month != month ||
                          date.day != day) {
                        return '올바른 날짜를 입력해주세요';
                      }
                      if (date.isAfter(DateTime.now())) {
                        return '미래 날짜는 입력할 수 없습니다';
                      }
                    } catch (e) {
                      return '올바른 날짜를 입력해주세요';
                    }
                  }
                  return null;
                },
                onSaved: (value) {
                  _formData['birth_day'] = (value ?? '').padLeft(2, '0');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 식사시간 입력 위젯 (1식, 2식, 3식, 기타 4칸 한 줄)
  Widget _buildMealtimeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1식',
                    style: TextStyle(
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 4)),
                  TextFormField(
                    initialValue: _formData['meal_1'] ?? '',
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '예: 08:00',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 8)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 16),
                        vertical: healthDp(context, 12),
                      ),
                    ),
                    onSaved: (value) {
                      _formData['meal_1'] = value ?? '';
                    },
                  ),
                ],
              ),
            ),
            SizedBox(width: healthDp(context, 8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2식',
                    style: TextStyle(
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 4)),
                  TextFormField(
                    initialValue: _formData['meal_2'] ?? '',
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '예: 12:00',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 8)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 16),
                        vertical: healthDp(context, 12),
                      ),
                    ),
                    onSaved: (value) {
                      _formData['meal_2'] = value ?? '';
                    },
                  ),
                ],
              ),
            ),
            SizedBox(width: healthDp(context, 8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '3식',
                    style: TextStyle(
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 4)),
                  TextFormField(
                    initialValue: _formData['meal_3'] ?? '',
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '예: 19:00',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 8)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 16),
                        vertical: healthDp(context, 12),
                      ),
                    ),
                    onSaved: (value) {
                      _formData['meal_3'] = value ?? '';
                    },
                  ),
                ],
              ),
            ),
            SizedBox(width: healthDp(context, 8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '4식',
                    style: TextStyle(
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 4)),
                  TextFormField(
                    initialValue: _formData['meal_other'] ?? '',
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '예: 21:00',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 8)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 16),
                        vertical: healthDp(context, 12),
                      ),
                    ),
                    onSaved: (value) {
                      _formData['meal_other'] = value ?? '';
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: healthDp(context, 8)),
        Text(
          '*해당되는 입력란에만 입력하세요.',
          style: TextStyle(
            fontSize: healthSp(context, 11),
            fontFamily: 'Gmarket Sans TTF',
            color: Colors.grey[500],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  @override
  void deactivate() {
    _removeAnswer6MenuOverlay();
    _hideBmiGuideOverlay();
    super.deactivate();
  }

  @override
  void dispose() {
    _goalWeightHintTimer?.cancel();
    _removeAnswer6MenuOverlay();
    _hideBmiGuideOverlay();
    _exerciseOtherDraftFocus.removeListener(_onExerciseOtherDraftFocusChange);
    _exerciseOtherDraftFocus.dispose();
    _exerciseOtherDraftCtrl.dispose();
    _medicationOtherDraftFocus
        .removeListener(_onMedicationOtherDraftFocusChange);
    _medicationOtherDraftFocus.dispose();
    _medicationOtherDraftCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }
}
