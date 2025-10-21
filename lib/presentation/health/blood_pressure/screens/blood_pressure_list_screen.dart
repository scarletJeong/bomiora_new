import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/chart_layout.dart';
import '../../../../data/models/health/blood_pressure/blood_pressure_record_model.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/repositories/health/blood_pressure/blood_pressure_repository.dart';
import '../../../../data/services/auth_service.dart';
import 'blood_pressure_input_screen.dart';

class BloodPressureListScreen extends StatefulWidget {
  final DateTime? initialDate; // 초기 선택 날짜 (옵션)
  
  const BloodPressureListScreen({super.key, this.initialDate});

  @override
  State<BloodPressureListScreen> createState() => _BloodPressureListScreenState();
}

class _BloodPressureListScreenState extends State<BloodPressureListScreen> {
  String selectedPeriod = '일'; // 일, 주, 월
  
  // 사용자 정보
  UserModel? currentUser;
  
  // 혈압 기록 목록 (날짜별)
  Map<String, BloodPressureRecord> bloodPressureRecordsMap = {}; // 날짜를 키로 하는 맵
  List<BloodPressureRecord> allRecords = []; // 모든 혈압 기록 (시간 정보 포함)
  bool isLoading = true;
  bool hasShownNoDataDialog = false; // 데이터 없음 다이얼로그를 한 번만 표시하기 위한 플래그
  
  // 현재 선택된 날짜 (기본값: 오늘)
  late DateTime selectedDate;
  
  // 그래프에서 선택된 점 (툴팁 표시용)
  int? selectedChartPointIndex;
  Offset? tooltipPosition;
  
  // 표시할 3개의 날짜 (이전날, 선택된날, 다음날)
  List<DateTime> get displayDates {
    return [
      selectedDate.subtract(const Duration(days: 1)), // 어제
      selectedDate,                                    // 오늘 (선택된 날짜)
      selectedDate.add(const Duration(days: 1)),       // 내일
    ];
  }
  
  // 현재 선택된 날짜의 기록
  BloodPressureRecord? get selectedRecord {
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    return bloodPressureRecordsMap[dateKey];
  }
  
  // 차트 데이터 생성
  List<Map<String, dynamic>> getChartData() {
    List<Map<String, dynamic>> chartData = [];
    
    if (selectedPeriod == '일') {
      // 현재 시간 기준으로 앞뒤 3시간씩 (총 7개 시간대)
      final now = DateTime.now();
      final currentHour = now.hour;
      
      // 선택된 날짜의 모든 기록
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      final todayRecords = allRecords.where((record) {
        final recordDateStr = DateFormat('yyyy-MM-dd').format(record.measuredAt);
        return recordDateStr == selectedDateStr;
      }).toList();
      
      // 모든 실제 측정 기록을 시간순으로 정렬
      todayRecords.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
      
      // 실제 측정 기록을 모두 차트 데이터로 변환
      for (var record in todayRecords) {
        final recordHour = record.measuredAt.hour;
        final recordMinute = record.measuredAt.minute;
        
        // 현재 시간 기준으로 상대적 위치 계산
        final currentHour = now.hour;
        final hourDiff = recordHour - currentHour;
        
        // 시간대가 범위 내에 있는지 확인 (-4 ~ +2)
        if (hourDiff >= -4 && hourDiff <= 2) {
          // 5분 단위로 정규화
          final normalizedMinute = (recordMinute / 5).floor() * 5;
          
          // 시간대 내에서의 위치 계산 (0-1 사이의 비율)
          double minuteRatio = normalizedMinute / 60.0;
          
          // 전체 차트에서의 위치 계산
          double xPosition = (hourDiff + 4) / 6.0; // -4~+2를 0~1로 정규화
          xPosition += minuteRatio / 6.0; // 분 단위 추가
          
          // 안전한 데이터 추가
          final dateStr = '${recordHour.toString().padLeft(2, '0')}시';
          chartData.add({
            'date': dateStr,
            'hour': recordHour,
            'systolic': record.systolic,
            'diastolic': record.diastolic,
            'record': record,
            'actualHour': recordHour,
            'actualMinute': recordMinute,
            'normalizedMinute': normalizedMinute,
            'xPosition': xPosition,
          });
        }
      }
      
      // 차트 데이터만 반환 (null 값과 유효하지 않은 데이터 제거)
      chartData = chartData.where((data) => 
        data['systolic'] != null && 
        data['diastolic'] != null && 
        data['record'] != null &&
        data['date'] != null &&
        data['xPosition'] != null
      ).toList();
    } else if (selectedPeriod == '주') {
      // 오늘부터 7일 전까지 (데이터가 있는 날짜만)
      final endDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final startDate = endDate.subtract(const Duration(days: 6));
      
      for (int i = 0; i < 7; i++) {
        final date = startDate.add(Duration(days: i));
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        
        if (bloodPressureRecordsMap.containsKey(dateKey)) {
          chartData.add({
            'date': DateFormat('M.d').format(date),
            'systolic': bloodPressureRecordsMap[dateKey]!.systolic,
            'diastolic': bloodPressureRecordsMap[dateKey]!.diastolic,
            'record': bloodPressureRecordsMap[dateKey]!,
          });
        }
      }
    } else if (selectedPeriod == '월') {
      // 오늘부터 30일 전까지 (데이터가 있는 날짜만)
      final endDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final startDate = endDate.subtract(const Duration(days: 29));
      
      for (int i = 0; i < 30; i++) {
        final date = startDate.add(Duration(days: i));
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        
        if (bloodPressureRecordsMap.containsKey(dateKey)) {
          chartData.add({
            'date': DateFormat('M.d').format(date),
            'systolic': bloodPressureRecordsMap[dateKey]!.systolic,
            'diastolic': bloodPressureRecordsMap[dateKey]!.diastolic,
            'record': bloodPressureRecordsMap[dateKey]!,
          });
        }
      }
    }
    
    return chartData;
  }
  
  // Y축 범위 계산 (고정 범위)
  List<double> getYAxisLabels() {
    // 고정 Y축 범위: 20, 60, 100, 140, 180, 220
    return [220, 180, 140, 100, 60, 20];
  }
  
  // 점선 Y축 라벨 (40, 80, 120, 160, 200)
  List<double> getDashedYAxisLabels() {
    return [200, 160, 120, 80, 40];
  }

  @override
  void initState() {
    super.initState();
    // 전달받은 날짜 또는 오늘 날짜로 초기화
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
        // 혈압 기록 목록 가져오기
        final records = await BloodPressureRepository.getBloodPressureRecords(currentUser!.id);
        
        // 모든 기록 저장 (시간 정보 포함)
        allRecords = records;
        
        // 날짜를 키로 하는 맵으로 변환 (각 날짜의 마지막 기록)
        bloodPressureRecordsMap.clear();
        for (var record in records) {
          final dateKey = DateFormat('yyyy-MM-dd').format(
            DateTime(record.measuredAt.year, record.measuredAt.month, record.measuredAt.day)
          );
          // 같은 날짜에 여러 기록이 있으면 가장 최근 것만 저장
          if (!bloodPressureRecordsMap.containsKey(dateKey) || 
              record.measuredAt.isAfter(bloodPressureRecordsMap[dateKey]!.measuredAt)) {
            bloodPressureRecordsMap[dateKey] = record;
          }
        }
        
        // 데이터가 없으면 다이얼로그 표시 (한 번만)
        if (records.isEmpty && mounted && !hasShownNoDataDialog) {
          hasShownNoDataDialog = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showNoDataDialog();
          });
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
      print('혈압 기록 로드 오류: $e');
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
          '혈압',
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
                  
                  // 1. 오늘의 혈압
                  _buildBloodPressureDisplay(),
                  const SizedBox(height: 24),
              
              // 2. 기간 선택 버튼
              _buildPeriodButtons(),
              const SizedBox(height: 24),
              
              // 3. 차트
              _buildChart(),
              const SizedBox(height: 32),
              
              // 4. 기록하기 버튼
              _buildAddButton(),
            ],
          ),
        ),
      ),
    );
  }

  // 0. 날짜 선택 슬라이더
  Widget _buildDateSelector() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = selectedDate.year == today.year && 
                    selectedDate.month == today.month && 
                    selectedDate.day == today.day;

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 왼쪽 날짜 (어제)
          _buildDateItem(displayDates[0], false),
          
          // 가운데 날짜 (선택된 날짜)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDateItem(displayDates[1], true),
              if (isToday)
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
    final hasRecord = bloodPressureRecordsMap.containsKey(dateKey);
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

  // 1. 오늘의 혈압
  Widget _buildBloodPressureDisplay() {
    final systolic = selectedRecord?.systolic ?? 0;
    final diastolic = selectedRecord?.diastolic ?? 0;
    final dateStr = DateFormat('yyyy년 M월 d일').format(selectedDate);
    
    return GestureDetector(
      onTap: () async {
        // 기록이 있으면 하루의 기록 개수 확인
        if (selectedRecord != null) {
          // 선택된 날짜의 모든 기록 가져오기
          final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
          final todayRecords = allRecords.where((record) {
            final recordDateStr = DateFormat('yyyy-MM-dd').format(record.measuredAt);
            return recordDateStr == selectedDateStr;
          }).toList();
          
          // 시간 순으로 정렬
          todayRecords.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
          
          if (todayRecords.length > 1) {
            // 여러 개면 시간별 리스트 표시
            _showTimeSelectionBottomSheet(todayRecords);
          } else if (todayRecords.length == 1) {
            // 한 개면 바로 수정 페이지로 이동
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BloodPressureInputScreen(record: todayRecords[0]),
              ),
            );
            
            // 수정 후 데이터 새로고침
            if (result == true) {
              _loadData();
            }
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
                if (selectedRecord != null)
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
            const SizedBox(height: 16),
            const Text(
              '오늘의 혈압',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 수축기
                Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          systolic > 0 ? systolic.toString() : '-',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        if (systolic > 0)
                          Text(
                            ' mmHg',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '수축기',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 32),
                // 이완기
                Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          diastolic > 0 ? diastolic.toString() : '-',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        if (diastolic > 0)
                          Text(
                            ' mmHg',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '이완기',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (selectedRecord != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
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

  // 2. 기간 선택 버튼
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

  // 3. 차트
  Widget _buildChart() {
    final chartData = getChartData();
    final yLabels = getYAxisLabels();
    
    // 데이터가 없으면 안내 메시지 표시
    if (chartData.isEmpty) {
      return Container(
        height: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: Text(
            '해당 기간에 혈압 기록이 없습니다',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ),
      );
    }
    
    return Container(
      height: 350,  // 높이 증가
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Y축 값
                    SizedBox(
                      width: ChartConstants.yAxisLabelWidth,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: yLabels.map((label) {
                          return Text(
                            '${label.round()}',
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(width: ChartConstants.yAxisSpacing),
                    // 차트 영역 (클릭 및 드래그 가능)
                    Expanded(
                      child: GestureDetector(
                        // 탭하면 툴팁 표시/숨기기 토글
                        onTapDown: (details) {
                          _handleChartTapToggle(
                            details.localPosition, 
                            chartData, 
                            20,  // 최소값 (고정)
                            220, // 최대값 (고정)
                            constraints.maxWidth - ChartConstants.yAxisTotalWidth,  // 차트 실제 너비
                            constraints.maxHeight,
                          );
                        },
                        child: Stack(
                          children: [
                            // 차트 (전체 크기를 차지하도록)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: BloodPressureChartPainter(
                                  chartData, 
                                  20,  // 최소값 (고정)
                                  220, // 최대값 (고정)
                                  highlightedIndex: selectedChartPointIndex,
                                ),
                              ),
                            ),
                            // 툴팁
                            if (selectedChartPointIndex != null && tooltipPosition != null)
                              _buildChartTooltip(chartData[selectedChartPointIndex!]),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
            ),
          ),
          const SizedBox(height: 8),
          // X축 라벨 (고정된 시간대 표시)
          Padding(
            padding: EdgeInsets.only(left: ChartConstants.yAxisTotalWidth),
            child: selectedPeriod == '일'
              ? Builder(
                  builder: (context) {
                    // 현재 시간 기준으로 X축 라벨 생성
                    final now = DateTime.now();
                    final currentHour = now.hour;
                    List<Widget> hourLabels = [];
                    
                    for (int i = -4; i <= 2; i++) {
                      final targetHour = currentHour + i;
                      final hourLabel = '${targetHour.toString().padLeft(2, '0')}시';
                      hourLabels.add(
                        Text(hourLabel, style: TextStyle(fontSize: 10, color: Colors.grey[600]))
                      );
                    }
                    
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: hourLabels,
                    );
                  },
                )
              : chartData.isEmpty
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('시간', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      Text('시간', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      Text('시간', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    ],
                  )
                : chartData.length <= 7
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: chartData.where((data) => data['date'] != null).map((data) {
                        final dateStr = data['date'];
                        return Text(
                          dateStr is String ? dateStr : '시간',
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        );
                      }).toList(),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          chartData.first['date'] is String ? chartData.first['date'] as String : '시간',
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                        Text(
                          chartData[chartData.length ~/ 2]['date'] is String ? chartData[chartData.length ~/ 2]['date'] as String : '시간',
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                        Text(
                          chartData.last['date'] is String ? chartData.last['date'] as String : '시간',
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  // 차트 클릭 핸들러
  // 차트 탭 핸들러 - 툴팁 토글
  void _handleChartTapToggle(
    Offset tapPosition, 
    List<Map<String, dynamic>> chartData, 
    double minValue, 
    double maxValue,
    double chartWidth,
    double chartHeight,
  ) {
    if (chartData.isEmpty) return;
    
    const double leftPadding = 0.0;
    final double effectiveWidth = chartWidth - leftPadding;
    
    int? closestIndex;
    double minDistance = double.infinity;
    Offset? closestPoint;
    
    for (int i = 0; i < chartData.length; i++) {
      // null 데이터는 건너뛰기
      if (chartData[i]['systolic'] == null || chartData[i]['diastolic'] == null) continue;
      
      double x;
      if (chartData[i]['xPosition'] != null) {
        // 미리 계산된 xPosition 사용
        final xPosition = chartData[i]['xPosition'] as double;
        x = leftPadding + (effectiveWidth * xPosition);
      } else if (chartData.length == 1) {
        x = leftPadding + effectiveWidth / 2;
      } else {
        x = leftPadding + (effectiveWidth * i / (chartData.length - 1));
      }
      
      // 수축기 기준으로 Y 좌표 계산 (고정 범위: 20-220)
      int systolic = chartData[i]['systolic'] as int;
      double normalizedValue = (220 - systolic) / (220 - 20);
      double y = chartHeight * normalizedValue;
      
      double dx = tapPosition.dx - x;
      double dy = tapPosition.dy - y;
      double distance = (dx * dx + dy * dy);
      
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
        closestPoint = Offset(x, y);
      }
    }
    
    // 가까운 점을 찾았으면 툴팁 토글
    if (closestIndex != null && minDistance < 1000) {
      setState(() {
        // 같은 점을 다시 탭하면 툴팁 숨기기
        if (selectedChartPointIndex == closestIndex) {
          selectedChartPointIndex = null;
          tooltipPosition = null;
        } else {
          // 새로운 점을 탭하면 툴팁 표시
          selectedChartPointIndex = closestIndex;
          tooltipPosition = closestPoint;
        }
      });
    } else {
      // 점 근처가 아니면 툴팁 숨기기
      setState(() {
        selectedChartPointIndex = null;
        tooltipPosition = null;
      });
    }
  }

  // 차트 툴팁 위젯
  Widget _buildChartTooltip(Map<String, dynamic> data) {
    if (tooltipPosition == null) return const SizedBox.shrink();
    
    // null 체크 추가
    if (data['systolic'] == null || data['diastolic'] == null) {
      return const SizedBox.shrink();
    }
    
    final systolic = data['systolic'] as int;
    final diastolic = data['diastolic'] as int;
    final record = data['record'] as BloodPressureRecord?;
    
    // 측정 시간 표시 (record가 있으면 실제 측정 시간, 없으면 시간대)
    final dateLabel = record != null 
        ? DateFormat('HH:mm').format(record.measuredAt)
        : (data['date'] is String ? data['date'] as String : '시간');
    
    return Positioned(
      left: (tooltipPosition!.dx - 40).clamp(0.0, double.infinity),
      top: (tooltipPosition!.dy - 65).clamp(0.0, double.infinity),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$systolic / $diastolic mmHg',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              dateLabel,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 4. 기록하기 버튼
  Widget _buildAddButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BloodPressureInputScreen(),
            ),
          );
          
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

  // 시간별 기록 선택 바텀시트
  void _showTimeSelectionBottomSheet(List<BloodPressureRecord> records) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '수정할 시간 선택 (${records.length}개)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),
              // 시간별 리스트
              ...records.map((record) {
                final timeStr = DateFormat('HH:mm').format(record.measuredAt);
                return InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BloodPressureInputScreen(record: record),
                      ),
                    );
                    
                    if (result == true) {
                      _loadData();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 20, color: Colors.grey[600]),
                            const SizedBox(width: 12),
                            Text(
                              timeStr,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              '${record.systolic}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            Text(
                              ' / ',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '${record.diastolic}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right, color: Colors.grey[400]),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // 데이터 없을 때 다이얼로그 표시
  void _showNoDataDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('혈압 기록 없음'),
        content: const Text(
          '아직 혈압 기록이 없습니다.\n지금 혈압을 입력해주세요!',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 다이얼로그 닫기
            },
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // 다이얼로그 닫기
              
              // 혈압 입력 페이지로 이동
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BloodPressureInputScreen(),
                ),
              );
              
              // 입력 완료 후 데이터 새로고침
              if (result == true && mounted) {
                await _loadData();
              }
            },
            child: const Text('혈압 입력하기'),
          ),
        ],
      ),
    );
  }
}

// 혈압 차트 Painter
class BloodPressureChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double minValue;
  final double maxValue;
  final int? highlightedIndex;
  
  BloodPressureChartPainter(
    this.data, 
    this.minValue, 
    this.maxValue, 
    {this.highlightedIndex}
  );
  
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    const double leftPadding = 0.0;
    final chartWidth = size.width - leftPadding;
    
    // 그리드 선 (고정 Y축: 20, 60, 100, 140, 180, 220)
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;
    
    // 점선 그리드 (40, 80, 120, 160, 200)
    final dashedGridPaint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 0.5;
    
    // 고정 Y축 값들
    final yValues = [220, 180, 140, 100, 60, 20];
    final dashedYValues = [200, 160, 120, 80, 40];
    
    // 실선 그리드 그리기
    for (int i = 0; i < yValues.length; i++) {
      double y = size.height * i / (yValues.length - 1);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
    
    // 점선 그리드 그리기
    for (int dashedValue in dashedYValues) {
      // Y축 값에 해당하는 위치 계산
      double normalizedY = (220 - dashedValue) / (220 - 20);
      double y = size.height * normalizedY;
      
      // 점선 그리기 (간단한 점선 효과)
      for (double x = leftPadding; x < size.width; x += 4) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x + 2, y),
          dashedGridPaint,
        );
      }
    }
    
    // 데이터 포인트 계산 - 연속된 데이터 그룹으로 분리
    List<List<Offset>> systolicSegments = [];
    List<List<Offset>> diastolicSegments = [];
    List<List<int>> indexSegments = [];
    
    List<Offset> currentSystolic = [];
    List<Offset> currentDiastolic = [];
    List<int> currentIndices = [];
    
    for (int i = 0; i < data.length; i++) {
      // null 데이터는 건너뛰기
      if (data[i]['systolic'] == null || data[i]['diastolic'] == null) continue;
      
      // 정확한 위치 계산
      double x;
      if (data[i]['xPosition'] != null) {
        // 미리 계산된 xPosition 사용
        final xPosition = data[i]['xPosition'] as double;
        x = leftPadding + (chartWidth * xPosition);
      } else {
        // 기본 위치 계산 (X축 라벨용)
        x = data.length == 1 
          ? leftPadding + chartWidth / 2 
          : leftPadding + (chartWidth * i / (data.length - 1));
      }
      
      int systolic = data[i]['systolic'];
      int diastolic = data[i]['diastolic'];
      
      // Y축 정규화 (고정 범위: 20-220)
      double normalizedSystolic = (220 - systolic) / (220 - 20);
      double ySystolic = size.height * normalizedSystolic;
      
      double normalizedDiastolic = (220 - diastolic) / (220 - 20);
      double yDiastolic = size.height * normalizedDiastolic;
      
      currentSystolic.add(Offset(x, ySystolic));
      currentDiastolic.add(Offset(x, yDiastolic));
      currentIndices.add(i);
    }
    
    // 마지막 세그먼트 저장
    if (currentSystolic.isNotEmpty) {
      systolicSegments.add(currentSystolic);
      diastolicSegments.add(currentDiastolic);
      indexSegments.add(currentIndices);
    }
    
    final linePaint = Paint()
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    
    // 수축기 부드러운 곡선 그리기 (Catmull-Rom 스플라인)
    linePaint.color = Colors.red;
    for (var segment in systolicSegments) {
      if (segment.length == 1) {
        // 단일 포인트는 그리지 않음 (나중에 점만 표시)
        continue;
      }
      
      final path = Path();
      path.moveTo(segment[0].dx, segment[0].dy);
      
      if (segment.length == 2) {
        // 2개 포인트만 있으면 직선
        path.lineTo(segment[1].dx, segment[1].dy);
      } else {
        // 3개 이상이면 Catmull-Rom 스플라인
        for (int i = 0; i < segment.length - 1; i++) {
          final p0 = i > 0 ? segment[i - 1] : segment[i];
          final p1 = segment[i];
          final p2 = segment[i + 1];
          final p3 = i < segment.length - 2 ? segment[i + 2] : segment[i + 1];
          
          // Catmull-Rom 스플라인의 제어점 계산
          final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
          final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
          final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
          final cp2y = p2.dy - (p3.dy - p1.dy) / 6;
          
          path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
        }
      }
      
      canvas.drawPath(path, linePaint);
    }
    
    // 이완기 부드러운 곡선 그리기 (Catmull-Rom 스플라인)
    linePaint.color = Colors.blue;
    for (var segment in diastolicSegments) {
      if (segment.length == 1) {
        // 단일 포인트는 그리지 않음 (나중에 점만 표시)
        continue;
      }
      
      final path = Path();
      path.moveTo(segment[0].dx, segment[0].dy);
      
      if (segment.length == 2) {
        // 2개 포인트만 있으면 직선
        path.lineTo(segment[1].dx, segment[1].dy);
      } else {
        // 3개 이상이면 Catmull-Rom 스플라인
        for (int i = 0; i < segment.length - 1; i++) {
          final p0 = i > 0 ? segment[i - 1] : segment[i];
          final p1 = segment[i];
          final p2 = segment[i + 1];
          final p3 = i < segment.length - 2 ? segment[i + 2] : segment[i + 1];
          
          // Catmull-Rom 스플라인의 제어점 계산
          final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
          final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
          final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
          final cp2y = p2.dy - (p3.dy - p1.dy) / 6;
          
          path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
        }
      }
      
      canvas.drawPath(path, linePaint);
    }
    
    // 포인트 그리기 (세그먼트별로)
    for (int segIdx = 0; segIdx < systolicSegments.length; segIdx++) {
      final systolicPoints = systolicSegments[segIdx];
      final diastolicPoints = diastolicSegments[segIdx];
      final dataIndices = indexSegments[segIdx];
      
      for (int i = 0; i < systolicPoints.length; i++) {
        final originalIndex = dataIndices[i];
        final isHighlighted = highlightedIndex != null && highlightedIndex == originalIndex;
        
        // 수축기 점 (빨간색)
        final systolicPaint = Paint()
          ..color = Colors.red
          ..style = PaintingStyle.fill;
        
        if (isHighlighted) {
          canvas.drawCircle(systolicPoints[i], 8, systolicPaint);
          canvas.drawCircle(systolicPoints[i], 5, Paint()..color = Colors.white);
          canvas.drawCircle(
            systolicPoints[i], 
            8, 
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        } else {
          canvas.drawCircle(systolicPoints[i], 5, systolicPaint);
          canvas.drawCircle(systolicPoints[i], 3, Paint()..color = Colors.white);
        }
        
        // 이완기 점 (파란색)
        final diastolicPaint = Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.fill;
        
        if (isHighlighted) {
          canvas.drawCircle(diastolicPoints[i], 8, diastolicPaint);
          canvas.drawCircle(diastolicPoints[i], 5, Paint()..color = Colors.white);
          canvas.drawCircle(
            diastolicPoints[i], 
            8, 
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        } else {
          canvas.drawCircle(diastolicPoints[i], 5, diastolicPaint);
          canvas.drawCircle(diastolicPoints[i], 3, Paint()..color = Colors.white);
        }
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

