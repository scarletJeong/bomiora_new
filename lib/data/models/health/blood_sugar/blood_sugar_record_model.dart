import '../../../../core/utils/node_value_parser.dart';

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
      'measured_at': measuredAt.toIso8601String(),
      'blood_sugar': bloodSugar,
      'measurement_type': measurementType,
      'status': status,
    };
  }

  factory BloodSugarRecord.fromJson(Map<String, dynamic> json) {
    final normalized = NodeValueParser.normalizeMap(json);
    final measuredAtValue =
        NodeValueParser.asString(normalized['measured_at']) ??
        NodeValueParser.asString(normalized['measuredAt']);

    return BloodSugarRecord(
      id: NodeValueParser.asInt(normalized['id']),
      mbId:
          NodeValueParser.asString(normalized['mb_id']) ??
          NodeValueParser.asString(normalized['mbId']) ??
          '',
      measuredAt: measuredAtValue != null
          ? (() {
              final dt = DateTime.tryParse(measuredAtValue) ?? DateTime.now();
              return dt.isUtc ? dt.toLocal() : dt;
            })()
          : DateTime.now(),
      bloodSugar:
          NodeValueParser.asInt(normalized['blood_sugar']) ??
          NodeValueParser.asInt(normalized['bloodSugar']) ??
          0,
      measurementType:
          NodeValueParser.asString(normalized['measurement_type']) ??
          NodeValueParser.asString(normalized['measurementType']) ??
          '평상시',
      status: NodeValueParser.asString(normalized['status']),
    );
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
