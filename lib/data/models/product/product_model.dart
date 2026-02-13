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
          NodeValueParser.asString(normalized['it_explan']),
      price: _parsePrice(normalized['price'] ?? normalized['it_price'] ?? 0),
      originalPrice: _parsePrice(normalized['originalPrice'] ?? normalized['it_cust_price']),
      imageUrl: ImageUrlHelper.normalizeThumbnailUrl(
        NodeValueParser.asString(normalized['imageUrl']) ??
            NodeValueParser.asString(normalized['it_img']) ??
            NodeValueParser.asString(normalized['it_img1']),
        id,
      ),
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
      additionalInfo: normalized,
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
