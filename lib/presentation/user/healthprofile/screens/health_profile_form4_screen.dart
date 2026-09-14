part of 'health_profile_form_screen.dart';

/// 문진표 4페이지 진입 — 건강 정보
class HealthProfileForm4Screen extends StatelessWidget {
  static const String routeName = 'health_profile_form4';

  const HealthProfileForm4Screen({
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
      initialSectionIndices: initialSectionIndices ?? const [3],
      editScreenTitle: editScreenTitle,
      initialWizardIndex: 3,
      prescriptionBooking: prescriptionBooking,
    );
  }
}

mixin HealthProfileForm4Ui on _HealthProfileFormState {
  void _syncMedicationOtherFormData() {
    _formData['answer_12_other'] = [
      ..._medicationOthers,
      if (_medicationOtherDraftCtrl.text.trim().isNotEmpty)
        _medicationOtherDraftCtrl.text.trim(),
    ].join(', ');
  }

  void _clearMedicationOthers() {
    _medicationOthers.clear();
    _medicationOtherDraftOpen = false;
    _medicationOtherDraftCtrl.clear();
    _formData['answer_12_other'] = '';
  }

  void _commitMedicationOtherDraft() {
    final text = _medicationOtherDraftCtrl.text.trim();
    if (text.isEmpty) return;
    if (_medicationOthers.contains(text)) {
      _medicationOtherDraftCtrl.clear();
      setState(() {
        _medicationOtherDraftOpen = false;
        _syncMedicationOtherFormData();
      });
      return;
    }
    setState(() {
      _medicationOthers.add(text);
      _medicationOtherDraftCtrl.clear();
      _medicationOtherDraftOpen = false;
      _syncMedicationOtherFormData();
    });
  }

  void _removeMedicationOtherAt(int index) {
    setState(() {
      if (index < 0 || index >= _medicationOthers.length) return;
      _medicationOthers.removeAt(index);
      if (_medicationOthers.isEmpty && _isMedicationOtherSelected()) {
        _medicationOtherDraftOpen = true;
      }
      _syncMedicationOtherFormData();
    });
  }

  bool _isMedicationOtherSelected() {
    final raw = _formData['answer_12'];
    if (raw is List) return raw.map((e) => e.toString()).contains('기타');
    return raw?.toString() == '기타';
  }

  void _openMedicationOtherDraft() {
    final text = _medicationOtherDraftCtrl.text.trim();
    if (text.isNotEmpty && !_medicationOthers.contains(text)) {
      _medicationOthers.add(text);
      _medicationOtherDraftCtrl.clear();
    }
    setState(() {
      _medicationOtherDraftOpen = true;
      _syncMedicationOtherFormData();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _medicationOtherDraftFocus.requestFocus();
    });
  }

  Widget _buildOtherMedicationCard() {
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
                  '기타 약 정보',
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
                  onTap: _openMedicationOtherDraft,
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
          if (_medicationOthers.isNotEmpty)
            Wrap(
              spacing: healthDp(context, 8),
              runSpacing: healthDp(context, 8),
              children: [
                for (var i = 0; i < _medicationOthers.length; i++)
                  _buildMedicationOtherChip(_medicationOthers[i], i),
              ],
            ),
          if (_medicationOtherDraftOpen || _medicationOthers.isEmpty) ...[
            if (_medicationOthers.isNotEmpty)
              SizedBox(height: healthDp(context, 8)),
            _buildMedicationOtherDraftField(),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicationOtherChip(String label, int index) {
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
            onTap: () => _removeMedicationOtherAt(index),
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

  Widget _buildMedicationOtherDraftField() {
    return SizedBox(
      width: double.infinity,
      height: healthDp(context, 45),
      child: TextField(
        controller: _medicationOtherDraftCtrl,
        focusNode: _medicationOtherDraftFocus,
        textInputAction: TextInputAction.done,
        textAlignVertical: TextAlignVertical.center,
        onSubmitted: (_) => _commitMedicationOtherDraft(),
        onChanged: (_) {
          _syncMedicationOtherFormData();
          setState(() {});
        },
        style: TextStyle(
          color: const Color(0xFF1A1A1E),
          fontSize: healthSp(context, 14),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: '복용중인 약 이름을 입력해주세요',
          hintStyle: TextStyle(
            color: const Color(0xFF898686),
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
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

  Widget _buildFigmaYesNoChips() {
    final v = _formData['answer_13'];
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
                    final oldValue = _formData['answer_13']?.toString();
                    _formData['answer_13'] = '2';
                    final wasNoOrUnset = oldValue == null ||
                        oldValue.isEmpty ||
                        oldValue == '1' ||
                        oldValue == '없음';
                    if (wasNoOrUnset) {
                      _formData['answer_13_medicine'] =
                          _backupAnswer13Fields['answer_13_medicine'] ?? '';
                      _formData['answer_13_period'] =
                          _backupAnswer13Fields['answer_13_period'] ?? '';
                      _formData['answer_13_dosage'] =
                          _backupAnswer13Fields['answer_13_dosage'] ?? '';
                      _formData['answer_13_sideeffect'] =
                          _backupAnswer13Fields['answer_13_sideeffect'] ?? '';
                      _dietDetailResetTick++;
                    }
                  });
                },
                child: Container(
                  height: healthDp(context, 40),
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: isYes ? HealthProfileFormCommon.pinkSoft : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: healthDp(context, 1),
                        color: isYes ? HealthProfileFormCommon.pink : HealthProfileFormCommon.border,
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
                    _formData['answer_13'] = '1';
                  });
                },
                child: Container(
                  height: healthDp(context, 40),
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: isNo ? HealthProfileFormCommon.pinkSoft : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: healthDp(context, 1),
                        color: isNo ? HealthProfileFormCommon.pink : HealthProfileFormCommon.border,
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
        if (_shouldShowQuestion(
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
          side: BorderSide(width: healthDp(context, 1), color: HealthProfileFormCommon.border),
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
                      _formData['answer_13_medicine'] = '';
                      _formData['answer_13_period'] = '';
                      _formData['answer_13_dosage'] = '';
                      _formData['answer_13_sideeffect'] = '';
                      _dietDetailResetTick++;
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
                            width: healthDp(context, 1), color: HealthProfileFormCommon.border),
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
          Container(height: healthDp(context, 1), color: HealthProfileFormCommon.border),
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
            key: ValueKey<String>('diet_$id:$_dietDetailResetTick'),
            initialValue: _formData[id]?.toString() ?? '',
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
                borderSide:
                    BorderSide(width: healthDp(context, 1), color: HealthProfileFormCommon.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 15)),
                borderSide:
                    BorderSide(width: healthDp(context, 1), color: HealthProfileFormCommon.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 15)),
                borderSide: BorderSide(
                    width: healthDp(context, 1),
                    color: const Color(0xFFFF5A8D)),
              ),
            ),
            onChanged: (v) {
              _formData[id] = v;
              setState(() {});
            },
            onSaved: (v) => _formData[id] = v ?? '',
          ),
        ),
      ],
    );
  }
}
