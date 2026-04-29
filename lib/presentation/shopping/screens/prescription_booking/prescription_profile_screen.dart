import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/health_profile_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../user/healthprofile/models/health_profile_model.dart';
import '../../../user/healthprofile/health_profile_questionnaire_options.dart';
import '../../../user/healthprofile/health_profile_payload.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_bar.dart';
import 'prescription_time_screen.dart';

/// `HealthProfileFormScreen._Answer6MenuLine` 과 동일 스타일 (다이어트 기간 오버레이 메뉴)
class _PrescriptionDietPeriodMenuLine extends StatelessWidget {
  const _PrescriptionDietPeriodMenuLine({
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

/// 처방 예약 — 문진·프로필 (한 화면 스크롤, 선택지는 마이페이지 문진과 동일 소스)
class PrescriptionProfileScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final dynamic selectedOptions;
  final List<int>? tempCartCtIdsToClearOnSuccess;

  const PrescriptionProfileScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.selectedOptions,
    this.tempCartCtIdsToClearOnSuccess,
  });

  @override
  State<PrescriptionProfileScreen> createState() =>
      _PrescriptionProfileScreenState();
}

class _PrescriptionProfileScreenState extends State<PrescriptionProfileScreen> {
  static const Color _kAccent = Color(0xFFFF5A8D);
  static const Color _kBorderGrey = Color(0x7FD2D2D2);
  static const Color _kMutedText = Color(0xFF898383);
  static const TextStyle _kBasicInfoLabelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    fontFamily: 'Gmarket Sans TTF',
  );
  static const double _kTabTextSize = 15;
  /// 기본정보 라벨 칸 폭 (작을수록 오른쪽 입력칸이 넓어짐)
  static const double _kBasicInfoLabelWidth = 60;

  /// 선택 시 연한 핑크 배경 (피그마 0x0CFF3787 계열, 앱 악센트에 맞춤)
  static const Color _kSelectedFill = Color(0x0CFF5A8D);

  /// 다이어트 기간 오버레이: 한 번에 보이는 최대 줄 수 · 줄 간격 · 줄 높이(패딩+16px 글자 기준)
  static const int _kDietPeriodMenuMaxVisibleRows = 4;
  static const double _kDietPeriodMenuRowGap = 5;
  static const double _kDietPeriodMenuRowExtent =
      44; // vertical padding 10*2 + ~24 (font 16)

  UserModel? _currentUser;
  HealthProfileModel? _existingProfile;
  bool _loadingInitial = true;
  bool _saving = false;

  final Map<String, dynamic> _formData = {};

  final TextEditingController _birthDate = TextEditingController();
  final GlobalKey _dietPeriodFieldKey = GlobalKey();
  OverlayEntry? _dietPeriodMenuOverlay;
  ScrollController? _dietPeriodMenuScrollController;
  final TextEditingController _height = TextEditingController();
  final TextEditingController _currentWeight = TextEditingController();
  final TextEditingController _targetWeight = TextEditingController();
  final List<TextEditingController> _mealControllers =
      List.generate(4, (_) => TextEditingController());
  final TextEditingController _dietMedicine = TextEditingController();
  final TextEditingController _dietPeriodMonths = TextEditingController();
  final TextEditingController _dietDosage = TextEditingController();
  final TextEditingController _dietSideEffect = TextEditingController();
  final TextEditingController _medicationsEtc = TextEditingController();

  @override
  void initState() {
    super.initState();
    _formData['eatingHabits'] = <String>[];
    _formData['foodPreference'] = <String>[];
    _formData['exerciseTypes'] = <String>[];
    _formData['diseases'] = <String>[];
    _formData['medications'] = <String>[];
    _loadUserAndProfile();
  }

  @override
  void dispose() {
    _removeDietPeriodMenuOverlay();
    _birthDate.dispose();
    _height.dispose();
    _currentWeight.dispose();
    _targetWeight.dispose();
    for (final c in _mealControllers) {
      c.dispose();
    }
    _dietMedicine.dispose();
    _dietPeriodMonths.dispose();
    _dietDosage.dispose();
    _dietSideEffect.dispose();
    _medicationsEtc.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndProfile() async {
    setState(() => _loadingInitial = true);
    try {
      final user = await AuthService.getUser();
      if (!mounted) return;
      setState(() => _currentUser = user);

      if (user != null) {
        final profile = await HealthProfileService.getHealthProfile(user.id);
        if (!mounted) return;
        setState(() {
          _existingProfile = profile;
          if (profile != null) {
            _applyProfileToForm(profile);
          }
        });
      }
    } catch (e) {
      // ignored
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  void _applyProfileToForm(HealthProfileModel p) {
    final a1 = p.answer1.trim().replaceAll(RegExp(r'\D'), '');
    if (a1.length >= 8) {
      _birthDate.text = a1.substring(0, 8);
      _formData['birthDate'] = a1.substring(0, 8);
    } else if (a1.isNotEmpty) {
      _birthDate.text = a1;
    }

    final g = p.answer2.trim();
    if (g == '여' || g == '여성' || g == 'F' || g.toUpperCase() == 'F') {
      _formData['gender'] = 'F';
    } else if (g == '남' || g == '남성' || g == 'M' || g.toUpperCase() == 'M') {
      _formData['gender'] = 'M';
    } else {
      _formData['gender'] = g.isEmpty ? null : g;
    }

    _height.text = p.answer4;
    _currentWeight.text = p.answer5;
    _targetWeight.text = p.answer3;
    _formData['dietPeriod'] = p.answer6.isEmpty ? null : p.answer6;
    _formData['mealsPerDay'] = p.answer7.isEmpty ? null : p.answer7;

    final mealParts = p.answer71.split('|');
    for (var i = 0; i < 4; i++) {
      _mealControllers[i].text =
          i < mealParts.length ? mealParts[i].trim() : '';
    }
    _formData['mealTimes'] = p.answer71;

    _formData['eatingHabits'] = _splitPipeList(p.answer8);
    _formData['foodPreference'] = _splitPipeList(p.answer9);

    HealthProfilePayload.parseAnswer10IntoFormData(
      p.answer10,
      answer10TypesRaw: p.answer102,
      setFrequency: (freq) => _formData['exerciseFrequency'] =
          freq.isEmpty ? null : freq,
      setTypes: (types) => _formData['exerciseTypes'] = types,
    );

    _formData['diseases'] = _splitPipeList(p.answer11);
    _applyMedicationsFromAnswer12(p.answer12);

    if (p.answer13 == '1') {
      _formData['dietExperience'] = '없음';
    } else if (p.answer13 == '2') {
      _formData['dietExperience'] = '있음';
    } else {
      _formData['dietExperience'] =
          p.answer13.isEmpty ? null : p.answer13;
    }

    _dietMedicine.text = p.answer13Medicine;
    _dietPeriodMonths.text = p.answer13Period;
    _dietDosage.text = p.answer13Dosage;
    _dietSideEffect.text = p.answer13Sideeffect;
  }

  List<String> _splitPipeList(String raw) {
    if (raw.isEmpty) return [];
    return raw
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  void _applyMedicationsFromAnswer12(String answer12) {
    final meds = <String>[];
    String? etc;
    for (final part in _splitPipeList(answer12)) {
      if (part.startsWith('기타:')) {
        meds.add('기타');
        etc = part.substring(3).trim();
      } else {
        final normalized =
            part == '없음' ? '해당 없음' : part;
        meds.add(normalized);
      }
    }
    _formData['medications'] = meds;
    _medicationsEtc.text = etc ?? '';
  }

  void _syncBirthDate() {
    final raw = _birthDate.text.replaceAll(RegExp(r'\D'), '');
    if (raw.length == 8) {
      _formData['birthDate'] = raw;
    } else {
      _formData['birthDate'] = null;
    }
  }

  void _syncMealTimes() {
    _formData['mealTimes'] =
        _mealControllers.map((c) => c.text.trim()).join('|');
  }

  void _syncScalarFields() {
    _formData['height'] = _height.text.trim();
    _formData['currentWeight'] = _currentWeight.text.trim();
    _formData['targetWeight'] = _targetWeight.text.trim();
    _formData['dietMedicine'] = _dietMedicine.text.trim();
    _formData['dietPeriodMonths'] = _dietPeriodMonths.text.trim();
    _formData['dietDosage'] = _dietDosage.text.trim();
    _formData['dietSideEffect'] = _dietSideEffect.text.trim();
    _formData['medicationsEtc'] = _medicationsEtc.text.trim();
  }

  bool _validate() {
    _syncBirthDate();
    _syncMealTimes();
    _syncScalarFields();

    String? msg;
    if (_formData['birthDate'] == null) {
      msg = '생년월일을 입력해주세요';
    } else if (_formData['gender'] == null) {
      msg = '성별을 선택해주세요';
    } else if ((_formData['height'] as String).isEmpty) {
      msg = '키를 입력해주세요';
    } else if ((_formData['currentWeight'] as String).isEmpty) {
      msg = '현재 몸무게를 입력해주세요';
    } else if ((_formData['targetWeight'] as String).isEmpty) {
      msg = '목표 감량 체중을 입력해주세요';
    } else if (_formData['dietPeriod'] == null) {
      msg = '다이어트 예상 기간을 선택해주세요';
    } else if (_formData['mealsPerDay'] == null) {
      msg = '하루 끼니를 선택해주세요';
    } else if (_formData['exerciseFrequency'] == null) {
      msg = '운동 빈도를 선택해주세요';
    } else if (_formData['dietExperience'] == null) {
      msg = '다이어트약 복용 경험을 선택해주세요';
    } else if (_formData['dietExperience'] == '있음') {
      if ((_formData['dietMedicine'] as String).isEmpty ||
          (_formData['dietPeriodMonths'] as String).isEmpty) {
        msg = '다이어트약 정보를 입력해주세요';
      }
    }

    final habits = List<String>.from(_formData['eatingHabits'] as List? ?? []);
    if (habits.isEmpty) {
      msg ??= '식습관을 한 가지 이상 선택해주세요';
    }
    final foods = List<String>.from(_formData['foodPreference'] as List? ?? []);
    if (foods.isEmpty) {
      msg ??= '자주 먹는 음식을 한 가지 이상 선택해주세요';
    }
    final dis = List<String>.from(_formData['diseases'] as List? ?? []);
    if (dis.isEmpty) {
      msg ??= '질병 항목을 선택해주세요';
    }
    final med = List<String>.from(_formData['medications'] as List? ?? []);
    if (med.isEmpty) {
      msg ??= '복용 중인 약을 선택해주세요';
    }
    if (med.contains('기타') &&
        (_formData['medicationsEtc'] as String).isEmpty) {
      msg ??= '기타 복용약 내용을 입력해주세요';
    }

    if (msg != null) {
      return false;
    }
    return true;
  }

  HealthProfileModel _buildProfileModel() {
    final user = _currentUser!;
    final now = DateTime.now();
    return HealthProfileModel(
      pfNo: _existingProfile?.pfNo,
      mbId: user.id,
      answer1: _formData['birthDate']?.toString() ?? '',
      answer2: _formData['gender']?.toString() ?? '',
      answer3: _formData['targetWeight']?.toString() ?? '',
      answer4: _formData['height']?.toString() ?? '',
      answer5: _formData['currentWeight']?.toString() ?? '',
      answer6: _formData['dietPeriod']?.toString() ?? '',
      answer7: _formData['mealsPerDay']?.toString() ?? '',
      answer71: _formData['mealTimes']?.toString() ?? '|||',
      answer8: HealthProfilePayload.formatListToString(
          _formData['eatingHabits']),
      answer9: HealthProfilePayload.formatListToString(
          _formData['foodPreference']),
      answer10: HealthProfilePayload.composeAnswer10FrequencyOnly(
        _formData['exerciseFrequency']?.toString(),
      ),
      answer102: HealthProfilePayload.composeAnswer10TypesOnly(
        _formData['exerciseTypes'],
      ),
      answer11:
          HealthProfilePayload.formatListToString(_formData['diseases']),
      answer12: HealthProfilePayload.formatAnswer12(
        _formData['medications'],
        _formData['medicationsEtc']?.toString(),
      ),
      answer13: HealthProfilePayload.encodeAnswer13ForApi(
        _formData['dietExperience']?.toString(),
      ),
      answer13Medicine: _formData['dietMedicine']?.toString() ?? '',
      answer13Period: _formData['dietPeriodMonths']?.toString() ?? '',
      answer13Dosage: _formData['dietDosage']?.toString() ?? '',
      answer13Sideeffect: _formData['dietSideEffect']?.toString() ?? '',
      pfWdatetime: _existingProfile?.pfWdatetime ?? now,
      pfMdatetime: now,
      pfIp: _existingProfile?.pfIp ?? '0.0.0.0',
      pfMemo: _existingProfile?.pfMemo ?? '',
    );
  }

  Future<void> _onNext() async {
    if (!_validate()) return;
    if (_currentUser == null) {
      return;
    }

    setState(() => _saving = true);
    try {
      final model = _buildProfileModel();
      final ok = await HealthProfileService.saveHealthProfile(model);
      if (!mounted) return;
      if (!ok) {
        return;
      }

      final refreshed =
          await HealthProfileService.getHealthProfile(_currentUser!.id);
      if (mounted) {
        setState(() => _existingProfile = refreshed);
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrescriptionTimeScreen(
            productId: widget.productId,
            productName: widget.productName,
            selectedOptions: widget.selectedOptions,
            formData: Map<String, dynamic>.from(_formData),
            existingProfile: refreshed ?? _existingProfile,
            tempCartCtIdsToClearOnSuccess: widget.tempCartCtIdsToClearOnSuccess,
          ),
        ),
      );
    } catch (e) {
      // ignored
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingInitial) {
      return const MobileAppLayoutWrapper(
        appBar: null,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(title: '02 문진표 작성하기', centerTitle: true),
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          fontFamily: 'Gmarket Sans TTF',
          color: Color(0xFF191C1D),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(27, 16, 27, 8),
                children: [
                  const SizedBox(height: 10),
                  _sectionTitleWithIcon('기본 정보', AppAssets.profile1),
                  const SizedBox(height: 12),
                  _labeledRow(
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('생년월일', style: _kBasicInfoLabelStyle),
                    ),
                    _numField(
                      controller: _birthDate,
                      hint: 'YYYYMMDD',
                      maxLen: 8,
                      dense: true,
                      onChanged: (_) {
                        _syncBirthDate();
                        setState(() {});
                      },
                    ),
                  ),
                  _labeledRow(
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('성별', style: _kBasicInfoLabelStyle),
                    ),
                    Row(
                      children: [
                        Expanded(child: _genderTile('M', '남')),
                        const SizedBox(width: 10),
                        Expanded(child: _genderTile('F', '여')),
                      ],
                    ),
                  ),
                  _labeledRow(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('키/', style: _kBasicInfoLabelStyle),
                        Text('몸무게', style: _kBasicInfoLabelStyle),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _numField(
                            controller: _height,
                            hint: '',
                            suffix: 'cm',
                            maxLen: 3,
                            dense: true,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _numField(
                            controller: _currentWeight,
                            hint: '',
                            suffix: 'kg',
                            maxLen: 3,
                            dense: true,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _labeledRow(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('목표감량', style: _kBasicInfoLabelStyle),
                        Text('체중', style: _kBasicInfoLabelStyle),
                      ],
                    ),
                    _numField(
                      controller: _targetWeight,
                      hint: '',
                      suffix: 'kg',
                      maxLen: 3,
                      dense: true,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  _labeledRow(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('다이어트', style: _kBasicInfoLabelStyle),
                        Text('예상 기간', style: _kBasicInfoLabelStyle),
                      ],
                    ),
                    _buildDietPeriodDropdown(),
                  ),
                  const SizedBox(height: 8),
                  _sectionDivider(),
                  const SizedBox(height: 16),
                  _sectionTitleWithIcon('식습관', AppAssets.profile2),
                  const SizedBox(height: 12),
                  const Text(
                    '하루 끼니',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  _mealsPerDayCards(),
                  const SizedBox(height: 16),
                  _mealTimeLabelRow(),
                  const SizedBox(height: 8),
                  _mealTimeRow(),
                  const SizedBox(height: 16),
                  _labelWithHint('식습관', '*중복선택가능'),
                  const SizedBox(height: 8),
                  _multiGridFigma(
                    HealthProfileQuestionnaireOptions.eatingHabits,
                    List<String>.from(
                        _formData['eatingHabits'] as List? ?? []),
                    '해당없음',
                    (next) => setState(() {
                          _formData['eatingHabits'] =
                              _withExclusiveNone(next, '해당없음');
                        }),
                  ),
                  const SizedBox(height: 16),
                  _labelWithHint('자주 먹는 음식', '*중복선택가능'),
                  const SizedBox(height: 8),
                  _multiGridFigma(
                    HealthProfileQuestionnaireOptions.foodPreference,
                    List<String>.from(
                        _formData['foodPreference'] as List? ?? []),
                    null,
                    (next) =>
                        setState(() => _formData['foodPreference'] = next),
                  ),
                  const SizedBox(height: 8),
                  _sectionDivider(),
                  const SizedBox(height: 16),
                  _sectionTitleWithIcon('운동', AppAssets.profile3),
                  const SizedBox(height: 12),
                  const Text(
                    '운동 습관',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  _twoColumnSingleChoice(
                    HealthProfileQuestionnaireOptions.exerciseFrequency,
                    _formData['exerciseFrequency'] as String?,
                    (v) => setState(() => _formData['exerciseFrequency'] = v),
                  ),
                  const SizedBox(height: 16),
                  _labelWithHint('주로 하는 운동', '*중복선택가능'),
                  const SizedBox(height: 8),
                  _multiGridFigma(
                    HealthProfileQuestionnaireOptions.exerciseTypes,
                    List<String>.from(
                        _formData['exerciseTypes'] as List? ?? []),
                    null,
                    (next) => setState(() => _formData['exerciseTypes'] = next),
                  ),
                  const SizedBox(height: 8),
                  _sectionDivider(),
                  const SizedBox(height: 16),
                  _sectionTitleWithIcon('질병', AppAssets.profile4),
                  const SizedBox(height: 12),
                  _labelWithHint('질병', '*중복선택가능'),
                  const SizedBox(height: 8),
                  _multiGridFigma(
                    HealthProfileQuestionnaireOptions.diseases,
                    List<String>.from(_formData['diseases'] as List? ?? []),
                    '해당 없음',
                    (next) => setState(() {
                      _formData['diseases'] =
                          _withExclusiveNone(next, '해당 없음');
                    }),
                  ),
                  const SizedBox(height: 16),
                  _labelWithHint('복용 중인 약', '*중복선택가능'),
                  const SizedBox(height: 8),
                  _multiGridFigma(
                    HealthProfileQuestionnaireOptions.medications,
                    List<String>.from(
                        _formData['medications'] as List? ?? []),
                    '해당 없음',
                    (next) => setState(() {
                      _formData['medications'] =
                          _withExclusiveNone(next, '해당 없음');
                    }),
                  ),
                  if (List<String>.from(_formData['medications'] as List? ?? [])
                      .contains('기타')) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _medicationsEtc,
                        decoration: _fieldDecoration('기타 복용약을 입력해주세요'),
                        maxLines: 1,
                        maxLength: 100,
                        buildCounter: _noCounter,
                        style: const TextStyle(
                          fontFamily: 'Gmarket Sans TTF',
                          fontSize: 15,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _sectionDivider(),
                  const SizedBox(height: 16),
                  _sectionTitleWithIcon('다이어트 약', AppAssets.profile5),
                  const SizedBox(height: 12),
                  const Text(
                    '다이어트약 복용 경험',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _expTile(
                          label: '있음',
                          selected: _formData['dietExperience'] == '있음',
                          onTap: () => setState(
                              () => _formData['dietExperience'] = '있음'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _expTile(
                          label: '없음',
                          selected: _formData['dietExperience'] == '없음',
                          onTap: () => setState(
                              () => _formData['dietExperience'] = '없음'),
                        ),
                      ),
                    ],
                  ),
                  if (_formData['dietExperience'] == '있음') ...[
                    const SizedBox(height: 16),
                    _buildDietDrugDetailCard(),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
            SafeArea(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(27, 0, 27, 20),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      height: 40,
                      child: FilledButton.tonal(
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(100, 40),
                          maximumSize: const Size(100, 40),
                          padding: EdgeInsets.zero,
                          backgroundColor: const Color(0x26D2D2D2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '이전',
                          style: TextStyle(
                            color: Color(0xFF898686),
                            fontSize: 20,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _onNext,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 40),
                            maximumSize: const Size(double.infinity, 40),
                            padding: EdgeInsets.zero,
                            backgroundColor: _kAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            disabledBackgroundColor: Colors.grey[300],
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  '다음',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget? _noCounter(
    BuildContext _, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) =>
      null;

  List<String> _withExclusiveNone(List<String> next, String noneToken) {
    if (next.contains(noneToken)) {
      return [noneToken];
    }
    return next.where((e) => e != noneToken).toList();
  }

  Widget _sectionTitleWithIcon(String title, String assetPath) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.asset(
          assetPath,
          width: 26,
          height: 26,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF584045),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionDivider() {
    return Container(height: 1, color: _kBorderGrey);
  }

  /// 기본 정보: 라벨(고정폭) + 입력을 한 행에 배치
  Widget _labeledRow(Widget label, Widget field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: _kBasicInfoLabelWidth, child: label),
          const SizedBox(width: 20),
          Expanded(child: field),
        ],
      ),
    );
  }

  Widget _mealTimeLabelRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          '식사 시간',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '*해당되는 입력란에만 입력하세요',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  void _removeDietPeriodMenuOverlay() {
    _dietPeriodMenuOverlay?.remove();
    _dietPeriodMenuOverlay = null;
    _dietPeriodMenuScrollController?.dispose();
    _dietPeriodMenuScrollController = null;
  }

  void _openDietPeriodMenu({
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    _removeDietPeriodMenuOverlay();
    _dietPeriodMenuScrollController = ScrollController();
    final ctx = _dietPeriodFieldKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final pos = box.localToGlobal(Offset.zero);
    final top = pos.dy + box.size.height + 4;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final menuWidth = box.size.width.clamp(160.0, screenWidth - 16.0);

    const visibleRowCap = _kDietPeriodMenuMaxVisibleRows;
    final menuScrolls = options.length > visibleRowCap;
    final menuViewportHeight = menuScrolls
        ? (visibleRowCap * _kDietPeriodMenuRowExtent +
            (visibleRowCap - 1) * _kDietPeriodMenuRowGap)
        : null;

    _dietPeriodMenuOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _removeDietPeriodMenuOverlay,
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
                      controller: _dietPeriodMenuScrollController,
                      thumbVisibility: menuScrolls,
                      child: SingleChildScrollView(
                        controller: _dietPeriodMenuScrollController,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < options.length; i++) ...[
                              if (i > 0) const SizedBox(height: 5),
                              _PrescriptionDietPeriodMenuLine(
                                label: options[i],
                                showBottomDivider: i < options.length - 1,
                                onTap: () {
                                  onSelected(options[i]);
                                  _removeDietPeriodMenuOverlay();
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
    Overlay.of(context).insert(_dietPeriodMenuOverlay!);
  }

  /// `HealthProfileFormScreen._buildAnswer6Dropdown` 과 동일 패턴
  Widget _buildDietPeriodDropdown() {
    const options = HealthProfileQuestionnaireOptions.dietPeriod;
    final current = _formData['dietPeriod']?.toString().trim() ?? '';
    final selected = current.isEmpty || !options.contains(current)
        ? null
        : current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: _dietPeriodFieldKey,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: _kBorderGrey),
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
          child: DefaultTextStyle(
            style: TextStyle(
              fontFamily: 'Gmarket Sans TTF',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: selected == null
                  ? const Color(0xFF898686)
                  : const Color(0xFF1A1A1A),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _openDietPeriodMenu(
                options: options,
                onSelected: (v) {
                  setState(() => _formData['dietPeriod'] = v);
                },
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selected ?? '선택',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
        ),
      ],
    );
  }

  Widget _mealsPerDayCards() {
    const opts = HealthProfileQuestionnaireOptions.mealsPerDay;
    final selected = _formData['mealsPerDay'] as String?;
    final rows = <Widget>[];
    for (var i = 0; i < opts.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(
              child: _figmaChoiceCard(
                opts[i],
                opts[i] == selected,
                () => setState(() => _formData['mealsPerDay'] = opts[i]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: i + 1 < opts.length
                  ? _figmaChoiceCard(
                      opts[i + 1],
                      opts[i + 1] == selected,
                      () => setState(
                          () => _formData['mealsPerDay'] = opts[i + 1]),
                    )
                  : const SizedBox(height: 40),
            ),
          ],
        ),
      );
      if (i + 2 < opts.length) {
        rows.add(const SizedBox(height: 10));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _figmaChoiceCard(String label, bool selected, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          width: double.infinity,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: selected ? _kSelectedFill : Colors.transparent,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: 1,
                color: selected ? _kAccent : _kBorderGrey,
              ),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected
                  ? const Color(0xFF1A1A1A)
                  : _kMutedText,
              fontSize: _kTabTextSize,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _figmaChoiceCardFullWidth(
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          width: double.infinity,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: selected ? _kSelectedFill : Colors.transparent,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: 1,
                color: selected ? _kAccent : _kBorderGrey,
              ),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? const Color(0xFF1A1A1A)
                  : _kMutedText,
              fontSize: _kTabTextSize,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _toggleMultiSelection(
    List<String> selected,
    String option,
    void Function(List<String>) onChanged,
  ) {
    final next = List<String>.from(selected);
    if (next.contains(option)) {
      next.remove(option);
    } else {
      if (option == '해당없음' || option == '해당 없음') {
        onChanged([option]);
        return;
      }
      next.remove('해당없음');
      next.remove('해당 없음');
      next.add(option);
    }
    onChanged(next);
  }

  /// 2열 카드 + (선택) 맨 아래 `fullWidthNoneToken` 전폭 행
  Widget _multiGridFigma(
    List<String> options,
    List<String> selected,
    String? fullWidthNoneToken,
    void Function(List<String>) onChanged,
  ) {
    final regular = fullWidthNoneToken != null
        ? options.where((e) => e != fullWidthNoneToken).toList()
        : options;

    final col = <Widget>[];
    for (var i = 0; i < regular.length; i += 2) {
      col.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _figmaChoiceCard(
                regular[i],
                selected.contains(regular[i]),
                () => _toggleMultiSelection(
                  selected,
                  regular[i],
                  onChanged,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: i + 1 < regular.length
                  ? _figmaChoiceCard(
                      regular[i + 1],
                      selected.contains(regular[i + 1]),
                      () => _toggleMultiSelection(
                        selected,
                        regular[i + 1],
                        onChanged,
                      ),
                    )
                  : const SizedBox(height: 40),
            ),
          ],
        ),
      );
      if (i + 2 < regular.length) {
        col.add(const SizedBox(height: 10));
      }
    }

    if (fullWidthNoneToken != null) {
      if (col.isNotEmpty) {
        col.add(const SizedBox(height: 10));
      }
      col.add(
        _figmaChoiceCardFullWidth(
          fullWidthNoneToken,
          selected.contains(fullWidthNoneToken),
          () => _toggleMultiSelection(
            selected,
            fullWidthNoneToken,
            onChanged,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: col,
    );
  }

  Widget _twoColumnSingleChoice(
    List<String> options,
    String? selected,
    void Function(String) onSelect,
  ) {
    final rows = <Widget>[];
    for (var i = 0; i < options.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(
              child: _figmaChoiceCard(
                options[i],
                options[i] == selected,
                () => onSelect(options[i]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: i + 1 < options.length
                  ? _figmaChoiceCard(
                      options[i + 1],
                      options[i + 1] == selected,
                      () => onSelect(options[i + 1]),
                    )
                  : const SizedBox(height: 40),
            ),
          ],
        ),
      );
      if (i + 2 < options.length) {
        rows.add(const SizedBox(height: 10));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _labelWithHint(String title, String hint) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        Text(
          hint,
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.grey[400],
        fontFamily: 'Gmarket Sans TTF',
        fontSize: 14,
      ),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: _kBorderGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: _kBorderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: _kAccent, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  InputDecoration _compactNumDecoration(String hint, {String? suffix}) {
    return InputDecoration(
      hintText: hint.isEmpty ? null : hint,
      hintStyle: TextStyle(
        color: Colors.grey[400],
        fontSize: 14,
        fontFamily: 'Gmarket Sans TTF',
      ),
      suffixText: suffix,
      suffixStyle: const TextStyle(
        fontFamily: 'Gmarket Sans TTF',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: _kMutedText,
      ),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: _kBorderGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: _kBorderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: _kAccent, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    );
  }

  Widget _numField({
    required TextEditingController controller,
    required String hint,
    String? suffix,
    required int maxLen,
    bool dense = false,
    required void Function(String) onChanged,
  }) {
    final field = TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: maxLen,
      buildCounter: _noCounter,
      style: const TextStyle(
        fontSize: 15,
        fontFamily: 'Gmarket Sans TTF',
      ),
      decoration: dense
          ? _compactNumDecoration(hint, suffix: suffix)
          : _fieldDecoration(hint),
      onChanged: onChanged,
    );
    if (dense) {
      return SizedBox(height: 40, child: field);
    }
    return field;
  }

  Widget _genderTile(String value, String label) {
    final sel = _formData['gender'] == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _formData['gender'] = value),
        borderRadius: BorderRadius.circular(7),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: ShapeDecoration(
            color: sel ? _kSelectedFill : Colors.transparent,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: 1,
                color: sel ? _kAccent : _kBorderGrey,
              ),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: _kTabTextSize,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
              color: sel ? const Color(0xFF1A1A1A) : _kMutedText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _expTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF0F5) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? _kAccent : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: _kTabTextSize,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? _kAccent : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildDietDrugDetailCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _kBorderGrey),
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
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                  fontFamily: 'Gmarket Sans TTF',
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _dietMedicine.clear();
                    _dietPeriodMonths.clear();
                    _dietDosage.clear();
                    _dietSideEffect.clear();
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kAccent,
                  side: const BorderSide(color: _kAccent),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '초기화',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Gmarket Sans TTF',
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: _kBorderGrey),
          const SizedBox(height: 8),
          _dietDrugDetailRow(
            label: '복용 약명',
            controller: _dietMedicine,
            hint: '약명',
            maxLength: 50,
          ),
          _dietDrugDetailRow(
            label: '복용 기간',
            controller: _dietPeriodMonths,
            hint: '예: 3개월',
            maxLength: 20,
          ),
          _dietDrugDetailRow(
            label: '복용 횟수',
            controller: _dietDosage,
            hint: '예: 1-2회',
            maxLength: 20,
          ),
          _dietDrugDetailRow(
            label: '부작용',
            controller: _dietSideEffect,
            hint: '예: 불면, 심장 두근거림',
            maxLength: 500,
          ),
        ],
      ),
    );
  }

  Widget _dietDrugDetailRow({
    required String label,
    required TextEditingController controller,
    required String hint,
    required int maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'Gmarket Sans TTF',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: controller,
                decoration: _fieldDecoration(hint),
                maxLines: 1,
                maxLength: maxLength,
                buildCounter: _noCounter,
                style: const TextStyle(
                  fontFamily: 'Gmarket Sans TTF',
                  fontSize: 15,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// `HealthProfileFormScreen._buildFigmaMealtimeTable` 과 동일: 1행 헤더(1~4식) / 2행 입력 4열
  Widget _mealTimeRow() {
    const headerStyle = TextStyle(
      color: Color(0xFF1A1A1A),
      fontSize: 13,
      fontWeight: FontWeight.w600,
      fontFamily: 'Gmarket Sans TTF',
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

    TableCell fieldCell(int index, String hint) {
      return TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: TextField(
              controller: _mealControllers[index],
              keyboardType: TextInputType.text,
              textAlignVertical: TextAlignVertical.center,
              textAlign: TextAlign.center,
              maxLines: 1,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintStyle: TextStyle(
                  fontSize: 11,
                  color: _kMutedText,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                  fontFamily: 'Gmarket Sans TTF',
                ),
              ),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
                fontFamily: 'Gmarket Sans TTF',
              ),
              onChanged: (_) {
                _syncMealTimes();
                setState(() {});
              },
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _kBorderGrey),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        border: TableBorder.all(color: _kBorderGrey, width: 1),
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
              fieldCell(0, '예: 8시'),
              fieldCell(1, '예: 12시'),
              fieldCell(2, '예: 19시'),
              fieldCell(3, '예: 21시'),
            ],
          ),
        ],
      ),
    );
  }
}
