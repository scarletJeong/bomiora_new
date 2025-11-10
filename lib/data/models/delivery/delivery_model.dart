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

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      ctId: json['ctId'] ?? 0,
      itId: json['itId'] ?? '',
      itName: json['itName'] ?? '',
      itSubject: json['itSubject'] ?? '',
      ctOption: json['ctOption'],
      ctQty: json['ctQty'] ?? 0,
      ctPrice: json['ctPrice'] ?? 0,
      ioPrice: json['ioPrice'] ?? 0,
      totalPrice: json['totalPrice'] ?? 0,
      ctStatus: json['ctStatus'],
      imageUrl: json['imageUrl'],
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
  final int odId;
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

  factory OrderListModel.fromJson(Map<String, dynamic> json) {
    List<OrderItem> itemList = [];
    if (json['items'] != null) {
      itemList = (json['items'] as List)
          .map((item) => OrderItem.fromJson(item))
          .toList();
    }

    return OrderListModel(
      odId: json['odId'] ?? 0,
      orderDate: json['orderDate'] ?? '',
      orderDateTime: json['orderDateTime'] ?? '',
      displayStatus: json['displayStatus'] ?? '',
      odStatus: json['odStatus'] ?? '',
      totalPrice: json['totalPrice'] ?? 0,
      odCartCount: json['odCartCount'] ?? 0,
      items: itemList,
      firstProductName: json['firstProductName'],
      firstProductOption: json['firstProductOption'],
      firstProductQty: json['firstProductQty'],
      firstProductPrice: json['firstProductPrice'],
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
  final int odId;
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
  });

  factory OrderDetailModel.fromJson(Map<String, dynamic> json) {
    List<OrderItem> productList = [];
    if (json['products'] != null) {
      productList = (json['products'] as List)
          .map((item) => OrderItem.fromJson(item))
          .toList();
    }

    return OrderDetailModel(
      odId: json['odId'] ?? 0,
      orderDate: json['orderDate'] ?? '',
      displayStatus: json['displayStatus'] ?? '',
      odStatus: json['odStatus'] ?? '',
      recipientName: json['recipientName'] ?? '',
      recipientPhone: json['recipientPhone'] ?? '',
      recipientAddress: json['recipientAddress'] ?? '',
      recipientAddressDetail: json['recipientAddressDetail'] ?? '',
      deliveryMessage: json['deliveryMessage'],
      deliveryCompany: json['deliveryCompany'],
      trackingNumber: json['trackingNumber'],
      products: productList,
      productPrice: json['productPrice'] ?? 0,
      deliveryFee: json['deliveryFee'] ?? 0,
      discountAmount: json['discountAmount'] ?? 0,
      totalPrice: json['totalPrice'] ?? 0,
      paymentMethod: json['paymentMethod'] ?? '',
      paymentMethodDetail: json['paymentMethodDetail'],
      ordererName: json['ordererName'] ?? '',
      ordererPhone: json['ordererPhone'] ?? '',
      ordererEmail: json['ordererEmail'] ?? '',
      cancelReason: json['cancelReason'],
      cancelType: json['cancelType'],
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
    };
  }
}

