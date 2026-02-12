import '../../../core/utils/node_value_parser.dart';

class Coupon {
  final int no; // cp_no
  final String id; // cp_id
  final String subject; // cp_subject
  final int method; // cp_method (할인 방법: 0=정액할인, 1=정률할인)
  final String target; // cp_target (대상)
  final String userId; // mb_id
  final int zoneId; // cz_id
  final DateTime startDate; // cp_start
  final DateTime endDate; // cp_end
  final int price; // cp_price (할인 금액)
  final int type; // cp_type
  final int trunc; // cp_trunc (할인율, 정률일 때)
  final int minimum; // cp_minimum (최소 주문 금액)
  final int maximum; // cp_maximum (최대 할인 금액)
  final int? orderId; // od_id
  final DateTime? datetime; // cp_datetime

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
      startDate: _parseDate(normalized['cp_start'] ?? normalized['startDate']),
      endDate: _parseDate(normalized['cp_end'] ?? normalized['endDate']),
      price: NodeValueParser.asInt(normalized['cp_price'] ?? normalized['price']) ?? 0,
      type: NodeValueParser.asInt(normalized['cp_type'] ?? normalized['type']) ?? 0,
      trunc: NodeValueParser.asInt(normalized['cp_trunc'] ?? normalized['trunc']) ?? 0,
      minimum: NodeValueParser.asInt(normalized['cp_minimum'] ?? normalized['minimum']) ?? 0,
      maximum: NodeValueParser.asInt(normalized['cp_maximum'] ?? normalized['maximum']) ?? 0,
      orderId: NodeValueParser.asInt(normalized['od_id'] ?? normalized['orderId']),
      datetime: normalized['cp_datetime'] != null || normalized['datetime'] != null
          ? _parseDateTime(normalized['cp_datetime'] ?? normalized['datetime'])
          : null,
    );
  }

  static DateTime _parseDate(dynamic dateValue) {
    try {
      if (dateValue == null) {
        return DateTime.now();
      }
      
      String dateStr = dateValue.toString();
      
      if (dateStr.contains('0000-00-00') || 
          dateStr.contains('1900-01-01') ||
          dateStr.isEmpty) {
        return DateTime.now();
      }
      
      // 날짜만 있는 경우 (시간 없음)
      if (dateStr.length == 10) {
        return DateTime.parse(dateStr);
      }
      
      return DateTime.parse(dateStr);
    } catch (e) {
      return DateTime.now();
    }
  }

  static DateTime _parseDateTime(dynamic dateValue) {
    try {
      if (dateValue == null) {
        return DateTime.now();
      }
      
      String dateStr = dateValue.toString();
      
      if (dateStr.contains('0000-00-00') || 
          dateStr.contains('1900-01-01') ||
          dateStr.isEmpty) {
        return DateTime.now();
      }
      
      return DateTime.parse(dateStr);
    } catch (e) {
      return DateTime.now();
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

  /// 할인 금액 표시 텍스트
  String get discountText {
    if (method == 1) {
      // 정률할인
      return '${trunc}% 할인';
    } else {
      // 정액할인
      return '${price.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      )}원 할인';
    }
  }

  /// 포맷된 날짜 범위
  String get formattedDateRange {
    final start = '${startDate.year}.${startDate.month.toString().padLeft(2, '0')}.${startDate.day.toString().padLeft(2, '0')}';
    final end = '${endDate.year}.${endDate.month.toString().padLeft(2, '0')}.${endDate.day.toString().padLeft(2, '0')}';
    return '$start – $end';
  }
}

