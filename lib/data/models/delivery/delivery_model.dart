import '../../../core/utils/node_value_parser.dart';

/// 라인아이템의 상품유형 문자열 (`prescription` | `general` | '').
String orderItemProductKind(OrderItem item) {
  final ck = (item.ctKind ?? '').toLowerCase().trim();
  if (ck == 'prescription' || ck == 'general') return ck;
  final ik = (item.itKind ?? '').toLowerCase().trim();
  if (ik == 'prescription' || ik == 'general') return ik;
  return '';
}

/// API 플래그 + 라인아이템 kind로 최종 비대면 여부 결정.
/// kind가 있으면 그걸 우선하고, 전부 비어 있을 때만 health profile 플래그 사용.
bool resolveIsPrescriptionOrder({
  required bool topLevelFlag,
  required List<OrderItem> items,
}) {
  if (items.isEmpty) return topLevelFlag;
  final mains = items
      .where((p) => (p.parent ?? '').toString().trim().isEmpty)
      .toList();
  final check = mains.isNotEmpty ? mains : items;
  final kinds = check.map(orderItemProductKind).toList();
  if (kinds.any((k) => k == 'prescription')) return true;
  if (kinds.any((k) => k == 'general')) return false;
  return topLevelFlag;
}

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
  /// 옵션 ID (`io_id`)
  final String? ioId;
  /// 장바구니 kind (`ct_kind`) — prescription | general
  final String? ctKind;
  /// 추가상품이면 부모 상품 it_id, 본품이면 null/빈값
  final String? parent;
  final int ioType;

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
    this.ioId,
    this.ctKind,
    this.parent,
    this.ioType = 0,
  });

  factory OrderItem.fromJson(Map<dynamic, dynamic> json) {
    final normalized = NodeValueParser.normalizeMap(Map<String, dynamic>.from(json));
    return OrderItem(
      ctId: NodeValueParser.asInt(normalized['ctId'] ?? normalized['ct_id']) ?? 0,
      itId: NodeValueParser.asString(normalized['itId'] ?? normalized['it_id']) ?? '',
      itName: NodeValueParser.asString(
            normalized['itName'] ??
                normalized['it_name'] ??
                normalized['item_name'] ??
                normalized['itemName'],
          ) ??
          '',
      itKind: NodeValueParser.asString(normalized['itKind'] ?? normalized['it_kind']),
      itSubject: NodeValueParser.asString(
            normalized['itSubject'] ?? normalized['it_subject'],
          ) ??
          '',
      ctOption: NodeValueParser.asString(normalized['ctOption'] ?? normalized['ct_option']),
      ctQty: NodeValueParser.asInt(normalized['ctQty'] ?? normalized['ct_qty']) ?? 0,
      ctPrice: NodeValueParser.asInt(normalized['ctPrice'] ?? normalized['ct_price']) ?? 0,
      ioPrice: NodeValueParser.asInt(normalized['ioPrice'] ?? normalized['io_price']) ?? 0,
      totalPrice: NodeValueParser.asInt(normalized['totalPrice'] ?? normalized['total_price']) ?? 0,
      ctStatus: NodeValueParser.asString(normalized['ctStatus'] ?? normalized['ct_status']),
      imageUrl: NodeValueParser.asString(
            normalized['imageUrl'] ??
                normalized['image_url'] ??
                normalized['itImg1'] ??
                normalized['it_img1'] ??
                normalized['productImage'] ??
                normalized['product_image'],
          ),
      ioId: NodeValueParser.asString(normalized['ioId'] ?? normalized['io_id']),
      ctKind: NodeValueParser.asString(normalized['ctKind'] ?? normalized['ct_kind']),
      parent: () {
        final p = NodeValueParser.asString(
              normalized['parent'] ??
                  normalized['parent_it_id'] ??
                  normalized['parentItId'],
            ) ??
            '';
        if (p.trim().isNotEmpty) return p.trim();
        final ck = NodeValueParser.asString(
              normalized['ctKind'] ?? normalized['ct_kind'],
            ) ??
            '';
        if (ck.toLowerCase().startsWith('supply_add|')) {
          final id = ck.substring('supply_add|'.length).trim();
          return id.isEmpty ? null : id;
        }
        return null;
      }(),
      ioType: NodeValueParser.asInt(normalized['ioType'] ?? normalized['io_type']) ?? 0,
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
      'ioId': ioId,
      'ctKind': ctKind,
      'parent': parent,
      'parent_it_id': parent,
      'ioType': ioType,
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
  /// 상담(처방) 완료 — hp_9=prescription + hp_10=completion + hp_mdatetime
  final bool isConsultationDone;
  final List<OrderItem> items;
  final String? firstProductName;
  final String? firstProductOption;
  final int? firstProductQty;
  final int? firstProductPrice;
  final String recipientName;
  final String recipientPhone;
  final String recipientAddress;
  final String recipientAddressDetail;

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
    this.isConsultationDone = false,
    required this.items,
    this.firstProductName,
    this.firstProductOption,
    this.firstProductQty,
    this.firstProductPrice,
    this.recipientName = '',
    this.recipientPhone = '',
    this.recipientAddress = '',
    this.recipientAddressDetail = '',
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

    final topLevelPrescription =
        (NodeValueParser.asInt(normalized['isPrescriptionOrder']) ?? 0) == 1 ||
            (NodeValueParser.asString(normalized['isPrescriptionOrder']) ?? '')
                    .toLowerCase() ==
                'true';
    final consultationDone =
        (NodeValueParser.asInt(normalized['isConsultationDone']) ?? 0) == 1 ||
            (NodeValueParser.asString(normalized['isConsultationDone']) ?? '')
                    .toLowerCase() ==
                'true' ||
            (NodeValueParser.asInt(normalized['is_consultation_done']) ?? 0) == 1;

    return OrderListModel(
      odId: NodeValueParser.asString(normalized['odId']) ?? '0', // String으로 변환 (int도 처리)
      orderDate: NodeValueParser.asString(normalized['orderDate']) ?? '',
      orderDateTime: NodeValueParser.asString(normalized['orderDateTime']) ?? '',
      displayStatus: NodeValueParser.asString(normalized['displayStatus']) ?? '',
      odStatus: NodeValueParser.asString(normalized['odStatus']) ?? '',
      totalPrice: resolvedTotalPrice,
      deliveryFee: parsedDeliveryFee,
      odCartCount: NodeValueParser.asInt(normalized['odCartCount']) ?? 0,
      isPrescriptionOrder: resolveIsPrescriptionOrder(
        topLevelFlag: topLevelPrescription,
        items: itemList,
      ),
      isConsultationDone: consultationDone,
      items: itemList,
      firstProductName: NodeValueParser.asString(normalized['firstProductName']),
      firstProductOption: NodeValueParser.asString(normalized['firstProductOption']),
      firstProductQty: NodeValueParser.asInt(normalized['firstProductQty']),
      firstProductPrice: NodeValueParser.asInt(normalized['firstProductPrice']),
      recipientName:
          NodeValueParser.asString(normalized['recipientName']) ?? '',
      recipientPhone:
          NodeValueParser.asString(normalized['recipientPhone']) ?? '',
      recipientAddress:
          NodeValueParser.asString(normalized['recipientAddress']) ?? '',
      recipientAddressDetail:
          NodeValueParser.asString(normalized['recipientAddressDetail']) ?? '',
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
      'isConsultationDone': isConsultationDone,
      'items': items.map((item) => item.toJson()).toList(),
      'firstProductName': firstProductName,
      'firstProductOption': firstProductOption,
      'firstProductQty': firstProductQty,
      'firstProductPrice': firstProductPrice,
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'recipientAddress': recipientAddress,
      'recipientAddressDetail': recipientAddressDetail,
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
  /// 쿠폰 합계 (장바구니·배송비·주문 쿠폰)
  final int couponDiscount;
  /// 포인트 사용액
  final int pointDiscount;
  final int totalPrice;
  /// 취소 금액 (`od_cancel_price`)
  final int cancelPrice;
  final bool isPrescriptionOrder;
  /// 상담(처방) 완료 — hp_9=prescription + hp_10=completion + hp_mdatetime
  final bool isConsultationDone;
  final String paymentMethod;
  final String? paymentMethodDetail;
  /// KCP 거래번호 (`od_tno`) — 영수증 URL 등
  final String? odTno;
  /// 카드 승인번호 (`od_app_no`)
  final String? odAppNo;
  /// 가상계좌 등 원문 `od_bank_account` (은행/계좌/입금기한)
  final String? odBankAccount;
  /// 가상계좌 예금주 (`od_deposit_name`)
  final String? odDepositName;
  /// 카드 매출전표/영수증 URL (백엔드가 내려주는 경우)
  final String? cardReceiptUrl;
  final String ordererName;
  final String ordererPhone;
  final String ordererEmail;
  final String? cancelReason;
  final String? cancelType;
  /// 취소일시 (`od_shop_memo` / `od_mod_history`에서 추출)
  final String? cancelDate;
  /// 표시용 취소 사유: 고객요청 / 입금기한만료 / 고객요청(관리자) / 기타
  final String? cancelReasonLabel;
  final String? reservationDate; // 예약 날짜 (hp_rsvt_date)
  final String? reservationTime; // 예약 시작 (hp_rsvt_stime)
  final String? reservationEndTime; // 예약 종료 (hp_rsvt_etime)

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
    this.couponDiscount = 0,
    this.pointDiscount = 0,
    required this.totalPrice,
    this.cancelPrice = 0,
    this.isPrescriptionOrder = false,
    this.isConsultationDone = false,
    required this.paymentMethod,
    this.paymentMethodDetail,
    this.odTno,
    this.odAppNo,
    this.odBankAccount,
    this.odDepositName,
    this.cardReceiptUrl,
    required this.ordererName,
    required this.ordererPhone,
    required this.ordererEmail,
    this.cancelReason,
    this.cancelType,
    this.cancelDate,
    this.cancelReasonLabel,
    this.reservationDate,
    this.reservationTime,
    this.reservationEndTime,
  });

  /// 목록 카드 정보로 상세 화면을 즉시 그릴 때 사용 (이후 상세 API로 덮어씀)
  factory OrderDetailModel.fromListPreview(OrderListModel order) {
    return OrderDetailModel(
      odId: order.odId,
      orderDate: order.orderDateTime.isNotEmpty
          ? order.orderDateTime
          : order.orderDate,
      displayStatus: order.displayStatus,
      odStatus: order.odStatus,
      recipientName: order.recipientName,
      recipientPhone: order.recipientPhone,
      recipientAddress: order.recipientAddress,
      recipientAddressDetail: order.recipientAddressDetail,
      products: List<OrderItem>.from(order.items),
      productPrice: 0,
      deliveryFee: order.deliveryFee,
      discountAmount: 0,
      totalPrice: order.totalPrice,
      isPrescriptionOrder: order.isPrescriptionOrder,
      isConsultationDone: order.isConsultationDone,
      paymentMethod: '',
      ordererName: '',
      ordererPhone: '',
      ordererEmail: '',
    );
  }

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

    final topLevelPrescription =
        (NodeValueParser.asInt(normalized['isPrescriptionOrder']) ?? 0) == 1 ||
            (NodeValueParser.asString(normalized['isPrescriptionOrder']) ?? '')
                    .toLowerCase() ==
                'true';
    final consultationDone =
        (NodeValueParser.asInt(normalized['isConsultationDone']) ?? 0) == 1 ||
            (NodeValueParser.asString(normalized['isConsultationDone']) ?? '')
                    .toLowerCase() ==
                'true' ||
            (NodeValueParser.asInt(normalized['is_consultation_done']) ?? 0) == 1;

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
      couponDiscount:
          NodeValueParser.asInt(normalized['couponDiscount'] ?? normalized['coupon_discount']) ?? 0,
      pointDiscount:
          NodeValueParser.asInt(normalized['pointDiscount'] ?? normalized['point_discount']) ?? 0,
      totalPrice: NodeValueParser.asInt(normalized['totalPrice']) ?? 0,
      cancelPrice: NodeValueParser.asInt(
            normalized['cancelPrice'] ?? normalized['od_cancel_price'],
          ) ??
          0,
      isPrescriptionOrder: resolveIsPrescriptionOrder(
        topLevelFlag: topLevelPrescription,
        items: productList,
      ),
      isConsultationDone: consultationDone,
      paymentMethod: NodeValueParser.asString(normalized['paymentMethod']) ?? '',
      paymentMethodDetail: NodeValueParser.asString(normalized['paymentMethodDetail']),
      odTno: NodeValueParser.asString(normalized['odTno'] ?? normalized['od_tno']),
      odAppNo: NodeValueParser.asString(normalized['odAppNo'] ?? normalized['od_app_no']),
      odBankAccount: NodeValueParser.asString(normalized['odBankAccount'] ?? normalized['od_bank_account']),
      odDepositName: NodeValueParser.asString(
        normalized['odDepositName'] ?? normalized['od_deposit_name'],
      ),
      cardReceiptUrl: receiptUrl,
      ordererName: NodeValueParser.asString(normalized['ordererName']) ?? '',
      ordererPhone: NodeValueParser.asString(normalized['ordererPhone']) ?? '',
      ordererEmail: NodeValueParser.asString(normalized['ordererEmail']) ?? '',
      cancelReason: NodeValueParser.asString(normalized['cancelReason']),
      cancelType: NodeValueParser.asString(normalized['cancelType']),
      cancelDate: NodeValueParser.asString(
        normalized['cancelDate'] ?? normalized['cancel_date'],
      ),
      cancelReasonLabel: NodeValueParser.asString(
        normalized['cancelReasonLabel'] ?? normalized['cancel_reason_label'],
      ),
      reservationDate: NodeValueParser.asString(normalized['reservationDate']),
      reservationTime: NodeValueParser.asString(normalized['reservationTime']),
      reservationEndTime: NodeValueParser.asString(
        normalized['reservationEndTime'] ?? normalized['reservation_end_time'],
      ),
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
      'couponDiscount': couponDiscount,
      'pointDiscount': pointDiscount,
      'totalPrice': totalPrice,
      'cancelPrice': cancelPrice,
      'isPrescriptionOrder': isPrescriptionOrder,
      'isConsultationDone': isConsultationDone,
      'paymentMethod': paymentMethod,
      'paymentMethodDetail': paymentMethodDetail,
      'odTno': odTno,
      'odAppNo': odAppNo,
      'odBankAccount': odBankAccount,
      'odDepositName': odDepositName,
      'cardReceiptUrl': cardReceiptUrl,
      'ordererName': ordererName,
      'ordererPhone': ordererPhone,
      'ordererEmail': ordererEmail,
      'cancelReason': cancelReason,
      'cancelType': cancelType,
      'cancelDate': cancelDate,
      'cancelReasonLabel': cancelReasonLabel,
      'reservationDate': reservationDate,
      'reservationTime': reservationTime,
      'reservationEndTime': reservationEndTime,
    };
  }
}

