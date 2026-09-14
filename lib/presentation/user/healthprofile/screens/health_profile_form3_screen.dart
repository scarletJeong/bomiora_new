part of 'health_profile_form_screen.dart';

/// 문진표 3페이지 진입 — 운동습관
class HealthProfileForm3Screen extends StatelessWidget {
  static const String routeName = 'health_profile_form3';

  const HealthProfileForm3Screen({
    super.key,
    this.existingProfile,
    this.initialSectionIndices,
    this.editScreenTitle,
    this.prescriptionBooking,
  });

  final HealthProfileModel? existingProfile;
  final List<int>? initialSectionIndices;
  final String? editScreenTitle;
  final HealthProfilePrescriptionBookingArgs? prescriptionBooking;

  @override
  Widget build(BuildContext context) {
    return HealthProfileFormShell(
      existingProfile: existingProfile,
      initialSectionIndices: initialSectionIndices ?? const [2],
      editScreenTitle: editScreenTitle,
      initialWizardIndex: 2,
      prescriptionBooking: prescriptionBooking,
    );
  }
}

mixin HealthProfileForm3Ui on _HealthProfileFormState {
  void _applyLoadedExerciseTypes(List<String> loaded) {
    final known = HealthProfileQuestionnaireOptions.exerciseTypes.toSet();
    final selected = <String>[];
    final others = <String>[];
    for (final raw in loaded) {
      final t = raw.trim();
      if (t.isEmpty) continue;
      if (t == '기타') {
        if (!selected.contains('기타')) selected.add('기타');
        continue;
      }
      if (known.contains(t)) {
        if (!selected.contains(t)) selected.add(t);
      } else {
        if (!others.contains(t)) others.add(t);
      }
    }
    if (others.isNotEmpty && !selected.contains('기타')) {
      selected.add('기타');
    }
    _formData['answer_10_types'] = selected;
    _exerciseOthers
      ..clear()
      ..addAll(others);
    _exerciseOtherDraftOpen = selected.contains('기타') && others.isEmpty;
    _exerciseOtherDraftCtrl.clear();
  }

  bool _isExerciseOtherSelected() {
    final raw = _formData['answer_10_types'];
    if (raw is List) return raw.map((e) => e.toString()).contains('기타');
    return raw?.toString() == '기타';
  }

  void _clearExerciseOthers() {
    _exerciseOthers.clear();
    _exerciseOtherDraftOpen = false;
    _exerciseOtherDraftCtrl.clear();
  }

  void _commitExerciseOtherDraft() {
    final text = _exerciseOtherDraftCtrl.text.trim();
    if (text.isEmpty) return;
    if (_exerciseOthers.contains(text)) {
      _exerciseOtherDraftCtrl.clear();
      setState(() => _exerciseOtherDraftOpen = false);
      return;
    }
    setState(() {
      _exerciseOthers.add(text);
      _exerciseOtherDraftCtrl.clear();
      _exerciseOtherDraftOpen = false;
    });
  }

  void _removeExerciseOtherAt(int index) {
    setState(() {
      if (index < 0 || index >= _exerciseOthers.length) return;
      _exerciseOthers.removeAt(index);
      if (_exerciseOthers.isEmpty && _isExerciseOtherSelected()) {
        _exerciseOtherDraftOpen = true;
      }
    });
  }

  void _openExerciseOtherDraft() {
    final text = _exerciseOtherDraftCtrl.text.trim();
    if (text.isNotEmpty && !_exerciseOthers.contains(text)) {
      _exerciseOthers.add(text);
      _exerciseOtherDraftCtrl.clear();
    }
    setState(() {
      _exerciseOtherDraftOpen = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _exerciseOtherDraftFocus.requestFocus();
    });
  }

  Widget _buildOtherExerciseCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 14)),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: HealthProfileFormCommon.border),
          borderRadius: BorderRadius.circular(healthDp(context, 15)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '기타 운동',
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
                  onTap: _openExerciseOtherDraft,
                  borderRadius: BorderRadius.circular(healthDp(context, 50)),
                  child: Container(
                    height: healthDp(context, 28),
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 10),
                    ),
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                            width: healthDp(context, 1), color: HealthProfileFormCommon.border),
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 50)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          size: healthDp(context, 14),
                          color: const Color(0xFF898686),
                        ),
                        SizedBox(width: healthDp(context, 2)),
                        Text(
                          '추가',
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
          Container(height: healthDp(context, 1), color: HealthProfileFormCommon.border),
          SizedBox(height: healthDp(context, 20)),
          if (_exerciseOtherDraftOpen || _exerciseOthers.isEmpty)
            _buildExerciseOtherDraftField(),
          if (_exerciseOthers.isNotEmpty) ...[
            if (_exerciseOtherDraftOpen || _exerciseOthers.isEmpty)
              SizedBox(height: healthDp(context, 8)),
            Wrap(
              spacing: healthDp(context, 8),
              runSpacing: healthDp(context, 8),
              children: [
                for (var i = 0; i < _exerciseOthers.length; i++)
                  _buildExerciseOtherChip(_exerciseOthers[i], i),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseOtherChip(String label, int index) {
    return Container(
      height: healthDp(context, 45),
      padding: EdgeInsets.only(
        left: healthDp(context, 14),
        right: healthDp(context, 8),
      ),
      decoration: ShapeDecoration(
        color: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: HealthProfileFormCommon.border),
          borderRadius: BorderRadius.circular(healthDp(context, 50)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF1A1A1E),
              fontSize: healthSp(context, 14),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: healthDp(context, 4)),
          GestureDetector(
            onTap: () => _removeExerciseOtherAt(index),
            behavior: HitTestBehavior.opaque,
            child: Icon(
              Icons.close,
              size: healthSp(context, 16),
              color: const Color(0xFF898686),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseOtherDraftField() {
    return SizedBox(
      width: double.infinity,
      height: healthDp(context, 45),
      child: TextField(
        controller: _exerciseOtherDraftCtrl,
        focusNode: _exerciseOtherDraftFocus,
        textInputAction: TextInputAction.done,
        textAlignVertical: TextAlignVertical.center,
        onSubmitted: (_) => _commitExerciseOtherDraft(),
        onChanged: (_) => setState(() {}),
        style: TextStyle(
          color: const Color(0xFF1A1A1E),
          fontSize: healthSp(context, 14),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: '운동을 입력해주세요',
          hintStyle: TextStyle(
            color: const Color(0xFF898686),
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 14),
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 50)),
            borderSide:
                BorderSide(width: healthDp(context, 1), color: HealthProfileFormCommon.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 50)),
            borderSide:
                BorderSide(width: healthDp(context, 1), color: HealthProfileFormCommon.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 50)),
            borderSide: BorderSide(
                width: healthDp(context, 1), color: const Color(0xFFFF5A8D)),
          ),
        ),
      ),
    );
  }
}
