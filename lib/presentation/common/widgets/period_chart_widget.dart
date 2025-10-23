import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  final String dataType; // 'bloodPressure' 또는 'weight'
  final int yAxisCount; // Y축 개수 (혈압: 4개, 체중: 4개 등)
  final DateTime selectedDate; // 선택된 날짜
  final double height; // 차트 높이

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
  }) : super(key: key);

  @override
  State<PeriodChartWidget> createState() => _PeriodChartWidgetState();
}

class _PeriodChartWidgetState extends State<PeriodChartWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // Y축 라벨과 차트 영역
          Expanded(
            child: Row(
              children: [
                // Y축 라벨
                SizedBox(
                  width: 35,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: widget.yLabels.map((label) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                         child: Text(
                           '${label.toStringAsFixed(0)}',
                           style: const TextStyle(
                             fontSize: 12,
                             color: Colors.grey,
                           ),
                         ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 8),
                // 차트 영역
                Expanded(
                  child: _buildChartArea(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // X축 라벨
          Padding(
            padding: const EdgeInsets.only(left: 43.0, bottom: 10.0),
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
              onPanUpdate: (details) => _handleDragUpdate(details.delta.dx),
              child: CustomPaint(
                painter: PeriodChartPainter(
                  chartData: widget.chartData,
                  yLabels: widget.yLabels,
                  timeOffset: widget.timeOffset,
                  selectedPeriod: widget.selectedPeriod,
                  selectedPointIndex: widget.selectedChartPointIndex,
                  dataType: widget.dataType,
                  yAxisCount: widget.yAxisCount,
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
    final tooltipWidth = 100.0; // 툴팁 너비 증가
    
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
    final chartHeight = widget.height - 32.0; // 패딩 제외
    final tooltipHeight = 60.0; // 툴팁 높이 증가
    
    // 점 위쪽에 툴팁 배치 시도
    double top = pointY - tooltipHeight - 10;
    
    // 그래프 영역을 벗어나면 점 아래쪽에 배치
    if (top < 10) {
      top = pointY + 10;
    }
    
    return top;
  }

  Widget _buildPeriodXAxisLabels() {
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
      final endIndex = startIndex + visibleDays;
      
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
    
    print('🔍 클릭 위치: tapPosition = $tapPosition');
    
    const double leftPadding = 10.0;
    const double rightPadding = 10.0;
    const double topPadding = 20.0;
    const double bottomPadding = 20.0;
    
    final effectiveWidth = chartWidth - leftPadding - rightPadding;
    
    print('🔍 chartWidth=$chartWidth, effectiveWidth=$effectiveWidth');
    
    int? closestIndex;
    double minDistance = double.infinity;
    Offset? closestPoint;
    
    final minValue = widget.yLabels[widget.yAxisCount - 1];
    final maxValue = widget.yLabels[0];
    
    for (int i = 0; i < widget.chartData.length; i++) {
      final data = widget.chartData[i];
      final value = data[widget.dataType == 'bloodPressure' ? 'systolic' : 'weight'];
      
      if (value == null) continue;
      
      // X 좌표 계산 (일별과 동일한 방식)
      double x;
      if (data['xPosition'] != null) {
        // 주별/월별 차트: xPosition 사용
        final xPosition = data['xPosition'] as double;
        final visibleDays = 7;
        final totalDays = widget.selectedPeriod == '주' ? 7 : 30;
        
        if (widget.selectedPeriod == '월') {
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
      
      print('🔍 점 $i: date=${data['date']}, x=$x, y=$y, distance=$distance');
      
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
        closestPoint = Offset(x, y);
      }
    }
    
    print('🔍 결과: closestIndex=$closestIndex, minDistance=$minDistance');
    
    // 일별 그래프와 동일한 조건 (minDistance < 1000)
    if (closestIndex != null && minDistance < 1000) {
      widget.onTooltipChanged(closestIndex, closestPoint);
    } else {
      widget.onTooltipChanged(null, null);
    }
  }

  Widget _buildChartTooltip() {
    
    
    if (widget.selectedChartPointIndex == null || 
        widget.selectedChartPointIndex! >= widget.chartData.length) {
      print('🔍 툴팁 숨김: 인덱스 범위 초과');
      return const SizedBox.shrink();
    }
    
    final data = widget.chartData[widget.selectedChartPointIndex!];
    final value = data[widget.dataType == 'bloodPressure' ? 'systolic' : 'weight'];
    final record = data['record'];
    
    if (value == null || record == null) {
      print('🔍 툴팁 숨김: 값 또는 레코드가 null');
      return const SizedBox.shrink();
    }
    
    
    // 차트 데이터의 날짜 사용 (X축 라벨과 일치)
    final chartDate = data['date'] as String;
    final dateTime = widget.dataType == 'bloodPressure' 
        ? (record.measuredAt is DateTime 
            ? record.measuredAt as DateTime 
            : DateTime.parse(record.measuredAt.toString()))
        : (record.createdAt is DateTime 
            ? record.createdAt as DateTime 
            : DateTime.parse(record.createdAt.toString()));
    final timeStr = DateFormat('HH:mm').format(dateTime);
    
    // 월별 그래프에서 툴팁 데이터 출력
    if (widget.selectedPeriod == '월') {
      print('🔍 월별 툴팁 데이터:');
      print('   - 차트 날짜: ${data['date']}');
      print('   - 실제 측정 날짜: ${DateFormat('M/d').format(dateTime)}');
      print('   - 측정 시간: $timeStr');
      print('   - 수축기: ${data['systolic']}');
      print('   - 이완기: ${data['diastolic']}');
      print('   - xPosition: ${data['xPosition']}');
      print('   - record: $record');
    }
    
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
      final maxOffset = (30 - 7) / 30;
      final clampedOffset = newOffset.clamp(0.0, maxOffset);
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

  PeriodChartPainter({
    required this.chartData,
    required this.yLabels,
    required this.timeOffset,
    required this.selectedPeriod,
    this.selectedPointIndex,
    required this.dataType,
    required this.yAxisCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (chartData.isEmpty) return;
    
    final minValue = yLabels[yAxisCount - 1]; // 최소값 (하단)
    final maxValue = yLabels[0]; // 최대값 (상단)
    
    // 그리드 선 그리기 (패딩 적용)
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;
    
    const double leftPadding = 10.0;
    const double rightPadding = 10.0;
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
      final systolicValue = data[dataType == 'bloodPressure' ? 'systolic' : 'weight'];
      final diastolicValue = dataType == 'bloodPressure' ? data['diastolic'] : null;
      
      if (systolicValue == null) continue;
      
      // X 좌표 계산
      double x;
      final xPosition = data['xPosition'] as double;
      final visibleDays = 7;
      final totalDays = selectedPeriod == '주' ? 7 : 30;
      
      // 주별과 월별 모두 동일한 방식으로 처리
      if (selectedPeriod == '월') {
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
    
    // 선 그리기
    final systolicLinePaint = Paint()
      ..color = dataType == 'bloodPressure' ? Colors.red : Colors.blue
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    for (int i = 0; i < systolicPoints.length - 1; i++) {
      canvas.drawLine(systolicPoints[i], systolicPoints[i + 1], systolicLinePaint);
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
      ..color = dataType == 'bloodPressure' ? Colors.red : Colors.blue
      ..style = PaintingStyle.fill;
    
    final diastolicPointPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    
    final selectedPointPaint = Paint()
      ..color = dataType == 'bloodPressure' ? Colors.red : Colors.blue
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < systolicPoints.length; i++) {
      final systolicPoint = systolicPoints[i];
      final isSelected = validIndices[i] == selectedPointIndex;
      
      // 수축기 점 그리기 (일별 그래프와 동일한 스타일)
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