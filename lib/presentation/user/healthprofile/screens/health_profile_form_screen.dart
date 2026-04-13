import 'package:flutter/material.dart';
import '../health_profile_questionnaire_options.dart';
import '../health_profile_payload_codec.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/health_profile_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../models/health_profile_model.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_bar.dart';

class HealthProfileFormScreen extends StatefulWidget {
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

  static String _profileSvgForStep(int stepIndex) {
    switch (stepIndex) {
      case 0:
        return AppAssets.profile1;
      case 1:
        return AppAssets.profile2;
      case 2:
        return AppAssets.profile3;
      case 3:
        return AppAssets.profile4;
      default:
        return AppAssets.profile5;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialSectionIndices != null &&
        widget.initialSectionIndices!.isNotEmpty) {
      final subs = widget.initialSectionIndices!;
      _currentPage = subs.first;
      _pageController = subs.length == 1
          ? PageController()
          : PageController(initialPage: 0);
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
    setState(() {
      _currentUser = user;
    });
    
    // 전달받은 기존 건강프로필가 있으면 우선 사용
    if (widget.existingProfile != null) {
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
      final existingProfile = await HealthProfileService.getHealthProfile(_currentUser!.id);
      
      if (existingProfile != null) {        
        // 기존 건강프로필 정보 저장
        setState(() {
          _existingProfile = existingProfile;
        });
        
        _loadExistingData(existingProfile);
      } else {
        print('기존 건강프로필 없음 - 새로 작성');
      }
    } catch (e) {
      print('기존 건강프로필 확인 중 오류: $e');
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
    _formData['answer_6'] = profile.answer6;
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
    
    HealthProfilePayloadCodec.parseAnswer10IntoFormData(
      profile.answer10,
      (f) => _formData['answer_10'] = f,
      (t) => _formData['answer_10_types'] = t,
    );

    // answer_11 (질병) - 파이프(|)로 구분된 문자열을 List로 변환
    if (profile.answer11.isNotEmpty) {
      _formData['answer_11'] = profile.answer11
          .split('|')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => e == '심혈관' ? '심혈증' : (e == '없음' ? '해당 없음' : e))
          .toList();
    } else {
      _formData['answer_11'] = [];
    }
    
    // 복용중인 약 처리 (기타 항목 파싱) - 파이프(|)로 구분
    if (profile.answer12.isNotEmpty) {
      // answer_12가 문자열인 경우 List로 변환
      if (profile.answer12.contains('|')) {
        final parts = profile.answer12.split('|');
        final List<String> answer12List = [];
        String? otherValue;
        
        for (final part in parts) {
          final trimmed = part.trim();
          if (trimmed.startsWith('기타:')) {
            // "기타: 약물명" 형식 파싱
            otherValue = trimmed.substring(3).trim();
            answer12List.add('기타');
          } else {
            answer12List.add(trimmed);
          }
        }
        
        _formData['answer_12'] = answer12List
            .map((e) => e == '없음' ? '해당 없음' : e)
            .toList();
        if (otherValue != null && otherValue.isNotEmpty) {
          _formData['answer_12_other'] = otherValue;
        }
      } else {
        // 단일 값인 경우
        if (profile.answer12 == '기타') {
          _formData['answer_12'] = ['기타'];
        } else {
          final v = profile.answer12 == '없음' ? '해당 없음' : profile.answer12;
          _formData['answer_12'] = [v];
        }
      }
    } else {
      _formData['answer_12'] = [];
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

    // UI 업데이트
    setState(() {});
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

    return MobileAppLayoutWrapper(
      appBar: HealthAppBar(
        title: isSubsetEdit ? '$appBarEditTitle' : '문진표',
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
    );
  }

  /// 식습관+운동처럼 여러 단계를 스와이프로 넘기되, 이전/다음 바는 숨기고 `수정하기`만 표시
  Widget _buildMultiSubsetFormMode() {
    final subs = widget.initialSectionIndices!;

    return ColoredBox(
      color: Colors.white,
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: PageView.builder(
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
                  ),
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

  /// 신규 작성 45px, 기존 프로필 수정(전체 문진) 진입 시 40px
  double get _wizardStepTabHeight =>
      widget.existingProfile != null ? 40.0 : 45.0;

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
                      child: SvgPicture.asset(
                        _profileSvgForStep(i),
                        width: 22,
                        height: 22,
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
  }

  Widget _buildWizardStepScrollable(HealthProfileSection section, int stepIndex) {
    final visible = section.questions.where((q) => _shouldShowQuestion(q)).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(27, 20, 27, 16),
      child: Column(
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
      ),
    );
  }

  Widget _buildWizardBottomBar() {
    final last = _currentPage >= _sections.length - 1;
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
            onTap: _isLoading ? null : (last ? _submitForm : _nextPage),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    last ? '완료' : '다음',
                    style: const TextStyle(
                      color: Color(0xFFFF5A8D),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    last ? Icons.check : Icons.chevron_right,
                    color: const Color(0xFFFF5A8D),
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
    if (_isFirstVisibleInStep(stepIndex, q.id)) {
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
            initialValue: _formData['answer_1']?.toString().length == 8
                ? _formData['answer_1'].toString()
                : '${_formData['birth_year'] ?? ''}${_formData['birth_month'] ?? ''}${_formData['birth_day'] ?? ''}',
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            style: _figmaFieldTextStyle,
            decoration: _figmaInputDecoration(hint: 'YYYYMMDD'),
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
          field: Row(
            children: [
              Expanded(
                child: _genderChip(
                  label: '여',
                  selected: _formData['answer_2'] == 'F',
                  onTap: () => setState(() => _formData['answer_2'] = 'F'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _genderChip(
                  label: '남',
                  selected: _formData['answer_2'] == 'M',
                  onTap: () => setState(() => _formData['answer_2'] = 'M'),
                ),
              ),
            ],
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
    return TextFormField(
      initialValue: _formData[questionId]?.toString() ?? '',
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: _figmaFieldTextStyle,
      decoration: _figmaInputDecoration(hint: hint).copyWith(
        suffixText: suffix,
        suffixStyle: _figmaFieldTextStyle,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return requiredMsg;
        return null;
      },
      onSaved: (v) => _formData[questionId] = v?.trim() ?? '',
    );
  }

  Widget _buildAnswer6Dropdown() {
    final options = HealthProfileQuestionnaireOptions.dietPeriod;
    final current = _formData['answer_6']?.toString().trim() ?? '';
    final selected = current.isEmpty || !options.contains(current) ? null : current;
    return FormField<String>(
      initialValue: selected,
      validator: (v) {
        final val = (v ?? _formData['answer_6']?.toString() ?? '').trim();
        if (val.isEmpty) return '기간을 선택해주세요';
        return null;
      },
      builder: (state) {
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
                    setState(() {
                      _formData['answer_6'] = v;
                      state.didChange(v);
                    });
                  },
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selected ?? '선택',
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
                    final oldValue = _formData['answer_13'];
                    _formData['answer_13'] = '2';
                    if (oldValue == '1' || oldValue == '없음') {
                      _formData['answer_13_medicine'] =
                          _backupAnswer13Fields['answer_13_medicine'] ?? '';
                      _formData['answer_13_period'] =
                          _backupAnswer13Fields['answer_13_period'] ?? '';
                      _formData['answer_13_dosage'] =
                          _backupAnswer13Fields['answer_13_dosage'] ?? '';
                      _formData['answer_13_sideeffect'] =
                          _backupAnswer13Fields['answer_13_sideeffect'] ?? '';
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
                    _backupAnswer13Fields['answer_13_medicine'] =
                        _formData['answer_13_medicine']?.toString() ?? '';
                    _backupAnswer13Fields['answer_13_period'] =
                        _formData['answer_13_period']?.toString() ?? '';
                    _backupAnswer13Fields['answer_13_dosage'] =
                        _formData['answer_13_dosage']?.toString() ?? '';
                    _backupAnswer13Fields['answer_13_sideeffect'] =
                        _formData['answer_13_sideeffect']?.toString() ?? '';
                    _formData['answer_13'] = '1';
                    _formData['answer_13_medicine'] = '';
                    _formData['answer_13_period'] = '';
                    _formData['answer_13_dosage'] = '';
                    _formData['answer_13_sideeffect'] = '';
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
              onChanged: (v) => _formData[id] = v,
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

    void toggle(String opt) {
      setState(() {
        if (question.id == 'answer_11' || question.id == 'answer_12') {
          if (opt == '해당 없음') {
            _formData[question.id] = isMulti ? <String>['해당 없음'] : '해당 없음';
            return;
          }
          if (isMulti) {
            final list = List<String>.from(selected);
            list.remove('해당 없음');
            if (list.contains(opt)) {
              list.remove(opt);
            } else {
              list.add(opt);
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
    final fullWidthNone =
        (question.id == 'answer_11' || question.id == 'answer_12') &&
            gridOptions.remove('해당 없음');

    for (var i = 0; i < gridOptions.length; i += 2) {
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _figmaOptionCell(
                gridOptions[i],
                isMulti
                    ? selected.contains(gridOptions[i])
                    : selected.isNotEmpty && selected.first == gridOptions[i],
                () => toggle(gridOptions[i]),
              ),
            ),
            const SizedBox(width: 10),
            if (i + 1 < gridOptions.length)
              Expanded(
                child: _figmaOptionCell(
                  gridOptions[i + 1],
                  isMulti
                      ? selected.contains(gridOptions[i + 1])
                      : selected.isNotEmpty && selected.first == gridOptions[i + 1],
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

    if (fullWidthNone) {
      rows.add(const SizedBox(height: 10));
      rows.add(
        _figmaOptionCell(
          '해당 없음',
          isMulti ? selected.contains('해당 없음') : selected.isNotEmpty && selected.first == '해당 없음',
          () => toggle('해당 없음'),
          stretchWidth: true,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: stretchWidth ? double.infinity : null,
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
          style: TextStyle(
            color: selected ? const Color(0xFF1A1A1A) : const Color(0xFF898383),
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.2,
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
                    final oldValue = _formData[question.id];
                    _formData[question.id] = newValue;
                    
                    if (value == '없음') {
                      // "없음" 선택 시 관련 필드 초기화
                      _formData['answer_13_medicine'] = '';
                      _formData['answer_13_period'] = '';
                      _formData['answer_13_dosage'] = '';
                      _formData['answer_13_sideeffect'] = '';
                    } else if (value == '있음') {
                      // "있음" 선택 시 기존 백업 데이터가 있으면 복원
                      if (oldValue == '1' || oldValue == '없음') {
                        // 없음에서 있음으로 변경한 경우, 백업 데이터 복원
                        if (_backupAnswer13Fields['answer_13_medicine'] != null) {
                          _formData['answer_13_medicine'] = _backupAnswer13Fields['answer_13_medicine'] ?? '';
                        }
                        if (_backupAnswer13Fields['answer_13_period'] != null) {
                          _formData['answer_13_period'] = _backupAnswer13Fields['answer_13_period'] ?? '';
                        }
                        if (_backupAnswer13Fields['answer_13_dosage'] != null) {
                          _formData['answer_13_dosage'] = _backupAnswer13Fields['answer_13_dosage'] ?? '';
                        }
                        if (_backupAnswer13Fields['answer_13_sideeffect'] != null) {
                          _formData['answer_13_sideeffect'] = _backupAnswer13Fields['answer_13_sideeffect'] ?? '';
                        }
                      }
                      // 이미 있음이었거나 데이터가 입력되어 있는 경우는 그대로 유지
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
        return _buildGridWidget(question);
        
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
    
    if (picked != null) {
      setState(() {
        _formData[questionId] = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _nextPage() {
    if (_currentPage == 0) {
      final g = _formData['answer_2']?.toString();
      if (g != 'M' && g != 'F') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('성별을 선택해주세요.'),
            duration: Duration(milliseconds: 1200),
          ),
        );
        return;
      }
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
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      setState(() {
        _isLoading = true;
      });
      
      try {
        await _saveHealthProfile();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_existingProfile != null
                  ? '문진표가 수정되었습니다'
                  : '문진표가 저장되었습니다'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pushReplacementNamed('/profile');
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 운동 빈도 + 선택 운동 종목(복수) — API 한 필드에 `빈도###종목1|종목2` 형태로 저장
  String _composeAnswer10() {
    return HealthProfilePayloadCodec.composeAnswer10(
      (_formData['answer_10'] ?? '').toString(),
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
      answer8: HealthProfilePayloadCodec.formatListToString(_formData['answer_8']),
      answer9: HealthProfilePayloadCodec.formatListToString(_formData['answer_9']),
      answer10: _composeAnswer10(),
      answer11: HealthProfilePayloadCodec.formatListToString(_formData['answer_11']),
      answer12: HealthProfilePayloadCodec.formatAnswer12(
        _formData['answer_12'],
        _formData['answer_12_other']?.toString(),
      ),
      answer13: HealthProfilePayloadCodec.encodeAnswer13ForApi(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _formData['birth_year'] ?? '',
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
                initialValue: _formData['birth_month'] ?? '',
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
                initialValue: _formData['birth_day'] ?? '',
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
  void dispose() {
    _removeAnswer6MenuOverlay();
    _pageController.dispose();
    super.dispose();
  }
}

