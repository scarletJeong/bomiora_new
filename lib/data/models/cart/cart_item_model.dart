import 'dart:convert';
import '../../../core/utils/node_value_parser.dart';

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
    final normalized = NodeValueParser.normalizeMap(json);
    // ct_option에서 예약 정보 파싱 (예: JSON 문자열 또는 특정 형식)
    String? doctorName;
    DateTime? reservationDate;
    String? reservationTime;
    
    if (normalized['ct_option'] != null &&
        NodeValueParser.asString(normalized['ct_option'])!.isNotEmpty) {
      try {
        final ctOptionStr = NodeValueParser.asString(normalized['ct_option'])!;
        
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
        // 일반 텍스트 옵션은 정상이므로 에러 로그 제거
      }
    }

    // ct_time 파싱
    DateTime? ctTime;
    if (normalized['ct_time'] != null) {
      final timeStr = NodeValueParser.asString(normalized['ct_time']) ?? '';
      if (timeStr.isNotEmpty && timeStr != '0000-00-00 00:00:00') {
        ctTime = DateTime.tryParse(timeStr);
      }
    }

    final rawCtKind =
        NodeValueParser.asString(normalized['ct_kind']) ??
        NodeValueParser.asString(normalized['ctKind']) ??
        'general';
    final normalizedCtKind = _normalizeKind(rawCtKind);

    return CartItem(
      ctId: _parseInt(normalized['ct_id'] ?? normalized['ctId']),
      odId:
          NodeValueParser.asString(normalized['od_id']) ??
          NodeValueParser.asString(normalized['odId']) ??
          '',
      mbId:
          NodeValueParser.asString(normalized['mb_id']) ??
          NodeValueParser.asString(normalized['mbId']) ??
          '',
      itId:
          NodeValueParser.asString(normalized['it_id']) ??
          NodeValueParser.asString(normalized['itId']) ??
          '',
      itName:
          NodeValueParser.asString(normalized['it_name']) ??
          NodeValueParser.asString(normalized['itName']) ??
          '',
      itSubject:
          NodeValueParser.asString(normalized['it_subject']) ??
          NodeValueParser.asString(normalized['itSubject']),
      ctStatus:
          NodeValueParser.asString(normalized['ct_status']) ??
          NodeValueParser.asString(normalized['ctStatus']) ??
          '',
      ctPrice: _parseInt(normalized['ct_price'] ?? normalized['ctPrice'] ?? 0),
      ctOption:
          NodeValueParser.asString(normalized['ct_option']) ??
          NodeValueParser.asString(normalized['ctOption']) ??
          '',
      ctQty: _parseInt(normalized['ct_qty'] ?? normalized['ctQty'] ?? 1),
      ioId:
          NodeValueParser.asString(normalized['io_id']) ??
          NodeValueParser.asString(normalized['ioId']),
      ioPrice:
          normalized['io_price'] != null
              ? _parseInt(normalized['io_price'] ?? normalized['ioPrice'])
              : null,
      ctKind: normalizedCtKind,
      ctTime: ctTime,
      doctorName:
          doctorName ??
          NodeValueParser.asString(normalized['doctor_name']) ??
          NodeValueParser.asString(normalized['doctorName']),
      reservationDate: reservationDate ?? 
                      (normalized['reservation_date'] != null 
                          ? DateTime.tryParse(NodeValueParser.asString(normalized['reservation_date']) ?? '') 
                          : null),
      reservationTime: reservationTime ?? 
                       NodeValueParser.asString(normalized['reservation_time']) ?? 
                       NodeValueParser.asString(normalized['reservationTime']),
      imageUrl: NodeValueParser.asString(normalized['image_url']) ?? 
                NodeValueParser.asString(normalized['imageUrl']) ?? 
                NodeValueParser.asString(normalized['it_img']) ?? 
                NodeValueParser.asString(normalized['it_img1']),
      productType: NodeValueParser.asString(normalized['product_type']) ?? 
                   NodeValueParser.asString(normalized['productType']) ?? 
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

  static String _normalizeKind(String kind) {
    final cleaned = kind
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim()
        .toLowerCase();
    if (cleaned.isEmpty) return 'general';
    return cleaned;
  }

  String get formattedPrice {
    return '${ctPrice.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}원';
  }

  bool get isPrescription {
    final kind = _normalizeKind(ctKind);
    if (kind == 'prescription') {
      return true;
    }
    if (doctorName != null && doctorName!.trim().isNotEmpty) return true;
    if (reservationDate != null) return true;
    if (reservationTime != null && reservationTime!.trim().isNotEmpty) return true;
    return false;
  }
}
