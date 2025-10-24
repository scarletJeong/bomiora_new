import 'package:flutter/material.dart';
import '../../../../data/models/health/steps/steps_record_model.dart';

class HourlyStepsChart extends StatelessWidget {
  final List<HourlySteps> hourlySteps;
  final String chartType;

  const HourlyStepsChart({
    super.key,
    required this.hourlySteps,
    required this.chartType,
  });

  @override
  Widget build(BuildContext context) {
    if (chartType == 'hourly') {
      return _buildHourlyChart();
    } else if (chartType == 'daily') {
      return _buildDailyChart();
    } else if (chartType == 'monthly') {
      return _buildMonthlyChart();
    }
    return _buildHourlyChart();
  }

  // 시간별 차트
  Widget _buildHourlyChart() {
    // 24시간 데이터 준비 (없는 시간은 0으로 채움)
    final List<HourlySteps> fullDayData = [];
    for (int hour = 0; hour < 24; hour++) {
      final existingData = hourlySteps.firstWhere(
        (data) => data.hour == hour,
        orElse: () => HourlySteps(hour: hour, steps: 0, distance: 0.0, calories: 0),
      );
      fullDayData.add(existingData);
    }

    final maxSteps = fullDayData.map((e) => e.steps).reduce((a, b) => a > b ? a : b);
    
    // 동적 Y축 설정
    double maxY;
    List<double> yAxisValues;
    
    if (maxSteps <= 1500) {
      maxY = 1500.0;
      yAxisValues = [0, 500, 1000, 1500];
    } else if (maxSteps <= 2000) {
      maxY = 3000.0;
      yAxisValues = [0, 1000, 2000, 3000];
    } else if (maxSteps <= 2500) {
      maxY = 5000.0;
      yAxisValues = [0, 2500, 5000];
    } else {
      maxY = 5000.0;
      yAxisValues = [0, 2500, 5000];
    }

    return SizedBox(
      height: 200,
      child: Row(
        children: [
          // Y축 레이블 (왼쪽)
          SizedBox(
            width: 50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: yAxisValues.reversed.map((value) {
                return Text(
                  value == maxY ? '${value.toInt()}' : '${value.toInt()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 8),
          
          // 차트 영역
          Expanded(
            child: Column(
              children: [
                // 차트
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.grey[300]!, width: 1),
                        bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                    ),
                    child: CustomPaint(
                      painter: BarChartPainter(
                        data: fullDayData,
                        maxY: maxY,
                      ),
                      child: Container(),
                    ),
                  ),
                ),
                // X축 라벨 (시간별: 00, 06, 12, 18, 24)
                Container(
                  height: 30,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['00', '06', '12', '18', '24'].map((hour) {
                      return Text(
                        hour,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 일별 차트 (주간 데이터)
  Widget _buildDailyChart() {
    // 오늘 날짜 기준으로 -6일부터 오늘까지 7일 데이터 생성
    final now = DateTime.now();
    final weeklyData = <Map<String, dynamic>>[];
    final weekLabels = <String>[];
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayName = _getDayName(date.weekday);
      final monthDay = '${date.month}/${date.day}';
      
      weeklyData.add({
        'day': dayName,
        'monthDay': monthDay,
        'steps': [8500, 7200, 9100, 6800, 10500, 12000, 9500][6-i],
      });
      
      weekLabels.add(monthDay);
    }

    final maxSteps = weeklyData.map((e) => e['steps'] as int).reduce((a, b) => a > b ? a : b);
    
    // 동적 Y축 설정 (주간 데이터)
    double maxY;
    List<double> yAxisValues;
    
    if (maxSteps <= 10000) {
      maxY = 10000.0;
      yAxisValues = [0, 5000, 10000];
    } else if (maxSteps <= 20000) {
      maxY = 15000.0;
      yAxisValues = [0, 5000, 10000, 15000];
    } else {
      maxY = 30000.0;
      yAxisValues = [0, 10000, 20000, 30000];
    }

    return SizedBox(
      height: 200,
      child: Row(
        children: [
          // Y축 레이블 (왼쪽)
          SizedBox(
            width: 50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: yAxisValues.reversed.map((value) {
                return Text(
                  value == maxY ? '${value.toInt()}' : '${value.toInt()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 8),
          
          // 차트 영역
          Expanded(
            child: Column(
              children: [
                // 차트
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.grey[300]!, width: 1),
                        bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                    ),
                    child: CustomPaint(
                      painter: WeeklyBarChartPainter(
                        data: weeklyData,
                        maxY: maxY,
                      ),
                      child: Container(),
                    ),
                  ),
                ),
                // X축 라벨 (주간: 월/일 형식)
                Container(
                  height: 30,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: weekLabels.map((label) {
                      return Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 월별 차트
  Widget _buildMonthlyChart() {
    // 월간 데이터 시뮬레이션 (월평균으로 계산)
    final monthlyData = [
      {'month': '1월', 'avgSteps': 8500},
      {'month': '2월', 'avgSteps': 9200},
      {'month': '3월', 'avgSteps': 8800},
      {'month': '4월', 'avgSteps': 9500},
      {'month': '5월', 'avgSteps': 10200},
      {'month': '6월', 'avgSteps': 9800},
      {'month': '7월', 'avgSteps': 8900},
      {'month': '8월', 'avgSteps': 8700},
      {'month': '9월', 'avgSteps': 9100},
      {'month': '10월', 'avgSteps': 9400},
      {'month': '11월', 'avgSteps': 8800},
      {'month': '12월', 'avgSteps': 9000},
    ];

    final maxAvgSteps = monthlyData.map((e) => e['avgSteps'] as int).reduce((a, b) => a > b ? a : b);
    
    // 동적 Y축 설정 (월평균 데이터)
    double maxY;
    List<double> yAxisValues;
    
    if (maxAvgSteps <= 10000) {
      maxY = 10000.0;
      yAxisValues = [0, 5000, 10000];
    } else {
      maxY = 20000.0;
      yAxisValues = [0, 10000, 20000];
    }

    return SizedBox(
      height: 200,
      child: Row(
        children: [
          // Y축 레이블 (왼쪽)
          SizedBox(
            width: 50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: yAxisValues.reversed.map((value) {
                return Text(
                  value == maxY ? '${value.toInt()}' : '${value.toInt()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 8),
          
          // 차트 영역
          Expanded(
            child: Column(
              children: [
                // 차트
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.grey[300]!, width: 1),
                        bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                    ),
                    child: CustomPaint(
                      painter: MonthlyBarChartPainter(
                        data: monthlyData,
                        maxY: maxY,
                      ),
                      child: Container(),
                    ),
                  ),
                ),
                // X축 라벨 (월별: 1월~12월)
                Container(
                  height: 30,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: monthlyData.map((month) {
                      return Text(
                        month['month'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 요일 이름 반환 헬퍼 함수
  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return '월';
      case 2: return '화';
      case 3: return '수';
      case 4: return '목';
      case 5: return '금';
      case 6: return '토';
      case 7: return '일';
      default: return '';
    }
  }
}

// 시간별 막대 차트 페인터
class BarChartPainter extends CustomPainter {
  final List<HourlySteps> data;
  final double maxY;

  BarChartPainter({required this.data, required this.maxY});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A90E2)
      ..style = PaintingStyle.fill;

    final barWidth = size.width / 24;
    
    for (int i = 0; i < data.length; i++) {
      final steps = data[i].steps;
      final barHeight = (steps / maxY) * size.height;
      
      final rect = Rect.fromLTWH(
        i * barWidth + barWidth * 0.1,
        size.height - barHeight,
        barWidth * 0.8,
        barHeight,
      );
      
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 주간 막대 차트 페인터
class WeeklyBarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double maxY;

  WeeklyBarChartPainter({required this.data, required this.maxY});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A90E2)
      ..style = PaintingStyle.fill;

    final barWidth = size.width / 7;
    
    for (int i = 0; i < data.length; i++) {
      final steps = data[i]['steps'] as int;
      final barHeight = (steps / maxY) * size.height;
      
      final rect = Rect.fromLTWH(
        i * barWidth + barWidth * 0.1,
        size.height - barHeight,
        barWidth * 0.8,
        barHeight,
      );
      
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 월간 막대 차트 페인터
class MonthlyBarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double maxY;

  MonthlyBarChartPainter({required this.data, required this.maxY});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A90E2)
      ..style = PaintingStyle.fill;

    final barWidth = size.width / 12;
    
    for (int i = 0; i < data.length; i++) {
      final avgSteps = data[i]['avgSteps'] as int;
      final barHeight = (avgSteps / maxY) * size.height;
      
      final rect = Rect.fromLTWH(
        i * barWidth + barWidth * 0.1,
        size.height - barHeight,
        barWidth * 0.8,
        barHeight,
      );
      
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}