import '../../../core/utils/node_value_parser.dart';

/// 주문 상품 모델
class OrderItem {
  final int ctId;
  final String itId;
  final String itName;
  final String? itKind;
  final String itSubject;
  final String? ctOption;
  final int ctQty;
  final int ctPrice;
  final int ioPrice;
  final int totalPrice;
  final String? ctStatus;
  final String? imageUrl; // 상품 이미지 URL

  OrderItem({
    required this.ctId,
    required this.itId,
    required this.itName,
    this.itKind,
    required this.itSubject,
    this.ctOption,
    required this.ctQty,
    required this.ctPrice,
    required this.ioPrice,
    required this.totalPrice,
    this.ctStatus,
    this.imageUrl,
  });

  factory OrderItem.fromJson(Map<dynamic, dynamic> json) {
    final normalized = NodeValueParser.normalizeMap(Map<String, dynamic>.from(json));
    return OrderItem(
      ctId: NodeValueParser.asInt(normalized['ctId'] ?? normalized['ct_id']) ?? 0,
      itId: NodeValueParser.asString(normalized['itId'] ?? normalized['it_id']) ?? '',
      itName: NodeValueParser.asString(
            normalized['itName'] ?? normalized['it_name'] ?? normalized['itSubject'] ?? normalized['it_subject'],
          ) ??
          '',
      itKind: NodeValueParser.asString(normalized['itKind'] ?? normalized['it_kind']),
      itSubject: NodeValueParser.asString(normalized['itSubject'] ?? normalized['it_subject']) ?? '',
      ctOption: NodeValueParser.asString(normalized['ctOption'] ?? normalized['ct_option']),
      ctQty: NodeValueParser.asInt(normalized['ctQty'] ?? normalized['ct_qty']) ?? 0,
      ctPrice: NodeValueParser.asInt(normalized['ctPrice'] ?? normalized['ct_price']) ?? 0,
      ioPrice: NodeValueParser.asInt(normalized['ioPrice'] ?? normalized['io_price']) ?? 0,
      totalPrice: NodeValueParser.asInt(normalized['totalPrice'] ?? normalized['total_price']) ?? 0,
      ctStatus: NodeValueParser.asString(normalized['ctStatus'] ?? normalized['ct_status']),
      imageUrl: NodeValueParser.asString(normalized['imageUrl'] ?? normalized['image_url']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ctId': ctId,
      'itId': itId,
      'itName': itName,
      'itKind': itKind,
      'itSubject': itSubject,
      'ctOption': ctOption,
      'ctQty': ctQty,
      'ctPrice': ctPrice,
      'ioPrice': ioPrice,
      'totalPrice': totalPrice,
      'ctStatus': ctStatus,
      'imageUrl': imageUrl,
    };
  }
}

/// 주문 목록 모델
class OrderListModel {
  final String odId; // String으로 변경 (큰 숫자 정밀도 손실 방지)
  final String orderDate; // yyyy.MM.dd
  final String orderDateTime; // yyyy.MM.dd HH:mm
  final String displayStatus;
  final String odStatus;
  final int totalPrice;
  final int deliveryFee;
  final int odCartCount;
  final bool isPrescriptionOrder;
  final List<OrderItem> items;
  final String? firstProductName;
  final String? firstProductOption;
  final int? firstProductQty;
  final int? firstProductPrice;

  OrderListModel({
    required this.odId,
    required this.orderDate,
    required this.orderDateTime,
    required this.displayStatus,
    required this.odStatus,
    required this.totalPrice,
    this.deliveryFee = 0,
    required this.odCartCount,
    this.isPrescriptionOrder = false,
    required this.items,
    this.firstProductName,
    this.firstProductOption,
    this.firstProductQty,
    this.firstProductPrice,
  });

  factory OrderListModel.fromJson(Map<dynamic, dynamic> json) {
    final normalized = NodeValueParser.normalizeMap(Map<String, dynamic>.from(json));
    List<OrderItem> itemList = [];

    List<OrderItem> parseItemArray(dynamic raw) {
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((item) => OrderItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    if (normalized['items'] != null) {
      itemList = parseItemArray(normalized['items']);
    }
    if (itemList.isEmpty && normalized['products'] != null) {
      itemList = parseItemArray(normalized['products']);
    }
    if (itemList.isEmpty && normalized['cart'] != null) {
      itemList = parseItemArray(normalized['cart']);
    }
    if (itemList.isEmpty && normalized['orderItems'] != null) {
      itemList = parseItemArray(normalized['orderItems']);
    }

    final parsedTotalPrice =
        NodeValueParser.asInt(normalized['totalPrice']) ??
        NodeValueParser.asInt(normalized['total_price']) ??
        NodeValueParser.asInt(normalized['odReceiptPrice']) ??
        NodeValueParser.asInt(normalized['od_receipt_price']) ??
        0;
    final parsedDeliveryFee =
        NodeValueParser.asInt(normalized['deliveryFee']) ??
        NodeValueParser.asInt(normalized['delivery_fee']) ??
        NodeValueParser.asInt(normalized['odSendCost']) ??
        NodeValueParser.asInt(normalized['od_send_cost']) ??
        0;
    final itemsTotalPrice = itemList.fold<int>(0, (sum, item) => sum + item.totalPrice);
    final resolvedTotalPrice = parsedTotalPrice > 0
        ? parsedTotalPrice
        : (itemsTotalPrice > 0 ? itemsTotalPrice : 0);

    return OrderListModel(
      odId: NodeValueParser.asString(normalized['odId']) ?? '0', // String으로 변환 (int도 처리)
      orderDate: NodeValueParser.asString(normalized['orderDate']) ?? '',
      orderDateTime: NodeValueParser.asString(normalized['orderDateTime']) ?? '',
      displayStatus: NodeValueParser.asString(normalized['displayStatus']) ?? '',
      odStatus: NodeValueParser.asString(normalized['odStatus']) ?? '',
      totalPrice: resolvedTotalPrice,
      deliveryFee: parsedDeliveryFee,
      odCartCount: NodeValueParser.asInt(normalized['odCartCount']) ?? 0,
      isPrescriptionOrder: (NodeValueParser.asInt(normalized['isPrescriptionOrder']) ?? 0) == 1 ||
          (NodeValueParser.asString(normalized['isPrescriptionOrder']) ?? '').toLowerCase() == 'true',
      items: itemList,
      firstProductName: NodeValueParser.asString(normalized['firstProductName']),
      firstProductOption: NodeValueParser.asString(normalized['firstProductOption']),
      firstProductQty: NodeValueParser.asInt(normalized['firstProductQty']),
      firstProductPrice: NodeValueParser.asInt(normalized['firstProductPrice']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'odId': odId,
      'orderDate': orderDate,
      'orderDateTime': orderDateTime,
      'displayStatus': displayStatus,
      'odStatus': odStatus,
      'totalPrice': totalPrice,
      'deliveryFee': deliveryFee,
      'odCartCount': odCartCount,
      'isPrescriptionOrder': isPrescriptionOrder,
      'items': items.map((item) => item.toJson()).toList(),
      'firstProductName': firstProductName,
      'firstProductOption': firstProductOption,
      'firstProductQty': firstProductQty,
      'firstProductPrice': firstProductPrice,
    };
  }
}

/// 주문 상세 모델
class OrderDetailModel {
  final String odId; // String으로 변경 (큰 숫자 정밀도 손실 방지)
  final String orderDate;
  final String displayStatus;
  final String odStatus;
  final String recipientName;
  final String recipientPhone;
  final String recipientAddress;
  final String recipientAddressDetail;
  final String? deliveryMessage;
  final String? deliveryCompany;
  final String? trackingNumber;
  final List<OrderItem> products;
  final int productPrice;
  final int deliveryFee;
  final int discountAmount;
  final int totalPrice;
  final bool isPrescriptionOrder;
  final String paymentMethod;
  final String? paymentMethodDetail;
  /// 카드 매출전표/영수증 URL (백엔드가 내려주는 경우)
  final String? cardReceiptUrl;
  final String ordererName;
  final String ordererPhone;
  final String ordererEmail;
  final String? cancelReason;
  final String? cancelType;
  final String? reservationDate; // 예약 날짜 (hp_rsvt_date)
  final String? reservationTime; // 예약 시간 (hp_rsvt_stime)

  OrderDetailModel({
    required this.odId,
    required this.orderDate,
    required this.displayStatus,
    required this.odStatus,
    required this.recipientName,
    required this.recipientPhone,
    required this.recipientAddress,
    required this.recipientAddressDetail,
    this.deliveryMessage,
    this.deliveryCompany,
    this.trackingNumber,
    required this.products,
    required this.productPrice,
    required this.deliveryFee,
    required this.discountAmount,
    required this.totalPrice,
    this.isPrescriptionOrder = false,
    required this.paymentMethod,
    this.paymentMethodDetail,
    this.cardReceiptUrl,
    required this.ordererName,
    required this.ordererPhone,
    required this.ordererEmail,
    this.cancelReason,
    this.cancelType,
    this.reservationDate,
    this.reservationTime,
  });

  factory OrderDetailModel.fromJson(Map<dynamic, dynamic> json) {
    final normalized = NodeValueParser.normalizeMap(Map<String, dynamic>.from(json));
    List<OrderItem> productList = [];
    if (normalized['products'] != null) {
      productList = (normalized['products'] as List)
          .whereType<Map>()
          .map((item) => OrderItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    // odId를 안전하게 String으로 변환 (큰 숫자 정밀도 손실 방지)
    final odIdString = NodeValueParser.asString(normalized['odId']) ?? '0';

    final topLevelPrescription = (NodeValueParser.asInt(normalized['isPrescriptionOrder']) ?? 0) == 1 ||
        (NodeValueParser.asString(normalized['isPrescriptionOrder']) ?? '').toLowerCase() == 'true';
    final inferredPrescription = productList.any(
      (p) => (p.itKind ?? '').toLowerCase() == 'prescription',
    );

    final receiptUrl = NodeValueParser.asString(normalized['cardReceiptUrl']) ??
        NodeValueParser.asString(normalized['card_receipt_url']) ??
        NodeValueParser.asString(normalized['receiptUrl']) ??
        NodeValueParser.asString(normalized['receipt_url']) ??
        NodeValueParser.asString(normalized['kcpReceiptUrl']) ??
        NodeValueParser.asString(normalized['kcp_receipt_url']);

    return OrderDetailModel(
      odId: odIdString,
      orderDate: NodeValueParser.asString(normalized['orderDate']) ?? '',
      displayStatus: NodeValueParser.asString(normalized['displayStatus']) ?? '',
      odStatus: NodeValueParser.asString(normalized['odStatus']) ?? '',
      recipientName: NodeValueParser.asString(normalized['recipientName']) ?? '',
      recipientPhone: NodeValueParser.asString(normalized['recipientPhone']) ?? '',
      recipientAddress: NodeValueParser.asString(normalized['recipientAddress']) ?? '',
      recipientAddressDetail: NodeValueParser.asString(normalized['recipientAddressDetail']) ?? '',
      deliveryMessage: NodeValueParser.asString(normalized['deliveryMessage']),
      deliveryCompany: NodeValueParser.asString(normalized['deliveryCompany']),
      trackingNumber: NodeValueParser.asString(normalized['trackingNumber']),
      products: productList,
      productPrice: NodeValueParser.asInt(normalized['productPrice']) ?? 0,
      deliveryFee: NodeValueParser.asInt(normalized['deliveryFee']) ?? 0,
      discountAmount: NodeValueParser.asInt(normalized['discountAmount']) ?? 0,
      totalPrice: NodeValueParser.asInt(normalized['totalPrice']) ?? 0,
      isPrescriptionOrder: topLevelPrescription || inferredPrescription,
      paymentMethod: NodeValueParser.asString(normalized['paymentMethod']) ?? '',
      paymentMethodDetail: NodeValueParser.asString(normalized['paymentMethodDetail']),
      cardReceiptUrl: receiptUrl,
      ordererName: NodeValueParser.asString(normalized['ordererName']) ?? '',
      ordererPhone: NodeValueParser.asString(normalized['ordererPhone']) ?? '',
      ordererEmail: NodeValueParser.asString(normalized['ordererEmail']) ?? '',
      cancelReason: NodeValueParser.asString(normalized['cancelReason']),
      cancelType: NodeValueParser.asString(normalized['cancelType']),
      reservationDate: NodeValueParser.asString(normalized['reservationDate']),
      reservationTime: NodeValueParser.asString(normalized['reservationTime']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'odId': odId,
      'orderDate': orderDate,
      'displayStatus': displayStatus,
      'odStatus': odStatus,
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'recipientAddress': recipientAddress,
      'recipientAddressDetail': recipientAddressDetail,
      'deliveryMessage': deliveryMessage,
      'deliveryCompany': deliveryCompany,
      'trackingNumber': trackingNumber,
      'products': products.map((item) => item.toJson()).toList(),
      'productPrice': productPrice,
      'deliveryFee': deliveryFee,
      'discountAmount': discountAmount,
      'totalPrice': totalPrice,
      'isPrescriptionOrder': isPrescriptionOrder,
      'paymentMethod': paymentMethod,
      'paymentMethodDetail': paymentMethodDetail,
      'cardReceiptUrl': cardReceiptUrl,
      'ordererName': ordererName,
      'ordererPhone': ordererPhone,
      'ordererEmail': ordererEmail,
      'cancelReason': cancelReason,
      'cancelType': cancelType,
      'reservationDate': reservationDate,
      'reservationTime': reservationTime,
    };
  }
}

