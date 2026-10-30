part of 'blood_pressure_list_screen.dart';

extension _BloodPressureListSummary on _BloodPressureListScreenState {
  // 혈압 상태 표시
  Widget _buildBloodPressureDisplay() {
    final systolic = selectedRecord?.systolic ?? 0;
    final diastolic = selectedRecord?.diastolic ?? 0;
    final previousDateKey = DateFormat('yyyy-MM-dd')
        .format(selectedDate.subtract(const Duration(days: 1)));
    final previousRecord = bloodPressureRecordsMap[previousDateKey];
    final int? systolicDiff = (selectedRecord != null && previousRecord != null)
        ? systolic - previousRecord.systolic
        : null;
    final int? diastolicDiff =
        (selectedRecord != null && previousRecord != null)
            ? diastolic - previousRecord.diastolic
            : null;

    return GestureDetector(
      onTap: _openSelectedRecordEditor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildPressureSummaryCardNew(
                  label: '수축기',
                  value: systolic > 0 ? '$systolic' : '-',
                  headerColor: _pressureHeaderColor(systolic, diastolic),
                  diffText: _diffText(systolicDiff),
                  diffUp: _isUp(systolicDiff),
                ),
              ),
              SizedBox(width: healthDp(context, 10)),
              Expanded(
                child: _buildPressureSummaryCardNew(
                  label: '이완기',
                  value: diastolic > 0 ? '$diastolic' : '-',
                  headerColor: _pressureHeaderColor(systolic, diastolic),
                  diffText: _diffText(diastolicDiff),
                  diffUp: _isUp(diastolicDiff),
                ),
              ),
            ],
          ),
          SizedBox(height: healthDp(context, 20)),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: healthDp(context, 10),
                  runSpacing: healthDp(context, 10),
                  children: const [
                    _PressureLegend(
                      color: HealthVitalStatus.lowBg,
                      label: '저혈압',
                    ),
                    _PressureLegend(
                      color: HealthVitalStatus.normalBg,
                      label: '정상',
                    ),
                    _PressureLegend(
                      color: HealthVitalStatus.cautionBg,
                      label: '고혈압 전단계',
                    ),
                    _PressureLegend(
                      color: HealthVitalStatus.stageBg,
                      label: '1기 고혈압',
                    ),
                    _PressureLegend(
                      color: HealthVitalStatus.dangerBg,
                      label: '2기 고혈압',
                    ),
                    _PressureLegend(
                      color: HealthVitalStatus.crisisBg,
                      label: '고혈압 위기',
                    ),
                  ],
                ),
              ),
              SizedBox(width: healthDp(context, 10)),
              SizedBox(
                height: healthDp(context, 22),
                child: selectedRecord == null
                    ? const SizedBox.shrink()
                    : HealthListEditButton(
                        onTap: _openSelectedRecordEditor,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openSelectedRecordEditor() async {
    if (selectedRecord == null) return;

    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final todayRecords = dailyRecordsCache[selectedDateStr] ?? [];
    todayRecords.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));

    // 1개여도 바텀시트로 선택 후 수정
    _showTimeSelectionBottomSheet(todayRecords);
  }

  String _diffText(int? diff) {
    if (diff == null) return '수치를 입력하세요';
    return '전날 대비 ${diff.abs()} mmHg';
  }

  bool _isUp(int? diff) => diff != null && diff > 0;

  /// 수축기·이완기 카드 헤더. 한 쌍을 [BloodPressureRecord.calculateStatus]로 판정한다.
  Color _pressureHeaderColor(int systolic, int diastolic) {
    if (systolic <= 0 || diastolic <= 0) return HealthVitalStatus.normalBg;
    return HealthVitalStatus.background(
      BloodPressureRecord.calculateStatus(systolic, diastolic),
    );
  }

  Widget _buildPressureSummaryCardNew({
    required String label,
    required String value,
    required Color headerColor,
    required String diffText,
    required bool diffUp,
  }) {
    final r = healthDp(context, 10);
    final showDiffArrow = diffText.startsWith('전날 대비');
    return SizedBox(
      height: healthDp(context, 86),
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
                          color: Colors.black,
                          fontSize: healthSp(context, 20),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight:
                              value == '-' ? FontWeight.w300 : FontWeight.w700,
                          height: 1,
                        ),
                      ),
                      SizedBox(width: healthDp(context, 2)),
                      Text(
                        'mmHg',
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

  Widget _buildPressureSummaryCard({
    required String label,
    required String value,
    required Color cardColor,
    required String diffText,
    required bool diffUp,
    double labelFontSize = 16,
    double diffFontSize = 10,
    double diffIconSize = 12.5,
  }) {
    // 혈압 요약 카드 컨테이너
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 4,
            offset: Offset(0, 0),
          ),
        ],
      ),
      // 카드 내부 세로 레이아웃
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 수축기/이완기 라벨 텍스트
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF1A1A1A),
              fontSize: 18,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w700,
            ),
          ),
          // 라벨-값 간 간격
          const SizedBox(height: 4),
          // 혈압 값 + 단위 행
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 혈압 숫자 값
              Text(
                value,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20.83,
                  fontWeight: FontWeight.w700,
                ),
              ),
              // 값-단위 간 간격
              const SizedBox(width: 2),
              // 단위 텍스트
              const Text(
                'mmHg',
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
          // 값-전일대비 간 간격
          const SizedBox(height: 2),
          // 전일 대비 텍스트 + 방향 아이콘 행
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 전일 대비 값 텍스트
              Text(
                diffText,
                style: TextStyle(
                  color: const Color(0xFF1A1A1A),
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
              ),
              // 텍스트-아이콘 간 간격
              const SizedBox(width: 4),
              // 증감 방향 아이콘
              Icon(
                diffUp ? Icons.arrow_upward : Icons.arrow_downward,
                size: diffIconSize,
                color:
                    diffUp ? const Color(0xFFFF0000) : const Color(0xFF002BFF),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
