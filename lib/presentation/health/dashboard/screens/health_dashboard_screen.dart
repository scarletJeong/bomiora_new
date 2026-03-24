import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/models/health/weight/weight_record_model.dart';
import '../../../../data/models/health/blood_pressure/blood_pressure_record_model.dart';
import '../../../../data/models/health/blood_sugar/blood_sugar_record_model.dart';
import '../../../../data/models/health/menstrual_cycle/menstrual_cycle_model.dart';
import '../../../../data/models/health/heart_rate/heart_rate_record_model.dart';
import '../../../../data/models/health/steps/steps_record_model.dart';
import '../../../../data/repositories/health/weight/weight_repository.dart';
import '../../../../data/repositories/health/blood_pressure/blood_pressure_repository.dart';
import '../../../../data/repositories/health/blood_sugar/blood_sugar_repository.dart';
import '../../../../data/repositories/health/menstrual_cycle/menstrual_cycle_repository.dart';
import '../../../../data/repositories/health/heart_rate/heart_rate_repository.dart';
import '../../../../data/repositories/health/steps/steps_repository.dart';
import '../../../../data/repositories/health/food/food_repository.dart';
import '../../weight/screens/weight_list_screen.dart';
import '../../blood_pressure/screens/blood_pressure_list_screen.dart';
import '../../blood_sugar/screens/blood_sugar_list_screen.dart';
import '../../menstrual_cycle/screens/menstrual_cycle_list_screen.dart';
import '../../heart_rate/screens/heart_rate_list_screen.dart';
import '../../steps/screens/steps_list_screen.dart';
import '../../food/screens/food_list_screen.dart';
import 'health_connect_screen.dart';
import 'health_goal_screen.dart';
import '../../health_common/widgets/health_date_selector.dart';
import '../../health_common/widgets/health_status_label.dart';

class HealthDashboardScreen extends StatefulWidget {
  const HealthDashboardScreen({super.key});

  @override
  State<HealthDashboardScreen> createState() => _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends State<HealthDashboardScreen> {
  UserModel? currentUser;
  WeightRecord? latestWeightRecord;
  BloodPressureRecord? latestBloodPressureRecord;
  BloodSugarRecord? latestBloodSugarRecord;
  MenstrualCycleRecord? latestMenstrualCycleRecord;
  HeartRateRecord? latestHeartRateRecord;
  StepsRecord? latestStepsRecord;

  double targetWeight = 74.0;
  double currentWeight = 0.0;
  double height = 170.0;
  double bmi = 0.0;

  bool isLoading = true;
  DateTime selectedDate = DateTime.now();

  int consumedCalories = 1500;
  int targetCalories = 2000;
  num totalCarbs = 0;
  num totalProtein = 0;
  num totalFat = 0;

  int steps = 6320;
  int heartRate = 96;
  int systolicBP = 0;
  int diastolicBP = 0;

  final Map<String, int> mealCalories = {
    'Breakfast': 0,
    'Lunch': 0,
    'Dinner': 0,
    'Snack': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      final user = await AuthService.getUser();

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login required')),
          );
          Navigator.pop(context);
        }
        return;
      }

      final userId = user.id.toString();
      final intUserId = int.tryParse(userId);

      final results = await Future.wait([
        WeightRepository.getWeightRecords(userId).catchError((_) => <WeightRecord>[]),
        BloodPressureRepository.getBloodPressureRecords(userId)
            .catchError((_) => <BloodPressureRecord>[]),
        BloodSugarRepository.getBloodSugarRecords(userId)
            .catchError((_) => <BloodSugarRecord>[]),
        HeartRateRepository.getHeartRateRecords(userId)
            .catchError((_) => <HeartRateRecord>[]),
        MenstrualCycleRepository.getLatestMenstrualCycleRecord(userId)
            .catchError((_) => null),
        if (intUserId != null)
          StepsRepository.getStepsRecordByDate(intUserId, selectedDate)
              .catchError((_) => null)
        else
          Future.value(null),
      ]);

      final weightRecords = results[0] as List<WeightRecord>;
      final bpRecords = results[1] as List<BloodPressureRecord>;
      final sugarRecords = results[2] as List<BloodSugarRecord>;
      final heartRateRecords = results[3] as List<HeartRateRecord>;
      final menstrualCycleRecord = results[4] as MenstrualCycleRecord?;
      final stepsRecord = results[5] as StepsRecord?;
      final weightRecord = _latestOfDate(weightRecords, (e) => e.measuredAt);
      final bloodPressureRecord =
          _latestOfDate(bpRecords, (e) => e.measuredAt);
      final bloodSugarRecord =
          _latestOfDate(sugarRecords, (e) => e.measuredAt);
      final heartRateRecord =
          _latestOfDate(heartRateRecords, (e) => e.measuredAt);
      final foodRecords = await FoodRepository.getRecordsForDate(
        userId,
        selectedDate,
      );

      setState(() {
        currentUser = user;
        latestWeightRecord = weightRecord;
        latestBloodPressureRecord = bloodPressureRecord;
        latestBloodSugarRecord = bloodSugarRecord;
        latestMenstrualCycleRecord = menstrualCycleRecord;
        latestHeartRateRecord = heartRateRecord;
        latestStepsRecord = stepsRecord;

        if (weightRecord != null) {
          currentWeight = weightRecord.weight;
          height = weightRecord.height ?? 170.0;
          bmi = weightRecord.bmi ?? 0.0;
        } else {
          currentWeight = 0.0;
          height = 170.0;
          bmi = 0.0;
        }

        if (bloodPressureRecord != null) {
          systolicBP = bloodPressureRecord.systolic;
          diastolicBP = bloodPressureRecord.diastolic;
        } else {
          systolicBP = 0;
          diastolicBP = 0;
        }

        heartRate = heartRateRecord?.heartRate ?? 0;
        steps = stepsRecord?.totalSteps ?? 0;

        consumedCalories =
            foodRecords.fold<int>(0, (sum, r) => sum + (r.calories ?? 0));
        totalCarbs = foodRecords.fold<num>(0, (sum, r) => sum + (r.carbs ?? 0));
        totalProtein =
            foodRecords.fold<num>(0, (sum, r) => sum + (r.protein ?? 0));
        totalFat = foodRecords.fold<num>(0, (sum, r) => sum + (r.fat ?? 0));
        mealCalories['Breakfast'] = _recordForMeal(foodRecords, '아침')?.calories ?? 0;
        mealCalories['Lunch'] = _recordForMeal(foodRecords, '점심')?.calories ?? 0;
        mealCalories['Dinner'] = _recordForMeal(foodRecords, '저녁')?.calories ?? 0;
        mealCalories['Snack'] = _recordForMeal(foodRecords, '간식')?.calories ?? 0;

        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  T? _latestOfDate<T>(
    List<T> records,
    DateTime Function(T) getDateTime,
  ) {
    final sameDayRecords =
        records.where((r) => _isSameDay(getDateTime(r), selectedDate)).toList();
    if (sameDayRecords.isEmpty) return null;
    sameDayRecords.sort((a, b) => getDateTime(a).compareTo(getDateTime(b)));
    return sameDayRecords.last;
  }

  FoodRecordSummary? _recordForMeal(
    List<FoodRecordSummary> records,
    String mealKey,
  ) {
    final foodTime = FoodRepository.foodTimeFromMealKey(mealKey).toLowerCase();
    for (final r in records) {
      if (r.foodTime.toLowerCase() == foodTime) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      child: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFFF5A8D)),
                  SizedBox(height: 16),
                  Text('Loading data...'),
                ],
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFFFF5A8D),
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildHeaderSection(),
                    Transform.translate(
                      offset: const Offset(0, -36),
                      child: Container(
                        margin: const EdgeInsets.only(top: 0),
                        padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(44)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HealthDateSelector(
                              selectedDate: selectedDate,
                              onDateChanged: (newDate) {
                                setState(() {
                                  selectedDate = newDate;
                                });
                                _loadData();
                              },
                              monthTextColor: const Color(0xFF898686),
                              selectedTextColor: const Color(0xFFFF5A8D),
                              unselectedTextColor: const Color(0xFFB7B7B7),
                              iconColor: const Color(0xFF898686),
                            ),
                            const SizedBox(height: 18),
                            _buildBodyMetricsSection(),
                            const SizedBox(height: 24),
                            _buildMealSection(),
                            const SizedBox(height: 24),
                            _buildHealthMetricsSection(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 56),
      color: const Color(0xFFFFACC6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.35),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child:
                        const Icon(Icons.person, color: Colors.white, size: 38),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add,
                          size: 14, color: Color(0xFFFF5A8D)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '안녕하세요',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Gmarket Sans TTF',
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    Text(
                      '${currentUser?.name ?? 'User'} !',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Gmarket Sans TTF',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: isLoading ? null : _loadData,
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildWeightProgressBar(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HealthGoalScreen(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white70),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  visualDensity:
                      const VisualDensity(horizontal: -2, vertical: -2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('목표설정',
                    style:
                        TextStyle(fontSize: 10, fontFamily: 'Gmarket Sans TTF', fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _openHealthConnectScreen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5A8D),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  visualDensity:
                      const VisualDensity(horizontal: -2, vertical: -2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('연동하기',
                    style:
                        TextStyle(fontSize: 10, fontFamily: 'Gmarket Sans TTF', fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 목표 체중 진행 바
  Widget _buildWeightProgressBar() {
    final double startWeight =
        (currentWeight > targetWeight ? currentWeight : targetWeight) + 6;
    final double whole = (startWeight - targetWeight).abs() < 0.1
        ? 1
        : (startWeight - targetWeight);
    final double ratio =
        ((startWeight - currentWeight) / whole).clamp(0.0, 1.0);
    final int diff = (currentWeight - targetWeight).round();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double barHeight = 14;
        final double arrowTipWidth = 10;
        const double bubbleWidth = 36;
        final double markerX = constraints.maxWidth * ratio;
        final double bubbleLeft = (markerX - bubbleWidth / 2).clamp(
          0.0,
          (constraints.maxWidth - bubbleWidth).clamp(0.0, double.infinity),
        );
        final double fillWidthFactor =
            ((bubbleLeft + bubbleWidth / 2) / constraints.maxWidth).clamp(0.0, 1.0);
        final double fillWidth = (constraints.maxWidth * fillWidthFactor)
            .clamp(0.0, constraints.maxWidth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Stack(
              clipBehavior: Clip.none,
              children: [
                // 배경 트랙
                Container(
                  width: double.infinity,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                // 화살표 모양 채우기 (왼쪽 둥글게, 오른쪽 뾰족하게)
                SizedBox(
                  width: fillWidth,
                  height: barHeight,
                  child: CustomPaint(
                    painter: _WeightBarArrowPainter(
                      color: Colors.white,
                      barHeight: barHeight,
                      arrowTipWidth: arrowTipWidth,
                    ),
                    size: Size(fillWidth, barHeight),
                  ),
                ),
                // 체중 바 말풍선 
                Positioned(
                  left: bubbleLeft,
                  top: -28,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      diff <= 0 ? '${diff}kg' : '-${diff}kg',
                      style: const TextStyle(
                        color: Color(0xFFFF5A8D),
                        fontFamily: 'Gmarket Sans TTF',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 체중 프로그레스 바 체중 표시 텍스트
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    currentWeight > 0
                        ? (currentWeight == currentWeight.roundToDouble()
                            ? '${currentWeight.toInt()}kg'
                            : '${currentWeight.toStringAsFixed(1)}kg')
                        : '-',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${targetWeight.toStringAsFixed(0)}kg',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _openHealthConnectScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HealthConnectScreen(),
      ),
    );
  }

  Widget _buildBodyMetricsSection() {
    final String heightValue =
        latestWeightRecord == null ? '-' : '${height.toStringAsFixed(1)}cm';
    final String weightValue = latestWeightRecord == null
        ? '-'
        : '${currentWeight.toStringAsFixed(1)}kg';
    final String bmiValue =
        latestWeightRecord == null ? '-' : bmi.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          Expanded(child: _buildMetricCard('키', heightValue)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('체중', weightValue)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('BMI', bmiValue)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value) {
    return GestureDetector(
      onTap: () async {
        if (title == '키' || title == '체중' || title == 'BMI') {
          if (!mounted) return;

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WeightListScreen(initialDate: selectedDate),
            ),
          );

          if (result == true && mounted) {
            _loadData();
          }
        }
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontFamily: 'Gmarket Sans TTF',
                color: Color(0xFF303030),
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'Gmarket Sans TTF',
                color: Color(0xFF707070),
                fontWeight: FontWeight.w300,
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFFB5B5B5),
                decorationThickness: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealSection() {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TodayDietScreen(),
          ),
        );
        if (!mounted) return;
        _loadData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 1,
                      height: 20,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 20, color: Colors.black),
                        children: [
                          TextSpan(
                            text: '오늘의 ',
                            style: TextStyle(fontFamily: 'Gmarket Sans TTF', fontWeight: FontWeight.w300),
                          ),
                          TextSpan(
                            text: '식사',
                            style: TextStyle(fontFamily: 'Gmarket Sans TTF', fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$consumedCalories',
                      style: const TextStyle(
                        color: Color(0xFFFF5A8D),
                        fontSize: 16,
                        fontFamily: 'Gmarket Sans TTF', 
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    Text(
                      ' / $targetCalories kcal',
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 10,
                        fontFamily: 'Gmarket Sans TTF', 
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // 오늘의 식사 - 색상 
            const SizedBox(height: 12),
            _buildMacroBar(),
            const SizedBox(height: 12),
            const Row(
              children: [
                _LegendDot('탄수화물', Color(0xFFFFDFC3)),
                SizedBox(width: 12),
                _LegendDot('단백질', Color(0xFFFEA38E)),
                SizedBox(width: 12),
                _LegendDot('지방', Color(0xFFFCF4C1)),
                SizedBox(width: 12),
                _LegendDot('기타', Color(0xFFE2E2E2)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildMealItemCard(
                        '아침', mealCalories['Breakfast']!, (mealCalories['Breakfast'] ?? 0) > 0,
                        centerText: true)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildMealItemCard(
                        '점심', mealCalories['Lunch']!, (mealCalories['Lunch'] ?? 0) > 0,
                        centerText: true)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildMealItemCard(
                        '저녁', mealCalories['Dinner']!, (mealCalories['Dinner'] ?? 0) > 0)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildMealItemCard(
                  '간식',
                  mealCalories['Snack']!,
                  mealCalories['Snack']! > 0,
                  centerText: true,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBar() {
    final fillRatio = (targetCalories > 0 && consumedCalories > 0)
        ? (consumedCalories / targetCalories).clamp(0.0, 1.0)
        : 0.0;
    final carbsKcal = (totalCarbs * 4).toDouble();
    final proteinKcal = (totalProtein * 4).toDouble();
    final fatKcal = (totalFat * 9).toDouble();
    final totalKcalFromMacros = carbsKcal + proteinKcal + fatKcal;
    int carbsFlex = 1, proteinFlex = 1, fatFlex = 1;
    if (totalKcalFromMacros > 0) {
      carbsFlex =
          (carbsKcal / totalKcalFromMacros * 100).round().clamp(1, 100);
      proteinFlex =
          (proteinKcal / totalKcalFromMacros * 100).round().clamp(1, 100);
      fatFlex = (fatKcal / totalKcalFromMacros * 100).round().clamp(1, 100);
    }
    final filledFlex = (fillRatio * 100).round().clamp(0, 100);
    final emptyFlex = (100 - filledFlex).clamp(1, 100);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            if (filledFlex > 0)
              Expanded(
                flex: filledFlex,
                child: Row(
                  children: [
                    Expanded(
                        flex: carbsFlex,
                        child: Container(color: const Color(0xFFFFDFC3))),
                    Expanded(
                        flex: proteinFlex,
                        child: Container(color: const Color(0xFFFEA38E))),
                    Expanded(
                        flex: fatFlex,
                        child: Container(color: const Color(0xFFFCF4C1))),
                  ],
                ),
              ),
            Expanded(
              flex: emptyFlex,
              child: Container(color: const Color(0xFFE2E2E2)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealItemCard(String mealName, int calories, bool hasMeal,
      {bool centerText = false}) {
    return AspectRatio(
      aspectRatio: 0.75,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEAEAEA)),
          gradient: hasMeal
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFB8B8B8), Color(0xFF6C6C6C)],
                )
              : null,
          color: hasMeal ? null : const Color(0xFFE2E2E2),
        ),
        child: hasMeal
            ? Container(
                padding: const EdgeInsets.all(6),
                alignment: Alignment.bottomCenter,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.black.withOpacity(0.25),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(mealName,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 2),
                    Text(
                      '$calories kcal',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontFamily: 'Gmarket Sans TTF', 
                          fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(mealName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 28,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHealthMetricsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 1,
                height: 20,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 20, color: Colors.black),
                  children: [
                    TextSpan(
                      text: '오늘의 ',
                      style: TextStyle(
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    TextSpan(
                      text: '건강기록',
                      style: TextStyle(
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildRecordCard(
                        title: '혈당',
                        value: latestBloodSugarRecord != null
                            ? '${latestBloodSugarRecord!.bloodSugar.toStringAsFixed(1)} mg/dL'
                            : '입력하세요.',
                        subtitle: latestBloodSugarRecord != null
                            ? BloodSugarRecord.getMeasurementTypeKorean(
                                latestBloodSugarRecord!.measurementType)
                            : '',
                        statusText: _bloodSugarStatusLabel(),
                        icon: Icons.favorite,
                        titleFontSize: 14,
                        valueFontSize: 16,
                        statusFontSize: 9,
                        onMore: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                BloodSugarListScreen(initialDate: selectedDate),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildRecordCard(
                        title: '혈압',
                        value: latestBloodPressureRecord != null
                            ? '수축기 $systolicBP mmHg\n이완기 $diastolicBP mmHg'
                            : '입력하세요.',
                        subtitle: '',
                        statusText: _bloodPressureStatusLabel(),
                        icon: Icons.monitor_heart,
                        titleFontSize: 14,
                        valueFontSize: 12,
                        statusFontSize: 9,
                        onMore: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BloodPressureListScreen(
                                initialDate: selectedDate),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildStepsCard()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildBottomRecordCard(
                  title: '심박수',
                  titleIcon: Icons.access_time,
                  value: latestHeartRateRecord != null
                      ? '$heartRate bpm'
                      : '입력하세요.',
                  titleFontSize: 14,
                  valueFontSize: 16,
                  onMore: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          HeartRateListScreen(initialDate: selectedDate),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBottomRecordCard(
                  title: '생리주기',
                  value: _periodText(),
                  titleFontSize: 14,
                  valueFontSize: 13,
                  onMore: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => MenstrualCycleInfoScreen()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard({
    required String title,
    required String value,
    required String subtitle,
    required String statusText,
    required IconData icon,
    required VoidCallback onMore,
    double titleFontSize = 14,
    double valueFontSize = 12,
    double statusFontSize = 10,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFFFF5A8D)),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Gmarket Sans TTF',
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              _buildMoreButton(onMore),
            ],
          ),
          const SizedBox(height: 10),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: TextStyle(
                color: const Color(0xFF8C8888),
                fontSize: 12,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
                letterSpacing: -1.08,
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: const Color(0xFF6B7280),
                    fontSize: valueFontSize,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                    height: 1.2,
                  ),
                ),
              ),
              HealthStatusLabel(
                label: statusText,
                fontSize: statusFontSize,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepsCard() {
    if (latestStepsRecord == null) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StepsTodayScreen(initialDate: selectedDate),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF0F0F0)),
          ),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '걸음수',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '입력하세요.',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 16,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: _buildMoreButton(() {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          StepsTodayScreen(initialDate: selectedDate),
                    ),
                  );
                }, minHeight: 30, verticalPadding: 8),
              ),
            ],
          ),
        ),
      );
    }

    final double ratio = (steps / 8000).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  StepsTodayScreen(initialDate: selectedDate)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('걸음수',
                  style: TextStyle(fontSize: 16, fontFamily: 'Gmarket Sans TTF', fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 9,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFF3F4F6)),
                  ),
                  CircularProgressIndicator(
                    value: ratio,
                    strokeWidth: 9,
                    color: const Color(0xFFFF5A8D),
                    backgroundColor: Colors.transparent,
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$steps',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF5A8D),
                          ),
                        ),
                        const Text('/8000',
                            style: TextStyle(
                                fontSize: 10, fontFamily: 'Gmarket Sans TTF', fontWeight: FontWeight.w300, color: Color(0xFFD1D5DB))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: _buildMoreButton(() {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          StepsTodayScreen(initialDate: selectedDate)),
                );
              }, minHeight: 34, verticalPadding: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomRecordCard({
    required String title,
    required String value,
    required VoidCallback onMore,
    IconData titleIcon = Icons.favorite_border,
    double titleFontSize = 16,
    double valueFontSize = 20,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(titleIcon, color: const Color(0xFFFF5A8D), size: 18),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      fontSize: titleFontSize, fontFamily: 'Gmarket Sans TTF', fontWeight: FontWeight.w700)),
              const Spacer(),
              _buildMoreButton(onMore),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                color: const Color(0xFF9CA3AF),
                fontSize: valueFontSize,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // more 버튼튼
  Widget _buildMoreButton(
    VoidCallback onPressed, {
    double minHeight = 0,
    double verticalPadding = 6,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF5A8D),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: verticalPadding),
        minimumSize: minHeight > 0 ? Size(0, minHeight) : Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: const Text('+ More',
          style: TextStyle(fontSize: 10, fontFamily: 'Gmarket Sans TTF', fontWeight: FontWeight.w300)),
    );
  }

  // 생리주기 텍스트
  String _periodText() {
    if (latestMenstrualCycleRecord == null) {
      return 'No record';
    }

    final int dday = latestMenstrualCycleRecord!.nextPeriodStart
        .difference(selectedDate)
        .inDays;
    final DateTime lastPeriodEnd = latestMenstrualCycleRecord!.lastPeriodStart
        .add(Duration(days: latestMenstrualCycleRecord!.periodLength - 1));
    final String cycleRange =
        '${DateFormat('M/d').format(latestMenstrualCycleRecord!.lastPeriodStart)}-${DateFormat('M/d').format(lastPeriodEnd)}';

    return '${dday.abs()}일전($cycleRange)';
  }

  /// 혈압 상태 라벨 (HealthStatusLabel용: 정상, 주의, 고혈압, 전단계, 모름)
  String _bloodPressureStatusLabel() {
    if (latestBloodPressureRecord == null) return '모름';
    if (systolicBP >= 140 || diastolicBP >= 90) return '고혈압';
    if (systolicBP < 90 || diastolicBP < 60) return '전단계';
    return '정상';
  }

  /// 혈당 상태 라벨 (HealthStatusLabel용: 정상, 주의, 의심, 모름)
  String _bloodSugarStatusLabel() {
    if (latestBloodSugarRecord == null) return '모름';
    final int sugar = latestBloodSugarRecord!.bloodSugar;
    if (sugar < 70) return '주의';
    if (sugar <= 140) return '정상';
    return '의심';
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendDot(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontFamily: 'Gmarket Sans TTF', fontWeight: FontWeight.w300)),
      ],
    );
  }
}

/// 체중 진행 바 채우기용: 왼쪽 둥글게(반원), 오른쪽 화살표 뾰족하게
/// 왼쪽 캡 / 중간 직사각형 / 화살표 삼각형을 각각 그려서 채움을 보장
class _WeightBarArrowPainter extends CustomPainter {
  final Color color;
  final double barHeight;
  final double arrowTipWidth;

  _WeightBarArrowPainter({
    required this.color,
    required this.barHeight,
    required this.arrowTipWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double r = h / 2;
    if (w <= 0) return;

    final paint = Paint()..color = color;

    if (w <= r * 2) {
      final path = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, w, h),
            Radius.circular(r),
          ),
        );
      canvas.drawPath(path, paint);
      return;
    }

    final tipStart = (w - arrowTipWidth).clamp(r, double.infinity);
    final leftCapRect = Rect.fromLTWH(0, 0, 2 * r, 2 * r);

    // 1) 왼쪽 반원 캡 — 바 맨 끝(x=0)부터 반원으로 완전히 채움
    // 경계: (0,r) -> (r,0) 호 -> (r,h) 직선 -> (r,h)~(0,r) 호 -> (0,r)
    final capPath = Path()
      ..moveTo(0, r)
      ..arcTo(leftCapRect, math.pi, -math.pi / 2, false)   // (0,r)->(r,0) 위쪽 호
      ..lineTo(r, h)
      ..arcTo(leftCapRect, -math.pi / 2, -math.pi / 2, false) // (r,h)->(0,r) 아래쪽 호
      ..close();
    canvas.drawPath(capPath, paint);

    // 2) 중간 직사각형 (x: r ~ tipStart)
    if (tipStart > r) {
      canvas.drawRect(Rect.fromLTWH(r, 0, tipStart - r, h), paint);
    }

    // 3) 오른쪽 화살표 삼각형
    final arrowPath = Path()
      ..moveTo(tipStart, 0)
      ..lineTo(w, h / 2)
      ..lineTo(tipStart, h)
      ..close();
    canvas.drawPath(arrowPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
