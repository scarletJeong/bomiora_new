import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../common/widgets/app_toast_overlay.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../widgets/health_profile_common.dart';
import '../widgets/health_profile_form_session.dart';
import '../widgets/health_profile_form_widgets.dart';
import '../widgets/health_profile_prescription_booking_args.dart';
import '../widgets/health_profile_questionnaire_options.dart';
import '../models/health_profile_model.dart';

import 'health_profile_form2_screen.dart';

/// 문진표 1페이지 — 기본정보
class HealthProfileForm1Screen extends StatefulWidget {
  static const String routeName = 'health_profile_form1';

  const HealthProfileForm1Screen({
    super.key,
    this.session,
    this.existingProfile,
    this.initialSectionIndices,
    this.editScreenTitle,
    this.prescriptionBooking,
  });

  final HealthProfileFormSession? session;
  final HealthProfileModel? existingProfile;
  final List<int>? initialSectionIndices;
  final String? editScreenTitle;
  final HealthProfilePrescriptionBookingArgs? prescriptionBooking;

  @override
  State<HealthProfileForm1Screen> createState() => _HealthProfileForm1State();
}

class _HealthProfileForm1State extends State<HealthProfileForm1Screen> {
  late final HealthProfileFormSession session;
  late final bool _ownsSession;
  final _formKey = GlobalKey<FormState>();

  bool get isSectionEdit =>
      widget.initialSectionIndices != null &&
      widget.initialSectionIndices!.isNotEmpty;

  bool get isFullWizard => !isSectionEdit;

  bool get mergeDietExercise {
    final subs = widget.initialSectionIndices;
    return subs != null && subs.length == 2 && subs[0] == 1 && subs[1] == 2;
  }

  void _bindSession() {
    if (widget.session != null) {
      session = widget.session!;
      _ownsSession = false;
    } else {
      session = HealthProfileFormSession(
        existingProfile: widget.existingProfile,
        prescriptionBooking: widget.prescriptionBooking,
      );
      _ownsSession = true;
      session.load();
    }
    session.addListener(_onSession);
  }

  void _onSession() {
    if (mounted) setState(() {});
  }

  void _unbindSession() {
    session.removeListener(_onSession);
    if (_ownsSession) session.dispose();
  }

  Future<void> _submit() {
    return HealthProfileFormUi.submit(
      context: context,
      session: session,
      formKey: _formKey,
    );
  }

  OverlayEntry? _bmiGuideOverlay;
  final GlobalKey _bmiGuideIconKey = GlobalKey();
  OverlayEntry? _answer6MenuOverlay;
  ScrollController? _answer6MenuScrollController;
  final GlobalKey _answer6FieldKey = GlobalKey();
  bool _goalWeightInvalid = false;
  bool _goalWeightHintVisible = false;
  Timer? _goalWeightHintTimer;

  @override
  void initState() {
    super.initState();
    _bindSession();
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
    _unbindSession();
    super.dispose();
  }

  void _goNext() {
    if (!session.isWizardStepFilled(0)) {
      AppToastOverlay.show(context, '모든 문진표를 작성해야합니다');
      _formKey.currentState?.validate();
      return;
    }
    _formKey.currentState?.save();
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: HealthProfileForm2Screen.routeName),
        builder: (_) => HealthProfileForm2Screen(
          session: session,
          prescriptionBooking:
              widget.prescriptionBooking ?? session.prescriptionBooking,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HealthProfileFormFrame(
      session: session,
      pageIndex: 0,
      isSectionEdit: isSectionEdit,
      editScreenTitle: widget.editScreenTitle,
      pinnedBottom: isSectionEdit
          ? HealthProfileSectionSubmitBar(session: session, onSubmit: _submit)
          : null,
      child: Form(
        key: _formKey,
        child: HealthProfileStepScroll(
          session: session,
          pageIndex: 0,
          showHero: isFullWizard,
          showBottomBar: isFullWizard,
          onNext: _goNext,
          onPrevious: () => Navigator.pop(context),
          onSubmit: _submit,
          questions: HealthProfileQuestionsColumn(
            session: session,
            stepIndex: 0,
            basicInfo: _buildFigmaBirthAndGender(),
          ),
        ),
      ),
    );
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
    final gap = healthDp(context, 8);
    final left = iconTopLeft.dx + iconSize.width + gap;
    final top = iconTopLeft.dy;

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
          side: BorderSide(
              width: healthDp(context, 1),
              color: HealthProfileFormCommon.border),
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

  double _figmaLabeledControlHeight(BuildContext context) =>
      healthDp(context, 45);

  Widget _buildFigmaBirthAndGender() {
    final height = double.tryParse(
      (session.formData['answer_4']?.toString() ?? '').replaceAll(',', ''),
    );
    final weight = double.tryParse(
      (session.formData['answer_5']?.toString() ?? '').replaceAll(',', ''),
    );
    final goal = double.tryParse(
      (session.formData['answer_3']?.toString() ?? '').replaceAll(',', ''),
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
                child: Container(
                  height: _figmaLabeledControlHeight(context),
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 10),
                  ),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: healthDp(context, 1),
                        color: HealthProfileFormCommon.border,
                      ),
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 15)),
                    ),
                  ),
                  child: TextFormField(
                    key: ValueKey<int>(session.wizardBirthFieldKeySeed),
                    initialValue: session.birthYyyymmddDisplay(),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    style: _figmaFieldTextStyle(context),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      hintText: 'YYYYMMDD',
                      hintStyle: TextStyle(
                        color: const Color(0xFF898686),
                        fontSize: healthSp(context, 14),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                        height: 1.2,
                      ),
                      errorStyle: const TextStyle(height: 0, fontSize: 0),
                    ),
                    onChanged: (v) {
                      final s = v.trim();
                      if (!mounted) return;
                      setState(() {
                        session.formData['answer_1'] = s;
                        if (s.length == 8) {
                          session.formData['birth_year'] = s.substring(0, 4);
                          session.formData['birth_month'] = s.substring(4, 6);
                          session.formData['birth_day'] = s.substring(6, 8);
                        } else {
                          session.formData['birth_year'] = '';
                          session.formData['birth_month'] = '';
                          session.formData['birth_day'] = '';
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
                        session.formData['answer_1'] = s;
                        session.formData['birth_year'] = s.substring(0, 4);
                        session.formData['birth_month'] = s.substring(4, 6);
                        session.formData['birth_day'] = s.substring(6, 8);
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
                  initialValue: session.formData['answer_2']?.toString(),
                  validator: (v) {
                    final g =
                        (v ?? session.formData['answer_2']?.toString() ?? '')
                            .trim();
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
                            selected: session.formData['answer_2'] == 'F',
                            onTap: () {
                              setState(
                                  () => session.formData['answer_2'] = 'F');
                              state.didChange('F');
                            },
                          ),
                        ),
                        SizedBox(width: healthDp(context, 8)),
                        Expanded(
                          child: _genderChip(
                            label: '남',
                            selected: session.formData['answer_2'] == 'M',
                            onTap: () {
                              setState(
                                  () => session.formData['answer_2'] = 'M');
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
                    width: healthDp(context, 51),
                    height: healthDp(context, 24),
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 4),
                    ),
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: bmiCat.$2,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 50)),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        bmiCat.$1,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: healthSp(context, 11),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
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
                      width: healthSp(context, 14),
                      height: healthSp(context, 14),
                    ),
                  ),
                ),
                child: _suffixField(
                  questionId: 'answer_5',
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
                      text: remaining >= 0 ? ' - ' : ' + ',
                      style: TextStyle(
                        color: HealthProfileFormCommon.pink,
                        fontSize: healthSp(context, 12),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextSpan(
                      text:
                          '${remaining.abs() == remaining.abs().roundToDouble() ? remaining.abs().toStringAsFixed(0) : remaining.abs().toStringAsFixed(1)} kg ',
                      style: TextStyle(
                        color: HealthProfileFormCommon.pink,
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
                height: 1,
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
    return ('고도비만', const Color(0xFFF87171));
  }

  TextStyle _figmaFieldTextStyle(BuildContext context) => TextStyle(
        color: const Color(0xFF1A1A1A),
        fontSize: healthSp(context, 14),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w500,
        height: 1.2,
      );

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
              color: selected
                  ? const Color(0xFFFF5A8D)
                  : HealthProfileFormCommon.border,
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
            height: 1.2,
          ),
        ),
      ),
    );
  }

  void _checkGoalWeightAgainstCurrent() {
    final tooHigh = session.isGoalWeightTooHigh();
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
    String hint = '',
    required String suffix,
    required String requiredMsg,
    bool allowDecimal = false,
    bool forcePinkBorder = false,
    String? transientErrorText,
    VoidCallback? onAfterChanged,
  }) {
    return FormField<String>(
      initialValue: (session.formData[questionId]?.toString() ?? '').trim(),
      validator: (v) {
        final s = (v ?? '').trim();
        if (s.isEmpty) return requiredMsg;
        if (questionId == 'answer_3' && session.isGoalWeightTooHigh()) {
          return '현재 체중보다 낮게만 입력해주세요';
        }
        return null;
      },
      onSaved: (v) => session.formData[questionId] = (v ?? '').trim(),
      builder: (state) {
        final showTransient =
            transientErrorText != null && transientErrorText.isNotEmpty;
        final showFormError = state.hasError && !showTransient;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StatefulBuilder(
              builder: (context, setLocal) {
                return Focus(
                  onFocusChange: (_) => setLocal(() {}),
                  child: Builder(
                    builder: (context) {
                      final focused = Focus.of(context).hasFocus;
                      final borderColor = forcePinkBorder || focused
                          ? HealthProfileFormCommon.pink
                          : HealthProfileFormCommon.border;
                      return Container(
                        height: _figmaLabeledControlHeight(context),
                        alignment: Alignment.centerLeft,
                        padding: EdgeInsets.symmetric(
                          horizontal: healthDp(context, 10),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 15)),
                          border: Border.all(
                            width: healthDp(context, 1),
                            color: borderColor,
                          ),
                        ),
                        child: Transform.translate(
                          offset: Offset(0, healthDp(context, -2.1)),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: state.value,
                                  textAlignVertical: TextAlignVertical.center,
                                  keyboardType: allowDecimal
                                      ? const TextInputType.numberWithOptions(
                                          decimal: true,
                                        )
                                      : TextInputType.number,
                                  inputFormatters: [
                                    if (allowDecimal)
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]'),
                                      )
                                    else
                                      FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  style: _figmaFieldTextStyle(context),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    isCollapsed: true,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    hintText: hint.isEmpty ? null : hint,
                                    hintStyle: TextStyle(
                                      color: const Color(0xFF898686),
                                      fontSize: healthSp(context, 14),
                                      fontFamily: 'Gmarket Sans TTF',
                                      fontWeight: FontWeight.w300,
                                      height: 1.2,
                                    ),
                                    errorStyle: const TextStyle(
                                      height: 0,
                                      fontSize: 0,
                                    ),
                                  ),
                                  onChanged: (v) {
                                    state.didChange(v);
                                    if (!mounted) return;
                                    setState(() {
                                      session.formData[questionId] = v.trim();
                                    });
                                    onAfterChanged?.call();
                                  },
                                  validator: (_) => null,
                                  onSaved: (_) {},
                                ),
                              ),
                              SizedBox(width: healthDp(context, 8)),
                              Text(
                                suffix,
                                style: _figmaFieldTextStyle(context),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            if (showTransient || showFormError) ...[
              SizedBox(height: healthDp(context, 4)),
              SizedBox(
                height: healthDp(context, 14),
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
                          ? HealthProfileFormCommon.pink
                          : Theme.of(context).colorScheme.error,
                      fontSize: healthSp(context, 10),
                      fontFamily: 'Gmarket Sans TTF',
                      height: 1.0,
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
    const options = HealthProfileQuestionnaireOptions.dietPeriod;
    final current = session.formData['answer_6']?.toString().trim() ?? '';
    final selected =
        current.isEmpty || !options.contains(current) ? null : current;
    return FormField<String>(
      // initialValue는 첫 마운트에만 적용되므로, 값이 바뀔 때마다 필드를 재생성해 표시·검증이 session.formData와 일치하게 함
      key: ValueKey<String>('answer6|${selected ?? ''}'),
      initialValue: selected,
      validator: (v) {
        final val =
            (v ?? session.formData['answer_6']?.toString() ?? '').trim();
        if (val.isEmpty) return '기간을 선택해주세요';
        return null;
      },
      onSaved: (v) {
        final s = (v ?? session.formData['answer_6']?.toString() ?? '').trim();
        if (s.isNotEmpty) session.formData['answer_6'] = s;
      },
      builder: (state) {
        final label = selected ?? '선택';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              key: _answer6FieldKey,
              height: _figmaLabeledControlHeight(context),
              padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    width: healthDp(context, 1),
                    color: HealthProfileFormCommon.border,
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
                      session.formData['answer_6'] = v;
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
                          fontWeight: selected == null
                              ? FontWeight.w300
                              : FontWeight.w500,
                          height: 1.2,
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
    final current = session.formData['answer_6']?.toString().trim() ?? '';

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
            healthDp(ctx, 20),
            healthDp(ctx, 12),
            healthDp(ctx, 20),
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
                    return _Answer6OptionTile(
                      label: opt,
                      selected: opt == current,
                      fontSize: healthSp(ctx, 16),
                      verticalPadding: healthDp(ctx, 14),
                      onTap: () {
                        onSelected(opt);
                        Navigator.of(ctx).pop();
                      },
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
}

class _Answer6OptionTile extends StatefulWidget {
  const _Answer6OptionTile({
    required this.label,
    required this.selected,
    required this.fontSize,
    required this.verticalPadding,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double fontSize;
  final double verticalPadding;
  final VoidCallback onTap;

  @override
  State<_Answer6OptionTile> createState() => _Answer6OptionTileState();
}

class _Answer6OptionTileState extends State<_Answer6OptionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = _hovered || widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: widget.verticalPadding),
          decoration: highlighted
              ? const ShapeDecoration(
                  color: Color(0x19FF5A8D),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      width: 0.30,
                      color: Color(0x7FD2D2D2),
                    ),
                  ),
                )
              : null,
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF1A1A1E),
              fontSize: widget.fontSize,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: widget.selected ? FontWeight.w500 : FontWeight.w300,
            ),
          ),
        ),
      ),
    );
  }
}
