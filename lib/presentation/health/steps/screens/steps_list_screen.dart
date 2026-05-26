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
import '../utils/step_calculator.dart';
import '../widgets/steps_chart_tooltip.dart';
import '../../health_common/health_chart_axis_style.dart';
import '../../health_common/health_responsive_scale.dart';
import '../../blood_pressure/widgets/blood_pressure_chart_section.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../health_common/widgets/health_chart_expand_control.dart';
import '../../health_common/widgets/health_chart_expand_page.dart';
import '../../health_common/widgets/health_expanded_chart_layout.dart';
import '../../health_common/widgets/health_date_selector.dart';
import '../../health_common/widgets/health_period_selector.dart';

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
        StepsRepository.getStepsMonthlyTotalsForYear(
            user.id, selectedDate.year),
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
    final startSlot = (currentSlot - 10).clamp(0, maxStartSlot);
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
        final maxOffset =
            ((currentSlot - 10).clamp(0, maxStartSlot)) / maxStartSlot;
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

    // 링 지름 375 기준 188 — CustomPaint도 동일 크기
    final ringSize = healthDp(context, 188);
    final strokeW = healthDp(context, 18);
    return Container(
      padding: EdgeInsets.only(left: healthDp(context, 16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Expanded 안에 두면 flex 3/5 폭(~173dp)에 링이 갇혀 실제로는 안 커짐
              Transform.translate(
                offset: Offset(-healthDp(context, 18), 0),
                child: SizedBox(
                  width: ringSize,
                  height: ringSize,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      CustomPaint(
                        size: Size(ringSize, ringSize),
                        painter: _StepsGoalRingPainter(
                          progress: ratio,
                          trackColor: const Color(0x7FD9D9D9),
                          progressColor: const Color(0xFFFF5A8D),
                          strokeWidth: strokeW,
                          progressStrokeWidth: strokeW,
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(0, -healthDp(context, 4)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '총 걸음 수',
                              style: TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontSize: 20,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            SizedBox(height: healthDp(context, 2)),
                            Text(
                              NumberFormat('#,###').format(totalSteps),
                              style: const TextStyle(
                                color: Color(0xFFFF5A8D),
                                fontSize: 32,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          '목표 걸음수',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: const Color(0xFF1A1A1A),
                            fontSize: healthSp(context, 20),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: healthDp(context, 5)),
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
                    SizedBox(height: healthDp(context, 20)),
                    const Text(
                      '전날 대비',
                      style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 20,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    SizedBox(height: healthDp(context, 6)),
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
                          SizedBox(width: healthDp(context, 4)),
                          SizedBox(
                            width: healthDp(context, 16),
                            height: healthDp(context, 16),
                            child: SvgPicture.asset(
                              diffUp
                                  ? AppAssets.stepsUp
                                  : AppAssets.stepsDown,
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
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String unitSmall,
    required String iconAsset,
    required String value,
    required String valueUnit,
  }) {
    return SizedBox(
      height: healthDp(context, 85),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 10),
          vertical: healthDp(context, 8),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
          border: Border.all(
            width: healthDp(context, 0.5),
            color: const Color(0xFFD9D9D9),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          height: 1.0,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      Text(
                        unitSmall,
                        style: const TextStyle(
                          color: Color(0xFF898686),
                          fontSize: 10,
                          height: 1.0,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: healthDp(context, 30),
                  height: healthDp(context, 30),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF2F8),
                    borderRadius: BorderRadius.circular(healthDp(context, 9999)),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      iconAsset,
                      width: healthDp(context, 16),
                      height: healthDp(context, 16),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFFFF5A8D),
                    fontSize: 20,
                    height: 1.0,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: healthDp(context, 5)),
                Text(
                  valueUnit,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 12,
                    height: 1.0,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({
    bool showExpandButton = true,
    bool chartPeriodTabsInCard = true,
    bool forExpandedChart = false,
    double? chartHeight,
  }) {
    final h =
        chartHeight ?? healthDp(context, ChartConstants.weightChartHeight);
    final showYHeader = _buildYAxisTicks().length > 1;
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
        Container(
          height: h,
          padding: forExpandedChart
              ? EdgeInsets.zero
              : healthChartCardPadding(context),
          decoration: forExpandedChart
              ? null
              : BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(healthDp(context, 12)),
                  border: Border.all(color: Colors.grey[200]!),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (chartPeriodTabsInCard && !forExpandedChart) ...[
                HealthPeriodSelector(
                  selectedPeriod: selectedPeriod,
                  onChanged: (period) {
                    setState(() {
                      selectedPeriod = period;
                      if (period == '일') {
                        timeOffset =
                            _isToday() ? _defaultDailyTimeOffset() : 0.0;
                      } else if (period == '월') {
                        timeOffset = 0.0;
                      } else {
                        timeOffset = 0.0;
                      }
                    });
                    _notifyExpandedChart();
                  },
                  plainStyle: true,
                ),
                SizedBox(
                    height: healthDp(
                        context, ChartConstants.weightChartTabToPlotGap)),
              ],
              Expanded(
                child: _buildBarChartPlotArea(
                  forExpandedChart: forExpandedChart,
                ),
              ),
              SizedBox(
                height: forExpandedChart
                    ? healthDp(context, 14.23)
                    : healthDp(context, 30),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: healthDp(
                      context,
                      ChartConstants.weightChartYAxisStripWidth,
                    ),
                  ),
                  child: _buildXAxisLabelRow(
                    context,
                    _buildXAxisLabels(),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showExpandButton)
          Positioned(
            top: topExpand,
            right: healthChartCardPadding(context).right,
            child: HealthChartExpandControl(
              onTap: _openExpandedChartPage,
              iconSize: iconSize,
            ),
          ),
      ],
    );
  }

  Widget _buildBarChartPlotArea({bool forExpandedChart = false}) {
    final data = _buildPeriodChartData();
    final maxValue = _chartMaxValue();
    final yTicks = _buildYAxisTicks();
    final yTickDoubles = yTicks.map((e) => e.toDouble()).toList();
    final showYHeader = yTickDoubles.length > 1;
    final headerBand =
        showYHeader ? bloodPressureYAxisUnitBandHeight(context) : 0.0;
    final ySpacing = healthDp(context, ChartConstants.weightChartYAxisPlotGap);
    final barW = healthDp(
      context,
      selectedPeriod == '일'
          ? 8.0
          : selectedPeriod == '월'
              ? 12.0
              : 14.0,
    );
    final chartPadTop = healthWeightChartVertPad(context);
    final chartPadBottom = healthWeightChartBottomPlotPad(context);
    final chartPadRight =
        healthDp(context, ChartConstants.weightXAxisUnitReservedWidth);
    final barCornerR = healthDp(context, 10);
    final minBarH = healthDp(context, 4);

    final visibleData = _buildVisibleChartData(data);
    final forceWhiteBg = selectedPeriod == '일' || selectedPeriod == '월';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildBloodPressureYAxisStrip(
          yLabels: yTickDoubles,
          showYAxisHeader: showYHeader,
          unitLabel: _yAxisUnitLabel(),
          tickFontSize: selectedPeriod == '일' ? 12 : 10,
        ),
        SizedBox(width: ySpacing),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showYHeader) SizedBox(height: headerBand),
              Expanded(
                child: ColoredBox(
                  color: forceWhiteBg ? Colors.white : Colors.transparent,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _clearTooltip,
                    child: LayoutBuilder(
                      builder: (context, plotConstraints) {
                        final plotW = plotConstraints.maxWidth;
                        final plotH = plotConstraints.maxHeight;
                        final contentW =
                            math.max(plotW - chartPadRight, 1.0);

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) {
                            if (visibleData.isEmpty) return;
                            final localX =
                                d.localPosition.dx.clamp(0.0, contentW);
                            final idx = _hitVisibleBarIndex(
                              localX,
                              visibleData.length,
                              contentW,
                            );
                            if (visibleData[idx].value <= 0) {
                              setState(() {
                                _tooltipIndex = null;
                                _tooltipPosition = null;
                              });
                              return;
                            }
                            setState(() {
                              _tooltipIndex = idx;
                              _tooltipPosition = Offset(
                                _visibleBarCenterX(
                                  idx,
                                  visibleData.length,
                                  contentW,
                                ),
                                healthDp(context, 30),
                              );
                            });
                          },
                          onPanUpdate: selectedPeriod == '일' ||
                                  selectedPeriod == '월'
                              ? (details) {
                                  final next = timeOffset -
                                      (details.delta.dx /
                                              math.max(plotW, 1)) *
                                          (selectedPeriod == '일' ? 2.4 : 1.8);
                                  setState(() {
                                    timeOffset = _clampTimeOffset(next);
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
                                  barWidth: barW,
                                  topPadding: chartPadTop,
                                  bottomPadding: chartPadBottom,
                                  rightPadding: chartPadRight,
                                  isDailyHalfHour: selectedPeriod == '일',
                                  dailyStartSlot: selectedPeriod == '일'
                                      ? _dailyStartSlot()
                                      : 0,
                                  barCornerRadius: barCornerR,
                                  minBarHeight: minBarH,
                                  gridStrokeWidth: healthDp(context, 0.5),
                                ),
                                size: Size(plotW, plotH),
                              ),
                              StepsChartTooltip(
                                selectedPeriod: selectedPeriod,
                                data: _tooltipDataForVisible(
                                  visibleData: visibleData,
                                  visibleIndex: _tooltipIndex,
                                ),
                                tooltipPosition: _tooltipPosition,
                                chartWidth: plotW,
                                chartHeight: plotH,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
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

  int _hitVisibleBarIndex(
    double localX,
    int visibleLength,
    double contentWidth,
  ) {
    if (visibleLength <= 1) return 0;
    final safeW = math.max(contentWidth, 1.0);
    if (selectedPeriod == '일') {
      final startParity = _dailyStartSlot().isOdd ? 1 : 0;
      final relHalf = ((localX / safeW) * 7.0 - 0.5) * 2.0;
      return (relHalf - startParity).round().clamp(0, visibleLength - 1);
    }
    return ((localX / safeW) * visibleLength)
        .floor()
        .clamp(0, visibleLength - 1);
  }

  double _visibleBarCenterX(
    int index,
    int visibleLength,
    double contentWidth,
  ) {
    final safeW = math.max(contentWidth, 1.0);
    if (selectedPeriod == '일') {
      final startParity = _dailyStartSlot().isOdd ? 1 : 0;
      final relHalf = startParity + index;
      return safeW * ((0.5 + (relHalf / 2.0)) / 7.0);
    }
    final slotW = safeW / math.max(visibleLength, 1);
    return slotW * (index + 0.5);
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
          label: '${d.day}',
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
    return List<int>.generate(5, (i) => cap - (step * i));
  }

  String _yAxisUnitLabel() => '(보)';

  List<String> _buildXAxisLabels() {
    if (selectedPeriod == '일') {
      final startIndex = _dailyStartSlot();
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
      return List<String>.generate(
          visibleMonths, (i) => '${startIndex + i + 1}');
    }
    return _buildPeriodChartData().map((item) => item.label).toList();
  }

  List<_StepsBarData> _buildVisibleChartData(List<_StepsBarData> data) {
    if (selectedPeriod == '일') {
      const visibleSlots = 12;
      final startIndex = _dailyStartSlot();
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

  int _dailyStartSlot() {
    const visibleSlots = 12;
    const maxStart = 48 - visibleSlots;
    return (timeOffset * maxStart).round().clamp(0, maxStart);
  }

  Widget _buildXAxisLabelRow(BuildContext context, List<String> labels) {
    final unit = selectedPeriod == '일'
        ? '(시)'
        : selectedPeriod == '주'
            ? '(일)'
            : '(월)';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selDay =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final isTodaySel = selDay == today;
    final currentHour = now.hour;

    late final List<Widget> rowChildren;
    if (selectedPeriod == '일') {
      final startIndex = _dailyStartSlot();
      rowChildren = List.generate(7, (i) {
        final hour = (startIndex + (i * 2)) ~/ 2;
        final hourLabel = hour.toString().padLeft(2, '0');
        final isCurrent = isTodaySel && hour == currentHour;
        return Expanded(
          child: Center(
            child: Text(
              hourLabel,
              style: healthChartAxisTickTextStyle(
                context,
                color: isCurrent ? healthChartAxisCurrentHourColor : null,
              ),
            ),
          ),
        );
      });
    } else {
      rowChildren = labels
          .map(
            (label) => Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: healthChartAxisTickTextStyle(context),
              ),
            ),
          )
          .toList();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            right: ChartConstants.weightXAxisUnitReservedWidth,
          ),
          child: Row(children: rowChildren),
        ),
        Positioned(
          right: -10,
          top: 1,
          bottom: 0,
          child: Align(
            alignment: Alignment.center,
            child: Text(
              unit,
              style: healthChartAxisUnitTextStyle(context),
            ),
          ),
        ),
      ],
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
          final scaledChartCap = healthExpandedMetrics(context)
              .d(HealthExpandedChartMetrics.chartHeightWithoutLegend);
          final scaledChartMin = healthDp(context, 160);
          final h = ChartConstants.healthExpandedChartHeight(
            constraints.maxHeight,
            bottomLegendReserve: 0,
            maxChartHeight: scaledChartCap,
            minChartHeight: scaledChartMin,
          );
          return _buildChartCard(
            showExpandButton: false,
            chartPeriodTabsInCard: false,
            forExpandedChart: true,
            chartHeight: h,
          );
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
  final double topPadding;
  final double bottomPadding;
  final double rightPadding;
  final bool isDailyHalfHour;
  final int dailyStartSlot;
  final double barCornerRadius;
  final double minBarHeight;
  final double gridStrokeWidth;

  _StepsBarChartPainter({
    required this.data,
    required this.maxValue,
    required this.yTickCount,
    required this.barWidth,
    this.topPadding = 20,
    this.bottomPadding = 20,
    this.rightPadding = 18,
    this.isDailyHalfHour = false,
    this.dailyStartSlot = 0,
    this.barCornerRadius = 10,
    this.minBarHeight = 4,
    this.gridStrokeWidth = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final chartWidth = size.width - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final barPaint = Paint()
      ..color = const Color(0xFFFF5A8D)
      ..style = PaintingStyle.fill;

    final slotWidth = chartWidth / data.length;
    final scaleMax = maxValue <= 0 ? 1 : maxValue;
    final corner = Radius.circular(barCornerRadius);
    for (int i = 0; i < data.length; i++) {
      final factor = (data[i].value / scaleMax).clamp(0.0, 1.0);
      final barHeight = math.max(
        chartHeight * factor,
        data[i].value > 0 ? minBarHeight : 0.0,
      );
      if (barHeight == 0) continue;

      final xCenter = isDailyHalfHour
          ? chartWidth *
              ((0.5 + (((dailyStartSlot.isOdd ? 1 : 0) + i) / 2.0)) / 7.0)
          : slotWidth * (i + 0.5);
      final x = xCenter - (barWidth / 2);
      final y = topPadding + chartHeight - barHeight;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        topLeft: corner,
        topRight: corner,
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
        oldDelegate.barWidth != barWidth ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.bottomPadding != bottomPadding ||
        oldDelegate.rightPadding != rightPadding ||
        oldDelegate.isDailyHalfHour != isDailyHalfHour ||
        oldDelegate.dailyStartSlot != dailyStartSlot ||
        oldDelegate.barCornerRadius != barCornerRadius ||
        oldDelegate.minBarHeight != minBarHeight ||
        oldDelegate.gridStrokeWidth != gridStrokeWidth;
  }
}
