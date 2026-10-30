import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

import '../../../../core/constants/app_assets.dart';

import '../../../common/chart_layout.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../../data/models/health/steps/steps_record_model.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/repositories/health/steps/steps_repository.dart';
import '../../../../data/repositories/health/health_goal/health_goal_repository.dart';
import '../../../../data/models/health/health_goal_record_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../core/health/health_refresh_bus.dart';
import '../../../../core/health/health_refresh_listener.dart';
import '../utils/step_calculator.dart';
import '../widgets/steps_chart_tooltip.dart';
import '../../health_common/health_chart_axis_style.dart';
import '../../health_common/health_chart_metrics.dart';
import '../../health_common/health_responsive_scale.dart';
import '../../blood_pressure/widgets/blood_pressure_chart_section.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../health_common/widgets/health_chart_expand_control.dart';
import '../../health_common/widgets/health_chart_expand_page.dart';
import '../../health_common/widgets/health_expanded_chart_layout.dart';
import '../../health_common/widgets/health_date_selector.dart';
import '../../health_common/widgets/health_period_selector.dart';
part 'steps_list_chart.dart';
part 'steps_list_expand.dart';
part 'steps_list_painters.dart';

class StepsTodayScreen extends StatefulWidget {
  final DateTime? initialDate;
  final StepsRecord? initialStepsRecord;
  final HealthGoalRecordModel? initialHealthGoal;

  const StepsTodayScreen({
    super.key,
    this.initialDate,
    this.initialStepsRecord,
    this.initialHealthGoal,
  });

  @override
  State<StepsTodayScreen> createState() => _StepsTodayScreenState();
}

class _StepsTodayScreenState extends State<StepsTodayScreen>
    with HealthRefreshListener {
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
    todayStepsRecord = widget.initialStepsRecord;
    latestHealthGoal = widget.initialHealthGoal;
    isLoading = todayStepsRecord == null && latestHealthGoal == null;
    timeOffset = _isToday() ? _defaultDailyTimeOffset() : 0.0;
    _loadData();
  }

  @override
  void onHealthDataChanged() {
    if (!healthRefreshIncludes(HealthRefreshDomain.steps)) return;
    _loadData();
  }

  Future<void> _loadData() async {
    final hasPreview = todayStepsRecord != null || latestHealthGoal != null;
    if (!hasPreview) {
      setState(() => isLoading = true);
    }

    try {
      final user = await AuthService.getUser();

      if (user == null) {
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      final end =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final start = end.subtract(const Duration(days: 6));
      final sameAsInitial = widget.initialDate != null &&
          widget.initialDate!.year == selectedDate.year &&
          widget.initialDate!.month == selectedDate.month &&
          widget.initialDate!.day == selectedDate.day;
      final cachedGoal = HealthGoalRepository.peekLatest(user.id);
      final reuseGoal = cachedGoal != null ||
          (sameAsInitial && widget.initialHealthGoal != null);
      final hasHourly = todayStepsRecord != null &&
          (todayStepsRecord!.hourlySteps.isNotEmpty ||
              todayStepsRecord!.halfHourSteps.any((s) => s > 0));

      final results = await Future.wait([
        hasHourly && sameAsInitial
            ? Future.value(todayStepsRecord)
            : StepsRepository.getStepsRecordByMbId(user.id, selectedDate),
        reuseGoal
            ? Future<HealthGoalRecordModel?>.value(
                cachedGoal ?? widget.initialHealthGoal,
              )
            : HealthGoalRepository.fetchLatest(user.id).catchError((_) => null),
        StepsRepository.getStepsDailyRange(user.id, start, end),
        StepsRepository.getStepsMonthlyTotalsForYear(
            user.id, selectedDate.year),
      ]);

      if (!mounted) return;
      setState(() {
        currentUser = user;
        todayStepsRecord = results[0] as StepsRecord?;
        latestHealthGoal = results[1] as HealthGoalRecordModel?;
        weekStepsByDate = Map<String, int>.from(results[2] as Map<String, int>);
        monthSteps12 = List<int>.from(results[3] as List<int>);
        isLoading = false;
      });
    } catch (e, st) {
      debugPrint('StepsTodayScreen._loadData: $e\n$st');
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _setState(VoidCallback fn) => setState(fn);

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

  static const int _dailyVisibleSlotsCard = 12;
  static const int _dailyVisibleSlotsExpanded = 24;
  static const int _dailyHalfHoursPerDay = 48;

  int _dailyVisibleSlots({bool forExpandedChart = false}) =>
      forExpandedChart ? _dailyVisibleSlotsExpanded : _dailyVisibleSlotsCard;

  int _dailyMaxStartSlot({bool forExpandedChart = false}) =>
      _dailyHalfHoursPerDay - _dailyVisibleSlots(forExpandedChart: forExpandedChart);

  int _dailyLeadSlots({bool forExpandedChart = false}) =>
      forExpandedChart ? 20 : 10;

  double _defaultDailyTimeOffset({bool forExpandedChart = false}) {
    final maxStartSlot = _dailyMaxStartSlot(forExpandedChart: forExpandedChart);
    final now = DateTime.now();
    final currentSlot = now.hour * 2 + (now.minute >= 30 ? 1 : 0);
    final startSlot = (currentSlot - _dailyLeadSlots(forExpandedChart: forExpandedChart))
        .clamp(0, maxStartSlot);
    return startSlot / maxStartSlot;
  }

  double _clampTimeOffset(double next, {bool forExpandedChart = false}) {
    if (selectedPeriod == '월') {
      return next.clamp(0.0, 1.0);
    }
    if (selectedPeriod == '일') {
      if (_isToday()) {
        final maxStartSlot =
            _dailyMaxStartSlot(forExpandedChart: forExpandedChart);
        final now = DateTime.now();
        final currentSlot = now.hour * 2 + (now.minute >= 30 ? 1 : 0);
        final maxOffset = ((currentSlot -
                    _dailyLeadSlots(forExpandedChart: forExpandedChart))
                .clamp(0, maxStartSlot)) /
            maxStartSlot;
        return next.clamp(0.0, maxOffset);
      }
      return next.clamp(0.0, 1.0);
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );
    final textScale = healthTextScaleByWidth(MediaQuery.sizeOf(context).width);

    return Theme(
      data: gmarketTheme,
      child: MobileAppLayoutWrapper(
        backgroundColor: Colors.white,
        appBar: HealthAppBar(
          title: '총 걸음 수',
          leadingIconSize: healthDp(context, 24),
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFFFF5A8D)),
                      SizedBox(height: healthDp(context, 16)),
                      const Text(
                        '데이터를 불러오는 중...',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 27),
                    ),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HealthDateSelector(
                        selectedDate: selectedDate,
                        onDateChanged: (newDate) async {
                          setState(() {
                            selectedDate = newDate;
                            if (selectedPeriod == '일') {
                              timeOffset =
                                  _isToday() ? _defaultDailyTimeOffset() : 0.0;
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
                      SizedBox(height: healthDp(context, 20)),
                      _buildTotalStepsCard(),
                      SizedBox(height: healthDp(context, 20)),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              title: '거리',
                              unitSmall: '(km)',
                              iconAsset: AppAssets.stepsDistanceCard,
                              value: (todayStepsRecord != null &&
                                      todayStepsRecord!.distance > 0)
                                  ? todayStepsRecord!.distance
                                      .toStringAsFixed(1)
                                  : StepCalculator.kmFromSteps(
                                          todayStepsRecord?.totalSteps ?? 0)
                                      .toStringAsFixed(1),
                              valueUnit: 'km',
                            ),
                          ),
                          SizedBox(width: healthDp(context, 20)),
                          Expanded(
                            child: _buildSummaryCard(
                              title: '칼로리',
                              unitSmall: '(kcal)',
                              iconAsset: AppAssets.stepsCaloriesCard,
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
                      SizedBox(height: healthDp(context, 20)),
                      _buildChartCard(
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
      ),
    );
  }
}
