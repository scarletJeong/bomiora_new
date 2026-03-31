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

      final results = await Future.wait([
        StepsRepository.getStepsRecordByMbId(user.id, selectedDate),
        StepsRepository.getStepsStatisticsByMbId(user.id),
        HealthGoalRepository.fetchLatest(user.id).catchError((_) => null),
      ]);

      setState(() {
        currentUser = user;
        todayStepsRecord = results[0] as StepsRecord?;
        stepsStatistics = results[1] as StepsStatistics?;
        latestHealthGoal = results[2] as HealthGoalRecordModel?;
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: isLoading ? null : _loadData,
          ),
        ],
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
                  const SizedBox(height: 20),
                  _buildTotalStepsCard(),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          title: '거리',
                          unitSmall: '(km)',
                          icon: Icons.directions_walk,
                          value: ((todayStepsRecord?.totalSteps ?? 0) * 0.0007)
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
                          value: (((todayStepsRecord?.totalSteps ?? 0) * 0.04))
                              .toStringAsFixed(0),
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
                child: Center(
                  child: SizedBox(
                    width: 160,
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 150,
                          height: 150,
                          child: CircularProgressIndicator(
                            value: 1,
                            strokeWidth: 14,
                            color: const Color(0x7FD9D9D9),
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          height: 150,
                          child: CircularProgressIndicator(
                            value: ratio,
                            strokeWidth: 14,
                            color: const Color(0xFFFF5A8D),
                            backgroundColor: Colors.transparent,
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
              Expanded(
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
      padding: const EdgeInsets.all(10),
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
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF2F8),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Icon(icon, size: 16, color: const Color(0xFFFF5A8D)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFFFF5A8D),
                  fontSize: 26,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                valueUnit,
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 12,
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

  Widget _buildChartCard({bool showExpandButton = true}) {
    return Stack(
      children: [
        Container(
          height: ChartConstants.healthChartHeight,
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

              return Column(
                children: [
                  const SizedBox(height: _stepsYAxisUnitBandHeight),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: selectedPeriod == '일' || selectedPeriod == '월'
                          ? (details) {
                              final next = timeOffset -
                                  (details.delta.dx /
                                      math.max(constraints.maxWidth, 1)) *
                                      (selectedPeriod == '일' ? 2.4 : 1.8);
                              setState(() {
                                timeOffset = _clampTimeOffset(next);
                              });
                              _notifyExpandedChart();
                            }
                          : null,
                      child: CustomPaint(
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
                        size: Size(
                          double.infinity,
                          constraints.maxHeight - _stepsYAxisUnitBandHeight - 26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildXAxisLabelRow(labels),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<_StepsBarData> _buildPeriodChartData() {
    if (selectedPeriod == '일') {
      return List<_StepsBarData>.generate(48, (i) {
        final hour = i ~/ 2;
        final minute = i.isEven ? '00' : '30';
        final value = switch (i) {
          24 => 600,
          25 => 1000,
          26 => 3000,
          _ => 0,
        };
        return _StepsBarData(label: '$hour:$minute', value: value);
      });
    }

    if (selectedPeriod == '주') {
      final base = stepsStatistics?.weeklyAverage ?? todayStepsRecord?.totalSteps ?? 3000;
      const labels = ['월', '화', '수', '목', '금', '토', '일'];
      return List<_StepsBarData>.generate(
        7,
        (i) => _StepsBarData(
          label: labels[i],
          value: (base * (0.68 + (i * 0.08))).round(),
        ),
      );
    }

    final base =
        stepsStatistics?.monthlyAverage ?? todayStepsRecord?.totalSteps ?? 4000;
    return List<_StepsBarData>.generate(
      12,
      (i) => _StepsBarData(
        label: '${i + 1}',
        value: (base * (0.55 + ((i % 6) * 0.07) + (i ~/ 6) * 0.12)).round(),
      ),
    );
  }

  int _chartMaxValue() {
    if (selectedPeriod == '일') return 5000;
    if (selectedPeriod == '주') return 50000;
    return 500000;
  }

  List<int> _buildYAxisTicks() {
    if (selectedPeriod == '일') {
      return const [5000, 4000, 3000, 2000, 1000, 0];
    }
    return const [5, 4, 3, 2, 1, 0];
  }

  List<String> _buildYAxisDisplayLabels() {
    return _buildYAxisTicks().map((e) => '$e').toList();
  }

  String _yAxisUnitLabel() {
    if (selectedPeriod == '일') return '(보)';
    if (selectedPeriod == '주') return '(만보)';
    return '(10만보)';
  }

  List<String> _buildXAxisLabels() {
    if (selectedPeriod == '일') {
      const visibleSlots = 12;
      final maxStart = 48 - visibleSlots;
      final startIndex = (timeOffset * maxStart).round().clamp(0, maxStart);
      return List<String>.generate(7, (i) {
        final hour = ((startIndex + (i * 2)) ~/ 2).toString().padLeft(2, '0');
        return hour;
      });
    }
    if (selectedPeriod == '월') {
      const visibleMonths = 7;
      const totalMonths = 12;
      final maxStart = totalMonths - visibleMonths;
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
      chartBuilder: (_) => _buildChartCard(showExpandButton: false),
      onRegisterRefresh: (refresh) {
        _refreshExpandedChart = refresh;
      },
      onDisposeRefresh: () {
        _refreshExpandedChart = null;
      },
    );
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
    if (data.isEmpty || maxValue <= 0) return;

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
    for (int i = 0; i < data.length; i++) {
      final factor = (data[i].value / maxValue).clamp(0.0, 1.0);
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
