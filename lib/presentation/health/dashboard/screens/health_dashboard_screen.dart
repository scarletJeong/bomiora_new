import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/appbar_menutap.dart';
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
import '../../../../data/repositories/health/health_goal/health_goal_repository.dart';
import '../../../../data/models/health/health_goal_record_model.dart';
import '../../weight/screens/weight_list_screen.dart';
import '../../weight/utils/weight_goal_progress.dart';
import 'health_connect_screen.dart';
import 'health_goal_screen.dart';
import '../widgets/today_healthrecord_widgets.dart';
import '../widgets/today_meal_widgets.dart';
import '../../health_common/health_responsive_scale.dart';
import '../../health_common/widgets/health_date_selector.dart';
import '../../../common/widgets/login_required_dialog.dart';
import '../../../common/widgets/navi_bar.dart';

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
  HealthGoalRecordModel? latestHealthGoal;

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
  num totalOther = 0;

  int steps = 6320;
  int heartRate = 0;
  int systolicBP = 0;
  int diastolicBP = 0;

  final Map<String, int> mealCalories = {
    'Breakfast': 0,
    'Lunch': 0,
    'Dinner': 0,
    'Snack': 0,
  };

  final Map<String, List<String>> mealImagePaths = {
    'Breakfast': const [],
    'Lunch': const [],
    'Dinner': const [],
    'Snack': const [],
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool showBlockingLoader = true}) async {
    if (showBlockingLoader) {
      setState(() => isLoading = true);
    }

    try {
      final user = await AuthService.getUser();

      if (user == null) {
        setState(() {
          currentUser = null;
          latestWeightRecord = null;
          latestBloodPressureRecord = null;
          latestBloodSugarRecord = null;
          latestMenstrualCycleRecord = null;
          latestHeartRateRecord = null;
          latestStepsRecord = null;
          latestHealthGoal = null;
          currentWeight = 0.0;
          height = 170.0;
          bmi = 0.0;
          consumedCalories = 0;
          totalCarbs = 0;
          totalProtein = 0;
          totalFat = 0;
          totalOther = 0;
          mealCalories['Breakfast'] = 0;
          mealCalories['Lunch'] = 0;
          mealCalories['Dinner'] = 0;
          mealCalories['Snack'] = 0;
          mealImagePaths['Breakfast'] = const [];
          mealImagePaths['Lunch'] = const [];
          mealImagePaths['Dinner'] = const [];
          mealImagePaths['Snack'] = const [];
          steps = 0;
          heartRate = 0;
          systolicBP = 0;
          diastolicBP = 0;
          isLoading = false;
        });
        return;
      }

      final userId = user.id.toString();

      final results = await Future.wait([
        WeightRepository.getWeightRecords(userId)
            .catchError((_) => <WeightRecord>[]),
        BloodPressureRepository.getBloodPressureRecords(userId)
            .catchError((_) => <BloodPressureRecord>[]),
        BloodSugarRepository.getBloodSugarRecords(userId)
            .catchError((_) => <BloodSugarRecord>[]),
        HeartRateRepository.getHeartRateRecords(userId)
            .catchError((_) => <HeartRateRecord>[]),
        MenstrualCycleRepository.getLatestMenstrualCycleRecord(userId)
            .catchError((_) => null),
        StepsRepository.getStepsRecordByMbId(userId, selectedDate)
            .catchError((_) => null),
        HealthGoalRepository.fetchLatest(userId).catchError((_) => null),
      ]);

      final weightRecords = results[0] as List<WeightRecord>;
      final bpRecords = results[1] as List<BloodPressureRecord>;
      final sugarRecords = results[2] as List<BloodSugarRecord>;
      final heartRateRecords = results[3] as List<HeartRateRecord>;
      final menstrualCycleRecord = results[4] as MenstrualCycleRecord?;
      final stepsRecord = results[5] as StepsRecord?;
      final healthGoal = results[6] as HealthGoalRecordModel?;
      // 선택한 날짜에 측정 기록이 있을 때만 사용 (다른 날의 최신 체중으로 채우지 않음)
      final WeightRecord? weightRecord = _latestOfDate(
        weightRecords,
        (e) => e.measuredAt,
      );
      final bloodPressureRecord = _latestOfDate(bpRecords, (e) => e.measuredAt);
      final bloodSugarRecord = _latestOfDate(sugarRecords, (e) => e.measuredAt);
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
        latestHealthGoal = healthGoal;

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
        totalOther = foodRecords.fold<num>(0, (sum, r) => sum + (r.other ?? 0));
        mealImagePaths.updateAll((_, __) => <String>[]);
        final breakfast = FoodRepository.recordForMealKey(foodRecords, '아침');
        final lunch = FoodRepository.recordForMealKey(foodRecords, '점심');
        final dinner = FoodRepository.recordForMealKey(foodRecords, '저녁');
        final snack = FoodRepository.recordForMealKey(foodRecords, '간식');
        mealCalories['Breakfast'] = breakfast?.calories ?? 0;
        mealCalories['Lunch'] = lunch?.calories ?? 0;
        mealCalories['Dinner'] = dinner?.calories ?? 0;
        mealCalories['Snack'] = snack?.calories ?? 0;
        mealImagePaths['Breakfast'] = breakfast?.imagePaths ?? const [];
        mealImagePaths['Lunch'] = lunch?.imagePaths ?? const [];
        mealImagePaths['Dinner'] = dinner?.imagePaths ?? const [];
        mealImagePaths['Snack'] = snack?.imagePaths ?? const [];

        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 선택한 날짜와 같은 날 기록만 남기고, measuredAt 기준 가장 최신 1건.
  T? _latestOfDate<T>(
    List<T> records,
    DateTime Function(T) getDateTime,
  ) {
    final sameDayRecords =
        records.where((r) => _isSameDay(getDateTime(r), selectedDate)).toList();
    if (sameDayRecords.isEmpty) return null;
    sameDayRecords.sort((a, b) => getDateTime(b).compareTo(getDateTime(a)));
    return sameDayRecords.first;
  }

  @override
  Widget build(BuildContext context) {
    final textScale = healthTextScaleByWidth(MediaQuery.of(context).size.width);
    return MobileAppLayoutWrapper(
      drawer: AppBarMenuTapDrawer(
        onHealthDashboardTap: () {
          Navigator.pop(context);
        },
      ),
      bottomNavigationBar: const FooterBar(),
      backgroundColor: Colors.white,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
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
                onRefresh: () => _loadData(showBlockingLoader: false),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            height: healthDp(context, 320),
                            child: const ColoredBox(
                              color: Color(0xFFFFACC6),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeaderSection(),
                              SizedBox(
                                  height: _headerToWhiteCardGap(context)),
                              Transform.translate(
                                offset: const Offset(0, -36),
                                child: Container(
                                  margin: const EdgeInsets.only(top: 0),
                                  padding: EdgeInsets.fromLTRB(
                                    healthDp(context, 18),
                                    0,
                                    healthDp(context, 18),
                                    0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(
                                        healthDp(context, 50),
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      HealthDateSelector(
                                        selectedDate: selectedDate,
                                        onDateChanged: (newDate) {
                                          setState(() {
                                            selectedDate = newDate;
                                          });
                                          _loadData();
                                        },
                                        monthTextColor:
                                            const Color(0xFF898686),
                                        selectedTextColor:
                                            const Color(0xFFFF5A8D),
                                        unselectedTextColor:
                                            const Color(0xFFB7B7B7),
                                        iconColor: const Color(0xFF898686),
                                        topGapBase: 10,
                                      ),
                                      SizedBox(
                                          height: healthDp(context, 14)),
                                      _buildBodyMetricsSection(),
                                      SizedBox(
                                          height: healthDp(context, 14)),
                                      TodayMealSection(
                                        consumedCalories: consumedCalories,
                                        targetCalories: targetCalories,
                                        totalCarbs: totalCarbs,
                                        totalProtein: totalProtein,
                                        totalFat: totalFat,
                                        totalOther: totalOther,
                                        mealCalories: mealCalories,
                                        mealImagePaths: mealImagePaths,
                                        selectedDate: selectedDate,
                                        isLoggedIn: currentUser != null,
                                        onAfterDietReturn: () {
                                          if (mounted) _loadData();
                                        },
                                      ),
                                      SizedBox(
                                          height: healthDp(context, 14)),
                                      TodayHealthRecordSection(
                                        isLoggedIn: currentUser != null,
                                        selectedDate: selectedDate,
                                        latestBloodSugarRecord:
                                            latestBloodSugarRecord,
                                        latestBloodPressureRecord:
                                            latestBloodPressureRecord,
                                        latestStepsRecord: latestStepsRecord,
                                        latestHeartRateRecord:
                                            latestHeartRateRecord,
                                        latestMenstrualCycleRecord:
                                            latestMenstrualCycleRecord,
                                        latestHealthGoal: latestHealthGoal,
                                        systolicBP: systolicBP,
                                        diastolicBP: diastolicBP,
                                        steps: steps,
                                        heartRate: heartRate,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// 핑크 헤더 하단과 흰 카드(라운드) 시작 사이 세로 간격.
  ///
  /// 폭 375 근처는 7, 넓어질수록(최대 650) 5에 가깝게 줄여 넓은 화면에서 여백이 과해 보이지 않게 함.
  double _headerToWhiteCardGap(BuildContext context) {
    const double narrow = 375;
    const double wide = 650;
    const double gapAtNarrow = 7;
    const double gapAtWide = 0;
    final w = MediaQuery.sizeOf(context).width.clamp(narrow, wide);
    final t = (w - narrow) / (wide - narrow);
    return gapAtNarrow + (gapAtWide - gapAtNarrow) * t;
  }

  Widget _buildProfileAvatar(BuildContext context) {
    final size = healthDp(context, 62);
    final profile = currentUser?.profileImage?.trim();
    if (profile != null && profile.isNotEmpty) {
      final url = ImageUrlHelper.getImageUrl(profile);
      if (url.isNotEmpty) {
        return Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildProfileAvatarPlaceholder(context),
        );
      }
    }
    return _buildProfileAvatarPlaceholder(context);
  }

  Widget _buildProfileAvatarPlaceholder(BuildContext context) {
    return SvgPicture.asset(
      AppAssets.mypagePhotoProfileIcon,
      width: healthDp(context, 62),
      height: healthDp(context, 62),
      fit: BoxFit.cover,
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 27),
        healthDp(context, 20),
        healthDp(context, 27),
        healthDp(context, 35),
      ),
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
                    width: healthDp(context, 62),
                    height: healthDp(context, 62),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.35),
                      border: Border.all(
                        color: Colors.white,
                        width: healthDp(context, 2),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildProfileAvatar(context),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: healthDp(context, 20),
                      height: healthDp(context, 20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add,
                        size: healthDp(context, 14),
                        color: const Color(0xFFFF5A8D),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: healthDp(context, 10)),
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
                        letterSpacing: -0.9,
                      ),
                    ),
                    Text(
                      '${currentUser?.name ?? '-'}님 !',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Gmarket Sans TTF',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox.shrink(),
            ],
          ),
          _buildWeightProgressBar(),
          SizedBox(height: healthDp(context, 8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () async {
                  if (currentUser == null) {
                    await showLoginRequiredDialog(
                      context,
                      message: '건강 대시보드 입력은 로그인 후 이용할 수 있습니다.',
                    );
                    return;
                  }
                  final saved = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HealthGoalScreen(),
                    ),
                  );
                  if (!mounted) return;
                  if (saved == true) _loadData();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white70),
                  foregroundColor: Colors.white,
                  minimumSize: Size(0, healthDp(context, 20)),
                  fixedSize: Size.fromHeight(healthDp(context, 20)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 8),
                    vertical: healthDp(context, 6),
                  ),
                  visualDensity:
                      const VisualDensity(horizontal: -2, vertical: -2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('목표수정 >',
                    style: TextStyle(
                        fontSize: 8,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _openHealthConnectScreen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5A8D),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: Size(0, healthDp(context, 20)),  
                  fixedSize: Size.fromHeight(healthDp(context, 20)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 8),
                    vertical: healthDp(context, 6),
                  ),
                  visualDensity:
                      const VisualDensity(horizontal: -2, vertical: -2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('연동하기 >',
                    style: TextStyle(
                        fontSize: 8,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 목표 체중 진행 바 (좌: 목표설정 시점에 저장된 체중, 우: 목표 체중, 채움은 실제 현재 체중 기준 진행)
  Widget _buildWeightProgressBar() {
    final double? goalTgt = latestHealthGoal?.targetWeight;
    final double? anchor = latestHealthGoal?.currentWeight;
    final double leftLabelWeight =
        (goalTgt != null && anchor != null && anchor > 0)
            ? anchor
            : currentWeight;
    final double ratio = goalTgt != null
        ? weightTowardGoalRatio(currentWeight, goalTgt, anchor)
        : 0.0;
    final int diff =
        goalTgt != null ? (leftLabelWeight - currentWeight).round() : 0;
    final String rightLabel = goalTgt != null
        ? (goalTgt == goalTgt.roundToDouble()
            ? '${goalTgt.toInt()}kg'
            : '${goalTgt.toStringAsFixed(1)}kg')
        : '--- kg';

    return LayoutBuilder(
      builder: (context, constraints) {
        final double barHeight = healthDp(context, 8);
        final double arrowTipWidth = healthDp(context, 8);
        final double bubbleWidth = healthDp(context, 40);
        final double bubbleTopSpace = healthDp(context, 24);
        final double markerX = constraints.maxWidth * ratio;
        final double bubbleLeft = (markerX - bubbleWidth / 2).clamp(
          0.0,
          (constraints.maxWidth - bubbleWidth).clamp(0.0, double.infinity),
        );
        final double fillWidthFactor =
            ((bubbleLeft + bubbleWidth / 2) / constraints.maxWidth)
                .clamp(0.0, 1.0);
        final double fillWidth = (constraints.maxWidth * fillWidthFactor)
            .clamp(0.0, constraints.maxWidth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: bubbleTopSpace + barHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: bubbleTopSpace,
                    left: 0,
                    right: 0,
                    child: Container(
                      width: double.infinity,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                  if (goalTgt != null && currentWeight > 0)
                    Positioned(
                      top: bubbleTopSpace,
                      left: 0,
                      child: SizedBox(
                        width: fillWidth,
                        height: barHeight,
                        child: CustomPaint(
                          painter: _WeightBarArrowPainter(
                            color: const Color(0xFFFF5A8D),
                            barHeight: barHeight,
                            arrowTipWidth: arrowTipWidth,
                          ),
                          size: Size(fillWidth, barHeight),
                        ),
                      ),
                    ),
                  if (goalTgt != null && currentWeight > 0)
                    Positioned(
                      left: bubbleLeft,
                      top: 3,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: healthDp(context, 4),
                              vertical: healthDp(context, 2),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: healthDp(context, 6),
                                  offset: Offset(0, healthDp(context, 2)),
                                ),
                              ],
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
                          Transform.translate(
                            offset: Offset(0, -healthDp(context, 2)),
                            child: CustomPaint(
                              size: Size(
                                  healthDp(context, 12), healthDp(context, 6)),
                              painter: _BubbleDownTailPainter(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: healthDp(context, 4)),
            // 체중 프로그레스 바 체중 표시 텍스트
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    leftLabelWeight > 0
                        ? (leftLabelWeight == leftLabelWeight.roundToDouble()
                            ? '${leftLabelWeight.toInt()}kg'
                            : '${leftLabelWeight.toStringAsFixed(1)}kg')
                        : '--- kg',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w400,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    rightLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w400,
                      fontSize: 11,
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
    if (currentUser == null) {
      showLoginRequiredDialog(
        context,
        message: '건강 대시보드 입력은 로그인 후 이용할 수 있습니다.',
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HealthConnectScreen(),
      ),
    );
  }

  Widget _buildBodyMetricsSection() {
    // 당일 기록이 없으면 단위/플레이스홀더 표시 (다른 날 데이터로 채우지 않음)
    final String heightValue = latestWeightRecord == null
        ? '- cm'
        : '${height.toStringAsFixed(1)}cm';
    final String weightValue = latestWeightRecord == null
        ? '- kg'
        : '${currentWeight.toStringAsFixed(1)}kg';
    final String bmiValue =
        latestWeightRecord == null ? '- - -' : bmi.toStringAsFixed(2);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
      child: Row(
        children: [
          Expanded(child: _buildMetricCard('키', heightValue)),
          SizedBox(width: healthDp(context, 12)),
          Expanded(child: _buildMetricCard('체중', weightValue)),
          SizedBox(width: healthDp(context, 12)),
          Expanded(child: _buildMetricCard('BMI', bmiValue)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value) {
    return GestureDetector(
      onTap: () async {
        if (title == '키' || title == '체중' || title == 'BMI') {
          if (currentUser == null) {
            await showLoginRequiredDialog(
              context,
              message: '건강 대시보드 입력은 로그인 후 이용할 수 있습니다.',
            );
            return;
          }
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
        height: healthDp(context, 28),
        padding: EdgeInsets.symmetric(horizontal: healthDp(context, 8)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Gmarket Sans TTF',
                color: Color(0xFF303030),
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'Gmarket Sans TTF',
                color: Colors.black,
                fontWeight: FontWeight.w300,
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
                decorationColor: Colors.black,
                decorationThickness: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 체중 차이 말풍선: 아래로 향하는 뾰족한 꼬리
class _BubbleDownTailPainter extends CustomPainter {
  final Color color;

  _BubbleDownTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BubbleDownTailPainter oldDelegate) {
    return oldDelegate.color != color;
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
      ..arcTo(leftCapRect, math.pi, -math.pi / 2, false) // (0,r)->(r,0) 위쪽 호
      ..lineTo(r, h)
      ..arcTo(
          leftCapRect, -math.pi / 2, -math.pi / 2, false) // (r,h)->(0,r) 아래쪽 호
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
