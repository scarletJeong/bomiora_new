import 'dart:convert';

import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/node_value_parser.dart';

/// 상품 기관인증 (웹 `it_certification1~10` + agency{n}.png)
class ProductCertification {
  final int id;
  final String label;
  final String imageUrl;

  const ProductCertification({
    required this.id,
    required this.label,
    required this.imageUrl,
  });

  static const Map<int, String> _fallbackLabels = {
    1: 'HGMP 인증',
    2: '기관2',
    3: '기관3',
    4: '기관4',
    5: '기관5',
    6: '기관6',
    7: '기관7',
    8: '기관8',
    9: '기관9',
    10: '기관10',
  };

  static String agencyImageUrl(int id) =>
      'https://bomiora.net/img/detail/agency$id.png';

  factory ProductCertification.fromJson(Map<String, dynamic> json) {
    final id = NodeValueParser.asInt(json['id']) ??
        NodeValueParser.asInt(json['index']) ??
        0;
    final label = NodeValueParser.asString(json['label'])?.trim() ??
        _fallbackLabels[id] ??
        '기관$id';
    final imageUrl = NodeValueParser.asString(json['imageUrl'])?.trim() ??
        NodeValueParser.asString(json['image_url'])?.trim() ??
        agencyImageUrl(id);
    return ProductCertification(id: id, label: label, imageUrl: imageUrl);
  }

  /// API `certifications` 배열 또는 `it_certification1~10` 플래그에서 켠 항목만.
  static List<ProductCertification> listFromProductMap(
    Map<String, dynamic>? info,
  ) {
    if (info == null || info.isEmpty) return const [];
    final rawList = info['certifications'];
    if (rawList is List && rawList.isNotEmpty) {
      final out = <ProductCertification>[];
      for (final e in rawList) {
        if (e is Map) {
          final c = ProductCertification.fromJson(
            Map<String, dynamic>.from(e),
          );
          if (c.id >= 1 && c.id <= 10) out.add(c);
        }
      }
      if (out.isNotEmpty) return out;
    }
    final out = <ProductCertification>[];
    for (var i = 1; i <= 10; i++) {
      final raw = info['it_certification$i'] ?? info['itCertification$i'];
      final on = raw == true ||
          raw == 1 ||
          raw == '1' ||
          (raw is num && raw.toInt() == 1);
      if (!on) continue;
      out.add(
        ProductCertification(
          id: i,
          label: _fallbackLabels[i] ?? '기관$i',
          imageUrl: agencyImageUrl(i),
        ),
      );
    }
    return out;
  }
}

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
  /// 종속선택옵션 1/2 라벨·제목 (관리자 it_depopt*)
  final String? depOption1Subject;
  final String? depOption1Label;
  final String? depOption2Subject;
  final String? depOption2Label;
  /// 연결상품 it_id 목록 (it_supply_items)
  final List<String> supplyItemIds;

  /// 켠 기관인증만 (없으면 빈 목록 → 상세에서 칸 숨김)
  List<ProductCertification> get certifications =>
      ProductCertification.listFromProductMap(additionalInfo);

  /// 품절·판매중지·재고 없음이면 상세로 들어가지 않는다.
  bool get isPurchasable {
    final info = additionalInfo;
    String? text(dynamic value) {
      if (value == null) return null;
      final s = value.toString().trim();
      return s.isEmpty ? null : s;
    }

    final soldout = text(info?['it_soldout'] ?? info?['soldout']);
    if (soldout == '1' || soldout == 'true') return false;
    final use = text(info?['it_use']);
    if (use != null && use != '1') return false;
    final qty = stock;
    if (qty != null && qty < 99999 && qty <= 0) return false;
    return true;
  }

  bool get isTelInquiry {
    final info = additionalInfo;
    final raw = info?['it_tel_inq'] ?? info?['itTelInq'];
    if (raw == true) return true;
    if (raw is num) return raw == 1;
    final s = raw?.toString().trim().toLowerCase();
    return s == '1' || s == 'true';
  }

  /// 바로구매·장바구니 가능 (전화문의 제외)
  bool get isOrderable => isPurchasable && !isTelInquiry;

  int get buyMinQty {
    final info = additionalInfo;
    final raw = info?['it_buy_min_qty'] ?? info?['itBuyMinQty'];
    final n = raw is int
        ? raw
        : raw is num
            ? raw.toInt()
            : int.tryParse('${raw ?? ''}'.trim()) ?? 0;
    return n > 0 ? n : 1;
  }

  /// 0이면 상한 없음(재고만)
  int get buyMaxQty {
    final info = additionalInfo;
    final raw = info?['it_buy_max_qty'] ?? info?['itBuyMaxQty'];
    final n = raw is int
        ? raw
        : raw is num
            ? raw.toInt()
            : int.tryParse('${raw ?? ''}'.trim()) ?? 0;
    return n > 0 ? n : 0;
  }

  /// 스테퍼 상한. 재고가 더 작으면 재고.
  int? get purchaseMaxQty {
    final maxBuy = buyMaxQty;
    final qty = stock;
    final stockCap = (qty != null && qty < 99999) ? qty : null;
    if (maxBuy > 0 && stockCap != null) {
      return maxBuy < stockCap ? maxBuy : stockCap;
    }
    if (maxBuy > 0) return maxBuy;
    return stockCap;
  }

  /// 웹과 동일: 품절(`it_soldout`) + 재입고SMS 허용(`it_stock_sms`)일 때만 신청 가능
  bool get canRequestStockSms {
    final info = additionalInfo;
    String? text(dynamic value) {
      if (value == null) return null;
      final s = value.toString().trim();
      return s.isEmpty ? null : s;
    }

    final soldout = text(info?['it_soldout'] ?? info?['soldout']);
    if (soldout != '1' && soldout != 'true') return false;
    final sms = info?['it_stock_sms'] ?? info?['stock_sms'] ?? info?['itStockSms'];
    return sms == true ||
        sms == 1 ||
        sms == '1' ||
        (sms is num && sms.toInt() == 1);
  }

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
    this.depOption1Subject,
    this.depOption1Label,
    this.depOption2Subject,
    this.depOption2Label,
    this.supplyItemIds = const [],
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
      price: _parsePrice(
        _firstNonZeroPrice(normalized, const [
          'price',
          'it_price',
          'product_price',
        ]),
      ),
      originalPrice: _parsePrice(
        _firstNonZeroPrice(normalized, const [
          'originalPrice',
          'it_cust_price',
          'original_price',
        ]),
      ),
      imageUrl: () {
        // 목록 카드 썸네일은 it_img1. 상세 첫 장은 it_img10, 없으면 it_img1.
        final selectedValue = _pickFirstThumbnailValue(rawFields) ??
            _pickFirstThumbnailValue(normalized) ??
            _pickFallbackImageValue(rawFields) ??
            _pickFallbackImageValue(normalized);

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
          NodeValueParser.asDouble(normalized['it_rating']) ??
          NodeValueParser.asDouble(normalized['it_use_avg']),
      reviewCount: NodeValueParser.asInt(normalized['reviewCount'] ??
          normalized['it_review_cnt'] ??
          normalized['it_use_cnt']),
      additionalInfo: mergedAdditionalInfo,
      depOption1Subject: _pickDepText(
        normalized,
        rawFields,
        'depOption1Subject',
        'it_depopt1_subject',
      ),
      depOption1Label: _pickDepText(
        normalized,
        rawFields,
        'depOption1Label',
        'it_depopt1_label',
      ),
      depOption2Subject: _pickDepText(
        normalized,
        rawFields,
        'depOption2Subject',
        'it_depopt2_subject',
      ),
      depOption2Label: _pickDepText(
        normalized,
        rawFields,
        'depOption2Label',
        'it_depopt2_label',
      ),
      supplyItemIds: _parseSupplyItemIds(normalized, rawFields, id),
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
      'depOption1Subject': depOption1Subject,
      'depOption1Label': depOption1Label,
      'depOption2Subject': depOption2Subject,
      'depOption2Label': depOption2Label,
      'supplyItemIds': supplyItemIds,
    };
  }

  static String? _pickDepText(
    Map<String, dynamic> normalized,
    Map<String, dynamic> rawFields,
    String camelKey,
    String snakeKey,
  ) {
    final v = NodeValueParser.asString(normalized[camelKey]) ??
        NodeValueParser.asString(normalized[snakeKey]) ??
        NodeValueParser.asString(rawFields[camelKey]) ??
        NodeValueParser.asString(rawFields[snakeKey]);
    final t = v?.trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }

  static List<String> _parseSupplyItemIds(
    Map<String, dynamic> normalized,
    Map<String, dynamic> rawFields,
    String selfId,
  ) {
    final raw = normalized['supplyItemIds'] ??
        normalized['it_supply_items'] ??
        rawFields['supplyItemIds'] ??
        rawFields['it_supply_items'];
    final ids = <String>[];
    void push(String? s) {
      final t = (s ?? '').trim();
      if (t.isEmpty || t == selfId) return;
      if (!ids.contains(t)) ids.add(t);
    }

    if (raw is List) {
      for (final e in raw) {
        push(e?.toString());
      }
    } else if (raw is String) {
      for (final part in raw.split(RegExp(r'[,|\s]+'))) {
        push(part);
      }
    }
    return ids;
  }

  static dynamic _firstNonZeroPrice(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    dynamic fallback;
    for (final key in keys) {
      if (!source.containsKey(key) || source[key] == null) continue;
      final parsed = _parsePrice(source[key]);
      if (parsed > 0) return source[key];
      fallback ??= source[key];
    }
    return fallback;
  }

  static int _parsePrice(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) {
      final text = value.replaceAll(',', '').trim();
      return int.tryParse(text) ?? double.tryParse(text)?.round() ?? 0;
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
    return _pickImageValue(source, 1);
  }

  static String? _pickFallbackImageValue(Map<String, dynamic> source) {
    const keys = [
      'image_url',
      'imageUrl',
      'thumbnail',
      'thumbnailUrl',
      'it_img',
    ];
    for (final key in keys) {
      final raw = NodeValueParser.asString(source[key]);
      if (raw != null) {
        final trimmed = raw.trim();
        if (trimmed.isNotEmpty && trimmed.toLowerCase() != 'null') {
          return trimmed;
        }
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

  /// API `it_subject` (한 줄 요약 등) — 목록/상세 JSON 루트 또는 additionalInfo
  String? get itSubject {
    final info = additionalInfo;
    if (info != null) {
      final s = NodeValueParser.asString(info['it_subject']) ??
          NodeValueParser.asString(info['itSubject']);
      if (s != null && s.trim().isNotEmpty) return s.trim();
    }
    return null;
  }

  /// API `it_basic` — 카드/목록용 짧은 설명 (`description`은 `it_explain` 매핑)
  String? get itBasic {
    final info = additionalInfo;
    if (info != null) {
      final s = NodeValueParser.asString(info['it_basic']);
      if (s != null && s.trim().isNotEmpty) return s.trim();
    }
    return null;
  }

  /// JSON 맵에서 `it_mb_inf` 값 추출 (루트·additionalInfo·키 변형)
  static String? readItMbInfFromMap(Map<String, dynamic>? source) {
    if (source == null) return null;
    final normalized = NodeValueParser.normalizeMap(source);

    String? pick(dynamic value) {
      final s = NodeValueParser.asString(value)?.trim();
      if (s == null || s.isEmpty || s.toLowerCase() == 'null') return null;
      return s;
    }

    final direct = pick(normalized['it_mb_inf']) ?? pick(normalized['itMbInf']);
    if (direct != null) return direct;

    final additionalInfo = normalized['additionalInfo'];
    if (additionalInfo is Map) {
      final nested =
          NodeValueParser.normalizeMap(Map<String, dynamic>.from(additionalInfo));
      final nestedVal =
          pick(nested['it_mb_inf']) ?? pick(nested['itMbInf']);
      if (nestedVal != null) return nestedVal;
    }

    for (final entry in normalized.entries) {
      final key =
          entry.key.toString().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
      if (key == 'itmbinf') {
        final v = pick(entry.value);
        if (v != null) return v;
      }
    }
    return null;
  }

  /// 검색 API 원본 item 기준 인플루언서 여부 (it_mb_inf 미포함 응답 보완)
  static bool isInfluencerFromRawJson(Map<String, dynamic> json) {
    if (readItMbInfFromMap(json) != null) return true;

    final normalized = NodeValueParser.normalizeMap(json);
    final name = NodeValueParser.asString(normalized['name']) ??
        NodeValueParser.asString(normalized['it_name']) ??
        '';
    if (name.contains('(@')) return true;

    final categoryId = NodeValueParser.asString(normalized['categoryId']) ??
        NodeValueParser.asString(normalized['ca_id']) ??
        '';
    final kind = (NodeValueParser.asString(normalized['productKind']) ??
            NodeValueParser.asString(normalized['it_kind']) ??
            NodeValueParser.asString(normalized['ct_kind']) ??
            '')
        .toLowerCase();

    // 비대면 일반 카탈로그(10·20·80·50) 밖 기타(40) 채널 상품
    if (kind == 'prescription' && categoryId == '40') return true;

    return false;
  }

  /// 인플루언서 연동 상품 (`it_mb_inf` 값이 있으면 true)
  bool get isInfluencerProduct => isInfluencerFromRawJson({
        'id': id,
        'name': name,
        'categoryId': categoryId,
        'productKind': productKind,
        if (additionalInfo != null) ...additionalInfo!,
        'additionalInfo': additionalInfo,
      });

  /// 상품 쿠폰적용안함 (`it_nocoupon` = 1)
  bool get isNoCoupon {
    final info = additionalInfo;
    final raw = info?['it_nocoupon'] ?? info?['itNocoupon'] ?? info?['nocoupon'];
    return raw == true ||
        raw == 1 ||
        raw == '1' ||
        (raw is num && raw.toInt() == 1);
  }

  /// 목록/카드용 이미지 URL (환경별 경로 정규화)
  String get displayImageUrl => ImageUrlHelper.getImageUrl(imageUrl);

  /// 장바구니에 추가할 때 사용할 ct_kind 값 반환
  /// productKind (it_kind)를 기반으로 판단, 없으면 'general'
  String get ctKind {
    final normalized = (productKind ?? '').trim().toLowerCase();
    if (normalized == 'prescription') return 'prescription';
    return 'general';
  }
}
