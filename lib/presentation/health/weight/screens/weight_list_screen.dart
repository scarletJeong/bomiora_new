import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/btn_record.dart';
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
import '../widgets/weight_chart_section.dart';
import '../utils/weight_goal_progress.dart';
import '../../health_common/health_chart_metrics.dart';
import '../../health_common/health_responsive_scale.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../health_common/widgets/health_list_edit_button.dart';
import 'weight_input_screen.dart';

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

class _WeightListScreenState extends State<WeightListScreen> {
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
  double _clampDragOffset(double newOffset) {
    if (selectedPeriod == '월') {
      return newOffset.clamp(0.0, 1.0);
    }
    if (selectedPeriod == '일' && _isToday()) {
      final now = DateTime.now();
      final currentHour = now.hour;
      final maxStartHour = (currentHour - 5).clamp(0, 18);
      final maxOffset = maxStartHour / 18.0;
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
  void _handleDragUpdate(double deltaX, double chartWidth) {
    final sensitivity = _getDragSensitivity();
    final dataDelta = -(deltaX / chartWidth) * sensitivity;
    final newOffset = timeOffset + dataDelta;

    setState(() {
      timeOffset = _clampDragOffset(newOffset);
    });
    _notifyExpandedChart();
  }

  /// 혈압 일그래프와 동일: 6시간 뷰 시작·끝 시각
  Map<String, double> _calculateTimeRange() {
    const maxStartHour = 18;
    final startHour =
        (timeOffset * maxStartHour).clamp(0.0, maxStartHour.toDouble());
    final endHour = (startHour + 6.0).clamp(6.0, 24.0);
    return {'min': startHour, 'max': endHour};
  }

  /// 시간대별(일): 선택일 당일 기록 유무 — 무기록이면 혈당과 동일 안내 카드
  bool _hasWeightRecordsOnSelectedDate() {
    final key = DateFormat('yyyy-MM-dd').format(selectedDate);
    return allRecords.any(
      (r) => DateFormat('yyyy-MM-dd').format(r.measuredAt) == key,
    );
  }

  double _dailyOffsetForDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (day == today) {
      final startHourTarget = (now.hour - 5).clamp(0, 18);
      return startHourTarget / 18.0;
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
    final startHourTarget = (firstHour - 1).clamp(0, 18);
    return startHourTarget / 18.0;
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
  List<Map<String, dynamic>> getChartData() {
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

    final timeRange = _calculateTimeRange();
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
        final slot = (hour - windowStartHour).clamp(0, 6).toInt();
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
          'xPosition': (slot + 0.5) / 7.0,
        });
      } else {
        final record = hourRecords.single;
        final recordHour = record.measuredAt.hour;
        const normalizedMinute = 0;
        final slot = (recordHour - windowStartHour).clamp(0, 6).toInt();

        chartData.add({
          'date': '$recordHour시',
          'weight': record.weight,
          'record': record,
          'hour': recordHour,
          'normalizedMinute': normalizedMinute,
          'xPosition': (slot + 0.5) / 7.0,
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

  // 데이터 로드
  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // 사용자 정보 가져오기
      currentUser = await AuthService.getUser();

      if (currentUser != null) {
        // 체중 기록 목록 가져오기
        final records =
            await WeightRepository.getWeightRecords(currentUser!.id);
        final goal = await HealthGoalRepository.fetchLatest(currentUser!.id)
            .catchError((_) => null);

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
                              SizedBox(height: healthDp(context, 20)),
                              Padding(
                                padding: EdgeInsets.only(bottom: healthDp(context, 20)),
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
                                        builder: (context) => WeightInputScreen(
                                          recordContextDate: selectedDate,
                                        ),
                                      ),
                                    );

                                    if (result == true && mounted) {
                                      _loadData();
                                    }
                                  },
                                  backgroundColor: const Color(0xFFFF5A8D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTopWeightSummaryCard() {
    final weight = selectedRecord?.weight ?? 0.0;
    final height = selectedRecord?.height ?? 0.0;
    final targetWeight = latestHealthGoal?.targetWeight ?? 0.0;
    final goalStartWeight = latestHealthGoal?.currentWeight ?? 0.0;
    final lostWeight =
        (weight > 0 && goalStartWeight > 0) ? (weight - goalStartWeight) : 0.0;
    final progressRatio = (weight <= 0 || targetWeight <= 0)
        ? 0.0
        : weightTowardGoalRatio(weight, targetWeight, goalStartWeight);
    // 오늘의 체중 흰 카드 바깥 패딩 없음. 349 안 좌우는 논리 10. 세로: healthDp(18)·원193·10·수정·10·메트릭·10.
    final squareSide = healthDp(context, 349);
    final chartDiameter = healthDp(context, 193);
    final ringStroke = healthDp(context, 18); // 원형차트 굵기기
    final chartTopGap = healthDp(context, 38);
    const double chartToButtonGap = 10;
    final chartBandH = chartTopGap + chartDiameter + chartToButtonGap;
    final buttonBandH = healthDp(context, 22);

    /// 수정하기 ↔ 메트릭 / 메트릭 ↔ 하단 (스케일 없이 10).
    const double gapBeforeMetricsBand = 10;
    const double gapAfterMetricsBand = 10;

    /// 301 정사각형 안 메트릭 행 최소 높이 (375 기준 66).
    final metricsBandH = healthDp(context, 66);
    final innerContentH = chartBandH +
        buttonBandH +
        gapBeforeMetricsBand +
        metricsBandH +
        gapAfterMetricsBand;
    final innerDesignH = innerContentH;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x19000000),
            blurRadius: healthDp(context, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: squareSide,
            height: squareSide,
            child: innerDesignH > squareSide + 0.5
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return ClipRect(
                          child: FittedBox(
                            fit: BoxFit.fitWidth,
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: constraints.maxWidth,
                              height: innerDesignH,
                              child: _topWeightSummarySquareContent(
                                context: context,
                                chartDiameter: chartDiameter,
                                ringStroke: ringStroke,
                                progressRatio: progressRatio,
                                weight: weight,
                                heightCm: height,
                                targetWeight: targetWeight,
                                goalStartWeight: goalStartWeight,
                                lostWeight: lostWeight,
                                chartBandH: chartBandH,
                                chartTopGap: chartTopGap,
                                chartToButtonGap: chartToButtonGap,
                                buttonBandH: buttonBandH,
                                gapBeforeMetricsBand: gapBeforeMetricsBand,
                                metricsBandH: metricsBandH,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: _topWeightSummarySquareContent(
                          context: context,
                          chartDiameter: chartDiameter,
                          ringStroke: ringStroke,
                          progressRatio: progressRatio,
                          weight: weight,
                          heightCm: height,
                          targetWeight: targetWeight,
                          goalStartWeight: goalStartWeight,
                          lostWeight: lostWeight,
                          chartBandH: chartBandH,
                          chartTopGap: chartTopGap,
                          chartToButtonGap: chartToButtonGap,
                          buttonBandH: buttonBandH,
                          gapBeforeMetricsBand: gapBeforeMetricsBand,
                          metricsBandH: metricsBandH,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// 301 정사각형 내부 세로 스택(좌우 10은 부모 [Padding]에서만 적용).
  Widget _topWeightSummarySquareContent({
    required BuildContext context,
    required double chartDiameter,
    required double ringStroke,
    required double progressRatio,
    required double weight,
    required double heightCm,
    required double targetWeight,
    required double goalStartWeight,
    required double lostWeight,
    required double chartBandH,
    required double chartTopGap,
    required double chartToButtonGap,
    required double buttonBandH,
    required double gapBeforeMetricsBand,
    required double metricsBandH,
  }) {
    final goalRingActive = targetWeight > 0 && goalStartWeight > 0;
    final knobEnd = goalRingActive
        ? _weightGoalRingProgressEndOffset(
            boxSize: chartDiameter,
            strokeWidth: ringStroke,
            progress: progressRatio,
          )
        : Offset.zero;
    final knobSize = healthDp(context, 32);
    final knobCornerR = healthDp(context, 17.5);
    final knobDeltaText = !goalRingActive
        ? '-'
        : (weight <= 0
            ? '-'
            : (lostWeight == 0
                ? '0'
                : '${lostWeight > 0 ? '+' : '-'}${lostWeight.abs().toStringAsFixed(1)}'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: chartBandH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: chartTopGap),
                  Center(
                    child: SizedBox(
                      width: chartDiameter,
                      height: chartDiameter,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: Size(chartDiameter, chartDiameter),
                            painter: _WeightGoalRingPainter(
                              progress: progressRatio,
                              trackColor: const Color(0x7FD9D9D9),
                              progressColor: const Color(0xFFFF5A8D),
                              strokeWidth: ringStroke,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '오늘의 체중',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 20,
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                              Text(
                                weight > 0
                                    ? '${weight.toStringAsFixed(1)}kg'
                                    : '-',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 32,
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          // 오늘 체중 미입력 시 감량 몸무게(흰 원) 숨김
                          if (goalRingActive && weight > 0)
                            Positioned(
                              left: knobEnd.dx - knobSize / 2,
                              top: knobEnd.dy - knobSize / 2,
                              child: Container(
                                width: knobSize,
                                height: knobSize,
                                decoration: ShapeDecoration(
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(knobCornerR),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    knobDeltaText,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 10,
                                      fontFamily: 'Gmarket Sans TTF',
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: chartToButtonGap),
                ],
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: healthDp(context, 8)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '목표체중',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        Text(
                          targetWeight > 0
                              ? '${targetWeight.toStringAsFixed(1)}kg'
                              : '-',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        CustomPaint(
                          size: Size(
                            healthDp(context, 7),
                            healthDp(context, 7),
                          ),
                          painter: const _GoalTargetDownTrianglePainter(
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: buttonBandH,
          child: Align(
            alignment: Alignment.centerRight,
            child: HealthListEditButton(
              onTap: _openSelectedDateEditorPopup,
            ),
          ),
        ),
        SizedBox(height: gapBeforeMetricsBand),
        SizedBox(
          height: metricsBandH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: healthDp(context, 0.5),
                width: double.infinity,
                child: const ColoredBox(
                  color: Color(0x7FD2D2D2),
                ),
              ),
              SizedBox(height: healthDp(context, 10)),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildTopMetricCell(
                      title: '키',
                      value: heightCm > 0 ? '${heightCm.toInt()}' : '-',
                      unit: 'cm',
                    ),
                    _buildVerticalDivider(),
                    _buildTopMetricCell(
                      title: '목표 체중',
                      value: targetWeight > 0
                          ? '${targetWeight.toStringAsFixed(1)}'
                          : '-',
                      unit: 'kg',
                    ),
                    _buildVerticalDivider(),
                    _buildTopMetricCell(
                      title: '감량 몸무게',
                      value: lostWeight != 0
                          ? '${lostWeight > 0 ? '+' : '-'}${lostWeight.abs().toStringAsFixed(1)}'
                          : '0',
                      unit: 'kg',
                      valueColor: const Color(0xFFFF5A8D),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildTopMetricCell({
    required String title,
    required String value,
    required String unit,
    Color valueColor = Colors.black,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Text(
              title,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: const Color(0xFF1A1A1A),
                fontSize: healthSp(context, 10),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
              ),
            ),
            SizedBox(height: healthDp(context, 8)),
            RichText(
              textScaler: TextScaler.noScaling,
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: valueColor,
                      fontSize: healthSp(context, 20),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      color: const Color(0xFF9C9393),
                      fontSize: healthSp(context, 12),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: healthDp(context, 0.5),
      height: healthDp(context, 46),
      color: const Color(0x7FD2D2D2),
    );
  }

  Widget _buildBmiSummaryCard() {
    final bmi = selectedRecord?.bmi ?? 0.0;
    final bmiStatus = selectedRecord?.bmiStatus ?? '';
    final Color statusAccent =
        bmi > 0 ? _getBmiStatusColor(bmi) : const Color(0xFF9C9393);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 10)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x19000000),
            blurRadius: healthDp(context, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'BMI',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: const Color(0xFF1A1A1A),
                  fontSize: healthSp(context, 16),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (bmiStatus.isNotEmpty)
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 28)),
                        border: Border.all(color: statusAccent),
                      ),
                      child: Text(
                        bmiStatus,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          color: statusAccent,
                          fontSize: healthSp(context, 12),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
              Text(
                bmi > 0 ? bmi.toStringAsFixed(2) : '-',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: const Color(0xFF1A1A1A),
                  fontSize: healthSp(context, 16),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (bmi > 0) ...[
            SizedBox(height: healthDp(context, 10)),
            _buildBmiColorBar(),
          ],
        ],
      ),
    );
  }

  // 1. 오늘의 체중
  Widget _buildWeightDisplay() {
    final weight = selectedRecord?.weight ?? 0.0;
    final dateStr = DateFormat('yyyy년 M월 d일').format(selectedDate);

    return GestureDetector(
      onTap: _openSelectedDateEditorPopup,
      child: Center(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                if (selectedRecord != null) // 기록이 있으면 편집 아이콘 표시
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.edit,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: weight > 0 ? weight.toStringAsFixed(1) : '-',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  TextSpan(
                    text: weight > 0 ? ' kg' : '',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (selectedRecord != null) // 기록이 있으면 힌트 표시
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '탭하여 수정',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 2. 키 / BMI
  Widget _buildHeightBmiRow() {
    final height = selectedRecord?.height ?? 0.0;
    final bmi = selectedRecord?.bmi ?? 0.0;
    final bmiStatus = selectedRecord?.bmiStatus ?? '';

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Text(
                '키(cm)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                height > 0 ? '${height.toInt()} cm' : '-',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 1,
          height: 40,
          color: Colors.grey[300],
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                'BMI(신체질량지수)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: bmi > 0 ? bmi.toStringAsFixed(1) : '-',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    if (bmiStatus.isNotEmpty)
                      TextSpan(
                        text: ' $bmiStatus',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getBmiStatusColor(bmi),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // BMI 상태 색상 (상태 배지·구간 라벨 등 글자 강조 통일)
  Color _getBmiStatusColor(double _) {
    return const Color(0xFFFF5A8D);
  }

  // 3. BMI 컬러 바
  Widget _buildBmiColorBar() {
    final bmi = selectedRecord?.bmi ?? 0.0;

    if (bmi <= 0) {
      return const SizedBox.shrink();
    }

    // BMI 위치 계산 (15 ~ 35 범위로 정규화)
    double minBmi = 15.0;
    double maxBmi = 35.0;
    double position = ((bmi - minBmi) / (maxBmi - minBmi)).clamp(0.0, 1.0);

    return Column(
      children: [
        LayoutBuilder(
          builder: (ctx, constraints) {
            // 바의 실제 너비 사용
            final barWidth = constraints.maxWidth;
            final hBar = healthDp(ctx, 8);
            final rBar = healthDp(ctx, 4);
            final indTop = -healthDp(ctx, 8);
            final indW = healthDp(ctx, 2);
            final indH = healthDp(ctx, 28);
            final dot = healthDp(ctx, 8);

            return Stack(
              children: [
                // 그라데이션 바
                Container(
                  height: hBar,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(rBar),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF4FC3F7), // 하늘색 (저체중)
                        Color(0xFF4CAF50), // 초록색 (정상)
                        Color(0xFFFF9800), // 주황색 (과체중)
                        Color(0xFFE91E63), // 분홍색 (비만)
                        Color(0xFFF44336), // 빨간색 (과체중·고BMI 구간)
                      ],
                    ),
                  ),
                ),
                // 인디케이터
                Positioned(
                  left: (barWidth * position - healthDp(ctx, 10))
                      .clamp(0.0, barWidth - healthDp(ctx, 20)),
                  top: indTop,
                  child: Column(
                    children: [
                      Container(
                        width: indW,
                        height: indH,
                        color: Colors.white,
                      ),
                      Container(
                        width: dot,
                        height: dot,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        SizedBox(height: healthDp(context, 4)),
        // BMI 범위 텍스트
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '저체중',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: healthSp(context, 8),
                color: const Color(0xFF94A3B8),
                fontFamily: 'Gmarket Sans TTF',
              ),
            ),
            Text(
              '정상',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: healthSp(context, 8),
                color: const Color(0xFF94A3B8),
                fontFamily: 'Gmarket Sans TTF',
              ),
            ),
            Text(
              '과체중',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: healthSp(context, 8),
                color: const Color(0xFF94A3B8),
                fontFamily: 'Gmarket Sans TTF',
              ),
            ),
            Text(
              '비만',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: healthSp(context, 8),
                color: const Color(0xFF94A3B8),
                fontFamily: 'Gmarket Sans TTF',
              ),
            ),
            Text(
              '과체중',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: healthSp(context, 8),
                color: const Color(0xFF94A3B8),
                fontFamily: 'Gmarket Sans TTF',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 4. 기간 선택 버튼
  Widget _buildPeriodButtons({bool plainStyle = false}) {
    return HealthPeriodSelector(
      selectedPeriod: selectedPeriod,
      plainStyle: plainStyle,
      onChanged: (period) {
        setState(() {
          selectedPeriod = period;
          selectedChartPointIndex = null;
          tooltipPosition = null;

          if (period == '월') {
            timeOffset = 0.0;
          } else if (period == '주') {
            timeOffset = 0.0;
          } else if (period == '일') {
            timeOffset = _dailyOffsetForDate(selectedDate);
          }
        });
        _notifyExpandedChart();

        if (period == '주' || period == '월') {
          _loadData();
        }
      },
    );
  }

  // 5. 차트
  Widget _buildChartContent({
    bool showExpandButton = true,
    double? chartHeight,
    bool expandedChartView = false,
  }) {
    final resolvedChartHeight =
        chartHeight ?? healthDp(context, ChartConstants.weightChartHeight);
    final chartData = getChartData();
    final yLabels =
        expandedChartView ? getYAxisLabelsExpanded() : getYAxisLabelsMain();
    final periodTabs = expandedChartView
        ? const SizedBox.shrink()
        : _buildPeriodButtons(plainStyle: true);
    return WeightChartContent(
      selectedPeriod: selectedPeriod,
      chartData: chartData,
      yLabels: yLabels,
      hasActualDailyData: _hasWeightRecordsOnSelectedDate(),
      chartHeight: resolvedChartHeight,
      showExpandButton: showExpandButton,
      onExpand: _openExpandedChartPage,
      periodSelector: periodTabs,
      dataChartBuilder: (height, tabs) => WeightDataChart(
        selectedPeriod: selectedPeriod,
        chartData: chartData,
        yLabels: yLabels,
        selectedChartPointIndex: selectedChartPointIndex,
        tooltipPosition: tooltipPosition,
        chartHeight: height,
        timeOffset: timeOffset,
        selectedDate: selectedDate,
        periodSelector: tabs,
        forExpandedChart: expandedChartView,
        showYAxisKgHeader: true,
        // 월별은 Y축 범위로 클램프하여 표시(실제값은 툴팁에 유지)
        omitOutOfRangeWeights:
            selectedPeriod == '일' ? !expandedChartView : selectedPeriod == '월',
        onTimeOffsetChanged: (newOffset) {
          setState(() {
            timeOffset = newOffset;
          });
          _notifyExpandedChart();
        },
        onTooltipChanged: (index, position) {
          setState(() {
            selectedChartPointIndex = index;
            tooltipPosition = position;
          });
          _notifyExpandedChart();
        },
        chartAreaBuilder: (a, b, c, d) => _buildChartArea(a, b, c, d),
        tooltipBuilder: _buildChartTooltip,
      ),
      emptyChartBuilder: (height, tabs) => WeightEmptyChart(
        chartHeight: height,
        selectedPeriod: selectedPeriod,
        selectedDate: selectedDate,
        timeOffset: timeOffset,
        yLabels: yLabels,
        periodSelector: tabs,
        showYAxisKgHeader: true,
      ),
    );
  }

  Future<void> _openExpandedChartPage() async {
    await openHealthChartExpandPage(
      context: context,
      periodSelectorBuilder: (ctx) => HealthExpandedPeriodSelector(
        metrics: healthExpandedMetrics(ctx),
        selectedPeriod: selectedPeriod,
        onChanged: (period) {
          setState(() {
            selectedPeriod = period;
            selectedChartPointIndex = null;
            tooltipPosition = null;
            if (period == '월') {
              timeOffset = 0.0;
            } else if (period == '주') {
              timeOffset = 0.0;
            } else if (period == '일') {
              timeOffset = _dailyOffsetForDate(selectedDate);
            }
          });
          _notifyExpandedChart();
        },
      ),
      chartBuilder: (ctx) {
        final base = Theme.of(ctx);
        final gmarket = base.copyWith(
          textTheme: base.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
          primaryTextTheme:
              base.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            final scaledChartCap = healthExpandedMetrics(context)
                .d(HealthExpandedChartMetrics.chartHeightWithoutLegend);
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
                child: _buildChartContent(
                  showExpandButton: false,
                  chartHeight: safeHeight,
                  expandedChartView: true,
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

  // 차트 영역 빌드
  Widget _buildChartArea(
    List<Map<String, dynamic>> chartData,
    List<double> yLabels,
    BoxConstraints constraints,
    bool omitOutOfRangeWeights,
  ) {
    return GestureDetector(
      onTapDown: (details) {
        _handleChartTap(
          details.localPosition,
          chartData,
          yLabels.last,
          yLabels.first,
          constraints.maxWidth,
          constraints.maxHeight,
          omitOutOfRangeWeights: omitOutOfRangeWeights,
        );
      },
      onPanDown: (details) {
        // 길게 누르지 않아도 바로 툴팁 표시
        _handleChartHover(
          details.localPosition,
          chartData,
          yLabels.last,
          yLabels.first,
          constraints.maxWidth,
          constraints.maxHeight,
          omitOutOfRangeWeights: omitOutOfRangeWeights,
        );
      },
      // 드래그: 일별(6시간 창)·월별
      onPanStart: (details) {
        if (selectedPeriod == '일' || selectedPeriod == '월') {
          _dragStartX = details.localPosition.dx;
        }
      },
      onPanUpdate: (details) {
        if (selectedPeriod == '일' || selectedPeriod == '월') {
          final deltaX = details.localPosition.dx - (_dragStartX ?? 0);
          _handleDragUpdate(deltaX, constraints.maxWidth);
          _dragStartX = details.localPosition.dx;
        }
      },
      onPanEnd: (details) {
        _dragStartX = null;
      },
      child: Stack(
        children: [
          // 차트 (전체 크기를 차지하도록)
          Positioned.fill(
            child: CustomPaint(
              painter: WeightChartPainter(
                chartData: chartData,
                yLabels: yLabels,
                timeOffset: timeOffset,
                selectedPeriod: selectedPeriod,
                selectedPointIndex: selectedChartPointIndex,
                omitOutOfRangeWeights: omitOutOfRangeWeights,
                topPadding: healthWeightChartVertPad(context),
                bottomPadding: healthWeightChartBottomPlotPad(context),
                barWidth: HealthChartMetrics(
                  healthTextScaleByWidth(MediaQuery.sizeOf(context).width),
                ).barWidth,
                scale: healthTextScaleByWidth(
                  MediaQuery.sizeOf(context).width,
                ),
              ),
              size: Size(
                constraints.maxWidth,
                constraints.maxHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 6. 눈바디 이미지
  Widget _buildBodyImages() {
    final frontImagePath = selectedRecord?.frontImagePath;
    final sideImagePath = selectedRecord?.sideImagePath;
    final gap = healthDp(context, 10);
    final maxSide = healthDp(context, 158);

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(
          maxSide,
          (constraints.maxWidth - gap) / 2,
        );
        return Row(
          children: [
            SizedBox(
              width: side,
              height: side,
              child: _buildImageContainer(
                '정면사진',
                frontImagePath,
                () => _selectImage('front'),
              ),
            ),
            SizedBox(width: gap),
            SizedBox(
              width: side,
              height: side,
              child: _buildImageContainer(
                '측면사진',
                sideImagePath,
                () => _selectImage('side'),
              ),
            ),
          ],
        );
      },
    );
  }

  // 이미지 컨테이너 위젯
  Widget _buildImageContainer(
      String label, String? imagePath, VoidCallback onTap) {
    final hasImage = imagePath != null &&
        imagePath.isNotEmpty &&
        ImagePickerUtils.isImageFileExists(imagePath);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: hasImage ? Colors.grey[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(healthDp(context, 12)),
          border: Border.all(
            color: hasImage ? Colors.grey[300]! : Colors.grey[200]!,
            width: healthDp(context, 1),
          ),
        ),
        child: hasImage
            ? Stack(
                children: [
                  // 이미지 표시
                  ClipRRect(
                    borderRadius: BorderRadius.circular(healthDp(context, 12)),
                    child: kIsWeb
                        ? Image.network(
                            imagePath,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildImagePlaceholder(label);
                            },
                          )
                        : Image.file(
                            File(imagePath),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildImagePlaceholder(label);
                            },
                          ),
                  ),
                  // 삭제 버튼
                  Positioned(
                    top: healthDp(context, 4),
                    right: healthDp(context, 4),
                    child: GestureDetector(
                      onTap: () => _deleteImage(imagePath),
                      child: Container(
                        padding: EdgeInsets.all(healthDp(context, 4)),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: healthDp(context, 16),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : _buildImagePlaceholder(label),
      ),
    );
  }

  // 이미지 플레이스홀더
  Widget _buildImagePlaceholder(String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: healthDp(context, 40),
          color: Colors.grey[400],
        ),
        SizedBox(height: healthDp(context, 8)),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 이미지 선택 및 업로드
  Future<void> _selectImage(String type) async {
    try {
      await ImagePickerUtils.showImageSourceDialog(context,
          (XFile? image) async {
        if (image != null) {
          String? imageUrl;

          if (kIsWeb) {
            // 웹에서는 XFile을 직접 전달
            try {
              imageUrl = await WeightRepository.uploadImage(image);
            } catch (e) {
              print('웹 이미지 업로드 실패: $e');
              // 업로드 실패 시 blob URL 사용 (임시)
              imageUrl = image.path;
            }
          } else {
            // 모바일에서는 실제 파일 업로드
            final File imageFile = File(image.path);
            imageUrl = await WeightRepository.uploadImage(imageFile);
          }

          if (imageUrl != null) {
            // 기존 이미지가 있으면 삭제 (선택사항)
            if (type == 'front' && selectedRecord?.frontImagePath != null) {
              // TODO: 기존 이미지 파일 삭제
            } else if (type == 'side' &&
                selectedRecord?.sideImagePath != null) {
              // TODO: 기존 이미지 파일 삭제
            }

            // 데이터베이스 업데이트
            if (selectedRecord != null) {
              final updatedRecord = selectedRecord!.copyWith(
                frontImagePath:
                    type == 'front' ? imageUrl : selectedRecord!.frontImagePath,
                sideImagePath:
                    type == 'side' ? imageUrl : selectedRecord!.sideImagePath,
              );

              await WeightRepository.updateWeightRecord(updatedRecord);
              _loadData(); // 데이터 새로고침
            } else {
              // 새 기록 생성 (체중 입력 화면으로 이동)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WeightInputScreen(
                    recordContextDate: selectedDate,
                    initialImages: {
                      'front': type == 'front' ? imageUrl : null,
                      'side': type == 'side' ? imageUrl : null,
                    },
                  ),
                ),
              );
            }
          }
        }
      });
    } catch (e) {
      print('이미지 선택 오류: $e');
    }
  }

  // 이미지 삭제
  Future<void> _deleteImage(String imagePath) async {
    try {
      // 확인 다이얼로그
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('이미지 삭제'),
          content: const Text('이미지를 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('삭제'),
            ),
          ],
        ),
      );

      if (confirmed == true && selectedRecord != null) {
        // 파일 시스템에서 이미지 삭제
        await ImagePickerUtils.deleteImageFile(imagePath);

        // 데이터베이스에서 이미지 경로 제거
        final updatedRecord = selectedRecord!.copyWith(
          frontImagePath: imagePath == selectedRecord!.frontImagePath
              ? null
              : selectedRecord!.frontImagePath,
          sideImagePath: imagePath == selectedRecord!.sideImagePath
              ? null
              : selectedRecord!.sideImagePath,
        );

        await WeightRepository.updateWeightRecord(updatedRecord);
        _loadData(); // 데이터 새로고침
      }
    } catch (e) {
      print('이미지 삭제 오류: $e');
    }
  }

  // 차트 클릭 핸들러 (차트의 점 클릭 감지)
  void _handleChartTap(
    Offset tapPosition,
    List<Map<String, dynamic>> chartData,
    double minWeight,
    double maxWeight,
    double chartWidth,
    double chartHeight, {
    bool omitOutOfRangeWeights = false,
  }) {
    if (chartData.isEmpty) return;

    final topPadChart = healthWeightChartVertPad(context);
    final botPadChart = healthWeightChartBottomPlotPad(context);
    final drawableTop = topPadChart;
    final drawableBottom = chartHeight - botPadChart;
    final hitPadV = healthDp(context, 12);
    final barHitHalfW = healthDp(context, 16);

    // 가장 가까운 점 찾기
    int? closestIndex;
    double minDistance = double.infinity;
    Offset? closestPoint;

    for (int i = 0; i < chartData.length; i++) {
      final data = chartData[i];

      if (selectedPeriod == '일' && data['hourSlotBar'] == true) {
        final minW = (data['minWeight'] as num).toDouble();
        final maxW = (data['maxWeight'] as num).toDouble();
        if (omitOutOfRangeWeights && (maxW < minWeight || minW > maxWeight)) {
          continue;
        }
        final weightRange = maxWeight - minWeight;
        if (weightRange.abs() < 1e-9) continue;

        final xPosition = (data['xPosition'] as double?) ?? 0.5;
        const leftPad = ChartConstants.weightDailyChartInnerPadH;
        const rightPad = ChartConstants.weightDailyChartInnerPadH +
            ChartConstants.weightXAxisUnitReservedWidth;
        final xCenter = leftPad + (chartWidth - leftPad - rightPad) * xPosition;
        final drawableHeight = chartHeight - topPadChart - botPadChart;
        final yHi =
            topPadChart + drawableHeight * ((maxWeight - maxW) / weightRange);
        final yLo =
            topPadChart + drawableHeight * ((maxWeight - minW) / weightRange);
        var yTop = math.min(yHi, yLo);
        var yBottom = math.max(yHi, yLo);
        yTop = yTop.clamp(drawableTop, drawableBottom);
        yBottom = yBottom.clamp(drawableTop, drawableBottom);
        if (yBottom < yTop) {
          final t = yTop;
          yTop = yBottom;
          yBottom = t;
        }
        final cy = (yTop + yBottom) / 2;
        if (tapPosition.dx >= xCenter - barHitHalfW &&
            tapPosition.dx <= xCenter + barHitHalfW &&
            tapPosition.dy >= yTop - hitPadV &&
            tapPosition.dy <= yBottom + hitPadV) {
          final dx = tapPosition.dx - xCenter;
          final dy = tapPosition.dy - cy;
          final distance = dx * dx + dy * dy;
          if (distance < minDistance) {
            minDistance = distance;
            closestIndex = i;
            closestPoint = Offset(xCenter, cy);
          }
        }
        continue;
      }

      final weight = data['weight'];

      if (weight == null) continue; // null 값 스킵

      if (omitOutOfRangeWeights) {
        final w = (weight as num).toDouble();
        if (w < minWeight || w > maxWeight) continue;
      }

      double x;
      if (data['xPosition'] != null) {
        final xPosition = data['xPosition'] as double;
        final leftPad = ChartConstants.weightDailyChartInnerPadH;
        final rightPad = ChartConstants.weightDailyChartInnerPadH +
            ChartConstants.weightXAxisUnitReservedWidth;
        x = leftPad + (chartWidth - leftPad - rightPad) * xPosition;
      } else if (selectedPeriod == '일') {
        final leftPad = ChartConstants.weightDailyChartInnerPadH;
        final rightPad = ChartConstants.weightDailyChartInnerPadH +
            ChartConstants.weightXAxisUnitReservedWidth;
        final effectiveWidth = chartWidth - leftPad - rightPad;
        x = chartData.length == 1
            ? leftPad + effectiveWidth / 2
            : leftPad + effectiveWidth * i / (chartData.length - 1);
      } else {
        final xPosition = data['xPosition'] as double;
        const visibleDays = 7;
        const totalDays = 30;
        final leftPad = ChartConstants.weightDailyChartInnerPadH;
        final rightPad = ChartConstants.weightDailyChartInnerPadH +
            ChartConstants.weightXAxisUnitReservedWidth;
        if (selectedPeriod == '월') {
          final maxOffset = (totalDays - visibleDays) / totalDays;
          final currentOffset = timeOffset.clamp(0.0, maxOffset);
          final startIndex = (currentOffset * totalDays).floor();
          final endIndex = startIndex + visibleDays;
          final dataIndex = (xPosition * totalDays).round();
          if (dataIndex < startIndex || dataIndex >= endIndex) continue;
          final relativeIndex = dataIndex - startIndex;
          final adjustedRatio = relativeIndex / (visibleDays - 1);
          x = leftPad + (chartWidth - leftPad - rightPad) * adjustedRatio;
        } else {
          x = leftPad + (chartWidth - leftPad - rightPad) * xPosition;
        }
      }

      // Y 좌표 계산 (페인터와 동일한 상하 패딩 적용)
      final drawableHeight = chartHeight - topPadChart - botPadChart;
      final wr = maxWeight - minWeight;
      if (wr.abs() < 1e-9) continue;
      final normalizedWeight = (maxWeight - weight) / wr;
      final y = topPadChart + drawableHeight * normalizedWeight;

      // 클릭 위치와 점 사이의 거리 계산
      final dx = tapPosition.dx - x;
      final dy = tapPosition.dy - y;
      final distance = dx * dx + dy * dy; // 제곱 거리

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
        closestPoint = Offset(x, y);
      }
    }

    // 탭 허용 범위를 넓혀 더 빠르고 정확하게 선택
    if (closestIndex != null && minDistance < 1600) {
      setState(() {
        selectedChartPointIndex = closestIndex;
        tooltipPosition = closestPoint;
      });
      _notifyExpandedChart();
    } else {
      // 가까운 점이 없으면 툴팁 숨기기
      setState(() {
        selectedChartPointIndex = null;
        tooltipPosition = null;
      });
      _notifyExpandedChart();
    }
  }

  // 차트 호버/드래그 핸들러 (툴팁 표시용)
  void _handleChartHover(
    Offset hoverPosition,
    List<Map<String, dynamic>> chartData,
    double minWeight,
    double maxWeight,
    double chartWidth,
    double chartHeight, {
    bool omitOutOfRangeWeights = false,
  }) {
    if (chartData.isEmpty) return;

    final topPadChart = healthWeightChartVertPad(context);
    final botPadChart = healthWeightChartBottomPlotPad(context);
    final drawableTop = topPadChart;
    final drawableBottom = chartHeight - botPadChart;
    final hitPadV = healthDp(context, 12);
    final barHitHalfW = healthDp(context, 16);

    // 가장 가까운 점 찾기
    int? closestIndex;
    double minDistance = double.infinity;
    Offset? closestPoint;

    for (int i = 0; i < chartData.length; i++) {
      final data = chartData[i];

      if (selectedPeriod == '일' && data['hourSlotBar'] == true) {
        final minW = (data['minWeight'] as num).toDouble();
        final maxW = (data['maxWeight'] as num).toDouble();
        if (omitOutOfRangeWeights && (maxW < minWeight || minW > maxWeight)) {
          continue;
        }
        final weightRange = maxWeight - minWeight;
        if (weightRange.abs() < 1e-9) continue;

        final xPosition = (data['xPosition'] as double?) ?? 0.5;
        const leftPad = ChartConstants.weightDailyChartInnerPadH;
        const rightPad = ChartConstants.weightDailyChartInnerPadH +
            ChartConstants.weightXAxisUnitReservedWidth;
        final xCenter = leftPad + (chartWidth - leftPad - rightPad) * xPosition;
        final drawableHeight = chartHeight - topPadChart - botPadChart;
        final yHi =
            topPadChart + drawableHeight * ((maxWeight - maxW) / weightRange);
        final yLo =
            topPadChart + drawableHeight * ((maxWeight - minW) / weightRange);
        var yTop = math.min(yHi, yLo);
        var yBottom = math.max(yHi, yLo);
        yTop = yTop.clamp(drawableTop, drawableBottom);
        yBottom = yBottom.clamp(drawableTop, drawableBottom);
        if (yBottom < yTop) {
          final t = yTop;
          yTop = yBottom;
          yBottom = t;
        }
        final cy = (yTop + yBottom) / 2;
        if (hoverPosition.dx >= xCenter - barHitHalfW &&
            hoverPosition.dx <= xCenter + barHitHalfW &&
            hoverPosition.dy >= yTop - hitPadV &&
            hoverPosition.dy <= yBottom + hitPadV) {
          final dx = hoverPosition.dx - xCenter;
          final dy = hoverPosition.dy - cy;
          final distance = dx * dx + dy * dy;
          if (distance < minDistance) {
            minDistance = distance;
            closestIndex = i;
            closestPoint = Offset(xCenter, cy);
          }
        }
        continue;
      }

      final weight = data['weight'];

      if (weight == null) continue; // null 값 스킵

      if (omitOutOfRangeWeights) {
        final w = (weight as num).toDouble();
        if (w < minWeight || w > maxWeight) continue;
      }

      double x;
      if (data['xPosition'] != null) {
        final xPosition = data['xPosition'] as double;
        final leftPad = ChartConstants.weightDailyChartInnerPadH;
        final rightPad = ChartConstants.weightDailyChartInnerPadH +
            ChartConstants.weightXAxisUnitReservedWidth;
        x = leftPad + (chartWidth - leftPad - rightPad) * xPosition;
      } else if (selectedPeriod == '일') {
        final leftPad = ChartConstants.weightDailyChartInnerPadH;
        final rightPad = ChartConstants.weightDailyChartInnerPadH +
            ChartConstants.weightXAxisUnitReservedWidth;
        final effectiveWidth = chartWidth - leftPad - rightPad;
        x = chartData.length == 1
            ? leftPad + effectiveWidth / 2
            : leftPad + effectiveWidth * i / (chartData.length - 1);
      } else {
        final xPosition = data['xPosition'] as double;
        const visibleDays = 7;
        const totalDays = 30;
        final leftPad = ChartConstants.weightDailyChartInnerPadH;
        final rightPad = ChartConstants.weightDailyChartInnerPadH +
            ChartConstants.weightXAxisUnitReservedWidth;
        if (selectedPeriod == '월') {
          final maxOffset = (totalDays - visibleDays) / totalDays;
          final currentOffset = timeOffset.clamp(0.0, maxOffset);
          final startIndex = (currentOffset * totalDays).floor();
          final endIndex = startIndex + visibleDays;
          final dataIndex = (xPosition * totalDays).round();
          if (dataIndex < startIndex || dataIndex >= endIndex) continue;
          final relativeIndex = dataIndex - startIndex;
          final adjustedRatio = relativeIndex / (visibleDays - 1);
          x = leftPad + (chartWidth - leftPad - rightPad) * adjustedRatio;
        } else {
          x = leftPad + (chartWidth - leftPad - rightPad) * xPosition;
        }
      }

      // Y 좌표 계산 (페인터와 동일한 상하 패딩 적용)
      final drawableHeight = chartHeight - topPadChart - botPadChart;
      final wr = maxWeight - minWeight;
      if (wr.abs() < 1e-9) continue;
      final normalizedWeight = (maxWeight - weight) / wr;
      final y = topPadChart + drawableHeight * normalizedWeight;

      // 거리 계산
      final dx = hoverPosition.dx - x;
      final dy = hoverPosition.dy - y;
      final distance = dx * dx + dy * dy;

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
        closestPoint = Offset(x, y);
      }
    }

    // hover/드래그 중에도 즉시 따라오도록 허용 반경 확장
    if (closestIndex != null && minDistance < 4900) {
      setState(() {
        selectedChartPointIndex = closestIndex;
        tooltipPosition = closestPoint;
      });
      _notifyExpandedChart();
    } else {
      setState(() {
        selectedChartPointIndex = null;
        tooltipPosition = null;
      });
      _notifyExpandedChart();
    }
  }

  // 차트 툴팁 위젯
  Widget _buildChartTooltip(
      Map<String, dynamic> data, double chartWidth, double chartHeight) {
    if (tooltipPosition == null) return const SizedBox.shrink();

    late final String timeLabel;
    late final String weightLine;

    if (data['hourSlotBar'] == true) {
      final minW = (data['minWeight'] as num).toDouble();
      final maxW = (data['maxWeight'] as num).toDouble();
      final hour = data['hour'] as int;
      timeLabel = '$hour시';
      weightLine = minW == maxW
          ? '${minW.toStringAsFixed(1)} kg'
          : '${minW.toStringAsFixed(1)} ~ ${maxW.toStringAsFixed(1)} kg';
    } else {
      final weight = data['weight'];
      final record = data['record'];
      if (weight == null || record == null) return const SizedBox.shrink();

      final weightValue = weight as double;
      final weightRecord = record as WeightRecord;

      String formatKoreanTime(DateTime dt) {
        return '${dt.hour}시';
      }

      timeLabel = selectedPeriod == '일'
          ? formatKoreanTime(weightRecord.measuredAt)
          : DateFormat('M/d HH:mm').format(weightRecord.measuredAt);
      weightLine = '${weightValue.toStringAsFixed(1)} kg';
    }

    // 부모 Positioned(점 위치 기준) 내에서 상대 이동으로 배치
    double tooltipX = tooltipPosition!.dx;
    double tooltipY = tooltipPosition!.dy - 60;
    const tooltipWidth = 110.0;
    const tooltipHeight = 56.0;

    if (tooltipX < 0) tooltipX = 0;
    if (tooltipX > chartWidth - tooltipWidth)
      tooltipX = chartWidth - tooltipWidth;
    if (tooltipY < 0) tooltipY = tooltipPosition!.dy + 20;
    if (tooltipY > chartHeight - tooltipHeight)
      tooltipY = chartHeight - tooltipHeight;

    final timeStyle = TextStyle(
      color: Colors.grey[700],
      fontSize: 12,
      fontWeight: FontWeight.w400,
    );
    final weightStyle = const TextStyle(
      color: Colors.black87,
      fontSize: 14,
      fontWeight: FontWeight.w700,
    );

    return Transform.translate(
      offset: Offset(
        tooltipX - tooltipPosition!.dx,
        tooltipY - tooltipPosition!.dy,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: selectedPeriod == '일'
              ? [
                  Text(timeLabel,
                      style: timeStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(
                    weightLine,
                    style: weightStyle,
                    textAlign: TextAlign.center,
                  ),
                ]
              : [
                  Text(
                    weightLine,
                    style: weightStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(timeLabel,
                      style: timeStyle, textAlign: TextAlign.center),
                ],
        ),
      ),
    );
  }

  // 시간별 기록 선택 바텀시트
  Future<void> _showTimeSelectionBottomSheet(List<WeightRecord> records) async {
    final selectedRecord = await showHealthEditBottomSheet<WeightRecord>(
      context: context,
      items: records
          .map(
            (record) => HealthEditBottomSheetItem<WeightRecord>(
              data: record,
              timeText: DateFormat('HH:mm').format(record.measuredAt),
              buildTrailing: (ctx) => Text.rich(
                textScaler: TextScaler.noScaling,
                TextSpan(
                  children: [
                    TextSpan(
                      text: record.weight.toStringAsFixed(1),
                      style: TextStyle(
                        color: const Color(0xFFFF5A8D),
                        fontSize: healthSp(ctx, 18),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: ' kg',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: healthSp(ctx, 18),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );

    if (selectedRecord == null || !mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeightInputScreen(record: selectedRecord),
      ),
    );

    if (result == true && mounted) {
      _loadData();
    }
  }

  Future<void> _openSelectedDateEditorPopup() async {
    if (selectedRecord == null) return;

    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final todayRecords = allRecords.where((record) {
      final recordDateStr = DateFormat('yyyy-MM-dd').format(record.measuredAt);
      return recordDateStr == selectedDateStr;
    }).toList();

    todayRecords.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    if (todayRecords.isEmpty) return;

    // 공통 수정 팝업(health_edit_bottom_sheet) 사용
    await _showTimeSelectionBottomSheet(todayRecords);
  }
}

/// 체중 확대 화면 레이아웃 정렬용 임시 범례 (심박 확대와 동일 스타일)
class _WeightExpandTempLegend extends StatelessWidget {
  final Color color;
  final String label;
  final bool compact;

  const _WeightExpandTempLegend({
    required this.color,
    required this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final dot = compact ? 8.0 : 12.0;
    final gap = compact ? 3.0 : 5.0;
    final fontSize = compact ? 9.0 : 12.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dot,
          height: dot,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: gap),
        Text(
          label,
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// 목표체중 라벨 아래, 차트 쪽을 가리키는 아래방향 삼각형(채움).
class _GoalTargetDownTrianglePainter extends CustomPainter {
  const _GoalTargetDownTrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _GoalTargetDownTrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 목표 체중 원형: 전체 원 = 시작(목표설정 시 체중)~목표 체중 구간, 12시에서 반시계로 채움.
class _WeightGoalRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _WeightGoalRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, track);

    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;

    final sweep = -math.pi * 2 * p;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _WeightGoalRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

// 체중 차트 Painter
class WeightChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> chartData;
  final List<double> yLabels;
  final double timeOffset;
  final String selectedPeriod;
  final int? selectedPointIndex;
  final bool omitOutOfRangeWeights;
  final double topPadding;
  final double bottomPadding;
  final double barWidth;
  final double scale;

  WeightChartPainter({
    required this.chartData,
    required this.yLabels,
    required this.timeOffset,
    required this.selectedPeriod,
    this.selectedPointIndex,
    this.omitOutOfRangeWeights = false,
    this.topPadding = 20,
    this.bottomPadding = 10,
    this.barWidth = 5,
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (chartData.isEmpty || yLabels.length < 2) return;

    final minWeight = yLabels.last; // 최소값 (하단)
    final maxWeight = yLabels.first; // 최대값 (상단)
    final weightRange = maxWeight - minWeight;
    if (weightRange == 0) return;

    final m = HealthChartMetrics(scale);
    const double leftPadding = ChartConstants.weightDailyChartInnerPadH;
    const double rightPadding = ChartConstants.weightDailyChartInnerPadH +
        ChartConstants.weightXAxisUnitReservedWidth;

    // 데이터: 같은 시(hour)에 2건 이상이면 막대, 그 외는 점
    List<Offset> points = [];
    List<int> validIndices = [];
    const maxStartHour = 18;
    final startHour =
        (timeOffset * maxStartHour).clamp(0, maxStartHour).round();
    final endHour = startHour + 6;

    final barFill = Paint()
      ..color = const Color(0xFFFF5A8D)
      ..style = PaintingStyle.fill;

    final drawableTop = topPadding;
    final drawableBottom = size.height - bottomPadding;

    for (int i = 0; i < chartData.length; i++) {
      final data = chartData[i];

      if (selectedPeriod == '일' && data['hourSlotBar'] == true) {
        final minW = (data['minWeight'] as num).toDouble();
        final maxW = (data['maxWeight'] as num).toDouble();
        final recordHour = data['hour'] as int;
        if (omitOutOfRangeWeights && (maxW < minWeight || minW > maxWeight)) {
          continue;
        }
        if (recordHour < startHour || recordHour > endHour) {
          continue;
        }
        final xPosition = (data['xPosition'] as double?) ?? 0.5;
        final xCenter =
            leftPadding + (size.width - leftPadding - rightPadding) * xPosition;
        final yHi = topPadding +
            (size.height - topPadding - bottomPadding) *
                ((maxWeight - maxW) / weightRange);
        final yLo = topPadding +
            (size.height - topPadding - bottomPadding) *
                ((maxWeight - minW) / weightRange);
        var yTop = math.min(yHi, yLo);
        var yBottom = math.max(yHi, yLo);
        yTop = yTop.clamp(drawableTop, drawableBottom);
        yBottom = yBottom.clamp(drawableTop, drawableBottom);
        if (yBottom < yTop) {
          final t = yTop;
          yTop = yBottom;
          yBottom = t;
        }
        final midY = (yTop + yBottom) / 2;
        final barH = math.max(yBottom - yTop, m.minBarHeight);
        final isSel = selectedPointIndex != null && selectedPointIndex == i;
        final wBar = isSel
            ? barWidth + m.barWidthSelectedExtra
            : barWidth;
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(xCenter, midY),
            width: wBar,
            height: barH,
          ),
          Radius.circular(wBar / 2),
        );
        canvas.drawRRect(rect, barFill);
        if (isSel) {
          canvas.drawRRect(
            rect,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = m.highlightRingStroke,
          );
        }
        continue;
      }

      final weight = data['weight'];

      if (weight == null) continue; // null 값 스킵

      final w = (weight as num).toDouble();
      if (omitOutOfRangeWeights && (w < minWeight || w > maxWeight)) {
        continue;
      }

      if (selectedPeriod == '일') {
        final recordHour = data['hour'] as int?;
        if (recordHour != null &&
            (recordHour < startHour || recordHour > endHour)) {
          continue;
        }
      }

      double x;
      if (selectedPeriod == '일') {
        final xPosition = (data['xPosition'] as double?) ?? 0.5;
        x = leftPadding + (size.width - leftPadding - rightPadding) * xPosition;
      } else {
        if (data['xPosition'] == null) continue;
        final xPosition = data['xPosition'] as double;
        const visibleDays = 7;
        const totalDays = 30;
        if (selectedPeriod == '월') {
          final maxOffset = (totalDays - visibleDays) / totalDays;
          final currentOffset = timeOffset.clamp(0.0, maxOffset);
          final startIndex = (currentOffset * totalDays).floor();
          final endIndex = startIndex + visibleDays;
          final dataIndex = (xPosition * totalDays).round();
          if (dataIndex < startIndex || dataIndex >= endIndex) continue;
          final relativeIndex = dataIndex - startIndex;
          final adjustedRatio = relativeIndex / (visibleDays - 1);
          x = leftPadding +
              (size.width - leftPadding - rightPadding) * adjustedRatio;
        } else {
          x = leftPadding +
              (size.width - leftPadding - rightPadding) * xPosition;
        }
      }

      // Y 좌표 계산 (상단 [topPadding]/[bottomPadding]과 동일)
      final normalizedWeight = (maxWeight - w) / weightRange;
      final y = topPadding +
          (size.height - topPadding - bottomPadding) * normalizedWeight;

      points.add(Offset(x, y));
      validIndices.add(i);
    }

    // 포인트만 그리기 (선 없음), 점은 꽉 찬 색 - 그래프 점
    final pointPaint = Paint()
      ..color = const Color(0xFFFF5A8D)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final originalIndex = validIndices[i];
      final isSelected =
          selectedPointIndex != null && selectedPointIndex == originalIndex;

      if (isSelected) {
        canvas.drawCircle(point, m.pointRadiusHighlighted, pointPaint);
        canvas.drawCircle(
          point,
          m.pointRadiusHighlighted,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = m.highlightRingStroke,
        );
      } else {
        canvas.drawCircle(point, m.pointRadius, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant WeightChartPainter oldDelegate) {
    return oldDelegate.chartData != chartData ||
        oldDelegate.yLabels != yLabels ||
        oldDelegate.timeOffset != timeOffset ||
        oldDelegate.selectedPeriod != selectedPeriod ||
        oldDelegate.selectedPointIndex != selectedPointIndex ||
        oldDelegate.omitOutOfRangeWeights != omitOutOfRangeWeights ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.bottomPadding != bottomPadding ||
        oldDelegate.barWidth != barWidth ||
        oldDelegate.scale != scale;
  }
}
