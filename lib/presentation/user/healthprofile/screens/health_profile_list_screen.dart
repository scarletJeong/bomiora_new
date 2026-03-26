import 'package:flutter/material.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/health_profile_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../models/health_profile_model.dart';
import 'health_profile_form_screen.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_bar.dart';

class HealthProfileListScreen extends StatefulWidget {
  const HealthProfileListScreen({super.key});

  @override
  State<HealthProfileListScreen> createState() => _HealthProfileListScreenState();
}

class _HealthProfileListScreenState extends State<HealthProfileListScreen> {
  static const Color _kAccentBar = Color(0xFFFF5A8D);
  static const Color _kCardBg = Color(0xFFF8F9FA);
  static const Color _kInkTitle = Color(0xFF191C1D);
  static const Color _kLabelBrown = Color(0xFF584045);
  static const Color _kBorderLight = Color(0xFFF1F5F9);
  static const Color _kSegmentTrack = Color(0x7FE2E8F0);

  static const TextStyle _listSubsectionStyle = TextStyle(
    color: _kLabelBrown,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.5,
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
      appBar: const HealthAppBar(title: '건강프로필'),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
              ? _buildLoginRequired()
              : _buildContent(),
    );
  }

  Widget _buildLoginRequired() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.login,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '로그인이 필요합니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '건강프로필를 작성하려면 로그인해주세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 12,
              ),
            ),
            child: const Text('로그인'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_healthProfile == null) {
      return _buildEmptyState();
    }

    return _buildProfileCard();
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.assignment_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            '건강프로필가 없습니다',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '다이어트 상담을 위해\n건강프로필를 작성해주세요',
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
            label: const Text('건강프로필 작성하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 300),
          // const AppFooter(),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final profile = _healthProfile!;

    return DefaultTextStyle.merge(
      style: const TextStyle(
        fontFamily: 'Gmarket Sans TTF',
        color: _kInkTitle,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFigmaSection(
                  title: '기본 정보',
                  onEdit: () => _openSectionForEdit([0], screenTitle: '기본 정보'),
                  innerPadding: const EdgeInsets.all(12),
                  child: _buildBasicInfoBody(profile),
                ),
                const SizedBox(height: 24),
                _buildFigmaSection(
                  title: '식습관 및 운동',
                  onEdit: () => _openSectionForEdit(
                    [1, 2],
                    screenTitle: '식습관 및 운동',
                  ),
                  innerPadding: const EdgeInsets.all(16),
                  child: _buildDietAndExerciseBody(profile),
                ),
                const SizedBox(height: 24),
                _buildFigmaSection(
                  title: '건강 상태',
                  onEdit: () => _openSectionForEdit([3], screenTitle: '건강 상태'),
                  innerPadding: const EdgeInsets.all(16),
                  child: _buildHealthBody(profile),
                ),
                const SizedBox(height: 24),
                _buildDietExperienceSection(profile),
                const SizedBox(height: 24),
                _buildMetaCard(profile),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _navigateToEditForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3787),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: const Text(
                      '건강프로필 전체 수정',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 100),
                // const AppFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFigmaSection({
    required String title,
    required VoidCallback onEdit,
    required Widget child,
    EdgeInsetsGeometry innerPadding = const EdgeInsets.all(16),
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _kAccentBar,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: _kInkTitle,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.43,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onEdit,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Text(
                    '수정',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _kAccentBar,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: innerPadding,
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildDietExperienceSection(HealthProfileModel profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _kAccentBar,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '다이어트 경험',
                    style: TextStyle(
                      color: _kInkTitle,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.43,
                    ),
                  ),
                ],
              ),
              const Spacer(),
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
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _kAccentBar,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorderLight),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: _buildDietDrugBody(profile),
        ),
      ],
    );
  }

  Widget _buildMetaCard(HealthProfileModel profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '건강프로필 정보',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kInkTitle,
            ),
          ),
          const SizedBox(height: 10),
          _metaRow('작성일', _formatDate(profile.pfWdatetime)),
          _metaRow('수정일', _formatDate(profile.pfMdatetime)),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: _kLabelBrown,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _kInkTitle,
              ),
            ),
          ),
        ],
      ),
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
    color: _kLabelBrown,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    height: 1.5,
  );

  Widget _whiteReadBox(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white),
      ),
      child: child,
    );
  }

  Widget _buildBasicInfoBody(HealthProfileModel profile) {
    final g = profile.answer2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('생년월일', style: _listLabelStyle),
                  const SizedBox(height: 6),
                  _whiteReadBox(
                    Text(
                      _birthDots(profile.answer1),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.33,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('성별', style: _listLabelStyle),
                  const SizedBox(height: 6),
                  _genderReadSegment(g == 'M', g == 'F'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _metricCompactColumn(
                label: '키',
                value: profile.answer4,
                unit: 'cm',
                emphasize: false,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _metricCompactColumn(
                label: '체중',
                value: profile.answer5,
                unit: 'kg',
                emphasize: false,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _metricCompactColumn(
                label: '목표',
                value: profile.answer3,
                unit: 'kg',
                emphasize: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metricCompactColumn({
    required String label,
    required String value,
    required String unit,
    required bool emphasize,
  }) {
    final v = value.trim().isEmpty ? '-' : value.trim();
    final labelColor = emphasize ? _kAccentBar : _kLabelBrown;
    final valueColor = emphasize ? _kAccentBar : _kInkTitle;
    final borderColor =
        emphasize ? const Color(0x33FF5A8D) : _kBorderLight;

    return Container(
      width: double.infinity,
      height: 30.5,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: 1, color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
            Text(
              v,
              style: TextStyle(
                color: valueColor,
                fontSize: 11,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
              if (v != '-') ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w300,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _genderReadSegment(bool male, bool female) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: _kSegmentTrack,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: _genderReadSide('남성', male)),
          Expanded(child: _genderReadSide('여성', female)),
        ],
      ),
    );
  }

  Widget _genderReadSide(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
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
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.5,
          color: selected ? _kAccentBar : _kLabelBrown.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  /// 식습관·음식 등: 흰 배경 + 흰 테두리(카드 위에서 은은히 구분), 글자 검정
  Widget _chipWhitePlain(String text, {FontWeight fontWeight = FontWeight.w400}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.black,
          fontSize: 11,
          fontWeight: fontWeight,
          height: 1.5,
        ),
      ),
    );
  }

  /// 운동 빈도(일주일 …)만 연한 테두리
  Widget _chipLightBorder(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorderLight),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.w400,
          height: 1.5,
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tag,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w400,
                  color: _kLabelBrown,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                  height: 1.5,
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
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [_healthDataChip('없음')],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: Colors.black,
          height: 1.5,
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
          color: selected ? Colors.black : _kLabelBrown.withValues(alpha: 0.55),
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
                  color: _kInkTitle,
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
                  color: _kBorderLight,
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
              border: Border(top: BorderSide(color: _kBorderLight)),
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
                color: _kLabelBrown,
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
                  color: _kInkTitle,
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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

