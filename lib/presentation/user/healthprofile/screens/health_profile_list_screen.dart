import 'package:flutter/material.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/health_profile_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../core/utils/date_formatter.dart';
import '../models/health_profile_model.dart';
import 'health_profile_form_screen.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/login_required_dialog.dart';
import '../../../common/widgets/centered_empty_state.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';

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
    fontSize: 14,
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
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );
    final textScale =
        healthTextScaleByWidth(MediaQuery.sizeOf(context).width);

    return Theme(
      data: gmarketTheme,
      child: MobileAppLayoutWrapper(
        appBar: HealthAppBar(
          title: '문진표',
          titleFontSize: healthSp(context, 16),
          leadingIconSize: healthDp(context, 24),
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: _kPink),
                )
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_currentUser == null) {
      return const CenteredEmptyState(
        icon: Icons.assignment_outlined,
        message: '로그인 후 이용 가능합니다.',
        fillAvailable: true,
      );
    }
    if (_healthProfile == null) {
      return _buildNoProfileState();
    }

    return _buildProfileCard();
  }

  Widget _buildNoProfileState() {
    return CenteredEmptyState(
      icon: Icons.assignment_outlined,
      message: '상담을 위해 문진표를 작성해주세요',
      fillAvailable: true,
      trailing: [
        ElevatedButton.icon(
          onPressed: _navigateToForm,
          icon: Icon(Icons.add, size: healthDp(context, 22)),
          label: Text(
            '문진표 작성하기',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF5A8D),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 20),
              vertical: healthDp(context, 12),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(healthDp(context, 8)),
            ),
          ),
        ),
      ],
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
          padding: EdgeInsets.fromLTRB(
            healthDp(context, 16),
            healthDp(context, 20),
            healthDp(context, 16),
            healthDp(context, 24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFigmaSection(
                    title: '기본정보',
                    onEdit: () => _openSectionForEdit([0], screenTitle: '기본정보'),
                    innerPadding: EdgeInsets.zero,
                    showBottomDivider: true,
                    child: _buildBasicInfoBody(profile),
                  ),
                  SizedBox(height: healthDp(context, 34)),
                  _buildFigmaSection(
                    title: '식습관',
                    onEdit: () => _openSectionForEdit(
                      [1],
                      screenTitle: '식습관',
                    ),
                    innerPadding: EdgeInsets.zero,
                    showBottomDivider: true,
                    child: _buildDietHabitsBody(profile),
                  ),
                  SizedBox(height: healthDp(context, 34)),
                  _buildFigmaSection(
                    title: '운동 습관',
                    onEdit: () => _openSectionForEdit(
                      [2],
                      screenTitle: '운동 습관',
                    ),
                    innerPadding: EdgeInsets.zero,
                    showBottomDivider: true,
                    child: _buildExerciseHabitsBody(profile),
                  ),
                  SizedBox(height: healthDp(context, 34)),
                  _buildFigmaSection(
                    title: '건강 정보',
                    onEdit: () => _openSectionForEdit([3], screenTitle: '건강 정보'),
                    innerPadding: EdgeInsets.zero,
                    showBottomDivider: true,
                    child: _buildHealthBody(profile),
                  ),
                  SizedBox(height: healthDp(context, 34)),
                  _buildDietExperienceSection(profile),
                  SizedBox(height: healthDp(context, 24)),
                  SizedBox(
                    width: double.infinity,
                    height: healthDp(context, 40),
                    child: FilledButton(
                      onPressed: _navigateToEditForm,
                      style: FilledButton.styleFrom(
                        backgroundColor: _kPink,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          horizontal: healthDp(context, 10),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 7)),
                        ),
                      ),
                      child: const Text(
                        '문진표 전체 수정',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: _kFont,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              SizedBox(height: healthDp(context, 100)),
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
                    width: healthDp(context, 3),
                    height: healthDp(context, 20),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 7)),
                      color: _kPink,
                    ),
                  ),
                  SizedBox(width: healthDp(context, 8)),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: _kInk,
                        fontSize: 16,
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
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: healthDp(context, 4),
                  horizontal: healthDp(context, 4),
                ),
                child: const Text(
                  '수정',
                  style: TextStyle(
                    color: _kPink,
                    fontSize: 12,
                    fontFamily: _kFont,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: healthDp(context, 20)),
        Padding(
          padding: innerPadding,
          child: child,
        ),
        if (showBottomDivider) ...[
          SizedBox(height: healthDp(context, 24)),
          Container(
            width: double.infinity,
            height: healthDp(context, 1),
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
                    width: healthDp(context, 5),
                    height: healthDp(context, 24),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 7)),
                      color: _kPink,
                    ),
                  ),
                  SizedBox(width: healthDp(context, 8)),
                  const Expanded(
                    child: Text(
                      '다이어트 약 경험',
                      style: TextStyle(
                        color: _kInk,
                        fontSize: 16,
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
                screenTitle: '다이어트 약 경험',
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: healthDp(context, 4),
                  horizontal: healthDp(context, 4),
                ),
                child: const Text(
                  '수정',
                  style: TextStyle(
                    color: _kPink,
                    fontSize: 12,
                    fontFamily: _kFont,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: healthDp(context, 20)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(healthDp(context, 20)),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: healthDp(context, 1),
                color: _kBorderField,
              ),
              borderRadius: BorderRadius.circular(healthDp(context, 7)),
            ),
          ),
          child: _buildDietDrugBody(profile),
        ),
        SizedBox(height: healthDp(context, 24)),
        Container(
          width: double.infinity,
          height: healthDp(context, 1),
          color: _kBorderField,
        ),
      ],
    );
  }

  Widget _metaRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontFamily: _kFont,
            fontWeight: FontWeight.w500,
            color: _kInk,
          ),
        ),
        SizedBox(width: healthDp(context, 10)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
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
    fontSize: 14,
    fontFamily: _kFont,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  Widget _readMetricBox(String value, String unit) {
    final v = value.trim().isEmpty ? '-' : value.trim();
    return Container(
      height: healthDp(context, 40),
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _kBorderField),
          borderRadius: BorderRadius.circular(healthDp(context, 7)),
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
              fontSize: 14,
              fontFamily: _kFont,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (v != '-')
            Text(
              unit,
              style: const TextStyle(
                color: _kInk,
                fontSize: 14,
                fontFamily: _kFont,
                fontWeight: FontWeight.w300,
              ),
            ),
        ],
      ),
    );
  }

  Widget _basicInfoGridItem({
    required String label,
    required Widget child,
    Color? labelColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: _listLabelStyle.copyWith(color: labelColor ?? _kInk),
        ),
        SizedBox(height: healthDp(context, 8)),
        child,
      ],
    );
  }

  Widget _buildBasicInfoBody(HealthProfileModel profile) {
    final g = profile.answer2;
    final goal = profile.answer3.trim().isEmpty ? '-' : profile.answer3.trim();
    final gridGap = healthDp(context, 10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _basicInfoGridItem(
                label: '생년월일',
                child: Container(
                  height: healthDp(context, 40),
                  padding:
                      EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
                  alignment: Alignment.centerLeft,
                  decoration: ShapeDecoration(
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: healthDp(context, 1),
                        color: _kBorderField,
                      ),
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 7)),
                    ),
                  ),
                  child: Text(
                    _birthDots(profile.answer1),
                    style: const TextStyle(
                      color: _kInk,
                      fontSize: 14,
                      fontFamily: _kFont,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: gridGap),
            Expanded(
              child: _basicInfoGridItem(
                label: '성별',
                child: _genderReadSegment(g == 'M', g == 'F'),
              ),
            ),
          ],
        ),
        SizedBox(height: gridGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _basicInfoGridItem(
                label: '목표',
                labelColor: _kPink,
                child: Container(
                  height: healthDp(context, 40),
                  padding:
                      EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
                  decoration: ShapeDecoration(
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: healthDp(context, 1),
                        color: _kBorderField,
                      ),
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 7)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        goal,
                        style: const TextStyle(
                          color: _kPink,
                          fontSize: 14,
                          fontFamily: _kFont,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (goal != '-')
                        const Text(
                          'kg',
                          style: TextStyle(
                            color: _kPink,
                            fontSize: 14,
                            fontFamily: _kFont,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: gridGap),
            Expanded(
              child: _basicInfoGridItem(
                label: '키/몸무게',
                child: Row(
                  children: [
                    Expanded(child: _readMetricBox(profile.answer4, 'cm')),
                    SizedBox(width: healthDp(context, 6)),
                    Expanded(child: _readMetricBox(profile.answer5, 'kg')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _genderReadSegment(bool male, bool female) {
    return Container(
      height: healthDp(context, 40),
      decoration: BoxDecoration(
        color: _kGenderTrack,
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
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
      margin: EdgeInsets.all(healthDp(context, 4)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
        border: Border.all(
          color: selected ? const Color(0x7F898686) : Colors.transparent,
          width: healthDp(context, 0.5),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
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
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 10),
        vertical: healthDp(context, 12),
      ),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _kBorderField),
          borderRadius: BorderRadius.circular(healthDp(context, 7)),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _kInk,
          fontSize: 14,
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
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 10),
        vertical: healthDp(context, 12),
      ),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _kBorderField),
          borderRadius: BorderRadius.circular(healthDp(context, 7)),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _kInk,
          fontSize: 14,
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
          fontSize: 9,
          fontWeight: FontWeight.w400,
          color: Colors.black54,
        ),
      );
    }
    return Wrap(
      spacing: healthDp(context, 6),
      runSpacing: healthDp(context, 6),
      children: items.map((t) => _chipWhitePlain(t)).toList(),
    );
  }

  Widget _buildDietHabitsBody(HealthProfileModel profile) {
    final mealParts = _pipeParts(profile.answer7);
    final mealItems = mealParts.isEmpty && profile.answer7.trim().isNotEmpty
        ? [profile.answer7.trim()]
        : mealParts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 4)),
          child: Text('하루 끼니', style: _listSubsectionStyle),
        ),
        SizedBox(height: healthDp(context, 8)),
        _wrapChipsWhite(mealItems),
        SizedBox(height: healthDp(context, 16)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 4)),
          child: Text('식사 시간', style: _listSubsectionStyle),
        ),
        SizedBox(height: healthDp(context, 8)),
        _buildMealTimeRowFigma(profile.answer71),
        SizedBox(height: healthDp(context, 16)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 4)),
          child: Text('식습관 정보', style: _listSubsectionStyle),
        ),
        SizedBox(height: healthDp(context, 8)),
        _wrapChipsWhite(_listItemsFromPipe(profile.answer8)),
        SizedBox(height: healthDp(context, 16)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 4)),
          child: Text('자주 먹는 음식', style: _listSubsectionStyle),
        ),
        SizedBox(height: healthDp(context, 8)),
        _wrapChipsWhite(_listItemsFromPipe(profile.answer9)),
      ],
    );
  }

  /// `answer_10` = 빈도, `answer102` = 주로 하는 운동(파이프). 구버전은 `answer_10`에 `###` 포함.
  Widget _buildExerciseHabitsBody(HealthProfileModel profile) {
    final freq = _exerciseFrequencyDisplay(profile.answer10);
    final types = _exerciseTypeItems(profile);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 4)),
          child: Text('운동 빈도', style: _listSubsectionStyle),
        ),
        SizedBox(height: healthDp(context, 8)),
        _buildExerciseFrequencyChips(freq),
        SizedBox(height: healthDp(context, 16)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 4)),
          child: Text('주로 하는 운동', style: _listSubsectionStyle),
        ),
        SizedBox(height: healthDp(context, 8)),
        types.isEmpty
            ? const Text(
                '-',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              )
            : _wrapChipsWhite(types),
      ],
    );
  }

  String _exerciseFrequencyDisplay(String answer10) {
    var raw = answer10.trim();
    if (raw.contains('###')) {
      raw = raw.split('###').first.trim();
    }
    if (raw == '일주일 4회 이상') return '일주일 4회 ~ 6회';
    return raw;
  }

  List<String> _exerciseTypeItems(HealthProfileModel profile) {
    final from102 = _listItemsFromPipe(profile.answer102);
    if (from102.isNotEmpty) return from102;
    final a10 = profile.answer10.trim();
    if (!a10.contains('###')) return [];
    final p = a10.split('###');
    if (p.length < 2) return [];
    final rest = p[1].trim();
    if (rest.isEmpty) return [];
    return rest
        .split(RegExp(r'\s*[,|]\s*'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Widget _buildExerciseFrequencyChips(String freq) {
    if (freq.isEmpty) {
      return const Text(
        '-',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          color: Colors.black54,
        ),
      );
    }
    final looksLikeWeeklyFreq = freq.contains('일주') ||
        freq.contains('매일') ||
        RegExp(r'주\s*\d').hasMatch(freq);
    return Wrap(
      spacing: healthDp(context, 6),
      runSpacing: healthDp(context, 6),
      children: [
        looksLikeWeeklyFreq ? _chipLightBorder(freq) : _chipWhitePlain(freq),
      ],
    );
  }

  List<String> _listItemsFromPipe(String raw) {
    final p = _pipeParts(raw);
    if (p.isNotEmpty) return p;
    final t = raw.trim();
    return t.isEmpty ? [] : [t];
  }

  Widget _buildMealTimeRowFigma(String answer71) {
    final parts = answer71.split('|');
    String at(int i) =>
        parts.length > i && parts[i].trim().isNotEmpty ? parts[i].trim() : '-';

    Widget slot(String tag, String time) {
      return Expanded(
        child: Container(
          height: healthDp(context, 50),
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 10),
            vertical: healthDp(context, 5),
          ),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: BorderSide(width: healthDp(context, 1), color: _kBorderField),
              borderRadius: BorderRadius.circular(healthDp(context, 7)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                tag,
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: _kFont,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF898383),
                  height: 1.3,
                ),
              ),
              SizedBox(height: healthDp(context, 2)),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 14,
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
        slot('1식', at(0)),
        SizedBox(width: healthDp(context, 6)),
        slot('2식', at(1)),
        SizedBox(width: healthDp(context, 6)),
        slot('3식', at(2)),
        SizedBox(width: healthDp(context, 6)),
        slot('4식', at(3)),
      ],
    );
  }

  Widget _buildHealthBody(HealthProfileModel profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 4)),
          child: Text('현재 질환', style: _listSubsectionStyle),
        ),
        SizedBox(height: healthDp(context, 8)),
        _healthDataChipsPipe(profile.answer11),
        SizedBox(height: healthDp(context, 16)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 4)),
          child: Text('복용중인 약', style: _listSubsectionStyle),
        ),
        SizedBox(height: healthDp(context, 8)),
        _healthDataChipsPipe(profile.answer12),
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
      return Wrap(
        spacing: healthDp(context, 4),
        runSpacing: healthDp(context, 4),
        children: [_healthDataChip('해당 없음')],
      );
    }
    final parts = _pipeParts(t);
    final items = parts.isEmpty ? [t] : parts;
    return Wrap(
      spacing: healthDp(context, 4),
      runSpacing: healthDp(context, 4),
      children: items.map(_healthDataChip).toList(),
    );
  }

  Widget _healthDataChip(String text) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 10),
        vertical: healthDp(context, 12),
      ),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _kBorderField),
          borderRadius: BorderRadius.circular(healthDp(context, 7)),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
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
        vertical: compact ? healthDp(context, 5) : healthDp(context, 10),
        horizontal: compact ? healthDp(context, 4) : healthDp(context, 8),
      ),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(healthDp(context, 4)),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: const Color(0x0C000000),
                  blurRadius: healthDp(context, 2),
                  offset: Offset(0, healthDp(context, 1)),
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: compact ? 12 : 14,
          fontWeight: selected ? FontWeight.w400 : FontWeight.w300,
          color: selected ? Color(0xFFFF5A8D) : _kMuted.withValues(alpha: 0.55),
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
                '최근 1년 내\n다이어트 약 복용',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _kInk,
                  height: 1.33,
                ),
              ),
            ),
            SizedBox(width: healthDp(context, 10)),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: healthDp(context, 128),
                minWidth: healthDp(context, 100),
              ),
              child: Container(
                padding: EdgeInsets.all(healthDp(context, 2)),
                decoration: BoxDecoration(
                  color: _kBorderField,
                  borderRadius: BorderRadius.circular(healthDp(context, 6)),
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
                    SizedBox(width: healthDp(context, 2)),
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
          SizedBox(height: healthDp(context, 16)),
          Container(
            padding: EdgeInsets.only(top: healthDp(context, 8)),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  width: healthDp(context, 1),
                  color: _kBorderField,
                ),
              ),
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
                    SizedBox(width: healthDp(context, 8)),
                    Expanded(
                      child: _dietDetailField(
                        '복용 기간',
                        profile.answer13Period,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: healthDp(context, 8)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _dietDetailField(
                        '복용 횟수',
                        profile.answer13Dosage,
                      ),
                    ),
                    SizedBox(width: healthDp(context, 8)),
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
      height: healthDp(context, 53),
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: healthDp(context, 4),
            top: 0,
            child: Text(
              label,
              style: const TextStyle(
                color: _kMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.5, // line ~15px
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: healthDp(context, 21),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: healthDp(context, 12),
                vertical: healthDp(context, 8),
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(healthDp(context, 8)),
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
        settings: const RouteSettings(name: HealthProfileFormScreen.routeName),
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
        settings: const RouteSettings(name: HealthProfileFormScreen.routeName),
        builder: (context) => HealthProfileFormScreen(
          existingProfile: _healthProfile,
        ),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  /// 카드별 수정: 이전/다음 없이 `수정하기`만. 식습관은 [1], 운동은 [2].
  void _openSectionForEdit(List<int> sectionIndices, {String? screenTitle}) async {
    if (sectionIndices.isEmpty) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: HealthProfileFormScreen.routeName),
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

