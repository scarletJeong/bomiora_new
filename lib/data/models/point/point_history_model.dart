import '../../../core/utils/node_value_parser.dart';

class PointHistory {
  final int id; // po_id
  final String userId; // mb_id
  final DateTime dateTime; // po_datetime
  final String content; // po_content (사용이유)
  final int point; // po_point (적립 포인트)
  final int usePoint; // po_use_point (사용 포인트)
  final int expired; // po_expired (소멸 포인트)
  final DateTime expireDate; // po_expire_date (소멸 날짜)
  final DateTime? useDate; // po_use_date (사용날짜)
  final int finalPoint; // po_mb_point (최종 포인트)
  final String? relTable; // po_rel_table
  final String? relId; // po_rel_id
  final String? relAction; // po_rel_action

  PointHistory({
    required this.id,
    required this.userId,
    required this.dateTime,
    required this.content,
    required this.point,
    required this.usePoint,
    required this.expired,
    required this.expireDate,
    this.useDate,
    required this.finalPoint,
    this.relTable,
    this.relId,
    this.relAction,
  });

  factory PointHistory.fromJson(Map<String, dynamic> json) {
    final normalized = NodeValueParser.normalizeMap(json);
    return PointHistory(
      id: NodeValueParser.asInt(normalized['po_id'] ?? normalized['id']) ?? 0,
      userId:
          NodeValueParser.asString(normalized['mb_id']) ??
          NodeValueParser.asString(normalized['userId']) ??
          '',
      dateTime: _parseDateTime(normalized['po_datetime'] ?? normalized['dateTime']),
      content:
          NodeValueParser.asString(normalized['po_content']) ??
          NodeValueParser.asString(normalized['content']) ??
          '',
      point: NodeValueParser.asInt(normalized['po_point'] ?? normalized['point']) ?? 0,
      usePoint:
          NodeValueParser.asInt(normalized['po_use_point'] ?? normalized['usePoint']) ??
          0,
      expired: NodeValueParser.asInt(normalized['po_expired'] ?? normalized['expired']) ?? 0,
      expireDate: _parseDateTime(normalized['po_expire_date'] ?? normalized['expireDate']),
      useDate: normalized['po_use_date'] != null || normalized['useDate'] != null
          ? _parseDateTime(normalized['po_use_date'] ?? normalized['useDate'])
          : null,
      finalPoint:
          NodeValueParser.asInt(normalized['po_mb_point'] ?? normalized['finalPoint']) ??
          0,
      relTable:
          NodeValueParser.asString(normalized['po_rel_table']) ??
          NodeValueParser.asString(normalized['relTable']),
      relId:
          NodeValueParser.asString(normalized['po_rel_id']) ??
          NodeValueParser.asString(normalized['relId']),
      relAction:
          NodeValueParser.asString(normalized['po_rel_action']) ??
          NodeValueParser.asString(normalized['relAction']),
    );
  }

  static DateTime _parseDateTime(dynamic dateValue) {
    try {
      if (dateValue == null) {
        return DateTime.now();
      }
      
      String dateStr = dateValue.toString();
      
      if (dateStr.contains('0000-00-00') || 
          dateStr.contains('1900-01-01') ||
          dateStr.contains('9999-12-31') ||
          dateStr.isEmpty) {
        return DateTime.now().add(const Duration(days: 365)); // 기본값: 1년 후
      }
      
      return DateTime.parse(dateStr);
    } catch (e) {
      return DateTime.now().add(const Duration(days: 365));
    }
  }

  /// 적립 내역인지 확인
  bool get isEarned => point > 0;
  
  /// 사용 내역인지 확인
  bool get isUsed => usePoint > 0;
  
  /// 포인트 변동량 (적립은 +, 사용은 -)
  int get changeAmount => point - usePoint;
  
  /// 포맷된 날짜 (YYYY.MM.DD)
  String get formattedDate {
    return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')}';
  }
  
  /// 포맷된 만료일 (YYYY.MM.DD)
  String get formattedExpireDate {
    return '${expireDate.year}.${expireDate.month.toString().padLeft(2, '0')}.${expireDate.day.toString().padLeft(2, '0')}';
  }
}

