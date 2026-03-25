import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../common/chart_layout.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../../data/models/health/steps/steps_record_model.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/repositories/health/steps/steps_repository.dart';
import '../../../../data/repositories/health/health_goal/health_goal_repository.dart';
import '../../../../data/models/health/health_goal_record_model.dart';
import '../../../../data/services/auth_service.dart';
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

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      selectedDate = widget.initialDate!;
    }
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
                      setState(() => selectedDate = newDate);
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
                          value: (todayStepsRecord?.distance ?? 0.0)
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
                          value: '${todayStepsRecord?.calories ?? 0}',
                          valueUnit: 'kcal',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                          color: diffUp
                              ? const Color(0xFFFF0000)
                              : const Color(0xFF002BFF),
                        ),
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

  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 4,
            offset: Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 25),
          HealthPeriodSelector(
            selectedPeriod: selectedPeriod,
            onChanged: (period) {
              setState(() => selectedPeriod = period);
            },
          ),
          // 그래프와 기간 선택(일자별/월별) 카드 간격
          const SizedBox(height: 3),
          SizedBox(
            height: ChartConstants.healthChartHeight,
            child: _buildBarChartArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartArea() {
    final data = _buildPeriodChartData();
    final maxValue = data.isEmpty ? 2500 : data.reduce((a, b) => a > b ? a : b);
    final yTicks = _buildYAxisTicks(maxValue);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 36,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '(보)',
                style: TextStyle(
                  color: Color(0xFF898383),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              ...yTicks.reversed.map(
                (v) => Text(
                  '$v',
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, barConstraints) {
                    final maxBar =
                        (barConstraints.maxHeight - 4).clamp(40.0, 600.0);
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(data.length, (index) {
                        final value = data[index];
                        final heightFactor =
                            maxValue == 0 ? 0.0 : value / maxValue;
                        return Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 8,
                              height: (maxBar * heightFactor)
                                  .clamp(4.0, maxBar)
                                  .toDouble(),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF5A8D),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(2.5),
                                  topRight: Radius.circular(2.5),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _buildXAxisLabels(data.length)
                    .map(
                      (label) => Text(
                        label,
                        style: TextStyle(
                          color: label == _buildXAxisLabels(data.length).last
                              ? const Color(0xFFFF5A8D)
                              : const Color(0xFF1A1A1A),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<int> _buildPeriodChartData() {
    if (selectedPeriod == '일') {
      final hourly = List<int>.filled(7, 0);
      final source = todayStepsRecord?.hourlySteps ?? [];
      for (int i = 0; i < 7; i++) {
        final hour = 12 + i;
        final matched = source.where((e) => e.hour == hour);
        hourly[i] = matched.isEmpty ? 0 : matched.first.steps;
      }
      return hourly;
    }
    if (selectedPeriod == '주') {
      final avg = (stepsStatistics?.weeklyAverage ?? 0);
      return List<int>.generate(7, (i) => (avg * (0.75 + (i * 0.05))).round());
    }
    final avg = (stepsStatistics?.monthlyAverage ?? 0);
    return List<int>.generate(7, (i) => (avg * (0.65 + (i * 0.06))).round());
  }

  List<int> _buildYAxisTicks(int maxValue) {
    final roundedTop = (((maxValue / 500).ceil()) * 500).clamp(500, 5000);
    final step = (roundedTop / 5).round();
    return [0, step, step * 2, step * 3, step * 4, roundedTop];
  }

  List<String> _buildXAxisLabels(int count) {
    if (selectedPeriod == '일') {
      return List<String>.generate(count, (i) => '${12 + i}');
    }
    if (selectedPeriod == '주') {
      const labels = ['월', '화', '수', '목', '금', '토', '일'];
      return labels.take(count).toList();
    }
    final now = DateTime.now();
    return List<String>.generate(
      count,
      (i) =>
          DateFormat('M/d').format(now.subtract(Duration(days: count - 1 - i))),
    );
  }
}
