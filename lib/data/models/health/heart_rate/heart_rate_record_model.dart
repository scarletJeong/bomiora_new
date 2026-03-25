class HeartRateRecord {
  final int? id;
  final String mbId;
  final int heartRate;
  final DateTime measuredAt;
  final String status;
  final String sourceType;
  final int? sourceRecordId;
  final DateTime? createdAt;

  const HeartRateRecord({
    this.id,
    required this.mbId,
    required this.heartRate,
    required this.measuredAt,
    this.status = '일상',
    this.sourceType = 'health_sync',
    this.sourceRecordId,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'mb_id': mbId,
      'heart_rate': heartRate,
      'measured_at': measuredAt.toUtc().toIso8601String(),
      'status': status,
      'source_type': sourceType,
      if (sourceRecordId != null) 'source_record_id': sourceRecordId,
    };
  }

  factory HeartRateRecord.fromJson(Map<String, dynamic> json) {
    return HeartRateRecord(
      id: _parseInt(json['id']),
      mbId: _parseString(json['mb_id'] ?? json['mbId']) ?? '',
      heartRate: _parseInt(json['heart_rate'] ?? json['heartRate']) ?? 0,
      measuredAt: _parseDateTime(json['measured_at'] ?? json['measuredAt']),
      status: _parseString(json['status']) ?? '일상',
      sourceType:
          _parseString(json['source_type'] ?? json['sourceType']) ??
          'health_sync',
      sourceRecordId: _parseInt(json['source_record_id'] ?? json['sourceRecordId']),
      createdAt: json['created_at'] != null
          ? _parseDateTime(json['created_at'] ?? json['createdAt'])
          : null,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    final parsed = DateTime.parse(value.toString());
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  static String? _parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) {
      if (value['type'] == 'Buffer' && value['data'] is List) {
        final codes = (value['data'] as List)
            .whereType<num>()
            .map((e) => e.toInt())
            .toList();
        return String.fromCharCodes(codes);
      }
      final nested = value['value'] ?? value['text'] ?? value['name'];
      if (nested is String) return nested;
      return nested?.toString();
    }
    return value.toString();
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
