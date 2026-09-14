part of 'health_profile_form_screen.dart';

/// 문진표 2페이지 진입 — 식습관
class HealthProfileForm2Screen extends StatelessWidget {
  static const String routeName = 'health_profile_form2';

  const HealthProfileForm2Screen({
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
      initialSectionIndices: initialSectionIndices ?? const [1],
      editScreenTitle: editScreenTitle,
      initialWizardIndex: 1,
      prescriptionBooking: prescriptionBooking,
    );
  }
}

mixin HealthProfileForm2Ui on _HealthProfileFormState {
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
          side: BorderSide(width: healthDp(context, 1), color: HealthProfileFormCommon.border),
          borderRadius: BorderRadius.circular(healthDp(context, 15)),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < slots.length; i++) ...[
              if (i > 0)
                Container(width: healthDp(context, 1), color: HealthProfileFormCommon.border),
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
    final raw = (_formData[fieldKey]?.toString() ?? '').trim();
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
    final raw = (_formData[fieldKey]?.toString() ?? '').trim();
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
                          _formData[fieldKey] = value;
                          HealthProfileFormCommon.applyUnusedMealDash(
                            _formData,
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

  Widget _buildMealtimeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1식',
                    style: TextStyle(
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 4)),
                  TextFormField(
                    initialValue: _formData['meal_1'] ?? '',
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '예: 08:00',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 8)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 16),
                        vertical: healthDp(context, 12),
                      ),
                    ),
                    onSaved: (value) {
                      _formData['meal_1'] = value ?? '';
                    },
                  ),
                ],
              ),
            ),
            SizedBox(width: healthDp(context, 8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2식',
                    style: TextStyle(
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 4)),
                  TextFormField(
                    initialValue: _formData['meal_2'] ?? '',
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '예: 12:00',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 8)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 16),
                        vertical: healthDp(context, 12),
                      ),
                    ),
                    onSaved: (value) {
                      _formData['meal_2'] = value ?? '';
                    },
                  ),
                ],
              ),
            ),
            SizedBox(width: healthDp(context, 8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '3식',
                    style: TextStyle(
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 4)),
                  TextFormField(
                    initialValue: _formData['meal_3'] ?? '',
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '예: 19:00',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 8)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 16),
                        vertical: healthDp(context, 12),
                      ),
                    ),
                    onSaved: (value) {
                      _formData['meal_3'] = value ?? '';
                    },
                  ),
                ],
              ),
            ),
            SizedBox(width: healthDp(context, 8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '4식',
                    style: TextStyle(
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 4)),
                  TextFormField(
                    initialValue: _formData['meal_other'] ?? '',
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '예: 21:00',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 8)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 16),
                        vertical: healthDp(context, 12),
                      ),
                    ),
                    onSaved: (value) {
                      _formData['meal_other'] = value ?? '';
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: healthDp(context, 8)),
        Text(
          '*해당되는 입력란에만 입력하세요.',
          style: TextStyle(
            fontSize: healthSp(context, 11),
            fontFamily: 'Gmarket Sans TTF',
            color: Colors.grey[500],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
