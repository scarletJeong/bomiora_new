import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/btn_record.dart';
import '../../../common/widgets/app_toast_overlay.dart';
import '../../../common/chart_layout.dart';
import '../../health_common/widgets/health_date_selector.dart';
import '../../health_common/widgets/health_edit_bottom_sheet.dart';
import '../../health_common/widgets/health_chart_expand_page.dart';
import '../../health_common/widgets/health_expanded_chart_layout.dart';
import '../../health_common/widgets/health_period_selector.dart';
import '../../../../data/models/health/weight/weight_record_model.dart';
import '../../../../data/models/health/health_goal_record_model.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/repositories/health/health_goal/health_goal_repository.dart';
import '../../../../data/repositories/health/weight/weight_repository.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../core/utils/image_picker_utils.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../core/health/health_refresh_bus.dart';
import '../../../../core/health/health_refresh_listener.dart';
import '../utils/weight_goal_progress.dart';
import '../widgets/weight_chart_section.dart';
import '../../health_common/widgets/health_delete_popup.dart';
import '../../health_common/health_chart_axis_style.dart';
import '../../health_common/health_chart_metrics.dart';
import '../../health_common/health_responsive_scale.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../health_common/widgets/health_list_edit_button.dart';
import 'weight_input_screen.dart';
part 'weight_list_summary.dart';
part 'weight_list_chart.dart';
part 'weight_list_body.dart';
part 'weight_list_interaction.dart';
part 'weight_list_painters.dart';

/// 목표 체중 링 진행 끝점(호 중심선 위). 12시 시작, 시계 방향으로 [progress]만큼.
Offset _weightGoalRingProgressEndOffset({
  required double boxSize,
  required double strokeWidth,
  required double progress,
}) {
  final c = boxSize / 2;
  final r = boxSize / 2 - strokeWidth / 2;
  final p = progress.clamp(0.0, 1.0);
  final sweep = -math.pi * 2 * p;
  final angle = -math.pi / 2 + sweep;
  return Offset(c + r * math.cos(angle), c + r * math.sin(angle));
}

class WeightListScreen extends StatefulWidget {
  final DateTime? initialDate; // 초기 선택 날짜 (옵션)

  const WeightListScreen({super.key, this.initialDate});

  @override
  State<WeightListScreen> createState() => _WeightListScreenState();
}

class _WeightListScreenState extends State<WeightListScreen>
    with HealthRefreshListener {
  String selectedPeriod = '일'; // 일, 주, 월

  // 사용자 정보
  UserModel? currentUser;
  HealthGoalRecordModel? latestHealthGoal;

  // 체중 기록 목록 (날짜별)
  Map<String, WeightRecord> weightRecordsMap = {}; // 날짜를 키로 하는 맵
  List<WeightRecord> allRecords = []; // 모든 체중 기록 (시간 정보 포함)
  bool isLoading = true;

  // 현재 선택된 날짜 (기본값: 오늘)
  late DateTime selectedDate;

  // 표시할 3개의 날짜 (이전날, 선택된날, 다음날)
  List<DateTime> get displayDates {
    return [
      selectedDate.subtract(const Duration(days: 1)), // 어제
      selectedDate, // 오늘 (선택된 날짜)
      selectedDate.add(const Duration(days: 1)), // 내일
    ];
  }

  // 현재 선택된 날짜의 기록
  WeightRecord? get selectedRecord {
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    return weightRecordsMap[dateKey];
  }

  // 그래프에서 선택된 점 (툴팁 표시용)
  int? selectedChartPointIndex;
  Offset? tooltipPosition;

  // 차트 관련
  double timeOffset = 0.0; // 통합된 드래그 오프셋
  double? _dragStartX;
  VoidCallback? _refreshExpandedChart;

  void _setState(VoidCallback fn) => setState(fn);

  void _notifyExpandedChart() {
    _refreshExpandedChart?.call();
  }

  bool _isToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;
  }

  // 드래그 범위: 월 고정 / 일별은 6시간 창 슬라이드(오늘은 현재시각 기준)
  double _clampDragOffset(
    double newOffset, {
    bool forExpandedChart = false,
  }) {
    if (selectedPeriod == '월') {
      return newOffset.clamp(0.0, 1.0);
    }
    if (selectedPeriod == '일' && _isToday()) {
      final maxOffset = healthDailyTimeOffsetForToday(
        forExpandedChart: forExpandedChart,
      );
      return newOffset.clamp(0.0, maxOffset);
    }
    if (selectedPeriod == '일') {
      return newOffset.clamp(0.0, 1.0);
    }
    return newOffset.clamp(0.0, 1.0);
  }

  // 드래그 민감도
  double _getDragSensitivity() {
    return 0.5;
  }

  // 공통 드래그 핸들러
  void _handleDragUpdate(
    double deltaX,
    double chartWidth, {
    bool forExpandedChart = false,
  }) {
    final sensitivity = _getDragSensitivity();
    final dataDelta = -(deltaX / chartWidth) * sensitivity;
    final newOffset = timeOffset + dataDelta;

    setState(() {
      timeOffset = _clampDragOffset(
        newOffset,
        forExpandedChart: forExpandedChart,
      );
    });
    _notifyExpandedChart();
  }

  /// 혈압 일그래프와 동일: N시간 뷰 시작·끝 시각
  Map<String, double> _calculateTimeRange({bool forExpandedChart = false}) {
    final maxStartHour = healthDailyMaxStartHour(forExpandedChart);
    final slots = healthDailyHourSlotCount(forExpandedChart);
    final startHour =
        (timeOffset * maxStartHour).clamp(0.0, maxStartHour.toDouble());
    final endHour = (startHour + slots - 1.0).clamp(slots - 1.0, 24.0);
    return {'min': startHour, 'max': endHour};
  }

  /// 시간대별(일): 선택일 당일 기록 유무 — 무기록이면 혈당과 동일 안내 카드
  bool _hasWeightRecordsOnSelectedDate() {
    final key = DateFormat('yyyy-MM-dd').format(selectedDate);
    return allRecords.any(
      (r) => DateFormat('yyyy-MM-dd').format(r.measuredAt) == key,
    );
  }

  double _dailyOffsetForDate(
    DateTime date, {
    bool forExpandedChart = false,
  }) {
    final day = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final maxStart = healthDailyMaxStartHour(forExpandedChart);

    if (day == today) {
      return healthDailyTimeOffsetForToday(forExpandedChart: forExpandedChart);
    }

    final recordsForDay = allRecords.where((record) {
      final measured = record.measuredAt;
      return measured.year == day.year &&
          measured.month == day.month &&
          measured.day == day.day;
    }).toList();

    if (recordsForDay.isEmpty) {
      return 0.0;
    }

    recordsForDay.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    final firstHour = recordsForDay.first.measuredAt.hour;
    final startHourTarget = (firstHour - 1).clamp(0, maxStart);
    return startHourTarget / maxStart;
  }

  double? _latestWeight() {
    if (allRecords.isEmpty) return null;
    final sorted = List<WeightRecord>.from(allRecords)
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    return sorted.last.weight;
  }

  double? _selectedMonthAverageWeight() {
    final list = allRecords.where((record) {
      return record.measuredAt.year == selectedDate.year &&
          record.measuredAt.month == selectedDate.month;
    }).toList();
    if (list.isEmpty) return null;
    final sum = list.fold<double>(0, (acc, e) => acc + e.weight);
    return sum / list.length;
  }

  // 차트 데이터 생성
  List<Map<String, dynamic>> getChartData({bool forExpandedChart = false}) {
    if (selectedPeriod == '월') {
      return _getCalendarYearMonthlyWeightData();
    }
    if (selectedPeriod == '주') {
      return _getSevenDayWeightChartData();
    }

    // 일: 선택일 당일 기록만, 시간 순
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final todayRecords = allRecords.where((record) {
      final recordDateStr = DateFormat('yyyy-MM-dd').format(record.measuredAt);
      return recordDateStr == selectedDateStr;
    }).toList();

    todayRecords.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

    final timeRange = _calculateTimeRange(forExpandedChart: forExpandedChart);
    final slots = healthDailyHourSlotCount(forExpandedChart);
    final minHourDiff = timeRange['min']!;
    final maxHourDiff = timeRange['max']!;
    final range = maxHourDiff - minHourDiff;
    final windowStartHour = minHourDiff.round();
    if (range <= 0) {
      return [];
    }

    final byHour = <int, List<WeightRecord>>{};
    for (final record in todayRecords) {
      byHour.putIfAbsent(record.measuredAt.hour, () => []).add(record);
    }
    final sortedHours = byHour.keys.toList()..sort();

    final chartData = <Map<String, dynamic>>[];
    for (final hour in sortedHours) {
      final hourRecords = List<WeightRecord>.from(byHour[hour]!)
        ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
      if (hourRecords.length >= 2) {
        final minW =
            hourRecords.map((r) => r.weight).reduce((a, b) => a < b ? a : b);
        final maxW =
            hourRecords.map((r) => r.weight).reduce((a, b) => a > b ? a : b);
        final slot = (hour - windowStartHour).clamp(0, slots - 1).toInt();
        chartData.add({
          'date': '$hour시',
          'weight': null,
          'minWeight': minW,
          'maxWeight': maxW,
          'hourSlotBar': true,
          'hour': hour,
          'normalizedMinute': 0,
          'record': hourRecords.last,
          'records': hourRecords,
          'count': hourRecords.length,
          'xPosition': (slot + 0.5) / slots,
        });
      } else {
        final record = hourRecords.single;
        final recordHour = record.measuredAt.hour;
        const normalizedMinute = 0;
        final slot = (recordHour - windowStartHour).clamp(0, slots - 1).toInt();

        chartData.add({
          'date': '$recordHour시',
          'weight': record.weight,
          'record': record,
          'hour': recordHour,
          'normalizedMinute': normalizedMinute,
          'xPosition': (slot + 0.5) / slots,
        });
      }
    }

    return chartData;
  }

  /// 주별: 선택일 포함 최근 7일 (날짜별 최신값·min/max·개수)
  List<Map<String, dynamic>> _getSevenDayWeightChartData() {
    List<Map<String, dynamic>> chartData = [];
    const days = 7;

    final endDate =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final startDate = endDate.subtract(Duration(days: days - 1));

    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);

      final dayRecords = allRecords.where((record) {
        final recordDateStr =
            DateFormat('yyyy-MM-dd').format(record.measuredAt);
        return recordDateStr == dateKey;
      }).toList();

      if (dayRecords.isNotEmpty) {
        dayRecords.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
        final latestRecord = dayRecords.last;
        final minWeight = dayRecords
            .map((record) => record.weight)
            .reduce((a, b) => a < b ? a : b);
        final maxWeight = dayRecords
            .map((record) => record.weight)
            .reduce((a, b) => a > b ? a : b);

        chartData.add({
          'date': '${date.day}',
          'weight': latestRecord.weight,
          'record': latestRecord,
          'minWeight': minWeight,
          'maxWeight': maxWeight,
          'count': dayRecords.length,
          'xPosition': i / days,
        });
      } else {
        chartData.add({
          'date': '${date.day}',
          'weight': null,
          'record': null,
          'minWeight': null,
          'maxWeight': null,
          'count': 0,
          'xPosition': i / days,
        });
      }
    }

    return chartData;
  }

  /// 월별: [selectedDate]의 연도 기준 1~12월, 월 단위 최소·최대 체중 (주간 막대와 동일 개념)
  List<Map<String, dynamic>> _getCalendarYearMonthlyWeightData() {
    final year = selectedDate.year;
    final chartData = <Map<String, dynamic>>[];

    for (int m = 1; m <= 12; m++) {
      final monthRecords = allRecords.where((record) {
        return record.measuredAt.year == year && record.measuredAt.month == m;
      }).toList();

      if (monthRecords.isNotEmpty) {
        monthRecords.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
        final minWeight = monthRecords
            .map((record) => record.weight)
            .reduce((a, b) => a < b ? a : b);
        final maxWeight = monthRecords
            .map((record) => record.weight)
            .reduce((a, b) => a > b ? a : b);
        final latestRecord = monthRecords.last;

        chartData.add({
          'date': '$m월',
          'weight': latestRecord.weight,
          'record': latestRecord,
          'minWeight': minWeight,
          'maxWeight': maxWeight,
          'count': monthRecords.length,
          'xPosition': (m - 1) / 11.0,
          'month': m,
          'year': year,
        });
      } else {
        chartData.add({
          'date': '$m월',
          'weight': null,
          'record': null,
          'minWeight': null,
          'maxWeight': null,
          'count': 0,
          'xPosition': (m - 1) / 11.0,
          'month': m,
          'year': year,
        });
      }
    }

    return chartData;
  }

  /// 메인 체중 그래프 Y축: 총 5개 숫자 눈금(위→아래).
  /// - 시간대별/일자별: 최근 체중 기준 1kg 간격
  /// - 월별: 선택 월 평균 체중 기준 3kg 간격
  List<double> getYAxisLabelsMain() {
    if (selectedPeriod == '월') {
      final monthAvg = _selectedMonthAverageWeight() ?? _latestWeight() ?? 65.0;
      final center = monthAvg.roundToDouble();
      final top = center + 6.0;
      return List<double>.generate(5, (i) => top - (i * 3.0));
    }

    final latest = _latestWeight() ?? 65.0;
    final center = latest.roundToDouble();
    final top = center + 2.0;
    return List<double>.generate(5, (i) => top - i);
  }

  /// 확대 체중 그래프 Y축: 총 7개 숫자 눈금(위→아래).
  /// - 시간대별/일자별: 최근 체중 기준 1kg 간격(±3kg)
  /// - 월별: 선택 월 평균 체중 기준 3kg 간격(근사 ±10kg)
  List<double> getYAxisLabelsExpanded() {
    if (selectedPeriod == '월') {
      final monthAvg = _selectedMonthAverageWeight() ?? _latestWeight() ?? 65.0;
      final center = monthAvg.roundToDouble();
      final top = center + 9.0;
      return List<double>.generate(7, (i) => top - (i * 3.0));
    }

    final latest = _latestWeight() ?? 65.0;
    final center = latest.roundToDouble();
    final top = center + 3.0;
    return List<double>.generate(7, (i) => top - i);
  }

  @override
  void initState() {
    super.initState();
    // 전달받은 날짜 또는 오늘 날짜로 초기화 (시간은 00:00:00으로 설정)
    if (widget.initialDate != null) {
      selectedDate = DateTime(
        widget.initialDate!.year,
        widget.initialDate!.month,
        widget.initialDate!.day,
      );
    } else {
      final now = DateTime.now();
      selectedDate = DateTime(now.year, now.month, now.day);
    }

    if (_isToday()) {
      timeOffset = _dailyOffsetForDate(selectedDate);
    }

    _loadData();
  }

  @override
  void onHealthDataChanged() {
    if (!healthRefreshIncludes(HealthRefreshDomain.weight)) return;
    _loadData();
  }

  // 데이터 로드
  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // 사용자 정보 가져오기
      currentUser = await AuthService.getUser();

      if (currentUser != null) {
        final results = await Future.wait<dynamic>([
          WeightRepository.getWeightRecords(currentUser!.id),
          HealthGoalRepository.fetchLatest(currentUser!.id),
        ]);
        final records = results[0] as List<WeightRecord>;
        final goal = results[1] as HealthGoalRecordModel?;

        // 모든 기록 저장 (시간 정보 포함)
        allRecords = records;

        // 날짜를 키로 하는 맵으로 변환 (각 날짜의 마지막 기록)
        weightRecordsMap.clear();
        for (var record in records) {
          final dateKey = DateFormat('yyyy-MM-dd').format(DateTime(
              record.measuredAt.year,
              record.measuredAt.month,
              record.measuredAt.day));
          // 같은 날짜에 여러 기록이 있으면 가장 최근 것만 저장
          if (!weightRecordsMap.containsKey(dateKey) ||
              record.measuredAt
                  .isAfter(weightRecordsMap[dateKey]!.measuredAt)) {
            weightRecordsMap[dateKey] = record;
          }
        }

        setState(() {
          latestHealthGoal = goal;
          if (selectedPeriod == '일') {
            timeOffset = _dailyOffsetForDate(selectedDate);
          }
          isLoading = false;
        });
      } else {
        setState(() {
          latestHealthGoal = null;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
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
        appBar: const HealthAppBar(title: '체중'),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          // 기간 탭 변경 시 전체 위젯 트리를 교체하면 스크롤 위치가 초기화됨
          // (특히 '주/월'에서 _loadData()로 isLoading=true가 되며 상단으로 튀는 현상)
          // → 스크롤 뷰는 유지하고 로딩 오버레이만 올린다.
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: healthDp(context, 27),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 0. 날짜 선택 공통 위젯
                            HealthDateSelector(
                              selectedDate: selectedDate,
                              onDateChanged: (newDate) {
                                setState(() {
                                  selectedDate = newDate;
                                  selectedChartPointIndex = null;
                                  tooltipPosition = null;

                                  timeOffset = _dailyOffsetForDate(newDate);
                                });
                                _notifyExpandedChart();
                                _loadData();
                              },
                              monthTextColor: const Color(0xFF898686),
                              selectedTextColor: const Color(0xFFFF5A8D),
                              unselectedTextColor: const Color(0xFFB7B7B7),
                              dividerColor: const Color(0xFFD2D2D2),
                              iconColor: const Color(0xFF898686),
                            ),
                            SizedBox(height: healthDp(context, 16)),

                            // 1~3. 상단 요약 카드 영역 (시안 기준)
                            _buildTopWeightSummaryCard(),
                            SizedBox(height: healthDp(context, 20)),
                            _buildBmiSummaryCard(),
                            SizedBox(height: healthDp(context, 30)),

                            // 4~5. 체중 차트(기간 탭은 카드 안)
                            WeightChartSection(
                              chartContent: _buildChartContent(),
                            ),
                            SizedBox(height: healthDp(context, 20)),

                            // 6. 눈바디 이미지
                            _buildBodyImages(),
                            SizedBox(height: healthDp(context, 120)),
                          ],
                        ),
                      ),
                    ),
                    if (isLoading)
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: true,
                          child: Container(
                            color: Colors.transparent,
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(
                              color: Color(0xFFFF5A8D),
                            ),
                          ),
                        ),
                      ),
                  ],
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
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WeightInputScreen(
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
