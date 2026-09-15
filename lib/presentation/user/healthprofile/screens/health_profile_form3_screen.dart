import 'package:flutter/material.dart';

import '../../../common/widgets/app_toast_overlay.dart';
import '../widgets/health_profile_form_session.dart';
import '../widgets/health_profile_form_widgets.dart';
import '../widgets/health_profile_prescription_booking_args.dart';
import '../models/health_profile_model.dart';
import 'health_profile_form4_screen.dart';

/// 문진표 3페이지 — 운동습관
class HealthProfileForm3Screen extends StatefulWidget {
  static const String routeName = 'health_profile_form3';

  const HealthProfileForm3Screen({
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
  State<HealthProfileForm3Screen> createState() => _HealthProfileForm3State();
}

class _HealthProfileForm3State extends State<HealthProfileForm3Screen> {
  late final HealthProfileFormSession session;
  late final bool _ownsSession;
  final _formKey = GlobalKey<FormState>();

  bool get isSectionEdit => widget.session == null;

  bool get isFullWizard => widget.session != null;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    session.removeListener(_onSession);
    if (_ownsSession) session.dispose();
    super.dispose();
  }

  Future<void> _submit() {
    return HealthProfileFormUi.submit(
      context: context,
      session: session,
      formKey: _formKey,
    );
  }

  void _goNext() {
    if (!session.isWizardStepFilled(2)) {
      AppToastOverlay.show(context, '모든 문진표를 작성해야합니다');
      _formKey.currentState?.validate();
      return;
    }
    _formKey.currentState?.save();
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: HealthProfileForm4Screen.routeName),
        builder: (_) => HealthProfileForm4Screen(
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
      pageIndex: 2,
      isSectionEdit: isSectionEdit,
      editScreenTitle: widget.editScreenTitle,
      pinnedBottom: isSectionEdit
          ? HealthProfileSectionSubmitBar(session: session, onSubmit: _submit)
          : null,
      child: Form(
        key: _formKey,
        child: HealthProfileStepScroll(
          session: session,
          pageIndex: 2,
          showHero: isFullWizard,
          showBottomBar: isFullWizard,
          onNext: _goNext,
          onPrevious: () => Navigator.pop(context),
          onSubmit: _submit,
          questions: HealthProfileQuestionsColumn(
            session: session,
            stepIndex: 2,
          ),
        ),
      ),
    );
  }
}
