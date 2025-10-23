import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/chart_layout.dart';
import '../../../common/widgets/period_chart_widget.dart';
import '../../../../data/models/health/weight/weight_record_model.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/repositories/health/weight/weight_repository.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../core/utils/image_picker_utils.dart';
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
  bool hasShownNoDataDialog = false; // 데이터 없음 다이얼로그를 한 번만 표시하기 위한 플래그
  
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
  
  // 그래프에서 선택된 점 (툴팁 표시용)
  int? selectedChartPointIndex;
  Offset? tooltipPosition;
  
  // 차트 관련
  double timeOffset = 0.0; // 통합된 드래그 오프셋
  double? _dragStartX;
  
  // 오늘인지 확인
  bool _isToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return selectedDate.year == today.year && 
           selectedDate.month == today.month && 
           selectedDate.day == today.day;
  }

  // 드래그 범위 제한
  double _clampDragOffset(double newOffset) {
    if (selectedPeriod == '월') {
      // 월별: 0부터 최대 오프셋까지 드래그 가능 (왼쪽으로 드래그해서 과거 날짜까지 볼 수 있음)
      final visibleDays = 7;
      final totalDays = 30;
      final maxOffset = (totalDays - visibleDays) / totalDays; // 23/30 = 0.767
      return newOffset.clamp(0.0, maxOffset);
    } else if (_isToday()) {
      // 오늘: 현재 시간 - 4시간까지만
      final now = DateTime.now();
      final currentHour = now.hour;
      final maxStartHour = (currentHour - 4).clamp(0, 18);
      final maxOffset = maxStartHour / 18.0;
      return newOffset.clamp(0.0, maxOffset);
    } else {
      // 과거 일별: 00시~24시 전체 범위
      return newOffset.clamp(0.0, 1.0);
    }
  }

  // 드래그 민감도
  double _getDragSensitivity() {
    if (selectedPeriod == '월') {
      return 3.0; // 월별 그래프는 민감도를 더 높임
    }
    return 0.5; // 일별 그래프는 기존 민감도 유지
  }

  // 공통 드래그 핸들러
  void _handleDragUpdate(double deltaX, double chartWidth) {
    final sensitivity = _getDragSensitivity();
    final dataDelta = -(deltaX / chartWidth) * sensitivity;
    final newOffset = timeOffset + dataDelta;
    
    setState(() {
      timeOffset = _clampDragOffset(newOffset);
    });
  }

  // 차트 데이터 생성
  List<Map<String, dynamic>> getChartData() {
    if (selectedPeriod != '일') {
      return _getWeeklyOrMonthlyData();
    }
    
    // 일별 차트: 선택된 날짜의 모든 기록 (시간별)
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final todayRecords = allRecords.where((record) {
      final recordDateStr = DateFormat('yyyy-MM-dd').format(record.measuredAt);
      return recordDateStr == selectedDateStr;
    }).toList();
    
    // 시간 순으로 정렬
    todayRecords.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    
    List<Map<String, dynamic>> chartData = [];
    for (var record in todayRecords) {
      chartData.add({
        'date': DateFormat('HH:mm').format(record.measuredAt), // 시간 표시
        'weight': record.weight,
        'record': record, // 실제 기록 객체 추가
        'hour': record.measuredAt.hour,
        'xPosition': null, // 일별 차트는 xPosition 사용 안함
      });
    }
    
    return chartData;
  }

  // 주/월 데이터 생성 (최적화) - 하루에 최고 체중 값만 선택
  List<Map<String, dynamic>> _getWeeklyOrMonthlyData() {
    List<Map<String, dynamic>> chartData = [];
    final days = selectedPeriod == '주' ? 7 : 30;
    
    // 오늘 날짜를 기준으로 과거 데이터 생성 (오늘이 맨 오른쪽)
    final today = DateTime.now();
    final endDate = DateTime(today.year, today.month, today.day);
    final startDate = endDate.subtract(Duration(days: days - 1));
    
    // 모든 날짜에 대해 데이터 생성 (데이터가 없어도 빈 슬롯 생성)
    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      
      // 해당 날짜의 모든 기록 가져오기
      final dayRecords = allRecords.where((record) {
        final recordDateStr = DateFormat('yyyy-MM-dd').format(record.measuredAt);
        return recordDateStr == dateKey;
      }).toList();
      
      if (dayRecords.isNotEmpty) {
        // 하루 중 체중이 가장 높은 기록 선택
        dayRecords.sort((a, b) => b.weight.compareTo(a.weight));
        final highestWeightRecord = dayRecords.first;
        
        chartData.add({
          'date': DateFormat('M.d').format(date),
          'weight': highestWeightRecord.weight,
          'record': highestWeightRecord,
          'xPosition': i / days, // X축 위치 (0~1)
        });
      } else {
        // 데이터가 없는 날짜는 null 값으로 추가 (차트에서 제외되지만 위치는 유지)
        chartData.add({
          'date': DateFormat('M.d').format(date),
          'weight': null,
          'record': null,
          'xPosition': i / days, // X축 위치 (0~1)
        });
      }
    }
    
    return chartData;
  }
  
  // Y축 범위 계산 (최저/최고 체중 기준)
  List<double> getYAxisLabels() {
    final chartData = getChartData();
    if (chartData.isEmpty) return [0, 2, 4, 6];
    
    // 모든 체중 데이터 추출 (null 값 제외)
    final weights = chartData
        .where((data) => data['weight'] != null)
        .map((data) => data['weight'] as double)
        .toList();
    
    // 유효한 체중 데이터가 없으면 기본값 반환
    if (weights.isEmpty) return [60.0, 65.0, 70.0, 75.0];
    
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

  // X축 라벨 생성 (통합)
  Widget _buildXAxisLabels(List<Map<String, dynamic>> chartData) {
    if (selectedPeriod != '일') {
      return _buildPeriodXAxisLabels(chartData);
    }
    
    // 일별 차트: 실제 측정 시간 표시
    if (chartData.isEmpty) return const SizedBox.shrink();
    
    // 데이터가 1개면 가운데에 시간 표시
    if (chartData.length == 1) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            chartData[0]['date'] ?? '',
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      );
    }
    
    // 데이터가 여러 개면 시간별로 표시 (최대 7개)
    final maxLabels = chartData.length > 7 ? 7 : chartData.length;
    final step = chartData.length > 7 ? (chartData.length / 7).ceil() : 1;
    
    List<Widget> timeLabels = [];
    for (int i = 0; i < maxLabels; i++) {
      final index = i * step;
      if (index < chartData.length) {
        timeLabels.add(
          Text(
            chartData[index]['date'] ?? '',
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        );
      }
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: timeLabels,
    );
  }

  // 주/월 X축 라벨 생성
  Widget _buildPeriodXAxisLabels(List<Map<String, dynamic>> chartData) {
    final days = selectedPeriod == '주' ? 7 : 30;
    final today = DateTime.now();
    final endDate = DateTime(today.year, today.month, today.day);
    final startDate = endDate.subtract(Duration(days: days - 1));
    
    // 모든 날짜에 대한 라벨 생성 (데이터 유무와 관계없이)
    List<String> allDateLabels = [];
    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      allDateLabels.add(DateFormat('M.d').format(date));
    }
    
    if (selectedPeriod == '주') {
      // 주별: 모든 날짜 표시
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: allDateLabels.map((label) {
          return Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          );
        }).toList(),
      );
    } else {
      // 월별: 현재 보이는 7개 날짜만 표시 (슬라이드 기능)
      final visibleDays = 7;
      final maxOffset = (days - visibleDays) / days; // 최대 오프셋
      final currentOffset = timeOffset.clamp(0.0, maxOffset);
      final startIndex = (currentOffset * days).floor();
      final endIndex = (startIndex + visibleDays).clamp(0, allDateLabels.length);
      
      List<String> visibleLabels = [];
      for (int i = startIndex; i < endIndex; i++) {
        if (i < allDateLabels.length) {
          visibleLabels.add(allDateLabels[i]);
        }
      }
      
      // 데이터 포인트와 일치하도록 X축 라벨 위치 조정
      return Row(
        children: List.generate(visibleDays, (index) {
          // 현재 보이는 범위 내에서 실제 데이터가 있는 날짜만 표시
          final actualIndex = startIndex + index;
          if (actualIndex < allDateLabels.length) {
            final label = allDateLabels[actualIndex];
            return Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            );
          } else {
            return Expanded(child: Container()); // 빈 공간
          }
        }),
      );
    }
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
    
    // 월별 그래프 초기 설정 (오늘 날짜가 맨 오른쪽에 보이도록)
    if (selectedPeriod == '월') {
      final visibleDays = 7;
      final totalDays = 30;
      final maxOffset = (totalDays - visibleDays) / totalDays;
      timeOffset = maxOffset;
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
                builder: (context) => WeightInputScreen(record: todayRecords[0]),
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
            selectedChartPointIndex = null;
            tooltipPosition = null;
            
            // 기간별 초기 설정
            if (period == '월') {
              final visibleDays = 7;
              final totalDays = 30;
              final maxOffset = (totalDays - visibleDays) / totalDays;
              timeOffset = maxOffset; // 오늘 날짜가 맨 오른쪽에 보이도록
            } else if (period == '주') {
              // 주별 그래프는 초기 오프셋 없음
              timeOffset = 0.0;
            } else if (period == '일') {
              // 일별 그래프로 돌아갈 때 오늘 날짜 기준으로 초기화
              if (_isToday()) {
                final now = DateTime.now();
                final currentHour = now.hour;
                final startHourTarget = (currentHour - 4).clamp(0, 18);
                timeOffset = startHourTarget / 18.0;
              } else {
                timeOffset = 0.0;
              }
            }
          });
          
          // 주/월 탭 선택 시 데이터 다시 로드
          if (period == '주' || period == '월') {
            _loadData();
          }
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
    
    // 주/월 차트는 항상 차트 표시 (데이터가 없어도 빈 차트)
    if (selectedPeriod != '일' && chartData.isEmpty) {
      return _buildEmptyChart();
    }
    
    // 일별 차트에서 데이터가 없으면 안내 메시지 표시
    if (selectedPeriod == '일' && chartData.isEmpty) {
      return Container(
        height: 250, // 200에서 250으로 증가
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
    
    return _buildDataChart(chartData, yLabels);
  }

  // 빈 차트 빌드 (주/월용)
  Widget _buildEmptyChart() {
    return Container(
      height: 250, // 200에서 250으로 증가
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
                    // Y축 값 (기본값)
                    SizedBox(
                      width: ChartConstants.yAxisLabelWidth,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [60.0, 65.0, 70.0, 75.0].map((label) {
                          return Text(
                            '${label.round()}kg',
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 차트 영역 (빈 그리드)
                    Expanded(
                      child: CustomPaint(
                        painter: EmptyChartGridPainter(),
                        size: Size(
                          constraints.maxWidth - ChartConstants.yAxisTotalWidth,
                          constraints.maxHeight,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // X축 라벨
          _buildXAxisLabels([]),
        ],
      ),
    );
  }

  // 차트 영역 빌드
  Widget _buildChartArea(List<Map<String, dynamic>> chartData, List<double> yLabels, BoxConstraints constraints) {
    return GestureDetector(
      onTapDown: (details) {
        _handleChartTap(
          details.localPosition, 
          chartData, 
          yLabels[3], 
          yLabels[0],
          constraints.maxWidth - ChartConstants.yAxisTotalWidth,
          constraints.maxHeight,
        );
      },
      onLongPressStart: (details) {
        _handleChartHover(
          details.localPosition, 
          chartData, 
          yLabels[3], 
          yLabels[0],
          constraints.maxWidth - ChartConstants.yAxisTotalWidth,
          constraints.maxHeight,
        );
      },
      onLongPressMoveUpdate: (details) {
        _handleChartHover(
          details.localPosition, 
          chartData, 
          yLabels[3], 
          yLabels[0],
          constraints.maxWidth - ChartConstants.yAxisTotalWidth,
          constraints.maxHeight,
        );
      },
      onLongPressEnd: (details) {
        setState(() {
          selectedChartPointIndex = null;
          tooltipPosition = null;
        });
      },
      // 드래그 기능 추가 (일별/월별)
      onPanStart: (details) {
        if (selectedPeriod == '일' || selectedPeriod == '월') {
          _dragStartX = details.localPosition.dx;
        }
      },
      onPanUpdate: (details) {
        if (selectedPeriod == '일' || selectedPeriod == '월') {
          final deltaX = details.localPosition.dx - (_dragStartX ?? 0);
          _handleDragUpdate(deltaX, constraints.maxWidth - ChartConstants.yAxisTotalWidth);
          _dragStartX = details.localPosition.dx;
        }
      },
      onPanEnd: (details) {
        _dragStartX = null;
      },
      child: Stack(
        children: [
          // 차트 (전체 크기를 차지하도록)
          Positioned.fill(
            child: CustomPaint(
              painter: WeightChartPainter(
                chartData: chartData,
                yLabels: yLabels,
                timeOffset: timeOffset,
                selectedPeriod: selectedPeriod,
                selectedPointIndex: selectedChartPointIndex,
              ),
              size: Size(
                constraints.maxWidth - ChartConstants.yAxisTotalWidth,
                constraints.maxHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 데이터가 있는 차트 빌드
  Widget _buildDataChart(List<Map<String, dynamic>> chartData, List<double> yLabels) {
    // 주/월 차트는 공통 컴포넌트 사용
    if (selectedPeriod == '주' || selectedPeriod == '월') {
      return PeriodChartWidget(
        chartData: chartData,
        yLabels: yLabels,
        selectedPeriod: selectedPeriod,
        timeOffset: timeOffset,
        onTimeOffsetChanged: (newOffset) {
          setState(() {
            timeOffset = newOffset;
          });
        },
        onTooltipChanged: (index, position) {
          setState(() {
            selectedChartPointIndex = index;
            tooltipPosition = position;
          });
        },
        selectedChartPointIndex: selectedChartPointIndex,
        tooltipPosition: tooltipPosition,
        dataType: 'weight',
        yAxisCount: yLabels.length,
      );
    }
    
    // 일별 차트는 기존 로직 유지
    return Container(
      height: 250, // 200에서 250으로 증가
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
                            '${label.round()}kg',
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 차트 영역 (클릭 및 드래그 가능)
                    Expanded(
                      child: Stack(
                        children: [
                          _buildChartArea(chartData, yLabels, constraints),
                          // 툴팁 오버레이
                          if (selectedChartPointIndex != null && tooltipPosition != null)
                            Positioned(
                              left: tooltipPosition!.dx,
                              top: tooltipPosition!.dy,
                              child: _buildChartTooltip(
                                chartData[selectedChartPointIndex!],
                                constraints.maxWidth - ChartConstants.yAxisTotalWidth,
                                constraints.maxHeight,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }
            ),
          ),
          const SizedBox(height: 10),
          // X축 라벨
          Padding(
            padding: EdgeInsets.only(left: 33.0), // Y축 라벨(25px) + 간격(8px) = 33px로 그래프와 정렬 jjy 
            child: _buildXAxisLabels(chartData),
          ),
        ],
      ),
    );
  }

  // 6. 눈바디 이미지
  Widget _buildBodyImages() {
    final frontImagePath = selectedRecord?.frontImagePath;
    final sideImagePath = selectedRecord?.sideImagePath;
    
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
            // 정면 이미지
            Expanded(
              child: _buildImageContainer(
                '정면',
                frontImagePath,
                () => _selectImage('front'),
              ),
            ),
            const SizedBox(width: 12),
            // 측면 이미지
            Expanded(
              child: _buildImageContainer(
                '측면',
                sideImagePath,
                () => _selectImage('side'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 이미지 컨테이너 위젯
  Widget _buildImageContainer(String label, String? imagePath, VoidCallback onTap) {
    final hasImage = imagePath != null && imagePath.isNotEmpty && ImagePickerUtils.isImageFileExists(imagePath);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: hasImage ? Colors.grey[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasImage ? Colors.grey[300]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: hasImage
            ? Stack(
                children: [
                  // 이미지 표시
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb 
                        ? Image.network(
                            imagePath,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildImagePlaceholder(label);
                            },
                          )
                        : Image.file(
                            File(imagePath),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildImagePlaceholder(label);
                            },
                          ),
                  ),
                  // 삭제 버튼
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _deleteImage(imagePath),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : _buildImagePlaceholder(label),
      ),
    );
  }

  // 이미지 플레이스홀더
  Widget _buildImagePlaceholder(String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 40,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 이미지 선택 및 업로드
  Future<void> _selectImage(String type) async {
    try {
      await ImagePickerUtils.showImageSourceDialog(context, (XFile? image) async {
        if (image != null) {
          String? imageUrl;
          
          if (kIsWeb) {
            // 웹에서는 XFile을 직접 전달
            try {
              imageUrl = await WeightRepository.uploadImage(image);
            } catch (e) {
              print('웹 이미지 업로드 실패: $e');
              // 업로드 실패 시 blob URL 사용 (임시)
              imageUrl = image.path;
            }
          } else {
            // 모바일에서는 실제 파일 업로드
            final File imageFile = File(image.path);
            imageUrl = await WeightRepository.uploadImage(imageFile);
          }
          
          if (imageUrl != null) {
            // 기존 이미지가 있으면 삭제 (선택사항)
            if (type == 'front' && selectedRecord?.frontImagePath != null) {
              // TODO: 기존 이미지 파일 삭제
            } else if (type == 'side' && selectedRecord?.sideImagePath != null) {
              // TODO: 기존 이미지 파일 삭제
            }
            
            // 데이터베이스 업데이트
            if (selectedRecord != null) {
              final updatedRecord = selectedRecord!.copyWith(
                frontImagePath: type == 'front' ? imageUrl : selectedRecord!.frontImagePath,
                sideImagePath: type == 'side' ? imageUrl : selectedRecord!.sideImagePath,
              );
              
              await WeightRepository.updateWeightRecord(updatedRecord);
              _loadData(); // 데이터 새로고침
            } else {
              // 새 기록 생성 (체중 입력 화면으로 이동)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WeightInputScreen(
                    initialImages: {
                      'front': type == 'front' ? imageUrl : null,
                      'side': type == 'side' ? imageUrl : null,
                    },
                  ),
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('이미지 업로드에 실패했습니다'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      });
    } catch (e) {
      print('이미지 선택 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 선택 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 이미지 삭제
  Future<void> _deleteImage(String imagePath) async {
    try {
      // 확인 다이얼로그
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('이미지 삭제'),
          content: const Text('이미지를 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('삭제'),
            ),
          ],
        ),
      );
      
      if (confirmed == true && selectedRecord != null) {
        // 파일 시스템에서 이미지 삭제
        await ImagePickerUtils.deleteImageFile(imagePath);
        
        // 데이터베이스에서 이미지 경로 제거
        final updatedRecord = selectedRecord!.copyWith(
          frontImagePath: imagePath == selectedRecord!.frontImagePath ? null : selectedRecord!.frontImagePath,
          sideImagePath: imagePath == selectedRecord!.sideImagePath ? null : selectedRecord!.sideImagePath,
        );
        
        await WeightRepository.updateWeightRecord(updatedRecord);
        _loadData(); // 데이터 새로고침
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미지가 삭제되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('이미지 삭제 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이미지 삭제 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  // 차트 클릭 핸들러 (차트의 점 클릭 감지)
  void _handleChartTap(
    Offset tapPosition, 
    List<Map<String, dynamic>> chartData, 
    double minWeight, 
    double maxWeight,
    double chartWidth,
    double chartHeight,
  ) {
    if (chartData.isEmpty) return;
    
    // 가장 가까운 점 찾기
    int? closestIndex;
    double minDistance = double.infinity;
    Offset? closestPoint;
    
    for (int i = 0; i < chartData.length; i++) {
      final data = chartData[i];
      final weight = data['weight'];
      
      if (weight == null) continue; // null 값 스킵
      
      // X 좌표 계산
      double x;
      if (selectedPeriod == '일') {
        // 일별: 시간 기반 계산
        final hour = data['hour'] as int;
        final startHour = (timeOffset * 18).round();
        final endHour = startHour + 4;
        
        if (hour < startHour || hour > endHour) continue;
        
        final hourRatio = (hour - startHour) / (endHour - startHour);
        x = chartWidth * hourRatio;
      } else {
        // 주/월별: xPosition 기반 계산
        final xPosition = data['xPosition'] as double;
        final visibleDays = selectedPeriod == '주' ? 7 : 7;
        final totalDays = selectedPeriod == '주' ? 7 : 30;
        
        if (selectedPeriod == '월') {
          final maxOffset = (totalDays - visibleDays) / totalDays;
          final currentOffset = timeOffset.clamp(0.0, maxOffset);
          final startIndex = (currentOffset * totalDays).floor();
          final endIndex = startIndex + visibleDays;
          
          // xPosition을 인덱스로 변환
          final dataIndex = (xPosition * totalDays).round();
          
          if (dataIndex < startIndex || dataIndex >= endIndex) continue;
          
          // 현재 보이는 범위 내에서의 상대적 위치 계산
          final relativeIndex = dataIndex - startIndex;
          final adjustedRatio = relativeIndex / (visibleDays - 1);
          x = 10.0 + (chartWidth - 20.0) * adjustedRatio;
        } else {
          x = 10.0 + (chartWidth - 20.0) * xPosition;
        }
      }
      
      // Y 좌표 계산
      final normalizedWeight = (maxWeight - weight) / (maxWeight - minWeight);
      final y = chartHeight * normalizedWeight;
      
      // 클릭 위치와 점 사이의 거리 계산
      final dx = tapPosition.dx - x;
      final dy = tapPosition.dy - y;
      final distance = dx * dx + dy * dy; // 제곱 거리
      
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
        closestPoint = Offset(x, y);
      }
    }
    
    // 가장 가까운 점이 있고, 거리가 20px 이내면 툴팁 표시, 아니면 숨기기
    if (closestIndex != null && minDistance < 400) {
      setState(() {
        selectedChartPointIndex = closestIndex;
        tooltipPosition = closestPoint;
      });
    } else {
      // 가까운 점이 없으면 툴팁 숨기기
      setState(() {
        selectedChartPointIndex = null;
        tooltipPosition = null;
      });
    }
  }

  // 차트 호버/드래그 핸들러 (툴팁 표시용)
  void _handleChartHover(
    Offset hoverPosition, 
    List<Map<String, dynamic>> chartData, 
    double minWeight, 
    double maxWeight,
    double chartWidth,
    double chartHeight,
  ) {
    if (chartData.isEmpty) return;
    
    // 가장 가까운 점 찾기
    int? closestIndex;
    double minDistance = double.infinity;
    Offset? closestPoint;
    
    for (int i = 0; i < chartData.length; i++) {
      final data = chartData[i];
      final weight = data['weight'];
      
      if (weight == null) continue; // null 값 스킵
      
      // X 좌표 계산
      double x;
      if (selectedPeriod == '일') {
        // 일별: 시간 기반 계산
        final hour = data['hour'] as int;
        final startHour = (timeOffset * 18).round();
        final endHour = startHour + 4;
        
        if (hour < startHour || hour > endHour) continue;
        
        final hourRatio = (hour - startHour) / (endHour - startHour);
        x = 10.0 + (chartWidth - 20.0) * hourRatio;
      } else {
        // 주/월별: xPosition 기반 계산
        final xPosition = data['xPosition'] as double;
        final visibleDays = selectedPeriod == '주' ? 7 : 7;
        final totalDays = selectedPeriod == '주' ? 7 : 30;
        
        if (selectedPeriod == '월') {
          final maxOffset = (totalDays - visibleDays) / totalDays;
          final currentOffset = timeOffset.clamp(0.0, maxOffset);
          final startIndex = (currentOffset * totalDays).floor();
          final endIndex = startIndex + visibleDays;
          
          // xPosition을 인덱스로 변환
          final dataIndex = (xPosition * totalDays).round();
          
          if (dataIndex < startIndex || dataIndex >= endIndex) continue;
          
          // 현재 보이는 범위 내에서의 상대적 위치 계산
          final relativeIndex = dataIndex - startIndex;
          final adjustedRatio = relativeIndex / (visibleDays - 1);
          x = 10.0 + (chartWidth - 20.0) * adjustedRatio;
        } else {
          x = 10.0 + (chartWidth - 20.0) * xPosition;
        }
      }
      
      // Y 좌표 계산
      final normalizedWeight = (maxWeight - weight) / (maxWeight - minWeight);
      final y = chartHeight * normalizedWeight;
      
      // 거리 계산
      final dx = hoverPosition.dx - x;
      final dy = hoverPosition.dy - y;
      final distance = dx * dx + dy * dy;
      
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
        closestPoint = Offset(x, y);
      }
    }
    
    // 가장 가까운 점이 있으면 툴팁 표시 (거리 제한 더 넓게: 50px = 2500)
    if (closestIndex != null && minDistance < 2500) {
      setState(() {
        selectedChartPointIndex = closestIndex;
        tooltipPosition = closestPoint;
      });
    } else {
      setState(() {
        selectedChartPointIndex = null;
        tooltipPosition = null;
      });
    }
  }

  // 차트 툴팁 위젯
  Widget _buildChartTooltip(Map<String, dynamic> data, double chartWidth, double chartHeight) {
    if (tooltipPosition == null) return const SizedBox.shrink();
    
    final weight = data['weight'];
    final record = data['record'];
    
    // null 값 체크
    if (weight == null || record == null) return const SizedBox.shrink();
    
    final weightValue = weight as double;
    final weightRecord = record as WeightRecord;
    
    // 측정 시간 표시 (일 기간일 때는 시간, 주/월 기간일 때는 날짜+시간)
    String timeLabel;
    if (selectedPeriod == '일') {
      timeLabel = DateFormat('HH:mm').format(weightRecord.measuredAt);
    } else {
      timeLabel = DateFormat('M/d HH:mm').format(weightRecord.measuredAt);
    }
    
    // 간단한 툴팁 위치 계산 (차트 영역 내에서만 표시)
    double tooltipX = tooltipPosition!.dx;
    double tooltipY = tooltipPosition!.dy - 60; // 툴팁을 점 위쪽에 표시
    
    // 차트 영역을 벗어나지 않도록 조정
    if (tooltipX < 0) tooltipX = 0;
    if (tooltipX > chartWidth - 100) tooltipX = chartWidth - 100; // 툴팁 너비 고려
    if (tooltipY < 0) tooltipY = tooltipPosition!.dy + 20; // 아래쪽에 표시
    if (tooltipY > chartHeight - 50) tooltipY = chartHeight - 50; // 툴팁 높이 고려
    
    return Positioned(
      left: tooltipX,
      top: tooltipY,
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
              '${weightValue.toStringAsFixed(1)} kg',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              timeLabel,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 시간별 기록 선택 바텀시트
  void _showTimeSelectionBottomSheet(List<WeightRecord> records) {
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
                    Navigator.pop(context); // 바텀시트 닫기
                    
                    // 수정 페이지로 이동
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WeightInputScreen(record: record),
                      ),
                    );
                    
                    // 수정 후 데이터 새로고침
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
                        // 시간
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
                        // 체중
                        Row(
                          children: [
                            Text(
                              '${record.weight.toStringAsFixed(1)} kg',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
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
        title: const Text('체중 기록 없음'),
        content: const Text(
          '아직 체중 기록이 없습니다.\n지금 체중을 입력해주세요!',
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
              
              // 체중 입력 페이지로 이동
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WeightInputScreen(),
                ),
              );
              
              // 입력 완료 후 데이터 새로고침
              if (result == true && mounted) {
                await _loadData();
              }
            },
            child: const Text('체중 입력하기'),
          ),
        ],
      ),
    );
  }
}

// 빈 차트 그리드 Painter
class EmptyChartGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 그리드 선 그리기
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;
    
    for (int i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 체중 차트 Painter
class WeightChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> chartData;
  final List<double> yLabels;
  final double timeOffset;
  final String selectedPeriod;
  final int? selectedPointIndex;
  
  WeightChartPainter({
    required this.chartData,
    required this.yLabels,
    required this.timeOffset,
    required this.selectedPeriod,
    this.selectedPointIndex,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (chartData.isEmpty) return;
    
    final minWeight = yLabels[3]; // 최소값 (하단)
    final maxWeight = yLabels[0]; // 최대값 (상단)
    
    // 그리드 선 그리기 (패딩 적용)
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;
    
    const double leftPadding = 10.0;
    const double rightPadding = 10.0;
    
    for (int i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(
        Offset(leftPadding, y),  // 왼쪽 패딩 추가
        Offset(size.width - rightPadding, y),  // 오른쪽 패딩 추가
        gridPaint,
      );
    }
    
    // 데이터 포인트 계산 및 필터링
    List<Offset> points = [];
    List<int> validIndices = [];
    
    for (int i = 0; i < chartData.length; i++) {
      final data = chartData[i];
      final weight = data['weight'];
      
      if (weight == null) continue; // null 값 스킵
      
      // X 좌표 계산
      double x;
      if (selectedPeriod == '일') {
        // 일별: 시간 기반 계산
        final hour = data['hour'] as int;
        final startHour = (timeOffset * 18).round();
        final endHour = startHour + 4;
        
        if (hour < startHour || hour > endHour) continue;
        
        final hourRatio = (hour - startHour) / (endHour - startHour);
        x = leftPadding + (size.width - leftPadding - rightPadding) * hourRatio;
      } else {
        // 주/월별: xPosition 기반 계산
        final xPosition = data['xPosition'] as double;
        final visibleDays = selectedPeriod == '주' ? 7 : 7;
        final totalDays = selectedPeriod == '주' ? 7 : 30;
        
        if (selectedPeriod == '월') {
          final maxOffset = (totalDays - visibleDays) / totalDays;
          final currentOffset = timeOffset.clamp(0.0, maxOffset);
          final startIndex = (currentOffset * totalDays).floor();
          final endIndex = startIndex + visibleDays;
          
          // xPosition을 인덱스로 변환
          final dataIndex = (xPosition * totalDays).round();
          
          if (dataIndex < startIndex || dataIndex >= endIndex) continue;
          
          // 현재 보이는 범위 내에서의 상대적 위치 계산
          final relativeIndex = dataIndex - startIndex;
          final adjustedRatio = relativeIndex / (visibleDays - 1);
          x = leftPadding + (size.width - leftPadding - rightPadding) * adjustedRatio;
        } else {
          x = leftPadding + (size.width - leftPadding - rightPadding) * xPosition;
        }
      }
      
      // Y 좌표 계산
      final normalizedWeight = (maxWeight - weight) / (maxWeight - minWeight);
      final y = size.height * normalizedWeight;
      
      points.add(Offset(x, y));
      validIndices.add(i);
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
    
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final originalIndex = validIndices[i];
      final isSelected = selectedPointIndex != null && selectedPointIndex == originalIndex;
      
      if (isSelected) {
        // 선택된 점 - 더 크게 그리기
        canvas.drawCircle(point, 8, pointPaint);
        canvas.drawCircle(point, 5, Paint()..color = Colors.white);
        // 외곽선 추가
        canvas.drawCircle(
          point, 
          8, 
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        // 일반 점
        canvas.drawCircle(point, 5, pointPaint);
        canvas.drawCircle(point, 3, Paint()..color = Colors.white);
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
