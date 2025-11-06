import 'dart:convert';

class CartItem {
  final int ctId; // 장바구니 ID
  final String odId; // 주문 ID
  final String mbId; // 회원 ID
  final String itId; // 상품 ID
  final String itName; // 상품명
  final String? itSubject; // 상품 설명
  final String ctStatus; // 장바구니 상태 (쇼핑, 주문완료 등)
  final int ctPrice; // 장바구니 가격 (총 가격)
  final String ctOption; // 옵션 정보
  final int ctQty; // 수량
  final String? ioId; // 옵션 ID
  final int? ioPrice; // 옵션 가격
  final String ctKind; // 상품 종류 (general, prescription)
  final DateTime? ctTime; // 장바구니 추가 시간
  
  // 처방 상품인 경우 예약 정보
  final String? doctorName; // 담당 한의사 이름
  final DateTime? reservationDate; // 예약 일자
  final String? reservationTime; // 예약 시간 (예: "18:30 ~ 19:00")
  
  // 상품 이미지 URL
  final String? imageUrl;
  
  // 상품 타입 (한의약품 등)
  final String? productType;

  CartItem({
    required this.ctId,
    required this.odId,
    required this.mbId,
    required this.itId,
    required this.itName,
    this.itSubject,
    required this.ctStatus,
    required this.ctPrice,
    this.ctOption = '',
    required this.ctQty,
    this.ioId,
    this.ioPrice,
    required this.ctKind,
    this.ctTime,
    this.doctorName,
    this.reservationDate,
    this.reservationTime,
    this.imageUrl,
    this.productType,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    // ct_option에서 예약 정보 파싱 (예: JSON 문자열 또는 특정 형식)
    String? doctorName;
    DateTime? reservationDate;
    String? reservationTime;
    
    if (json['ct_option'] != null && json['ct_option'].toString().isNotEmpty) {
      try {
        final ctOptionStr = json['ct_option'].toString();
        
        // JSON 문자열인지 확인 (시작이 '{' 또는 '['로 시작하는 경우만 JSON으로 처리)
        if (ctOptionStr.trim().startsWith('{') || ctOptionStr.trim().startsWith('[')) {
          // ct_option이 JSON 문자열인 경우
          final optionData = jsonDecode(ctOptionStr);
          
          if (optionData is Map) {
            doctorName = optionData['doctor_name']?.toString() ?? 
                        optionData['doctorName']?.toString();
            if (optionData['reservation_date'] != null || 
                optionData['reservationDate'] != null) {
              final dateStr = optionData['reservation_date']?.toString() ?? 
                             optionData['reservationDate']?.toString();
              if (dateStr != null && dateStr.isNotEmpty) {
                reservationDate = DateTime.tryParse(dateStr);
              }
            }
            reservationTime = optionData['reservation_time']?.toString() ?? 
                             optionData['reservationTime']?.toString();
          }
        }
        // JSON이 아닌 경우 (예: "소프트 / 3일(6포)")는 그냥 옵션 텍스트로 처리
      } catch (e) {
        // JSON 파싱 실패 시 무시 (일반 텍스트일 수 있음)
        print('⚠️ ct_option 파싱 오류 (무시됨): $e');
      }
    }

    // ct_time 파싱
    DateTime? ctTime;
    if (json['ct_time'] != null) {
      final timeStr = json['ct_time'].toString();
      if (timeStr.isNotEmpty && timeStr != '0000-00-00 00:00:00') {
        ctTime = DateTime.tryParse(timeStr);
      }
    }

    return CartItem(
      ctId: _parseInt(json['ct_id'] ?? json['ctId']),
      odId: json['od_id']?.toString() ?? json['odId']?.toString() ?? '',
      mbId: json['mb_id']?.toString() ?? json['mbId']?.toString() ?? '',
      itId: json['it_id']?.toString() ?? json['itId']?.toString() ?? '',
      itName: json['it_name']?.toString() ?? json['itName']?.toString() ?? '',
      itSubject: json['it_subject']?.toString() ?? json['itSubject']?.toString(),
      ctStatus: json['ct_status']?.toString() ?? json['ctStatus']?.toString() ?? '',
      ctPrice: _parseInt(json['ct_price'] ?? json['ctPrice'] ?? 0),
      ctOption: json['ct_option']?.toString() ?? json['ctOption']?.toString() ?? '',
      ctQty: _parseInt(json['ct_qty'] ?? json['ctQty'] ?? 1),
      ioId: json['io_id']?.toString() ?? json['ioId']?.toString(),
      ioPrice: json['io_price'] != null ? _parseInt(json['io_price'] ?? json['ioPrice']) : null,
      ctKind: json['ct_kind']?.toString() ?? json['ctKind']?.toString() ?? 'general',
      ctTime: ctTime,
      doctorName: doctorName ?? json['doctor_name']?.toString() ?? json['doctorName']?.toString(),
      reservationDate: reservationDate ?? 
                      (json['reservation_date'] != null 
                          ? DateTime.tryParse(json['reservation_date'].toString()) 
                          : null),
      reservationTime: reservationTime ?? 
                       json['reservation_time']?.toString() ?? 
                       json['reservationTime']?.toString(),
      imageUrl: json['image_url']?.toString() ?? 
                json['imageUrl']?.toString() ?? 
                json['it_img']?.toString() ?? 
                json['it_img1']?.toString(),
      productType: json['product_type']?.toString() ?? 
                   json['productType']?.toString() ?? 
                   '한의약품',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ct_id': ctId,
      'od_id': odId,
      'mb_id': mbId,
      'it_id': itId,
      'it_name': itName,
      'it_subject': itSubject,
      'ct_status': ctStatus,
      'ct_price': ctPrice,
      'ct_option': ctOption,
      'ct_qty': ctQty,
      'io_id': ioId,
      'io_price': ioPrice,
      'ct_kind': ctKind,
      'ct_time': ctTime?.toIso8601String(),
      'doctor_name': doctorName,
      'reservation_date': reservationDate?.toIso8601String(),
      'reservation_time': reservationTime,
      'image_url': imageUrl,
      'product_type': productType,
    };
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value.replaceAll(',', '')) ?? 0;
    }
    return 0;
  }

  String get formattedPrice {
    return '${ctPrice.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}원';
  }

  bool get isPrescription => ctKind == 'prescription';
}
