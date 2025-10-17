import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../../data/models/health/weight_record_model.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/repositories/health/weight_repository.dart';
import '../../../../data/services/auth_service.dart';
import 'weight_input_screen.dart';

class WeightListScreen extends StatefulWidget {
  final DateTime? initialDate; // 초기 선택 날짜 (옵션)
  
  const WeightListScreen({super.key, this.initialDate});

  @override
  State<WeightListScreen> createState() => _WeightListScreenState();
}

class _WeightListScreenState extends State<WeightListScreen> {
  String selectedPeriod = '일'; // 일, 주, 월
  
  // 사용자 정보
  UserModel? currentUser;
  
  // 체중 기록 목록 (날짜별)
  Map<String, WeightRecord> weightRecordsMap = {}; // 날짜를 키로 하는 맵
  List<WeightRecord> allRecords = []; // 모든 체중 기록 (시간 정보 포함)
  bool isLoading = true;
  
  // 현재 선택된 날짜 (기본값: 오늘)
  late DateTime selectedDate;
  
  // 표시할 3개의 날짜 (이전날, 선택된날, 다음날)
  List<DateTime> get displayDates {
    return [
      selectedDate.subtract(const Duration(days: 1)), // 어제
      selectedDate,                                    // 오늘 (선택된 날짜)
      selectedDate.add(const Duration(days: 1)),       // 내일
    ];
  }
  
  // 현재 선택된 날짜의 기록
  WeightRecord? get selectedRecord {
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    return weightRecordsMap[dateKey];
  }
  
  // 차트 데이터 생성
  List<Map<String, dynamic>> getChartData() {
    if (allRecords.isEmpty) return [];
    
    List<Map<String, dynamic>> chartData = [];
    
    if (selectedPeriod == '일') {
      // 선택된 날짜의 모든 기록 (시간별)
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      final todayRecords = allRecords.where((record) {
        final recordDateStr = DateFormat('yyyy-MM-dd').format(record.measuredAt);
        return recordDateStr == selectedDateStr;
      }).toList();
      
      // 시간 순으로 정렬
      todayRecords.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
      
      for (var record in todayRecords) {
        chartData.add({
          'date': DateFormat('HH:mm').format(record.measuredAt), // 시간 표시
          'weight': record.weight,
        });
      }
    } else if (selectedPeriod == '주') {
      // 오늘부터 7일 전까지 (각 날짜당 마지막 기록 1개)
      final endDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final startDate = endDate.subtract(const Duration(days: 6));
      
      for (int i = 0; i < 7; i++) {
        final date = startDate.add(Duration(days: i));
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        
        if (weightRecordsMap.containsKey(dateKey)) {
          chartData.add({
            'date': DateFormat('M.d').format(date),
            'weight': weightRecordsMap[dateKey]!.weight,
          });
        }
      }
    } else if (selectedPeriod == '월') {
      // 오늘부터 30일 전까지 (각 날짜당 마지막 기록 1개)
      final endDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final startDate = endDate.subtract(const Duration(days: 29));
      
      for (int i = 0; i < 30; i++) {
        final date = startDate.add(Duration(days: i));
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        
        if (weightRecordsMap.containsKey(dateKey)) {
          chartData.add({
            'date': DateFormat('M.d').format(date),
            'weight': weightRecordsMap[dateKey]!.weight,
          });
        }
      }
    }
    
    return chartData;
  }
  
  // Y축 범위 계산 (최저/최고 체중 기준)
  List<double> getYAxisLabels() {
    final chartData = getChartData();
    if (chartData.isEmpty) return [0, 2, 4, 6];
    
    // 모든 체중 데이터 추출
    final weights = chartData.map((data) => data['weight'] as double).toList();
    
    // 최저/최고 체중
    final minWeight = weights.reduce((a, b) => a < b ? a : b);
    final maxWeight = weights.reduce((a, b) => a > b ? a : b);
    
    // 최소 범위 보장 (최소 4kg 범위로 4개 라벨이 겹치지 않고 여유 공간 확보)
    final range = maxWeight - minWeight;
    final minRange = 4.0; // 최소 4kg 범위 (상하 여유 공간 포함)
    
    double adjustedMin, adjustedMax;
    
    if (range < minRange) {
      // 범위가 작으면 최저값 기준으로 확장 (하단 여유 확보)
      adjustedMin = minWeight - 1.0; // 하단 1kg 여유
      adjustedMax = adjustedMin + minRange;
    } else {
      // 여유 공간 추가 (위아래 여유)
      final padding = range * 0.15; // 15% 여유
      adjustedMin = minWeight - padding;
      adjustedMax = maxWeight + padding;
    }
    
    // 4개의 균등한 간격으로 라벨 생성 (1kg 단위로 반올림)
    return [
      adjustedMax.roundToDouble(),              // 최고
      (adjustedMax - (adjustedMax - adjustedMin) / 3).roundToDouble(),       // 중상
      (adjustedMax - (adjustedMax - adjustedMin) * 2 / 3).roundToDouble(),   // 중하
      adjustedMin.roundToDouble(),              // 최저
    ];
  }

  @override
  void initState() {
    super.initState();
    // 전달받은 날짜 또는 오늘 날짜로 초기화 (시간은 00:00:00으로 설정)
    if (widget.initialDate != null) {
      selectedDate = DateTime(
        widget.initialDate!.year,
        widget.initialDate!.month,
        widget.initialDate!.day,
      );
    } else {
      final now = DateTime.now();
      selectedDate = DateTime(now.year, now.month, now.day);
    }
    _loadData();
  }

  // 데이터 로드
  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // 사용자 정보 가져오기
      currentUser = await AuthService.getUser();
      
      if (currentUser != null) {
        // 체중 기록 목록 가져오기
        final records = await WeightRepository.getWeightRecords(currentUser!.id);
        
        // 모든 기록 저장 (시간 정보 포함)
        allRecords = records;
        
        // 날짜를 키로 하는 맵으로 변환 (각 날짜의 마지막 기록)
        weightRecordsMap.clear();
        for (var record in records) {
          final dateKey = DateFormat('yyyy-MM-dd').format(
            DateTime(record.measuredAt.year, record.measuredAt.month, record.measuredAt.day)
          );
          // 같은 날짜에 여러 기록이 있으면 가장 최근 것만 저장
          if (!weightRecordsMap.containsKey(dateKey) || 
              record.measuredAt.isAfter(weightRecordsMap[dateKey]!.measuredAt)) {
            weightRecordsMap[dateKey] = record;
          }
        }
        
        setState(() {
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('체중 기록 로드 오류: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '체중 기록',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      child: isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 0. 날짜 선택 슬라이더
                  _buildDateSelector(),
                  const SizedBox(height: 16),
                  
                  // 1. 오늘의 체중
                  _buildWeightDisplay(),
                  const SizedBox(height: 24),
              
              // 2. 키 / BMI
              _buildHeightBmiRow(),
              const SizedBox(height: 16),
              
              // 3. BMI 컬러 바
              _buildBmiColorBar(),
              const SizedBox(height: 24),
              
              // 4. 기간 선택 버튼
              _buildPeriodButtons(),
              const SizedBox(height: 24),
              
              // 5. 차트
              _buildChart(),
              const SizedBox(height: 32),
              
              // 6. 눈바디 이미지
              _buildBodyImages(),
              const SizedBox(height: 24),
              
              // 7. 기록하기 버튼
              _buildAddButton(),
            ],
          ),
        ),
      ),
    );
  }

  // 0. 날짜 선택 슬라이더 (3개만 표시: 어제 - 오늘 - 내일)
  Widget _buildDateSelector() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = selectedDate.year == today.year && 
                    selectedDate.month == today.month && 
                    selectedDate.day == today.day;

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 9), // 양쪽 9px
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // 양 끝으로 배치
        children: [
          // 왼쪽 날짜 (어제)
          _buildDateItem(displayDates[0], false),
          
          // 가운데 날짜 (선택된 날짜)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDateItem(displayDates[1], true),
              if (isToday) // 오늘이면 "오늘" 표시
                Container(
                  margin: const EdgeInsets.only(left: 0),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '오늘',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          
          // 오른쪽 날짜 (내일)
          _buildDateItem(displayDates[2], false),
        ],
      ),
    );
  }

  // 날짜 아이템 위젯
  Widget _buildDateItem(DateTime date, bool isCenter) {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final hasRecord = weightRecordsMap.containsKey(dateKey);
    final dateStr = DateFormat('M.d').format(date);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedDate = date;
        });
      },
      child: Container(
        width: isCenter ? 80 : 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dateStr,
              style: TextStyle(
                fontSize: isCenter ? 18 : 14,
                fontWeight: isCenter ? FontWeight.bold : FontWeight.normal,
                color: isCenter ? Colors.black : Colors.grey[400],
              ),
            ),
            if (hasRecord)
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isCenter ? Colors.black : Colors.grey[400],
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 1. 오늘의 체중
  Widget _buildWeightDisplay() {
    final weight = selectedRecord?.weight ?? 0.0;
    final dateStr = DateFormat('yyyy년 M월 d일').format(selectedDate);
    
    return GestureDetector(
      onTap: () async {
        // 기록이 있으면 수정 모드로 이동
        if (selectedRecord != null) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WeightInputScreen(record: selectedRecord),
            ),
          );
          
          // 수정 후 데이터 새로고침
          if (result == true) {
            _loadData();
          }
        }
      },
      child: Center(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                if (selectedRecord != null) // 기록이 있으면 편집 아이콘 표시
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.edit,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: weight > 0 ? weight.toStringAsFixed(1) : '-',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  TextSpan(
                    text: weight > 0 ? ' kg' : '',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (selectedRecord != null) // 기록이 있으면 힌트 표시
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '탭하여 수정',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 2. 키 / BMI
  Widget _buildHeightBmiRow() {
    final height = selectedRecord?.height ?? 0.0;
    final bmi = selectedRecord?.bmi ?? 0.0;
    final bmiStatus = selectedRecord?.bmiStatus ?? '';
    
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Text(
                '키(cm)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                height > 0 ? '${height.toInt()} cm' : '-',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 1,
          height: 40,
          color: Colors.grey[300],
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                'BMI(신체질량지수)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: bmi > 0 ? bmi.toStringAsFixed(1) : '-',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    if (bmiStatus.isNotEmpty)
                      TextSpan(
                        text: ' $bmiStatus',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getBmiStatusColor(bmi),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // BMI 상태 색상
  Color _getBmiStatusColor(double bmi) {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 23) return Colors.green;
    if (bmi < 25) return Colors.orange;
    if (bmi < 30) return const Color(0xFFE91E63);
    return Colors.red;
  }

  // 3. BMI 컬러 바
  Widget _buildBmiColorBar() {
    final bmi = selectedRecord?.bmi ?? 0.0;
    
    if (bmi <= 0) {
      return Center(
        child: Text(
          'BMI 데이터가 없습니다',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      );
    }
    
    // BMI 위치 계산 (15 ~ 35 범위로 정규화)
    double minBmi = 15.0;
    double maxBmi = 35.0;
    double position = ((bmi - minBmi) / (maxBmi - minBmi)).clamp(0.0, 1.0);
    
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // 바의 실제 너비 사용
            final barWidth = constraints.maxWidth;
            
            return Stack(
              children: [
                // 그라데이션 바
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF4FC3F7), // 하늘색 (저체중)
                        Color(0xFF4CAF50), // 초록색 (정상)
                        Color(0xFFFF9800), // 주황색 (과체중)
                        Color(0xFFE91E63), // 분홍색 (비만)
                        Color(0xFFF44336), // 빨간색 (고도비만)
                      ],
                    ),
                  ),
                ),
                // 인디케이터
                Positioned(
                  left: (barWidth * position - 10).clamp(0.0, barWidth - 20),
                  top: -8,
                  child: Column(
                    children: [
                      Container(
                        width: 2,
                        height: 28,
                        color: Colors.white,
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        // BMI 범위 텍스트
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('저체중', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            Text('정상', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            Text('과체중', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            Text('비만', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            Text('고도비만', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ],
    );
  }

  // 4. 기간 선택 버튼
  Widget _buildPeriodButtons() {
    return Row(
      children: [
        _buildPeriodButton('일'),
        const SizedBox(width: 8),
        _buildPeriodButton('주'),
        const SizedBox(width: 8),
        _buildPeriodButton('월'),
      ],
    );
  }

  Widget _buildPeriodButton(String period) {
    bool isSelected = selectedPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedPeriod = period;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2196F3) : Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              period,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 5. 차트
  Widget _buildChart() {
    final chartData = getChartData();
    final yLabels = getYAxisLabels();
    
    // 데이터가 없으면 안내 메시지 표시
    if (chartData.isEmpty) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: Text(
            '해당 기간에 체중 기록이 없습니다',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ),
      );
    }
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Y축 라벨
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Y축 값
                SizedBox(
                  width: 45,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: yLabels.map((label) {
                      return Text(
                        '${label.round()}kg',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 8),
                // 차트 영역
                Expanded(
                  child: CustomPaint(
                    painter: WeightChartPainter(
                      chartData, 
                      yLabels[3], // 최소값 (하단) - 4개 배열이므로 인덱스 3
                      yLabels[0], // 최대값 (상단)
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // X축 라벨
          Padding(
            padding: const EdgeInsets.only(left: 53),
            child: chartData.length <= 7
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: chartData.map((data) {
                    return Text(
                      data['date'],
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    );
                  }).toList(),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      chartData.first['date'],
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                    Text(
                      chartData[chartData.length ~/ 2]['date'],
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                    Text(
                      chartData.last['date'],
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  // 6. 눈바디 이미지
  Widget _buildBodyImages() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '눈바디 이미지',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 40,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 40,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 7. 기록하기 버튼
  Widget _buildAddButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const WeightInputScreen(),
            ),
          );
          
          // 기록 추가 후 데이터 새로고침
          if (result == true) {
            _loadData();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2196F3),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text(
          '+ 기록하기',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// 체중 차트 Painter
class WeightChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double minWeight; // Y축 최소값
  final double maxWeight; // Y축 최대값
  
  WeightChartPainter(this.data, this.minWeight, this.maxWeight);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    // X축 시작점 여백 (Y축과 떨어뜨리기)
    const double leftPadding = 8.0;
    final chartWidth = size.width - leftPadding;
    
    // 그리드 선 그리기 (3개 = 4줄)
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;
    
    for (int i = 0; i <= 3; i++) {
      double y = size.height * i / 3;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
    
    // 데이터 포인트 계산
    List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
      double x = data.length == 1 
        ? leftPadding + chartWidth / 2 
        : leftPadding + (chartWidth * i / (data.length - 1));
      double weight = data[i]['weight'];
      
      // Y축 정규화 (상단이 최대값, 하단이 최소값)
      double normalizedWeight = (maxWeight - weight) / (maxWeight - minWeight);
      double y = size.height * normalizedWeight;
      
      points.add(Offset(x, y));
    }
    
    // 선 그리기 (2개 이상의 포인트가 있을 때만)
    if (points.length > 1) {
      final linePaint = Paint()
        ..color = const Color(0xFF2196F3)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      
      final path = Path();
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, linePaint);
    }
    
    // 포인트 그리기
    final pointPaint = Paint()
      ..color = const Color(0xFF2196F3)
      ..style = PaintingStyle.fill;
    
    for (var point in points) {
      canvas.drawCircle(point, 5, pointPaint);
      canvas.drawCircle(point, 3, Paint()..color = Colors.white);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
