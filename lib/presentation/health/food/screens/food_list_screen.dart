import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../data/models/user/user_model.dart';
import '../../../../data/repositories/health/food/food_repository.dart';
import '../../../../data/services/auth_service.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
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
    setState(() {
      _dayRecords = list;
      totalCalories = calories;
      totalCarbs = carbs;
      totalProtein = protein;
      totalFat = fat;
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
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      appBar: const HealthAppBar(
        title: '식사 기록',
        centerTitle: false,
      ),
      child: Column(
        children: [
          HealthDateSelector(
            selectedDate: selectedDate,
            onDateChanged: (date) {
              setState(() => selectedDate = date);
              _loadMealData();
            },
            monthTextColor: const Color(0xFF898686),
            selectedTextColor: const Color(0xFFFF5A8D),
            unselectedTextColor: const Color(0xFFB7B7B7),
            dividerColor: const Color(0xFFD2D2D2),
            iconColor: const Color(0xFF898686),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(27, 14, 27, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          '총 섭취 칼로리',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${NumberFormat('#,###').format(totalCalories)} kcal',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 36,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildDashboardMacroBar(),
                  const SizedBox(height: 8),
                  _buildMacroLegendRow(),
                  const SizedBox(height: 28),
                  _buildMealDetailCard(
                    title: '아침',
                    kcal: _recordFor('아침')?.calories ?? 0,
                    carb: _recordFor('아침')?.carbs?.toStringAsFixed(1) ?? '-',
                    protein: _recordFor('아침')?.protein?.toStringAsFixed(1) ?? '-',
                    fat: _recordFor('아침')?.fat?.toStringAsFixed(1) ?? '-',
                    mealRecord: _recordFor('아침'),
                    onTap: () => _toggleFoodSearchFor('아침'),
                  ),
                  if (_expandedMealKey == '아침') ...[
                    const SizedBox(height: 12),
                    CalorieSearchBlock(
                      mealKey: '아침',
                      selectedDate: selectedDate,
                      mbId: _currentUser?.id ?? '',
                      foodRecordId: _recordFor('아침')?.id ?? '',
                      addedItems: _recordFor('아침')?.items ?? [],
                      onItemAdded: _onFoodItemAdded,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _buildMealDetailCard(
                    title: '점심',
                    kcal: _recordFor('점심')?.calories ?? 0,
                    carb: _recordFor('점심')?.carbs?.toStringAsFixed(1) ?? '-',
                    protein: _recordFor('점심')?.protein?.toStringAsFixed(1) ?? '-',
                    fat: _recordFor('점심')?.fat?.toStringAsFixed(1) ?? '-',
                    mealRecord: _recordFor('점심'),
                    onTap: () => _toggleFoodSearchFor('점심'),
                  ),
                  if (_expandedMealKey == '점심') ...[
                    const SizedBox(height: 12),
                    CalorieSearchBlock(
                      mealKey: '점심',
                      selectedDate: selectedDate,
                      mbId: _currentUser?.id ?? '',
                      foodRecordId: _recordFor('점심')?.id ?? '',
                      addedItems: _recordFor('점심')?.items ?? [],
                      onItemAdded: _onFoodItemAdded,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _buildMealDetailCard(
                    title: '저녁',
                    kcal: _recordFor('저녁')?.calories ?? 0,
                    carb: _recordFor('저녁')?.carbs?.toStringAsFixed(1) ?? '-',
                    protein: _recordFor('저녁')?.protein?.toStringAsFixed(1) ?? '-',
                    fat: _recordFor('저녁')?.fat?.toStringAsFixed(1) ?? '-',
                    mealRecord: _recordFor('저녁'),
                    onTap: () => _toggleFoodSearchFor('저녁'),
                  ),
                  if (_expandedMealKey == '저녁') ...[
                    const SizedBox(height: 12),
                    CalorieSearchBlock(
                      mealKey: '저녁',
                      selectedDate: selectedDate,
                      mbId: _currentUser?.id ?? '',
                      foodRecordId: _recordFor('저녁')?.id ?? '',
                      addedItems: _recordFor('저녁')?.items ?? [],
                      onItemAdded: _onFoodItemAdded,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _buildMealDetailCard(
                    title: '간식',
                    kcal: _recordFor('간식')?.calories ?? 0,
                    carb: _recordFor('간식')?.carbs?.toStringAsFixed(1) ?? '-',
                    protein: _recordFor('간식')?.protein?.toStringAsFixed(1) ?? '-',
                    fat: _recordFor('간식')?.fat?.toStringAsFixed(1) ?? '-',
                    mealRecord: _recordFor('간식'),
                    onTap: () => _toggleFoodSearchFor('간식'),
                  ),
                  if (_expandedMealKey == '간식') ...[
                    const SizedBox(height: 12),
                    CalorieSearchBlock(
                      mealKey: '간식',
                      selectedDate: selectedDate,
                      mbId: _currentUser?.id ?? '',
                      foodRecordId: _recordFor('간식')?.id ?? '',
                      addedItems: _recordFor('간식')?.items ?? [],
                      onItemAdded: _onFoodItemAdded,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 칼로리 바: 최대 2000kcal 기준, 탄수화물/단백질/지방 비율로 채움
  Widget _buildDashboardMacroBar() {
    final fillRatio = (_maxCalories > 0 && totalCalories > 0)
        ? (totalCalories / _maxCalories).clamp(0.0, 1.0)
        : 0.0;
    final carbsKcal = (totalCarbs * 4).toDouble();
    final proteinKcal = (totalProtein * 4).toDouble();
    final fatKcal = (totalFat * 9).toDouble();
    final totalKcalFromMacros = carbsKcal + proteinKcal + fatKcal;
    int cF = 1, pF = 1, fF = 1;
    if (totalKcalFromMacros > 0) {
      cF = (carbsKcal / totalKcalFromMacros * 100).round().clamp(1, 100);
      pF = (proteinKcal / totalKcalFromMacros * 100).round().clamp(1, 100);
      fF = (fatKcal / totalKcalFromMacros * 100).round().clamp(1, 100);
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
                    Expanded(flex: cF, child: Container(color: const Color(0xFFFFDFC3))),
                    Expanded(flex: pF, child: Container(color: const Color(0xFFFEA38E))),
                    Expanded(flex: fF, child: Container(color: const Color(0xFFFCF4C1))),
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

  /// 메인 매크로 바 바로 아래, 왼쪽 정렬 범례
  Widget _buildMacroLegendRow() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        MacroLegend(color: Color(0xFFFFDFC3), label: '탄수화물'),
        SizedBox(width: 24),
        MacroLegend(color: Color(0xFFFEA38E), label: '단백질'),
        SizedBox(width: 24),
        MacroLegend(color: Color(0xFFFCF4C1), label: '지방'),
        SizedBox(width: 24),
        MacroLegend(color: Color(0xFFE2E2E2), label: '기타'),
      ],
    );
  }

  Widget _buildMealDetailCard({
    required String title,
    required int kcal,
    required String carb,
    required String protein,
    required String fat,
    FoodRecordSummary? mealRecord,
    VoidCallback? onTap,
  }) {
    final isEmptyMeal = mealRecord == null ||
        (mealRecord.items.isEmpty && (mealRecord.calories ?? 0) == 0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x19000000),
              blurRadius: 4.17,
            ),
          ],
        ),
        child: Row(
            children: [
              Container(
                width: 47.08,
                height: 48.33,
                decoration: BoxDecoration(
                  color: isEmptyMeal
                      ? const Color(0xFFD9D9D9)
                      : const Color(0xFFFF5A8D),
                  borderRadius: BorderRadius.circular(5),
                ),
                alignment: Alignment.center,
                child: isEmptyMeal
                    ? const Icon(Icons.add, color: Colors.white, size: 22)
                    : null,
              ),
              const SizedBox(width: 12),
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$kcal',
                            style: const TextStyle(
                              color: Color(0xFFFF5A8D),
                              fontSize: 12,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(
                            text: ' kcal',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        _buildNutrientText('탄수화물', carb),
                        _buildNutrientText('단백질', protein),
                        _buildNutrientText('지방', fat),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.expand_more,
                size: 24,
                color: const Color(0xFF898383),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildNutrientText(String label, String value) {
    final display = value == '-' ? '---' : value;
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Color(0xFF898383),
          fontSize: 10,
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
            ),
          ),
          const TextSpan(text: 'g'),
        ],
      ),
    );
  }
}
