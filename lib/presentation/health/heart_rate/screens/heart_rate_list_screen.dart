import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../data/models/health/heart_rate/heart_rate_record_model.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/repositories/health/heart_rate/heart_rate_repository.dart';
import '../../../../data/services/auth_service.dart';
import '../../../common/chart_layout.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../widgets/heart_rate_period_chart.dart';
import '../widgets/heart_rate_tooltip.dart';
import '../../health_common/health_responsive_scale.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../health_common/widgets/health_chart_expand_control.dart';
import '../../health_common/widgets/health_chart_expand_page.dart';
import '../../blood_pressure/widgets/blood_pressure_chart_section.dart';
import '../../health_common/widgets/health_date_selector.dart';
import '../../health_common/widgets/health_period_selector.dart';
import '../../weight/widgets/weight_chart_section.dart';

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

class _HeartRateListScreenState extends State<HeartRateListScreen> {
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
      timeOffset = (now.hour - 5).clamp(0, 18) / 18.0;
    }
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

    final exercise =
        records.where((r) => r.isExerciseForChart).toList();
    final daily =
        records.where((r) => !r.isExerciseForChart).toList();

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

  Map<String, double> _calculateTimeRange() {
    const maxStartHour = 18;
    final startHour =
        (timeOffset * maxStartHour).clamp(0.0, maxStartHour.toDouble());
    final endHour = (startHour + 6.0).clamp(6.0, 24.0);
    return {'min': startHour, 'max': endHour};
  }

  double _clampDragOffset(double newOffset) {
    if (_isToday()) {
      final now = DateTime.now();
      final maxStartHour = (now.hour - 5).clamp(0, 18);
      return newOffset.clamp(0.0, maxStartHour / 18.0);
    }
    if (selectedPeriod == '월') {
      return newOffset.clamp(0.0, 1.0);
    }
    return newOffset.clamp(0.0, 1.0);
  }

  void _handleDragUpdate(double deltaX, double chartWidth) {
    final sensitivity = selectedPeriod == '월' ? 3.0 : 0.5;
    final dataDelta = -(deltaX / chartWidth) * sensitivity;
    _setChartState(() {
      timeOffset = _clampDragOffset(timeOffset + dataDelta);
    });
  }

  void _handleDailyChartTap(
    Offset local,
    Size chartSize,
    List<_HeartDailyVisual> visuals,
  ) {
    final topPad = healthWeightChartVertPad(context);
    final botPad = healthWeightChartBottomPlotPad(context);
    final idx = _HeartRateChartPainter.hitTestVisual(
      local,
      chartSize,
      visuals,
      minValue: 50,
      maxValue: 250,
      topPlotPad: topPad,
      bottomPlotPad: botPad,
    );
    _DailyChartTooltip? nextTooltip;
    if (idx == null) {
      nextTooltip = null;
    } else {
      final v = visuals[idx];
      const maxStartHour = 18;
      final startHour =
          (timeOffset * maxStartHour).clamp(0, maxStartHour).round();
      final endHour = startHour + 6;
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
    const headerStyle = TextStyle(
      color: Color(0xFF374151),
      fontSize: 12,
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
      final daily = t.hourRecords!
          .where((r) => !r.isExerciseForChart)
          .toList()
        ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
      final exercise = t.hourRecords!
          .where((r) => r.isExerciseForChart)
          .toList()
        ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

      final body = <Widget>[
        Text(
          '${t.bucketHour}시',
          textAlign: TextAlign.center,
          style: headerStyle,
        ),
        const SizedBox(height: 8),
      ];
      if (daily.isNotEmpty) {
        body.add(
          heartRateTooltipValueRowWithBadge(
            badgeLabel: '일',
            badgeColor: heartRateTooltipDailyColor,
            value: rangeValueFor(daily),
          ),
        );
      }
      if (daily.isNotEmpty && exercise.isNotEmpty) {
        body.add(const SizedBox(height: 6));
      }
      if (exercise.isNotEmpty) {
        body.add(
          heartRateTooltipValueRowWithBadge(
            badgeLabel: '운',
            badgeColor: heartRateTooltipExerciseColor,
            value: rangeValueFor(exercise),
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${r.measuredAt.hour}시',
            textAlign: TextAlign.center,
            style: headerStyle,
          ),
          const SizedBox(height: 8),
          heartRateTooltipValueRowWithBadge(
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
  List<_HeartDailyVisual> _buildDailyHeartVisuals() {
    const maxStartHour = 18;
    final startHour =
        (timeOffset * maxStartHour).clamp(0, maxStartHour).round();
    final endHour = startHour + 6;
    final minHour = startHour.toDouble();
    final range = (endHour - minHour).toDouble();
    if (range <= 0) return [];

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
      final color =
          _heartRateColorForStatus(isEx ? '운동' : '일상');

      /// X축 정수 시 라벨(10시)과 동일: 해당 시각 0분 위치 (평균 시각 아님)
      final hourTickX =
          (bucketHour - minHour) / range.clamp(0.001, double.infinity);
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

  List<double> getYAxisLabels() => [250, 200, 150, 100, 50];

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
    final textScale =
        healthTextScaleByWidth(MediaQuery.of(context).size.width);

    return Theme(
      data: gmarketTheme,
      child: MobileAppLayoutWrapper(
        appBar: HealthAppBar(
          title: '심박수',
          titleFontSize: healthSp(context, 18),
          leadingIconSize: healthDp(context, 24),
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
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
                            final now = DateTime.now();
                            timeOffset =
                                (now.hour - 5).clamp(0, 18) / 18.0;
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
                    SizedBox(height: healthDp(context, 16)),
                    Row(
                      children: [
                        Expanded(
                          child: _summaryCard(context, '최저 심박수', minBpm),
                        ),
                        SizedBox(width: healthDp(context, 10)),
                        Expanded(
                          child: _summaryCard(context, '최고 심박수', maxBpm),
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
                    SizedBox(height: healthDp(context, 12)),
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
                    SizedBox(height: healthDp(context, 16)),
                    ...todayRecords.reversed.map(_recordTile),
                    SizedBox(height: healthDp(context, 24)),
                    SizedBox(
                      width: double.infinity,
                      height: healthDp(context, 45),
                      child: ElevatedButton(
                        onPressed: _loadData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5A8D),
                          foregroundColor: Colors.white,
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
                    SizedBox(height: healthDp(context, 24)),
                  ],
                ),
              ),
            ),
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context, String title, String value) {
    final bool hasData = value != '-';
    final hPad = healthDp(context, 14);
    final vPad = healthDp(context, 12);
    return Container(
      constraints: BoxConstraints(minHeight: healthDp(context, 90)),
      padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 0.5),
            color: const Color(0x7FD2D2D2),
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: const Color(0xFF1A1A1A),
              fontSize: healthSp(context, 16.67),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          RichText(
            textScaler: TextScaler.noScaling,
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: healthSp(context, 20.83),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: hasData ? FontWeight.w700 : FontWeight.w300,
                  ),
                ),
                TextSpan(
                  text: ' bpm',
                  style: TextStyle(
                    color: const Color(0xFF9C9393),
                    fontSize: healthSp(context, 13.33),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
          if (!hasData) ...[
            SizedBox(height: healthDp(context, 5)),
            Text(
              '수치를 입력하세요',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: const Color(0xFF9C9393),
                fontSize: healthSp(context, 10),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _recordTile(HeartRateRecord record) {
    final tilePad = healthDp(context, 12);
    return Container(
      margin: EdgeInsets.only(bottom: healthDp(context, 10)),
      padding: EdgeInsets.all(tilePad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x19000000),
            blurRadius: healthDp(context, 4.17),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            color: Colors.grey,
            size: healthDp(context, 20),
          ),
          SizedBox(width: healthDp(context, 15)),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('a h:mm', 'ko').format(record.measuredAt),
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: healthSp(context, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                heartRateTooltipValueRowWithBadge(
                  badgeLabel:
                      record.isExerciseForChart ? '운' : '일',
                  badgeColor: record.isExerciseForChart
                      ? heartRateTooltipExerciseColor
                      : heartRateTooltipDailyColor,
                  value: '${record.heartRate}bpm',
                  valueStyle: TextStyle(
                    color: Colors.black,
                    fontSize: healthSp(context, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                  ),
                  valueTextScaler: TextScaler.noScaling,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handlePeriodChanged(String period) {
    _setChartState(() {
      selectedPeriod = period;
      _recordsCacheDateKey = null;
      _recordsCacheForDate = null;
      selectedChartPointIndex = null;
      tooltipPosition = null;
      _dailyChartTooltip = null;
      if (period == '월') {
        timeOffset = 0.0;
      } else if (period == '주') {
        timeOffset = 0.0;
      } else if (_isToday()) {
        final now = DateTime.now();
        timeOffset = (now.hour - 5).clamp(0, 18) / 18.0;
      } else {
        timeOffset = 0.0;
      }
    });
  }

  Widget _buildChart({
    bool showExpandButton = true,
    bool chartPeriodTabsInCard = true,
    double chartHeight = ChartConstants.weightChartHeight,
  }) {
    final yLabels = getYAxisLabels();

    Widget chartBody;
    if (selectedPeriod != '일') {
      chartBody = HeartRateChartWidget(
        chartData: getChartData(),
        yLabels: yLabels,
        selectedPeriod: selectedPeriod,
        selectedDate: selectedDate,
        timeOffset: timeOffset,
        height: chartHeight,
        onTimeOffsetChanged: (newOffset) {
          _setChartState(() => timeOffset = newOffset);
        },
        onTooltipChanged: (index, position) {
          if (!mounted) return;
          _setChartState(() {
            selectedChartPointIndex = index;
            tooltipPosition = position;
          });
        },
        selectedChartPointIndex: selectedChartPointIndex,
        tooltipPosition: tooltipPosition,
        yAxisCount: yLabels.length,
        useCalendarYearMonths: selectedPeriod == '월',
        showPeriodSelector: chartPeriodTabsInCard,
        onPeriodChanged:
            chartPeriodTabsInCard ? _handlePeriodChanged : null,
        cardBackgroundColor: Colors.white,
      );
    } else if (_recordsForSelectedDate().isEmpty) {
      chartBody = HealthDailyNoDataChartCard(
        chartHeight: chartHeight,
        title: '해당 기간에 심박수 기록이 없습니다',
        subtitle: '심박수를 측정해보세요',
        header: chartPeriodTabsInCard
            ? HealthPeriodSelector(
                selectedPeriod: selectedPeriod,
                onChanged: _handlePeriodChanged,
                plainStyle: true,
              )
            : null,
      );
    } else {
      chartBody = _buildDailyChart(
        yLabels,
        chartPeriodTabsInCard: chartPeriodTabsInCard,
        chartHeight: chartHeight,
      );
    }

    if (!showExpandButton) return chartBody;

    final showYHeader = yLabels.length > 1;
    final headerBand =
        showYHeader ? bloodPressureYAxisUnitBandHeight(context) : 0.0;
    final padTop = healthChartCardPadding(context).top;
    final tabH =
        healthDp(context, ChartConstants.weightChartPeriodTabBarHeight);
    final gap = healthDp(context, ChartConstants.weightChartTabToPlotGap);
    final iconSize = healthDp(context, 20);
    final expandH = HealthChartExpandControl.blockHeight(context, iconSize);
    final topExpand = chartPeriodTabsInCard
        ? padTop + tabH + gap + headerBand / 2 - expandH / 2
        : padTop + headerBand / 2 - expandH / 2;

    return Stack(
      children: [
        chartBody,
        Positioned(
          right: healthChartCardPadding(context).right,
          top: topExpand,
          child: HealthChartExpandControl(
            onTap: _openExpandedChartPage,
            iconSize: iconSize,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyChart(
    List<double> yLabels, {
    required bool chartPeriodTabsInCard,
    double chartHeight = ChartConstants.weightChartHeight,
  }) {
    final dailyVisuals = _buildDailyHeartVisuals();
    final topPad = healthWeightChartVertPad(context);
    final botPad = healthWeightChartBottomPlotPad(context);
    return Container(
      height: chartHeight,
      padding: healthChartCardPadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(healthDp(context, 12)),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chartPeriodTabsInCard) ...[
            HealthPeriodSelector(
              selectedPeriod: selectedPeriod,
              onChanged: _handlePeriodChanged,
              plainStyle: true,
            ),
            SizedBox(
                height: healthDp(
                    context, ChartConstants.weightChartTabToPlotGap)),
          ],
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showYHeader = yLabels.length > 1;
                final headerBand = showYHeader
                    ? bloodPressureYAxisUnitBandHeight(context)
                    : 0.0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildBloodPressureYAxisStrip(
                      yLabels: yLabels,
                      showYAxisHeader: showYHeader,
                      unitLabel: '(bpm)',
                    ),
                    SizedBox(
                        width: healthDp(
                            context, ChartConstants.weightChartYAxisPlotGap)),
                    Expanded(
                      child: ColoredBox(
                        color: Colors.white,
                        child: Column(
                          children: [
                            if (showYHeader) SizedBox(height: headerBand),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, inner) {
                                  final w = inner.maxWidth;
                                  final h = inner.maxHeight;
                                  if (w <= 0 || h <= 0) {
                                    return const SizedBox.shrink();
                                  }
                                  final tooltipPad = healthDp(context, 6);
                                  final tooltipLift = healthDp(context, 92);
                                  final tooltipBottomReserve =
                                      healthDp(context, 110);
                                  final tooltipMinW = healthDp(context, 88);
                                  final tooltipMaxWCap = healthDp(context, 240);
                                  Widget? dailyTooltipOverlay;
                                  if (_dailyChartTooltip != null) {
                                    final double anchorLeft =
                                        _dailyChartTooltip!.chartLocal.dx
                                            .clamp(
                                      tooltipPad,
                                      math.max(
                                        tooltipPad,
                                        w - tooltipPad,
                                      ),
                                    ).toDouble();
                                    /// [HeartRateTooltip._positionedCard]와 동일
                                    final double maxTooltipW = (w -
                                                anchorLeft -
                                                tooltipPad)
                                            .clamp(
                                              tooltipMinW,
                                              tooltipMaxWCap,
                                            )
                                            .toDouble();
                                    final double topY =
                                        (_dailyChartTooltip!.chartLocal.dy -
                                                tooltipLift)
                                            .clamp(
                                      tooltipPad,
                                      math.max(
                                        tooltipPad,
                                        h -
                                            tooltipBottomReserve -
                                            tooltipPad,
                                      ),
                                    ).toDouble();
                                    dailyTooltipOverlay = Positioned(
                                      left: anchorLeft,
                                      top: topY,
                                      child: FractionalTranslation(
                                        translation: const Offset(-0.5, 0),
                                        child: Material(
                                          type: MaterialType.transparency,
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              minWidth: tooltipMinW,
                                              maxWidth: maxTooltipW,
                                            ),
                                            child: _buildDailyTooltipBubble(
                                              _dailyChartTooltip!,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      GestureDetector(
                                        behavior: HitTestBehavior.translucent,
                                        onTapDown: (details) {
                                          _handleDailyChartTap(
                                            details.localPosition,
                                            Size(w, h),
                                            dailyVisuals,
                                          );
                                        },
                                        onPanStart:
                                            (selectedPeriod == '일' ||
                                                    selectedPeriod == '월')
                                                ? (details) {
                                                    _setChartState(
                                                      () => _dailyChartTooltip =
                                                          null,
                                                    );
                                                    _dragStartX = details
                                                        .localPosition.dx;
                                                  }
                                                : null,
                                        onPanUpdate:
                                            (selectedPeriod == '일' ||
                                                    selectedPeriod == '월')
                                                ? (details) {
                                                    if (_dragStartX != null) {
                                                      final deltaX = details
                                                              .localPosition
                                                              .dx -
                                                          _dragStartX!;
                                                      _handleDragUpdate(
                                                          deltaX, w);
                                                      _dragStartX = details
                                                          .localPosition.dx;
                                                    }
                                                  }
                                                : null,
                                        onPanEnd:
                                            (selectedPeriod == '일' ||
                                                    selectedPeriod == '월')
                                                ? (_) => _dragStartX = null
                                                : null,
                                        child: CustomPaint(
                                          size: Size(w, h),
                                          painter: _HeartRateChartPainter(
                                            visuals: dailyVisuals,
                                            minValue: 50,
                                            maxValue: 250,
                                            topPlotPad: topPad,
                                            bottomPlotPad: botPad,
                                          ),
                                        ),
                                      ),
                                      if (dailyTooltipOverlay != null)
                                        dailyTooltipOverlay,
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(
            height: healthDp(context, 30),
            child: Padding(
              padding: EdgeInsets.only(
                left: healthDp(
                  context,
                  ChartConstants.weightChartYAxisStripWidth,
                ),
              ),
              child: buildWeightXAxisLabels(
                context: context,
                selectedPeriod: '일',
                selectedDate: selectedDate,
                timeOffset: timeOffset,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openExpandedChartPage() async {
    await openHealthChartExpandPage(
      context: context,
      periodSelectorBuilder: (_) => HealthPeriodSelector(
        selectedPeriod: selectedPeriod,
        onChanged: (period) => _setChartState(() {
          selectedPeriod = period;
          selectedChartPointIndex = null;
          tooltipPosition = null;
          _dailyChartTooltip = null;
          if (period == '월' || period == '주') {
            timeOffset = 0.0;
          } else if (_isToday()) {
            final now = DateTime.now();
            timeOffset = (now.hour - 5).clamp(0, 18) / 18.0;
          } else {
            timeOffset = 0.0;
          }
        }),
      ),
      chartBuilder: (_) {
        final base = Theme.of(context);
        final gmarket = base.copyWith(
          textTheme: base.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
          primaryTextTheme:
              base.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            final scaledChartCap =
                healthDp(context, ChartConstants.weightChartHeight);
            final scaledChartMin = healthDp(context, 160);
            final safeHeight = ChartConstants.healthExpandedChartHeight(
              constraints.maxHeight,
              bottomLegendReserve: 34,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildChart(
                      showExpandButton: false,
                      chartPeriodTabsInCard: false,
                      chartHeight: safeHeight,
                    ),
                    SizedBox(height: healthDp(context, 6)),
                    Row(
                      children: [
                        const _HeartLegend(
                          color: Color(0xFFFF8686),
                          label: '운동',
                          compact: true,
                        ),
                        SizedBox(width: healthDp(context, 6)),
                        const _HeartLegend(
                          color: Color(0xFF86B0FF),
                          label: '일상',
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      onRegisterRefresh: (refresh) => _refreshExpandedChart = refresh,
      onDisposeRefresh: () => _refreshExpandedChart = null,
    );
  }
}

/// 시간대별(일) 차트 탭 시 표시
class _DailyChartTooltip {
  final Offset chartLocal;
  /// true: 해당 시에 기록 2건 이상 → 일상/운동 구간을 한 카드에 표시
  final bool isHourBucket;
  final HeartRateRecord? record;
  final int? bucketHour;
  final List<HeartRateRecord>? hourRecords;

  _DailyChartTooltip._({
    required this.chartLocal,
    required this.isHourBucket,
    this.record,
    this.bucketHour,
    this.hourRecords,
  });

  factory _DailyChartTooltip.single({
    required Offset chartLocal,
    required HeartRateRecord record,
  }) {
    return _DailyChartTooltip._(
      chartLocal: chartLocal,
      isHourBucket: false,
      record: record,
    );
  }

  factory _DailyChartTooltip.hourBucket({
    required Offset chartLocal,
    required int bucketHour,
    required List<HeartRateRecord> records,
  }) {
    return _DailyChartTooltip._(
      chartLocal: chartLocal,
      isHourBucket: true,
      bucketHour: bucketHour,
      hourRecords: records,
    );
  }
}

class _HeartLegend extends StatelessWidget {
  final Color color;
  final String label;
  final bool compact;

  const _HeartLegend({
    required this.color,
    required this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final dot = compact ? healthDp(context, 8) : healthDp(context, 12);
    final gap = compact ? healthDp(context, 3) : healthDp(context, 5);
    final fontSize = compact ? healthSp(context, 9) : healthSp(context, 12);
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
          textScaler: TextScaler.noScaling,
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

class _HeartDailyVisual {
  final bool isBar;
  final double xNorm;
  final int singleBpm;
  final int minBpm;
  final int maxBpm;
  final Color color;
  final HeartRateRecord? record;
  final int? bucketHour;

  _HeartDailyVisual.point(
    this.xNorm,
    this.singleBpm,
    this.color,
    this.record,
  )   : isBar = false,
        minBpm = singleBpm,
        maxBpm = singleBpm,
        bucketHour = null;

  _HeartDailyVisual.range(
    this.xNorm,
    this.minBpm,
    this.maxBpm,
    this.color,
    this.bucketHour,
  )   : isBar = true,
        singleBpm = minBpm,
        record = null;

  @override
  bool operator ==(Object other) {
    if (other is! _HeartDailyVisual) return false;
    return isBar == other.isBar &&
        xNorm == other.xNorm &&
        minBpm == other.minBpm &&
        maxBpm == other.maxBpm &&
        color == other.color &&
        bucketHour == other.bucketHour &&
        record?.id == other.record?.id;
  }

  @override
  int get hashCode =>
      Object.hash(isBar, xNorm, minBpm, maxBpm, color, bucketHour, record?.id);
}

class _HeartRateChartPainter extends CustomPainter {
  final List<_HeartDailyVisual> visuals;
  final double minValue;
  final double maxValue;
  final double topPlotPad;
  final double bottomPlotPad;

  _HeartRateChartPainter({
    required this.visuals,
    required this.minValue,
    required this.maxValue,
    required this.topPlotPad,
    required this.bottomPlotPad,
  });

  static const double _leftPad = ChartConstants.weightDailyChartInnerPadH;
  // X축 라벨(끝의 '(시)')이 차지하는 오른쪽 여백과 동일하게 맞춰야
  // 정시 라벨 중심과 점/막대가 정확히 정렬된다.
  static const double _rightPad = ChartConstants.weightDailyChartInnerPadH +
      ChartConstants.weightXAxisUnitReservedWidth;
  static const double _dotRadius = 6.0;
  static const double _barWidth = 10.0;
  static const double _minBarHeight = 5.0;
  static const double _hitSlop = 14.0;

  /// 탭 위치가 점/막대에 가까우면 인덱스, 아니면 null (위에서 그린 순서 우선)
  static int? hitTestVisual(
    Offset local,
    Size size,
    List<_HeartDailyVisual> visuals, {
    required double minValue,
    required double maxValue,
    required double topPlotPad,
    required double bottomPlotPad,
  }) {
    if (visuals.isEmpty) return null;
    final plotH = size.height - topPlotPad - bottomPlotPad;
    final plotW = size.width - _leftPad - _rightPad;
    final rangeBpm = maxValue - minValue;
    if (rangeBpm <= 0 || plotW <= 0 || plotH <= 0) return null;

    double toY(double bpm) {
      final n = (maxValue - bpm) / rangeBpm;
      return topPlotPad + plotH * n;
    }

    for (int i = visuals.length - 1; i >= 0; i--) {
      final v = visuals[i];
      final x = _leftPad + plotW * v.xNorm.clamp(0.0, 1.0);
      if (v.isBar) {
        var yHigh = toY(v.maxBpm.toDouble());
        var yLow = toY(v.minBpm.toDouble());
        if (yHigh > yLow) {
          final t = yHigh;
          yHigh = yLow;
          yLow = t;
        }
        var barH = yLow - yHigh;
        if (barH < _minBarHeight) {
          final mid = (yHigh + yLow) / 2;
          yHigh = mid - _minBarHeight / 2;
          barH = _minBarHeight;
        }
        final rect = Rect.fromLTRB(
          x - _barWidth / 2 - _hitSlop,
          yHigh - _hitSlop,
          x + _barWidth / 2 + _hitSlop,
          yHigh + barH + _hitSlop,
        );
        if (rect.contains(local)) return i;
      } else {
        final y = toY(v.singleBpm.toDouble());
        if ((local - Offset(x, y)).distance <= _dotRadius + _hitSlop) {
          return i;
        }
      }
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white,
    );

    const leftPad = _leftPad;
    const rightPad = _rightPad;
    final topPad = topPlotPad;
    final botPad = bottomPlotPad;
    final plotH = size.height - topPad - botPad;
    final plotW = size.width - leftPad - rightPad;

    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    const yAxisCount = 5;
    for (int i = 0; i < yAxisCount; i++) {
      final y = topPad + plotH * i / (yAxisCount - 1);
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );
    }

    if (visuals.isEmpty) return;

    final rangeBpm = maxValue - minValue;
    if (rangeBpm <= 0) return;

    double toY(double bpm) {
      final n = (maxValue - bpm) / rangeBpm;
      return topPad + plotH * n;
    }

    const dotRadius = _dotRadius;
    const barWidth = _barWidth;
    const minBarHeight = _minBarHeight;

    for (final v in visuals) {
      final x = leftPad + plotW * v.xNorm.clamp(0.0, 1.0);
      final fill = Paint()
        ..color = v.color
        ..style = PaintingStyle.fill;

      if (v.isBar) {
        var yHigh = toY(v.maxBpm.toDouble());
        var yLow = toY(v.minBpm.toDouble());
        if (yHigh > yLow) {
          final t = yHigh;
          yHigh = yLow;
          yLow = t;
        }
        var barH = yLow - yHigh;
        if (barH < minBarHeight) {
          final mid = (yHigh + yLow) / 2;
          yHigh = mid - minBarHeight / 2;
          barH = minBarHeight;
        }
        final barRect = Rect.fromLTWH(x - barWidth / 2, yHigh, barWidth, barH);
        final cornerR = math.min(barWidth / 2, barH / 2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            barRect,
            Radius.circular(cornerR),
          ),
          fill,
        );
      } else {
        canvas.drawCircle(
          Offset(x, toY(v.singleBpm.toDouble())),
          dotRadius,
          fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeartRateChartPainter oldDelegate) {
    return !listEquals(oldDelegate.visuals, visuals) ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.topPlotPad != topPlotPad ||
        oldDelegate.bottomPlotPad != bottomPlotPad;
  }
}
