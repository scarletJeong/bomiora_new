class WeightRecord {
  final int? id;
  final String mbId;
  final DateTime measuredAt;
  final double weight; // kg
  final double? height; // cm
  final double? bmi;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  WeightRecord({
    this.id,
    required this.mbId,
    required this.measuredAt,
    required this.weight,
    this.height,
    this.bmi,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  // BMI 계산 (키가 있을 때만)
  static double? calculateBMI(double weight, double? height) {
    if (height == null || height <= 0) return null;
    final heightInMeters = height / 100; // cm → m
    final bmi = weight / (heightInMeters * heightInMeters);
    return double.parse(bmi.toStringAsFixed(1)); // 소수점 1자리
  }

  // BMI 상태 텍스트
  String get bmiStatus {
    if (bmi == null) return '';
    if (bmi! < 18.5) return '저체중';
    if (bmi! < 23) return '정상';
    if (bmi! < 25) return '과체중';
    if (bmi! < 30) return '비만';
    return '고도비만';
  }

  // BMI 상태 색상
  static String getBmiStatusColor(double? bmi) {
    if (bmi == null) return 'gray';
    if (bmi < 18.5) return 'blue';
    if (bmi < 23) return 'green';
    if (bmi < 25) return 'orange';
    return 'red';
  }

  factory WeightRecord.fromJson(Map<String, dynamic> json) {
    return WeightRecord(
      id: json['recordId'] ?? json['record_id'] ?? json['id'],
      mbId: (json['mbId'] ?? json['mb_id'] ?? '').toString(),
      measuredAt: _parseDateTime(json['measuredAt'] ?? json['measured_at']),
      weight: (json['weight'] as num).toDouble(),
      height: json['height'] != null ? (json['height'] as num).toDouble() : null,
      bmi: json['bmi'] != null ? (json['bmi'] as num).toDouble() : null,
      notes: json['notes']?.toString(),
      createdAt: (json['createdAt'] ?? json['created_at']) != null 
          ? _parseDateTime(json['createdAt'] ?? json['created_at']) 
          : null,
      updatedAt: (json['updatedAt'] ?? json['updated_at']) != null 
          ? _parseDateTime(json['updatedAt'] ?? json['updated_at']) 
          : null,
    );
  }

  // 안전한 날짜 파싱 함수
  static DateTime _parseDateTime(dynamic dateValue) {
    try {
      if (dateValue == null) {
        return DateTime.now(); // null이면 현재 시간 반환
      }
      
      String dateStr = dateValue.toString();
      
      // 잘못된 날짜 형식 체크
      if (dateStr.contains('0000-00-00') || 
          dateStr.contains('1900-01-01') ||
          dateStr.isEmpty) {
        print('⚠️ 잘못된 날짜 형식 감지: $dateStr, 현재 시간으로 대체');
        return DateTime.now();
      }
      
      return DateTime.parse(dateStr);
    } catch (e) {
      print('❌ 날짜 파싱 오류: $dateValue, 현재 시간으로 대체');
      return DateTime.now();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'record_id': id,
      'mb_id': mbId,
      'measured_at': measuredAt.toIso8601String(),
      'weight': weight,
      if (height != null) 'height': height,
      if (bmi != null) 'bmi': bmi,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }

  WeightRecord copyWith({
    int? id,
    String? mbId,
    DateTime? measuredAt,
    double? weight,
    double? height,
    double? bmi,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WeightRecord(
      id: id ?? this.id,
      mbId: mbId ?? this.mbId,
      measuredAt: measuredAt ?? this.measuredAt,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      bmi: bmi ?? this.bmi,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

