part of 'blood_sugar_list_screen.dart';

extension _BloodSugarListSummary on _BloodSugarListScreenState {
  Widget _buildBloodSugarDisplay() {
    final todayRecords = getTodayRecords();
    final fastingRecord = _latestRecordByType(todayRecords, '공복');
    final postMealRecord = _latestRecordByType(todayRecords, '식후');
    final previousDate =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day - 1);
    final previousDayRecords = _recordsForDate(previousDate);
    final previousFasting = _latestRecordByType(previousDayRecords, '공복');
    final previousPostMeal = _latestRecordByType(previousDayRecords, '식후');

    final int? fastingDiff = (fastingRecord != null && previousFasting != null)
        ? fastingRecord.bloodSugar - previousFasting.bloodSugar
        : null;
    final int? postDiff = (postMealRecord != null && previousPostMeal != null)
        ? postMealRecord.bloodSugar - previousPostMeal.bloodSugar
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _openSugarEditorForType('공복'),
                child: _buildSugarSummaryCardNew(
                  label: '공복',
                  value: fastingRecord?.bloodSugar.toString() ?? '-',
                  headerColor:
                      _sugarHeaderColor(fastingRecord?.bloodSugar, '공복'),
                  diffText: _sugarDiffText(
                    hasToday: fastingRecord != null,
                    diff: fastingDiff,
                  ),
                  diffUp: _isDiffUp(fastingDiff),
                ),
              ),
            ),
            SizedBox(width: healthDp(context, 10)),
            Expanded(
              child: GestureDetector(
                onTap: () => _openSugarEditorForType('식후'),
                child: _buildSugarSummaryCardNew(
                  label: '식후',
                  value: postMealRecord?.bloodSugar.toString() ?? '-',
                  headerColor:
                      _sugarHeaderColor(postMealRecord?.bloodSugar, '식후'),
                  diffText: _sugarDiffText(
                    hasToday: postMealRecord != null,
                    diff: postDiff,
                  ),
                  diffUp: _isDiffUp(postDiff),
                ),
              ),
            ),
          ],
        ),
          // 공복/식후 카드 ui 와 혈당 상태 색상 notice 부분 간격
          SizedBox(height: healthDp(context, 20)),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: healthDp(context, 10),
                  runSpacing: healthDp(context, 10),
                  children: const [
                    _SugarLegend(
                      color: HealthVitalStatus.normalBg,
                      label: '정상',
                    ),
                    _SugarLegend(
                      color: HealthVitalStatus.cautionBg,
                      label: '당뇨 전단계',
                    ),
                    _SugarLegend(
                      color: HealthVitalStatus.dangerBg,
                      label: '당뇨',
                    ),
                  ],
                ),
              ),
              SizedBox(width: healthDp(context, 10)),
              if (_recordsForDate(selectedDate).isNotEmpty)
                HealthListEditButton(
                  onTap: _openSelectedSugarRecordEditor,
                ),
            ],
          ),
        ],
      );
  }

  List<BloodSugarRecord> _recordsForDate(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    return dailyRecordsCache[key] ?? [];
  }

  BloodSugarRecord? _latestRecordByType(
      List<BloodSugarRecord> records, String type) {
    final filtered = records.where((r) => r.measurementType == type).toList();
    if (filtered.isEmpty) return null;
    filtered.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    return filtered.first;
  }

  String _sugarDiffText({required bool hasToday, int? diff}) {
    if (!hasToday) return '수치를 입력하세요';
    if (diff == null) return '전날 기록이 없습니다';
    return '전날 대비 ${diff.abs()} mg/dL';
  }

  bool _isDiffUp(int? diff) => diff != null && diff > 0;

  /// 공복/식후 카드 헤더. [BloodSugarRecord.calculateStatus]와 같은 판정.
  Color _sugarHeaderColor(int? bloodSugar, String type) {
    if (bloodSugar == null) return HealthVitalStatus.normalBg;
    final status = BloodSugarRecord.calculateStatus(bloodSugar, type);
    return HealthVitalStatus.background(status);
  }

  Future<void> _openSugarEditorForType(String type) async {
    final existing = _latestRecordByType(_recordsForDate(selectedDate), type);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => existing != null
            ? BloodSugarInputScreen(record: existing)
            : BloodSugarInputScreen(
                recordContextDate: selectedDate,
                initialMeasurementType: type,
              ),
      ),
    );
  }

  Future<void> _openSelectedSugarRecordEditor() async {
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final todayRecords = dailyRecordsCache[selectedDateStr] ?? [];
    if (todayRecords.isEmpty) return;

    todayRecords.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    _showTimeSelectionBottomSheet(todayRecords);
  }

  Widget _buildSugarSummaryCardNew({
    required String label,
    required String value,
    required Color headerColor,
    required String diffText,
    required bool diffUp,
  }) {
    final r = healthDp(context, 10);
    final showDiffArrow = diffText.startsWith('전날 대비');
    return SizedBox(
      height: healthDp(context, 85),
      child: Container(
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: healthDp(context, 0.5),
              color: const Color(0x7FD2D2D2),
            ),
            borderRadius: BorderRadius.circular(r),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: healthDp(context, 28),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: healthDp(context, 5)),
                decoration: BoxDecoration(
                  color: headerColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(r),
                    topRight: Radius.circular(r),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: healthSp(context, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        textAlign: TextAlign.center,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          color: const Color(0xFF1A1A1A),
                          fontSize: healthSp(context, 20),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight:
                              value == '-' ? FontWeight.w300 : FontWeight.w700,
                          height: 1,
                        ),
                      ),
                      SizedBox(width: healthDp(context, 2)),
                      Text(
                        'mg/dl',
                        textAlign: TextAlign.center,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          color: const Color(0xFF1A1A1A),
                          fontSize: healthSp(context, 12),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: healthDp(context, 5)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        diffText,
                        textAlign: TextAlign.center,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: healthSp(context, 8),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                          height: 1,
                        ),
                      ),
                      if (showDiffArrow) ...[
                        SizedBox(width: healthDp(context, 5)),
                        SizedBox(
                          width: healthDp(context, 10),
                          height: healthDp(context, 10),
                          child: SvgPicture.asset(
                            diffUp ? AppAssets.arrowUp : AppAssets.arrowDown,
                            width: healthDp(context, 10),
                            height: healthDp(context, 10),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
