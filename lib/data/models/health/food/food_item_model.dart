/// 식사에 포함된 개별 음식 항목 모델
class FoodItem {
  final int? id;
  final int? foodRecordId; // 식사 기록 ID (외래키)
  final String foodName; // 음식명
  final int? foodId; // FoodLens에서 제공하는 음식 ID
  final double calories; // 칼로리 (kcal)
  final double? carbs; // 탄수화물 (g)
  final double? protein; // 단백질 (g)
  final double? fat; // 지방 (g)
  final double? sodium; // 나트륨 (mg)
  final double? sugar; // 당분 (g)
  final double? eatAmount; // 섭취량 (FoodLens에서 제공)
  final bool recognizedByFoodLens; // FoodLens로 인식된 음식인지 여부
  final String? imagePath; // 음식 사진 경로 (FoodLens 인식 시 사용된 이미지)

  FoodItem({
    this.id,
    this.foodRecordId,
    required this.foodName,
    this.foodId,
    required this.calories,
    this.carbs,
    this.protein,
    this.fat,
    this.sodium,
    this.sugar,
    this.eatAmount,
    this.recognizedByFoodLens = false,
    this.imagePath,
  });

  /// FoodLens API 응답으로부터 생성
  factory FoodItem.fromFoodLensResult(
    Map<String, dynamic> foodLensResult, {
    String? imagePath,
  }) {
    return FoodItem(
      foodName: foodLensResult['foodName']?.toString() ?? '인식된 음식',
      foodId: foodLensResult['foodId'] != null 
          ? (foodLensResult['foodId'] as num).toInt() 
          : null,
      calories: (foodLensResult['calories'] ?? 0.0) as double,
      carbs: foodLensResult['carbs'] != null 
          ? (foodLensResult['carbs'] as num).toDouble() 
          : null,
      protein: foodLensResult['protein'] != null 
          ? (foodLensResult['protein'] as num).toDouble() 
          : null,
      fat: foodLensResult['fat'] != null 
          ? (foodLensResult['fat'] as num).toDouble() 
          : null,
      sodium: foodLensResult['sodium'] != null 
          ? (foodLensResult['sodium'] as num).toDouble() 
          : null,
      sugar: foodLensResult['sugar'] != null 
          ? (foodLensResult['sugar'] as num).toDouble() 
          : null,
      eatAmount: foodLensResult['eatAmount'] != null 
          ? (foodLensResult['eatAmount'] as num).toDouble() 
          : null,
      recognizedByFoodLens: true,
      imagePath: imagePath,
    );
  }

  /// 수동 입력 음식으로부터 생성
  factory FoodItem.fromManualInput({
    required String foodName,
    required double calories,
    double? carbs,
    double? protein,
    double? fat,
  }) {
    return FoodItem(
      foodName: foodName,
      calories: calories,
      carbs: carbs,
      protein: protein,
      fat: fat,
      recognizedByFoodLens: false,
    );
  }

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'] ?? json['food_item_id'],
      foodRecordId: json['foodRecordId'] ?? json['food_record_id'],
      foodName: (json['foodName'] ?? json['food_name'] ?? '').toString(),
      foodId: json['foodId'] != null || json['food_id'] != null
          ? ((json['foodId'] ?? json['food_id']) as num).toInt()
          : null,
      calories: (json['calories'] as num).toDouble(),
      carbs: json['carbs'] != null ? (json['carbs'] as num).toDouble() : null,
      protein: json['protein'] != null ? (json['protein'] as num).toDouble() : null,
      fat: json['fat'] != null ? (json['fat'] as num).toDouble() : null,
      sodium: json['sodium'] != null ? (json['sodium'] as num).toDouble() : null,
      sugar: json['sugar'] != null ? (json['sugar'] as num).toDouble() : null,
      eatAmount: json['eatAmount'] != null || json['eat_amount'] != null
          ? ((json['eatAmount'] ?? json['eat_amount']) as num).toDouble()
          : null,
      recognizedByFoodLens: json['recognizedByFoodLens'] ?? json['recognized_by_foodlens'] ?? false,
      imagePath: json['imagePath'] ?? json['image_path']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'food_item_id': id,
      if (foodRecordId != null) 'food_record_id': foodRecordId,
      'food_name': foodName,
      if (foodId != null) 'food_id': foodId,
      'calories': calories,
      if (carbs != null) 'carbs': carbs,
      if (protein != null) 'protein': protein,
      if (fat != null) 'fat': fat,
      if (sodium != null) 'sodium': sodium,
      if (sugar != null) 'sugar': sugar,
      if (eatAmount != null) 'eat_amount': eatAmount,
      'recognized_by_foodlens': recognizedByFoodLens ? 1 : 0,
      if (imagePath != null && imagePath!.isNotEmpty) 'image_path': imagePath,
    };
  }

  FoodItem copyWith({
    int? id,
    int? foodRecordId,
    String? foodName,
    int? foodId,
    double? calories,
    double? carbs,
    double? protein,
    double? fat,
    double? sodium,
    double? sugar,
    double? eatAmount,
    bool? recognizedByFoodLens,
    String? imagePath,
  }) {
    return FoodItem(
      id: id ?? this.id,
      foodRecordId: foodRecordId ?? this.foodRecordId,
      foodName: foodName ?? this.foodName,
      foodId: foodId ?? this.foodId,
      calories: calories ?? this.calories,
      carbs: carbs ?? this.carbs,
      protein: protein ?? this.protein,
      fat: fat ?? this.fat,
      sodium: sodium ?? this.sodium,
      sugar: sugar ?? this.sugar,
      eatAmount: eatAmount ?? this.eatAmount,
      recognizedByFoodLens: recognizedByFoodLens ?? this.recognizedByFoodLens,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}

