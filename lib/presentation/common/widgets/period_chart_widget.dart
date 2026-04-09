import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/api_date_time.dart';
import '../chart_layout.dart';

/// 주/월별 차트를 위한 공통 위젯
class PeriodChartWidget extends StatefulWidget {
  final List<Map<String, dynamic>> chartData;
  final List<double> yLabels;
  final String selectedPeriod;
  final double timeOffset;
  final Function(double) onTimeOffsetChanged;
  final Function(int?, Offset?) onTooltipChanged;
  final int? selectedChartPointIndex;
  final Offset? tooltipPosition;
  final String dataType; // 'bloodPressure', 'weight', 'bloodSugar'
  final int yAxisCount; // Y축 개수 (혈압: 4개, 체중: 4개 등)
  final DateTime selectedDate; // 선택된 날짜
  final double height; // 차트 높이
  /// 체중 메인 그래프: Y축 상단에 단위 행 (예: `(kg)`)
  final bool showYAxisUnitHeader;
  final String yAxisUnitLabel;
  /// 체중: Y축 숫자 범위 밖 값은 점·선에서 제외
  final bool omitOutOfRangeWeightPoints;
  /// true: 월 모드에서 30일 슬라이드 대신 해당 연도 1~12월 고정 축
  final bool useCalendarYearMonths;

  /// 카드 바깥 패딩 (체중은 [ChartConstants.weightChartCardPadding]로 일·주·월 통일)
  final EdgeInsetsGeometry padding;

  /// null이면 `Colors.grey[50]` (기존 동작)
  final Color? cardBackgroundColor;

  const PeriodChartWidget({
    Key? key,
    required this.chartData,
    required this.yLabels,
    required this.selectedPeriod,
    required this.timeOffset,
    required this.onTimeOffsetChanged,
    required this.onTooltipChanged,
    this.selectedChartPointIndex,
    this.tooltipPosition,
    required this.dataType,
    required this.yAxisCount,
    required this.selectedDate,
    required this.height,
    this.showYAxisUnitHeader = false,
    this.yAxisUnitLabel = '(kg)',
    this.omitOutOfRangeWeightPoints = false,
    this.useCalendarYearMonths = false,
    this.padding = const EdgeInsets.all(10),
    this.cardBackgroundColor,
  }) : super(key: key);

  @override
  State<PeriodChartWidget> createState() => _PeriodChartWidgetState();
}

class _PeriodChartWidgetState extends State<PeriodChartWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.cardBackgroundColor ?? Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: widget.dataType == 'weight'
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          // Y축 라벨과 차트 영역
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final totalH = c.maxHeight;
                final kgBand = widget.showYAxisUnitHeader &&
                        widget.yLabels.length > 1
                    ? totalH / 6.0
                    : 0.0;

                /// spaceBetween + 큰 vertical 패딩은 눈금이 많을 때 하단 오버플로우 유발 → Stack 배치
                Widget yLabelsColumn() {
                  final n = widget.yLabels.length;
                  if (n < 2) return const SizedBox.shrink();
                  return LayoutBuilder(
                    builder: (context, lc) {
                      const topPad = 6.0;
                      const botPad = 6.0;
                      final h = lc.maxHeight - topPad - botPad;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: widget.yLabels.asMap().entries.map((e) {
                          final i = e.key;
                          final label = e.value;
                          final y = topPad + h * i / (n - 1);
                          return Positioned(
                            top: y - 8,
                            left: 0,
                            right: 0,
                            child: Text(
                              label.toStringAsFixed(0),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: ChartConstants.weightChartYAxisWidth,
                      child: widget.showYAxisUnitHeader
                          ? Column(
                              children: [
                                SizedBox(
                                  height: kgBand,
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Text(
                                      widget.yAxisUnitLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(child: yLabelsColumn()),
                              ],
                            )
                          : yLabelsColumn(),
                    ),
                    SizedBox(width: ChartConstants.yAxisSpacing),
                    Expanded(
                      child: Column(
                        children: [
                          if (widget.showYAxisUnitHeader)
                            SizedBox(height: kgBand),
                          Expanded(
                            child: _buildChartArea(),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // X축 라벨 (체중은 일·주 카드와 동일: 하단 추가 패딩 없음)
          Padding(
            padding: EdgeInsets.only(
              left: 43.0,
              bottom: widget.dataType == 'weight' ? 0.0 : 10.0,
            ),
            child: _buildPeriodXAxisLabels(),
          ),
        ],
      ),
    );
  }

  Widget _buildChartArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartAreaWidth = constraints.maxWidth;
        final chartAreaHeight = constraints.maxHeight;
        
        return Stack(
          children: [
            GestureDetector(
              onTapDown: (details) => _handleChartTapWithSize(details.localPosition, chartAreaWidth, chartAreaHeight),
              onTap: () {
                // 빈 공간을 탭하면 툴팁 닫기
                if (widget.selectedChartPointIndex != null) {
                  widget.onTooltipChanged(null, null);
                }
              },
              onPanUpdate: (details) {
                _handleDragUpdate(details.delta.dx);
              },
              child: CustomPaint(
                painter: PeriodChartPainter(
                  chartData: widget.chartData,
                  yLabels: widget.yLabels,
                  timeOffset: widget.timeOffset,
                  selectedPeriod: widget.selectedPeriod,
                  selectedPointIndex: widget.selectedChartPointIndex,
                  dataType: widget.dataType,
                  yAxisCount: widget.yAxisCount,
                  omitOutOfRangeWeightPoints:
                      widget.omitOutOfRangeWeightPoints,
                  useCalendarYearMonths: widget.useCalendarYearMonths,
                ),
                size: Size(chartAreaWidth, chartAreaHeight),
              ),
            ),
             // 툴팁 오버레이
             if (widget.selectedChartPointIndex != null && widget.tooltipPosition != null)
               Positioned(
                 left: _calculateTooltipLeft(widget.tooltipPosition!.dx),
                 top: _calculateTooltipTop(widget.tooltipPosition!.dy),
                 child: _buildChartTooltip(),
               ),
          ],
        );
      },
    );
  }

  double _calculateTooltipLeft(double pointX) {
    final chartWidth = MediaQuery.of(context).size.width - 43 - 32; // Y축 라벨 + 패딩 제외
    const tooltipWidth = 100.0;

    // 점 중앙에 툴팁 배치 시도
    double left = pointX - tooltipWidth / 2;
    
    // 그래프 영역을 벗어나면 조정
    if (left < 10) {
      left = 10; // 왼쪽 여백
    } else if (left + tooltipWidth > chartWidth - 10) {
      left = chartWidth - tooltipWidth - 10; // 오른쪽 여백
    }
    
    return left;
  }

  double _calculateTooltipTop(double pointY) {
    const tooltipHeight = 60.0;

    // 점 위쪽에 툴팁 배치 시도
    double top = pointY - tooltipHeight - 10;
    
    // 그래프 영역을 벗어나면 점 아래쪽에 배치
    if (top < 10) {
      top = pointY + 10;
    }
    
    return top;
  }

  Widget _buildPeriodXAxisLabels() {
    if (widget.selectedPeriod == '월' && widget.useCalendarYearMonths) {
      const totalMonths = 12;
      const visibleMonths = 7;
      final maxStart = totalMonths - visibleMonths;
      final startIndex =
          (widget.timeOffset * maxStart).round().clamp(0, maxStart);

      final monthRow = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(visibleMonths, (i) {
          final m = startIndex + i + 1;
          return Expanded(
            child: Text(
              '$m',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.clip,
              // 체중 [_buildWeightPeriodXAxisLabels] 월 눈금과 동일 (9pt, grey[600])
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          );
        }),
      );

      if (widget.dataType == 'weight') {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: monthRow),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                '(월)',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      }
      return monthRow;
    }

    final days = widget.selectedPeriod == '주' ? 7 : 30;
    final visibleDays = 7;
    
    if (widget.selectedPeriod == '주') {
      // 주별: 모든 날짜 표시
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(days, (i) {
          final endDate = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
          final startDate = endDate.subtract(Duration(days: days - 1));
          final date = startDate.add(Duration(days: i));
          return Text(
            '${date.month}/${date.day}',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          );
        }),
      );
    } else {
      // 월별: 선택된 날짜 기준으로 표시 (선택된 날짜가 맨 오른쪽에 보이도록)
      final maxOffset = (days - visibleDays) / days;
      final currentOffset = widget.timeOffset.clamp(0.0, maxOffset);
      final startIndex = (currentOffset * days).floor();
      
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(visibleDays, (i) {
          final dayIndex = startIndex + i;
          final endDate = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
          final startDate = endDate.subtract(Duration(days: days - 1));
          final date = startDate.add(Duration(days: dayIndex));
          return Text(
            '${date.month}/${date.day}',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          );
        }),
      );
    }
  }

  void _handleChartTapWithSize(Offset tapPosition, double chartWidth, double chartHeight) {
    if (widget.chartData.isEmpty) return;

    final double leftPadding = widget.dataType == 'weight'
        ? ChartConstants.weightDailyChartInnerPadH
        : 10.0;
    final double rightPadding = widget.dataType == 'weight'
        ? ChartConstants.weightDailyChartInnerPadH
        : 10.0;
    const double topPadding = 20.0;
    const double bottomPadding = 20.0;

    final effectiveWidth = chartWidth - leftPadding - rightPadding;
    
    int? closestIndex;
    double minDistance = double.infinity;
    Offset? closestPoint;
    
    final minValue = widget.yLabels[widget.yAxisCount - 1];
    final maxValue = widget.yLabels[0];
    
    for (int i = 0; i < widget.chartData.length; i++) {
      final data = widget.chartData[i];
      final value = data[widget.dataType == 'bloodPressure'
          ? 'systolic'
          : widget.dataType == 'bloodSugar'
              ? 'bloodSugar'
              : 'weight'];
      
      if (value == null) continue;

      if (widget.omitOutOfRangeWeightPoints && widget.dataType == 'weight') {
        final w = (value as num).toDouble();
        if (w < minValue || w > maxValue) continue;
      }
      
      // X 좌표 계산 (일별과 동일한 방식)
      double x;
      if (data['xPosition'] != null) {
        // 주별/월별 차트: xPosition 사용
        final xPosition = data['xPosition'] as double;
        final visibleDays = 7;
        final totalDays = widget.selectedPeriod == '주' ? 7 : 30;
        
        if (widget.selectedPeriod == '월' && widget.useCalendarYearMonths) {
          const totalMonths = 12;
          const visibleMonths = 7;
          final maxStart = totalMonths - visibleMonths;
          final startIndex =
              (widget.timeOffset * maxStart).round().clamp(0, maxStart);
          final endIndex = startIndex + visibleMonths;
          final dataIndex = (xPosition * (totalMonths - 1)).round();

          if (dataIndex < startIndex || dataIndex >= endIndex) continue;

          final relativeIndex = dataIndex - startIndex;
          final adjustedRatio = relativeIndex / (visibleMonths - 1);
          x = leftPadding + (effectiveWidth * adjustedRatio);
        } else if (widget.selectedPeriod == '월') {
          // 월별: 현재 보이는 7개 날짜만 표시
          final maxOffset = (totalDays - visibleDays) / totalDays;
          final currentOffset = widget.timeOffset.clamp(0.0, maxOffset);
          final startIndex = (currentOffset * totalDays).floor();
          final endIndex = startIndex + visibleDays;
          
          // xPosition을 인덱스로 변환
          final dataIndex = (xPosition * totalDays).round();
          
          if (dataIndex < startIndex || dataIndex >= endIndex) continue;
          
          // 현재 보이는 범위 내에서의 상대적 위치 계산
          final relativeIndex = dataIndex - startIndex;
          final adjustedRatio = relativeIndex / (visibleDays - 1);
          x = leftPadding + (effectiveWidth * adjustedRatio);
        } else {
          // 주별: 모든 데이터가 보이므로 직접 계산
          final dataIndex = (xPosition * totalDays).round();
          final adjustedRatio = dataIndex / (totalDays - 1);
          x = leftPadding + (effectiveWidth * adjustedRatio);
        }
      } else if (widget.chartData.length == 1) {
        // 단일 데이터
        x = leftPadding + effectiveWidth / 2;
      } else {
        // 여러 데이터
        x = leftPadding + (effectiveWidth * i / (widget.chartData.length - 1));
      }
      
      // Y 좌표 계산
      final normalizedValue = (maxValue - value) / (maxValue - minValue);
      final y = topPadding + (chartHeight - topPadding - bottomPadding) * normalizedValue;
      
      // 클릭 위치와 점 사이의 거리 계산
      final dx = tapPosition.dx - x;
      final dy = tapPosition.dy - y;
      final distance = dx * dx + dy * dy;

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
        closestPoint = Offset(x, y);
      }
    }

    // 일별 그래프와 동일한 조건 (minDistance < 1000)
    if (closestIndex != null && minDistance < 1000) {
      widget.onTooltipChanged(closestIndex, closestPoint);
    } else {
      widget.onTooltipChanged(null, null);
    }
  }

  /// 혈압·혈당·체중 레코드 공통: 측정 시각 우선, 없으면 createdAt.
  DateTime _chartTooltipTime(dynamic record) {
    final measured = record.measuredAt;
    if (measured is DateTime) return measured;
    final fromMeasured = ApiDateTime.parseInstant(measured);
    if (fromMeasured != null) return fromMeasured;

    final created = record.createdAt;
    if (created is DateTime) return created;
    final fromCreated = ApiDateTime.parseInstant(created);
    if (fromCreated != null) return fromCreated;

    return DateTime.now();
  }

  Widget _buildChartTooltip() {
    if (widget.selectedChartPointIndex == null ||
        widget.selectedChartPointIndex! >= widget.chartData.length) {
      return const SizedBox.shrink();
    }

    final data = widget.chartData[widget.selectedChartPointIndex!];

    final value = data[widget.dataType == 'bloodPressure'
        ? 'systolic'
        : widget.dataType == 'bloodSugar'
            ? 'bloodSugar'
            : 'weight'];
    final record = data['record'];

    if (value == null || record == null) {
      return const SizedBox.shrink();
    }

    // 차트 데이터의 날짜 사용 (X축 라벨과 일치)
    final chartDate = data['date'] as String;
    final DateTime dateTime = _chartTooltipTime(record);
    final timeStr = DateFormat('HH:mm').format(dateTime);
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$chartDate $timeStr',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          if (widget.dataType == 'bloodPressure')
            Text(
              '${data['systolic']}/${data['diastolic']} mmHg',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            )
          else if (widget.dataType == 'bloodSugar')
            Text(
              '${value.toStringAsFixed(0)} mg/dL',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Text(
              '${value.toStringAsFixed(0)} kg',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  void _handleDragUpdate(double deltaX) {
    if (widget.selectedPeriod == '월') {
      final sensitivity = 3.0;
      final newOffset = widget.timeOffset - (deltaX / 1000) * sensitivity;
      final clampedOffset = newOffset.clamp(0.0, 1.0);
      widget.onTimeOffsetChanged(clampedOffset);
    }
  }
}

/// 주/월별 차트 페인터
class PeriodChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> chartData;
  final List<double> yLabels;
  final double timeOffset;
  final String selectedPeriod;
  final int? selectedPointIndex;
  final String dataType;
  final int yAxisCount;
  final bool omitOutOfRangeWeightPoints;
  final bool useCalendarYearMonths;

  PeriodChartPainter({
    required this.chartData,
    required this.yLabels,
    required this.timeOffset,
    required this.selectedPeriod,
    this.selectedPointIndex,
    required this.dataType,
    required this.yAxisCount,
    this.omitOutOfRangeWeightPoints = false,
    this.useCalendarYearMonths = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (chartData.isEmpty) return;
    
    final minValue = yLabels[yAxisCount - 1]; // 최소값 (하단)
    final maxValue = yLabels[0]; // 최대값 (상단)

    /// 일·주 체중 그래프와 동일한 포인트 색
    const weightPointColor = Color(0xFFFF5A8D);

    // 그리드 선 그리기 (패딩 적용)
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    final double leftPadding = dataType == 'weight'
        ? ChartConstants.weightDailyChartInnerPadH
        : 10.0;
    final double rightPadding = dataType == 'weight'
        ? ChartConstants.weightDailyChartInnerPadH
        : 10.0;
    const double topPadding = 20.0;
    const double bottomPadding = 20.0;

    for (int i = 0; i < yAxisCount; i++) {
      final y = topPadding + (size.height - topPadding - bottomPadding) * i / (yAxisCount - 1);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
    }

    // 데이터 포인트 계산 및 필터링
    List<Offset> systolicPoints = [];
    List<Offset> diastolicPoints = [];
    List<int> validIndices = [];

    for (int i = 0; i < chartData.length; i++) {
      final data = chartData[i];
      final systolicValue = data[dataType == 'bloodPressure'
          ? 'systolic'
          : dataType == 'bloodSugar'
              ? 'bloodSugar'
              : 'weight'];
      final diastolicValue = dataType == 'bloodPressure' ? data['diastolic'] : null;
      
      if (systolicValue == null) continue;

      if (omitOutOfRangeWeightPoints && dataType == 'weight') {
        final w = (systolicValue as num).toDouble();
        if (w < minValue || w > maxValue) continue;
      }
      
      // X 좌표 계산
      double x;
      final xPosition = data['xPosition'] as double;
      final visibleDays = 7;
      final totalDays = selectedPeriod == '주' ? 7 : 30;
      
      if (selectedPeriod == '월' && useCalendarYearMonths) {
        const totalMonths = 12;
        const visibleMonths = 7;
        final maxStart = totalMonths - visibleMonths;
        final startIndex = (timeOffset * maxStart).round().clamp(0, maxStart);
        final endIndex = startIndex + visibleMonths;
        final dataIndex = (xPosition * (totalMonths - 1)).round();

        if (dataIndex < startIndex || dataIndex >= endIndex) continue;

        final relativeIndex = dataIndex - startIndex;
        final adjustedRatio = relativeIndex / (visibleMonths - 1);
        x = leftPadding +
            (size.width - leftPadding - rightPadding) * adjustedRatio;
      } else if (selectedPeriod == '월') {
        final maxOffset = (totalDays - visibleDays) / totalDays;
        final currentOffset = timeOffset.clamp(0.0, maxOffset);
        final startIndex = (currentOffset * totalDays).floor();
        final endIndex = startIndex + visibleDays;
        
        final dataIndex = (xPosition * totalDays).round();
        
        if (dataIndex < startIndex || dataIndex >= endIndex) continue;
        
        final relativeIndex = dataIndex - startIndex;
        final adjustedRatio = relativeIndex / (visibleDays - 1);
        x = leftPadding + (size.width - leftPadding - rightPadding) * adjustedRatio;
      } else {
        // 주별: 모든 데이터가 보이므로 직접 계산
        final dataIndex = (xPosition * totalDays).round();
        final adjustedRatio = dataIndex / (totalDays - 1);
        x = leftPadding + (size.width - leftPadding - rightPadding) * adjustedRatio;
      }
      
      // Y 좌표 계산 (패딩 적용)
      final normalizedSystolic = (maxValue - systolicValue) / (maxValue - minValue);
      final ySystolic = topPadding + (size.height - topPadding - bottomPadding) * normalizedSystolic;
      
      systolicPoints.add(Offset(x, ySystolic));
      validIndices.add(i);

      // 혈압인 경우 이완기도 계산
      if (dataType == 'bloodPressure' && diastolicValue != null) {
        final normalizedDiastolic = (maxValue - diastolicValue) / (maxValue - minValue);
        final yDiastolic = topPadding + (size.height - topPadding - bottomPadding) * normalizedDiastolic;
        diastolicPoints.add(Offset(x, yDiastolic));
      }
    }
    
    if (systolicPoints.isEmpty) return;

    // 선 그리기 (체중은 점만)
    if (dataType != 'weight') {
      final systolicLinePaint = Paint()
        ..color = dataType == 'bloodPressure'
            ? Colors.red
            : dataType == 'bloodSugar'
                ? Colors.pink
                : Colors.blue
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < systolicPoints.length - 1; i++) {
        canvas.drawLine(
            systolicPoints[i], systolicPoints[i + 1], systolicLinePaint);
      }
    }
    
    // 혈압인 경우 이완기 선도 그리기
    if (dataType == 'bloodPressure' && diastolicPoints.isNotEmpty) {
      final diastolicLinePaint = Paint()
        ..color = Colors.blue
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      
      for (int i = 0; i < diastolicPoints.length - 1; i++) {
        canvas.drawLine(diastolicPoints[i], diastolicPoints[i + 1], diastolicLinePaint);
      }
    }
    
    // 점 그리기
    final systolicPointPaint = Paint()
      ..color = dataType == 'bloodPressure'
          ? Colors.red
          : dataType == 'bloodSugar'
              ? Colors.pink
              : dataType == 'weight'
                  ? weightPointColor
                  : Colors.blue
      ..style = PaintingStyle.fill;

    final diastolicPointPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    for (int i = 0; i < systolicPoints.length; i++) {
      final systolicPoint = systolicPoints[i];
      final isSelected = validIndices[i] == selectedPointIndex;

      if (dataType == 'weight') {
        if (isSelected) {
          canvas.drawCircle(systolicPoint, 8, systolicPointPaint);
          canvas.drawCircle(
            systolicPoint,
            8,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        } else {
          canvas.drawCircle(systolicPoint, 5, systolicPointPaint);
        }
        continue;
      }

      // 수축기 점 그리기 (혈압·혈당)
      if (isSelected) {
        canvas.drawCircle(systolicPoint, 8, systolicPointPaint);
        canvas.drawCircle(systolicPoint, 5, Paint()..color = Colors.white);
        canvas.drawCircle(
          systolicPoint,
          8,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        canvas.drawCircle(systolicPoint, 5, systolicPointPaint);
        canvas.drawCircle(systolicPoint, 3, Paint()..color = Colors.white);
      }
      
      // 혈압인 경우 이완기 점도 그리기
      if (dataType == 'bloodPressure' && i < diastolicPoints.length) {
        final diastolicPoint = diastolicPoints[i];
        
        if (isSelected) {
          canvas.drawCircle(diastolicPoint, 8, diastolicPointPaint);
          canvas.drawCircle(diastolicPoint, 5, Paint()..color = Colors.white);
          canvas.drawCircle(
            diastolicPoint, 
            8, 
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        } else {
          canvas.drawCircle(diastolicPoint, 5, diastolicPointPaint);
          canvas.drawCircle(diastolicPoint, 3, Paint()..color = Colors.white);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}