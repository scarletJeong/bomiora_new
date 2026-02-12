import '../../../../core/utils/node_value_parser.dart';

class HealthProfileModel {
  final int? pfNo;
  final String mbId;
  final String answer1; // 생년월일
  final String answer2; // 성별
  final String answer3; // 목표감량체중
  final String answer4; // 키
  final String answer5; // 몸무게
  final String answer6; // 다이어트예상기간
  final String answer7; // 하루끼니
  final String answer8; // 식습관
  final String answer9; // 자주먹는음식
  final String answer10; // 운동습관
  final String answer11; // 질병
  final String answer12; // 복용중인 약
  final String answer13; // 기존 다이어트 복용약 여부
  final String answer13Period; // 다이어트약 복용기간
  final String answer13Dosage; // 다이어트약 복용횟수
  final String answer13Medicine; // 복용한 다이어트약명
  final String answer71; // 식사시간
  final String answer13Sideeffect; // 부작용(불편했던점)
  final DateTime pfWdatetime;
  final DateTime pfMdatetime;
  final String pfIp;
  final String pfMemo;

  HealthProfileModel({
    this.pfNo,
    required this.mbId,
    required this.answer1,
    required this.answer2,
    required this.answer3,
    required this.answer4,
    required this.answer5,
    required this.answer6,
    required this.answer7,
    required this.answer8,
    required this.answer9,
    required this.answer10,
    required this.answer11,
    required this.answer12,
    required this.answer13,
    required this.answer13Period,
    required this.answer13Dosage,
    required this.answer13Medicine,
    required this.answer71,
    required this.answer13Sideeffect,
    required this.pfWdatetime,
    required this.pfMdatetime,
    required this.pfIp,
    required this.pfMemo,
  });

  factory HealthProfileModel.fromJson(Map<dynamic, dynamic> json) {
    final normalized = NodeValueParser.normalizeMap(Map<String, dynamic>.from(json));
    // camelCase와 snake_case 모두 지원
    print('=== HealthProfileModel.fromJson 파싱 시작 ===');
    print('입력 JSON: $normalized');
    
    // pfNo 파싱 (camelCase 또는 snake_case)
    final pfNo = normalized['pfNo'] ?? normalized['pf_no'];
    print('pfNo: $pfNo');
    
    // DateTime 파싱 헬퍼 함수
    DateTime? parseDateTime(dynamic value) {
      final stringValue = NodeValueParser.asString(value);
      if (stringValue == null || stringValue.isEmpty) return null;
      final direct = DateTime.tryParse(stringValue);
      if (direct != null) return direct;
      final withT = DateTime.tryParse(stringValue.replaceAll(' ', 'T'));
      if (withT != null) return withT;
      print('날짜 파싱 오류: $value');
      return null;
    }
    
    final result = HealthProfileModel(
      pfNo: NodeValueParser.asInt(pfNo),
      mbId:
          NodeValueParser.asString(normalized['mbId']) ??
          NodeValueParser.asString(normalized['mb_id']) ??
          '',
      answer1:
          NodeValueParser.asString(normalized['answer1']) ??
          NodeValueParser.asString(normalized['answer_1']) ??
          '',
      answer2:
          NodeValueParser.asString(normalized['answer2']) ??
          NodeValueParser.asString(normalized['answer_2']) ??
          '',
      answer3:
          NodeValueParser.asString(normalized['answer3']) ??
          NodeValueParser.asString(normalized['answer_3']) ??
          '',
      answer4:
          NodeValueParser.asString(normalized['answer4']) ??
          NodeValueParser.asString(normalized['answer_4']) ??
          '',
      answer5:
          NodeValueParser.asString(normalized['answer5']) ??
          NodeValueParser.asString(normalized['answer_5']) ??
          '',
      answer6:
          NodeValueParser.asString(normalized['answer6']) ??
          NodeValueParser.asString(normalized['answer_6']) ??
          '',
      answer7:
          NodeValueParser.asString(normalized['answer7']) ??
          NodeValueParser.asString(normalized['answer_7']) ??
          '',
      answer8:
          NodeValueParser.asString(normalized['answer8']) ??
          NodeValueParser.asString(normalized['answer_8']) ??
          '',
      answer9:
          NodeValueParser.asString(normalized['answer9']) ??
          NodeValueParser.asString(normalized['answer_9']) ??
          '',
      answer10:
          NodeValueParser.asString(normalized['answer10']) ??
          NodeValueParser.asString(normalized['answer_10']) ??
          '',
      answer11:
          NodeValueParser.asString(normalized['answer11']) ??
          NodeValueParser.asString(normalized['answer_11']) ??
          '',
      answer12:
          NodeValueParser.asString(normalized['answer12']) ??
          NodeValueParser.asString(normalized['answer_12']) ??
          '',
      answer13:
          NodeValueParser.asString(normalized['answer13']) ??
          NodeValueParser.asString(normalized['answer_13']) ??
          '',
      answer13Period:
          NodeValueParser.asString(normalized['answer13Period']) ??
          NodeValueParser.asString(normalized['answer_13_period']) ??
          '',
      answer13Dosage:
          NodeValueParser.asString(normalized['answer13Dosage']) ??
          NodeValueParser.asString(normalized['answer_13_dosage']) ??
          '',
      answer13Medicine:
          NodeValueParser.asString(normalized['answer13Medicine']) ??
          NodeValueParser.asString(normalized['answer_13_medicine']) ??
          '',
      answer71:
          NodeValueParser.asString(normalized['answer71']) ??
          NodeValueParser.asString(normalized['answer_7_1']) ??
          '',
      answer13Sideeffect:
          NodeValueParser.asString(normalized['answer13Sideeffect']) ??
          NodeValueParser.asString(normalized['answer_13_sideeffect']) ??
          '',
      pfWdatetime: parseDateTime(normalized['pfWdatetime'] ?? normalized['pf_wdatetime']) ?? DateTime.now(),
      pfMdatetime: parseDateTime(normalized['pfMdatetime'] ?? normalized['pf_mdatetime']) ?? DateTime.now(),
      pfIp:
          NodeValueParser.asString(normalized['pfIp']) ??
          NodeValueParser.asString(normalized['pf_ip']) ??
          '',
      pfMemo:
          NodeValueParser.asString(normalized['pfMemo']) ??
          NodeValueParser.asString(normalized['pf_memo']) ??
          '',
    );
    
    print('=== 파싱 완료 ===');
    print('pfNo: ${result.pfNo}, mbId: ${result.mbId}');
    print('answer1: ${result.answer1}, answer2: ${result.answer2}');
    
    return result;
  }

  Map<String, dynamic> toJson() {
    return {
      'pfNo': pfNo,
      'mbId': mbId,
      'answer1': answer1,
      'answer2': answer2,
      'answer3': answer3,
      'answer4': answer4,
      'answer5': answer5,
      'answer6': answer6,
      'answer7': answer7,
      'answer8': answer8,
      'answer9': answer9,
      'answer10': answer10,
      'answer11': answer11,
      'answer12': answer12,
      'answer13': answer13,
      'answer13Period': answer13Period,
      'answer13Dosage': answer13Dosage,
      'answer13Medicine': answer13Medicine,
      'answer71': answer71,
      'answer13Sideeffect': answer13Sideeffect,
      'pfWdatetime': pfWdatetime.toIso8601String(),
      'pfMdatetime': pfMdatetime.toIso8601String(),
      'pfIp': pfIp,
      'pfMemo': pfMemo,
    };
  }

  HealthProfileModel copyWith({
    int? pfNo,
    String? mbId,
    String? answer1,
    String? answer2,
    String? answer3,
    String? answer4,
    String? answer5,
    String? answer6,
    String? answer7,
    String? answer8,
    String? answer9,
    String? answer10,
    String? answer11,
    String? answer12,
    String? answer13,
    String? answer13Period,
    String? answer13Dosage,
    String? answer13Medicine,
    String? answer71,
    String? answer13Sideeffect,
    DateTime? pfWdatetime,
    DateTime? pfMdatetime,
    String? pfIp,
    String? pfMemo,
  }) {
    return HealthProfileModel(
      pfNo: pfNo ?? this.pfNo,
      mbId: mbId ?? this.mbId,
      answer1: answer1 ?? this.answer1,
      answer2: answer2 ?? this.answer2,
      answer3: answer3 ?? this.answer3,
      answer4: answer4 ?? this.answer4,
      answer5: answer5 ?? this.answer5,
      answer6: answer6 ?? this.answer6,
      answer7: answer7 ?? this.answer7,
      answer8: answer8 ?? this.answer8,
      answer9: answer9 ?? this.answer9,
      answer10: answer10 ?? this.answer10,
      answer11: answer11 ?? this.answer11,
      answer12: answer12 ?? this.answer12,
      answer13: answer13 ?? this.answer13,
      answer13Period: answer13Period ?? this.answer13Period,
      answer13Dosage: answer13Dosage ?? this.answer13Dosage,
      answer13Medicine: answer13Medicine ?? this.answer13Medicine,
      answer71: answer71 ?? this.answer71,
      answer13Sideeffect: answer13Sideeffect ?? this.answer13Sideeffect,
      pfWdatetime: pfWdatetime ?? this.pfWdatetime,
      pfMdatetime: pfMdatetime ?? this.pfMdatetime,
      pfIp: pfIp ?? this.pfIp,
      pfMemo: pfMemo ?? this.pfMemo,
    );
  }
}

// 건강 프로필 질문 모델
class HealthProfileQuestion {
  final String id;
  final String question;
  final String type; // 'text', 'radio', 'checkbox', 'number', 'date', 'grid', 'birthdate', 'mealtime'
  final List<String>? options;
  final bool isRequired;
  final String? placeholder;
  final String? hint;
  final int? columns; // 그리드 레이아웃용 컬럼 수
  final bool allowMultiple; // 중복 선택 가능 여부

  HealthProfileQuestion({
    required this.id,
    required this.question,
    required this.type,
    this.options,
    this.isRequired = true,
    this.placeholder,
    this.hint,
    this.columns,
    this.allowMultiple = false,
  });
}

// 건강 프로필 섹션 모델
class HealthProfileSection {
  final String title;
  final String description;
  final List<HealthProfileQuestion> questions;

  HealthProfileSection({
    required this.title,
    required this.description,
    required this.questions,
  });
}

