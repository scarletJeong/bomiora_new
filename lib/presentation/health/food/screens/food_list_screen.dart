import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/utils/image_url_helper.dart';

import '../../../../data/models/user/user_model.dart';
import '../../../../data/repositories/health/food/food_repository.dart';
import '../../../../data/services/auth_service.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../health_common/health_responsive_scale.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../health_common/widgets/health_date_selector.dart';
import '../widgets/food_input_widgets.dart';

/// 오늘의 식사 화면
class TodayDietScreen extends StatefulWidget {
  const TodayDietScreen({super.key, this.initialDate});

  /// 건강 대시보드 등에서 열 때 해당 날짜로 맞춤
  final DateTime? initialDate;

  @override
  State<TodayDietScreen> createState() => _TodayDietScreenState();
}

class _TodayDietScreenState extends State<TodayDietScreen> {
  late DateTime selectedDate;
  /// 열린 칼로리 검색 블록의 식사 타입 ('아침' | '점심' | '저녁' | '간식'), null이면 모두 닫힘
  String? _expandedMealKey;

  UserModel? _currentUser;
  int totalCalories = 0;
  num totalCarbs = 0;
  num totalProtein = 0;
  num totalFat = 0;
  num totalOther = 0;
  static const int _maxCalories = 2000;
  List<FoodRecordSummary> _dayRecords = [];

  void _toggleFoodSearchFor(String mealKey) {
    setState(() {
      _expandedMealKey = _expandedMealKey == mealKey ? null : mealKey;
    });
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getUser();
    if (!mounted) return;
    setState(() => _currentUser = user);
  }

  void _loadMealData() async {
    final mbId = _currentUser?.id;
    if (mbId == null || mbId.isEmpty) {
      setState(() => _dayRecords = []);
      return;
    }
    final list = await FoodRepository.getRecordsForDate(mbId, selectedDate);
    if (!mounted) return;
    final calories = list.fold<int>(0, (sum, r) => sum + (r.calories ?? 0));
    final carbs = list.fold<num>(0, (sum, r) => sum + (r.carbs ?? 0));
    final protein = list.fold<num>(0, (sum, r) => sum + (r.protein ?? 0));
    final fat = list.fold<num>(0, (sum, r) => sum + (r.fat ?? 0));
    final other = list.fold<num>(0, (sum, r) => sum + (r.other ?? 0));
    setState(() {
      _dayRecords = list;
      totalCalories = calories;
      totalCarbs = carbs;
      totalProtein = protein;
      totalFat = fat;
      totalOther = other;
    });
  }

  FoodRecordSummary? _recordFor(String mealKey) {
    final foodTime = FoodRepository.foodTimeFromMealKey(mealKey).toLowerCase();
    for (final r in _dayRecords) {
      if ((r.foodTime ?? '').toLowerCase() == foodTime) return r;
    }
    return null;
  }

  /// 음식 추가 후: 목록 새로고침 (검색 블록은 열린 채로 두어 추가된 음식 리스트가 바로 보이게)
  void _onFoodItemAdded() {
    _loadMealData();
  }

  @override
  void initState() {
    super.initState();
    final d = widget.initialDate;
    selectedDate = d != null
        ? DateTime(d.year, d.month, d.day)
        : DateTime.now();
    _loadUser().then((_) => _loadMealData());
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: Colors.white,
        appBar: HealthAppBar(
          title: '식사 기록',
          centerTitle: false,
          leadingIconSize: healthDp(context, 24),
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              healthDp(context, 27),
              healthDp(context, 14),
              healthDp(context, 27),
              healthDp(context, 14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HealthDateSelector(
                  selectedDate: selectedDate,
                  onDateChanged: (date) {
                    setState(() => selectedDate = date);
                    _loadMealData();
                  },
                  topGapBase: 0,
                  monthTextColor: const Color(0xFF898686),
                  selectedTextColor: const Color(0xFFFF5A8D),
                  unselectedTextColor: const Color(0xFFB7B7B7),
                  dividerColor: const Color(0xFFD2D2D2),
                  iconColor: const Color(0xFF898686),
                ),
                SizedBox(height: healthDp(context, 14)),
                Center(
                        child: MediaQuery(
                          data: MediaQuery.of(context)
                              .copyWith(textScaler: TextScaler.noScaling),
                          child: Column(
                            children: [
                              Text(
                                '총 섭취 칼로리',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: healthSp(context, 20),
                                  height: 1.0,
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                              SizedBox(height: healthDp(context, 5)),
                              Text(
                                '${NumberFormat('#,###').format(totalCalories)} kcal',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: healthSp(context, 32),
                                  height: 1.0,
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: healthDp(context, 14)),
                      _buildDashboardMacroBar(context),
                      SizedBox(height: healthDp(context, 10)),
                      _buildMacroLegendRow(context),
                      SizedBox(height: healthDp(context, 14)),
                  _buildMealDetailCard(
                    context,
                    title: '아침',
                    kcal: _recordFor('아침')?.calories ?? 0,
                    carb: _recordFor('아침')?.carbs?.toStringAsFixed(1) ?? '-',
                    protein: _recordFor('아침')?.protein?.toStringAsFixed(1) ?? '-',
                    fat: _recordFor('아침')?.fat?.toStringAsFixed(1) ?? '-',
                    other: _recordFor('아침')?.other?.toStringAsFixed(1) ?? '-',
                    mealRecord: _recordFor('아침'),
                    onTap: () => _toggleFoodSearchFor('아침'),
                  ),
                  if (_expandedMealKey == '아침') ...[
                    SizedBox(height: healthDp(context, 5)),
                    CalorieSearchBlock(
                      mealKey: '아침',
                      selectedDate: selectedDate,
                      mbId: _currentUser?.id ?? '',
                      foodRecordId: _recordFor('아침')?.id ?? '',
                      mealImagePath: _recordFor('아침')?.imagePath,
                      addedItems: _recordFor('아침')?.items ?? [],
                      onItemAdded: _onFoodItemAdded,
                    ),
                  ],
                  SizedBox(height: healthDp(context, 14)),
                  _buildMealDetailCard(
                    context,
                    title: '점심',
                    kcal: _recordFor('점심')?.calories ?? 0,
                    carb: _recordFor('점심')?.carbs?.toStringAsFixed(1) ?? '-',
                    protein: _recordFor('점심')?.protein?.toStringAsFixed(1) ?? '-',
                    fat: _recordFor('점심')?.fat?.toStringAsFixed(1) ?? '-',
                    other: _recordFor('점심')?.other?.toStringAsFixed(1) ?? '-',
                    mealRecord: _recordFor('점심'),
                    onTap: () => _toggleFoodSearchFor('점심'),
                  ),
                  if (_expandedMealKey == '점심') ...[
                    SizedBox(height: healthDp(context, 5)),
                    CalorieSearchBlock(
                      mealKey: '점심',
                      selectedDate: selectedDate,
                      mbId: _currentUser?.id ?? '',
                      foodRecordId: _recordFor('점심')?.id ?? '',
                      mealImagePath: _recordFor('점심')?.imagePath,
                      addedItems: _recordFor('점심')?.items ?? [],
                      onItemAdded: _onFoodItemAdded,
                    ),
                  ],
                  SizedBox(height: healthDp(context, 14)),
                  _buildMealDetailCard(
                    context,
                    title: '저녁',
                    kcal: _recordFor('저녁')?.calories ?? 0,
                    carb: _recordFor('저녁')?.carbs?.toStringAsFixed(1) ?? '-',
                    protein: _recordFor('저녁')?.protein?.toStringAsFixed(1) ?? '-',
                    fat: _recordFor('저녁')?.fat?.toStringAsFixed(1) ?? '-',
                    other: _recordFor('저녁')?.other?.toStringAsFixed(1) ?? '-',
                    mealRecord: _recordFor('저녁'),
                    onTap: () => _toggleFoodSearchFor('저녁'),
                  ),
                  if (_expandedMealKey == '저녁') ...[
                    SizedBox(height: healthDp(context, 5)),
                    CalorieSearchBlock(
                      mealKey: '저녁',
                      selectedDate: selectedDate,
                      mbId: _currentUser?.id ?? '',
                      foodRecordId: _recordFor('저녁')?.id ?? '',
                      mealImagePath: _recordFor('저녁')?.imagePath,
                      addedItems: _recordFor('저녁')?.items ?? [],
                      onItemAdded: _onFoodItemAdded,
                    ),
                  ],
                  SizedBox(height: healthDp(context, 14)),
                  _buildMealDetailCard(
                    context,
                    title: '간식',
                    kcal: _recordFor('간식')?.calories ?? 0,
                    carb: _recordFor('간식')?.carbs?.toStringAsFixed(1) ?? '-',
                    protein: _recordFor('간식')?.protein?.toStringAsFixed(1) ?? '-',
                    fat: _recordFor('간식')?.fat?.toStringAsFixed(1) ?? '-',
                    other: _recordFor('간식')?.other?.toStringAsFixed(1) ?? '-',
                    mealRecord: _recordFor('간식'),
                    onTap: () => _toggleFoodSearchFor('간식'),
                  ),
                  if (_expandedMealKey == '간식') ...[
                    SizedBox(height: healthDp(context, 5)),
                    CalorieSearchBlock(
                      mealKey: '간식',
                      selectedDate: selectedDate,
                      mbId: _currentUser?.id ?? '',
                      foodRecordId: _recordFor('간식')?.id ?? '',
                      mealImagePath: _recordFor('간식')?.imagePath,
                      addedItems: _recordFor('간식')?.items ?? [],
                      onItemAdded: _onFoodItemAdded,
                    ),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 칼로리 바: 최대 2000kcal 기준, 탄수화물/단백질/지방 비율로 채움
  Widget _buildDashboardMacroBar(BuildContext context) {
    final fillRatio = (_maxCalories > 0 && totalCalories > 0)
        ? (totalCalories / _maxCalories).clamp(0.0, 1.0)
        : 0.0;
    final carbsKcal = (totalCarbs * 4).toDouble();
    final proteinKcal = (totalProtein * 4).toDouble();
    final fatKcal = (totalFat * 9).toDouble();
    final otherKcal = (totalOther * 4).toDouble();
    final totalKcalFromMacros =
        carbsKcal + proteinKcal + fatKcal + otherKcal;
    int cF = 1, pF = 1, fF = 1, oF = 1;
    if (totalKcalFromMacros > 0) {
      cF = (carbsKcal / totalKcalFromMacros * 100).round().clamp(1, 100);
      pF = (proteinKcal / totalKcalFromMacros * 100).round().clamp(1, 100);
      fF = (fatKcal / totalKcalFromMacros * 100).round().clamp(1, 100);
      oF = (otherKcal / totalKcalFromMacros * 100).round().clamp(1, 100);
    }
    final filledFlex = (fillRatio * 100).round().clamp(0, 100);
    final emptyFlex = (100 - filledFlex).clamp(1, 100);
    final barHeight = healthDp(context, 8);
    final barRadius = BorderRadius.circular(999);

    return SizedBox(
      width: double.infinity,
      height: barHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: barRadius,
          border: Border.all(
            color: const Color(0xCCD2D2D2),
            width: healthDp(context, 0.5),
          ),
        ),
        child: ClipRRect(
          borderRadius: barRadius,
          child: filledFlex > 0
              ? Row(
                  children: [
                    Expanded(
                      flex: filledFlex,
                      child: Row(
                        children: [
                          Expanded(
                            flex: cF,
                            child: Container(color: const Color(0xFFFFDFC3)),
                          ),
                          Expanded(
                            flex: pF,
                            child: Container(color: const Color(0xFFFEA38E)),
                          ),
                          Expanded(
                            flex: fF,
                            child: Container(color: const Color(0xFFFCF4C1)),
                          ),
                          Expanded(
                            flex: oF,
                            child: Container(color: const Color(0xFFD6DEE8)),
                          ),
                        ],
                      ),
                    ),
                    if (emptyFlex > 0)
                      Expanded(
                        flex: emptyFlex,
                        child: const ColoredBox(color: Colors.white),
                      ),
                  ],
                )
              : const SizedBox.expand(),
        ),
      ),
    );
  }

  /// 메인 매크로 바 바로 아래, 왼쪽 정렬 범례
  Widget _buildMacroLegendRow(BuildContext context) {
    final gap = healthDp(context, 24);
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        MacroLegend(color: const Color(0xFFFFDFC3), label: '탄수화물'),
        SizedBox(width: gap),
        MacroLegend(color: const Color(0xFFFEA38E), label: '단백질'),
        SizedBox(width: gap),
        MacroLegend(color: const Color(0xFFFCF4C1), label: '지방'),
        SizedBox(width: gap),
        MacroLegend(color: const Color(0xFFD6DEE8), label: '기타'),
      ],
    );
  }

  Widget _buildMealDetailCard(
    BuildContext context, {
    required String title,
    required int kcal,
    required String carb,
    required String protein,
    required String fat,
    required String other,
    FoodRecordSummary? mealRecord,
    VoidCallback? onTap,
  }) {
    final isEmptyMeal = mealRecord == null ||
        (mealRecord.items.isEmpty && (mealRecord.calories ?? 0) == 0);
    final imagePath = mealRecord?.imagePath;
    final hasPhoto = imagePath != null && imagePath.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: healthDp(context, 76.5),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(healthDp(context, 10)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
            border: Border.all(
              width: healthDp(context, 0.5),
              color: const Color(0xFFD9D9D9),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMealThumbnail(
                context,
                isEmptyMeal: isEmptyMeal,
                hasPhoto: hasPhoto,
                imagePath: imagePath,
              ),
              SizedBox(width: healthDp(context, 20)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        height: 1.0,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: healthDp(context, 6)),
                    MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.noScaling),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$kcal',
                              style: TextStyle(
                                color: const Color(0xFFFF5A8D),
                                fontSize: healthSp(context, 12),
                                height: 1.0,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: ' kcal',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: healthSp(context, 12),
                                height: 1.0,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: healthDp(context, 6)),
                    Wrap(
                      spacing: healthDp(context, 6),
                      runSpacing: healthDp(context, 2),
                      children: [
                        _buildNutrientText(context, '탄수화물', carb),
                        _buildNutrientText(context, '단백질', protein),
                        _buildNutrientText(context, '지방', fat),
                        // _buildNutrientText(context, '기타', other),
                      ],
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Icon(
                  Icons.expand_more,
                  size: healthDp(context, 10),
                  color: const Color(0xFF898383),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealThumbnail(
    BuildContext context, {
    required bool isEmptyMeal,
    required bool hasPhoto,
    String? imagePath,
  }) {
    final thumbW = healthDp(context, 47.08);
    final thumbH = healthDp(context, 48.33);

    if (isEmptyMeal) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(healthDp(context, 5)),
        child: Container(
          width: thumbW,
          height: thumbH,
          color: const Color(0xFFD9D9D9),
          alignment: Alignment.center,
          child: Icon(
            Icons.add,
            color: Colors.white,
            size: healthDp(context, 20),
          ),
        ),
      );
    }

    if (hasPhoto) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(healthDp(context, 5)),
        child: Image.network(
          ImageUrlHelper.getImageUrl(imagePath),
          width: thumbW,
          height: thumbH,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _mealPlaceholderSvg(context, thumbW, thumbH),
        ),
      );
    }

    return _mealPlaceholderSvg(context, thumbW, thumbH);
  }

  Widget _mealPlaceholderSvg(BuildContext context, double w, double h) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(healthDp(context, 5)),
      child: Container(
        width: w,
        height: h,
        color: const Color(0xFFFDF2F8),
        alignment: Alignment.center,
        child: SvgPicture.asset(
          AppAssets.foodCaloriesCard,
          width: w,
          height: h,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildNutrientText(BuildContext context, String label, String value) {
    final display = value == '-' ? '---' : value;
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.noScaling),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: const Color(0xFF898383),
            fontSize: healthSp(context, 10),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
          children: [
            TextSpan(text: '$label '),
            TextSpan(
              text: display,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
              ),
            ),
            const TextSpan(text: 'g'),
          ],
        ),
      ),
    );
  }
}
