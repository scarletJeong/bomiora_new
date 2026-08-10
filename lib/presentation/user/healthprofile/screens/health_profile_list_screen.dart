import 'package:flutter/material.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/health_profile_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/models/cart/cart_item_model.dart';
import '../models/health_profile_model.dart';
import '../health_profile_payload.dart';
import 'health_profile_form_screen.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/login_required_dialog.dart';
import '../../../common/widgets/centered_empty_state.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../../../shopping/screens/prescription_booking/prescription_time_screen.dart';
import '../../../shopping/widgets/prescription_booking_progress_bar.dart';

/// 처방 예약 플로우에서 문진표 확인 시 전달
class HealthProfilePrescriptionBookingArgs {
  final String productId;
  final String productName;
  final dynamic selectedOptions;
  final List<int>? cartCtIdsForCheckout;
  final List<CartItem>? checkoutCartItems;
  final int? checkoutShippingCost;

  const HealthProfilePrescriptionBookingArgs({
    required this.productId,
    required this.productName,
    this.selectedOptions,
    this.cartCtIdsForCheckout,
    this.checkoutCartItems,
    this.checkoutShippingCost,
  });
}

class HealthProfileListScreen extends StatefulWidget {
  final String appBarTitle;
  final bool appBarCenterTitle;
  final HealthProfilePrescriptionBookingArgs? prescriptionBooking;

  const HealthProfileListScreen({
    super.key,
    this.appBarTitle = '문진표',
    this.appBarCenterTitle = false,
    this.prescriptionBooking,
  });

  @override
  State<HealthProfileListScreen> createState() =>
      _HealthProfileListScreenState();
}

class _HealthProfileListScreenState extends State<HealthProfileListScreen> {
  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kInk = Color(0xFF1A1A1E);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kBorderSoft = Color(0x7FD2D2D2);
  static const Color _kCardBorder = Color(0xFFF1F5F9);
  static const Color _kChipBg = Color(0xFFFAFAFA);
  static const Color _kBmiYellow = Color(0xFFFACC15);
  static const String _kFont = 'Gmarket Sans TTF';

  UserModel? _currentUser;
  HealthProfileModel? _healthProfile;
  bool _isLoading = true;
  double _scrollProgress = 0;

  bool get _isPrescriptionBooking => widget.prescriptionBooking != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!_isPrescriptionBooking) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is! ScrollUpdateNotification &&
        notification is! ScrollEndNotification) {
      return false;
    }
    final next =
        prescriptionBookingScrollProgress(notification.metrics);
    if ((next - _scrollProgress).abs() < 0.001) return false;
    setState(() => _scrollProgress = next);
    return false;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthService.getUser();
      if (user != null) {
        setState(() => _currentUser = user);
        await _loadHealthProfile();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHealthProfile() async {
    try {
      _healthProfile =
          await HealthProfileService.getHealthProfile(_currentUser!.id);
    } catch (_) {
      _healthProfile = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: _kFont),
      primaryTextTheme: baseTheme.primaryTextTheme.apply(fontFamily: _kFont),
    );
    return Theme(
      data: gmarketTheme,
      child: MobileAppLayoutWrapper(
        appBar: HealthAppBar(
          title: widget.appBarTitle,
          centerTitle: widget.appBarCenterTitle,
          titleFontSize: healthSp(context, 16),
          leadingIconSize: healthDp(context, 24),
          bottom: _isPrescriptionBooking
              ? PrescriptionBookingProgressBar.asAppBarBottom(
                  currentStep: PrescriptionBookingSteps.questionnaire,
                  stepProgress: _scrollProgress,
                )
              : null,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _kPink))
            : NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: _buildContent(),
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
              fontFamily: _kFont,
              fontWeight: FontWeight.w500,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPink,
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

  // ─── Profile layout (Figma) ─────────────────────────────────────────────

  Widget _buildProfileCard() {
    final profile = _healthProfile!;

    return ColoredBox(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          healthDp(context, 27),
          healthDp(context, 20),
          healthDp(context, 27),
          healthDp(context, 20) + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionBlock(
              title: '기본정보',
              onEdit: () => _openSectionForEdit([0], screenTitle: '기본정보'),
              child: _buildBasicInfoCard(profile),
            ),
            SizedBox(height: healthDp(context, 30)),
            _sectionBlock(
              title: '식습관 및 운동',
              onEdit: () => _openSectionForEdit(
                [1, 2],
                screenTitle: '식습관 및 운동',
              ),
              child: _buildDietExerciseCard(profile),
            ),
            SizedBox(height: healthDp(context, 30)),
            _sectionBlock(
              title: '건강 정보',
              onEdit: () => _openSectionForEdit(
                [3],
                screenTitle: '건강 정보',
              ),
              child: _buildHealthInfoCard(profile),
            ),
            SizedBox(height: healthDp(context, 30)),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _sectionBlock({
    required String title,
    required VoidCallback onEdit,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: healthDp(context, 1),
              height: healthDp(context, 14),
              margin: EdgeInsets.only(right: healthDp(context, 6)),
              decoration: BoxDecoration(
                color: _kInk,
                borderRadius: BorderRadius.circular(healthDp(context, 50)),
              ),
            ),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: _kInk,
                  fontSize: healthSp(context, 16),
                  fontFamily: _kFont,
                  fontWeight: FontWeight.w500,
                  letterSpacing: healthSp(context, -1.44),
                  height: 1.2,
                ),
              ),
            ),
            SizedBox(width: healthDp(context, 8)),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onEdit,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: healthDp(context, 4),
                  vertical: healthDp(context, 4),
                ),
                child: Text(
                  '수정 >',
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: healthSp(context, 11),
                    fontFamily: _kFont,
                    fontWeight: FontWeight.w500,
                    letterSpacing: healthSp(context, -0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: healthDp(context, 14)),
        child,
      ],
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(healthDp(context, 12)),
        border: Border.all(color: _kCardBorder, width: healthDp(context, 1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x14000000),
            blurRadius: healthDp(context, 3),
            offset: Offset(0, healthDp(context, 1)),
          ),
        ],
      );

  // ─── 기본정보 ───────────────────────────────────────────────────────────

  Widget _buildBasicInfoCard(HealthProfileModel profile) {
    final name = (_currentUser?.name.trim().isNotEmpty ?? false)
        ? _currentUser!.name.trim()
        : '-';
    final genderLabel = profile.answer2 == 'M'
        ? '남'
        : profile.answer2 == 'F'
            ? '여'
            : '-';
    final nameGender =
        genderLabel == '-' ? name : '$name ($genderLabel)';

    final height = _asDouble(profile.answer4);
    final weight = _asDouble(profile.answer5);
    final a3 = _asDouble(profile.answer3);
    final bmi = (height != null && height > 0 && weight != null)
        ? weight / ((height / 100) * (height / 100))
        : null;
    final bmiLabel = _bmiCategory(bmi);

    // answer3: 신규=목표 체중, 레거시=감량량(작은 값). 목표 체중 / 목표까지 잔량 분리.
    double? goalWeight;
    double? remaining;
    if (a3 != null && weight != null) {
      if (a3 >= 30 && a3 <= 250) {
        goalWeight = a3;
        remaining = weight - a3;
      } else {
        remaining = a3;
        goalWeight = weight - a3;
      }
    } else if (a3 != null) {
      goalWeight = a3;
    }
    final toGoal = remaining != null ? -remaining : null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 14)),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _infoUnderlineRow('이름/성별', nameGender),
          _infoUnderlineRow('생년월일', _birthDots(profile.answer1)),
          _infoUnderlineRow(
            '키',
            height != null
                ? '${_trimNum(height)} cm'
                : (profile.answer4.trim().isEmpty
                    ? '-'
                    : '${profile.answer4.trim()} cm'),
          ),
          SizedBox(height: healthDp(context, 20)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(healthDp(context, 10)),
            decoration: BoxDecoration(
              color: _kChipBg,
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
              border: Border.all(color: const Color(0x0F000000), width: healthDp(context, 0.5)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'BMI',
                      style: TextStyle(
                        color: _kMuted,
                        fontSize: healthSp(context, 12),
                        fontFamily: _kFont,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: healthDp(context, 10)),
                    if (bmiLabel != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: healthDp(context, 8),
                          vertical: healthDp(context, 2),
                        ),
                        decoration: BoxDecoration(
                          color: bmiLabel.$2,
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 28)),
                          border: Border.all(color: bmiLabel.$2, width: healthDp(context, 1)),
                        ),
                        child: Text(
                          bmiLabel.$1,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: healthSp(context, 10),
                            fontFamily: _kFont,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      bmi != null ? bmi.toStringAsFixed(2) : '-',
                      style: TextStyle(
                        color: const Color(0xFF1A1A1A),
                        fontSize: healthSp(context, 16),
                        fontFamily: _kFont,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: healthDp(context, 10)),
                Row(
                  children: [
                    Expanded(
                      child: _weightStatCell(
                        label: '현재 체중',
                        value: weight != null ? _trimNum(weight) : '-',
                        valueColor: Colors.black,
                      ),
                    ),
                    Container(
                      width: healthDp(context, 1),
                      height: healthDp(context, 46),
                      color: _kBorderSoft,
                    ),
                    Expanded(
                      child: _weightStatCell(
                        label: '목표 체중까지',
                        value: toGoal != null
                            ? (toGoal > 0
                                ? '+${_trimNum(toGoal)}'
                                : _trimNum(toGoal))
                            : '-',
                        valueColor: _kPink,
                        unitColor: _kInk,
                      ),
                    ),
                    Container(
                      width: healthDp(context, 1),
                      height: healthDp(context, 46),
                      color: _kBorderSoft,
                    ),
                    Expanded(
                      child: _weightStatCell(
                        label: '목표 체중',
                        value: goalWeight != null ? _trimNum(goalWeight) : '-',
                        valueColor: Colors.black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: healthDp(context, 10)),
                Row(
                  children: [
                    Text(
                      '감량 기간',
                      style: TextStyle(
                        color: _kMuted,
                        fontSize: healthSp(context, 12),
                        fontFamily: _kFont,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      profile.answer6.trim().isEmpty
                          ? '-'
                          : profile.answer6.trim(),
                      style: TextStyle(
                        color: const Color(0xFF1A1A1A),
                        fontSize: healthSp(context, 14),
                        fontFamily: _kFont,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _weightStatCell({
    required String label,
    required String value,
    required Color valueColor,
    Color unitColor = const Color(0xFF1A1A1A),
  }) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: _kMuted,
              fontSize: healthSp(context, 12),
              fontFamily: _kFont,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: healthDp(context, 10)),
        Center(
          child: Container(
            width: healthDp(context, 75),
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 4),
              vertical: healthDp(context, 4),
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: valueColor,
                      fontSize: healthSp(context, 16),
                      fontFamily: _kFont,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (value != '-')
                    TextSpan(
                      text: ' kg',
                      style: TextStyle(
                        color: unitColor,
                        fontSize: healthSp(context, 12),
                        fontFamily: _kFont,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                ],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  // ─── 식습관 및 운동 ─────────────────────────────────────────────────────

  Widget _buildDietExerciseCard(HealthProfileModel profile) {
    final mealLabel = profile.answer7.trim().isEmpty
        ? '-'
        : profile.answer7.trim();
    final mealTimes = _mealTimes(profile.answer71);
    final habits = _listItemsFromPipe(profile.answer8);
    final foods = _listItemsFromPipe(profile.answer9);
    final freq = _exerciseFrequencyDisplay(profile.answer10);
    final types = _exerciseTypeItems(profile);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 14)),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _infoUnderlineRow(
            '하루식사',
            mealLabel,
            valueHeight: null,
            showUnderline: false,
          ),
          if (mealTimes.isNotEmpty) ...[
            SizedBox(height: healthDp(context, 10)),
            _mealTimeChipRow(mealTimes),
          ],
          SizedBox(height: healthDp(context, 20)),
          _labeledChipBlock('식습관', habits),
          SizedBox(height: healthDp(context, 20)),
          _labeledChipBlock('자주 먹는 음식', foods),
          SizedBox(height: healthDp(context, 12)),
          Container(
            width: double.infinity,
            height: healthDp(context, 1),
            color: _kBorderSoft,
          ),
          SizedBox(height: healthDp(context, 12)),
          _infoUnderlineRow(
            '운동 습관',
            freq.isEmpty ? '-' : freq,
            valueHeight: null,
            showUnderline: false,
          ),
          if (types.isNotEmpty) ...[
            SizedBox(height: healthDp(context, 10)),
            _chipWrap(types),
          ],
        ],
      ),
    );
  }

  // ─── 건강 정보 ──────────────────────────────────────────────────────────

  Widget _buildHealthInfoCard(HealthProfileModel profile) {
    final diseases = _healthItems(profile.answer11);
    final meds = _healthItems(profile.answer12);
    final a13 = profile.answer13.trim();
    final hasDietDrug = a13 == '2' || a13 == '있음';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 14)),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _labeledChipBlock('현재 질환', diseases),
          SizedBox(height: healthDp(context, 20)),
          _labeledChipBlock('복용 중인 약', meds),
          SizedBox(height: healthDp(context, 20)),
          Container(
            width: double.infinity,
            height: healthDp(context, 1),
            color: _kBorderSoft,
          ),
          SizedBox(height: healthDp(context, 20)),
          _infoUnderlineRow(
            '다이어트 약 복용 경험',
            hasDietDrug ? '있음' : '없음',
            valueHeight: null,
            labelWidth: 128,
            showUnderline: false,
          ),
          if (hasDietDrug) ...[
            SizedBox(height: healthDp(context, 10)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
              decoration: BoxDecoration(
                color: _kChipBg,
                borderRadius: BorderRadius.circular(healthDp(context, 15)),
                border: Border.all(color: const Color(0x0F000000), width: healthDp(context, 0.5)),
              ),
              child: Column(
                children: [
                  _infoUnderlineRow(
                    '복용 약명',
                    _dash(profile.answer13Medicine),
                  ),
                  _infoUnderlineRow(
                    '복용 기간',
                    _dash(profile.answer13Period),
                  ),
                  _infoUnderlineRow(
                    '복용 횟수',
                    _dash(profile.answer13Dosage),
                  ),
                  _infoUnderlineRow(
                    '부작용',
                    _dash(profile.answer13Sideeffect),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    final booking = widget.prescriptionBooking;
    if (booking != null) {
      return Row(
        children: [
          SizedBox(
            width: healthDp(context, 110),
            height: healthDp(context, 40),
            child: OutlinedButton(
              onPressed: _navigateToEditForm,
              style: OutlinedButton.styleFrom(
                foregroundColor: _kMuted,
                side: BorderSide(
                  width: healthDp(context, 0.5),
                  color: const Color(0xFFD2D2D2),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: healthDp(context, 6),
                  vertical: healthDp(context, 10),
                ),
              ),
              child: Text(
                '문진표 전체 수정',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _kMuted,
                  fontSize: healthSp(context, 11),
                  fontFamily: _kFont,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SizedBox(width: healthDp(context, 10)),
          Expanded(
            flex: 3,
            child: SizedBox(
              height: healthDp(context, 40),
              child: FilledButton(
                onPressed: () => _goToPrescriptionTime(booking),
                style: FilledButton.styleFrom(
                  backgroundColor: _kPink,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 10)),
                  ),
                  padding: EdgeInsets.all(healthDp(context, 10)),
                ),
                child: Text(
                  '다음',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: healthSp(context, 16),
                    fontFamily: _kFont,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      height: healthDp(context, 40),
      child: OutlinedButton(
        onPressed: _navigateToEditForm,
        style: OutlinedButton.styleFrom(
          foregroundColor: _kMuted,
          side: BorderSide(width: healthDp(context, 0.5), color: const Color(0xFFD2D2D2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
          ),
          padding: EdgeInsets.all(healthDp(context, 10)),
        ),
        child: Text(
          '문진표 전체 수정',
          style: TextStyle(
            color: _kMuted,
            fontSize: healthSp(context, 16),
            fontFamily: _kFont,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _goToPrescriptionTime(HealthProfilePrescriptionBookingArgs booking) {
    final profile = _healthProfile;
    if (profile == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrescriptionTimeScreen(
          productId: booking.productId,
          productName: booking.productName,
          selectedOptions: booking.selectedOptions,
          formData: HealthProfilePayload.formDataFromProfile(profile),
          existingProfile: profile,
          cartCtIdsForCheckout: booking.cartCtIdsForCheckout,
          checkoutCartItems: booking.checkoutCartItems,
          checkoutShippingCost: booking.checkoutShippingCost,
        ),
      ),
    );
  }

  // ─── Shared UI bits ─────────────────────────────────────────────────────

  Widget _infoUnderlineRow(
    String label,
    String value, {
    double? valueHeight = 45,
    bool showUnderline = true,
    double labelWidth = 88,
  }) {
    return Container(
      width: double.infinity,
      decoration: showUnderline
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  width: healthDp(context, 1),
                  color: _kBorderSoft,
                ),
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: healthDp(context, labelWidth),
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextStyle(
                color: _kMuted,
                fontSize: healthSp(context, 12),
                fontFamily: _kFont,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
          SizedBox(width: healthDp(context, 8)),
          Expanded(
            child: Container(
              constraints: BoxConstraints(
                minHeight: valueHeight == null
                    ? healthDp(context, 36)
                    : healthDp(context, valueHeight),
              ),
              alignment: Alignment.centerRight,
              padding: EdgeInsets.symmetric(vertical: healthDp(context, 10)),
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: _kInk,
                  fontSize: healthSp(context, 14),
                  fontFamily: _kFont,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labeledChipBlock(String label, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _kMuted,
            fontSize: healthSp(context, 12),
            fontFamily: _kFont,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
        SizedBox(height: healthDp(context, 12)),
        if (items.isEmpty)
          Text(
            '-',
            style: TextStyle(
              color: _kInk,
              fontSize: healthSp(context, 14),
              fontFamily: _kFont,
              fontWeight: FontWeight.w500,
            ),
          )
        else
          _chipWrap(items),
      ],
    );
  }

  Widget _chipWrap(List<String> items) {
    return Wrap(
      spacing: healthDp(context, 8),
      runSpacing: healthDp(context, 8),
      children: items.map(_pillChip).toList(),
    );
  }

  /// 식사시간 칩 — 동일 width, 한 줄
  Widget _mealTimeChipRow(List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final gap = healthDp(context, 8);
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: healthDp(context, 6),
                vertical: healthDp(context, 8),
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kChipBg,
                borderRadius: BorderRadius.circular(healthDp(context, 50)),
                border: Border.all(
                  color: const Color(0x0F000000),
                  width: healthDp(context, 0.5),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  items[i],
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _kInk,
                    fontSize: healthSp(context, 14),
                    fontFamily: _kFont,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _pillChip(String text) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 14),
        vertical: healthDp(context, 8),
      ),
      decoration: BoxDecoration(
        color: _kChipBg,
        borderRadius: BorderRadius.circular(healthDp(context, 50)),
        border: Border.all(color: const Color(0x0F000000), width: healthDp(context, 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: _kInk,
          fontSize: healthSp(context, 14),
          fontFamily: _kFont,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),
    );
  }

  // ─── Data helpers ───────────────────────────────────────────────────────

  double? _asDouble(String raw) {
    final t = raw.trim().replaceAll(',', '');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  String _trimNum(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  /// Asia-Pacific BMI cutoffs
  (String, Color)? _bmiCategory(double? bmi) {
    if (bmi == null) return null;
    if (bmi < 18.5) return ('저체중', const Color(0xFF60A5FA));
    if (bmi < 23) return ('정상', const Color(0xFF4ADE80));
    if (bmi < 25) return ('과체중', _kBmiYellow);
    if (bmi < 30) return ('비만', const Color(0xFFFB923C));
    return ('고도비만', const Color(0xFFEF4444));
  }

  List<String> _pipeParts(String s) {
    if (s.isEmpty) return [];
    return s
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<String> _listItemsFromPipe(String raw) {
    final p = _pipeParts(raw);
    if (p.isNotEmpty) return p;
    final t = raw.trim();
    return t.isEmpty ? [] : [t];
  }

  List<String> _healthItems(String raw) {
    final t = raw.trim();
    if (t.isEmpty || t == '없음' || t == '해당 없음' || t == '해당없음') {
      return ['해당 없음'];
    }
    return _listItemsFromPipe(t).map((e) {
      if (e.startsWith('기타:')) {
        final name = e.substring(3).trim();
        return name.isEmpty ? '기타' : name;
      }
      return e;
    }).toList();
  }

  List<String> _mealTimes(String answer71) {
    return answer71
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != '-')
        .toList();
  }

  String _birthDots(String raw) {
    if (raw.isEmpty) return '-';
    if (raw.length == 8) {
      return '${raw.substring(0, 4)}.${raw.substring(4, 6)}.${raw.substring(6, 8)}';
    }
    return raw.replaceAll('-', '.');
  }

  String _dash(String v) => v.trim().isEmpty ? '-' : v.trim();

  String _exerciseFrequencyDisplay(String answer10) {
    var raw = answer10.trim();
    if (raw.contains('###')) {
      raw = raw.split('###').first.trim();
    }
    if (raw == '일주일 4회 이상') return '일주일 4회 ~ 6회';
    if (raw == '일주일 2~3회' || raw == '일주일 2~ 3회') {
      return '일주일 2회 ~ 3회';
    }
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

  // ─── Navigation ─────────────────────────────────────────────────────────

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
    if (result == true) _loadData();
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
    if (result == true) _loadData();
  }

  void _openSectionForEdit(
    List<int> sectionIndices, {
    String? screenTitle,
  }) async {
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
    if (result == true) _loadData();
  }
}
