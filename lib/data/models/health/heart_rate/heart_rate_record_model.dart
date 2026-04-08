class HeartRateRecord {
  final int? id;
  final String mbId;
  final int heartRate;
  final DateTime measuredAt;
  final String status;
  final String sourceType;
  final int? sourceRecordId;
  final DateTime? createdAt;

  /// 그래프 색상 등 UI에서 운동 구간 여부 판별
  bool get isExerciseForChart => statusMeansExercise(status);

  /// API/입력값 표기 차이 흡수 (공백, zero-width, 영문 등)
  static bool statusMeansExercise(String status) {
    final s = status
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .trim();
    if (s == '운동') return true;
    final lower = s.toLowerCase();
    return lower == 'exercise' || lower == 'workout' || lower == 'active';
  }

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
      measuredAt: _parseDateTime(json['measured_at'] ?? json['measuredAt']) ?? DateTime.now(),
      status: _statusFromJson(json),
      sourceType:
          _parseString(json['source_type'] ?? json['sourceType']) ??
          'health_sync',
      sourceRecordId: _parseInt(json['source_record_id'] ?? json['sourceRecordId']),
      createdAt: json['created_at'] != null
          ? _parseDateTime(json['created_at'] ?? json['createdAt'])
          : null,
    );
  }

  /// API마다 키가 달라질 수 있음. 빈 문자열은 기본값으로 간주.
  static String _statusFromJson(Map<String, dynamic> json) {
    const keys = [
      'status',
      'hr_status',
      'Status',
      'measurement_status',
      'measure_type',
      'activity_type',
      'record_status',
    ];
    for (final k in keys) {
      final s = _parseString(json[k]);
      if (s != null && s.trim().isNotEmpty) return s.trim();
    }
    return '일상';
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    try {
      final parsed = DateTime.parse(value.toString());
      return parsed.isUtc ? parsed.toLocal() : parsed;
    } catch (_) {
      return null;
    }
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
