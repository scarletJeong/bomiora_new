/// 탄수화물·단백질·기타 4kcal/g, 지방 9kcal/g로 나눈 막대 비율.
class MacroKcalShares {
  const MacroKcalShares({
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.other,
  });

  final int carbs;
  final int protein;
  final int fat;
  final int other;

  factory MacroKcalShares.fromGrams({
    required num carbsG,
    required num proteinG,
    required num fatG,
    required num otherG,
  }) {
    final carbsKcal = carbsG * 4;
    final proteinKcal = proteinG * 4;
    final fatKcal = fatG * 9;
    final otherKcal = otherG * 4;
    final total = carbsKcal + proteinKcal + fatKcal + otherKcal;
    int share(num kcal) {
      if (total <= 0) return 1;
      return (kcal / total * 100).round().clamp(1, 100);
    }

    return MacroKcalShares(
      carbs: share(carbsKcal),
      protein: share(proteinKcal),
      fat: share(fatKcal),
      other: share(otherKcal),
    );
  }
}
