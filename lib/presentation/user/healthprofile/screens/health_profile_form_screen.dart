import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../health_profile_questionnaire_options.dart';
import '../health_profile_payload.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/health_profile_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../models/health_profile_model.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_bar.dart';

class HealthProfileFormScreen extends StatefulWidget {
  /// [HealthProfileListScreen] 등에서 push 시 `RouteSettings.name`으로 넣어야 함.
  /// 뒤로가기 한 번에 연속으로 쌓인 문진표 라우트를 모두 닫을 때 사용.
  static const String routeName = 'health_profile_form';

  final HealthProfileModel? existingProfile;
  /// 목록 등에서 특정 섹션만 수정할 때. 길이 1이면 해당 섹션만, 2 이상이면 해당 섹션들만 PageView(스와이프) + 하단 `수정하기`만 표시.
  final List<int>? initialSectionIndices;
  /// 앱바 제목용 (예: 카드 제목이 `질병`과 다를 때 `건강 상태`). null이면 해당 섹션의 `title` 사용.
  final String? editScreenTitle;
  /// 전체 문진표 모드에서 처음 열 페이지 (0~4). `initialSectionIndices`가 있으면 무시됩니다.
  final int? initialWizardIndex;

  const HealthProfileFormScreen({
    super.key,
    this.existingProfile,
    this.initialSectionIndices,
    this.editScreenTitle,
    this.initialWizardIndex,
  });

  @override
  State<HealthProfileFormScreen> createState() => _HealthProfileFormScreenState();
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
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: showBottomDivider
              ? const Border(
                  bottom: BorderSide(
                    width: 0.3,
                    color: Color(0x7FD2D2D2),
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
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
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

  /// 생년월일 `TextFormField` 재마운트용(프리필/기존 데이터 로드 시만 증가). 입력마다 바꾸면 포커스가 끊김.
  int _wizardBirthFieldKeySeed = 0;

  // 건강 프로필 섹션들
  late List<HealthProfileSection> _sections;

  static const Color _pfPink = Color(0xFFFF3787);
  static const Color _pfPinkSoft = Color(0x0CFF3787);
  static const Color _pfBorder = Color(0x7FD2D2D2);
  static const int _answer6MenuMaxVisibleRows = 4;
  static const double _answer6MenuRowGap = 5;
  static const double _answer6MenuRowExtent =
      46; // vertical padding 10*2 + fontSize 16 × height 1.2
  static const List<String> _stepLabels = [
    '기본정보',
    '식습관',
    '운동습관',
    '질병',
    '다이어트약 복용경험',
  ];

  static const List<String> _wizardStepIconAssets = [
    AppAssets.profile1,
    AppAssets.profile2,
    AppAssets.profile3,
    AppAssets.profile4,
    AppAssets.profile5,
  ];

  @override
  void initState() {
    super.initState();
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
        print('기존 건강프로필 없음 - 새로 작성');
        final u = _currentUser!;
        final digitsBirth =
            (u.birthDate ?? '').trim().replaceAll(RegExp(r'\D'), '');
        print(
          '[HealthProfileForm] 로컬 UserModel — birthDate=${u.birthDate} (digits=$digitsBirth), sex=${u.sex}',
        );
        // 최초 작성: 회원 테이블(bomiora_member) 값은 "프리필"만 (저장 시 member 테이블은 갱신하지 않음)
        _prefillMemberBasicsFromUser(u);
        print(
          '[HealthProfileForm] 프리필 후 폼 — answer_1=${_formData['answer_1']}, '
          'birth_year=${_formData['birth_year']}, birth_month=${_formData['birth_month']}, '
          'birth_day=${_formData['birth_day']}, answer_2=${_formData['answer_2']}',
        );
      }
    } catch (e) {
      if (mounted) {
        print('기존 건강프로필 확인 중 오류: $e');
      }
    }
  }

  void _prefillMemberBasicsFromUser(UserModel user) {
    // 이미 프로필/폼에 값이 있으면 덮어쓰지 않음
    final hasBirth = (_formData['answer_1']?.toString().trim().isNotEmpty == true) ||
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
            question: '하루 끼니',
            type: 'grid',
            options: HealthProfileQuestionnaireOptions.mealsPerDay,
            columns: 2,
          ),
          HealthProfileQuestion(id: 'answer_7_1', question: '식사 시간', type: 'mealtime'),
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
            question: '운동 습관',
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
        title: '질병',
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
            question: '복용 중인 약',
            type: 'grid',
            options: HealthProfileQuestionnaireOptions.medications,
            columns: 2,
            allowMultiple: true,
          ),
          HealthProfileQuestion(
            id: 'answer_12_other',
            question: '기타 (복용 중인 약)',
            type: 'text',
            hint: '기타 약물명을 입력해주세요',
            isRequired: false,
          ),
        ],
      ),
      HealthProfileSection(
        title: '다이어트약 복용경험',
        description: '',
        questions: [
          HealthProfileQuestion(
            id: 'answer_13',
            question: '다이어트약 복용경험',
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
    _formData['answer_3'] = profile.answer3;
    _formData['answer_4'] = profile.answer4;
    _formData['answer_5'] = profile.answer5;
    _formData['answer_6'] = _normalizeDietPeriodOption(profile.answer6);
    _formData['answer_7'] = profile.answer7;
    
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
      _formData['answer_8'] = profile.answer8.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } else {
      _formData['answer_8'] = [];
    }
    
    // answer_9 (자주 먹는 음식) - 파이프(|)로 구분된 문자열을 List로 변환
    if (profile.answer9.isNotEmpty) {
      _formData['answer_9'] = profile.answer9.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } else {
      _formData['answer_9'] = [];
    }
    
    HealthProfilePayload.parseAnswer10IntoFormData(
      profile.answer10,
      answer10TypesRaw: profile.answer102,
      setFrequency: (f) => _formData['answer_10'] = f,
      setTypes: (t) => _formData['answer_10_types'] = t,
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
      return parts
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((e) {
            if (e == '없음' || e == '해당없음') return '해당 없음';
            if (e == '심혈관') return '심혈증';
            return e;
          })
          .toList();
    }

    // answer_11 (질병)
    if (rawMeansNoHealth(profile.answer11)) {
      _formData['answer_11'] = <String>['해당 없음'];
    } else if (profile.answer11.isNotEmpty) {
      _formData['answer_11'] = normalizeDiseaseMedicationParts(
        profile.answer11.split('|'),
      );
    } else {
      _formData['answer_11'] = <String>['해당 없음'];
    }

    // 복용중인 약 (기타 파싱 유지)
    if (profile.answer12.isNotEmpty) {
      if (profile.answer12.contains('|')) {
        final parts = profile.answer12.split('|');
        final answer12List = <String>[];
        String? otherValue;

        for (final part in parts) {
          final trimmed = part.trim();
          if (trimmed.startsWith('기타:')) {
            otherValue = trimmed.substring(3).trim();
            answer12List.add('기타');
          } else {
            answer12List.add(trimmed);
          }
        }

        final normalized = normalizeDiseaseMedicationParts(answer12List);
        if (normalized.isEmpty ||
            (normalized.length == 1 && normalized.first == '해당 없음')) {
          _formData['answer_12'] = <String>['해당 없음'];
          _formData.remove('answer_12_other');
        } else {
          _formData['answer_12'] = normalized;
          if (otherValue != null && otherValue.isNotEmpty) {
            _formData['answer_12_other'] = otherValue;
          }
        }
      } else {
        if (profile.answer12 == '기타') {
          _formData['answer_12'] = ['기타'];
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
    
    // 다이어트약 복용경험 변환 (1 = 없음, 2 = 있음)
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _popAllHealthProfileFormRoutes(context);
      },
      child: MobileAppLayoutWrapper(
        appBar: HealthAppBar(
          title: isSubsetEdit ? '$appBarEditTitle' : '문진표',
          onBack: () => _popAllHealthProfileFormRoutes(context),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
          child: _currentUser == null
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF3787)))
              : isMultiSubsetMode
                  ? _buildMultiSubsetFormMode()
                  : isSingleSectionMode
                      ? _buildSingleSectionMode()
                      : _buildFullFormMode(),
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
    final mergeDietExercise =
        subs.length == 2 && subs[0] == 1 && subs[1] == 2;

    Widget body;
    if (mergeDietExercise) {
      body = SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(27, 20, 27, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _wizardStepQuestionsColumn(_sections[1], 1),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(height: 1, thickness: 1, color: _pfBorder),
            ),
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
                padding: const EdgeInsets.fromLTRB(27, 4, 27, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3787),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      '수정하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(27, 12, 27, 22),
                child: _buildWizardStepIndicator(),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: PageView.builder(
                    controller: _pageController,
                    clipBehavior: Clip.hardEdge,
                    onPageChanged: (page) {
                      setState(() => _currentPage = page);
                    },
                    itemCount: _sections.length,
                    itemBuilder: (context, index) {
                      return RepaintBoundary(
                        child: _buildWizardStepScrollable(_sections[index], index),
                      );
                    },
                  ),
                ),
              ),
              _buildWizardBottomBar(),
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

  /// 전체/부분 수정 모두 동일한 탭 높이
  double get _wizardStepTabHeight => 45.0;

  Widget _buildWizardStepIndicator() {
    final tabH = _wizardStepTabHeight;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_sections.length, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < _sections.length - 1 ? 6 : 0),
            child: i == _currentPage
                ? Container(
                    height: tabH,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _pfPink,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _stepLabels[i],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
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
                        border: Border.all(color: _pfPink),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
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
                              width: 20,
                              height: 20,
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
          if (i < visible.length - 1)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Divider(
                height: 1,
                thickness: 1,
                color: _pfBorder,
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildWizardStepScrollable(HealthProfileSection section, int stepIndex) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(27, 20, 27, 16),
      child: _wizardStepQuestionsColumn(section, stepIndex),
    );
  }

  Widget _buildWizardBottomBar() {
    final last = _currentPage >= _sections.length - 1;
    final canFinish = last ? _isAllWizardStepsFilled() : true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(27, 4, 27, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _isLoading ? null : _previousPage,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chevron_left, color: Colors.grey[700], size: 20),
                    const Text(
                      '이전',
                      style: TextStyle(
                        color: Color(0xFF898686),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const SizedBox(width: 72),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _isLoading || !canFinish
                ? null
                : (last ? _submitForm : _nextPage),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    last ? '완료' : '다음',
                    style: TextStyle(
                      color: canFinish
                          ? const Color(0xFFFF5A8D)
                          : const Color(0xFFBDBDBD),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    last ? Icons.check : Icons.chevron_right,
                    color: canFinish
                        ? const Color(0xFFFF5A8D)
                        : const Color(0xFFBDBDBD),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _nonEmptyString(dynamic v) => (v?.toString().trim().isNotEmpty ?? false);

  bool _nonEmptyList(dynamic v) => v is List && v.map((e) => e.toString().trim()).any((e) => e.isNotEmpty);

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

    // 다이어트약 상세(있음) 필수값
    final a13 = _formData['answer_13']?.toString().trim() ?? '';
    if (stepIndex == 4 && (a13 == '있음' || a13 == '2')) {
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
    if (q.type == 'radio' && q.id == 'answer_13') return false;
    if (q.type == 'mealtime') return true;
    // 전체 마법사: 섹션 첫 그리드는 단계 제목과 중복되면 캡션 생략(운동 습관만).
    // 부분 수정·식습관+운동 병합: 단계 제목이 없으므로 answer_10(운동 습관) 캡션도 표시.
    final isFullWizard = widget.initialSectionIndices == null ||
        widget.initialSectionIndices!.isEmpty;
    if (isFullWizard && _isFirstVisibleInStep(stepIndex, q.id)) {
      if (q.type == 'grid' && q.id != 'answer_10_types') return false;
    }
    return true;
  }

  Widget _buildFigmaQuestionBlock(HealthProfileQuestion question, int stepIndex) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if ((widget.initialSectionIndices == null ||
                  widget.initialSectionIndices!.isEmpty) &&
              _isFirstVisibleInStep(stepIndex, question.id)) ...[
            _buildFigmaStepHeading(stepIndex),
            const SizedBox(height: 24),
          ],
          if (_showPerQuestionCaption(question, stepIndex) &&
              question.type != 'mealtime') ...[
            _figmaTitleLeadingBarRow(
              crossAxisAlignment: CrossAxisAlignment.end,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      question.question,
                      style: _figmaBlockTitleStyle,
                    ),
                  ),
                  if (question.allowMultiple)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text(
                        '*중복선택가능',
                        style: _figmaMultiHintStyle,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (question.type == 'mealtime') ...[
            const SizedBox(height: 8),
            _figmaTitleLeadingBarRow(
              crossAxisAlignment: CrossAxisAlignment.center,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 5,
                runSpacing: 4,
                children: [
                  const Text(
                    '식사 시간',
                    style: _figmaBlockTitleStyle,
                  ),
                  const Text(
                    '*해당되는 입력란에만 입력하세요',
                    style: _figmaMultiHintStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 34),
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
      2 => '운동 습관',
      3 => '질병 정보',
      _ => '다이어트약 복용경험',
    };
    return _figmaTitleLeadingBarRow(
      crossAxisAlignment: CrossAxisAlignment.center,
      child: Text(
        title,
        style: _figmaBlockTitleStyle,
      ),
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
          width: 2,
          height: 18,
          color: Colors.black,
        ),
        const SizedBox(width: 10),
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
      default:
        return _buildFigmaLabeledField(question);
    }
  }

  Widget _buildFigmaBirthAndGender() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _figmaLabeledRow(
          label: '생년월일',
          field: TextFormField(
            key: ValueKey<int>(_wizardBirthFieldKeySeed),
            initialValue: _birthYyyymmddDisplayForWizardField(),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            style: _figmaFieldTextStyle,
            decoration: _figmaInputDecoration(hint: 'YYYYMMDD'),
            onChanged: (v) {
              final s = (v ?? '').trim();
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
              if (v == null || v.length != 8) return '생년월일 8자리를 입력해주세요';
              final y = int.tryParse(v.substring(0, 4));
              final m = int.tryParse(v.substring(4, 6));
              final d = int.tryParse(v.substring(6, 8));
              if (y == null || m == null || d == null) return '올바른 날짜를 입력해주세요';
              try {
                final dt = DateTime(y, m, d);
                if (dt.isAfter(DateTime.now())) return '미래 날짜는 입력할 수 없습니다';
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
        const SizedBox(height: 16),
        _figmaLabeledRow(
          label: '성별',
          labelAlign: TextAlign.right,
          field: FormField<String>(
            initialValue: _formData['answer_2']?.toString(),
            validator: (v) {
              final g = (v ?? _formData['answer_2']?.toString() ?? '').trim();
              if (g != 'M' && g != 'F') return '성별을 선택해주세요';
              return null;
            },
            onSaved: (_) {},
            builder: (state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
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
                      const SizedBox(width: 10),
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
                  ),
                  if (state.hasError) ...[
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 16,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          state.errorText ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _figmaLabeledRow(
          label: '키/\n몸무게',
          labelAlign: TextAlign.right,
          field: Row(
            children: [
              Expanded(
                child: _suffixField(
                  questionId: 'answer_4',
                  hint: '키',
                  suffix: 'cm',
                  requiredMsg: '키를 입력해주세요',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _suffixField(
                  questionId: 'answer_5',
                  hint: '몸무게',
                  suffix: 'kg',
                  requiredMsg: '몸무게를 입력해주세요',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _figmaLabeledRow(
          label: '목표감량\n체중',
          labelAlign: TextAlign.right,
          field: _suffixField(
            questionId: 'answer_3',
            hint: '목표',
            suffix: 'kg',
            requiredMsg: '목표 감량 체중을 입력해주세요',
          ),
        ),
        const SizedBox(height: 16),
        _figmaLabeledRow(
          label: '다이어트\n목표 기간',
          labelAlign: TextAlign.right,
          field: _buildAnswer6Dropdown(),
        ),
      ],
    );
  }

  static const TextStyle _figmaFieldTextStyle = TextStyle(
    color: Color(0xFF1A1A1A),
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  /// 그리드/블록 질문 제목 (크기 통일)
  static const TextStyle _figmaBlockTitleStyle = TextStyle(
    color: Color(0xFF1A1A1A),
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static const TextStyle _figmaMultiHintStyle = TextStyle(
    color: Color(0xFF898383),
    fontSize: 10,
    fontWeight: FontWeight.w300,
  );

  InputDecoration _figmaInputDecoration({String? hint}) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF898686), fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: _pfBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: _pfBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: _pfPink),
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
        height: 50,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: selected ? _pfPinkSoft : Colors.transparent,
          shape: RoundedRectangleBorder(
            side: BorderSide(width: 1, color: selected ? _pfPink : _pfBorder),
            borderRadius: BorderRadius.circular(7),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF1A1A1A) : const Color(0xFF898383),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _suffixField({
    required String questionId,
    required String hint,
    required String suffix,
    required String requiredMsg,
  }) {
    return FormField<String>(
      initialValue: (_formData[questionId]?.toString() ?? '').trim(),
      validator: (v) {
        final s = (v ?? '').trim();
        if (s.isEmpty) return requiredMsg;
        return null;
      },
      onSaved: (v) => _formData[questionId] = (v ?? '').trim(),
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              initialValue: state.value,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: _figmaFieldTextStyle,
              decoration: _figmaInputDecoration(hint: hint).copyWith(
                suffixText: suffix,
                suffixStyle: _figmaFieldTextStyle,
                errorStyle: const TextStyle(height: 0, fontSize: 0),
              ),
              onChanged: (v) {
                state.didChange(v);
                if (!mounted) return;
                setState(() {
                  _formData[questionId] = (v ?? '').trim();
                });
              },
              validator: (_) => null,
              onSaved: (_) {},
            ),
            if (state.hasError) ...[
              const SizedBox(height: 4),
              SizedBox(
                height: 16,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    state.errorText ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
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
    final selected = current.isEmpty || !options.contains(current) ? null : current;
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
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: _pfBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
                shadows: const [
                  BoxShadow(
                    color: Color(0x19000000),
                    blurRadius: 4,
                    offset: Offset(0, 0),
                    spreadRadius: 0,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _openAnswer6Menu(
                  options: options,
                  onSelected: (v) {
                    _removeAnswer6MenuOverlay();
                    if (!mounted) return;
                    setState(() {
                      _formData['answer_6'] = v;
                    });
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
                              : const Color(0xFF1A1A1A),
                          fontSize: 16,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Colors.black87,
                    ),
                  ],
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  state.errorText ?? '',
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
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

  void _openAnswer6Menu({
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    _removeAnswer6MenuOverlay();
    _answer6MenuScrollController = ScrollController();
    final ctx = _answer6FieldKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final overlay = Overlay.of(context);
    final pos = box.localToGlobal(Offset.zero);
    final top = pos.dy + box.size.height + 4;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final menuWidth = box.size.width.clamp(160.0, screenWidth - 16.0);
    const visibleRowCap = _answer6MenuMaxVisibleRows;
    final menuScrolls = options.length > visibleRowCap;
    final menuViewportHeight = menuScrolls
        ? (visibleRowCap * _answer6MenuRowExtent +
            (visibleRowCap - 1) * _answer6MenuRowGap)
        : null;
    
    _answer6MenuOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _removeAnswer6MenuOverlay,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: pos.dx
                .clamp(8.0, MediaQuery.sizeOf(context).width - menuWidth - 8),
            top: top,
            width: menuWidth,
            child: Material(
              color: Colors.transparent,
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontFamily: 'Gmarket Sans TTF',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                  height: 1.2,
                ),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x19000000),
                        blurRadius: 4,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    height: menuViewportHeight,
                    child: Scrollbar(
                      controller: _answer6MenuScrollController,
                      thumbVisibility: menuScrolls,
                      child: SingleChildScrollView(
                        controller: _answer6MenuScrollController,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < options.length; i++) ...[
                              if (i > 0) const SizedBox(height: 5),
                              _Answer6MenuLine(
                                label: options[i],
                                showBottomDivider: i < options.length - 1,
                                onTap: () {
                                  onSelected(options[i]);
                                  _removeAnswer6MenuOverlay();
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_answer6MenuOverlay!);
  }

  Widget _figmaLabeledRow({
    required String label,
    required Widget field,
    TextAlign labelAlign = TextAlign.left,
  }) {
    // 오류 문구로 필드 열 높이가 늘어나도 라벨이 세로 중앙으로 밀리지 않도록 상단 정렬
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            textAlign: labelAlign,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(width: 12),
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
                  height: 50,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: isYes ? _pfPinkSoft : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(width: 1, color: isYes ? _pfPink : _pfBorder),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  child: const Text('있음', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _formData['answer_13'] = '1';
                  });
                },
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: isNo ? _pfPinkSoft : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(width: 1, color: isNo ? _pfPink : _pfBorder),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  child: Text(
                    '없음',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isNo ? const Color(0xFF1A1A1A) : const Color(0xFF898383),
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
          const SizedBox(height: 20),
          _buildDietDrugDetailCard(),
        ],
      ],
    );
  }

  Widget _buildDietDrugDetailCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _pfBorder),
          borderRadius: BorderRadius.circular(7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '다이어트약 상세 정보',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _formData['answer_13_medicine'] = '';
                    _formData['answer_13_period'] = '';
                    _formData['answer_13_dosage'] = '';
                    _formData['answer_13_sideeffect'] = '';
                    _dietDetailResetTick++;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _pfPink,
                  side: const BorderSide(color: _pfPink),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('초기화', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const Divider(color: _pfBorder),
          const SizedBox(height: 8),
          _detailRow('복용 약명', 'answer_13_medicine', '약명'),
          _detailRow('복용 기간', 'answer_13_period', '예: 3개월'),
          _detailRow('복용 횟수', 'answer_13_dosage', '예: 1-2회'),
          _detailRow('부작용', 'answer_13_sideeffect', '예: 불면, 심장 두근거림'),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String id, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              key: ValueKey<String>('diet_$id:$_dietDetailResetTick'),
              initialValue: _formData[id]?.toString() ?? '',
              decoration: _figmaInputDecoration(hint: hint),
              style: _figmaFieldTextStyle,
              onChanged: (v) {
                _formData[id] = v;
                setState(() {});
              },
              onSaved: (v) => _formData[id] = v ?? '',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFigmaMealtimeTable() {
    const headerStyle = TextStyle(
      color: Color(0xFF1A1A1A),
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );

    TableCell headerCell(String label) {
      return TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: SizedBox(
          height: 36,
          child: Center(
            child: Text(
              label,
              style: headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    TableCell fieldCell(
      String fieldKey, {
      int maxLines = 1,
      double minHeight = 36,
      String? hint,
    }) {
      return TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: SizedBox(
          height: minHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: TextFormField(
              initialValue: _formData[fieldKey]?.toString() ?? '',
              maxLines: maxLines,
              keyboardType:
                  maxLines > 1 ? TextInputType.multiline : TextInputType.text,
              textAlignVertical: TextAlignVertical.center,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintStyle: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF898383),
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
              ),
              onSaved: (v) => _formData[fieldKey] = v ?? '',
            ),
          ),
        ),
      );
    }

    /// 1행: 1식·2식·3식·4식 라벨 / 2행: 입력 (4열)
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _pfBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        border: TableBorder.all(color: _pfBorder, width: 1),
        defaultColumnWidth: const FlexColumnWidth(1),
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF9F9F9)),
            children: [
              headerCell('1식'),
              headerCell('2식'),
              headerCell('3식'),
              headerCell('4식'),
            ],
          ),
          TableRow(
            children: [
              fieldCell('meal_1', hint: '예: 8시'),
              fieldCell('meal_2', hint: '예: 12시'),
              fieldCell('meal_3', hint: '예: 19시'),
              fieldCell('meal_other', hint: '예: 21시'),
            ],
          ),
        ],
      ),
    );
  }

  String _canonicalHealthNoneGridOption(String questionId, String opt) {
    if (questionId != 'answer_8' &&
        questionId != 'answer_9' &&
        questionId != 'answer_11' &&
        questionId != 'answer_12') {
      return opt;
    }
    final o = opt.trim();
    if (o == '해당없음' || o == '없음' || o == '해당 없음') return '해당 없음';
    return opt;
  }

  Widget _buildFigmaGrid(HealthProfileQuestion question) {
    final options = question.options ?? [];
    final isMulti = question.allowMultiple;
    List<String> selected = [];
    final raw = _formData[question.id];
    if (isMulti) {
      selected = raw is List ? List<String>.from(raw.map((e) => e.toString())) : [];
    } else {
      if (raw != null) selected = [raw.toString()];
    }
    if (isMulti &&
        (question.id == 'answer_11' || question.id == 'answer_12')) {
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
          if (optC == '해당 없음') {
            _formData[question.id] = isMulti ? <String>['해당 없음'] : '해당 없음';
            return;
          }
          if (isMulti) {
            final list = selected
                .map((e) => _canonicalHealthNoneGridOption(question.id, e))
                .toList();
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
          if (optC == '해당 없음') {
            _formData[question.id] = isMulti ? <String>['해당 없음'] : '해당 없음';
            return;
          }
          if (isMulti) {
            final list = selected
                .map((e) => _canonicalHealthNoneGridOption(question.id, e))
                .toList();
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

    final rows = <Widget>[];
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

    for (var i = 0; i < gridOptions.length; i += 2) {
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _figmaOptionCell(
                gridOptions[i],
                cellSelected(gridOptions[i]),
                () => toggle(gridOptions[i]),
              ),
            ),
            const SizedBox(width: 10),
            if (i + 1 < gridOptions.length)
              Expanded(
                child: _figmaOptionCell(
                  gridOptions[i + 1],
                  cellSelected(gridOptions[i + 1]),
                  () => toggle(gridOptions[i + 1]),
                ),
              )
            else
              const Expanded(child: SizedBox()),
          ],
        ),
      );
      if (i + 2 < gridOptions.length) rows.add(const SizedBox(height: 10));
    }

    if (fullWidthNoneLabel != null) {
      final noneLabel = fullWidthNoneLabel;
      rows.add(const SizedBox(height: 10));
      rows.add(
        Row(
          children: [
            Expanded(
              child: _figmaOptionCell(
                noneLabel,
                cellSelected(noneLabel),
                () => toggle(noneLabel),
                stretchWidth: true,
              ),
            ),
          ],
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _figmaOptionCell(
    String label,
    bool selected,
    VoidCallback onTap, {
    bool stretchWidth = false,
  }) {
    // 줄바꿈이 있을 때만 작은 글꼴(한 줄 10자 이상이어도 운동 빈도 등은 16px 유지)
    final bool compactLabel = label.contains('\n');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: stretchWidth ? double.infinity : null,
        constraints: const BoxConstraints(minHeight: 45, maxHeight: 45),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: selected ? _pfPinkSoft : Colors.transparent,
          shape: RoundedRectangleBorder(
            side: BorderSide(width: 1, color: selected ? _pfPink : _pfBorder),
            borderRadius: BorderRadius.circular(7),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? const Color(0xFF1A1A1A) : const Color(0xFF898383),
            fontSize: compactLabel ? 13 : 16,
            fontWeight: FontWeight.w500,
            height: compactLabel ? 1.05 : 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildFigmaLabeledField(HealthProfileQuestion question) {
    return _buildInputWidget(question);
  }

  // 단일 섹션 수정 모드 (새로운 방식)
  Widget _buildSingleSectionMode() {
    if (_currentPage >= _sections.length) {
      return const Center(child: Text('섹션을 찾을 수 없습니다'));
    }
    
    final section = _sections[_currentPage];
    
    return Column(
      children: [
        // 폼 내용
        Expanded(
          child: Form(
            key: _formKey,
            child: _buildSectionPage(section),
          ),
        ),
        
        // 완료 버튼 (바로 표시)
        Container(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3787),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                '수정하기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionPage(HealthProfileSection section) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(27, 16, 27, 20),
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
      margin: const EdgeInsets.only(bottom: 24),
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (question.allowMultiple == true)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '*중복 선택 가능',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
              ],
            ),
            if (question.hint != null) ...[
              const SizedBox(height: 4),
              Text(
                question.hint!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 12),
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
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
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
            if (question.id.startsWith('answer_13') && question.id != 'answer_13') {
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
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
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
            if (question.id.startsWith('answer_13') && question.id != 'answer_13') {
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
            // 성별 변환 (M/F -> 남성/여성)
            // 다이어트약 복용경험 변환 (1 -> 없음, 2 -> 있음)
            String? groupValue = _formData[question.id];
            if (question.id == 'answer_2') {
              if (groupValue == 'M') groupValue = '남성';
              if (groupValue == 'F') groupValue = '여성';
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
                    _formData[question.id] = value == '남성' ? 'M' : (value == '여성' ? 'F' : value ?? '');
                  } else if (question.id == 'answer_13') {
                    // 다이어트약 복용경험 저장 시 1/2로 변환 (없음=1, 있음=2)
                    final newValue = value == '없음' ? '1' : (value == '있음' ? '2' : value ?? '');
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
        : (_formData[question.id] != null ? [_formData[question.id]] : []).cast<String>();
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
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
                    _formData['answer_12_other'] = '';
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
                color: isSelected ? const Color(0xFFFF3787) : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                option,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFFF3787) : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
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
        
        if (mounted) {
          // `pushReplacementNamed`만 쓰면 [이전 목록(미작성)] 위에 [새 /profile]만 얹혀
          // 뒤로가기 시 이전 목록으로 가며 "문진표가 없습니다"가 다시 보임.
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/profile',
            (route) => route.isFirst,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('저장 중 오류가 발생했습니다: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              width: 568, // 600px - 32px (양쪽 16px 여백)
              duration: const Duration(seconds: 3),
            ),
          );
        }
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
    return HealthProfilePayload.composeAnswer10TypesOnly(
      _formData['answer_10_types'],
    );
  }

  Future<void> _saveHealthProfile() async {
    // 생년월일 합치기 (YYYYMMDD 형식)
    final birthYear = _formData['birth_year'] ?? '';
    final birthMonth = _formData['birth_month'] ?? '';
    final birthDay = _formData['birth_day'] ?? '';
    final birthDate = birthYear.length == 4 && birthMonth.length == 2 && birthDay.length == 2
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
        _formData['answer_12_other']?.toString(),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
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
            const SizedBox(width: 8),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
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
            const SizedBox(width: 8),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
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
                      if (date.year != year || date.month != month || date.day != day) {
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
                  const Text(
                    '1식',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    initialValue: _formData['meal_1'] ?? '',
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '예: 08:00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSaved: (value) {
                      _formData['meal_1'] = value ?? '';
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '2식',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    initialValue: _formData['meal_2'] ?? '',
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '예: 12:00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSaved: (value) {
                      _formData['meal_2'] = value ?? '';
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '3식',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    initialValue: _formData['meal_3'] ?? '',
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '예: 19:00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSaved: (value) {
                      _formData['meal_3'] = value ?? '';
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '4식',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    initialValue: _formData['meal_other'] ?? '',
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '예: 21:00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
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
        const SizedBox(height: 8),
        Text(
          '*해당되는 입력란에만 입력하세요.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  @override
  void deactivate() {
    _removeAnswer6MenuOverlay();
    super.deactivate();
  }

  @override
  void dispose() {
    _removeAnswer6MenuOverlay();
    _pageController.dispose();
    super.dispose();
  }
}

