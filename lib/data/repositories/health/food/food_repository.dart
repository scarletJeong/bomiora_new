import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';

/// Node.js Buffer 직렬화({ type: 'Buffer', data: [...] })를 UTF-8로 디코딩 후 JSON으로 파싱 (재귀 처리)
dynamic _unwrapBuffer(dynamic value) {
  if (value is! Map) return value;
  final map = value as Map;
  if (map['type'] == 'Buffer' && map['data'] is List) {
    final list = map['data'] as List;
    if (list.isEmpty) return value;
    final bytes = list.map((e) => (e is int) ? e : 0).toList();
    final decoded = utf8.decode(bytes);
    final parsed = json.decode(decoded);
    return _unwrapBuffer(parsed); // 이중 감싸기 대비
  }
  return value;
}

/// 필드 값이 Buffer 객체로 오면 UTF-8 문자열로 복원 (음식명 등)
String _bufferFieldToString(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is Map && value['type'] == 'Buffer' && value['data'] is List) {
    final list = value['data'] as List;
    if (list.isEmpty) return '';
    final bytes = list.map((e) => (e is int) ? e : 0).toList();
    return utf8.decode(bytes);
  }
  return value.toString();
}

/// 응답 body 파싱 + Buffer면 언래핑
dynamic _decodeResponseBody(String rawBody) {
  final body = json.decode(rawBody);
  return _unwrapBuffer(body);
}

/// 음식 검색 결과 한 건
class FoodSearchItem {
  final String foodCode;
  final String foodName;
  final String manufacturerName;
  final num? energy;
  final num? carbohydrates;
  final num? protein;
  final num? fat;
  /// 탄·단·지 제외, DB에 있는 g 단위 성분 합(수분·회분·지방산(g)·당(g)等). kcal/mg/μg 미포함.
  final num? otherGrams;
  final String? representativeFoodName;
  final String? nutrientBaseQuantity;

  FoodSearchItem({
    required this.foodCode,
    required this.foodName,
    this.manufacturerName = '',
    this.energy,
    this.carbohydrates,
    this.protein,
    this.fat,
    this.otherGrams,
    this.representativeFoodName,
    this.nutrientBaseQuantity,
  });

  factory FoodSearchItem.fromJson(Map<String, dynamic> json) {
    return FoodSearchItem(
      foodCode: _bufferFieldToString(json['food_code']),
      foodName: _bufferFieldToString(json['food_name']),
      manufacturerName: _bufferFieldToString(json['manufacturer_name']),
      energy: json['energy'] != null ? num.tryParse(json['energy'].toString()) : null,
      carbohydrates: json['carbohydrates'] != null
          ? num.tryParse(json['carbohydrates'].toString())
          : null,
      protein: json['protein'] != null ? num.tryParse(json['protein'].toString()) : null,
      fat: json['fat'] != null ? num.tryParse(json['fat'].toString()) : null,
      otherGrams:
          json['other_grams'] != null ? num.tryParse(json['other_grams'].toString()) : null,
      representativeFoodName: _bufferFieldToString(json['representative_food_name']).isNotEmpty
          ? _bufferFieldToString(json['representative_food_name'])
          : null,
      nutrientBaseQuantity: _bufferFieldToString(json['nutrient_base_quantity']).isNotEmpty
          ? _bufferFieldToString(json['nutrient_base_quantity'])
          : null,
    );
  }

  String get desc {
    final parts = <String>[];
    if (carbohydrates != null) parts.add('탄수화물 ${carbohydrates!.toStringAsFixed(1)}g');
    if (protein != null) parts.add('단백질 ${protein!.toStringAsFixed(1)}g');
    if (fat != null) parts.add('지방 ${fat!.toStringAsFixed(1)}g');
    if (otherGrams != null && otherGrams != 0) {
      parts.add('기타 ${otherGrams!.toStringAsFixed(1)}g');
    }
    return parts.isEmpty ? '' : '(${parts.join(', ')})';
  }
}

/// 식사 기록에 포함된 음식 한 건 (bm_food_records_items)
class FoodRecordItemSummary {
  final String itemId;
  final String foodName;
  final num? kcal;
  final num? carbohydrate;
  final num? protein;
  final num? fat;
  final num? other;

  FoodRecordItemSummary({
    required this.itemId,
    required this.foodName,
    this.kcal,
    this.carbohydrate,
    this.protein,
    this.fat,
    this.other,
  });

  factory FoodRecordItemSummary.fromJson(Map<String, dynamic> json) {
    return FoodRecordItemSummary(
      itemId: json['item_id']?.toString() ?? '',
      foodName: _bufferFieldToString(json['food_name']),
      kcal: json['kcal'] != null ? num.tryParse(json['kcal'].toString()) : null,
      carbohydrate: json['carbohydrate'] != null ? num.tryParse(json['carbohydrate'].toString()) : null,
      protein: json['protein'] != null ? num.tryParse(json['protein'].toString()) : null,
      fat: json['fat'] != null ? num.tryParse(json['fat'].toString()) : null,
      other: json['other'] != null ? num.tryParse(json['other'].toString()) : null,
    );
  }

  String get desc {
    final parts = <String>[];
    if (carbohydrate != null) parts.add('탄수화물 ${carbohydrate!.toStringAsFixed(1)}g');
    if (protein != null) parts.add('단백질 ${protein!.toStringAsFixed(1)}g');
    if (fat != null) parts.add('지방 ${fat!.toStringAsFixed(1)}g');
    if (other != null) parts.add('기타 ${other!.toStringAsFixed(1)}g');
    return parts.isEmpty ? '' : '(${parts.join(', ')})';
  }
}

/// 식사 기록 한 건 (아침/점심/저녁/간식)
class FoodRecordSummary {
  final String id;
  final String recordDate;
  final String foodTime;
  final int? calories;
  final num? protein;
  final num? carbs;
  final num? fat;
  final num? other;
  final List<FoodRecordItemSummary> items;

  FoodRecordSummary({
    required this.id,
    required this.recordDate,
    required this.foodTime,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.other,
    this.items = const [],
  });

  factory FoodRecordSummary.fromJson(Map<String, dynamic> json) {
    List<FoodRecordItemSummary> items = [];
    if (json['items'] is List) {
      items = (json['items'] as List)
          .map((e) => FoodRecordItemSummary.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    final caloriesRaw = json['calories'];
    final calories = caloriesRaw != null
        ? (caloriesRaw is int ? caloriesRaw : int.tryParse(caloriesRaw.toString()))
        : null;
    return FoodRecordSummary(
      id: json['id']?.toString() ?? json['food_record_id']?.toString() ?? '',
      recordDate: json['record_date']?.toString() ?? '',
      foodTime: (json['food_time']?.toString() ?? '').toLowerCase(),
      calories: calories,
      protein: json['protein'] != null ? num.tryParse(json['protein'].toString()) : null,
      carbs: json['carbs'] != null ? num.tryParse(json['carbs'].toString()) : null,
      fat: json['fat'] != null ? num.tryParse(json['fat'].toString()) : null,
      other: json['other'] != null ? num.tryParse(json['other'].toString()) : null,
      items: items,
    );
  }
}

/// 화면 식사 키(아침/점심/저녁/간식) <-> API food_time
const Map<String, String> _mealKeyToFoodTime = {
  '아침': 'breakfast',
  '점심': 'lunch',
  '저녁': 'dinner',
  '간식': 'snack',
};

class FoodRepository {
  static String get _baseUrl => ApiClient.baseUrl;

  static int _foodCodePriority(String code) {
    if (code.isEmpty) return 99;
    final type = code[0].toUpperCase();
    if (type == 'D') return 0; // 음식
    if (type == 'P') return 1; // 가공식품
    if (type == 'F') return 2; // 건강기능식품
    return 3;
  }

  static List<String> _splitKeywordTokens(String keyword) {
    return keyword
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static bool _matchesAllTokens(FoodSearchItem item, List<String> tokens) {
    if (tokens.isEmpty) return true;
    final searchable = '${item.manufacturerName} ${item.foodName}'.toLowerCase();
    for (final token in tokens) {
      if (!searchable.contains(token)) return false;
    }
    return true;
  }

  static Future<List<FoodSearchItem>> _fetchFoodSearchRaw(
    String keyword, {
    int limit = 20,
    int offset = 0,
  }) async {
    final q = keyword.trim();
    if (q.isEmpty) return [];
    final uri = Uri.parse(
      '$_baseUrl${ApiEndpoints.foodSearch(q, limit: limit, offset: offset)}',
    );
    final response = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) return [];
    final body = _decodeResponseBody(response.body);
    List<dynamic> list = [];
    if (body is List) {
      list = body;
    } else if (body is Map && body['data'] is List) {
      list = body['data'] as List;
    } else if (body is Map && body['success'] == true && body['data'] is List) {
      list = body['data'] as List;
    }
    return list
        .map((e) {
          final unwrapped = _unwrapBuffer(e);
          if (unwrapped is! Map) return null;
          return FoodSearchItem.fromJson(Map<String, dynamic>.from(unwrapped));
        })
        .whereType<FoodSearchItem>()
        .toList();
  }

  /// 식품명으로 검색 (칼로리/탄수화물/단백질/지방 반환)
  static Future<List<FoodSearchItem>> searchFood(
    String keyword, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final q = keyword.trim();
      if (q.isEmpty) return [];
      if (limit <= 0) return [];
      if (offset < 0) offset = 0;

      // 공백 포함 검색어는 전체 문장 + 토큰 단위 재검색으로 회수율 보완
      // 예) "스타벅스 커피" -> ["스타벅스 커피", "스타벅스", "커피"]
      final queries = <String>{q};
      final baseTokens = _splitKeywordTokens(q);
      if (baseTokens.length > 1) {
        queries.addAll(baseTokens);
      }

      final merged = <FoodSearchItem>[];
      final dedup = <String>{};
      final neededCount = offset + limit;
      for (final query in queries) {
        final fetchLimit = query == q ? neededCount : (neededCount * 2);
        final list = await _fetchFoodSearchRaw(query, limit: fetchLimit, offset: 0);
        for (final item in list) {
          final key = '${item.foodCode}|${item.foodName}';
          if (dedup.add(key)) {
            merged.add(item);
          }
        }
      }

      final filtered = merged.where((item) => _matchesAllTokens(item, baseTokens)).toList();
      final sorted = (filtered.isNotEmpty ? filtered : merged)..sort((a, b) {
        final pA = _foodCodePriority(a.foodCode);
        final pB = _foodCodePriority(b.foodCode);
        if (pA != pB) return pA.compareTo(pB);
        return a.foodName.compareTo(b.foodName);
      });

      if (offset >= sorted.length) return [];
      final end = (offset + limit) > sorted.length ? sorted.length : (offset + limit);
      final result = sorted.sublist(offset, end);

      if (kDebugMode) {
        debugPrint('[칼로리 검색] 질의="$q", offset=$offset, limit=$limit, 결과 수: ${result.length}');
        for (var i = 0; i < result.length; i++) {
          final it = result[i];
          debugPrint(
            '  ${i + 1}. ${it.manufacturerName} ${it.foodName} | food_code: ${it.foodCode} | ${it.energy ?? 0}kcal',
          );
        }
      }
      return result;
    } catch (e) {
      print('음식 검색 오류: $e');
      return [];
    }
  }

  /// 해당 날짜 식사 기록 목록 조회 (날짜별 아침/점심/저녁/간식)
  static Future<List<FoodRecordSummary>> getRecordsForDate(String mbId, DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final uri = Uri.parse(
        '$_baseUrl${ApiEndpoints.foodRecords(dateStr)}&mb_id=${Uri.encodeComponent(mbId)}',
      );
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode != 200) return [];
      final body = _decodeResponseBody(response.body);
      List<dynamic> list = [];
      if (body is List) list = body;
      else if (body is Map && body['data'] is List) list = body['data'] as List;
      else if (body is Map && body['success'] == true && body['data'] is List) {
        list = body['data'] as List;
      }
      return list
          .map((e) => FoodRecordSummary.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      print('식사 기록 조회 오류: $e');
      return [];
    }
  }

  /// 식사 기록 생성 (해당 날짜/시간대)
  static Future<FoodRecordSummary?> createRecord(
    String mbId,
    DateTime date,
    String mealKey,
  ) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final foodTime = _mealKeyToFoodTime[mealKey] ?? 'snack';
      final uri = Uri.parse('$_baseUrl${ApiEndpoints.foodRecordCreate}');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'mb_id': mbId,
          'record_date': dateStr,
          'food_time': foodTime,
        }),
      );
      if (response.statusCode != 200 && response.statusCode != 201) return null;
      final body = _decodeResponseBody(response.body);
      final data = body is Map ? body['data'] ?? body : body;
      if (data is Map) {
        return FoodRecordSummary.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } catch (e) {
      print('식사 기록 생성 오류: $e');
      return null;
    }
  }

  /// 식사 기록에 음식 추가
  static Future<bool> addItemToRecord(String foodRecordId, FoodSearchItem item) async {
    try {
      final uri = Uri.parse('$_baseUrl${ApiEndpoints.foodRecordItems(foodRecordId)}');
      final body = {
        'food_code': item.foodCode,
        'food_name': item.foodName,
        'serving_quantity': 1.0,
        'energy': item.energy?.toDouble() ?? 0.0,
        'carbohydrates': item.carbohydrates?.toDouble() ?? 0.0,
        'protein': item.protein?.toDouble() ?? 0.0,
        'fat': item.fat?.toDouble() ?? 0.0,
        'other': item.otherGrams?.toDouble() ?? 0.0,
      };
      if (kDebugMode) {
        debugPrint('[식사 기록 추가] POST $uri');
        debugPrint('[식사 기록 추가] body: $body');
      }
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      if (kDebugMode && response.statusCode >= 400) {
        debugPrint('[식사 기록 추가] 응답 ${response.statusCode}: ${response.body}');
      }
      if (response.statusCode == 500) {
        debugPrint('[식사 기록 추가] 500 원인 확인용 body: ${response.body}');
      }
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      if (kDebugMode) debugPrint('식사 기록 항목 추가 오류: $e');
      return false;
    }
  }

  /// 식사 기록에서 음식 항목 삭제
  static Future<bool> deleteRecordItem(String foodRecordId, String itemId) async {
    try {
      final uri = Uri.parse('$_baseUrl${ApiEndpoints.foodRecordItemDelete(foodRecordId, itemId)}');
      final response = await http.delete(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      if (kDebugMode) debugPrint('식사 기록 항목 삭제 오류: $e');
      return false;
    }
  }

  /// mealKey(아침/점심/저녁/간식)에 해당하는 food_time
  static String foodTimeFromMealKey(String mealKey) {
    return _mealKeyToFoodTime[mealKey] ?? 'snack';
  }
}
