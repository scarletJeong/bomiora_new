/// 건강 문진표(마이페이지 `HealthProfileFormScreen`)와 동일한 선택지.
/// 처방 예약 플로우 등에서 하드코딩 대신 이 상수만 참조합니다.
abstract final class HealthProfileQuestionnaireOptions {
  HealthProfileQuestionnaireOptions._();

  static const List<String> dietPeriod = [
    '3일 이내',
    '5일 이내',
    '1주 이내',
    '2주 이내',
    '3주 이내',
    '4주 이내',
    '5주 이내',
    '6주 이내',
    '10주 이내',
    '10주 이상',
  ];

  static const List<String> mealsPerDay = [
    '하루 1식',
    '하루 2식',
    '하루 3식',
    '하루 3식 이상',
  ];

  static const List<String> eatingHabits = [
    '과식 주3회 이상',
    '군것질\n 주 3회 이상',
    '야식 주 3회 이상',
    '카페인음료\n 1일 3잔 이상',
    '해당없음',
  ];

  static const List<String> foodPreference = [
    '한식',
    '육식',
    '양식',
    '해산물',
    '중식',
    '튀김',
    '샐러드/다이터트\n식단',
    '과일',
    '빵/떡',
    '유제품',
  ];

  static const List<String> exerciseFrequency = [
    '일주일 1회 이하',
    '일주일 2~3회',
    '일주일 4회 ~ 6회',
    '매일',
  ];

  static const List<String> exerciseTypes = [
    '걷기/산책',
    '러닝/조깅',
    '등산',
    '자전거 타기',
    '수영',
    '요가/필라테스',
    '웨이트 트레이닝',    
    '구기 종목',
    '홈트레이닝',
    '기타',
  ];

  static const List<String> diseases = [
    '간질환',
    '호흡계통',
    '심혈증',
    '비뇨생식계통',
    '뼈/관절',
    '신경계통',
    '특이질환',
    '피부',
    '소화계통',
    '정신/행동',
    '내분비,영양,\n신장질환',
    '당뇨',
    '해당 없음',
  ];

  static const List<String> medications = [
    '혈압약',
    '다이어트약',
    '갑상선약',
    '피부과약',
    '항생제',
    '스테로이드제',
    '당뇨약',
    '위산분비 억제제',
    '정신과약',
    '항히스타민제',
    '항혈전제',
    '소염진통제',
    '피임약',
    '기타',
    '해당 없음',
  ];
}
