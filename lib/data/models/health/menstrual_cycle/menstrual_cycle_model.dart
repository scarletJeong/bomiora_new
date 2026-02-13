import '../../../../core/utils/node_value_parser.dart';

class MenstrualCycleRecord {
  final int? id;
  final String mbId;
  final DateTime lastPeriodStart; // 마지막 생리 시작일
  final int cycleLength; // 생리주기 길이 (일)
  final int periodLength; // 생리 기간 길이 (일)
  final String? notes; // 메모
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MenstrualCycleRecord({
    this.id,
    required this.mbId,
    required this.lastPeriodStart,
    required this.cycleLength,
    required this.periodLength,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  // 다음 생리 예정일 계산
  DateTime get nextPeriodStart {
    return lastPeriodStart.add(Duration(days: cycleLength));
  }

  // 다음 생리 종료일 계산
  DateTime get nextPeriodEnd {
    return nextPeriodStart.add(Duration(days: periodLength - 1));
  }

  // 배란일 계산 (다음 생리 예정일에서 14일 전)
  DateTime get ovulationDate {
    return nextPeriodStart.subtract(const Duration(days: 14));
  }

  // 가임기 시작일 (배란일에서 5일 전)
  DateTime get fertileWindowStart {
    return ovulationDate.subtract(const Duration(days: 5));
  }

  // 가임기 종료일 (배란일에서 1일 후)
  DateTime get fertileWindowEnd {
    return ovulationDate.add(const Duration(days: 1));
  }

  // 현재 생리주기에서 몇 일째인지 계산
  int get currentCycleDay {
    final now = DateTime.now();
    final daysSinceLastPeriod = now.difference(lastPeriodStart).inDays;
    return (daysSinceLastPeriod % cycleLength) + 1;
  }

  // 현재 생리주기 단계 반환
  MenstrualPhase get currentPhase {
    final cycleDay = currentCycleDay;
    
    if (cycleDay <= periodLength) {
      return MenstrualPhase.menstrual; // 월경기
    } else if (cycleDay <= 14) {
      return MenstrualPhase.follicular; // 난포기
    } else if (cycleDay <= 17) {
      return MenstrualPhase.ovulation; // 배란기
    } else {
      return MenstrualPhase.luteal; // 황체기
    }
  }

  // 현재 단계에 따른 상태 메시지
  String get currentPhaseMessage {
    final phase = currentPhase;
    final cycleDay = currentCycleDay;
    
    switch (phase) {
      case MenstrualPhase.menstrual:
        return '월경기입니다. 충분한 휴식을 취하세요.';
      case MenstrualPhase.follicular:
        return '난포기입니다. 운동과 다이어트에 좋은 시기입니다.';
      case MenstrualPhase.ovulation:
        return '배란기입니다. 가임력이 가장 높은 시기입니다.';
      case MenstrualPhase.luteal:
        return '황체기입니다. PMS 증상에 주의하세요.';
    }
  }

  // JSON 변환
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'mb_id': mbId,
      'last_period_start': lastPeriodStart.toIso8601String(),
      'cycle_length': cycleLength,
      'period_length': periodLength,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }

  factory MenstrualCycleRecord.fromJson(Map<String, dynamic> json) {
    final normalized = NodeValueParser.normalizeMap(json);
    final periodStartValue =
        NodeValueParser.asString(normalized['last_period_start']) ??
        NodeValueParser.asString(normalized['lastPeriodStart']);
    final createdAtValue = NodeValueParser.asString(normalized['created_at']);
    final updatedAtValue = NodeValueParser.asString(normalized['updated_at']);

    return MenstrualCycleRecord(
      id: NodeValueParser.asInt(normalized['id']),
      mbId:
          NodeValueParser.asString(normalized['mb_id']) ??
          NodeValueParser.asString(normalized['mbId']) ??
          '',
      lastPeriodStart: periodStartValue != null
          ? DateTime.tryParse(periodStartValue) ?? DateTime.now()
          : DateTime.now(),
      cycleLength:
          NodeValueParser.asInt(normalized['cycle_length']) ??
          NodeValueParser.asInt(normalized['cycleLength']) ??
          28,
      periodLength:
          NodeValueParser.asInt(normalized['period_length']) ??
          NodeValueParser.asInt(normalized['periodLength']) ??
          5,
      notes: NodeValueParser.asString(normalized['notes']),
      createdAt: createdAtValue != null
          ? DateTime.tryParse(createdAtValue)
          : null,
      updatedAt: updatedAtValue != null
          ? DateTime.tryParse(updatedAtValue)
          : null,
    );
  }

  // 복사 메서드
  MenstrualCycleRecord copyWith({
    int? id,
    String? mbId,
    DateTime? lastPeriodStart,
    int? cycleLength,
    int? periodLength,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenstrualCycleRecord(
      id: id ?? this.id,
      mbId: mbId ?? this.mbId,
      lastPeriodStart: lastPeriodStart ?? this.lastPeriodStart,
      cycleLength: cycleLength ?? this.cycleLength,
      periodLength: periodLength ?? this.periodLength,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// 생리주기 단계 열거형
enum MenstrualPhase {
  menstrual,   // 월경기 (1~5일)
  follicular,  // 난포기 (6~14일)
  ovulation,   // 배란기 (15~17일)
  luteal,      // 황체기 (18~28일)
}

// 생리주기 단계별 정보 클래스
class MenstrualPhaseInfo {
  final MenstrualPhase phase;
  final String name;
  final String description;
  final List<String> foodRecommendations;
  final List<String> healthRecommendations;
  final List<String> managementRecommendations;

  const MenstrualPhaseInfo({
    required this.phase,
    required this.name,
    required this.description,
    required this.foodRecommendations,
    required this.healthRecommendations,
    required this.managementRecommendations,
  });

  // 단계별 정보 반환
  static MenstrualPhaseInfo getPhaseInfo(MenstrualPhase phase) {
    switch (phase) {
      case MenstrualPhase.menstrual:
        return const MenstrualPhaseInfo(
          phase: MenstrualPhase.menstrual,
          name: '월경기',
          description: '1~5일',
          foodRecommendations: [
            '철분이 풍부한 음식 (소고기, 시금치, 해조류)',
          ],
          healthRecommendations: [
            '무리한 운동은 피하고 가벼운 스트레칭 추천',
          ],
          managementRecommendations: [
            '따뜻한 차(생강차, 계피차) 섭취로 혈액 순환 촉진',
          ],
        );
      case MenstrualPhase.follicular:
        return const MenstrualPhaseInfo(
          phase: MenstrualPhase.follicular,
          name: '난포기',
          description: '6~14일',
          foodRecommendations: [
            '단백질 & 채소 위주 식단 (닭가슴살, 달걀, 두부, 브로콜리 등)',
          ],
          healthRecommendations: [
            '다이어트 및 운동 효과가 좋은 시기 → 근력 운동, 유산소 운동 추천',
          ],
          managementRecommendations: [
            '피부 컨디션이 좋아지는 시기이므로 미용 관리하기 좋은 시점',
          ],
        );
      case MenstrualPhase.ovulation:
        return const MenstrualPhaseInfo(
          phase: MenstrualPhase.ovulation,
          name: '배란기',
          description: '15~17일',
          foodRecommendations: [
            '체온 상승으로 땀 배출 증가 - 충분한 수분 섭취 필수',
          ],
          healthRecommendations: [
            '변비 예방을 위해 식이섬유 섭취 (고구마, 바나나, 견과류)',
          ],
          managementRecommendations: [
            '생리전 증후군(PMS) 시작될 수 있어 심리적 안정 필요',
          ],
        );
      case MenstrualPhase.luteal:
        return const MenstrualPhaseInfo(
          phase: MenstrualPhase.luteal,
          name: '황체기',
          description: '18~28일',
          foodRecommendations: [
            '나트륨 섭취 줄이고 칼륨(바나나, 감자) 함유 음식 섭취 → 부종 완화에 도움',
          ],
          healthRecommendations: [
            '마그네슘(다크초콜릿, 견과류) 섭취 → 우울감 완화 효과',
          ],
          managementRecommendations: [
            '격렬한 운동 대신 스트레칭, 요가, 가벼운 산책 추천',
          ],
        );
    }
  }
}
