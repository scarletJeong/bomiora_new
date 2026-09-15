import 'package:flutter/material.dart';

import '../../../health/health_common/health_responsive_scale.dart';
import '../widgets/health_profile_common.dart';
import '../widgets/health_profile_form_session.dart';
import '../widgets/health_profile_form_widgets.dart';
import '../widgets/health_profile_prescription_booking_args.dart';
import '../models/health_profile_model.dart';

/// 문진표 4페이지 — 건강 정보
class HealthProfileForm4Screen extends StatefulWidget {
  static const String routeName = 'health_profile_form4';

  const HealthProfileForm4Screen({
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
  State<HealthProfileForm4Screen> createState() => _HealthProfileForm4State();
}

class _HealthProfileForm4State extends State<HealthProfileForm4Screen> {
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

  @override
  Widget build(BuildContext context) {
    return HealthProfileFormFrame(
      session: session,
      pageIndex: 3,
      isSectionEdit: isSectionEdit,
      editScreenTitle: widget.editScreenTitle,
      pinnedBottom: isSectionEdit
          ? HealthProfileSectionSubmitBar(session: session, onSubmit: _submit)
          : null,
      child: Form(
        key: _formKey,
        child: HealthProfileStepScroll(
          session: session,
          pageIndex: 3,
          showHero: isFullWizard,
          showBottomBar: isFullWizard,
          onNext: () {},
          onPrevious: () => Navigator.pop(context),
          onSubmit: _submit,
          questions: HealthProfileQuestionsColumn(
            session: session,
            stepIndex: 3,
            yesNo: _buildFigmaYesNoChips(),
          ),
        ),
      ),
    );
  }

  Widget _buildFigmaYesNoChips() {
    final v = session.formData['answer_13'];
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
                    final oldValue = session.formData['answer_13']?.toString();
                    session.formData['answer_13'] = '2';
                    final wasNoOrUnset = oldValue == null ||
                        oldValue.isEmpty ||
                        oldValue == '1' ||
                        oldValue == '없음';
                    if (wasNoOrUnset) {
                      session.formData['answer_13_medicine'] =
                          session.backupAnswer13Fields['answer_13_medicine'] ??
                              '';
                      session.formData['answer_13_period'] =
                          session.backupAnswer13Fields['answer_13_period'] ??
                              '';
                      session.formData['answer_13_dosage'] =
                          session.backupAnswer13Fields['answer_13_dosage'] ??
                              '';
                      session.formData['answer_13_sideeffect'] = session
                              .backupAnswer13Fields['answer_13_sideeffect'] ??
                          '';
                      session.dietDetailResetTick++;
                    }
                  });
                },
                child: Container(
                  height: healthDp(context, 40),
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: isYes
                        ? HealthProfileFormCommon.pinkSoft
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: healthDp(context, 1),
                        color: isYes
                            ? HealthProfileFormCommon.pink
                            : HealthProfileFormCommon.border,
                      ),
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 15)),
                    ),
                  ),
                  child: Text(
                    '있음',
                    style: TextStyle(
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: healthDp(context, 10)),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    session.formData['answer_13'] = '1';
                  });
                },
                child: Container(
                  height: healthDp(context, 40),
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: isNo
                        ? HealthProfileFormCommon.pinkSoft
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: healthDp(context, 1),
                        color: isNo
                            ? HealthProfileFormCommon.pink
                            : HealthProfileFormCommon.border,
                      ),
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 15)),
                    ),
                  ),
                  child: Text(
                    '없음',
                    style: TextStyle(
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                      color: isNo
                          ? const Color(0xFF1A1A1A)
                          : const Color(0xFF898383),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (session.shouldShowQuestion(
          HealthProfileQuestion(
            id: 'answer_13_medicine',
            question: '',
            type: 'text',
            isRequired: false,
          ),
        )) ...[
          SizedBox(height: healthDp(context, 20)),
          _buildDietDrugDetailCard(),
        ],
      ],
    );
  }

  Widget _buildDietDrugDetailCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 14)),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
              width: healthDp(context, 1),
              color: HealthProfileFormCommon.border),
          borderRadius: BorderRadius.circular(healthDp(context, 15)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '다이어트약 상세 정보',
                  style: TextStyle(
                    color: const Color(0xFF1A1A1E),
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      session.formData['answer_13_medicine'] = '';
                      session.formData['answer_13_period'] = '';
                      session.formData['answer_13_dosage'] = '';
                      session.formData['answer_13_sideeffect'] = '';
                      session.dietDetailResetTick++;
                    });
                  },
                  borderRadius: BorderRadius.circular(healthDp(context, 50)),
                  child: Container(
                    height: healthDp(context, 28),
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                            width: healthDp(context, 1),
                            color: HealthProfileFormCommon.border),
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 50)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh,
                          size: healthDp(context, 14),
                          color: const Color(0xFF898686),
                        ),
                        SizedBox(width: healthDp(context, 2)),
                        Text(
                          '초기화',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF898686),
                            fontSize: healthSp(context, 12),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: healthDp(context, 14)),
          Container(
              height: healthDp(context, 1),
              color: HealthProfileFormCommon.border),
          SizedBox(height: healthDp(context, 20)),
          _detailRow('복용 약명', 'answer_13_medicine', '약명'),
          SizedBox(height: healthDp(context, 20)),
          _detailRow('복용 기간', 'answer_13_period', '예: 1주'),
          SizedBox(height: healthDp(context, 20)),
          _detailRow('복용 횟수', 'answer_13_dosage', '예: 하루 1-2회'),
          SizedBox(height: healthDp(context, 20)),
          _detailRow('부작용', 'answer_13_sideeffect', '예: 잠이 안와요'),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String id, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF898686),
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: healthDp(context, 10)),
        SizedBox(
          height: healthDp(context, 45),
          child: TextFormField(
            key: ValueKey<String>('diet_$id:$session.dietDetailResetTick'),
            initialValue: session.formData[id]?.toString() ?? '',
            textAlignVertical: TextAlignVertical.center,
            style: TextStyle(
              color: const Color(0xFF1A1A1E),
              fontSize: healthSp(context, 14),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: const Color(0xFF898686),
                fontSize: healthSp(context, 14),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: EdgeInsets.symmetric(
                horizontal: healthDp(context, 10),
                vertical: 0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 15)),
                borderSide: BorderSide(
                    width: healthDp(context, 1),
                    color: HealthProfileFormCommon.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 15)),
                borderSide: BorderSide(
                    width: healthDp(context, 1),
                    color: HealthProfileFormCommon.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 15)),
                borderSide: BorderSide(
                    width: healthDp(context, 1),
                    color: const Color(0xFFFF5A8D)),
              ),
            ),
            onChanged: (v) {
              session.formData[id] = v;
              setState(() {});
            },
            onSaved: (v) => session.formData[id] = v ?? '',
          ),
        ),
      ],
    );
  }
}
