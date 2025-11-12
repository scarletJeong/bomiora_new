import 'food_item_model.dart';

/// 식사 기록 모델
class FoodRecord {
  final int? id;
  final String mbId; // 회원 ID
  final String mealType; // 식사 종류: '아침식사', '점심식사', '저녁식사', '간식'
  final DateTime recordedAt; // 식사 기록 시간
  final List<FoodItem> foods; // 식사에 포함된 음식 목록
  final double totalCalories; // 총 칼로리 (음식들의 칼로리 합계)
  final String? imagePath; // 식사 사진 경로 (FoodLens 인식에 사용된 이미지)
  final String? notes; // 메모
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FoodRecord({
    this.id,
    required this.mbId,
    required this.mealType,
    required this.recordedAt,
    required this.foods,
    double? totalCalories,
    this.imagePath,
    this.notes,
    this.createdAt,
    this.updatedAt,
  }) : totalCalories = totalCalories ?? _calculateTotalCalories(foods);

  /// 음식 목록으로부터 총 칼로리 계산
  static double _calculateTotalCalories(List<FoodItem> foods) {
    return foods.fold(0.0, (sum, food) => sum + food.calories);
  }

  /// 총 영양소 계산
  double get totalCarbs => foods.fold(0.0, (sum, food) => sum + (food.carbs ?? 0.0));
  double get totalProtein => foods.fold(0.0, (sum, food) => sum + (food.protein ?? 0.0));
  double get totalFat => foods.fold(0.0, (sum, food) => sum + (food.fat ?? 0.0));
  double get totalSodium => foods.fold(0.0, (sum, food) => sum + (food.sodium ?? 0.0));
  double get totalSugar => foods.fold(0.0, (sum, food) => sum + (food.sugar ?? 0.0));

  /// FoodLens로 인식된 음식이 있는지 확인
  bool get hasFoodLensRecognition => foods.any((food) => food.recognizedByFoodLens);

  factory FoodRecord.fromJson(Map<String, dynamic> json) {
    // foods가 리스트인 경우
    List<FoodItem> foodsList = [];
    if (json['foods'] != null) {
      if (json['foods'] is List) {
        foodsList = (json['foods'] as List)
            .map((item) => FoodItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }

    return FoodRecord(
      id: json['id'] ?? json['food_record_id'] ?? json['record_id'],
      mbId: (json['mbId'] ?? json['mb_id'] ?? '').toString(),
      mealType: (json['mealType'] ?? json['meal_type'] ?? '').toString(),
      recordedAt: _parseDateTime(json['recordedAt'] ?? json['recorded_at']),
      foods: foodsList,
      totalCalories: json['totalCalories'] != null || json['total_calories'] != null
          ? ((json['totalCalories'] ?? json['total_calories']) as num).toDouble()
          : null,
      imagePath: json['imagePath'] ?? json['image_path']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: json['createdAt'] != null || json['created_at'] != null
          ? _parseDateTime(json['createdAt'] ?? json['created_at'])
          : null,
      updatedAt: json['updatedAt'] != null || json['updated_at'] != null
          ? _parseDateTime(json['updatedAt'] ?? json['updated_at'])
          : null,
    );
  }

  // 안전한 날짜 파싱 함수
  static DateTime _parseDateTime(dynamic dateValue) {
    try {
      if (dateValue == null) {
        return DateTime.now();
      }
      
      String dateStr = dateValue.toString();
      
      if (dateStr.contains('0000-00-00') || 
          dateStr.contains('1900-01-01') ||
          dateStr.isEmpty) {
        print('⚠️ 잘못된 날짜 형식 감지: $dateStr, 현재 시간으로 대체');
        return DateTime.now();
      }
      
      return DateTime.parse(dateStr);
    } catch (e) {
      print('❌ 날짜 파싱 오류: $dateValue, 현재 시간으로 대체');
      return DateTime.now();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'food_record_id': id,
      'mb_id': mbId,
      'meal_type': mealType,
      'recorded_at': recordedAt.toIso8601String(),
      'foods': foods.map((food) => food.toJson()).toList(),
      'total_calories': totalCalories,
      if (imagePath != null && imagePath!.isNotEmpty) 'image_path': imagePath,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }

  /// API 전송용 JSON (중첩 구조)
  Map<String, dynamic> toApiJson() {
    return {
      if (id != null) 'food_record_id': id,
      'mb_id': mbId,
      'meal_type': mealType,
      'recorded_at': recordedAt.toIso8601String(),
      'foods': foods.map((food) => food.toJson()).toList(),
      'total_calories': totalCalories,
      if (imagePath != null && imagePath!.isNotEmpty) 'image_path': imagePath,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }

  FoodRecord copyWith({
    int? id,
    String? mbId,
    String? mealType,
    DateTime? recordedAt,
    List<FoodItem>? foods,
    double? totalCalories,
    String? imagePath,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FoodRecord(
      id: id ?? this.id,
      mbId: mbId ?? this.mbId,
      mealType: mealType ?? this.mealType,
      recordedAt: recordedAt ?? this.recordedAt,
      foods: foods ?? this.foods,
      totalCalories: totalCalories ?? this.totalCalories,
      imagePath: imagePath ?? this.imagePath,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

