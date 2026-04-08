import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 차트 관련 공통 상수들
class ChartConstants {
  /// 건강 모듈 목록·그래프 확대 공통 높이 (혈압/혈당/심박수/체중/걸음)
  static const double healthChartHeight = 320.0;

  /// 가로 확대 화면: 부모가 준 세로 공간에 맞춤 (혈당·걸음 확대와 동일한 방식).
  /// [bottomLegendReserve]: 확대 페이지 하단 범례 등을 위해 남길 여백(혈압/심박 등).
  static double healthExpandedChartHeight(
    double parentMaxHeight, {
    double topReserve = 8,
    double bottomLegendReserve = 34,
  }) {
    return (parentMaxHeight - topReserve - bottomLegendReserve)
        .clamp(160.0, healthChartHeight);
  }

  // Y축 관련 상수
  static const double yAxisLabelWidth = 25.0; // Y축 라벨 영역 너비
  static const double yAxisSpacing = 8.0; // Y축과 차트 사이 간격
  
  // 차트 패딩 상수 (데이터가 많을 때)
  static const double chartLeftPadding = 10.0; // 차트 왼쪽 패딩
  static const double chartRightPadding = 8.0; // 차트 오른쪽 패딩
  
  // 차트 패딩 상수 (데이터가 적을 때 - 2개 이하)
  static const double chartLeftPaddingSmall = 20.0; // 차트 왼쪽 패딩
  static const double chartRightPaddingSmall = 20.0; // 차트 오른쪽 패딩
  
  // 툴팁 관련 상수
  static const double tooltipWidth = 80.0; // 툴팁 기본 너비
  static const double tooltipHeight = 50.0; // 툴팁 기본 높이
  static const double tooltipPadding = 5.0; // 툴팁 여백
  static const double tooltipOffset = 10.0; // 툴팁과 점 사이 간격
  
  // 계산된 상수
  static double get yAxisTotalWidth => yAxisLabelWidth + yAxisSpacing; // Y축 총 너비

  /// 체중 일·주 그래프 및 [PeriodChartWidget] Y축 열 너비(동일 UI)
  static const double weightChartYAxisWidth = 35.0;
  static double get weightChartYAxisStripWidth =>
      weightChartYAxisWidth + yAxisSpacing;

  /// 체중 시간대별(일) 차트 플롯 영역 좌·우 여백 (그리드·점·탭 hit 동일)
  static const double weightDailyChartInnerPadH = 6.0;
  /// 체중 X축 오른쪽 단위 `(시)/(일)/(월)`을 위한 여유 폭
  static const double weightXAxisUnitReservedWidth = 18.0;

  /// 체중 일·주·월 그래프 카드 공통 패딩 (시간대별과 동일)
  static const EdgeInsets weightChartCardPadding =
      EdgeInsets.fromLTRB(8, 16, 16, 16);
  
  // 데이터 개수에 따른 패딩 계산 헬퍼 메서드
  static double getLeftPadding(int dataCount) {
    return dataCount <= 2 ? chartLeftPaddingSmall : chartLeftPadding;
  }
  
  static double getRightPadding(int dataCount) {
    return dataCount <= 2 ? chartRightPaddingSmall : chartRightPadding;
  }
  
  /// 툴팁 위치를 동적으로 계산하여 화면 밖으로 나가지 않도록 조정
  static Offset calculateTooltipPosition(
    Offset pointPosition,
    double tooltipWidth,
    double tooltipHeight,
    double chartWidth,
    double chartHeight,
  ) {
    // 기본 위치: 점 위에 표시
    double left = pointPosition.dx - tooltipWidth / 2;
    double top = pointPosition.dy - tooltipHeight - tooltipOffset;
    
    // 왼쪽 경계 체크
    if (left < tooltipPadding) {
      left = tooltipPadding;
    } else if (left + tooltipWidth > chartWidth - tooltipPadding) {
      left = chartWidth - tooltipWidth - tooltipPadding;
    }
    
    // 위쪽 경계 체크 (너무 위로 올라가면 아래쪽에 표시)
    if (top < tooltipPadding) {
      top = pointPosition.dy + tooltipOffset; // 점 아래에 표시
    }
    
    return Offset(left, top);
  }
}

/// 시간대별(일)에서 **선택일 당일 기록이 없을 때** — 축·그리드 없이 문구만 (혈당 그래프와 동일).
class HealthDailyNoDataChartCard extends StatelessWidget {
  const HealthDailyNoDataChartCard({
    super.key,
    required this.chartHeight,
    required this.title,
    required this.subtitle,
  });

  final double chartHeight;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: chartHeight,
      padding: ChartConstants.weightChartCardPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Gmarket Sans TTF',
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Gmarket Sans TTF',
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
