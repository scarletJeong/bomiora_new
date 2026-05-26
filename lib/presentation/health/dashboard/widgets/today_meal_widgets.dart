import 'package:flutter/material.dart';

import '../../../common/widgets/login_required_dialog.dart';
import '../../food/screens/food_list_screen.dart';
import '../../health_common/health_responsive_scale.dart';

/// 건강 대시보드 — 「오늘의 식사」 블록(헤더, 매크로 바, 끼니 카드).
class TodayMealSection extends StatelessWidget {
  const TodayMealSection({
    super.key,
    required this.consumedCalories,
    required this.targetCalories,
    required this.totalCarbs,
    required this.totalProtein,
    required this.totalFat,
    required this.totalOther,
    required this.mealCalories,
    required this.selectedDate,
    required this.isLoggedIn,
    required this.onAfterDietReturn,
  });

  final int consumedCalories;
  final int targetCalories;
  final num totalCarbs;
  final num totalProtein;
  final num totalFat;
  final num totalOther;
  final Map<String, int> mealCalories;
  final DateTime selectedDate;
  final bool isLoggedIn;
  final VoidCallback onAfterDietReturn;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (!isLoggedIn) {
          await showLoginRequiredDialog(
            context,
            message: '건강 대시보드 입력은 로그인 후 이용할 수 있습니다.',
          );
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TodayDietScreen(initialDate: selectedDate),
          ),
        );
        onAfterDietReturn();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(healthDp(context, 20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: healthDp(context, 1.5),
                      height: healthDp(context, 16),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.all(
                            Radius.circular(healthDp(context, 3)),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: healthDp(context, 8)),
                    RichText(
                      textScaler: TextScaler.noScaling,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: healthSp(context, 16),
                          color: Colors.black,
                        ),
                        children: const [
                          TextSpan(
                            text: '오늘의 ',
                            style: TextStyle(
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          TextSpan(
                            text: '식사',
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$consumedCalories',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: const Color(0xFFFF5A8D),
                        fontSize: healthSp(context, 16),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    Text(
                      ' / $targetCalories kcal',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: healthSp(context, 10),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: healthDp(context, 14)),
            _TodayMealMacroBar(
              consumedCalories: consumedCalories,
              targetCalories: targetCalories,
              totalCarbs: totalCarbs,
              totalProtein: totalProtein,
              totalFat: totalFat,
              totalOther: totalOther,
            ),
            SizedBox(height: healthDp(context, 10)),
            Row(
              children: [
                _LegendDot('탄수화물', const Color(0xFFFFDFC3)),
                SizedBox(width: healthDp(context, 24)),
                _LegendDot('단백질', const Color(0xFFFEA38E)),
                SizedBox(width: healthDp(context, 24)),
                _LegendDot('지방', const Color(0xFFFCF4C1)),
                SizedBox(width: healthDp(context, 24)),
                _LegendDot('기타', const Color(0xFFE2E2E2)),
              ],
            ),
            SizedBox(height: healthDp(context, 14)),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _TodayMealItemCard(
                  mealName: '아침',
                  calories: mealCalories['Breakfast'] ?? 0,
                  hasMeal: (mealCalories['Breakfast'] ?? 0) > 0,
                ),
                SizedBox(width: healthDp(context, 6)),
                _TodayMealItemCard(
                  mealName: '점심',
                  calories: mealCalories['Lunch'] ?? 0,
                  hasMeal: (mealCalories['Lunch'] ?? 0) > 0,
                ),
                SizedBox(width: healthDp(context, 6)),
                _TodayMealItemCard(
                  mealName: '저녁',
                  calories: mealCalories['Dinner'] ?? 0,
                  hasMeal: (mealCalories['Dinner'] ?? 0) > 0,
                ),
                SizedBox(width: healthDp(context, 6)),
                _TodayMealItemCard(
                  mealName: '간식',
                  calories: mealCalories['Snack'] ?? 0,
                  hasMeal: (mealCalories['Snack'] ?? 0) > 0,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayMealMacroBar extends StatelessWidget {
  const _TodayMealMacroBar({
    required this.consumedCalories,
    required this.targetCalories,
    required this.totalCarbs,
    required this.totalProtein,
    required this.totalFat,
    required this.totalOther,
  });

  final int consumedCalories;
  final int targetCalories;
  final num totalCarbs;
  final num totalProtein;
  final num totalFat;
  final num totalOther;

  @override
  Widget build(BuildContext context) {
    final fillRatio = (targetCalories > 0 && consumedCalories > 0)
        ? (consumedCalories / targetCalories).clamp(0.0, 1.0)
        : 0.0;
    final carbsKcal = (totalCarbs * 4).toDouble();
    final proteinKcal = (totalProtein * 4).toDouble();
    final fatKcal = (totalFat * 9).toDouble();
    final otherKcal = (totalOther * 4).toDouble();
    final totalKcalFromMacros =
        carbsKcal + proteinKcal + fatKcal + otherKcal;
    int carbsFlex = 1, proteinFlex = 1, fatFlex = 1, otherFlex = 1;
    if (totalKcalFromMacros > 0) {
      carbsFlex =
          (carbsKcal / totalKcalFromMacros * 100).round().clamp(1, 100);
      proteinFlex =
          (proteinKcal / totalKcalFromMacros * 100).round().clamp(1, 100);
      fatFlex = (fatKcal / totalKcalFromMacros * 100).round().clamp(1, 100);
      otherFlex =
          (otherKcal / totalKcalFromMacros * 100).round().clamp(1, 100);
    }
    final filledFlex = (fillRatio * 100).round().clamp(0, 100);
    final emptyFlex = (100 - filledFlex).clamp(1, 100);
    final barHeight = healthDp(context, 8);
    final barRadius = BorderRadius.circular(999);

    // 빈 상태: 흰 배경 + 테두리만으로 트랙이 보이도록 decoration에 color 지정
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
                            flex: carbsFlex,
                            child: Container(
                              color: const Color(0xFFFFDFC3),
                            ),
                          ),
                          Expanded(
                            flex: proteinFlex,
                            child: Container(
                              color: const Color(0xFFFEA38E),
                            ),
                          ),
                          Expanded(
                            flex: fatFlex,
                            child: Container(
                              color: const Color(0xFFFCF4C1),
                            ),
                          ),
                          Expanded(
                            flex: otherFlex,
                            child: Container(
                              color: const Color(0xFFE2E2E2),
                            ),
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
}

class _TodayMealItemCard extends StatelessWidget {
  const _TodayMealItemCard({
    required this.mealName,
    required this.calories,
    required this.hasMeal,
  });

  final String mealName;
  final int calories;
  final bool hasMeal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: healthDp(context, 75),
      height: healthDp(context, 96),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(healthDp(context, 16)),
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
                padding: EdgeInsets.all(healthDp(context, 6)),
                alignment: Alignment.bottomCenter,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(healthDp(context, 15)),
                  color: Colors.black.withOpacity(0.25),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      mealName,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: healthSp(context, 12),
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: healthDp(context, 4)),
                    Text(
                      '$calories kcal',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: healthSp(context, 10),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    mealName,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: healthSp(context, 14),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 0)),
                  Icon(
                    Icons.add,
                    color: Colors.white,
                    size: healthDp(context,30),
                  ),
                ],
              ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: healthDp(context, 10),
          height: healthDp(context, 10),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: healthDp(context, 3)),
        Text(
          label,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: const Color(0xFF6B7280),
            fontSize: healthSp(context, 10),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}
