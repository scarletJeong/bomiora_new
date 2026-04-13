import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

import '../../../common/chart_layout.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../../data/models/health/steps/steps_record_model.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/repositories/health/steps/steps_repository.dart';
import '../../../../data/repositories/health/health_goal/health_goal_repository.dart';
import '../../../../data/models/health/health_goal_record_model.dart';
import '../../../../data/services/auth_service.dart';
import '../utils/step_calculator.dart';
import '../widgets/steps_chart_tooltip.dart';
import '../../health_common/widgets/health_chart_expand_page.dart';
import '../../health_common/widgets/health_date_selector.dart';
import '../../health_common/widgets/health_period_selector.dart';

const double _stepsYAxisUnitBandHeight = 16.0;

class StepsTodayScreen extends StatefulWidget {
  final DateTime? initialDate;

  const StepsTodayScreen({super.key, this.initialDate});

  @override
  State<StepsTodayScreen> createState() => _StepsTodayScreenState();
}

class _StepsTodayScreenState extends State<StepsTodayScreen> {
  UserModel? currentUser;
  StepsRecord? todayStepsRecord;
  StepsStatistics? stepsStatistics;
  HealthGoalRecordModel? latestHealthGoal;
  DateTime selectedDate = DateTime.now();
  bool isLoading = true;
  String selectedPeriod = '일';
  double timeOffset = 0.0;
  VoidCallback? _refreshExpandedChart;
  /// 주간(월~일) 일자키 `YYYY-MM-DD` → 총 걸음 (`bm_steps` 집계)
  Map<String, int> weekStepsByDate = {};
  /// 선택 연도 1~12월 총 걸음
  List<int> monthSteps12 = List<int>.filled(12, 0);
  int? _tooltipIndex;
  Offset? _tooltipPosition;

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      selectedDate = widget.initialDate!;
    }
    timeOffset = _isToday() ? _defaultDailyTimeOffset() : 0.0;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      final user = await AuthService.getUser();

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다')),
          );
          Navigator.pop(context);
        }
        return;
      }

      final end =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final start = end.subtract(const Duration(days: 6));

      final results = await Future.wait([
        StepsRepository.getStepsRecordByMbId(user.id, selectedDate),
        StepsRepository.getStepsStatisticsByMbId(user.id),
        HealthGoalRepository.fetchLatest(user.id).catchError((_) => null),
        StepsRepository.getStepsDailyRange(user.id, start, end),
        StepsRepository.getStepsMonthlyTotalsForYear(user.id, selectedDate.year),
      ]);

      setState(() {
        currentUser = user;
        todayStepsRecord = results[0] as StepsRecord?;
        stepsStatistics = results[1] as StepsStatistics?;
        latestHealthGoal = results[2] as HealthGoalRecordModel?;
        weekStepsByDate = Map<String, int>.from(results[3] as Map<String, int>);
        monthSteps12 = List<int>.from(results[4] as List<int>);
        isLoading = false;
      });
    } catch (e, st) {
      debugPrint('StepsTodayScreen._loadData: $e\n$st');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터 로딩 실패: $e')),
        );
      }
    }
  }

  void _notifyExpandedChart() {
    _refreshExpandedChart?.call();
  }

  bool _isToday() {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  void _clearTooltip() {
    if (_tooltipIndex == null && _tooltipPosition == null) return;
    setState(() {
      _tooltipIndex = null;
      _tooltipPosition = null;
    });
  }

  double _defaultDailyTimeOffset() {
    const maxStartSlot = 36;
    final now = DateTime.now();
    final currentSlot = now.hour * 2 + (now.minute >= 30 ? 1 : 0);
    final startSlot = (currentSlot - 8).clamp(0, maxStartSlot);
    return startSlot / maxStartSlot;
  }

  double _clampTimeOffset(double next) {
    if (selectedPeriod == '월') {
      return next.clamp(0.0, 1.0);
    }
    if (selectedPeriod == '일') {
      if (_isToday()) {
        const maxStartSlot = 36;
        final now = DateTime.now();
        final currentSlot = now.hour * 2 + (now.minute >= 30 ? 1 : 0);
        final maxOffset = ((currentSlot - 8).clamp(0, maxStartSlot)) / maxStartSlot;
        return next.clamp(0.0, maxOffset);
      }
      return next.clamp(0.0, 1.0);
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '총 걸음 수',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      child: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFFF5A8D)),
                  SizedBox(height: 16),
                  Text('데이터를 불러오는 중...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HealthDateSelector(
                    selectedDate: selectedDate,
                    onDateChanged: (newDate) async {
                      setState(() {
                        selectedDate = newDate;
                        if (selectedPeriod == '일') {
                          timeOffset = _isToday() ? _defaultDailyTimeOffset() : 0.0;
                        }
                      });
                      await _loadData();
                    },
                    monthTextColor: const Color(0xFF898686),
                    selectedTextColor: const Color(0xFFFF5A8D),
                    unselectedTextColor: const Color(0xFF1A1A1A),
                    iconColor: const Color(0xFF898686),
                    dividerColor: const Color(0xFFD2D2D2),
                  ),
                  const SizedBox(height: 5),
                  _buildTotalStepsCard(),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          title: '거리',
                          unitSmall: '(km)',
                          icon: Icons.directions_walk,
                          value: (todayStepsRecord != null &&
                                  todayStepsRecord!.distance > 0)
                              ? todayStepsRecord!.distance.toStringAsFixed(1)
                              : StepCalculator.kmFromSteps(
                                      todayStepsRecord?.totalSteps ?? 0)
                                  .toStringAsFixed(1),
                          valueUnit: 'km',
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildSummaryCard(
                          title: '칼로리',
                          unitSmall: '(kcal)',
                          icon: Icons.local_fire_department,
                          value: (todayStepsRecord != null &&
                                  todayStepsRecord!.calories > 0)
                              ? todayStepsRecord!.calories.toString()
                              : StepCalculator.kcalFromSteps(
                                      todayStepsRecord?.totalSteps ?? 0)
                                  .toString(),
                          valueUnit: 'kcal',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  HealthPeriodSelector(
                    selectedPeriod: selectedPeriod,
                    onChanged: (period) {
                      setState(() {
                        selectedPeriod = period;
                        if (period == '일') {
                          timeOffset = _isToday() ? _defaultDailyTimeOffset() : 0.0;
                        } else if (period == '월') {
                          timeOffset = 0.0;
                        } else {
                          timeOffset = 0.0;
                        }
                      });
                      _notifyExpandedChart();
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildChartCard(),
                ],
              ),
            ),
    );
  }

  // 총 걸음수 원
  Widget _buildTotalStepsCard() {
    final totalSteps = todayStepsRecord?.totalSteps ?? 0;
    final int? goalSteps = latestHealthGoal?.dailyStepGoal;
    final ratio = (goalSteps == null || goalSteps <= 0)
        ? 0.0
        : (totalSteps / goalSteps).clamp(0.0, 1.0);
    final diff = todayStepsRecord?.stepsDifference ??
        stepsStatistics?.stepsDifference ??
        0;
    final diffUp = diff > 0;
    final diffDown = diff < 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Transform.translate(
                    offset: const Offset(-18, 0),
                    child: SizedBox(
                      width: 204,
                      height: 204,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(192, 192),
                            painter: _StepsGoalRingPainter(
                              progress: ratio,
                              trackColor: const Color(0x7FD9D9D9),
                              progressColor: const Color(0xFFFF5A8D),
                              strokeWidth: 18,
                              progressStrokeWidth: 18,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '총 걸음 수',
                                style: TextStyle(
                                  color: Color(0xFF1A1A1A),
                                  fontSize: 16,
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                NumberFormat('#,###').format(totalSteps),
                                style: const TextStyle(
                                  color: Color(0xFFFF5A8D),
                                  fontSize: 28,
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      '목표 걸음수',
                      style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 20,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      goalSteps != null
                          ? NumberFormat('#,###').format(goalSteps)
                          : '-',
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 20,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '전날 대비',
                      style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 20,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (diff == 0)
                          const Text(
                            '-',
                            style: TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 20,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        else ...[
                          Text(
                            NumberFormat('#,###').format(diff.abs()),
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 20,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            diffUp ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 16,
                            color: diffDown
                                ? const Color(0xFF002BFF)
                                : const Color(0xFFFF0000),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String unitSmall,
    required IconData icon,
    required String value,
    required String valueUnit,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(width: 0.5, color: const Color(0xFFD9D9D9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    Text(
                      unitSmall,
                      style: const TextStyle(
                        color: Color(0xFF898686),
                        fontSize: 10,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF2F8),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Icon(icon, size: 16, color: const Color(0xFFFF5A8D)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFFFF5A8D),
                  fontSize: 22,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                valueUnit,
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 11,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({
    bool showExpandButton = true,
    double? chartHeight,
  }) {
    final h = chartHeight ?? ChartConstants.healthChartHeight;
    return Stack(
      children: [
        Container(
          height: h,
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: _buildBarChartArea(),
        ),
        if (showExpandButton)
          Positioned(
            top: 8,
            right: 8,
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

  Widget _buildBarChartArea() {
    final data = _buildPeriodChartData();
    final maxValue = _chartMaxValue();
    final yTicks = _buildYAxisTicks();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepsYAxisStrip(
          labels: _buildYAxisDisplayLabels(),
          unitLabel: _yAxisUnitLabel(),
        ),
        const SizedBox(width: ChartConstants.yAxisSpacing),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final labels = _buildXAxisLabels();
              final visibleData = _buildVisibleChartData(data);
              final forceWhiteBg =
                  selectedPeriod == '일' || selectedPeriod == '월';
              final chartH = constraints.maxHeight -
                  _stepsYAxisUnitBandHeight -
                  26;

              return ColoredBox(
                color: forceWhiteBg ? Colors.white : Colors.transparent,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _clearTooltip,
                  child: Column(
                    children: [
                      const SizedBox(height: _stepsYAxisUnitBandHeight),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) {
                            if (visibleData.isEmpty) return;
                            final w = math.max(constraints.maxWidth, 1.0);
                            final localX =
                                d.localPosition.dx.clamp(0.0, w);
                            final idx = ((localX / w) * visibleData.length)
                                .floor()
                                .clamp(0, visibleData.length - 1);
                            if (visibleData[idx].value <= 0) {
                              setState(() {
                                _tooltipIndex = null;
                                _tooltipPosition = null;
                              });
                              return;
                            }
                            setState(() {
                              _tooltipIndex = idx;
                              _tooltipPosition = Offset(localX, 30);
                            });
                          },
                          onPanUpdate:
                              selectedPeriod == '일' || selectedPeriod == '월'
                                  ? (details) {
                                      final next = timeOffset -
                                          (details.delta.dx /
                                              math.max(
                                                  constraints.maxWidth, 1)) *
                                              (selectedPeriod == '일'
                                                  ? 2.4
                                                  : 1.8);
                                      setState(() {
                                        timeOffset =
                                            _clampTimeOffset(next);
                                      });
                                      _notifyExpandedChart();
                                    }
                                  : null,
                          child: Stack(
                            children: [
                              CustomPaint(
                                painter: _StepsBarChartPainter(
                                  data: visibleData,
                                  maxValue: maxValue,
                                  yTickCount: yTicks.length,
                                  barWidth: selectedPeriod == '일'
                                      ? 8
                                      : selectedPeriod == '월'
                                          ? 12
                                          : 14,
                                ),
                                size: Size(double.infinity, chartH),
                              ),
                              StepsChartTooltip(
                                selectedPeriod: selectedPeriod,
                                data: _tooltipDataForVisible(
                                  visibleData: visibleData,
                                  visibleIndex: _tooltipIndex,
                                ),
                                tooltipPosition: _tooltipPosition,
                                chartWidth: constraints.maxWidth,
                                chartHeight: chartH,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildXAxisLabelRow(labels),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _tooltipDataForVisible({
    required List<_StepsBarData> visibleData,
    required int? visibleIndex,
  }) {
    if (visibleIndex == null ||
        visibleIndex < 0 ||
        visibleIndex >= visibleData.length) {
      return const {};
    }
    final bar = visibleData[visibleIndex];
    final steps = bar.value;
    if (steps <= 0) return const {};

    if (selectedPeriod == '일') {
      final parts = bar.label.split(':');
      final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
      final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
      return {
        'slotHour': hour,
        'slotMinute': minute,
        'steps': steps,
      };
    }

    if (selectedPeriod == '주') {
      final end =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final start = end.subtract(const Duration(days: 6));
      final d = start.add(Duration(days: visibleIndex));
      return {
        'slotDate': d,
        'steps': steps,
      };
    }

    final month = int.tryParse(bar.label) ?? 1;
    return {
      'slotYear': selectedDate.year,
      'slotMonth': month,
      'steps': steps,
    };
  }

  List<_StepsBarData> _buildPeriodChartData() {
    if (selectedPeriod == '일') {
      final raw = todayStepsRecord?.halfHourSteps ?? const <int>[];
      return List<_StepsBarData>.generate(48, (i) {
        final hour = i ~/ 2;
        final minute = i.isEven ? '00' : '30';
        final value = i < raw.length ? raw[i] : 0;
        return _StepsBarData(label: '$hour:$minute', value: value);
      });
    }

    if (selectedPeriod == '주') {
      final end =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final start = end.subtract(const Duration(days: 6));
      return List<_StepsBarData>.generate(7, (i) {
        final d = start.add(Duration(days: i));
        final key =
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        return _StepsBarData(
          label: '${d.month}.${d.day}',
          value: weekStepsByDate[key] ?? 0,
        );
      });
    }

    return List<_StepsBarData>.generate(
      12,
      (i) => _StepsBarData(
        label: '${i + 1}',
        value: i < monthSteps12.length ? monthSteps12[i] : 0,
      ),
    );
  }

  int _chartMaxValue() {
    // 요청 스케일 고정
    // - 시간대별(일): 0~5,000 (1,000 단위)
    // - 일자별(주): 0~50,000 (10,000 단위)
    // - 월별(월): 0~500,000 (100,000 단위)
    if (selectedPeriod == '일') return 5000;
    if (selectedPeriod == '주') return 50000;
    return 500000;
  }

  List<int> _buildYAxisTicks() {
    final cap = _chartMaxValue();
    final step = (cap / 5).round();
    return List<int>.generate(6, (i) => math.max(0, cap - (step * i)));
  }

  List<String> _buildYAxisDisplayLabels() {
    final fmt = NumberFormat('#,###');
    return _buildYAxisTicks().map((e) => fmt.format(e)).toList();
  }

  String _yAxisUnitLabel() => '(보)';

  List<String> _buildXAxisLabels() {
    if (selectedPeriod == '일') {
      const visibleSlots = 12;
      const maxStart = 48 - visibleSlots;
      final startIndex = (timeOffset * maxStart).round().clamp(0, maxStart);
      return List<String>.generate(7, (i) {
        final hour = ((startIndex + (i * 2)) ~/ 2).toString().padLeft(2, '0');
        return hour;
      });
    }
    if (selectedPeriod == '월') {
      const visibleMonths = 7;
      const totalMonths = 12;
      const maxStart = totalMonths - visibleMonths;
      final startIndex = (timeOffset * maxStart).round().clamp(0, maxStart);
      return List<String>.generate(visibleMonths, (i) => '${startIndex + i + 1}');
    }
    return _buildPeriodChartData().map((item) => item.label).toList();
  }

  List<_StepsBarData> _buildVisibleChartData(List<_StepsBarData> data) {
    if (selectedPeriod == '일') {
      const visibleSlots = 12;
      final maxStart = data.length - visibleSlots;
      final startIndex = (timeOffset * maxStart).round().clamp(0, maxStart);
      return data.sublist(startIndex, startIndex + visibleSlots);
    }
    if (selectedPeriod == '월') {
      const visibleMonths = 7;
      final maxStart = data.length - visibleMonths;
      final startIndex = (timeOffset * maxStart).round().clamp(0, maxStart);
      return data.sublist(startIndex, startIndex + visibleMonths);
    }
    return data;
  }

  Widget _buildXAxisLabelRow(List<String> labels) {
    final unit = selectedPeriod == '일'
        ? '(시)'
        : selectedPeriod == '주'
            ? '(일)'
            : '(월)';
    final children = selectedPeriod == '일'
        ? labels
            .map(
              (label) => Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ),
            )
            .toList()
        : labels
            .map(
              (label) => Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            )
            .toList();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            right: ChartConstants.weightXAxisUnitReservedWidth,
          ),
          child: Row(children: children),
        ),
        Positioned(
          right: -10,
          top: 1,
          bottom: 0,
          child: Align(
            alignment: Alignment.center,
            child: Text(
              unit,
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

  Future<void> _openExpandedChartPage() async {
    await openHealthChartExpandPage(
      context: context,
      periodSelectorBuilder: (_) => HealthPeriodSelector(
        selectedPeriod: selectedPeriod,
        onChanged: (period) {
          setState(() {
            selectedPeriod = period;
            if (period == '일') {
              timeOffset = _isToday() ? _defaultDailyTimeOffset() : 0.0;
            } else if (period == '월') {
              timeOffset = 0.0;
            } else {
              timeOffset = 0.0;
            }
          });
          _notifyExpandedChart();
        },
      ),
      chartBuilder: (_) => LayoutBuilder(
        builder: (context, constraints) {
          final h =
              ChartConstants.healthExpandedChartHeight(constraints.maxHeight);
          return _buildChartCard(showExpandButton: false, chartHeight: h);
        },
      ),
      onRegisterRefresh: (refresh) {
        _refreshExpandedChart = refresh;
      },
      onDisposeRefresh: () {
        _refreshExpandedChart = null;
      },
    );
  }
}

class _StepsGoalRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double trackStrokeWidth;
  final double progressStrokeWidth;

  _StepsGoalRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required double strokeWidth,
    double? progressStrokeWidth,
  })  : trackStrokeWidth = strokeWidth,
        progressStrokeWidth = progressStrokeWidth ?? strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final trackW = trackStrokeWidth;
    final progressW = progressStrokeWidth;
    final maxW = math.max(trackW, progressW);
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - maxW / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackW
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = progressW
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, track);

    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;

    /// 12시 방향에서 **반시계** 방향으로 채움
    final sweep = -math.pi * 2 * p;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _StepsGoalRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackStrokeWidth != trackStrokeWidth ||
        oldDelegate.progressStrokeWidth != progressStrokeWidth;
  }
}

class _StepsBarData {
  final String label;
  final int value;

  const _StepsBarData({
    required this.label,
    required this.value,
  });
}

class _StepsBarChartPainter extends CustomPainter {
  final List<_StepsBarData> data;
  final int maxValue;
  final int yTickCount;
  final double barWidth;

  const _StepsBarChartPainter({
    required this.data,
    required this.maxValue,
    required this.yTickCount,
    required this.barWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const topPadding = 20.0;
    const bottomPadding = 20.0;
    const rightPadding = ChartConstants.weightXAxisUnitReservedWidth;
    final chartWidth = size.width - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;
    final barPaint = Paint()
      ..color = const Color(0xFFFF5A8D)
      ..style = PaintingStyle.fill;

    final segments = math.max(yTickCount - 1, 1);
    for (int i = 0; i <= segments; i++) {
      final y = topPadding + chartHeight * i / segments;
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
    }

    final slotWidth = chartWidth / data.length;
    final scaleMax = maxValue <= 0 ? 1 : maxValue;
    for (int i = 0; i < data.length; i++) {
      final factor = (data[i].value / scaleMax).clamp(0.0, 1.0);
      final barHeight =
          math.max(chartHeight * factor, data[i].value > 0 ? 4.0 : 0.0);
      if (barHeight == 0) continue;

      final x = slotWidth * i + (slotWidth - barWidth) / 2;
      final y = topPadding + chartHeight - barHeight;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        topLeft: const Radius.circular(10),
        topRight: const Radius.circular(10),
        bottomLeft: Radius.zero,
        bottomRight: Radius.zero,
      );
      canvas.drawRRect(rect, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StepsBarChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.yTickCount != yTickCount ||
        oldDelegate.barWidth != barWidth;
  }
}

Widget _buildStepsYAxisStrip({
  required List<String> labels,
  required String unitLabel,
}) {
  return SizedBox(
    width: ChartConstants.weightChartYAxisWidth,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _stepsYAxisUnitBandHeight,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Text(
              unitLabel,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const topPad = 20.0;
              const bottomPad = 20.0;
              final h = constraints.maxHeight - topPad - bottomPad;
              return Stack(
                clipBehavior: Clip.none,
                children: labels.asMap().entries.map((entry) {
                  final i = entry.key;
                  final y = topPad + h * i / (labels.length - 1);
                  return Positioned(
                    top: y - 7,
                    left: 0,
                    right: 0,
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    ),
  );
}
