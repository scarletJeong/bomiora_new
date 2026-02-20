import 'dart:convert';

import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/node_value_parser.dart';

class Product {
  final String id;
  final String name;
  final String? description;
  final int price;
  final int? originalPrice;
  final String? imageUrl;
  final String categoryId;
  final String? categoryName;
  final String? productKind; // prescription, general 등 (it_kind 필드)
  final bool isNew;
  final bool isBest;
  final int? stock;
  final double? rating;
  final int? reviewCount;
  final Map<String, dynamic>? additionalInfo;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.originalPrice,
    this.imageUrl,
    required this.categoryId,
    this.categoryName,
    this.productKind,
    this.isNew = false,
    this.isBest = false,
    this.stock,
    this.rating,
    this.reviewCount,
    this.additionalInfo,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final normalized = NodeValueParser.normalizeMap(json);
    final rawFields = _extractRawFields(normalized);
    final mergedAdditionalInfo = <String, dynamic>{
      ...rawFields,
      ...normalized,
    };

    final id =
        NodeValueParser.asString(normalized['id']) ??
        NodeValueParser.asString(normalized['it_id']) ??
        '';

    return Product(
      id: id,
      name:
          NodeValueParser.asString(normalized['name']) ??
          NodeValueParser.asString(normalized['it_name']) ??
          '',
      description:
          NodeValueParser.asString(normalized['description']) ??
          NodeValueParser.asString(rawFields['it_explain']) ??
          NodeValueParser.asString(normalized['it_explain']),
      price: _parsePrice(normalized['price'] ?? normalized['it_price'] ?? 0),
      originalPrice: _parsePrice(normalized['originalPrice'] ?? normalized['it_cust_price']),
      imageUrl: () {
        // 대표 썸네일은 it_img1~it_img9 중 실제 값이 있는 첫 슬롯을 선택
        final selectedValue = _pickFirstThumbnailValue(rawFields) ??
            _pickFirstThumbnailValue(normalized);

        return ImageUrlHelper.normalizeThumbnailUrl(
          selectedValue,
          id,
        );
      }(),
      categoryId:
          NodeValueParser.asString(normalized['categoryId']) ??
          NodeValueParser.asString(normalized['ca_id']) ??
          '',
      categoryName:
          NodeValueParser.asString(normalized['categoryName']) ??
          NodeValueParser.asString(normalized['ca_name']),
      productKind:
          NodeValueParser.asString(normalized['productKind']) ??
          NodeValueParser.asString(normalized['it_kind']) ??
          NodeValueParser.asString(normalized['ct_kind']),
      isNew: _parseBool(normalized['isNew'] ?? normalized['it_new']),
      isBest: _parseBool(normalized['isBest'] ?? normalized['it_best']),
      stock: NodeValueParser.asInt(normalized['stock'] ?? normalized['it_stock_qty']),
      rating:
          NodeValueParser.asDouble(normalized['rating']) ??
          NodeValueParser.asDouble(normalized['it_rating']),
      reviewCount: NodeValueParser.asInt(normalized['reviewCount'] ?? normalized['it_review_cnt']),
      additionalInfo: mergedAdditionalInfo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'originalPrice': originalPrice,
      'imageUrl': imageUrl,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'productKind': productKind,
      'isNew': isNew,
      'isBest': isBest,
      'stock': stock,
      'rating': rating,
      'reviewCount': reviewCount,
      'additionalInfo': additionalInfo,
    };
  }

  static int _parsePrice(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value.replaceAll(',', '')) ?? 0;
    }
    return 0;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase();
    return text == 'true' || text == 'y' || text == '1';
  }

  static String? _pickImageValue(Map<String, dynamic> normalized, int index) {
    final candidates = <String>[
      'it_img$index',
      'itImg$index',
      'itIMG$index',
      'IT_IMG$index',
    ];

    for (final key in candidates) {
      final raw = NodeValueParser.asString(normalized[key]);
      if (raw != null) {
        final trimmed = raw.trim();
        if (trimmed.isNotEmpty && trimmed.toLowerCase() != 'null') {
          return trimmed;
        }
      }
    }

    final normalizedTarget = 'itimg$index';
    for (final entry in normalized.entries) {
      final key = entry.key.toString().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
      if (key == normalizedTarget) {
        final raw = NodeValueParser.asString(entry.value);
        if (raw != null) {
          final trimmed = raw.trim();
          if (trimmed.isNotEmpty && trimmed.toLowerCase() != 'null') {
            return trimmed;
          }
        }
      }
    }

    return null;
  }

  static String? _pickFirstThumbnailValue(Map<String, dynamic> source) {
    for (int i = 1; i <= 9; i++) {
      final value = _pickImageValue(source, i);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  static Map<String, dynamic> _extractRawFields(Map<String, dynamic> normalized) {
    final raw = <String, dynamic>{};
    final additionalInfo = normalized['additionalInfo'];

    if (additionalInfo is Map) {
      raw.addAll(NodeValueParser.normalizeMap(Map<String, dynamic>.from(additionalInfo)));
    } else if (additionalInfo is String && additionalInfo.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(additionalInfo);
        if (decoded is Map) {
          raw.addAll(NodeValueParser.normalizeMap(Map<String, dynamic>.from(decoded)));
        }
      } catch (_) {
        // additionalInfo가 문자열이지만 JSON이 아닌 경우 무시
      }
    }

    // additionalInfo 안에 한 번 더 additionalInfo가 중첩된 형태를 지원
    final nested = raw['additionalInfo'];
    if (nested is Map) {
      raw.addAll(NodeValueParser.normalizeMap(Map<String, dynamic>.from(nested)));
    } else if (nested is String && nested.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(nested);
        if (decoded is Map) {
          raw.addAll(NodeValueParser.normalizeMap(Map<String, dynamic>.from(decoded)));
        }
      } catch (_) {
        // nested additionalInfo가 JSON이 아닌 경우 무시
      }
    }

    return raw;
  }

  String get formattedPrice {
    return '${price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}원';
  }

  String? get formattedOriginalPrice {
    if (originalPrice == null) return null;
    return '${originalPrice!.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}원';
  }

  double? get discountRate {
    if (originalPrice == null || originalPrice! <= 0) return null;
    return ((originalPrice! - price) / originalPrice!) * 100;
  }

  /// 장바구니에 추가할 때 사용할 ct_kind 값 반환
  /// productKind (it_kind)를 기반으로 판단, 없으면 'general'
  String get ctKind {
    if (productKind != null && productKind!.trim().isNotEmpty) {
      final normalized = productKind!.trim().toLowerCase();
      // prescription 관련 값이면 'prescription' 반환
      if (normalized == 'prescription'  ) {
        return 'prescription';
      }
      return normalized;
    }
    return 'general';
  }
}
