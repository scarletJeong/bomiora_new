import '../../../../core/utils/api_date_time.dart';
import 'menstrual_cycle_calculator.dart';

class MenstrualCycleRecord {
  final int? id;
  final String mbId;
  final DateTime lastPeriodStart; // 마지막 생리 시작일
  /// 표시용(수정 가능, 계산엔 영향 없음)
  final DateTime? periodStartDate;
  /// 표시용(수정 가능, 계산엔 영향 없음)
  final DateTime? periodEndDate;
  final int cycleLength; // 생리주기 길이 (일)
  final int periodLength; // 생리 기간 길이 (일)
  final String? notes; // 메모
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MenstrualCycleRecord({
    this.id,
    required this.mbId,
    required this.lastPeriodStart,
    this.periodStartDate,
    this.periodEndDate,
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
    return lastPeriodStart.add(Duration(days: ovulationDay - 1));
  }

  int get ovulationDay => MenstrualCycleCalculator.ovulationDay(cycleLength);

  // 가임기 시작일 (배란일에서 3일 전)
  DateTime get fertileWindowStart {
    return lastPeriodStart.add(Duration(days: fertileWindowStartDay - 1));
  }

  int get fertileWindowStartDay =>
      MenstrualCycleCalculator.fertileWindowStartDay(cycleLength);

  // 가임기 종료일 (배란일에서 1일 후)
  DateTime get fertileWindowEnd {
    return lastPeriodStart.add(Duration(days: fertileWindowEndDay - 1));
  }

  int get fertileWindowEndDay =>
      MenstrualCycleCalculator.fertileWindowEndDay(cycleLength);

  // 현재 생리주기에서 몇 일째인지 계산
  int get currentCycleDay {
    return cycleDayOn(DateTime.now());
  }

  // 현재 생리주기 단계 반환
  MenstrualPhase get currentPhase {
    return phaseOn(DateTime.now());
  }

  int cycleDayOn(DateTime date) {
    return MenstrualCycleCalculator.cycleDayForDate(
      date: date,
      cycleStartDate: lastPeriodStart,
      cycleLength: cycleLength,
    );
  }

  MenstrualPhase phaseOn(DateTime date) {
    final cycleDay = cycleDayOn(date);
    final safePeriodLength = periodLength.clamp(1, cycleLength).toInt();
    final ovulation = ovulationDay;
    if (cycleDay <= safePeriodLength) {
      return MenstrualPhase.menstrual;
    }
    if (cycleDay == ovulation) {
      return MenstrualPhase.ovulation;
    }
    if (cycleDay < ovulation) {
      return MenstrualPhase.follicular;
    }
    return MenstrualPhase.luteal;
  }

  // 현재 단계에 따른 상태 메시지
  String get currentPhaseMessage {
    final phase = currentPhase;

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
      'last_period_start': _formatDateOnly(lastPeriodStart),
      if (periodStartDate != null) 'period_start_date': _formatDateOnly(periodStartDate!),
      if (periodEndDate != null) 'period_end_date': _formatDateOnly(periodEndDate!),
      'cycle_length': cycleLength,
      'period_length': periodLength,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }

  factory MenstrualCycleRecord.fromJson(Map<String, dynamic> json) {
    return MenstrualCycleRecord(
      id: _parseInt(json['id']),
      mbId: _parseString(json['mb_id'] ?? json['mbId']) ?? '',
      lastPeriodStart: _parseDateOnly(
              json['last_period_start'] ?? json['lastPeriodStart']) ??
          DateTime.now(),
      periodStartDate: _parseDateOnly(json['period_start_date'] ?? json['periodStartDate']),
      periodEndDate: _parseDateOnly(json['period_end_date'] ?? json['periodEndDate']),
      cycleLength: _parseInt(json['cycle_length'] ?? json['cycleLength']) ?? 28,
      periodLength:
          _parseInt(json['period_length'] ?? json['periodLength']) ?? 5,
      notes: _parseString(json['notes']),
      createdAt: (json['created_at'] != null || json['createdAt'] != null)
          ? ApiDateTime.parseInstant(json['created_at'] ?? json['createdAt'])
          : null,
      updatedAt: (json['updated_at'] != null || json['updatedAt'] != null)
          ? ApiDateTime.parseInstant(json['updated_at'] ?? json['updatedAt'])
          : null,
    );
  }


  // 생리주기 날짜 Date 응답/요청 형식 변환
  static DateTime? _parseDateOnly(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    // DATE(yyyy-mm-dd)는 타임존 영향 없이 직접 파싱
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      final y = int.tryParse(raw.substring(0, 4));
      final m = int.tryParse(raw.substring(5, 7));
      final d = int.tryParse(raw.substring(8, 10));
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    // ISO instant 등은 기존 로직(로컬 변환) 사용
    final parsed = ApiDateTime.parseInstant(value);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static String _formatDateOnly(DateTime value) {
    final d = DateTime(value.year, value.month, value.day);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
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

      final dynamic nested = value['value'] ??
          value['text'] ??
          value['name'];
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
  MenstrualCycleRecord copyWith({
    int? id,
    String? mbId,
    DateTime? lastPeriodStart,
    DateTime? periodStartDate,
    DateTime? periodEndDate,
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
      periodStartDate: periodStartDate ?? this.periodStartDate,
      periodEndDate: periodEndDate ?? this.periodEndDate,
      cycleLength: cycleLength ?? this.cycleLength,
      periodLength: periodLength ?? this.periodLength,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 달력 표시용 시작일(없으면 계산용 lastPeriodStart)
  DateTime get displayPeriodStart =>
      periodStartDate ?? DateTime(lastPeriodStart.year, lastPeriodStart.month, lastPeriodStart.day);

  /// 달력 표시용 종료일(없으면 계산용 periodLength로 계산)
  DateTime get displayPeriodEnd {
    if (periodEndDate != null) return periodEndDate!;
    final s = displayPeriodStart;
    return s.add(Duration(days: periodLength - 1));
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
