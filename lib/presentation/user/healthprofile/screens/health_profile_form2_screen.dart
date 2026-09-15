import 'package:flutter/material.dart';

import '../../../common/widgets/app_toast_overlay.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../widgets/health_profile_common.dart';
import '../widgets/health_profile_form_session.dart';
import '../widgets/health_profile_form_widgets.dart';
import '../widgets/health_profile_prescription_booking_args.dart';
import '../models/health_profile_model.dart';

import 'health_profile_form3_screen.dart';

/// 문진표 2페이지 — 식습관
class HealthProfileForm2Screen extends StatefulWidget {
  static const String routeName = 'health_profile_form2';

  const HealthProfileForm2Screen({
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
  State<HealthProfileForm2Screen> createState() => _HealthProfileForm2State();
}

class _HealthProfileForm2State extends State<HealthProfileForm2Screen> {
  late final HealthProfileFormSession session;
  late final bool _ownsSession;
  final _formKey = GlobalKey<FormState>();

  bool get isSectionEdit => widget.session == null;

  bool get isFullWizard => widget.session != null;

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

  @override
  void initState() {
    super.initState();
    _bindSession();
  }

  @override
  void dispose() {
    _unbindSession();
    super.dispose();
  }

  void _goNext() {
    if (!session.isWizardStepFilled(1)) {
      AppToastOverlay.show(context, '모든 문진표를 작성해야합니다');
      _formKey.currentState?.validate();
      return;
    }
    _formKey.currentState?.save();
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: HealthProfileForm3Screen.routeName),
        builder: (_) => HealthProfileForm3Screen(
          session: session,
          prescriptionBooking:
              widget.prescriptionBooking ?? session.prescriptionBooking,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final questions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HealthProfileQuestionsColumn(
          session: session,
          stepIndex: 1,
          mealtime: _buildFigmaMealtimeTable(),
        ),
        if (mergeDietExercise) ...[
          SizedBox(height: healthDp(context, 20)),
          HealthProfileQuestionsColumn(
            session: session,
            stepIndex: 2,
          ),
        ],
      ],
    );

    return HealthProfileFormFrame(
      session: session,
      pageIndex: 1,
      isSectionEdit: isSectionEdit,
      editScreenTitle: widget.editScreenTitle,
      pinnedBottom: isSectionEdit
          ? HealthProfileSectionSubmitBar(session: session, onSubmit: _submit)
          : null,
      child: Form(
        key: _formKey,
        child: mergeDietExercise
            ? SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  healthDp(context, 20),
                  healthDp(context, 20),
                  healthDp(context, 20),
                  healthDp(context, 16),
                ),
                child: questions,
              )
            : HealthProfileStepScroll(
                session: session,
                pageIndex: 1,
                showHero: isFullWizard,
                showBottomBar: isFullWizard,
                onNext: _goNext,
                onPrevious: () => Navigator.pop(context),
                onSubmit: _submit,
                questions: questions,
              ),
      ),
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
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
              width: healthDp(context, 1),
              color: HealthProfileFormCommon.border),
          borderRadius: BorderRadius.circular(healthDp(context, 15)),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < slots.length; i++) ...[
              if (i > 0)
                Container(
                    width: healthDp(context, 1),
                    color: HealthProfileFormCommon.border),
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
    final raw = (session.formData[fieldKey]?.toString() ?? '').trim();
    final display = raw.isEmpty ? '-' : raw;
    final empty = raw.isEmpty || raw == '-';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showMealTimePickerBottomSheet(fieldKey),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(healthDp(context, 14)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
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
                  height: 1,
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
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMealTimePickerBottomSheet(String fieldKey) async {
    final raw = (session.formData[fieldKey]?.toString() ?? '').trim();
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
                        setState(() {
                          session.formData[fieldKey] = value;
                          HealthProfileFormCommon.applyUnusedMealDash(
                            session.formData,
                            justSetKey: fieldKey,
                          );
                        });
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
}
