import 'package:flutter/material.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/health_profile_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../core/utils/date_formatter.dart';
import '../models/health_profile_model.dart';
import 'health_profile_form_screen.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_bar.dart';
import '../../../common/widgets/login_required_dialog.dart';

class HealthProfileListScreen extends StatefulWidget {
  const HealthProfileListScreen({super.key});

  @override
  State<HealthProfileListScreen> createState() => _HealthProfileListScreenState();
}

class _HealthProfileListScreenState extends State<HealthProfileListScreen> {
  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kInk = Color(0xFF1A1A1A);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kBorderField = Color(0x7FD2D2D2);
  static const Color _kGenderTrack = Color(0xFFF9F9F9);
  static const String _kFont = 'Gmarket Sans TTF';

  static const TextStyle _listSubsectionStyle = TextStyle(
    color: _kInk,
    fontSize: 16,
    fontFamily: _kFont,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  UserModel? _currentUser;
  HealthProfileModel? _healthProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await AuthService.getUser();
      if (user != null) {
        setState(() {
          _currentUser = user;
        });
        
        await _loadHealthProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('데이터 로드 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
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

  Future<void> _loadHealthProfile() async {
    try {
      _healthProfile = await HealthProfileService.getHealthProfile(_currentUser!.id);
    } catch (e) {
      // 건강프로필가 없거나 오류가 발생한 경우
      _healthProfile = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(title: '문진표'),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_currentUser == null || _healthProfile == null) {
      return _buildEmptyState();
    }

    return _buildProfileCard();
  }

  Widget _buildEmptyState() {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '문진표가 없습니다',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '다이어트 상담을 위해\n문진표를 작성해주세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _navigateToForm,
                      icon: const Icon(Icons.add),
                      label: const Text('문진표 작성하기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5A8D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileCard() {
    final profile = _healthProfile!;

    return DefaultTextStyle.merge(
      style: const TextStyle(
        fontFamily: _kFont,
        color: _kInk,
      ),
      child: ColoredBox(
        color: Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFigmaSection(
                    title: '기본정보',
                    onEdit: () => _openSectionForEdit([0], screenTitle: '기본 정보'),
                    innerPadding: EdgeInsets.zero,
                    showBottomDivider: true,
                    child: _buildBasicInfoBody(profile),
                  ),
                  const SizedBox(height: 34),
                  _buildFigmaSection(
                    title: '식습관 및 운동',
                    onEdit: () => _openSectionForEdit(
                      [1, 2],
                      screenTitle: '식습관 및 운동',
                    ),
                    innerPadding: EdgeInsets.zero,
                    showBottomDivider: true,
                    child: _buildDietAndExerciseBody(profile),
                  ),
                  const SizedBox(height: 34),
                  _buildFigmaSection(
                    title: '건강 상태',
                    onEdit: () => _openSectionForEdit([3], screenTitle: '건강 상태'),
                    innerPadding: EdgeInsets.zero,
                    showBottomDivider: true,
                    child: _buildHealthBody(profile),
                  ),
                  const SizedBox(height: 34),
                  _buildDietExperienceSection(profile),
                  const SizedBox(height: 34),
                  _buildMetaCard(profile),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _navigateToEditForm,
                      style: FilledButton.styleFrom(
                        backgroundColor: _kPink,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      child: const Text(
                        '문진표 전체 수정',
                        style: TextStyle(
                          fontSize: 18,
                          fontFamily: _kFont,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFigmaSection({
    required String title,
    required VoidCallback onEdit,
    required Widget child,
    EdgeInsetsGeometry innerPadding = EdgeInsets.zero,
    bool showBottomDivider = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 5,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      color: _kPink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: _kInk,
                        fontSize: 20,
                        fontFamily: _kFont,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onEdit,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Text(
                  '수정',
                  style: TextStyle(
                    color: _kPink,
                    fontSize: 16,
                    fontFamily: _kFont,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Padding(
          padding: innerPadding,
          child: child,
        ),
        if (showBottomDivider) ...[
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            height: 1,
            color: _kBorderField,
          ),
        ],
      ],
    );
  }

  Widget _buildDietExperienceSection(HealthProfileModel profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 5,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      color: _kPink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '다이어트 경험',
                      style: TextStyle(
                        color: _kInk,
                        fontSize: 20,
                        fontFamily: _kFont,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openSectionForEdit(
                [4],
                screenTitle: '다이어트 경험',
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Text(
                  '수정',
                  style: TextStyle(
                    color: _kPink,
                    fontSize: 16,
                    fontFamily: _kFont,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: _kBorderField),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          child: _buildDietDrugBody(profile),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          height: 1,
          color: _kBorderField,
        ),
      ],
    );
  }

  Widget _buildMetaCard(HealthProfileModel profile) {
    final written = DateDisplayFormatter.formatYmdDash(profile.pfWdatetime);
    final modified = DateDisplayFormatter.formatYmdDash(profile.pfMdatetime);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _kBorderField),
          borderRadius: BorderRadius.circular(7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '프로필 정보',
            style: TextStyle(
              fontSize: 16,
              fontFamily: _kFont,
              fontWeight: FontWeight.w500,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: _kBorderField),
          const SizedBox(height: 12),
          _metaRow('작성일', written),
          const SizedBox(height: 8),
          _metaRow('수정일', modified),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontFamily: _kFont,
            fontWeight: FontWeight.w500,
            color: _kInk,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 16,
              fontFamily: _kFont,
              fontWeight: FontWeight.w300,
              color: _kInk,
            ),
          ),
        ),
      ],
    );
  }

  List<String> _pipeParts(String s) {
    if (s.isEmpty) return [];
    return s
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _birthDots(String raw) {
    if (raw.isEmpty) return '-';
    if (raw.length == 8) {
      return '${raw.substring(0, 4)}.${raw.substring(4, 6)}.${raw.substring(6, 8)}';
    }
    return _formatBirthDate(raw).replaceAll('-', '.');
  }

  static const TextStyle _listLabelStyle = TextStyle(
    color: _kInk,
    fontSize: 16,
    fontFamily: _kFont,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  Widget _basicInfoLabeledRow({
    required String label,
    required Widget child,
    double labelWidth = 72,
    Color? labelColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: _listLabelStyle.copyWith(color: labelColor ?? _kInk),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: child),
      ],
    );
  }

  Widget _readMetricBox(String value, String unit) {
    final v = value.trim().isEmpty ? '-' : value.trim();
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _kBorderField),
          borderRadius: BorderRadius.circular(7),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            v,
            style: const TextStyle(
              color: _kInk,
              fontSize: 16,
              fontFamily: _kFont,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (v != '-')
            Text(
              unit,
              style: const TextStyle(
                color: _kInk,
                fontSize: 16,
                fontFamily: _kFont,
                fontWeight: FontWeight.w300,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoBody(HealthProfileModel profile) {
    final g = profile.answer2;
    final goal = profile.answer3.trim().isEmpty ? '-' : profile.answer3.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _basicInfoLabeledRow(
          label: '생년월일',
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            decoration: ShapeDecoration(
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 1, color: _kBorderField),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            child: Text(
              _birthDots(profile.answer1),
              style: const TextStyle(
                color: _kInk,
                fontSize: 16,
                fontFamily: _kFont,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _basicInfoLabeledRow(
          label: '성별',
          labelWidth: 56,
          child: _genderReadSegment(g == 'M', g == 'F'),
        ),
        const SizedBox(height: 24),
        _basicInfoLabeledRow(
          label: '목표',
          labelWidth: 56,
          labelColor: _kPink,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: ShapeDecoration(
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 1, color: _kBorderField),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  goal,
                  style: const TextStyle(
                    color: _kPink,
                    fontSize: 16,
                    fontFamily: _kFont,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (goal != '-')
                  const Text(
                    'kg',
                    style: TextStyle(
                      color: _kPink,
                      fontSize: 16,
                      fontFamily: _kFont,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _basicInfoLabeledRow(
          label: '키/\n몸무게',
          labelWidth: 56,
          child: Row(
            children: [
              Expanded(child: _readMetricBox(profile.answer4, 'cm')),
              const SizedBox(width: 10),
              Expanded(child: _readMetricBox(profile.answer5, 'kg')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _genderReadSegment(bool male, bool female) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: _kGenderTrack,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(child: _genderReadSide('남성', male)),
          Expanded(child: _genderReadSide('여성', female)),
        ],
      ),
    );
  }

  Widget _genderReadSide(String label, bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? const Color(0x7F898686) : Colors.transparent,
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontFamily: _kFont,
          fontWeight: FontWeight.w500,
          color: selected ? _kPink : _kMuted,
        ),
      ),
    );
  }

  /// 식습관·음식 등: 흰 배경 + 흰 테두리(카드 위에서 은은히 구분), 글자 검정
  Widget _chipWhitePlain(String text, {FontWeight fontWeight = FontWeight.w500}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _kBorderField),
          borderRadius: BorderRadius.circular(7),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _kInk,
          fontSize: 16,
          fontFamily: _kFont,
          fontWeight: fontWeight,
          height: 1.25,
        ),
      ),
    );
  }

  /// 운동 빈도(일주일 …)만 연한 테두리
  Widget _chipLightBorder(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _kBorderField),
          borderRadius: BorderRadius.circular(7),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _kInk,
          fontSize: 16,
          fontFamily: _kFont,
          fontWeight: FontWeight.w500,
          height: 1.25,
        ),
      ),
    );
  }

  Widget _wrapChipsWhite(List<String> items) {
    if (items.isEmpty) {
      return const Text(
        '-',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: Colors.black54,
        ),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.map((t) => _chipWhitePlain(t)).toList(),
    );
  }

  Widget _buildDietAndExerciseBody(HealthProfileModel profile) {
    final mealParts = _pipeParts(profile.answer7);
    final mealItems = mealParts.isEmpty && profile.answer7.trim().isNotEmpty
        ? [profile.answer7.trim()]
        : mealParts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('평균 식사 횟수 및 빈도', style: _listSubsectionStyle),
        ),
        const SizedBox(height: 8),
        _wrapChipsWhite(mealItems),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('식사 시간', style: _listSubsectionStyle),
        ),
        const SizedBox(height: 8),
        _buildMealTimeRowFigma(profile.answer71),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('식습관 정보', style: _listSubsectionStyle),
        ),
        const SizedBox(height: 8),
        _wrapChipsWhite(_listItemsFromPipe(profile.answer8)),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('자주 먹는 음식', style: _listSubsectionStyle),
        ),
        const SizedBox(height: 8),
        _wrapChipsWhite(_listItemsFromPipe(profile.answer9)),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('운동 습관', style: _listSubsectionStyle),
        ),
        const SizedBox(height: 8),
        _buildExerciseHabitChips(profile.answer10),
      ],
    );
  }

  List<String> _listItemsFromPipe(String raw) {
    final p = _pipeParts(raw);
    if (p.isNotEmpty) return p;
    final t = raw.trim();
    return t.isEmpty ? [] : [t];
  }

  Widget _buildExerciseHabitChips(String answer10) {
    if (answer10.trim().isEmpty) {
      return const Text(
        '-',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Colors.black54,
        ),
      );
    }
    if (!answer10.contains('###')) {
      final t = answer10.trim();
      final looksLikeWeeklyFreq = t.contains('일주') ||
          t.contains('매일') ||
          RegExp(r'주\s*\d').hasMatch(t);
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          looksLikeWeeklyFreq ? _chipLightBorder(t) : _chipWhitePlain(t),
        ],
      );
    }
    final p = answer10.split('###');
    final freq = p[0].trim();
    final types = p.length > 1 ? p[1].trim() : '';
    final typeList = types.isEmpty
        ? <String>[]
        : types
            .split(RegExp(r'\s*[,|]\s*'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (freq.isNotEmpty) _chipLightBorder(freq),
        ...typeList.map((t) => _chipWhitePlain(t)),
      ],
    );
  }

  Widget _buildMealTimeRowFigma(String answer71) {
    final parts = answer71.split('|');
    String at(int i) =>
        parts.length > i && parts[i].trim().isNotEmpty ? parts[i].trim() : '-';

    Widget slot(String tag, String time) {
      return Expanded(
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: _kBorderField),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                tag,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: _kFont,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF898383),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: _kFont,
                  fontWeight: FontWeight.w500,
                  color: _kInk,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        slot('1st 식사', at(0)),
        const SizedBox(width: 6),
        slot('2nd 식사', at(1)),
        const SizedBox(width: 6),
        slot('3rd 식사', at(2)),
        const SizedBox(width: 6),
        slot('기타', at(3)),
      ],
    );
  }

  Widget _buildHealthBody(HealthProfileModel profile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('현재 질환', style: _listSubsectionStyle),
              ),
              const SizedBox(height: 8),
              _healthDataChipsPipe(profile.answer11),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('복용 약물', style: _listSubsectionStyle),
              ),
              const SizedBox(height: 8),
              _healthDataChipsPipe(profile.answer12),
            ],
          ),
        ),
      ],
    );
  }

  /// 질환·복용약 동일: `|` 분리 시 칩 여러 개, 없음/빈 값은 `없음` 한 칩
  Widget _healthDataChipsPipe(String raw) {
    final t = raw.trim();
    final isNone = t.isEmpty ||
        t == '없음' ||
        t == '해당 없음' ||
        t == '해당없음';
    if (isNone) {
      return SizedBox(
        width: double.infinity,
        child: _healthDataChip('해당 없음'),
      );
    }
    final parts = _pipeParts(t);
    final items = parts.isEmpty ? [t] : parts;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: items.map(_healthDataChip).toList(),
    );
  }

  Widget _healthDataChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _kBorderField),
          borderRadius: BorderRadius.circular(7),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontFamily: _kFont,
          fontWeight: FontWeight.w500,
          color: _kInk,
          height: 1.25,
        ),
      ),
    );
  }

  Widget _dietYesNoCell({
    required String label,
    required bool selected,
    bool compact = false,
  }) {
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(
        vertical: compact ? 5 : 10,
        horizontal: compact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: compact ? 10 : 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? Colors.black : _kMuted.withValues(alpha: 0.55),
          height: 1.33,
        ),
      ),
    );
  }

  Widget _buildDietDrugBody(HealthProfileModel profile) {
    final a13 = profile.answer13.trim();
    // API: 1/없음=아니오, 2/있음=예 — 그 외는 아니오 쪽으로 표시
    final isYes = a13 == '2' || a13 == '있음';
    final isNo = !isYes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                '최근 1년 내 다이어트 약 복용',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kInk,
                  height: 1.33,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 128, minWidth: 100),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: _kBorderField,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _dietYesNoCell(
                        label: '예',
                        selected: isYes,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: _dietYesNoCell(
                        label: '아니오',
                        selected: isNo,
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (isYes) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _kBorderField)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _dietDetailField(
                        '복용 약명',
                        profile.answer13Medicine,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _dietDetailField(
                        '복용 기간',
                        profile.answer13Period,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _dietDetailField(
                        '복용 횟수',
                        profile.answer13Dosage,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _dietDetailField(
                        '부작용 여부',
                        profile.answer13Sideeffect,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Figma: 높이 53, 라벨 absolute top, 값 박스 top 21 · #F8FAFC · 12px/400
  Widget _dietDetailField(String label, String value) {
    final display = value.trim().isEmpty ? '-' : value.trim();

    return SizedBox(
      height: 53,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 4,
            top: 0,
            child: Text(
              label,
              style: const TextStyle(
                color: _kMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.5, // line ~15px
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 21,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                display,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _kInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 16 / 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 생년월일 포맷팅 (YYYYMMDD -> YYYY-MM-DD)
  String _formatBirthDate(String birthDate) {
    if (birthDate.isEmpty) return '-';
    if (birthDate.length == 8) {
      // YYYYMMDD 형식
      return '${birthDate.substring(0, 4)}-${birthDate.substring(4, 6)}-${birthDate.substring(6, 8)}';
    }
    return birthDate;
  }

  void _navigateToForm() async {
    if (_currentUser == null) {
      await showLoginRequiredDialog(
        context,
        message: '건강프로필 작성은 로그인 후 이용할 수 있습니다.',
      );
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HealthProfileFormScreen(),
      ),
    );
    
    if (result == true) {
      _loadData();
    }
  }

  void _navigateToEditForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HealthProfileFormScreen(
          existingProfile: _healthProfile,
        ),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  /// 카드별 수정: 이전/다음 없이 `수정하기`만. 식습관+운동은 [1,2]로 스와이프만 가능.
  void _openSectionForEdit(List<int> sectionIndices, {String? screenTitle}) async {
    if (sectionIndices.isEmpty) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HealthProfileFormScreen(
          existingProfile: _healthProfile,
          initialSectionIndices: sectionIndices,
          editScreenTitle: screenTitle,
        ),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }
}

