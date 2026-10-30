import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/btn_record.dart';
import '../../../common/chart_layout.dart';
import '../../health_common/health_chart_axis_style.dart';
import '../../health_common/health_responsive_scale.dart';
import '../../health_common/health_vital_status.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../health_common/widgets/health_edit_bottom_sheet.dart';
import '../../health_common/widgets/health_period_selector.dart';
import '../../health_common/widgets/health_chart_expand_control.dart';
import '../../health_common/widgets/health_chart_expand_page.dart';
import '../../health_common/widgets/health_expanded_chart_layout.dart';
import '../../health_common/widgets/health_date_selector.dart';
import '../../health_common/widgets/health_list_edit_button.dart';
import '../../../../data/models/health/blood_pressure/blood_pressure_record_model.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/repositories/health/blood_pressure/blood_pressure_repository.dart';
import '../../../../core/health/health_refresh_bus.dart';
import '../../../../core/health/health_refresh_listener.dart';
import '../../../../data/services/auth_service.dart';
import 'blood_pressure_input_screen.dart';
import '../widgets/blood_pressure_chart_section.dart';
import '../widgets/blood_pressure_chart_tooltip.dart';
part 'blood_pressure_list_summary.dart';
part 'blood_pressure_list_chart.dart';
part 'blood_pressure_list_sheet.dart';
part 'blood_pressure_list_legends.dart';

class BloodPressureListScreen extends StatefulWidget {
  final DateTime? initialDate;

  const BloodPressureListScreen({super.key, this.initialDate});

  @override
  State<BloodPressureListScreen> createState() =>
      _BloodPressureListScreenState();
}

class _BloodPressureListScreenState extends State<BloodPressureListScreen>
    with HealthRefreshListener {
  String selectedPeriod = '일';
  UserModel? currentUser;
  List<BloodPressureRecord> allRecords = []; // 전체 혈압 기록
  Map<String, BloodPressureRecord> bloodPressureRecordsMap = {}; // 날짜별 요약 기록
  Map<String, List<BloodPressureRecord>> dailyRecordsCache = {}; // 날짜별 상세 기록 캐시
  bool isLoading = true;
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
  Map<String, double> _calculateTimeRange({bool forExpandedChart = false}) {
    final maxStartHour = healthDailyMaxStartHour(forExpandedChart);
    final slots = healthDailyHourSlotCount(forExpandedChart);
    // X축 라벨과 데이터 슬롯이 같은 시작 시간을 쓰도록 round 기준으로 통일한다.
    final startHour = (timeOffset * maxStartHour)
        .clamp(0.0, maxStartHour.toDouble())
        .roundToDouble();
    final endHour = (startHour + slots - 1.0).clamp(slots - 1.0, 24.0);

    return {'min': startHour, 'max': endHour};
  }

  // 드래그 범위 제한
  double _clampDragOffset(
    double newOffset, {
    bool forExpandedChart = false,
  }) {
    if (selectedPeriod == '월') {
      if (healthMonthlyMaxStartIndex(forExpandedChart) == 0) {
        return 0.0;
      }
      return newOffset.clamp(0.0, 1.0);
    }

    if (_isToday()) {
      final maxOffset = healthDailyTimeOffsetForToday(
        forExpandedChart: forExpandedChart,
      );
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
  void _handleDragUpdate(
    double deltaX,
    double chartWidth, {
    bool forExpandedChart = false,
  }) {
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
        timeOffset = _clampDragOffset(
          timeOffset + dataDelta,
          forExpandedChart: forExpandedChart,
        );
      });
    });
  }

  // 차트 데이터 생성
  // - 슬롯 내 기록 1건: 점
  // - 슬롯 내 기록 2건 이상: 최저~최고 막대
  List<Map<String, dynamic>> getChartData({bool forExpandedChart = false}) {
    if (selectedPeriod == '일') {
      return _buildHourlyChartData(forExpandedChart: forExpandedChart);
    }
    if (selectedPeriod == '주') {
      return _buildDailyRangeChartData();
    }
    return _buildMonthlyRangeChartData(forExpandedChart: forExpandedChart);
  }

  /// 시간대별 차트는 N시간 창만 보여 줌. 창 밖에만 기록이 있으면 빈 그래프로 보이므로
  /// 해당 날 기록이 보이도록 timeOffset을 맞춤.
  void _ensureHourlyWindowShowsData({bool forExpandedChart = false}) {
    if (selectedPeriod != '일') return;
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final dayRecords = dailyRecordsCache[selectedDateStr] ?? [];
    if (dayRecords.isEmpty) return;

    final slots = healthDailyHourSlotCount(forExpandedChart);
    final maxStart = healthDailyMaxStartHour(forExpandedChart);
    final startHour =
        _calculateTimeRange(forExpandedChart: forExpandedChart)['min']!.floor();
    var visibleHasData = false;
    for (int i = 0; i < slots; i++) {
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
    final low = (maxH - (slots - 1)).clamp(0, maxStart);
    final high = minH.clamp(0, maxStart);
    final startTarget =
        low <= high ? low : (maxH - (slots - 1)).clamp(0, maxStart);
    timeOffset = _clampDragOffset(
      startTarget / maxStart,
      forExpandedChart: forExpandedChart,
    );
  }

  List<Map<String, dynamic>> _buildHourlyChartData({
    bool forExpandedChart = false,
  }) {
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final dayRecords = (dailyRecordsCache[selectedDateStr] ?? [])
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

    final slots = healthDailyHourSlotCount(forExpandedChart);
    final startHour =
        _calculateTimeRange(forExpandedChart: forExpandedChart)['min']!.floor();
    final labels = List.generate(
      slots,
      (i) => (startHour + i).clamp(0, 23).toString().padLeft(2, '0'),
    );

    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < slots; i++) {
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
    final endDate =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
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

  /// 체중 월별과 동일: [selectedDate] 연도 기준 1~12월 중 N개월 창 슬라이드
  List<Map<String, dynamic>> _buildMonthlyRangeChartData({
    bool forExpandedChart = false,
  }) {
    final visibleMonths = healthMonthlySlotCount(forExpandedChart);
    final year = selectedDate.year;
    final maxStart = healthMonthlyMaxStartIndex(forExpandedChart);
    final startIndex = (timeOffset * maxStart).round().clamp(0, maxStart);

    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < visibleMonths; i++) {
      final month = startIndex + i + 1;
      final records = allRecords
          .where(
              (r) => r.measuredAt.year == year && r.measuredAt.month == month)
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
    final unitReserve =
        healthDp(context, ChartConstants.weightXAxisUnitReservedWidth);
    final inset = BloodPressureChartPainter.borderWidth +
        healthDp(context, BloodPressureChartPainter.basePointRadius);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          // 플롯 시작/끝 좌표와 동일한 inset을 라벨 행에도 적용 (scale 반영)
          padding: EdgeInsets.only(left: inset, right: unitReserve + inset),
          child: labelRow,
        ),
        Positioned(
          right: -healthDp(context, 10),
          top: healthDp(context, 3),
          child: Text(
            unitText,
            style: healthChartAxisUnitTextStyle(context),
          ),
        ),
      ],
    );
  }

  Widget _buildBloodPressureXAxisLabels({bool forExpandedChart = false}) {
    if (selectedPeriod == '일') {
      final slots = healthDailyHourSlotCount(forExpandedChart);
      final startHour =
          _calculateTimeRange(forExpandedChart: forExpandedChart)['min']!
              .round();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final selDay =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final isToday = selDay == today;
      final currentHour = now.hour;

      final hourLabels = <Widget>[];
      for (int i = 0; i < slots; i++) {
        final hour = (startHour + i).clamp(0, 24);
        final hourLabel = hour == 24 ? '24' : hour.toString().padLeft(2, '0');
        final isCurrentHour = isToday && hour == currentHour;
        hourLabels.add(
          Expanded(
            child: Text(
              hourLabel,
              textAlign: TextAlign.center,
              style: healthChartAxisTickTextStyle(
                context,
                color: isCurrentHour ? healthChartAxisCurrentHourColor : null,
              ),
            ),
          ),
        );
      }
      return _buildBloodPressureXAxisWithUnit(
        labelRow: Row(children: hourLabels),
        unitText: '(시)',
      );
    }

    if (selectedPeriod == '월') {
      final visibleMonths = healthMonthlySlotCount(forExpandedChart);
      final maxStart = healthMonthlyMaxStartIndex(forExpandedChart);
      final startIndex = (timeOffset * maxStart).round().clamp(0, maxStart);

      return _buildBloodPressureXAxisWithUnit(
        labelRow: Row(
          children: List.generate(visibleMonths, (i) {
            final m = startIndex + i + 1;
            return Expanded(
              child: Text(
                '$m',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: healthChartAxisTickTextStyle(context),
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
      children: List.generate(days, (i) {
        final date = startDate.add(Duration(days: i));
        return Expanded(
          child: Text(
            '${date.day}',
            style: healthChartAxisTickTextStyle(context),
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
      timeOffset = healthDailyTimeOffsetForToday();
    }

    // 월별: 체중과 동일 1~7월부터 시작, 드래그로 6~12월까지
    if (selectedPeriod == '월') {
      timeOffset = 0.0;
    }

    _loadData();
  }

  @override
  void onHealthDataChanged() {
    if (!healthRefreshIncludes(HealthRefreshDomain.bloodPressure)) return;
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

        setState(() {
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
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
    final textScale = healthTextScaleByWidth(MediaQuery.of(context).size.width);

    return Theme(
      data: gmarketTheme,
      child: MobileAppLayoutWrapper(
        appBar: HealthAppBar(
          title: '혈압',
          leadingIconSize: healthDp(context, 24),
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF5A8D)),
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: healthDp(context, 27),
                          ),
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
                                      timeOffset =
                                          healthDailyTimeOffsetForToday();
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
                              SizedBox(height: healthDp(context, 20)),
                              _buildBloodPressureDisplay(),
                              SizedBox(height: healthDp(context, 20)),
                              _buildChart(
                                chartHeight: healthDp(
                                  context,
                                  ChartConstants.weightChartHeight,
                                ),
                              ),
                              SizedBox(height: healthDp(context, 20)),
                              Row(
                                children: [
                                  const _GraphSeriesLegend(
                                      color: Color(0xFF86B0FF), label: '수축기'),
                                  SizedBox(width: healthDp(context, 12)),
                                  const _GraphSeriesLegend(
                                      color: Color(0xFFFFC686), label: '이완기'),
                                ],
                              ),
                              SizedBox(height: healthDp(context, 24)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          healthDp(context, 27),
                          healthDp(context, 8),
                          healthDp(context, 27),
                          healthDp(context, 16),
                        ),
                        child: BtnRecord(
                          text: '+기록하기',
                          labelTextScaler: TextScaler.noScaling,
                          textStyle: TextStyle(
                            color: Colors.white,
                            fontSize: healthSp(context, 16),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BloodPressureInputScreen(
                                  recordContextDate: selectedDate,
                                ),
                              ),
                            );
                          },
                          backgroundColor: const Color(0xFFFF5A8D),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
