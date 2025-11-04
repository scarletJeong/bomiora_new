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
    return PointHistory(
      id: json['po_id'] ?? json['id'] ?? 0,
      userId: json['mb_id']?.toString() ?? json['userId']?.toString() ?? '',
      dateTime: _parseDateTime(json['po_datetime'] ?? json['dateTime']),
      content: json['po_content']?.toString() ?? json['content']?.toString() ?? '',
      point: json['po_point'] ?? json['point'] ?? 0,
      usePoint: json['po_use_point'] ?? json['usePoint'] ?? 0,
      expired: json['po_expired'] ?? json['expired'] ?? 0,
      expireDate: _parseDateTime(json['po_expire_date'] ?? json['expireDate']),
      useDate: json['po_use_date'] != null || json['useDate'] != null
          ? _parseDateTime(json['po_use_date'] ?? json['useDate'])
          : null,
      finalPoint: json['po_mb_point'] ?? json['finalPoint'] ?? 0,
      relTable: json['po_rel_table']?.toString() ?? json['relTable']?.toString(),
      relId: json['po_rel_id']?.toString() ?? json['relId']?.toString(),
      relAction: json['po_rel_action']?.toString() ?? json['relAction']?.toString(),
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

