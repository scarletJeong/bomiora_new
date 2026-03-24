import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/btn_record.dart';
import '../../../common/chart_layout.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../health_common/widgets/health_edit_bottom_sheet.dart';
import '../../health_common/widgets/health_period_selector.dart';
import '../../health_common/widgets/health_chart_expand_page.dart';
import '../../health_common/widgets/health_date_selector.dart';
import '../../../../data/models/health/blood_pressure/blood_pressure_record_model.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/repositories/health/blood_pressure/blood_pressure_repository.dart';
import '../../../../data/services/auth_service.dart';
import 'blood_pressure_input_screen.dart';
import '../widgets/blood_pressure_chart_section.dart';

class BloodPressureListScreen extends StatefulWidget {
  final DateTime? initialDate;

  const BloodPressureListScreen({super.key, this.initialDate});

  @override
  State<BloodPressureListScreen> createState() =>
      _BloodPressureListScreenState();
}

class _BloodPressureListScreenState extends State<BloodPressureListScreen> {
  String selectedPeriod = '일';
  UserModel? currentUser;
  List<BloodPressureRecord> allRecords = []; // 전체 혈압 기록
  Map<String, BloodPressureRecord> bloodPressureRecordsMap = {}; // 날짜별 요약 기록
  Map<String, List<BloodPressureRecord>> dailyRecordsCache = {}; // 날짜별 상세 기록 캐시
  bool isLoading = true;
  bool hasShownNoDataDialog = false;
  late DateTime selectedDate;

  // 차트 관련
  int? selectedChartPointIndex;
  Offset? tooltipPosition;
  double timeOffset = 0.0; // 통합된 드래그 오프셋
  double? _dragStartX;
  VoidCallback? _refreshExpandedChart;
  double _bpDragAccumDX = 0;
  bool _bpDragFrameScheduled = false;
  double _bpLastPlotWidth = 1.0;

  void _setChartState(VoidCallback updates) {
    if (!mounted) return;
    setState(updates);
    _refreshExpandedChart?.call();
  }

  // 표시할 3개의 날짜
  List<DateTime> get displayDates {
    return [
      selectedDate.subtract(const Duration(days: 1)),
      selectedDate,
      selectedDate.add(const Duration(days: 1)),
    ];
  }

  BloodPressureRecord? get selectedRecord {
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    return bloodPressureRecordsMap[dateKey];
  }

  // 오늘인지 확인
  bool _isToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;
  }

  // 시간 범위 계산 (통합 로직)
  Map<String, double> _calculateTimeRange() {
    const maxStartHour = 18; // 24시 - 6시간 = 18시 (7개 라벨)
    final startHour =
        (timeOffset * maxStartHour).clamp(0.0, maxStartHour.toDouble());
    final endHour = (startHour + 6.0).clamp(6.0, 24.0);

    return {'min': startHour, 'max': endHour};
  }

  // 드래그 범위 제한
  double _clampDragOffset(double newOffset) {
    if (selectedPeriod == '월') {
      // 월별: 12개월 중 7개월 창 이동
      final totalMonths = 12;
      final visibleMonths = 7;
      final maxStart = (totalMonths - visibleMonths).clamp(0, 99);
      if (maxStart == 0) return 0.0;
      return newOffset.clamp(0.0, 1.0);
    }

    if (_isToday()) {
      // 오늘: 현재 시간 - 4시간까지만
      final now = DateTime.now();
      final currentHour = now.hour;
      final maxStartHour = (currentHour - 4).clamp(0, 18);
      final maxOffset = maxStartHour / 18.0;
      return newOffset.clamp(0.0, maxOffset);
    } else {
      // 과거 일별: 00시~24시 전체 범위
      return newOffset.clamp(0.0, 1.0);
    }
  }

  // 드래그 민감도
  double _getDragSensitivity() {
    if (selectedPeriod == '월') {
      return 3.0; // 월별 그래프는 민감도를 더 높임
    }
    return 0.5; // 일별 그래프는 기존 민감도 유지
  }

  // 공통 드래그 핸들러 (프레임당 1회 setState — onPanUpdate 중 mouse_tracker 재진입 방지)
  void _handleDragUpdate(double deltaX, double chartWidth) {
    _bpLastPlotWidth = chartWidth;
    _bpDragAccumDX += deltaX;
    if (_bpDragFrameScheduled) return;
    _bpDragFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bpDragFrameScheduled = false;
      if (!mounted) return;
      final dx = _bpDragAccumDX;
      _bpDragAccumDX = 0;
      if (dx == 0) return;
      final w = _bpLastPlotWidth;
      if (w <= 0) return;
      final sensitivity = _getDragSensitivity();
      final dataDelta = -(dx / w) * sensitivity;
      _setChartState(() {
        timeOffset = _clampDragOffset(timeOffset + dataDelta);
      });
    });
  }

  // 차트 데이터 생성
  // - 슬롯 내 기록 1건: 점
  // - 슬롯 내 기록 2건 이상: 최저~최고 막대
  List<Map<String, dynamic>> getChartData() {
    if (selectedPeriod == '일') {
      return _buildHourlyChartData();
    }
    if (selectedPeriod == '주') {
      return _buildDailyRangeChartData();
    }
    return _buildMonthlyRangeChartData();
  }

  /// 시간대별 차트는 7시간 창만 보여 줌. 창 밖에만 기록이 있으면 빈 그래프로 보이므로
  /// 해당 날 기록이 보이도록 timeOffset을 맞춤.
  void _ensureHourlyWindowShowsData() {
    if (selectedPeriod != '일') return;
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final dayRecords = dailyRecordsCache[selectedDateStr] ?? [];
    if (dayRecords.isEmpty) return;

    final startHour = _calculateTimeRange()['min']!.floor();
    var visibleHasData = false;
    for (int i = 0; i < 7; i++) {
      final slotHour = (startHour + i).clamp(0, 23);
      if (dayRecords.any((r) => r.measuredAt.hour == slotHour)) {
        visibleHasData = true;
        break;
      }
    }
    if (visibleHasData) return;

    final hours = dayRecords.map((r) => r.measuredAt.hour).toList();
    final minH = hours.reduce(math.min);
    final maxH = hours.reduce(math.max);
    // 7슬롯(start..start+6)에 [minH,maxH]가 들어가도록 start 선택 (가능할 때)
    final low = (maxH - 6).clamp(0, 18);
    final high = minH.clamp(0, 18);
    final startTarget = low <= high ? low : (maxH - 6).clamp(0, 18);
    timeOffset = _clampDragOffset(startTarget / 18.0);
  }

  List<Map<String, dynamic>> _buildHourlyChartData() {
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final dayRecords = (dailyRecordsCache[selectedDateStr] ?? [])
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

    final startHour = _calculateTimeRange()['min']!.floor();
    final labels = List.generate(
      7,
      (i) => (startHour + i).clamp(0, 23).toString().padLeft(2, '0'),
    );

    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < 7; i++) {
      final slotHour = (startHour + i).clamp(0, 23);
      final records = dayRecords
          .where((r) => r.measuredAt.hour == slotHour)
          .toList()
        ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

      result.add(_buildPressureRangeSlotData(
        label: labels[i],
        records: records,
      ));
    }
    return result;
  }

  List<Map<String, dynamic>> _buildDailyRangeChartData() {
    final endDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final startDate = endDate.subtract(const Duration(days: 6));
    final result = <Map<String, dynamic>>[];

    for (int i = 0; i < 7; i++) {
      final day = startDate.add(Duration(days: i));
      final records = allRecords
          .where((r) =>
              r.measuredAt.year == day.year &&
              r.measuredAt.month == day.month &&
              r.measuredAt.day == day.day)
          .toList()
        ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

      result.add(_buildPressureRangeSlotData(
        label: DateFormat('M.d').format(day),
        records: records,
      ));
    }

    return result;
  }

  /// 체중 월별과 동일: [selectedDate] 연도 기준 1~12월 중 7개월 창 슬라이드
  List<Map<String, dynamic>> _buildMonthlyRangeChartData() {
    const totalMonths = 12;
    const visibleMonths = 7;
    final year = selectedDate.year;
    final maxStart = totalMonths - visibleMonths;
    final startIndex = (timeOffset * maxStart).round().clamp(0, maxStart);

    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < visibleMonths; i++) {
      final month = startIndex + i + 1;
      final records = allRecords
          .where((r) => r.measuredAt.year == year && r.measuredAt.month == month)
          .toList()
        ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

      result.add(_buildPressureRangeSlotData(
        label: '$month',
        records: records,
      ));
    }
    return result;
  }

  Map<String, dynamic> _buildPressureRangeSlotData({
    required String label,
    required List<BloodPressureRecord> records,
  }) {
    if (records.isEmpty) {
      return {
        'date': label,
        'recordCount': 0,
        'systolicMin': null,
        'systolicMax': null,
        'diastolicMin': null,
        'diastolicMax': null,
        'record': null,
      };
    }

    var systolicMin = records.first.systolic;
    var systolicMax = records.first.systolic;
    var diastolicMin = records.first.diastolic;
    var diastolicMax = records.first.diastolic;

    for (final r in records) {
      if (r.systolic < systolicMin) systolicMin = r.systolic;
      if (r.systolic > systolicMax) systolicMax = r.systolic;
      if (r.diastolic < diastolicMin) diastolicMin = r.diastolic;
      if (r.diastolic > diastolicMax) diastolicMax = r.diastolic;
    }

    return {
      'date': label,
      'recordCount': records.length,
      'systolicMin': systolicMin,
      'systolicMax': systolicMax,
      'diastolicMin': diastolicMin,
      'diastolicMax': diastolicMax,
      'record': records.last,
    };
  }

  /// 체중 그래프와 동일: 오른쪽 (시)/(일)/(월) 단위
  Widget _buildBloodPressureXAxisWithUnit({
    required Widget labelRow,
    required String unitText,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            right: ChartConstants.weightXAxisUnitReservedWidth,
          ),
          child: labelRow,
        ),
        Positioned(
          right: -10,
          top: 1,
          bottom: 0,
          child: Align(
            alignment: Alignment.center,
            child: Text(
              unitText,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBloodPressureXAxisLabels() {
    if (selectedPeriod == '일') {
      const maxStartHour = 18;
      final startHour =
          (timeOffset * maxStartHour).clamp(0.0, 18.0).round();
      final hourLabels = <Widget>[];
      for (int i = 0; i < 7; i++) {
        final hour = (startHour + i).clamp(0, 24);
        final hourLabel = hour == 24 ? '24' : hour.toString().padLeft(2, '0');
        hourLabels.add(
          Text(
            hourLabel,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        );
      }
      return _buildBloodPressureXAxisWithUnit(
        labelRow: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: hourLabels,
        ),
        unitText: '(시)',
      );
    }

    if (selectedPeriod == '월') {
      const totalMonths = 12;
      const visibleMonths = 7;
      final maxStart = totalMonths - visibleMonths;
      final startIndex = (timeOffset * maxStart).round().clamp(0, maxStart);

      return _buildBloodPressureXAxisWithUnit(
        labelRow: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(visibleMonths, (i) {
            final m = startIndex + i + 1;
            return Expanded(
              child: Text(
                '$m',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            );
          }),
        ),
        unitText: '(월)',
      );
    }

    const days = 7;
    final endDate =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final startDate = endDate.subtract(Duration(days: days - 1));

    final dateRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(days, (i) {
        final date = startDate.add(Duration(days: i));
        return Expanded(
          child: Text(
            DateFormat('M.d').format(date),
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        );
      }),
    );

    return _buildBloodPressureXAxisWithUnit(
      labelRow: dateRow,
      unitText: '(일)',
    );
  }

  /// 체중 일별과 같이: 선택일에 기록이 하나도 없을 때만 안내 카드 (드래그로 창만 비어도 그리드 유지)
  bool _shouldShowBloodPressureNoDataCard() {
    if (selectedPeriod == '일') {
      final key = DateFormat('yyyy-MM-dd').format(selectedDate);
      return (dailyRecordsCache[key] ?? []).isEmpty;
    }
    return false;
  }

  // Y축 범위 계산
  // 확대 그래프: 0~200, 20 간격(총 11개)
  List<double> getYAxisLabels({bool forExpandedChart = false}) {
    if (forExpandedChart) {
      return List<double>.generate(11, (i) => (200 - i * 20).toDouble());
    }
    return [250, 200, 150, 100, 50];
  }

  // 점선 Y축 라벨
  List<double> getDashedYAxisLabels() {
    return [225, 175, 125, 75];
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    if (widget.initialDate != null) {
      selectedDate = DateTime(
        widget.initialDate!.year,
        widget.initialDate!.month,
        widget.initialDate!.day,
      );
    } else {
      selectedDate = DateTime(now.year, now.month, now.day);
    }

    // 오늘 날짜일 경우: 현재 시간 - 4시간을 시작점으로 초기 timeOffset 설정
    if (_isToday()) {
      final currentHour = now.hour;
      final startHourTarget = (currentHour - 4).clamp(0, 18);
      timeOffset = startHourTarget / 18.0;
    }

    // 월별: 체중과 동일 1~7월부터 시작, 드래그로 6~12월까지
    if (selectedPeriod == '월') {
      timeOffset = 0.0;
    }

    _loadData();
  }

  // 주/월 데이터 로드 (메모리에서 필터링)
  void _loadPeriodData() {
    // 이미 allRecords에 모든 데이터가 있으므로 UI만 업데이트
    setState(() {});
  }

  // 데이터 로드 (최적화: 전체 데이터를 한 번만 로드)
  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    try {
      currentUser = await AuthService.getUser();

      if (currentUser != null) {
        // 전체 혈압 기록 한 번만 로드
        allRecords = await BloodPressureRepository.getBloodPressureRecords(
            currentUser!.id);

        // 메모리에서 날짜별로 캐싱 (API 호출 없이 필터링)
        _cacheRecordsFromMemory();
        _ensureHourlyWindowShowsData();

        // 데이터가 없을 때만 다이얼로그 표시 (한 번만)
        if (allRecords.isEmpty && mounted && !hasShownNoDataDialog) {
          hasShownNoDataDialog = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showNoDataDialog();
          });
        }

        setState(() {
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('혈압 기록 로드 오류: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // 메모리에서 날짜별로 캐싱 (API 호출 없이 필터링)
  void _cacheRecordsFromMemory() {
    dailyRecordsCache.clear();
    bloodPressureRecordsMap.clear();

    for (var record in allRecords) {
      final dateKey = DateFormat('yyyy-MM-dd').format(record.measuredAt);

      // 날짜별 리스트에 추가
      if (!dailyRecordsCache.containsKey(dateKey)) {
        dailyRecordsCache[dateKey] = [];
      }
      dailyRecordsCache[dateKey]!.add(record);

      // 요약 맵 업데이트 (가장 최근 기록)
      if (!bloodPressureRecordsMap.containsKey(dateKey) ||
          record.measuredAt
              .isAfter(bloodPressureRecordsMap[dateKey]!.measuredAt)) {
        bloodPressureRecordsMap[dateKey] = record;
      }
    }
  }

  // 날짜 변경 시 데이터 로드 (메모리에서 필터링)
  void _loadDataForSelectedDate() {
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);

    // 이미 캐시에 있으면 UI만 업데이트
    if (dailyRecordsCache.containsKey(dateKey)) {
      _ensureHourlyWindowShowsData();
      setState(() {});
      return;
    }

    // 메모리에서 필터링하여 캐시에 추가
    final records = allRecords.where((record) {
      final recordDateKey = DateFormat('yyyy-MM-dd').format(record.measuredAt);
      return recordDateKey == dateKey;
    }).toList();

    dailyRecordsCache[dateKey] = records;

    if (records.isNotEmpty) {
      records.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
      bloodPressureRecordsMap[dateKey] = records.first;
    }

    _ensureHourlyWindowShowsData();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );

    return Theme(
      data: gmarketTheme,
      child: MobileAppLayoutWrapper(
        appBar: const HealthAppBar(title: '혈압'),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 27),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HealthDateSelector(
                        selectedDate: selectedDate,
                        onDateChanged: (newDate) {
                          setState(() {
                            selectedDate = newDate;
                            selectedChartPointIndex = null;
                            tooltipPosition = null;

                            // 오늘 날짜로 변경 시 현재 시간 기준으로 timeOffset 설정
                            final now = DateTime.now();
                            final today =
                                DateTime(now.year, now.month, now.day);
                            final isSelectingToday =
                                newDate.year == today.year &&
                                    newDate.month == today.month &&
                                    newDate.day == today.day;

                            if (isSelectingToday) {
                              final currentHour = now.hour;
                              final startHourTarget =
                                  (currentHour - 4).clamp(0, 18);
                              timeOffset = startHourTarget / 18.0;
                            } else {
                              timeOffset = 0.0;
                            }
                          });

                          // 새로운 날짜의 데이터 로드
                          _loadDataForSelectedDate();
                        },
                        monthTextColor: const Color(0xFF898686),
                        selectedTextColor: const Color(0xFFFF5A8D),
                        unselectedTextColor: const Color(0xFFB7B7B7),
                        dividerColor: const Color(0xFFD2D2D2),
                        iconColor: const Color(0xFF898686),
                      ),
                      const SizedBox(height: 16),
                      _buildBloodPressureDisplay(),
                      const SizedBox(height: 25),
                      _buildPeriodButtons(),
                      // 그래프와 기간 선택(일자별/월별) 카드 간격
                      const SizedBox(height: 3),
                      _buildChart(),
                      const SizedBox(height: 14),
                      const Row(
                        children: [
                          _GraphSeriesLegend(
                              color: Color(0xFF86B0FF), label: '수축기'),
                          SizedBox(width: 12),
                          _GraphSeriesLegend(
                              color: Color(0xFFFFC686), label: '이완기'),
                        ],
                      ),
                      const SizedBox(height: 60),
                      BtnRecord(
                        text: '+기록하기',
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const BloodPressureInputScreen(),
                            ),
                          );

                          if (result == true) {
                            _loadData();
                          }
                        },
                        backgroundColor: const Color(0xFFFF5A8D),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildPressureSummaryCardNew(
                  label: '수축기',
                  value: systolic > 0 ? '$systolic' : '-',
                  headerColor: _pressureHeaderColor(systolic > 0 ? systolic : null, '수축기'),
                  diffText: _diffText(systolicDiff),
                  diffUp: _isUp(systolicDiff),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPressureSummaryCardNew(
                  label: '이완기',
                  value: diastolic > 0 ? '$diastolic' : '-',
                  headerColor: _pressureHeaderColor(diastolic > 0 ? diastolic : null, '이완기'),
                  diffText: _diffText(diastolicDiff),
                  diffUp: _isUp(diastolicDiff),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _PressureLegend(color: Color(0xFF71D375), label: '정상'),
                    _PressureLegend(color: Color(0xFFFFE78B), label: '주의혈압'),
                    _PressureLegend(color: Color(0xFFFEAF8E), label: '전단계'),
                    _PressureLegend(color: Color(0xFFFF6161), label: '고혈압'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _openSelectedRecordEditor,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5A8D),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '수정하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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

  // 혈압상태색상 정하는 곳 (정상: 0xFF71D375, 주의혈압: 0xFFFFE78B, 전단계: 0xFFFEAF8E, 고혈압: 0xFFFF6161)
  // 사용처: 수축기/이완기 카드 상단 헤더(_buildPressureSummaryCardNew의 headerColor), 아래 범례(_PressureLegend)
  Color _pressureHeaderColor(int? value, String type) {
    if (value == null || value <= 0) return const Color(0xFF71D375);
    if (type == '수축기') {
      if (value < 120) return const Color(0xFF71D375); // 정상
      if (value <= 129) return const Color(0xFFFFE78B); // 주의혈압
      if (value <= 139) return const Color(0xFFFEAF8E); // 전단계
      return const Color(0xFFFF6161); // 고혈압
    }
    // 이완기
    if (value < 80) return const Color(0xFF71D375); // 정상
    if (value <= 84) return const Color(0xFFFFE78B); // 주의혈압
    if (value <= 89) return const Color(0xFFFEAF8E); // 전단계
    return const Color(0xFFFF6161); // 고혈압
  }

  Widget _buildPressureSummaryCardNew({
    required String label,
    required String value,
    required Color headerColor,
    required String diffText,
    required bool diffUp,
  }) {
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 0.50, color: Color(0x7FD2D2D2)),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: ShapeDecoration(
              color: headerColor,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16.67,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20.83,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: value == '-' ? FontWeight.w300 : FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'mmHg',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 12,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    diffText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 8,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    diffUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    size: 10,
                    color: const Color(0xFF1A1A1A),
                  ),
                ],
              ),
            ],
          ),
        ],
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

  // 기간 선택 버튼
  Widget _buildPeriodButtons() {
    return HealthPeriodSelector(
      selectedPeriod: selectedPeriod,
      onChanged: (period) {
        _setChartState(() {
          selectedPeriod = period;
          selectedChartPointIndex = null;
          tooltipPosition = null;
          if (period == '월') {
            timeOffset = 0.0;
          } else if (period == '주') {
            timeOffset = 0.0;
          } else if (period == '일') {
            if (_isToday()) {
              final now = DateTime.now();
              final currentHour = now.hour;
              final startHourTarget = (currentHour - 4).clamp(0, 18);
              timeOffset = startHourTarget / 18.0;
            } else {
              timeOffset = 0.0;
            }
            _ensureHourlyWindowShowsData();
          } else {
            timeOffset = 0.0;
          }
        });

        if (period == '주' || period == '월') {
          _loadPeriodData();
        }
      },
    );
  }

  // 차트
  Widget _buildChart(
      {bool showExpandButton = true,
      bool forExpandedChart = false,
      double chartHeight = ChartConstants.healthChartHeight}) {
    final chartData = getChartData();
    final yLabels = getYAxisLabels(forExpandedChart: forExpandedChart);

    Widget chartBody;

    if (_shouldShowBloodPressureNoDataCard()) {
      chartBody = _buildNoDataMessage(chartHeight: chartHeight);
    } else {
      chartBody = _buildDataChart(chartData, yLabels, chartHeight: chartHeight);
    }

    if (!showExpandButton) return chartBody;

    return Stack(
      children: [
        chartBody,
        Positioned(
          right: 8,
          top: 8,
          child: GestureDetector(
            onTap: _openExpandedChartPage,
            child: Container(
              width: 16,
              height: 16,
              decoration: ShapeDecoration(
                color: const Color(0x7FD2D2D2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              child: const Icon(
                Icons.open_in_full,
                size: 12,
                color: Color(0xFF4B5563),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 데이터 없음 메시지 빌드
  Widget _buildNoDataMessage(
      {double chartHeight = ChartConstants.healthChartHeight}) {
    return Container(
      height: chartHeight,
      padding: ChartConstants.weightChartCardPadding,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Text(
              '해당 기간에 혈압 기록이 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '혈압을 측정해보세요',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 데이터가 있는 차트 빌드
  Widget _buildDataChart(
      List<Map<String, dynamic>> chartData, List<double> yLabels,
      {double chartHeight = ChartConstants.healthChartHeight}) {
    return _buildDraggableChart(
      chartData,
      yLabels,
      isEmpty: false,
      chartHeight: chartHeight,
    );
  }

  // 드래그 가능한 차트 빌드 (체중 그래프와 동일 패딩·Y축·X축 단위)
  Widget _buildDraggableChart(
      List<Map<String, dynamic>> chartData, List<double> yLabels,
      {required bool isEmpty,
      double chartHeight = ChartConstants.healthChartHeight}) {
    return Container(
      height: chartHeight,
      padding: ChartConstants.weightChartCardPadding,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(builder: (context, outerConstraints) {
              final totalH = outerConstraints.maxHeight;
              final showYHeader = yLabels.length > 1;
              final headerBand =
                  showYHeader ? bloodPressureYAxisUnitBandHeight : 0.0;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buildBloodPressureYAxisStrip(
                    yLabels: yLabels,
                    showYAxisHeader: showYHeader,
                  ),
                  SizedBox(width: ChartConstants.yAxisSpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showYHeader) SizedBox(height: headerBand),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, plotConstraints) {
                              return _buildChartArea(
                                chartData,
                                plotConstraints,
                                isEmpty,
                                yLabels,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.only(
              left: ChartConstants.weightChartYAxisStripWidth,
            ),
            child: _buildBloodPressureXAxisLabels(),
          ),
        ],
      ),
    );
  }

  // 차트 영역 빌드
  Widget _buildChartArea(List<Map<String, dynamic>> chartData,
      BoxConstraints constraints, bool isEmpty, List<double> yLabels) {
    _bpLastPlotWidth = constraints.maxWidth;
    final chartW = constraints.maxWidth;
    final chartH = constraints.maxHeight;

    // 체중 주간·월간과 동일: GestureDetector가 차트+툴팁 Stack을 감싸 onTapDown이 바로 동작
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (selectedPeriod == '일' || selectedPeriod == '월')
          ? (details) {
              _setChartState(() {
                selectedChartPointIndex = null;
                tooltipPosition = null;
              });
              _dragStartX = details.localPosition.dx;
            }
          : null,
      onPanUpdate: (selectedPeriod == '일' || selectedPeriod == '월')
          ? (details) {
              if (_dragStartX != null) {
                final deltaX = details.localPosition.dx - _dragStartX!;
                _handleDragUpdate(deltaX, constraints.maxWidth);
                _dragStartX = details.localPosition.dx;
              }
            }
          : null,
      onPanEnd: (selectedPeriod == '일' || selectedPeriod == '월')
          ? (details) => _dragStartX = null
          : null,
      onTapDown: isEmpty
          ? null
          : (details) {
              _handleChartTapToggle(
                details.localPosition,
                chartData,
                yLabels.last,
                yLabels.first,
                chartW,
                chartH,
              );
            },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: isEmpty
                ? CustomPaint(painter: EmptyChartGridPainter(yLabels: yLabels))
                : CustomPaint(
                    painter: BloodPressureChartPainter(
                      chartData,
                      yLabels.last,
                      yLabels.first,
                      yLabels: yLabels,
                      highlightedIndex: selectedChartPointIndex,
                      isToday: _isToday(),
                      timeOffset: timeOffset,
                      cellCenterXSlots:
                          selectedPeriod == '주' || selectedPeriod == '월',
                    ),
                  ),
          ),
          if (!isEmpty &&
              selectedChartPointIndex != null &&
              tooltipPosition != null &&
              selectedChartPointIndex! >= 0 &&
              selectedChartPointIndex! < chartData.length)
            Positioned(
              left: tooltipPosition!.dx,
              top: tooltipPosition!.dy,
              child: _buildChartTooltip(
                chartData[selectedChartPointIndex!],
                chartW,
                chartH,
              ),
            ),
        ],
      ),
    );
  }

  // 차트 탭 핸들러 - 툴팁 토글 (막대는 세로 전체 밴드 히트, 체중 주/월과 동일 패턴)
  void _handleChartTapToggle(
    Offset tapPosition,
    List<Map<String, dynamic>> chartData,
    double minValue,
    double maxValue,
    double chartWidth,
    double chartHeight,
  ) {
    if (chartData.isEmpty) return;

    final cellCenter =
        selectedPeriod == '주' || selectedPeriod == '월';
    final halfHitW = BloodPressureChartPainter.slotHitHalfWidth(
      chartWidth,
      chartData.length,
      cellCenterXSlots: cellCenter,
    );

    int? closestIndex;
    double minDistance = double.infinity;
    Offset? closestPoint;

    const double topPadding = 20.0;
    const double bottomPadding = 20.0;
    double toY(int value) {
      final clampedValue = value.clamp(minValue.toInt(), maxValue.toInt());
      final nv = (maxValue - clampedValue) / (maxValue - minValue);
      return topPadding +
          (chartHeight - topPadding - bottomPadding) * nv;
    }

    for (int i = 0; i < chartData.length; i++) {
      if ((chartData[i]['recordCount'] as int? ?? 0) == 0) {
        continue;
      }

      final x = BloodPressureChartPainter.slotCenterX(
        i,
        chartData.length,
        chartWidth,
        cellCenterXSlots: cellCenter,
      );

      final dx = (tapPosition.dx - x).abs();
      if (dx > halfHitW * 1.35) {
        continue;
      }

      final systolicMin = chartData[i]['systolicMin'] as int;
      final systolicMax = chartData[i]['systolicMax'] as int;
      final diastolicMin = chartData[i]['diastolicMin'] as int;
      final diastolicMax = chartData[i]['diastolicMax'] as int;
      final recordCount = chartData[i]['recordCount'] as int? ?? 0;

      final ySysMin = toY(systolicMin);
      final ySysMax = toY(systolicMax);
      final yDiaMin = toY(diastolicMin);
      final yDiaMax = toY(diastolicMax);

      double bandDistance;
      Offset tooltipAnchor;

      if (recordCount >= 2) {
        final colTop = math.min(ySysMax, yDiaMax);
        final colBottom = math.max(ySysMin, yDiaMin);
        const yMargin = 14.0;
        final inYBand = tapPosition.dy >= colTop - yMargin &&
            tapPosition.dy <= colBottom + yMargin;
        final yCenter = (colTop + colBottom) / 2;
        bandDistance =
            dx + (inYBand ? 0 : (tapPosition.dy - yCenter).abs());
        tooltipAnchor = Offset(x, colTop);
      } else {
        final ySys = toY(systolicMax);
        final yDia = toY(diastolicMax);
        final yTop = math.min(ySys, yDia);
        final yBot = math.max(ySys, yDia);
        const yMargin = 18.0;
        final inYBand = tapPosition.dy >= yTop - yMargin &&
            tapPosition.dy <= yBot + yMargin;
        final yCenter = (yTop + yBot) / 2;
        bandDistance =
            dx + (inYBand ? 0 : (tapPosition.dy - yCenter).abs());
        tooltipAnchor = Offset(x, yTop);
      }

      if (bandDistance < minDistance) {
        minDistance = bandDistance;
        closestIndex = i;
        closestPoint = tooltipAnchor;
      }
    }

    if (closestIndex != null && minDistance < 220) {
      final idx = closestIndex;
      final pt = closestPoint;
      _setChartState(() {
        if (selectedChartPointIndex == idx) {
          selectedChartPointIndex = null;
          tooltipPosition = null;
        } else {
          selectedChartPointIndex = idx;
          tooltipPosition = pt;
        }
      });
    } else {
      _setChartState(() {
        selectedChartPointIndex = null;
        tooltipPosition = null;
      });
    }
  }

  Future<void> _openExpandedChartPage() async {
    await openHealthChartExpandPage(
      context: context,
      periodSelectorBuilder: (_) => _buildPeriodButtons(),
      chartBuilder: (_) =>
          _buildChart(
              showExpandButton: false,
              forExpandedChart: true,
              chartHeight: ChartConstants.healthChartHeight),
      onRegisterRefresh: (refresh) {
        _refreshExpandedChart = refresh;
      },
      onDisposeRefresh: () {
        _refreshExpandedChart = null;
      },
    );
  }

  // 차트 툴팁 (공통: 흰 배경, 수·이 배지는 수정하기 바텀시트와 동일)
  Widget _buildChartTooltip(
      Map<String, dynamic> data, double chartWidth, double chartHeight) {
    if (tooltipPosition == null) return const SizedBox.shrink();

    if ((data['recordCount'] as int? ?? 0) == 0) {
      return const SizedBox.shrink();
    }

    final systolicMin = data['systolicMin'] as int;
    final systolicMax = data['systolicMax'] as int;
    final diastolicMin = data['diastolicMin'] as int;
    final diastolicMax = data['diastolicMax'] as int;
    final recordCount = data['recordCount'] as int? ?? 0;
    final record = data['record'] as BloodPressureRecord?;

    final bool isRange = recordCount >= 2;
    final String sysText =
        isRange ? '$systolicMin~$systolicMax' : '$systolicMax';
    final String diaText =
        isRange ? '$diastolicMin~$diastolicMax' : '$diastolicMax';

    String headerText;
    if (selectedPeriod == '일') {
      if (record != null) {
        final d = record.measuredAt;
        headerText = '${d.hour}시 ${d.minute}분';
      } else {
        final slot = data['date']?.toString() ?? '';
        final h = int.tryParse(slot) ?? 0;
        headerText = '$h시 0분';
      }
    } else if (selectedPeriod == '주') {
      if (record != null) {
        final d = record.measuredAt;
        headerText = '${d.month}월 ${d.day}일';
      } else {
        headerText = data['date']?.toString() ?? '';
      }
    } else {
      final month = int.tryParse(data['date']?.toString() ?? '') ??
          selectedDate.month;
      headerText = '${selectedDate.year}년 $month월';
    }

    const double tooltipW = 88.0;
    const double tooltipH = 82.0;

    final calculatedTooltipPosition = ChartConstants.calculateTooltipPosition(
      tooltipPosition!,
      tooltipW,
      tooltipH,
      chartWidth,
      chartHeight,
    );

    // 툴팁 width 제한
    final maxTooltipWidth = math.min(
      142.0,
      math.max(96.0, chartWidth - calculatedTooltipPosition.dx - 8),
    );

    Widget valueRowWithBadge({
      required String badgeLabel,
      required Color badgeColor,
      required String value,
    }) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: ShapeDecoration(
              color: badgeColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(19),
              ),
            ),
            child: Center(
              child: Text(
                badgeLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    return Transform.translate(
      offset: Offset(
        calculatedTooltipPosition.dx - tooltipPosition!.dx,
        calculatedTooltipPosition.dy - tooltipPosition!.dy,
      ),
      child: ConstrainedBox(
        // 툴팁 width 제한
        constraints: BoxConstraints(
          minWidth: 88,
          maxWidth: maxTooltipWidth,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                headerText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Gmarket Sans TTF',
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: valueRowWithBadge(
                  badgeLabel: '수',
                  badgeColor: const Color(0xFF85B0FF),
                  value: sysText,
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: valueRowWithBadge(
                  badgeLabel: '이',
                  badgeColor: const Color(0xFFFFBC71),
                  value: diaText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 시간별 기록 선택 바텀시트
  void _showTimeSelectionBottomSheet(List<BloodPressureRecord> records) async {
    final items = records
        .map(
          (record) => HealthEditBottomSheetItem<BloodPressureRecord>(
            data: record,
            timeText: DateFormat('HH:mm').format(record.measuredAt),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 16,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: ShapeDecoration(
                        color: const Color(0xFF85B0FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(19),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          '수',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${record.systolic}',
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 16,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Row(
                  children: [
                    Container(
                      width: 16,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: ShapeDecoration(
                        color: const Color(0xFFFFBC71),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(19),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          '이',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${record.diastolic}',
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 16,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
        .toList();

    final selected = await showHealthEditBottomSheet<BloodPressureRecord>(
      context: context,
      items: items,
    );

    if (selected == null || !mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BloodPressureInputScreen(record: selected),
      ),
    );

    if (result == true && mounted) {
      _loadData();
    }
  }

  // 데이터 없을 때 다이얼로그 표시
  void _showNoDataDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('혈압 기록 없음'),
        content: const Text(
          '아직 혈압 기록이 없습니다.\n지금 혈압을 입력해주세요!',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BloodPressureInputScreen(),
                ),
              );

              if (result == true && mounted) {
                await _loadData();
              }
            },
            child: const Text('혈압 입력하기'),
          ),
        ],
      ),
    );
  }
}

class _PressureLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _PressureLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphSeriesLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _GraphSeriesLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
