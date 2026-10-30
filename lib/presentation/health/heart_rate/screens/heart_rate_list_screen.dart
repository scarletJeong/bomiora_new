import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../data/models/health/heart_rate/heart_rate_record_model.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/repositories/health/heart_rate/heart_rate_repository.dart';
import '../../../../core/health/health_refresh_bus.dart';
import '../../../../core/health/health_refresh_listener.dart';
import '../../../../data/services/auth_service.dart';
import '../../../common/chart_layout.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../widgets/heart_rate_period_chart.dart';
import '../widgets/heart_rate_tooltip.dart';
import '../../health_common/health_chart_axis_style.dart';
import '../../health_common/health_responsive_scale.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../health_common/widgets/health_chart_expand_control.dart';
import '../../health_common/widgets/health_chart_expand_page.dart';
import '../../health_common/widgets/health_expanded_chart_layout.dart';
import '../../health_common/health_chart_y_axis.dart';
import '../../health_common/widgets/health_date_selector.dart';
import '../../health_common/widgets/health_period_selector.dart';
import '../../weight/widgets/weight_chart_section.dart';
part 'heart_rate_list_summary.dart';
part 'heart_rate_list_chart.dart';
part 'heart_rate_list_expand.dart';
part 'heart_rate_list_chart_widgets.dart';

Color _heartRateColorForStatus(String status) =>
    HeartRateRecord.statusMeansExercise(status)
        ? const Color(0xFFFF8686)
        : const Color(0xFF86B0FF);

class HeartRateListScreen extends StatefulWidget {
  final DateTime? initialDate;

  const HeartRateListScreen({super.key, this.initialDate});

  @override
  State<HeartRateListScreen> createState() => _HeartRateListScreenState();
}

class _HeartRateListScreenState extends State<HeartRateListScreen>
    with HealthRefreshListener {
  String selectedPeriod = '일';
  late DateTime selectedDate;

  UserModel? currentUser;
  bool isLoading = true;
  final List<HeartRateRecord> _allRecords = [];
  int? selectedChartPointIndex;
  Offset? tooltipPosition;
  double timeOffset = 0.0;
  double? _dragStartX;
  VoidCallback? _refreshExpandedChart;

  /// 시간대별(일) 차트 탭 툴팁
  _DailyChartTooltip? _dailyChartTooltip;
  String? _recordsCacheDateKey;
  List<HeartRateRecord>? _recordsCacheForDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedDate = widget.initialDate != null
        ? DateTime(
            widget.initialDate!.year,
            widget.initialDate!.month,
            widget.initialDate!.day,
          )
        : DateTime(now.year, now.month, now.day);
    if (_isToday()) {
      timeOffset = _dailyOffsetForToday();
    }
    _loadData();
  }

  @override
  void onHealthDataChanged() {
    if (!healthRefreshIncludes(HealthRefreshDomain.heartRate)) return;
    _loadData();
  }

  void _setChartState(VoidCallback updates) {
    if (!mounted) return;
    setState(updates);
    _refreshExpandedChart?.call();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      _dailyChartTooltip = null;
    });

    try {
      currentUser = await AuthService.getUser();
      if (currentUser != null) {
        final records = await HeartRateRepository.getHeartRateRecords(
          currentUser!.id,
        );
        _allRecords
          ..clear()
          ..addAll(records);
      } else {
        _allRecords.clear();
      }
    } catch (e) {
      _allRecords.clear();
    } finally {
      if (mounted) {
        _recordsCacheDateKey = null;
        _recordsCacheForDate = null;
        setState(() => isLoading = false);
      }
    }
  }

  bool _isToday() {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  List<HeartRateRecord> _recordsForSelectedDate() {
    final key =
        '${selectedDate.year}-${selectedDate.month}-${selectedDate.day}';
    if (_recordsCacheDateKey == key && _recordsCacheForDate != null) {
      return _recordsCacheForDate!;
    }
    final list = _allRecords.where((r) {
      final d = r.measuredAt;
      return d.year == selectedDate.year &&
          d.month == selectedDate.month &&
          d.day == selectedDate.day;
    }).toList()
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    _recordsCacheDateKey = key;
    _recordsCacheForDate = list;
    return list;
  }

  List<Map<String, dynamic>> getChartData() {
    if (selectedPeriod == '월') return _getCalendarYearMonthlyHeartData();
    if (selectedPeriod == '주') return _getWeeklyHeartData();

    final records = _recordsForSelectedDate();
    final timeRange = _calculateTimeRange();
    final minHour = timeRange['min']!;
    final maxHour = timeRange['max']!;
    final range = maxHour - minHour;

    return records.map((record) {
      final h = record.measuredAt.hour;
      final xPosition = (h - minHour) / range;
      return {
        'date': '$h시',
        'hour': h,
        'bloodSugar': record.heartRate, // 공통 차트 위젯과 키 호환
        'measurementType': record.sourceType,
        'record': record,
        'xPosition': xPosition.clamp(0.0, 1.0),
      };
    }).toList();
  }

  List<Map<String, dynamic>> _getWeeklyHeartData() {
    final chartData = <Map<String, dynamic>>[];
    const days = 7;
    final endDate =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final startDate = endDate.subtract(Duration(days: days - 1));

    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      final dayRecords = _allRecords
          .where((r) => DateFormat('yyyy-MM-dd').format(r.measuredAt) == key)
          .toList();

      chartData.add({
        'date': '${date.day}',
        'slotDate': date,
        'heartRate': null,
        'measurementType': null,
        'record': null,
        // 주간 7칸: 0.0~1.0 양끝 포함 정규화 (차트의 슬롯 인덱스 역산과 일치)
        'xPosition': days <= 1 ? 0.0 : i / (days - 1),
        'hrSeries': _buildHeartRateSeriesForSlot(dayRecords),
      });
    }

    return chartData;
  }

  /// 선택 연도 1~12월 (체중 월별 그래프와 동일 축, 드래그로 7개월 창 이동)
  List<Map<String, dynamic>> _getCalendarYearMonthlyHeartData() {
    final chartData = <Map<String, dynamic>>[];
    final year = selectedDate.year;
    for (int month = 1; month <= 12; month++) {
      final dayRecords = _allRecords.where((r) {
        return r.measuredAt.year == year && r.measuredAt.month == month;
      }).toList();
      final xPosition = (month - 1) / 11.0;
      chartData.add({
        'date': '$month',
        'slotYear': year,
        'slotMonth': month,
        'heartRate': null,
        'measurementType': null,
        'record': null,
        'xPosition': xPosition,
        'hrSeries': _buildHeartRateSeriesForSlot(dayRecords),
      });
    }
    return chartData;
  }

  /// 같은 슬롯(하루 또는 한 달) 내: 운동 먼저(아래), 일상 나중(위). 2건+ 막대, 1건 점.
  List<Map<String, dynamic>> _buildHeartRateSeriesForSlot(
    List<HeartRateRecord> records,
  ) {
    if (records.isEmpty) return [];

    final exercise = records.where((r) => r.isExerciseForChart).toList();
    final daily = records.where((r) => !r.isExerciseForChart).toList();

    final out = <Map<String, dynamic>>[];

    void addCategory(List<HeartRateRecord> list, bool isExercise) {
      if (list.isEmpty) return;
      final bpms = list.map((r) => r.heartRate).toList();
      final minB = bpms.reduce(math.min);
      final maxB = bpms.reduce(math.max);
      if (list.length >= 2) {
        out.add(<String, dynamic>{
          'kind': 'bar',
          'exercise': isExercise,
          'minBpm': minB,
          'maxBpm': maxB,
        });
      } else {
        out.add(<String, dynamic>{
          'kind': 'dot',
          'exercise': isExercise,
          'bpm': minB,
        });
      }
    }

    addCategory(exercise, true);
    addCategory(daily, false);
    return out;
  }

  Map<String, double> _calculateTimeRange({bool forExpandedChart = false}) {
    final maxStartHour = healthDailyMaxStartHour(forExpandedChart);
    final slots = healthDailyHourSlotCount(forExpandedChart);
    final startHour =
        (timeOffset * maxStartHour).clamp(0.0, maxStartHour.toDouble());
    final endHour = (startHour + slots - 1.0).clamp(slots - 1.0, 24.0);
    return {'min': startHour, 'max': endHour};
  }

  double _clampDragOffset(double newOffset, {bool forExpandedChart = false}) {
    if (_isToday()) {
      final now = DateTime.now();
      final maxStartHour = healthDailyMaxStartHour(forExpandedChart);
      final slots = healthDailyHourSlotCount(forExpandedChart);
      final targetStart = (now.hour - (slots - 2)).clamp(0, maxStartHour);
      return newOffset.clamp(0.0, targetStart / maxStartHour);
    }
    if (selectedPeriod == '월') {
      return newOffset.clamp(0.0, 1.0);
    }
    return newOffset.clamp(0.0, 1.0);
  }

  void _handleDragUpdate(
    double deltaX,
    double chartWidth, {
    bool forExpandedChart = false,
  }) {
    final sensitivity = selectedPeriod == '월' ? 3.0 : 0.5;
    final dataDelta = -(deltaX / chartWidth) * sensitivity;
    _setChartState(() {
      timeOffset = _clampDragOffset(
        timeOffset + dataDelta,
        forExpandedChart: forExpandedChart,
      );
    });
  }

  void _handleDailyChartTap(
    Offset local,
    Size chartSize,
    List<_HeartDailyVisual> visuals, {
    bool forExpandedChart = false,
  }) {
    final topPad = healthWeightChartVertPad(context);
    final botPad = healthWeightChartBottomPlotPad(context);
    final chartMinBpm = forExpandedChart ? 20.0 : 50.0;
    final chartMaxBpm = forExpandedChart ? 200.0 : 250.0;
    final idx = _HeartRateChartPainter.hitTestVisual(
      local,
      chartSize,
      visuals,
      minValue: chartMinBpm,
      maxValue: chartMaxBpm,
      topPlotPad: topPad,
      bottomPlotPad: botPad,
      scale: healthTextScaleByWidth(MediaQuery.of(context).size.width),
      xUnitReservedWidth:
          healthDp(context, ChartConstants.weightXAxisUnitReservedWidth),
    );
    _DailyChartTooltip? nextTooltip;
    if (idx == null) {
      nextTooltip = null;
    } else {
      final v = visuals[idx];
      final maxStartHour = healthDailyMaxStartHour(forExpandedChart);
      final slots = healthDailyHourSlotCount(forExpandedChart);
      final startHour =
          (timeOffset * maxStartHour).clamp(0, maxStartHour).round();
      final endHour = startHour + slots - 1;
      final hour = v.isBar ? v.bucketHour : v.record?.measuredAt.hour;
      if (hour == null || hour < startHour || hour > endHour) {
        nextTooltip = null;
      } else {
        final inHour = _recordsForSelectedDate()
            .where((r) => r.measuredAt.hour == hour)
            .toList();
        if (inHour.length >= 2) {
          nextTooltip = _DailyChartTooltip.hourBucket(
            chartLocal: local,
            bucketHour: hour,
            records: inHour,
          );
        } else if (!v.isBar && v.record != null) {
          nextTooltip = _DailyChartTooltip.single(
            chartLocal: local,
            record: v.record!,
          );
        } else {
          nextTooltip = null;
        }
      }
    }

    if (!mounted) return;
    _setChartState(() => _dailyChartTooltip = nextTooltip);
  }

  Widget _buildDailyTooltipBubble(_DailyChartTooltip t) {
    const font = 'Gmarket Sans TTF';
    final headerStyle = TextStyle(
      color: const Color(0xFF374151),
      fontSize: healthSp(context, 12),
      fontWeight: FontWeight.w400,
      fontFamily: font,
    );

    String rangeValueFor(List<HeartRateRecord> list) {
      if (list.isEmpty) return '';
      final bpms = list.map((e) => e.heartRate).toList();
      final minB = bpms.reduce(math.min);
      final maxB = bpms.reduce(math.max);
      if (list.length >= 2) {
        return minB == maxB ? '$minB' : '$minB ~ $maxB';
      }
      return '${list.single.heartRate}';
    }

    if (t.isHourBucket && t.hourRecords != null && t.bucketHour != null) {
      final daily = t.hourRecords!.where((r) => !r.isExerciseForChart).toList()
        ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
      final exercise = t.hourRecords!
          .where((r) => r.isExerciseForChart)
          .toList()
        ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

      final body = <Widget>[
        Text(
          '${t.bucketHour}시',
          textAlign: TextAlign.center,
          textScaler: TextScaler.noScaling,
          style: headerStyle,
        ),
        SizedBox(height: healthDp(context, 8)),
      ];
      if (daily.isNotEmpty) {
        body.add(
          heartRateTooltipValueRowWithBadge(
            context: context,
            badgeLabel: '일',
            badgeColor: heartRateTooltipDailyColor,
            value: rangeValueFor(daily),
          ),
        );
      }
      if (daily.isNotEmpty && exercise.isNotEmpty) {
        body.add(SizedBox(height: healthDp(context, 6)));
      }
      if (exercise.isNotEmpty) {
        body.add(
          heartRateTooltipValueRowWithBadge(
            context: context,
            badgeLabel: '운',
            badgeColor: heartRateTooltipExerciseColor,
            value: rangeValueFor(exercise),
          ),
        );
      }

      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 8),
          vertical: healthDp(context, 7),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: body,
        ),
      );
    }
    final r = t.record!;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 8),
        vertical: healthDp(context, 7),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${r.measuredAt.hour}시',
            textAlign: TextAlign.center,
            textScaler: TextScaler.noScaling,
            style: headerStyle,
          ),
          SizedBox(height: healthDp(context, 8)),
          heartRateTooltipValueRowWithBadge(
            context: context,
            badgeLabel: r.isExerciseForChart ? '운' : '일',
            badgeColor: r.isExerciseForChart
                ? heartRateTooltipExerciseColor
                : heartRateTooltipDailyColor,
            value: '${r.heartRate}',
          ),
        ],
      ),
    );
  }

  /// 같은 시(hour)·같은 status(운동/일상) 그룹: 2건 이상이면 min–max 막대, 1건이면 점.
  /// 해당 **시(hour) 전체**에 기록이 2건 이상이면 분 단위 x 대신 그 시 정각 x축에만 표시.
  List<_HeartDailyVisual> _buildDailyHeartVisuals({
    bool forExpandedChart = false,
  }) {
    final maxStartHour = healthDailyMaxStartHour(forExpandedChart);
    final slots = healthDailyHourSlotCount(forExpandedChart);
    final startHour =
        (timeOffset * maxStartHour).clamp(0, maxStartHour).round();
    final endHour = startHour + slots - 1;

    final records = _recordsForSelectedDate();
    final groups = <String, List<HeartRateRecord>>{};
    for (final r in records) {
      final calHour = r.measuredAt.hour;
      if (calHour < startHour || calHour > endHour) continue;
      final cat = r.isExerciseForChart ? 'E' : 'D';
      groups.putIfAbsent('$calHour|$cat', () => []).add(r);
    }

    final out = <_HeartDailyVisual>[];
    for (final e in groups.entries) {
      final parts = e.key.split('|');
      if (parts.length != 2) continue;
      final bucketHour = int.tryParse(parts[0]);
      if (bucketHour == null) continue;
      final isEx = parts[1] == 'E';
      final list = List<HeartRateRecord>.from(e.value)
        ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
      final color = _heartRateColorForStatus(isEx ? '운동' : '일상');

      /// X축 슬롯 중앙과 동일: (slot + 0.5) / slots
      final slot = bucketHour - startHour;
      if (slot < 0 || slot >= slots) continue;
      final hourTickX = (slot + 0.5) / slots;
      if (list.length >= 2) {
        final bpms = list.map((r) => r.heartRate).toList();
        final minB = bpms.reduce(math.min);
        final maxB = bpms.reduce(math.max);
        out.add(_HeartDailyVisual.range(
          hourTickX.clamp(0.0, 1.0),
          minB,
          maxB,
          color,
          bucketHour,
        ));
      } else {
        final r = list.single;
        // 단일 데이터도 분 단위가 아닌 해당 시간 정각 슬롯에 고정
        final x = hourTickX.clamp(0.0, 1.0);
        out.add(_HeartDailyVisual.point(x, r.heartRate, color, r));
      }
    }
    out.sort((a, b) {
      final c = a.xNorm.compareTo(b.xNorm);
      if (c != 0) return c;
      if (a.isBar == b.isBar) return 0;
      return a.isBar ? -1 : 1;
    });
    return out;
  }

  List<double> getYAxisLabels({bool forExpandedChart = false}) {
    if (forExpandedChart) {
      return const [200, 180, 160, 140, 120, 100, 80, 60, 40, 20];
    }
    return [250, 200, 150, 100, 50];
  }

  double _dailyOffsetForToday({bool forExpandedChart = false}) =>
      healthDailyTimeOffsetForToday(forExpandedChart: forExpandedChart);

  @override
  Widget build(BuildContext context) {
    final todayRecords = _recordsForSelectedDate();
    final minBpm = todayRecords.isEmpty
        ? '-'
        : '${todayRecords.map((e) => e.heartRate).reduce((a, b) => a < b ? a : b)}';
    final maxBpm = todayRecords.isEmpty
        ? '-'
        : '${todayRecords.map((e) => e.heartRate).reduce((a, b) => a > b ? a : b)}';

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
          title: '심박수',
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
                                  _setChartState(() {
                                    selectedDate = newDate;
                                    _recordsCacheDateKey = null;
                                    _recordsCacheForDate = null;
                                    selectedChartPointIndex = null;
                                    tooltipPosition = null;
                                    _dailyChartTooltip = null;
                                    if (_isToday()) {
                                      timeOffset = _dailyOffsetForToday();
                                    } else {
                                      timeOffset = 0.0;
                                    }
                                  });
                                },
                                monthTextColor: const Color(0xFF898686),
                                selectedTextColor: const Color(0xFFFF5A8D),
                                unselectedTextColor: const Color(0xFFB7B7B7),
                                dividerColor: const Color(0xFFD2D2D2),
                                iconColor: const Color(0xFF898686),
                              ),
                              SizedBox(height: healthDp(context, 20)),
                              Row(
                                children: [
                                  Expanded(
                                    child:
                                        _summaryCard(context, '최저 심박수', minBpm),
                                  ),
                                  SizedBox(width: healthDp(context, 10)),
                                  Expanded(
                                    child:
                                        _summaryCard(context, '최고 심박수', maxBpm),
                                  ),
                                ],
                              ),
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
                                  const _HeartLegend(
                                    color: Color(0xFFFF8686),
                                    label: '운동',
                                  ),
                                  SizedBox(width: healthDp(context, 10)),
                                  const _HeartLegend(
                                    color: Color(0xFF86B0FF),
                                    label: '일상',
                                  ),
                                ],
                              ),
                              SizedBox(height: healthDp(context, 20)),
                              ...todayRecords.reversed.map(_recordTile),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!kIsWeb)
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            healthDp(context, 27),
                            healthDp(context, 8),
                            healthDp(context, 27),
                            healthDp(context, 16),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: healthDp(context, 38),
                            child: ElevatedButton(
                              onPressed: _loadData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF5A8D),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  vertical: healthDp(context, 10),
                                ),
                                minimumSize: Size(
                                  double.infinity,
                                  healthDp(context, 38),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    healthDp(context, 10),
                                  ),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                '동기화 하기',
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontSize: healthSp(context, 16),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
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
}
