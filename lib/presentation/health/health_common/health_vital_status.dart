import 'package:flutter/material.dart';

import '../../../data/models/health/blood_pressure/blood_pressure_record_model.dart';
import '../../../data/models/health/blood_sugar/blood_sugar_record_model.dart';

/// 혈당·혈압 상태 문구와 색.
/// 판정은 [BloodSugarRecord.calculateStatus], [BloodPressureRecord.calculateStatus]만 사용한다.
class HealthVitalStatus {
  static const Color normalBg = Color(0xFF71D375);
  static const Color normalFg = Color(0xFF1F8154);
  static const Color cautionBg = Color(0xFFFFE78B);
  static const Color stageBg = Color(0xFFFEAF8E);
  static const Color dangerBg = Color(0xFFFF6161);
  static const Color crisisBg = Color(0xFFC62828);
  static const Color lowBg = Color(0xFF7EB6FF);
  static const Color unknownBg = Color(0xFFEBECED);
  static const Color unknownFg = Color(0xFF666E75);
  static const Color onColorFg = Colors.white;

  static String bloodSugar(BloodSugarRecord? record) {
    if (record == null) return '모름';
    return BloodSugarRecord.calculateStatus(
      record.bloodSugar,
      record.measurementType,
    );
  }

  static String bloodPressure({
    BloodPressureRecord? record,
    int? systolic,
    int? diastolic,
  }) {
    final sys = record?.systolic ?? systolic;
    final dia = record?.diastolic ?? diastolic;
    if (sys == null || dia == null || sys <= 0 || dia <= 0) return '모름';
    return BloodPressureRecord.calculateStatus(sys, dia);
  }

  static Color background(String label) {
    switch (label) {
      case '정상':
        return normalBg;
      case '당뇨 전단계':
      case '고혈압 전단계':
        return cautionBg;
      case '1기 고혈압':
        return stageBg;
      case '당뇨':
      case '2기 고혈압':
        return dangerBg;
      case '고혈압 위기':
        return crisisBg;
      case '저혈압':
        return lowBg;
      case '모름':
        return unknownBg;
      default:
        return unknownBg;
    }
  }

  static Color foreground(String label) {
    switch (label) {
      case '정상':
        return normalFg;
      case '모름':
        return unknownFg;
      case '당뇨 전단계':
      case '고혈압 전단계':
      case '1기 고혈압':
      case '당뇨':
      case '2기 고혈압':
      case '고혈압 위기':
      case '저혈압':
        return onColorFg;
      default:
        return unknownFg;
    }
  }
}
