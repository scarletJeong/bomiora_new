import 'dart:convert';

import '../../../data/models/delivery/delivery_model.dart';

/// 문의 상세 상품 카드에 그릴 한 줄(본품 또는 추가상품)
class QaInquiryCardItem {
  final String name;
  final String? vendor;
  final String? imageUrl;
  final int? price;
  final int qty;
  final String? optionText;
  final bool showOptions;
  final bool isHerbal;
  final List<QaInquiryCardItem> extras;

  const QaInquiryCardItem({
    required this.name,
    this.vendor,
    this.imageUrl,
    this.price,
    this.qty = 1,
    this.optionText,
    this.showOptions = true,
    this.isHerbal = false,
    this.extras = const [],
  });

  Map<String, dynamic> toJson() => {
        'n': name,
        if ((vendor ?? '').trim().isNotEmpty) 'v': vendor,
        if ((imageUrl ?? '').trim().isNotEmpty) 'i': imageUrl,
        if (price != null) 'p': price,
        'q': qty,
        if ((optionText ?? '').trim().isNotEmpty) 'o': optionText,
        's': showOptions,
        'h': isHerbal,
        if (extras.isNotEmpty)
          'e': extras.map((e) => e.toJson()).toList(),
      };

  factory QaInquiryCardItem.fromJson(Map<String, dynamic> json) {
    final extraRaw = json['e'];
    return QaInquiryCardItem(
      name: (json['n'] ?? '').toString(),
      vendor: json['v']?.toString(),
      imageUrl: json['i']?.toString(),
      price: json['p'] is int ? json['p'] as int : int.tryParse('${json['p']}'),
      qty: json['q'] is int ? json['q'] as int : int.tryParse('${json['q']}') ?? 1,
      optionText: json['o']?.toString(),
      showOptions: json['s'] != false,
      isHerbal: json['h'] == true,
      extras: extraRaw is List
          ? extraRaw
              .whereType<Map>()
              .map((e) => QaInquiryCardItem.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : const [],
    );
  }
}

/// 1:1 문의 작성 전 선택 컨텍스트 + 칩/안내 문구
class QaInquiryDraft {
  final String category; // 상품 | 주문 | 기타
  /// 큰 카테고리 (상품문의, 예약/결제, …) — 주문/상품 공통
  final String? majorCategory;
  /// 문의유형에 따른 상세 내용
  final String? detailCategory;
  final String? itId;
  final String? productName;
  final String? brandName;
  final String? imageUrl;
  final int? price;
  final String? odId;
  final String? orderDate;
  /// 장바구니/주문 옵션 표시용
  final String? optionText;
  /// it_subject (상품명 위 표시)
  final String? itSubject;
  /// 상품선택 탭명 (장바구니/찜한 상품, 주문/배송/취소)
  final String? selectTabLabel;
  /// 상세 카드에 표시할 선택 상품들
  final List<QaInquiryCardItem> cardItems;

  const QaInquiryDraft({
    required this.category,
    this.majorCategory,
    this.detailCategory,
    this.itId,
    this.productName,
    this.brandName,
    this.imageUrl,
    this.price,
    this.odId,
    this.orderDate,
    this.optionText,
    this.itSubject,
    this.selectTabLabel,
    this.cardItems = const [],
  });

  bool get hasTarget =>
      (productName != null && productName!.trim().isNotEmpty) ||
      (odId != null && odId!.trim().isNotEmpty);

  /// 제목 컬럼: 상품/주문 메타는 subject에 저장(화면 비표시), 기타는 카테고리만
  String buildSubject(String message) {
    if (category == '상품' && hasTarget) {
      return _buildTargetSubject('[상품 문의]');
    }
    if (category == '주문' && hasTarget) {
      return _buildTargetSubject('[주문 문의]', includeOrderMeta: true);
    }
    return category;
  }

  String _buildTargetSubject(String header, {bool includeOrderMeta = false}) {
    final buf = StringBuffer(header);
    if (includeOrderMeta) {
      _appendField(buf, '주문번호', odId);
      _appendField(buf, '주문일', orderDate);
    }
    _appendField(buf, '브랜드', brandName);
    _appendField(buf, '품목', itSubject);
    _appendField(buf, '상품', productName);
    _appendField(buf, '옵션', optionText);
    _appendField(buf, '탭', selectTabLabel);
    _appendField(buf, '상세유형', detailCategory);
    _appendField(buf, '상품코드', itId);
    _appendField(buf, '이미지', imageUrl);
    if (price != null) {
      buf.writeln();
      buf.write('가격: $price');
    }
    if (cardItems.length > 1) {
      buf.writeln();
      buf.write('상품수: ${cardItems.length}');
    }
    return buf.toString();
  }

  static const String cardMarker = '[QA_CARD]';
  static const String cardSeparator = '\n---\n';

  String? encodeCardJson() {
    if (cardItems.isEmpty) return null;
    return jsonEncode({
      'tab': selectTabLabel,
      'od': odId,
      'items': cardItems.map((e) => e.toJson()).toList(),
    });
  }

  static Map<String, dynamic>? decodeCardMap(String content) {
    final body = content.trim();
    if (!body.startsWith(cardMarker)) return null;
    final sep = body.indexOf(cardSeparator);
    if (sep < 0) return null;
    final raw = body.substring(cardMarker.length, sep).trim();
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  static List<QaInquiryCardItem> parseCardItems(String content) {
    final map = decodeCardMap(content);
    final raw = map?['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => QaInquiryCardItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static String stripCardBlock(String body) {
    final t = body.trim();
    if (!t.startsWith(cardMarker)) return t;
    final sep = t.indexOf(cardSeparator);
    if (sep < 0) return t;
    return t.substring(sep + cardSeparator.length).trim();
  }

  static void _appendField(StringBuffer buf, String label, String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return;
    buf.writeln();
    buf.write('$label: $trimmed');
  }

  static String? formatOptionText({String? ctOption, String? itSubject}) {
    final opt = (ctOption ?? '').trim();
    final sub = (itSubject ?? '').trim();
    if (opt.contains(' / ')) {
      final parts = opt
          .split(' / ')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.length >= 2) return parts.join(' | ');
    }
    if (sub.isNotEmpty && opt.isNotEmpty) return '$sub | $opt';
    if (opt.isNotEmpty) return opt;
    if (sub.isNotEmpty) return sub;
    return null;
  }

  /// 본문 앞에 상세 카드 JSON을 붙이고, 사용자 메시지는 `---` 뒤에 둔다
  String buildContent(String message) {
    final text = message.trim();
    final json = encodeCardJson();
    if (json == null || json.isEmpty) return text;
    return '$cardMarker\n$json$cardSeparator$text';
  }

  // ── 칩 / CS 안내 (작성·상세 공통) ──

  static const String askPrompt = '어떤 것이 궁금하신가요?';

  /// 기타 카테고리 진입 시 CS 첫 안내 (칩 없음)
  static const String etcAskPrompt =
      '안녕하세요. 보미오라 한의원입니다.\n 궁금한 내용을 입력해 주세요.';

  /// 문의 유형 (랜딩 화면 드롭다운)
  static const List<String> inquiryTypes = [
    '상품문의',
    '예약/결제',
    '배송',
    '교환/반품',
    '취소/환불',
    '이벤트/쿠폰/회원',
    '기타',
  ];

  static const Map<String, List<String>> _detailOptions = {
    '상품문의': [
      '단계추천',
      '복용방법',
      '입고 일정',
      '임산부 복용',
      '위고비/마운자로병행',
      '유통기한',
      '기타',
    ],
    '예약/결제': [
      '예약방법',
      '결제문의',
      '예약시간 변경',
      '제품 단계 변경',
      '현금영수증',
      '기타',
    ],
    '배송': [
      '배송 일정 문의',
      '배송비 문의',
      '해외 배송 문의',
      '배송지 변경 요청',
      '배송 오류',
      '기타',
    ],
    '교환/반품': [
      '교환 신청 관련',
      '반품 신청 관련',
      '교환/반품 철회 신청',
      '기타',
    ],
    '취소/환불': ['취소 문의', '환불 문의', '기타'],
    '이벤트/쿠폰/회원': [
      '이벤트 관련 문의',
      '쿠폰 관련 문의',
      '적립금 관련 문의',
      '리뷰 관련 문의',
      '회원 정보 문의',
      '기타',
    ],
  };

  static const Map<String, String> _guideMessages = {
    '주문': '안녕하세요. 보미오라 한의원입니다.\n [주문문의]에서 궁금하신 사항을 선택해주세요.',
    '상품': '안녕하세요. 보미오라 한의원입니다.\n [상품문의]에서 궁금하신 사항을 선택해주세요.',
    '기타': '안녕하세요. 보미오라 한의원입니다.\n 궁금하신 사항을 입력해주세요.',
  };

  static List<String> _detailOptionsFor(String inquiryType) =>
      _detailOptions[inquiryType.trim()] ?? const [];

  /// 문의 작성 랜딩 — 상세 내용 드롭다운
  static List<String> detailOptionsForInquiryType(String inquiryType) =>
      _detailOptionsFor(inquiryType);

  /// 문의 상세 — 카테고리별 주제 칩
  static List<String> topicsFor(String category, [String? majorCategory]) {
    final type = (majorCategory ?? '').trim();
    if (type.isNotEmpty) return _detailOptionsFor(type);
    return _detailOptionsFor(category);
  }

  static String guideMessage(String category) =>
      _guideMessages[category] ?? '';

  static String? _itSubjectFromItem(OrderItem item) {
    final name = item.itName.trim();
    if (name.isEmpty) return null;
    final subject = item.itSubject.trim();
    if (subject.isEmpty || subject == name) return null;
    return subject;
  }

  static String? vendorLabel({
    String? brandName,
    String? itSubject,
    String? productKind,
  }) {
    final brand = (brandName ?? '').trim();
    if (brand.isNotEmpty) return brand;
    final subject = (itSubject ?? '').trim();
    if (subject.isEmpty) return null;
    return subject;
  }

  static bool isHerbalProduct(String? productKind, String? itSubject) {
    final k = (productKind ?? '').toLowerCase().trim();
    if (k.contains('prescription')) return true;
    final subject = (itSubject ?? '').trim();
    return RegExp(r'보미오라\s*한의원').hasMatch(subject);
  }

  static String? _nonEmpty(String? value) {
    final trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static QaInquiryDraft _fromOrderContext({
    required String odId,
    required String orderDate,
    List<OrderItem> items = const [],
    OrderItem? item,
    String? fallbackProductName,
    int? fallbackPrice,
    String? fallbackOption,
    int? fallbackCount,
  }) {
    final source = items.isNotEmpty
        ? items
        : (item != null ? <OrderItem>[item] : <OrderItem>[]);

    if (source.isNotEmpty) {
      final cards = source.map(_cardFromOrderItem).toList(growable: false);
      final firstName = cards.first.name.trim().isNotEmpty
          ? cards.first.name.trim()
          : '상품';
      final extraCount = cards.length > 1
          ? cards.length - 1
          : ((fallbackCount != null && fallbackCount > 1)
              ? fallbackCount - 1
              : 0);
      final displayName =
          extraCount > 0 ? '$firstName 외 $extraCount건' : firstName;
      return QaInquiryDraft(
        category: '주문',
        itId: _nonEmpty(source.first.itId),
        productName: displayName,
        imageUrl: source.first.imageUrl,
        price: source.first.totalPrice > 0
            ? source.first.totalPrice
            : source.first.ctPrice,
        odId: odId,
        orderDate: orderDate,
        optionText: formatOptionText(
          ctOption: source.first.ctOption,
          itSubject: null,
        ),
        itSubject: _itSubjectFromItem(source.first),
        selectTabLabel: '주문/배송',
        cardItems: cards,
      );
    }

    final count = fallbackCount ?? 1;
    final baseName = fallbackProductName ?? '주문 상품';
    final displayName =
        count > 1 ? '$baseName 외 ${count - 1}건' : baseName;
    return QaInquiryDraft(
      category: '주문',
      productName: displayName,
      price: fallbackPrice,
      odId: odId,
      orderDate: orderDate,
      optionText: fallbackOption,
      selectTabLabel: '주문/배송',
      cardItems: [
        QaInquiryCardItem(
          name: baseName,
          price: fallbackPrice,
          optionText: fallbackOption,
          showOptions: true,
        ),
      ],
    );
  }

  static QaInquiryCardItem _cardFromOrderItem(OrderItem item) {
    final name = item.itName.trim().isNotEmpty ? item.itName.trim() : '상품';
    final kind = orderItemProductKind(item);
    return QaInquiryCardItem(
      name: name,
      vendor: vendorLabel(
        brandName: null,
        itSubject: item.itSubject,
        productKind: kind,
      ),
      imageUrl: item.imageUrl,
      price: item.totalPrice > 0 ? item.totalPrice : item.ctPrice,
      qty: item.ctQty,
      optionText: formatOptionText(ctOption: item.ctOption, itSubject: null),
      showOptions: true,
      isHerbal: isHerbalProduct(kind, item.itSubject),
    );
  }

  /// 주문내역 목록에서 1:1 문의 진입 시 상품·주문 정보 프리필
  factory QaInquiryDraft.fromOrderList(OrderListModel order) =>
      _fromOrderContext(
        odId: order.odId,
        orderDate: order.orderDate,
        items: order.items,
        item: order.items.isNotEmpty ? order.items.first : null,
        fallbackProductName: order.firstProductName,
        fallbackPrice: order.firstProductPrice ?? order.totalPrice,
        fallbackOption: order.firstProductOption,
        fallbackCount: order.odCartCount > 0 ? order.odCartCount : null,
      );

  /// 주문 상세에서 1:1 문의 진입 시 상품·주문 정보 프리필
  factory QaInquiryDraft.fromOrderDetail(OrderDetailModel order) =>
      _fromOrderContext(
        odId: order.odId,
        orderDate: order.orderDate,
        items: order.products,
        item: order.products.isNotEmpty ? order.products.first : null,
        fallbackPrice: order.totalPrice,
        fallbackCount: order.products.isNotEmpty ? order.products.length : null,
      );
}
