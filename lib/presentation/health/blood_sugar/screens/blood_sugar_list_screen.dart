import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../common/chart_layout.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/btn_record.dart';
import '../../health_common/health_chart_axis_style.dart';
import '../../health_common/health_responsive_scale.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../health_common/widgets/health_edit_bottom_sheet.dart';
import '../../health_common/widgets/health_chart_expand_page.dart';
import '../../health_common/widgets/health_expanded_chart_layout.dart';
import '../../health_common/widgets/health_date_selector.dart';
import '../../health_common/widgets/health_list_edit_button.dart';
import '../../../../data/models/health/blood_sugar/blood_sugar_record_model.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/repositories/health/blood_sugar/blood_sugar_repository.dart';
import '../../../../data/services/auth_service.dart';
import '../widgets/blood_sugar_chart_section.dart';
import 'blood_sugar_input_screen.dart';

class BloodSugarListScreen extends StatefulWidget {
  final DateTime? initialDate;

  const BloodSugarListScreen({super.key, this.initialDate});

  @override
  State<BloodSugarListScreen> createState() => _BloodSugarListScreenState();
}

class _BloodSugarListScreenState extends State<BloodSugarListScreen> {
  String selectedPeriod = '일';
  UserModel? currentUser;
  List<BloodSugarRecord> allRecords = []; // 전체 혈당 기록
  Map<String, BloodSugarRecord> bloodSugarRecordsMap = {}; // 날짜별 요약 기록
  Map<String, List<BloodSugarRecord>> dailyRecordsCache = {}; // 날짜별 상세 기록 캐시
  bool isLoading = true;
  late DateTime selectedDate;

  // 차트 관련
  int? selectedChartPointIndex;
  Offset? tooltipPosition;
  double timeOffset = 0.0; // 통합된 드래그 오프셋
  String selectedMeasurementFilter = '전체';
  VoidCallback? _refreshExpandedChart;

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

  BloodSugarRecord? get selectedRecord {
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    return bloodSugarRecordsMap[dateKey];
  }

  // 오늘인지 확인
  bool _isToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;
  }

  // 오늘의 혈당 데이터 가져오기
  List<BloodSugarRecord> getTodayRecords() {
    final today =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    return allRecords.where((record) {
      final recordDate = DateTime(record.measuredAt.year,
          record.measuredAt.month, record.measuredAt.day);
      return recordDate.isAtSameMomentAs(today);
    }).toList();
  }

  // 시간 범위 계산 (통합 로직)
  Map<String, double> _calculateTimeRange({
    double? offset,
    bool forExpandedChart = false,
  }) {
    final maxStartHour = healthDailyMaxStartHour(forExpandedChart);
    final slots = healthDailyHourSlotCount(forExpandedChart);
    // X축 라벨(startHour round)과 동일한 기준을 사용해 점 위치 오차를 제거한다.
    final startHour = ((offset ?? timeOffset) * maxStartHour)
        .clamp(0.0, maxStartHour.toDouble())
        .roundToDouble();
    final endHour =
        (startHour + slots - 1.0).clamp(slots - 1.0, 24.0);

    return {'min': startHour, 'max': endHour};
  }

  /// 일별 그래프: 기본 timeOffset이 6시간 창 밖에 기록이 있으면(오후 식후 등) 안 보임.
  /// 오늘은 현재 시각 기준(오른쪽에서 두번째), 과거 날짜는 마지막 기록이 오른쪽 끝에 오도록 맞춘다.
  void _syncTimeOffsetForSelectedDayRecords() {
    if (selectedPeriod != '일') return;

    if (_isToday()) {
      timeOffset = healthDailyTimeOffsetForToday();
      return;
    }

    final key = DateFormat('yyyy-MM-dd').format(selectedDate);
    final dayRecords = dailyRecordsCache[key] ?? [];
    if (dayRecords.isEmpty) return;

    var maxH = 0;
    for (final r in dayRecords) {
      final h = r.measuredAt.hour;
      if (h > maxH) maxH = h;
    }
    final maxStart = healthDailyMaxStartHour(false);
    final slots = healthDailyHourSlotCount(false);
    final start = (maxH - (slots - 1)).clamp(0, maxStart);
    timeOffset = start / maxStart;
  }

  // 드래그 범위 제한
  double _clampDragOffset(
    double newOffset, {
    String? period,
    bool forExpandedChart = false,
  }) {
    final targetPeriod = period ?? selectedPeriod;
    if (targetPeriod == '월') {
      // 체중·혈압과 동일: 12개월 중 7개월 창 (timeOffset 0~1)
      return newOffset.clamp(0.0, 1.0);
    }
    if (targetPeriod == '일' && _isToday()) {
      final maxOffset = healthDailyTimeOffsetForToday(
        forExpandedChart: forExpandedChart,
      );
      return newOffset.clamp(0.0, maxOffset);
    }
    return newOffset.clamp(0.0, 1.0);
  }

  /// 월별: 선택 날짜의 달이 보이도록 7개월 창 시작 위치
  void _syncMonthlyTimeOffsetForSelectedDate({bool forExpandedChart = false}) {
    if (selectedPeriod != '월') return;
    timeOffset = healthMonthlyTimeOffsetForSelectedMonth(
      selectedDate.month,
      forExpandedChart: forExpandedChart,
    );
  }

  // 드래그 민감도
  double _getDragSensitivity({String? period}) {
    final targetPeriod = period ?? selectedPeriod;
    if (targetPeriod == '월') {
      return 3.0; // 월별 그래프는 민감도를 더 높임
    }
    return 0.5; // 일별 그래프는 기존 민감도 유지
  }

  // 공통 드래그 핸들러
  void _handleDragUpdate(double deltaX, double chartWidth) {
    final sensitivity = _getDragSensitivity();
    final dataDelta = -(deltaX / chartWidth) * sensitivity;
    final newOffset = timeOffset + dataDelta;

    _setChartState(() {
      timeOffset = _clampDragOffset(newOffset);
    });
  }

  // 차트 데이터 생성 (캐시 없이 매번 로드)
  List<Map<String, dynamic>> getChartData({
    String? period,
    double? offset,
    bool forExpandedChart = false,
  }) {
    final targetPeriod = period ?? selectedPeriod;
    final targetOffset = offset ?? timeOffset;
    if (targetPeriod != '일') {
      return _getWeeklyOrMonthlyData(
        period: targetPeriod,
        offset: targetOffset,
        forExpandedChart: forExpandedChart,
      );
    }

    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    // 캐시에서 데이터 가져오기 (없으면 빈 배열)
    final dayRecords = dailyRecordsCache[selectedDateStr] ?? [];

    dayRecords.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

    final timeRange = _calculateTimeRange(
      offset: targetOffset,
      forExpandedChart: forExpandedChart,
    );
    final minHourDiff = timeRange['min']!;
    final maxHourDiff = timeRange['max']!;
    final range = maxHourDiff - minHourDiff;
    if (range <= 0) return [];

    final byHour = <int, List<BloodSugarRecord>>{};
    for (final record in dayRecords) {
      byHour.putIfAbsent(record.measuredAt.hour, () => []).add(record);
    }
    final sortedHours = byHour.keys.toList()..sort();

    final chartData = <Map<String, dynamic>>[];
    for (final hour in sortedHours) {
      final hourRecords = List<BloodSugarRecord>.from(byHour[hour]!)
        ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

      // 같은 시간대라도 측정유형별로 분리해서 그린다.
      // (겹쳐도 허용) -> 범례 색상(공복/식전/식후/취침전/평상시)이 모두 보이도록.
      final byType = <String, List<BloodSugarRecord>>{};
      for (final r in hourRecords) {
        final t =
            r.measurementType.trim().isEmpty ? '기타' : r.measurementType.trim();
        byType.putIfAbsent(t, () => []).add(r);
      }

      final typeEntries = byType.entries.toList()
        ..sort((a, b) => _measurementTypeOrder(a.key)
            .compareTo(_measurementTypeOrder(b.key)));

      for (final e in typeEntries) {
        final typed = List<BloodSugarRecord>.from(e.value)
          ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
        // 같은 시간·같은 측정유형 데이터가 여러 건이면 최댓값 1건만 그래프에 표시
        final record = typed.reduce(
          (a, b) => a.bloodSugar >= b.bloodSugar ? a : b,
        );
        final recordHour = record.measuredAt.hour;
        final chartPoint = _createChartPoint(
          record,
          recordHour,
          minHourDiff,
          maxHourDiff,
          forExpandedChart: forExpandedChart,
        );
        if (chartPoint != null) {
          chartData.add(chartPoint);
        }
      }
    }

    return chartData;
  }

  // 차트 포인트 생성 (통합)
  Map<String, dynamic>? _createChartPoint(
    BloodSugarRecord record,
    int recordHour,
    double minHourDiff,
    double maxHourDiff, {
    bool forExpandedChart = false,
  }) {
    const normalizedMinute = 0;
    final slotCount = healthDailyHourSlotCount(forExpandedChart);
    final windowStartHour = minHourDiff.round();
    final slot = recordHour - windowStartHour;

    // X축 N칸 균등 분할 중앙 — 라벨(Expanded·center)과 동일
    if (slot < 0 || slot >= slotCount) {
      return null;
    }
    final xPosition = (slot + 0.5) / slotCount;

    final dateStr = '$recordHour시';

    return {
      'date': dateStr,
      'hour': recordHour,
      'bloodSugar': record.bloodSugar,
      'measurementType': record.measurementType,
      'record': record,
      'normalizedMinute': normalizedMinute,
      'xPosition': xPosition,
    };
  }

  // 주/월 데이터 — 주: 7일, 월: 체중·혈압과 동일 연도 1~12월 중 7개월 창
  List<Map<String, dynamic>> _getWeeklyOrMonthlyData({
    String? period,
    double? offset,
    bool forExpandedChart = false,
  }) {
    final targetPeriod = period ?? selectedPeriod;
    if (targetPeriod == '주') {
      return _buildWeeklyBloodSugarData();
    }
    return _buildMonthlyBloodSugarData(
      offset: offset ?? timeOffset,
      forExpandedChart: forExpandedChart,
    );
  }

  /// 주별: 각 날짜·측정유형별로 그날 해당 유형 수치의 최댓값 1점 (여러 점이 평면 리스트로 전달됨)
  List<Map<String, dynamic>> _buildWeeklyBloodSugarData() {
    const days = 7;
    final chartPoints = <Map<String, dynamic>>[];
    final endDate = selectedDate;
    final startDate = endDate.subtract(Duration(days: days - 1));

    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final dayRecords = allRecords.where((record) {
        final recordDateStr =
            DateFormat('yyyy-MM-dd').format(record.measuredAt);
        return recordDateStr == dateKey;
      }).toList();

      final xPos = (i + 0.5) / days;
      final dateLabel = '${date.day}';

      if (dayRecords.isEmpty) continue;

      final byType = <String, List<BloodSugarRecord>>{};
      for (final r in dayRecords) {
        final key =
            r.measurementType.trim().isEmpty ? '_기타' : r.measurementType.trim();
        byType.putIfAbsent(key, () => []).add(r);
      }

      for (final e in byType.entries) {
        final list = e.value;
        list.sort((a, b) => b.bloodSugar.compareTo(a.bloodSugar));
        final best = list.first;
        chartPoints.add({
          'date': dateLabel,
          'slotIndex': i,
          'bloodSugar': best.bloodSugar,
          'measurementType': best.measurementType.trim().isEmpty
              ? '기타'
              : best.measurementType.trim(),
          'record': best,
          'xPosition': xPos,
          'useSlotDateTooltip': true,
        });
      }
    }

    chartPoints.sort((a, b) {
      final si = a['slotIndex'] as int;
      final sj = b['slotIndex'] as int;
      if (si != sj) return si.compareTo(sj);
      return _measurementTypeOrder(a['measurementType'] as String?)
          .compareTo(_measurementTypeOrder(b['measurementType'] as String?));
    });
    return chartPoints;
  }

  /// 월별: 각 월·측정유형별로 해당 월 해당 유형 수치의 최댓값 1점
  List<Map<String, dynamic>> _buildMonthlyBloodSugarData({
    double? offset,
    bool forExpandedChart = false,
  }) {
    final visibleMonths = healthMonthlySlotCount(forExpandedChart);
    final year = selectedDate.year;
    final maxStart = healthMonthlyMaxStartIndex(forExpandedChart);
    final startMonthIndex =
        ((offset ?? timeOffset) * maxStart).round().clamp(0, maxStart);

    final chartPoints = <Map<String, dynamic>>[];
    for (int i = 0; i < visibleMonths; i++) {
      final month = startMonthIndex + i + 1;
      final monthRecords = allRecords
          .where(
            (r) => r.measuredAt.year == year && r.measuredAt.month == month,
          )
          .toList();

      final xPos = (i + 0.5) / visibleMonths;
      final label = '$month월';

      if (monthRecords.isEmpty) continue;

      final byType = <String, List<BloodSugarRecord>>{};
      for (final r in monthRecords) {
        final key =
            r.measurementType.trim().isEmpty ? '_기타' : r.measurementType.trim();
        byType.putIfAbsent(key, () => []).add(r);
      }

      for (final e in byType.entries) {
        final list = e.value;
        list.sort((a, b) => b.bloodSugar.compareTo(a.bloodSugar));
        final best = list.first;
        chartPoints.add({
          'date': label,
          'chartYear': year,
          'slotIndex': i,
          'bloodSugar': best.bloodSugar,
          'measurementType': best.measurementType.trim().isEmpty
              ? '기타'
              : best.measurementType.trim(),
          'record': best,
          'xPosition': xPos,
          'useSlotDateTooltip': true,
        });
      }
    }

    chartPoints.sort((a, b) {
      final si = a['slotIndex'] as int;
      final sj = b['slotIndex'] as int;
      if (si != sj) return si.compareTo(sj);
      return _measurementTypeOrder(a['measurementType'] as String?)
          .compareTo(_measurementTypeOrder(b['measurementType'] as String?));
    });
    return chartPoints;
  }

  static int _measurementTypeOrder(String? type) {
    const order = ['공복', '식전', '식후', '취침전', '평상시'];
    final t = type ?? '';
    final i = order.indexOf(t);
    return i >= 0 ? i : 50;
  }

  // 메인 그래프 Y축: 0~400, 100단위
  List<double> getYAxisLabelsMain() {
    return const [400, 300, 200, 100, 0];
  }

  // 확대 그래프 Y축: 요청 반영 (20~200, 20단위 10개)
  List<double> getYAxisLabelsExpanded() {
    return const [200, 180, 160, 140, 120, 100, 80, 60, 40, 20];
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

    if (selectedPeriod == '월') {
      _syncMonthlyTimeOffsetForSelectedDate();
    } else if (_isToday()) {
      final currentHour = now.hour;
      timeOffset = healthDailyTimeOffsetForToday();
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
        // 전체 혈당 기록 한 번만 로드
        allRecords =
            await BloodSugarRepository.getBloodSugarRecords(currentUser!.id);

        // 메모리에서 날짜별로 캐싱 (API 호출 없이 필터링)
        _cacheRecordsFromMemory();

        setState(() {
          _syncTimeOffsetForSelectedDayRecords();
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
    bloodSugarRecordsMap.clear();

    for (var record in allRecords) {
      final dateKey = DateFormat('yyyy-MM-dd').format(record.measuredAt);

      // 날짜별 리스트에 추가
      if (!dailyRecordsCache.containsKey(dateKey)) {
        dailyRecordsCache[dateKey] = [];
      }
      dailyRecordsCache[dateKey]!.add(record);

      // 요약 맵 업데이트 (가장 최근 기록)
      if (!bloodSugarRecordsMap.containsKey(dateKey) ||
          record.measuredAt
              .isAfter(bloodSugarRecordsMap[dateKey]!.measuredAt)) {
        bloodSugarRecordsMap[dateKey] = record;
      }
    }
  }

  // 날짜 변경 시 데이터 로드 (메모리에서 필터링)
  void _loadDataForSelectedDate() {
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);

    // 이미 캐시에 있으면 UI만 업데이트
    if (dailyRecordsCache.containsKey(dateKey)) {
      setState(() {
        _syncTimeOffsetForSelectedDayRecords();
      });
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
      bloodSugarRecordsMap[dateKey] = records.first;
    }

    setState(() {
      _syncTimeOffsetForSelectedDayRecords();
    });
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
          title: '혈당',
          leadingIconSize: healthDp(context, 24),
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
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

                                    if (selectedPeriod == '월') {
                                      _syncMonthlyTimeOffsetForSelectedDate();
                                    } else if (selectedPeriod == '일') {
                                      final now = DateTime.now();
                                      final today = DateTime(
                                          now.year, now.month, now.day);
                                      final isSelectingToday =
                                          newDate.year == today.year &&
                                              newDate.month == today.month &&
                                              newDate.day == today.day;
                                      if (isSelectingToday) {
                                        timeOffset =
                                            healthDailyTimeOffsetForToday();
                                      } else {
                                        timeOffset = 0.0;
                                      }
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
                              _buildBloodSugarDisplay(),
                              SizedBox(height: healthDp(context, 20)),
                              BloodSugarChartSection(
                                selectedPeriod: selectedPeriod,
                                selectedDate: selectedDate,
                                timeOffset: timeOffset,
                                selectedChartPointIndex:
                                    selectedChartPointIndex,
                                tooltipPosition: tooltipPosition,
                                isToday: _isToday(),
                                chartData: getChartData(),
                                yLabels: getYAxisLabelsMain(),
                                hasActualDailyData: (dailyRecordsCache[
                                            DateFormat('yyyy-MM-dd')
                                                .format(selectedDate)] ??
                                        [])
                                    .isNotEmpty,
                                onPeriodChanged: (period) {
                                  _setChartState(() {
                                    selectedPeriod = period;
                                    selectedChartPointIndex = null;
                                    tooltipPosition = null;

                                    if (period == '월') {
                                      _syncMonthlyTimeOffsetForSelectedDate();
                                    } else if (period == '주') {
                                      timeOffset = 0.0;
                                    } else if (period == '일') {
                                      if (_isToday()) {
                                        timeOffset =
                                            healthDailyTimeOffsetForToday();
                                      } else {
                                        timeOffset = 0.0;
                                      }
                                    } else {
                                      timeOffset = 0.0;
                                    }

                                    if (period == '일' && !_isToday()) {
                                      _syncTimeOffsetForSelectedDayRecords();
                                    }
                                  });

                                  if (period == '주' || period == '월') {
                                    _loadPeriodData();
                                  }
                                },
                                onDragUpdate: _handleDragUpdate,
                                selectedMeasurementFilter:
                                    selectedMeasurementFilter,
                                onMeasurementFilterChanged: (value) {
                                  _setChartState(() {
                                    selectedMeasurementFilter = value;
                                    selectedChartPointIndex = null;
                                    tooltipPosition = null;
                                  });
                                },
                                onSelectionChanged: (index, position) {
                                  _setChartState(() {
                                    selectedChartPointIndex = index;
                                    tooltipPosition = position;
                                  });
                                },
                                onExpand: _openExpandedChartPage,
                                chartHeight: healthDp(
                                  context,
                                  ChartConstants.weightChartHeight,
                                ),
                              ),
                              SizedBox(height: healthDp(context, 20)),
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
                            fontFamily: 'Gmarket Sans TTF',
                            fontSize: healthSp(context, 16),
                            fontWeight: FontWeight.w500,
                          ),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BloodSugarInputScreen(
                                  recordContextDate: selectedDate,
                                ),
                              ),
                            );

                            if (result == true || result == null) {
                              await _loadData();
                            }
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

  // 혈당 표시
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

    return GestureDetector(
      onTap: _openSelectedSugarRecordEditor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSugarSummaryCardNew(
                  label: '공복',
                  value: fastingRecord?.bloodSugar.toString() ?? '-',
                  headerColor:
                      _sugarHeaderColor(fastingRecord?.bloodSugar, '공복'),
                  diffText: _sugarDiffText(fastingDiff),
                  diffUp: _isDiffUp(fastingDiff),
                ),
              ),
              SizedBox(width: healthDp(context, 10)),
              Expanded(
                child: _buildSugarSummaryCardNew(
                  label: '식후',
                  value: postMealRecord?.bloodSugar.toString() ?? '-',
                  headerColor:
                      _sugarHeaderColor(postMealRecord?.bloodSugar, '식후'),
                  diffText: _sugarDiffText(postDiff),
                  diffUp: _isDiffUp(postDiff),
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
                    _SugarLegend(color: Color(0xFF71D375), label: '정상'),
                    _SugarLegend(color: Color(0xFFFFE78B), label: '전단계'),
                    _SugarLegend(color: Color(0xFFFF6161), label: '의심'),
                  ],
                ),
              ),
              SizedBox(width: healthDp(context, 10)),
              HealthListEditButton(
                onTap: _openSelectedSugarRecordEditor,
              ),
            ],
          ),
        ],
      ),
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

  String _sugarDiffText(int? diff) {
    if (diff == null) return '수치를 입력하세요';
    return '전날 대비 ${diff.abs()} mg/dL';
  }

  bool _isDiffUp(int? diff) => diff != null && diff > 0;

  /// 혈당 상태별 헤더 색상: 정상 #71D375, 전단계 #FFE78B, 의심 #FF6161.
  /// 사용처: 공복/식후 카드 헤더(_buildSugarSummaryCardNew의 headerColor), 아래 범례(_SugarLegend)와 동일 구간 색상.
  Color _sugarHeaderColor(int? bloodSugar, String type) {
    if (bloodSugar == null) return const Color(0xFF71D375);
    if (type == '공복') {
      if (bloodSugar < 100) return const Color(0xFF71D375); // 정상
      if (bloodSugar <= 125) return const Color(0xFFFFE78B); // 전단계
      return const Color(0xFFFF6161); // 의심
    }
    // 식후
    if (bloodSugar < 140) return const Color(0xFF71D375);
    if (bloodSugar <= 199) return const Color(0xFFFFE78B);
    return const Color(0xFFFF6161);
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

  Future<void> _openExpandedChartPage() async {
    var expandedPeriod = selectedPeriod;
    var expandedTimeOffset = timeOffset;
    var expandedSelectedChartPointIndex = selectedChartPointIndex;
    var expandedTooltipPosition = tooltipPosition;
    var expandedMeasurementFilter = selectedMeasurementFilter;

    double monthlyOffsetForSelectedDate() =>
        healthMonthlyTimeOffsetForSelectedMonth(
          selectedDate.month,
          forExpandedChart: true,
        );

    double dailyInitialOffset() {
      if (!_isToday()) return 0.0;
      return healthDailyTimeOffsetForToday(forExpandedChart: true);
    }

    void refreshExpanded() => _refreshExpandedChart?.call();

    await openHealthChartExpandPage(
      context: context,
      periodSelectorBuilder: (ctx) => HealthExpandedPeriodSelector(
        metrics: healthExpandedMetrics(ctx),
        selectedPeriod: expandedPeriod,
        onChanged: (period) {
          expandedPeriod = period;
          expandedSelectedChartPointIndex = null;
          expandedTooltipPosition = null;
          if (period == '월') {
            expandedTimeOffset = monthlyOffsetForSelectedDate();
          } else if (period == '일') {
            expandedTimeOffset = dailyInitialOffset();
          } else {
            expandedTimeOffset = 0.0;
          }
          refreshExpanded();
        },
      ),
      legendBuilder: (ctx) {
        final m = healthExpandedMetrics(ctx);
        final gap = m.d(17.62);
        const legends = [
          (Color(0xFF4F82E0), '공복'),
          (Color(0xFFFC8B3A), '식전'),
          (Color(0xFF38B769), '식후'),
          (Color(0xFF4FD1E0), '취침전'),
          (Color(0xFFB24FE0), '평상시'),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: m.d(8.81),
          children: [
            for (final e in legends)
              HealthExpandedChartLegendItem(
                metrics: m,
                color: e.$1,
                label: e.$2,
              ),
          ],
        );
      },
      chartBuilder: (_) {
        final base = Theme.of(context);
        final gmarket = base.copyWith(
          textTheme: base.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
          primaryTextTheme:
              base.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            final scaledChartCap = healthExpandedMetrics(context)
                .d(HealthExpandedChartMetrics.chartHeightWithLegend);
            final scaledChartMin = healthDp(context, 160);
            final safeHeight = ChartConstants.healthExpandedChartHeight(
              constraints.maxHeight,
              bottomLegendReserve: 0,
              maxChartHeight: scaledChartCap,
              minChartHeight: scaledChartMin,
            );
            final expandScale =
                healthTextScaleByWidth(MediaQuery.of(context).size.width);
            return Theme(
              data: gmarket,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(expandScale),
                ),
                child: BloodSugarChartSection(
                  selectedPeriod: expandedPeriod,
                  selectedDate: selectedDate,
                  timeOffset: expandedTimeOffset,
                  selectedChartPointIndex: expandedSelectedChartPointIndex,
                  tooltipPosition: expandedTooltipPosition,
                  isToday: _isToday(),
                  chartData: getChartData(
                    period: expandedPeriod,
                    offset: expandedTimeOffset,
                    forExpandedChart: true,
                  ),
                  yLabels: getYAxisLabelsExpanded(),
                  hasActualDailyData: (dailyRecordsCache[
                              DateFormat('yyyy-MM-dd').format(selectedDate)] ??
                          [])
                      .isNotEmpty,
                  showPeriodSelector: false,
                  showLegend: false,
                  forExpandedChart: true,
                  showExpandButton: false,
                  selectedMeasurementFilter: expandedMeasurementFilter,
                  onMeasurementFilterChanged: (value) {
                    expandedMeasurementFilter = value;
                    expandedSelectedChartPointIndex = null;
                    expandedTooltipPosition = null;
                    refreshExpanded();
                  },
                  chartHeight: safeHeight,
                  onDragUpdate: (deltaX, chartWidth) {
                    final sensitivity =
                        _getDragSensitivity(period: expandedPeriod);
                    final dataDelta = -(deltaX / chartWidth) * sensitivity;
                    expandedTimeOffset = _clampDragOffset(
                      expandedTimeOffset + dataDelta,
                      period: expandedPeriod,
                      forExpandedChart: true,
                    );
                    expandedSelectedChartPointIndex = null;
                    expandedTooltipPosition = null;
                    refreshExpanded();
                  },
                  onSelectionChanged: (index, position) {
                    expandedSelectedChartPointIndex = index;
                    expandedTooltipPosition = position;
                    refreshExpanded();
                  },
                ),
              ),
            );
          },
        );
      },
      onRegisterRefresh: (refresh) {
        _refreshExpandedChart = refresh;
      },
      onDisposeRefresh: () {
        _refreshExpandedChart = null;
      },
    );
  }

  // 시간별 기록 선택 바텀시트
  void _showTimeSelectionBottomSheet(List<BloodSugarRecord> records) async {
    final items = records
        .map(
          (record) => HealthEditBottomSheetItem<BloodSugarRecord>(
            data: record,
            timeText: DateFormat('HH:mm').format(record.measuredAt),
            buildTrailing: (ctx) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${record.bloodSugar}',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: const Color(0xFF1A1A1A),
                    fontSize: healthSp(ctx, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: healthDp(ctx, 8)),
                SizedBox(
                  width: _sugarMeasurementTypeBadgeWidth(ctx),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(ctx, 3),
                      vertical: healthDp(ctx, 3),
                    ),
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: _sugarStatusBadgeColor(record),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(healthDp(ctx, 4)),
                      ),
                    ),
                    child: Text(
                      record.measurementType,
                      textAlign: TextAlign.center,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: const Color(0xFF1A1A1A),
                        fontSize: healthSp(ctx, 10),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        letterSpacing: healthDp(ctx, -0.3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();

    final selected = await showHealthEditBottomSheet<BloodSugarRecord>(
      context: context,
      items: items,
    );

    if (selected == null || !mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BloodSugarInputScreen(record: selected),
      ),
    );

    if ((result == true || result == null) && mounted) {
      await _loadData();
    }
  }

  /// 바텀시트 측정 유형 배지 너비 — 3글자(취침전) 기준, 식후·공복 등 2글자도 동일 폭.
  double _sugarMeasurementTypeBadgeWidth(BuildContext context) {
    final style = TextStyle(
      fontSize: healthSp(context, 10),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w500,
      letterSpacing: healthDp(context, -0.3),
    );
    final painter = TextPainter(
      text: TextSpan(text: '취침전', style: style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    return painter.width + healthDp(context, 6);
  }

  /// 수정 바텀시트·상태 배지: 정상·전단계·의심 색 (목록 범례와 동일).
  Color _sugarStatusBadgeColor(BloodSugarRecord record) {
    final status = BloodSugarRecord.calculateStatus(
      record.bloodSugar,
      record.measurementType,
    );
    switch (status) {
      case '정상':
        return const Color(0xFF71D375);
      case '당뇨 전단계':
        return const Color(0xFFFFE78B);
      case '당뇨':
        return const Color(0xFFFF6161);
      default:
        return const Color(0xFF71D375);
    }
  }

}

class _SugarLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _SugarLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: healthDp(context, 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: healthDp(context, 10),
            height: healthDp(context, 10),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: healthDp(context, 3)),
          Text(
            label,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: Colors.black,
              fontSize: healthSp(context, 10),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}
