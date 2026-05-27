import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/image_url_helper.dart';

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
  final List<String> imagePaths;
  final List<FoodRecordItemSummary> items;

  /// 대표 사진(목록 첫 번째)
  String? get imagePath =>
      imagePaths.isNotEmpty ? imagePaths.first : null;

  FoodRecordSummary({
    required this.id,
    required this.recordDate,
    required this.foodTime,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.other,
    this.imagePaths = const [],
    this.items = const [],
  });

  factory FoodRecordSummary.fromJson(Map<String, dynamic> json) {
    List<FoodRecordItemSummary> items = [];
    if (json['items'] is List) {
      items = (json['items'] as List)
          .whereType<Map>()
          .map(
            (e) => FoodRecordItemSummary.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
    }
    final caloriesRaw = json['calories'];
    int? calories;
    if (caloriesRaw != null) {
      if (caloriesRaw is int) {
        calories = caloriesRaw;
      } else if (caloriesRaw is num) {
        calories = caloriesRaw.round();
      } else {
        calories = int.tryParse(caloriesRaw.toString().split('.').first);
      }
    }
    return FoodRecordSummary(
      id: json['id']?.toString() ?? json['food_record_id']?.toString() ?? '',
      recordDate: json['record_date']?.toString() ?? '',
      foodTime: (json['food_time']?.toString() ?? '').toLowerCase(),
      calories: calories,
      protein: json['protein'] != null ? num.tryParse(json['protein'].toString()) : null,
      carbs: json['carbs'] != null ? num.tryParse(json['carbs'].toString()) : null,
      fat: json['fat'] != null ? num.tryParse(json['fat'].toString()) : null,
      other: json['other'] != null ? num.tryParse(json['other'].toString()) : null,
      imagePaths: _safeParseImagePaths(json),
      items: items,
    );
  }
}

const int _maxMealImages = 3;

/// 달력에서 고른 날짜를 API `record_date`(YYYY-MM-DD)로 — `toIso8601String`은 UTC라 KST에서 하루 밀릴 수 있음
String _localDateYmd(DateTime date) {
  final y = date.year;
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// 화면 식사 키(아침/점심/저녁/간식) <-> API food_time
const Map<String, String> _mealKeyToFoodTime = {
  '아침': 'breakfast',
  '점심': 'lunch',
  '저녁': 'dinner',
  '간식': 'snack',
};

bool _isCorruptImagePath(String path) {
  final t = path.trim();
  return t.contains('{type:') ||
      t.contains('"type":"Buffer"') ||
      t.contains('"type": "Buffer"');
}

/// API 필드가 배열·JSON 문자열·단일 경로 중 어떤 형태로 와도 경로 목록으로 변환
List<String> _coerceToPathList(dynamic raw) {
  if (raw == null) return [];
  if (raw is List) {
    final out = <String>[];
    for (final e in raw) {
      final item = _bufferFieldToString(e).trim();
      if (item.isEmpty || _isCorruptImagePath(item)) continue;
      if (item.startsWith('[')) {
        out.addAll(_coerceToPathList(item));
      } else {
        out.add(item);
      }
    }
    return out;
  }
  if (raw is Map &&
      raw['type'] == 'Buffer' &&
      raw['data'] is List) {
    return _coerceToPathList(_bufferFieldToString(raw));
  }
  final str = _bufferFieldToString(raw).trim();
  if (str.isEmpty || _isCorruptImagePath(str)) return [];
  if (str.startsWith('[')) {
    try {
      final decoded = jsonDecode(str);
      if (decoded is List) {
        return decoded
            .map((e) => e?.toString().trim() ?? '')
            .where((p) => p.isNotEmpty && !_isCorruptImagePath(p))
            .toList();
      }
    } catch (_) {}
  }
  return [str];
}

Map<String, dynamic> _normalizeFoodRecordJson(Map<String, dynamic> json) {
  final out = <String, dynamic>{};
  json.forEach((key, value) {
    final unwrapped = _unwrapBuffer(value);
    if (key == 'items' && unwrapped is List) {
      out[key] = unwrapped
          .map((item) {
            if (item is Map) {
              return _normalizeFoodRecordJson(Map<String, dynamic>.from(item));
            }
            return _unwrapBuffer(item);
          })
          .toList();
      return;
    }
    if (unwrapped is Map &&
        unwrapped['type'] == 'Buffer' &&
        unwrapped['data'] is List) {
      out[key] = _bufferFieldToString(unwrapped);
    } else {
      out[key] = unwrapped;
    }
  });
  return out;
}

Map<String, dynamic>? _foodRecordMapFromDynamic(dynamic raw) {
  try {
    final unwrapped = _unwrapBuffer(raw);
    if (unwrapped is! Map) return null;
    return _normalizeFoodRecordJson(Map<String, dynamic>.from(unwrapped));
  } catch (_) {
    return null;
  }
}

List<String> _safeParseImagePaths(Map<String, dynamic> json) {
  try {
    return _parseImagePaths(json);
  } catch (_) {
    return const [];
  }
}

List<String> _parseImagePaths(Map<String, dynamic> json) {
  final results = <String>[];
  final seen = <String>{};

  void addSinglePath(String? raw) {
    if (raw == null) return;
    var v = ImageUrlHelper.fixHealthApiImagePath(raw.trim());
    if (v.isEmpty || _isCorruptImagePath(v)) return;
    if (v.startsWith('[')) {
      for (final p in _coerceToPathList(v)) {
        addSinglePath(p);
      }
      return;
    }
    final key = _imagePathForApi(v);
    if (key.isEmpty || seen.contains(key)) return;
    seen.add(key);
    results.add(key);
  }

  void addField(dynamic raw) {
    for (final p in _coerceToPathList(raw)) {
      addSinglePath(p);
    }
  }

  for (final field in ['image_paths', 'imagePaths', 'photos', 'photos_json']) {
    addField(json[field]);
  }
  for (final field in ['image_path', 'imagePath', 'photo']) {
    addField(json[field]);
  }

  return results.take(_maxMealImages).toList();
}

/// API 저장용 상대 경로 (체중 기록과 동일하게 경로 문자열만 전달)
String _imagePathForApi(String imageUrl) {
  var path = imageUrl.trim();
  final base = ApiClient.baseUrl;
  if (path.startsWith(base)) {
    path = path.substring(base.length);
  }
  if (!path.startsWith('/')) path = '/$path';
  return path;
}

class FoodRepository {
  static const int maxMealImages = _maxMealImages;

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
      return result;
    } catch (e) {
      return [];
    }
  }

  /// 해당 날짜 식사 기록 목록 조회 (날짜별 아침/점심/저녁/간식)
  static Future<List<FoodRecordSummary>> getRecordsForDate(String mbId, DateTime date) async {
    try {
      final trimmedMbId = mbId.trim();
      if (trimmedMbId.isEmpty) {
        return [];
      }
      final dateStr = _localDateYmd(date);
      final uri = Uri.parse(
        '$_baseUrl${ApiEndpoints.foodRecords(dateStr)}&mb_id=${Uri.encodeComponent(trimmedMbId)}',
      );
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode != 200) {
        return [];
      }
      final body = _decodeResponseBody(response.body);
      List<dynamic> list = [];
      if (body is List) list = body;
      else if (body is Map && body['data'] is List) list = body['data'] as List;
      else if (body is Map && body['success'] == true && body['data'] is List) {
        list = body['data'] as List;
      }
      final records = <FoodRecordSummary>[];
      for (final e in list) {
        try {
          final map = _foodRecordMapFromDynamic(e);
          if (map == null) continue;
          records.add(FoodRecordSummary.fromJson(map));
        } catch (err, st) {
          // skip invalid record
        }
      }
      return records;
    } catch (e, st) {
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
      final dateStr = _localDateYmd(date);
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
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
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
      return false;
    }
  }

  /// mealKey(아침/점심/저녁/간식)에 해당하는 food_time
  static String foodTimeFromMealKey(String mealKey) {
    return _mealKeyToFoodTime[mealKey] ?? 'snack';
  }

  /// 해당 끼니(breakfast/lunch/…) 기록 1건 — 이미지·칼로리는 끼니별로 따로 조회
  static FoodRecordSummary? recordForMealKey(
    List<FoodRecordSummary> records,
    String mealKey,
  ) {
    final foodTime = foodTimeFromMealKey(mealKey).toLowerCase();
    for (final r in records) {
      if (r.foodTime.toLowerCase() == foodTime) return r;
    }
    return null;
  }

  /// 식사 사진 업로드 (체중 이미지 업로드와 동일 패턴)
  static Future<String?> uploadMealImage(dynamic imageFile) async {
    try {
      final response = await ApiClient.uploadFile(
        ApiEndpoints.foodUploadImage,
        imageFile,
      );
      if (response.statusCode == 200) {
        final data = _decodeResponseBody(response.body);
        if (data is Map && data['success'] == true && data['url'] != null) {
          final relativeUrl = _bufferFieldToString(data['url']).trim();
          if (relativeUrl.isEmpty || _isCorruptImagePath(relativeUrl)) {
            return null;
          }
          if (relativeUrl.startsWith('http')) return relativeUrl;
          return '${ApiClient.baseUrl}$relativeUrl';
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// API·풀 URL을 상대 경로로 통일 (중복·병합 비교용)
  static String normalizeMealImagePathForStorage(String url) {
    return _imagePathForApi(url);
  }

  /// 식사 기록에 사진 URL 목록 저장 (첫 항목 = 대표사진)
  static Future<bool> updateRecordImagePaths(
    String foodRecordId,
    List<String> imageUrls,
  ) async {
    try {
      final paths = imageUrls
          .where((u) => u.trim().isNotEmpty)
          .map(_imagePathForApi)
          .take(maxMealImages)
          .toList();
      final uri = Uri.parse(
        '$_baseUrl${ApiEndpoints.foodRecordUpdate(foodRecordId)}',
      );
      final body = <String, dynamic>{
        'image_paths': paths,
        'image_path': paths.isEmpty ? '' : paths.first,
      };
      final response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  /// 단일 사진 저장 (기존 목록 덮어쓰기)
  static Future<bool> updateRecordImagePath(
    String foodRecordId,
    String imageUrl,
  ) async {
    return updateRecordImagePaths(foodRecordId, [imageUrl]);
  }
}
