import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bomiora_app/data/models/health/blood_sugar/blood_sugar_record_model.dart';
import 'package:bomiora_app/data/repositories/health/blood_sugar/blood_sugar_repository.dart';
import 'package:bomiora_app/presentation/health/blood_sugar/screens/blood_sugar_input_screen.dart';
import 'package:bomiora_app/presentation/common/widgets/date_top_widget.dart';
import 'package:bomiora_app/presentation/common/widgets/period_chart_widget.dart';
import 'package:bomiora_app/presentation/common/widgets/btn_record.dart';

class BloodSugarListScreen extends StatefulWidget {
  final DateTime? initialDate;
  
  const BloodSugarListScreen({
    super.key,
    this.initialDate,
  });

  @override
  State<BloodSugarListScreen> createState() => _BloodSugarListScreenState();
}

class _BloodSugarListScreenState extends State<BloodSugarListScreen> {
  late DateTime selectedDate;
  String selectedPeriod = '일별'; // '일별', '주별', '월별'
  String selectedChartType = '시간별'; // '시간별', '일별'
  
  List<BloodSugarRecord> allRecords = [];
  Map<String, List<BloodSugarRecord>> dailyRecordsCache = {};
  Set<String> loadingDates = {};
  bool isLoading = false;
  bool hasShownNoDataDialog = false;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate ?? DateTime.now();
    _loadData();
  }

  Future<void> _loadData() async {
    if (isLoading) return;
    
    setState(() {
      isLoading = true;
    });

    try {
      final records = await BloodSugarRepository.getBloodSugarRecords('user1');
      setState(() {
        allRecords = records;
      });
    } catch (e) {
      print('혈당 데이터 로딩 오류: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _onDateChanged(DateTime date) {
    setState(() {
      selectedDate = date;
    });
  }

  void _onPeriodChanged(String period) {
    setState(() {
      selectedPeriod = period;
    });
  }

  void _onChartTypeChanged(String chartType) {
    setState(() {
      selectedChartType = chartType;
    });
  }

  // 오늘의 혈당 데이터 가져오기
  List<BloodSugarRecord> getTodayRecords() {
    final today = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    return allRecords.where((record) {
      final recordDate = DateTime(record.measuredAt.year, record.measuredAt.month, record.measuredAt.day);
      return recordDate.isAtSameMomentAs(today);
    }).toList();
  }

  // 공복 혈당 데이터
  BloodSugarRecord? getFastingRecord() {
    final todayRecords = getTodayRecords();
    return todayRecords.where((record) => record.measurementType == '공복').isNotEmpty
        ? todayRecords.where((record) => record.measurementType == '공복').first
        : null;
  }

  // 식후 혈당 데이터
  BloodSugarRecord? getPostMealRecord() {
    final todayRecords = getTodayRecords();
    return todayRecords.where((record) => record.measurementType == '식후').isNotEmpty
        ? todayRecords.where((record) => record.measurementType == '식후').first
        : null;
  }

  // 전날 대비 변화량 계산
  String getComparisonText(BloodSugarRecord? todayRecord, String measurementType) {
    if (todayRecord == null) return '';
    
    final yesterday = selectedDate.subtract(const Duration(days: 1));
    final yesterdayRecords = allRecords.where((record) {
      final recordDate = DateTime(record.measuredAt.year, record.measuredAt.month, record.measuredAt.day);
      return recordDate.isAtSameMomentAs(yesterday) && record.measurementType == measurementType;
    }).toList();
    
    if (yesterdayRecords.isEmpty) return '';
    
    final yesterdayRecord = yesterdayRecords.first;
    final difference = todayRecord.bloodSugar - yesterdayRecord.bloodSugar;
    
    if (difference > 0) {
      return '전날 대비 ${difference}mg/dl ↑';
    } else if (difference < 0) {
      return '전날 대비 ${difference.abs()}mg/dl ↓';
    } else {
      return '전날과 동일';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '혈당',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // 날짜 선택 위젯
          DateTopWidget(
            selectedDate: selectedDate,
            onDateChanged: _onDateChanged,
            recordsMap: _getRecordsMap(),
            recordKey: 'blood_sugar',
            primaryColor: Colors.black,
            secondaryColor: Colors.grey[400],
          ),
          
          Expanded(
            child: SingleChildScrollView(
      child: Column(
        children: [
                  // 오늘의 혈당 요약 카드
                  _buildTodaySummaryCards(),
                  
                  const SizedBox(height: 20),
                  
                  // 차트 섹션
                  _buildChartSection(),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          
          // 하단 기록하기 버튼
          _buildRecordButton(),
        ],
      ),
    );
  }

  Map<String, dynamic> _getRecordsMap() {
    final Map<String, dynamic> recordsMap = {};
    for (final record in allRecords) {
      final dateKey = DateFormat('yyyy-MM-dd').format(record.measuredAt);
      if (!recordsMap.containsKey(dateKey)) {
        recordsMap[dateKey] = [];
      }
      recordsMap[dateKey].add(record);
    }
    return recordsMap;
  }

  Widget _buildTodaySummaryCards() {
    final fastingRecord = getFastingRecord();
    final postMealRecord = getPostMealRecord();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
                children: [
              Expanded(
                child: _buildSummaryCard(
                  '공복',
                  fastingRecord?.bloodSugar.toString() ?? '--',
                  'mg/dl',
                  getComparisonText(fastingRecord, '공복'),
                  fastingRecord != null,
                ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                child: _buildSummaryCard(
                  '식후',
                  postMealRecord?.bloodSugar.toString() ?? '--',
                  'mg/dl',
                  getComparisonText(postMealRecord, '식후'),
                  postMealRecord != null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, String unit, String comparison, bool hasData) {
    Color cardColor = const Color(0xFFF8BBD9); // 연한 핑크색
    Color arrowColor = Colors.blue;
    
    if (hasData && comparison.contains('↑')) {
      arrowColor = Colors.red;
    } else if (hasData && comparison.contains('↓')) {
      arrowColor = Colors.blue;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                            fontWeight: FontWeight.bold,
                  color: Colors.black,
                          ),
                        ),
              const SizedBox(width: 4),
                        Text(
                unit,
                style: const TextStyle(
                            fontSize: 14,
                  color: Colors.black,
                          ),
                        ),
                      ],
                    ),
          if (hasData && comparison.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  comparison.contains('↑') ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: arrowColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(
                    comparison,
                    style: TextStyle(
                        fontSize: 12,
                      color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
        color: Colors.white,
                borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
              ),
      child: Column(
                children: [
          // 차트 타입 탭
          _buildChartTypeTabs(),
          
          const SizedBox(height: 16),
          
          // 차트
          _buildChart(),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildChartTypeTabs() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton('시간별', selectedChartType == '시간별'),
          ),
          Expanded(
            child: _buildTabButton('일별', selectedChartType == '일별'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, bool isSelected) {
    return GestureDetector(
      onTap: () => _onChartTypeChanged(label),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
          label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (selectedChartType == '시간별') {
      return _buildTimeChart();
    } else {
      return _buildPeriodChart();
    }
  }

  Widget _buildTimeChart() {
    final todayRecords = getTodayRecords();
    
    if (todayRecords.isEmpty) {
      return Container(
        height: 300,
        child: const Center(
          child: Text(
            '오늘의 혈당 기록이 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    // 샘플 데이터로 두 개의 피크 생성
    final chartData = _generateSampleChartData();

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: CustomPaint(
        painter: TimeChartPainter(
          chartData: chartData,
          maxValue: 200,
          minValue: 0,
        ),
        child: Container(),
      ),
    );
  }

  Widget _buildPeriodChart() {
    // 주/월별 차트를 위한 데이터 준비
    final chartData = _getPeriodChartData();
    final yLabels = _getYAxisLabels();
    
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: PeriodChartWidget(
                  chartData: chartData,
                  yLabels: yLabels,
        selectedPeriod: selectedPeriod,
        timeOffset: 0.0,
        onTimeOffsetChanged: (offset) {},
        onTooltipChanged: (index, position) {},
        dataType: 'bloodSugar',
        yAxisCount: yLabels.length,
        selectedDate: selectedDate,
        height: 300,
      ),
    );
  }

  List<Map<String, dynamic>> _getPeriodChartData() {
    // 주/월별 차트 데이터 생성
    final List<Map<String, dynamic>> data = [];
    
    if (selectedPeriod == '주별') {
      // 최근 7일 데이터
      for (int i = 6; i >= 0; i--) {
        final date = selectedDate.subtract(Duration(days: i));
        final dayRecords = allRecords.where((record) {
          final recordDate = DateTime(record.measuredAt.year, record.measuredAt.month, record.measuredAt.day);
          return recordDate.isAtSameMomentAs(date);
        }).toList();
        
        if (dayRecords.isNotEmpty) {
          final avgBloodSugar = dayRecords.map((r) => r.bloodSugar).reduce((a, b) => a + b) / dayRecords.length;
          data.add({
            'date': DateFormat('M.d').format(date),
            'bloodSugar': avgBloodSugar,
            'record': dayRecords.first,
          });
        }
      }
    } else if (selectedPeriod == '월별') {
      // 최근 30일 데이터 (일주일 단위로 평균)
      for (int i = 4; i >= 0; i--) {
        final weekStart = selectedDate.subtract(Duration(days: i * 7 + 6));
        final weekEnd = selectedDate.subtract(Duration(days: i * 7));
        
        final weekRecords = allRecords.where((record) {
          final recordDate = DateTime(record.measuredAt.year, record.measuredAt.month, record.measuredAt.day);
          return recordDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
                 recordDate.isBefore(weekEnd.add(const Duration(days: 1)));
        }).toList();
        
        if (weekRecords.isNotEmpty) {
          final avgBloodSugar = weekRecords.map((r) => r.bloodSugar).reduce((a, b) => a + b) / weekRecords.length;
          data.add({
            'date': DateFormat('M.d').format(weekEnd),
            'bloodSugar': avgBloodSugar,
            'record': weekRecords.first,
          });
        }
      }
    }
    
    return data;
  }

  List<double> _getYAxisLabels() {
    final chartData = _getPeriodChartData();
    if (chartData.isEmpty) return [0, 50, 100, 150, 200];
    
    final values = chartData.map((d) => d['bloodSugar'] as double).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    
    final range = maxValue - minValue;
    final step = range / 4;
    
    return [
      maxValue + step,
      maxValue,
      maxValue - step,
      maxValue - step * 2,
      maxValue - step * 3,
      minValue - step,
    ];
  }

  List<Map<String, dynamic>> _generateSampleChartData() {
    // 이미지와 유사한 두 개의 피크 데이터 생성
    return [
      {'time': 0, 'value': 80},
      {'time': 3, 'value': 85},
      {'time': 6, 'value': 90},
      {'time': 9, 'value': 95},
      {'time': 12, 'value': 180}, // 첫 번째 피크
      {'time': 15, 'value': 160}, // 두 번째 피크
      {'time': 18, 'value': 120},
      {'time': 21, 'value': 100},
    ];
  }

  Widget _buildRecordButton() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BloodSugarInputScreen(),
              ),
            ).then((_) => _loadData());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            '+ 기록하기',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// 시간별 차트 페인터
class TimeChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> chartData;
  final double maxValue;
  final double minValue;

  TimeChartPainter({
    required this.chartData,
    required this.maxValue,
    required this.minValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (chartData.isEmpty) return;

    // 그리드 선 그리기
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    // Y축 그리드 선
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // X축 그리드 선 (3시간 간격)
    for (int i = 0; i <= 7; i++) {
      final x = size.width * i / 7;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }

    // Y축 라벨
    final textPainter = TextPainter();

    for (int i = 0; i <= 4; i++) {
      final value = minValue + (maxValue - minValue) * (4 - i) / 4;
      textPainter.text = TextSpan(
        text: value.toStringAsFixed(0),
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width - 8, size.height * i / 4 - textPainter.height / 2),
      );
    }

    // X축 라벨
    for (int i = 0; i <= 7; i++) {
      final time = i * 3;
      textPainter.text = TextSpan(
        text: time.toString().padLeft(2, '0'),
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(size.width * i / 7 - textPainter.width / 2, size.height + 8),
      );
    }

    // 차트 선 그리기
    final linePaint = Paint()
      ..color = Colors.pink
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = Colors.pink
      ..style = PaintingStyle.fill;

    // 데이터 포인트 계산 및 그리기
    List<Offset> points = [];
    for (int i = 0; i < chartData.length; i++) {
      final data = chartData[i];
      final time = data['time'] as int;
      final value = data['value'] as double;
      
      final x = size.width * time / 21; // 0-21시간 범위
      final y = size.height * (maxValue - value) / (maxValue - minValue);
      
      points.add(Offset(x, y));
      
      // 점 그리기
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
      canvas.drawCircle(Offset(x, y), 2, Paint()..color = Colors.white);
    }

    // 선 연결
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], linePaint);
    }

    // 특정 포인트에 빨간 점 표시 (12시, 15시)
    final redPointPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < chartData.length; i++) {
      final data = chartData[i];
      final time = data['time'] as int;
      final value = data['value'] as double;
      
      if (time == 12 || time == 15) {
        final x = size.width * time / 21;
        final y = size.height * (maxValue - value) / (maxValue - minValue);
        
        canvas.drawCircle(Offset(x, y), 6, redPointPaint);
        canvas.drawCircle(Offset(x, y), 3, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
