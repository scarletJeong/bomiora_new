import '../../../core/utils/node_value_parser.dart';

class Coupon {
  final int no; // cp_no
  final String id; // cp_id
  final String subject; // cp_subject
  /// 보미오라 cp_method: 0=제품(it_id), 1=카테고리(ca_id), 2=주문금액, 3=배송비
  final int method;
  final String target; // cp_target
  final String userId; // mb_id
  final int zoneId; // cz_id
  final DateTime startDate; // cp_start
  final DateTime endDate; // cp_end
  /// 할인율(%) 또는 할인액(원). % 인지 구분은 [maximum] 참고
  final int price; // cp_price
  final int type; // cp_type (쿠폰 구분 등, 표시는 method 우선)
  final int trunc; // cp_trunc
  final int minimum; // cp_minimum
  /// 0 초과면 `cp_price` 는 할인율(%), 0 이면 `cp_price` 는 할인액(원)
  final int maximum; // cp_maximum
  final int? orderId; // od_id
  final DateTime? datetime; // cp_datetime
  /// API `applied_product` — `적용상품: …` 문구 (카테고리·상품명 조회 결과)
  final String? appliedProduct;

  Coupon({
    required this.no,
    required this.id,
    required this.subject,
    required this.method,
    required this.target,
    required this.userId,
    required this.zoneId,
    required this.startDate,
    required this.endDate,
    required this.price,
    required this.type,
    required this.trunc,
    required this.minimum,
    required this.maximum,
    this.orderId,
    this.datetime,
    this.appliedProduct,
  });

  factory Coupon.fromJson(Map<String, dynamic> json) {
    final normalized = NodeValueParser.normalizeMap(json);
    return Coupon(
      no: NodeValueParser.asInt(normalized['cp_no'] ?? normalized['no']) ?? 0,
      id:
          NodeValueParser.asString(normalized['cp_id']) ??
          NodeValueParser.asString(normalized['id']) ??
          '',
      subject:
          NodeValueParser.asString(normalized['cp_subject']) ??
          NodeValueParser.asString(normalized['subject']) ??
          '',
      method: NodeValueParser.asInt(normalized['cp_method'] ?? normalized['method']) ?? 0,
      target:
          NodeValueParser.asString(normalized['cp_target']) ??
          NodeValueParser.asString(normalized['target']) ??
          '',
      userId:
          NodeValueParser.asString(normalized['mb_id']) ??
          NodeValueParser.asString(normalized['userId']) ??
          '',
      zoneId: NodeValueParser.asInt(normalized['cz_id'] ?? normalized['zoneId']) ?? 0,
      startDate: _parseDate(normalized['cp_start'] ?? normalized['startDate']) ?? DateTime.now(),
      endDate: _parseDate(normalized['cp_end'] ?? normalized['endDate']) ?? DateTime.now(),
      price: NodeValueParser.asInt(normalized['cp_price'] ?? normalized['price']) ?? 0,
      type: NodeValueParser.asInt(normalized['cp_type'] ?? normalized['type']) ?? 0,
      trunc: NodeValueParser.asInt(normalized['cp_trunc'] ?? normalized['trunc']) ?? 0,
      minimum: NodeValueParser.asInt(normalized['cp_minimum'] ?? normalized['minimum']) ?? 0,
      maximum: NodeValueParser.asInt(normalized['cp_maximum'] ?? normalized['maximum']) ?? 0,
      orderId: NodeValueParser.asInt(normalized['od_id'] ?? normalized['orderId']),
      datetime: normalized['cp_datetime'] != null || normalized['datetime'] != null
          ? _parseDateTime(normalized['cp_datetime'] ?? normalized['datetime'])
          : null,
      appliedProduct: NodeValueParser.asString(normalized['applied_product']),
    );
  }

  static DateTime? _parseDate(dynamic dateValue) {
    try {
      if (dateValue == null) return null;
      
      String dateStr = dateValue.toString();
      
      if (dateStr.contains('0000-00-00') || 
          dateStr.contains('1900-01-01') ||
          dateStr.isEmpty) {
        return null;
      }
      
      // 날짜만 있는 경우 (시간 없음)
      if (dateStr.length == 10) {
        return DateTime.parse(dateStr);
      }
      
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseDateTime(dynamic dateValue) {
    try {
      if (dateValue == null) return null;
      
      String dateStr = dateValue.toString();
      
      if (dateStr.contains('0000-00-00') || 
          dateStr.contains('1900-01-01') ||
          dateStr.isEmpty) {
        return null;
      }
      
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  /// 사용 가능한 쿠폰인지 확인
  bool get isAvailable {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    
    // 날짜 유효성: 시작일 <= 오늘 <= 종료일
    final dateValid = !today.isBefore(start) && !today.isAfter(end);
    
    // 미사용: orderId가 null이거나 0
    final notUsed = orderId == null || orderId == 0;
    
    return dateValid && notUsed;
  }

  /// 사용한 쿠폰인지 확인
  bool get isUsed {
    return orderId != null && orderId! > 0;
  }

  /// 만료된 쿠폰인지 확인
  bool get isExpired {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    
    // 종료일이 오늘보다 이전이고, 사용하지 않은 쿠폰
    return today.isAfter(end) && !isUsed;
  }

  /// `cp_maximum` 이 있으면 `cp_price` 는 할인율(%), 없으면 할인액(원)
  bool get _cpPriceIsPercent => maximum > 0;

  /// 할인 금액 표시 텍스트
  String get discountText {
    if (price <= 0) return '할인';
    if (_cpPriceIsPercent) {
      return '$price% 할인';
    }
    return '${_commaWon(price)}원 할인';
  }

  /// 카드 우측(큰 글씨)용: `20%` / `10,000원`
  String get discountPrimaryLabel {
    if (price <= 0) return '—';
    if (_cpPriceIsPercent) {
      return '$price%';
    }
    return '${_commaWon(price)}원';
  }

  /// 포맷된 날짜 범위
  String get formattedDateRange {
    final start = '${startDate.year}.${startDate.month.toString().padLeft(2, '0')}.${startDate.day.toString().padLeft(2, '0')}';
    final end = '${endDate.year}.${endDate.month.toString().padLeft(2, '0')}.${endDate.day.toString().padLeft(2, '0')}';
    return '$start – $end';
  }

  static String _commaWon(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  /// 화면에 그릴 `적용상품:` 한 줄 (API 없을 때 `cp_method` 기준 폴백)
  String get displayAppliedLine {
    final a = appliedProduct?.trim();
    if (a != null && a.isNotEmpty) return a;
    switch (method) {
      case 0:
        if (target.isNotEmpty) return '적용상품: $target 상품할인';
        return '적용상품: 지정 상품 상품할인';
      case 1:
        if (target.isNotEmpty) return '적용상품: $target 상품할인';
        return '적용상품: 지정 카테고리 상품할인';
      case 2:
        return '적용상품: 주문 금액 할인';
      case 3:
        return '적용상품: 배송비 할인';
      default:
        return '';
    }
  }

  /// `최소 n원 이상`, `최대 m원까지` 조합 (둘 다 없으면 null)
  String? get minMaxOrderDescription {
    final hasMin = minimum > 0;
    final hasMax = maximum > 0;
    if (hasMin && hasMax) {
      return '최소 ${_commaWon(minimum)}원 이상, 최대 ${_commaWon(maximum)}원까지';
    }
    if (hasMin) return '최소 ${_commaWon(minimum)}원 이상';
    if (hasMax) return '최대 ${_commaWon(maximum)}원까지';
    return null;
  }
}

