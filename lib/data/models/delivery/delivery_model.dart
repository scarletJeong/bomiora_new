import '../../../core/utils/node_value_parser.dart';

/// 주문 상품 모델
class OrderItem {
  final int ctId;
  final String itId;
  final String itName;
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
      ctId: NodeValueParser.asInt(normalized['ctId']) ?? 0,
      itId: NodeValueParser.asString(normalized['itId']) ?? '',
      itName: NodeValueParser.asString(normalized['itName']) ?? '',
      itSubject: NodeValueParser.asString(normalized['itSubject']) ?? '',
      ctOption: NodeValueParser.asString(normalized['ctOption']),
      ctQty: NodeValueParser.asInt(normalized['ctQty']) ?? 0,
      ctPrice: NodeValueParser.asInt(normalized['ctPrice']) ?? 0,
      ioPrice: NodeValueParser.asInt(normalized['ioPrice']) ?? 0,
      totalPrice: NodeValueParser.asInt(normalized['totalPrice']) ?? 0,
      ctStatus: NodeValueParser.asString(normalized['ctStatus']),
      imageUrl: NodeValueParser.asString(normalized['imageUrl']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ctId': ctId,
      'itId': itId,
      'itName': itName,
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
  final int odCartCount;
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
    required this.odCartCount,
    required this.items,
    this.firstProductName,
    this.firstProductOption,
    this.firstProductQty,
    this.firstProductPrice,
  });

  factory OrderListModel.fromJson(Map<dynamic, dynamic> json) {
    final normalized = NodeValueParser.normalizeMap(Map<String, dynamic>.from(json));
    List<OrderItem> itemList = [];
    if (normalized['items'] != null) {
      itemList = (normalized['items'] as List)
          .whereType<Map>()
          .map((item) => OrderItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    return OrderListModel(
      odId: NodeValueParser.asString(normalized['odId']) ?? '0', // String으로 변환 (int도 처리)
      orderDate: NodeValueParser.asString(normalized['orderDate']) ?? '',
      orderDateTime: NodeValueParser.asString(normalized['orderDateTime']) ?? '',
      displayStatus: NodeValueParser.asString(normalized['displayStatus']) ?? '',
      odStatus: NodeValueParser.asString(normalized['odStatus']) ?? '',
      totalPrice: NodeValueParser.asInt(normalized['totalPrice']) ?? 0,
      odCartCount: NodeValueParser.asInt(normalized['odCartCount']) ?? 0,
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
      'odCartCount': odCartCount,
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
  final String paymentMethod;
  final String? paymentMethodDetail;
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
    required this.paymentMethod,
    this.paymentMethodDetail,
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
      paymentMethod: NodeValueParser.asString(normalized['paymentMethod']) ?? '',
      paymentMethodDetail: NodeValueParser.asString(normalized['paymentMethodDetail']),
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
      'paymentMethod': paymentMethod,
      'paymentMethodDetail': paymentMethodDetail,
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

