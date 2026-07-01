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

  // 배란기 계산 (다음 생리 예정일에서 14일 전)
  DateTime get ovulationDate {
    return lastPeriodStart.add(Duration(days: ovulationDay - 1));
  }

  int get ovulationDay => MenstrualCycleCalculator.ovulationDay(cycleLength);

  // 가임기 시작일 (배란기에서 3일 전)
  DateTime get fertileWindowStart {
    return lastPeriodStart.add(Duration(days: fertileWindowStartDay - 1));
  }

  int get fertileWindowStartDay =>
      MenstrualCycleCalculator.fertileWindowStartDay(cycleLength);

  // 가임기 종료일 (배란기에서 1일 후)
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

  /// 가임기(배란기 -3일 ~ +1일) 여부
  bool isInFertileWindowOn(DateTime date) {
    if (cycleLength <= 0) return false;
    final cycleDay = cycleDayOn(date);
    return cycleDay >= fertileWindowStartDay && cycleDay <= fertileWindowEndDay;
  }

  /// 컨디션 체크·보미오라 Pick용 단계 (가임기는 배란기과 동일 추천)
  MenstrualPhase recommendationPhaseOn(DateTime date) {
    final phase = phaseOn(date);
    if (phase != MenstrualPhase.menstrual && isInFertileWindowOn(date)) {
      return MenstrualPhase.ovulation;
    }
    return phase;
  }

  /// 추천 카드 등에 표시할 단계 제목
  String phaseDisplayNameOn(DateTime date) {
    final phase = phaseOn(date);
    if (phase == MenstrualPhase.menstrual) {
      return MenstrualPhaseInfo.getPhaseInfo(MenstrualPhase.menstrual).name;
    }
    if (phase == MenstrualPhase.ovulation) {
      return MenstrualPhaseInfo.getPhaseInfo(MenstrualPhase.ovulation).name;
    }
    if (isInFertileWindowOn(date)) {
      return MenstrualPhaseInfo.fertileWindowLabel;
    }
    return MenstrualPhaseInfo.getPhaseInfo(phase).name;
  }

  // 현재 단계에 따른 상태 메시지
  String get currentPhaseMessage {
    final phase = currentPhase;

    switch (phase) {
      case MenstrualPhase.menstrual:
        return '생리 중';
      case MenstrualPhase.follicular:
        return '생리 후';
      case MenstrualPhase.ovulation:
        return '배란기';
      case MenstrualPhase.luteal:
        return '생리 전';
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
  menstrual,   // 생리 중 (1~5일)
  follicular,  // 생리 후
  ovulation,   // 배란기
  luteal,      // 생리 전
}

/// 생리주기 단계별 추천 탭 이동 대상
enum MenstrualPhaseLinkTarget {
  none,
  generalDietProducts,
  prescriptionDietProducts,
  prescriptionDetoxProducts,
  prescriptionCalmProducts,
  healthGoal,
  mealRecord,
}

/// 컨디션 체크 / 보미오라 Pick 한 줄
class MenstrualPhaseTip {
  static const String conditionCheckLabel = '컨디션 체크';
  static const String bomioraPickLabel = '보미오라 Pick';

  final String label;
  final String message;
  final MenstrualPhaseLinkTarget linkTarget;

  const MenstrualPhaseTip({
    required this.label,
    required this.message,
    this.linkTarget = MenstrualPhaseLinkTarget.none,
  });

  bool get isTappable => linkTarget != MenstrualPhaseLinkTarget.none;
}

// 생리주기 단계별 정보 클래스
class MenstrualPhaseInfo {
  static const String fertileWindowLabel = '가임기';

  final MenstrualPhase phase;
  final String name;
  final String description;
  final MenstrualPhaseTip conditionCheck;
  final MenstrualPhaseTip bomioraPick;

  const MenstrualPhaseInfo({
    required this.phase,
    required this.name,
    required this.description,
    required this.conditionCheck,
    required this.bomioraPick,
  });

  // 단계별 정보 반환
  static MenstrualPhaseInfo getPhaseInfo(MenstrualPhase phase) {
    switch (phase) {
      case MenstrualPhase.menstrual:
        return const MenstrualPhaseInfo(
          phase: MenstrualPhase.menstrual,
          name: '생리 중',
          description: '1~5일',
          conditionCheck: MenstrualPhaseTip(
            label: MenstrualPhaseTip.conditionCheckLabel,
            message: '생리 중에는 피로·부종으로 체중이 1~2kg 정도 변할 수 있어요.',
          ),
          bomioraPick: MenstrualPhaseTip(
            label: MenstrualPhaseTip.bomioraPickLabel,
            message:
                '무리한 다이어트·과한 운동은 잠시 쉬고, 수분과 수면만 챙겨보세요.',
            linkTarget: MenstrualPhaseLinkTarget.generalDietProducts,
          ),
        );
      case MenstrualPhase.follicular:
        return const MenstrualPhaseInfo(
          phase: MenstrualPhase.follicular,
          name: '생리 후',
          description: '6~14일',
          conditionCheck: MenstrualPhaseTip(
            label: MenstrualPhaseTip.conditionCheckLabel,
            message:
                '목표 체중·걸음 목표를 다시 맞추고, 식단·운동 루틴을 시작하기 좋아요.',
            linkTarget: MenstrualPhaseLinkTarget.healthGoal,
          ),
          bomioraPick: MenstrualPhaseTip(
            label: MenstrualPhaseTip.bomioraPickLabel,
            message:
                '체형 관리를 새로 시작한다면 보미 다이어트환·맞춤 단계를 함께 살펴보세요.',
            linkTarget: MenstrualPhaseLinkTarget.prescriptionDietProducts,
          ),
        );
      case MenstrualPhase.ovulation:
        return const MenstrualPhaseInfo(
          phase: MenstrualPhase.ovulation,
          name: '배란기',
          description: '15~17일',
          conditionCheck: MenstrualPhaseTip(
            label: MenstrualPhaseTip.conditionCheckLabel,
            message:
                '가벼운 활동과 함께 건강기록을 꾸준히 남기면 다음 생리 전 변화를 비교하기 쉬워요.',
            linkTarget: MenstrualPhaseLinkTarget.mealRecord,
          ),
          bomioraPick: MenstrualPhaseTip(
            label: MenstrualPhaseTip.bomioraPickLabel,
            message: '컨디션 변화가 느껴질 때는 심신안정환을 함께 살펴보세요.',
            linkTarget: MenstrualPhaseLinkTarget.prescriptionCalmProducts,
          ),
        );
      case MenstrualPhase.luteal:
        return const MenstrualPhaseInfo(
          phase: MenstrualPhase.luteal,
          name: '생리 전',
          description: '18~28일',
          conditionCheck: MenstrualPhaseTip(
            label: MenstrualPhaseTip.conditionCheckLabel,
            message: '부종·식욕·컨디션 변화가 올 수 있는 시기예요.',
          ),
          bomioraPick: MenstrualPhaseTip(
            label: MenstrualPhaseTip.bomioraPickLabel,
            message:
                '몸이 무겁고 붓는 느낌이 들 때는 가벼운 루틴과 디톡스·관리 상품을 함께 고려해보세요.',
            linkTarget: MenstrualPhaseLinkTarget.prescriptionDetoxProducts,
          ),
        );
    }
  }
}
