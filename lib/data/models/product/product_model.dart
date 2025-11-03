import '../../../core/utils/image_url_helper.dart';

class Product {
  final String id;
  final String name;
  final String? description;
  final int price;
  final int? originalPrice;
  final String? imageUrl;
  final String categoryId;
  final String? categoryName;
  final String? productKind; // prescription, general 등
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
    return Product(
      id: json['id']?.toString() ?? json['it_id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['it_name']?.toString() ?? '',
      description: json['description']?.toString() ?? json['it_explan']?.toString(),
      price: _parsePrice(json['price'] ?? json['it_price'] ?? 0),
      originalPrice: _parsePrice(json['originalPrice'] ?? json['it_cust_price']),
      imageUrl: ImageUrlHelper.normalizeThumbnailUrl(
        json['imageUrl']?.toString() ?? 
        json['it_img']?.toString() ?? 
        json['it_img1']?.toString(),
        json['id']?.toString() ?? json['it_id']?.toString(),
      ),
      categoryId: json['categoryId']?.toString() ?? json['ca_id']?.toString() ?? '',
      categoryName: json['categoryName']?.toString() ?? json['ca_name']?.toString(),
      productKind: json['productKind']?.toString() ?? json['it_kind']?.toString(),
      isNew: json['isNew'] ?? json['it_new'] ?? false,
      isBest: json['isBest'] ?? json['it_best'] ?? false,
      stock: json['stock'] ?? json['it_stock_qty'],
      rating: json['rating']?.toDouble() ?? 
              (json['it_rating'] != null ? double.tryParse(json['it_rating'].toString()) : null),
      reviewCount: json['reviewCount'] ?? json['it_review_cnt'],
      additionalInfo: json['additionalInfo'] ?? json,
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
}
