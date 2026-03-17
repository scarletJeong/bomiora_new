class BloodSugarRecord {
  final int? id;
  final String mbId;
  final DateTime measuredAt;
  final int bloodSugar; // 혈당 수치 (mg/dL)
  final String measurementType; // 측정 유형 (공복, 식전, 식후, 취침전, 평상시)
  final String? status; // 혈당 상태 (정상, 당뇨 전단계, 당뇨 등)

  BloodSugarRecord({
    this.id,
    required this.mbId,
    required this.measuredAt,
    required this.bloodSugar,
    required this.measurementType,
    String? status,
  }) : status = status ?? calculateStatus(bloodSugar, measurementType);

  // 혈당 상태 계산 (ADA 기준)
  static String calculateStatus(int bloodSugar, String measurementType) {
    switch (measurementType) {
      case '공복':
        if (bloodSugar < 70) {
          return '저혈당';
        } else if (bloodSugar < 100) {
          return '정상';
        } else if (bloodSugar < 126) {
          return '당뇨 전단계';
        } else {
          return '당뇨';
        }
      case '식후':
        if (bloodSugar < 140) {
          return '정상';
        } else if (bloodSugar < 200) {
          return '당뇨 전단계';
        } else {
          return '당뇨';
        }
      case '식전':
        if (bloodSugar < 100) {
          return '정상';
        } else if (bloodSugar < 126) {
          return '당뇨 전단계';
        } else {
          return '당뇨';
        }
      case '취침전':
        if (bloodSugar < 100) {
          return '정상';
        } else if (bloodSugar < 140) {
          return '당뇨 전단계';
        } else {
          return '당뇨';
        }
      case '평상시':
        if (bloodSugar < 100) {
          return '정상';
        } else if (bloodSugar < 126) {
          return '당뇨 전단계';
        } else {
          return '당뇨';
        }
      default:
        return '정상';
    }
  }

  // 혈당 상태별 색상
  static String getStatusColor(String status) {
    switch (status) {
      case '저혈당':
        return 'blue';
      case '정상':
        return 'green';
      case '당뇨 전단계':
        return 'yellow';
      case '당뇨':
        return 'red';
      default:
        return 'grey';
    }
  }

  // 측정 유형별 한글명
  static String getMeasurementTypeKorean(String type) {
    switch (type) {
      case '공복':
        return '공복';
      case '식전':
        return '식전';
      case '식후':
        return '식후';
      case '취침전':
        return '취침전';
      case '평상시':
        return '평상시';
      default:
        return type;
    }
  }

  // 측정 유형별 아이콘
  static String getMeasurementTypeIcon(String type) {
    switch (type) {
      case '공복':
        return '🍽️';
      case '식전':
        return '⏰';
      case '식후':
        return '🥣';
      case '취침전':
        return '🌙';
      case '평상시':
        return '👤';
      default:
        return '📊';
    }
  }

  // JSON 변환
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'mb_id': mbId,
      // Always send UTC with timezone suffix (Z) to avoid server/client ambiguity.
      'measured_at': measuredAt.toUtc().toIso8601String(),
      'blood_sugar': bloodSugar,
      'measurement_type': measurementType,
      'status': status,
    };
  }

  factory BloodSugarRecord.fromJson(Map<String, dynamic> json) {
    return BloodSugarRecord(
      id: _parseInt(json['id']),
      mbId: _parseString(json['mb_id'] ?? json['mbId']) ?? '',
      measuredAt: _parseDateTime(json['measured_at']),
      bloodSugar: _parseInt(json['blood_sugar']) ?? 0,
      measurementType:
          _parseString(json['measurement_type'] ?? json['measurementType']) ??
              '',
      status: _parseString(json['status']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    final parsed = DateTime.parse(value.toString());
    // API가 UTC(Z)로 내려주면 로컬 시간대로 변환해
    // 입력/DB 표시와 그래프 시간이 동일하게 보이도록 맞춘다.
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

  // 복사 메서드
  BloodSugarRecord copyWith({
    int? id,
    String? mbId,
    DateTime? measuredAt,
    int? bloodSugar,
    String? measurementType,
    String? status,
  }) {
    return BloodSugarRecord(
      id: id ?? this.id,
      mbId: mbId ?? this.mbId,
      measuredAt: measuredAt ?? this.measuredAt,
      bloodSugar: bloodSugar ?? this.bloodSugar,
      measurementType: measurementType ?? this.measurementType,
      status: status ?? this.status,
    );
  }
}
