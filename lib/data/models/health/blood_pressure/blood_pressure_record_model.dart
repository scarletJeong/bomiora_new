class BloodPressureRecord {
  final int? id;
  final String mbId;
  final DateTime measuredAt;
  final int systolic; // 수축기 혈압
  final int diastolic; // 이완기 혈압
  final int pulse; // 맥박/심박수
  final String? status; // 혈압 상태 (정상, 고혈압 전단계, 고혈압 등)

  BloodPressureRecord({
    this.id,
    required this.mbId,
    required this.measuredAt,
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    String? status,
  }) : status = status ?? calculateStatus(systolic, diastolic);

  // 혈압 상태 계산 (AHA 및 대한고혈압학회 기준)
  static String calculateStatus(int systolic, int diastolic) {
    // 저혈압: 수축기 < 90 OR 이완기 < 60
    if (systolic < 90 || diastolic < 60) {
      return '저혈압';
    }
    // 고혈압 위기: 수축기 ≥ 180 OR 이완기 ≥ 120 (응급)
    else if (systolic >= 180 || diastolic >= 120) {
      return '고혈압 위기';
    }
    // 2기 고혈압: 수축기 ≥ 140 OR 이완기 ≥ 90
    else if (systolic >= 140 || diastolic >= 90) {
      return '2기 고혈압';
    }
    // 1기 고혈압: 수축기 130-139 OR 이완기 80-89
    else if ((systolic >= 130 && systolic < 140) ||
        (diastolic >= 80 && diastolic < 90)) {
      return '1기 고혈압';
    }
    // 고혈압 전단계: 수축기 120-129 AND 이완기 < 80
    else if (systolic >= 120 && systolic < 130 && diastolic < 80) {
      return '고혈압 전단계';
    }
    // 정상: 수축기 < 120 AND 이완기 < 80
    else if (systolic < 120 && diastolic < 80) {
      return '정상';
    } else {
      return '정상';
    }
  }

  // 혈압 상태별 색상
  static String getStatusColor(String status) {
    switch (status) {
      case '저혈압':
        return 'blue';
      case '정상':
        return 'green';
      case '고혈압 전단계':
        return 'yellow';
      case '1기 고혈압':
        return 'orange';
      case '2기 고혈압':
        return 'red';
      case '고혈압 위기':
        return 'darkred';
      default:
        return 'grey';
    }
  }

  // JSON 변환
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'mb_id': mbId,
      // Always send UTC with timezone suffix (Z) to avoid server/client ambiguity.
      'measured_at': measuredAt.toUtc().toIso8601String(),
      'systolic': systolic,
      'diastolic': diastolic,
      'pulse': pulse,
      'status': status,
    };
  }

  factory BloodPressureRecord.fromJson(Map<String, dynamic> json) {
    return BloodPressureRecord(
      id: _parseInt(json['id']),
      mbId: _parseString(json['mb_id'] ?? json['mbId']) ?? '',
      measuredAt: _parseDateTime(json['measured_at']) ?? DateTime.now(),
      systolic: _parseInt(json['systolic']) ?? 0,
      diastolic: _parseInt(json['diastolic']) ?? 0,
      pulse: _parseInt(json['pulse']) ?? 0,
      status: _parseString(json['status']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    try {
      final parsed = DateTime.parse(value.toString());
      // API가 UTC(Z)로 내려주면 로컬 시간대로 변환해
      // 입력/DB 표시와 그래프 시간이 동일하게 보이도록 맞춘다.
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

  // 복사 메서드
  BloodPressureRecord copyWith({
    int? id,
    String? mbId,
    DateTime? measuredAt,
    int? systolic,
    int? diastolic,
    int? pulse,
    String? status,
  }) {
    return BloodPressureRecord(
      id: id ?? this.id,
      mbId: mbId ?? this.mbId,
      measuredAt: measuredAt ?? this.measuredAt,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      pulse: pulse ?? this.pulse,
      status: status ?? this.status,
    );
  }
}
