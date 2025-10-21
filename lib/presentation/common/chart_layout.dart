/// 차트 관련 공통 상수들
class ChartConstants {
  // Y축 관련 상수
  static const double yAxisLabelWidth = 25.0; // Y축 라벨 영역 너비
  static const double yAxisSpacing = 8.0; // Y축과 차트 사이 간격
  
  // 차트 패딩 상수 (데이터가 많을 때)
  static const double chartLeftPadding = 10.0; // 차트 왼쪽 패딩
  static const double chartRightPadding = 8.0; // 차트 오른쪽 패딩
  
  // 차트 패딩 상수 (데이터가 적을 때 - 2개 이하)
  static const double chartLeftPaddingSmall = 20.0; // 차트 왼쪽 패딩
  static const double chartRightPaddingSmall = 20.0; // 차트 오른쪽 패딩
  
  // 계산된 상수
  static double get yAxisTotalWidth => yAxisLabelWidth + yAxisSpacing; // Y축 총 너비
  
  // 데이터 개수에 따른 패딩 계산 헬퍼 메서드
  static double getLeftPadding(int dataCount) {
    return dataCount <= 2 ? chartLeftPaddingSmall : chartLeftPadding;
  }
  
  static double getRightPadding(int dataCount) {
    return dataCount <= 2 ? chartRightPaddingSmall : chartRightPadding;
  }
}
