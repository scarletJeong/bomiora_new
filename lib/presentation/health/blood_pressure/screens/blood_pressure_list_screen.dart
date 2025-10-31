import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/btn_record.dart';
import '../../../common/widgets/date_top_widget.dart';
import '../../../common/chart_layout.dart';
import '../../../common/widgets/period_chart_widget.dart';
import '../../../../data/models/health/blood_pressure/blood_pressure_record_model.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/repositories/health/blood_pressure/blood_pressure_repository.dart';
import '../../../../data/services/auth_service.dart';
import 'blood_pressure_input_screen.dart';

class BloodPressureListScreen extends StatefulWidget {
  final DateTime? initialDate;
  
  const BloodPressureListScreen({super.key, this.initialDate});

  @override
  State<BloodPressureListScreen> createState() => _BloodPressureListScreenState();
}

class _BloodPressureListScreenState extends State<BloodPressureListScreen> {
  String selectedPeriod = '일';
  UserModel? currentUser;
  List<BloodPressureRecord> allRecords = []; // 전체 혈압 기록
  Map<String, BloodPressureRecord> bloodPressureRecordsMap = {}; // 날짜별 요약 기록
  Map<String, List<BloodPressureRecord>> dailyRecordsCache = {}; // 날짜별 상세 기록 캐시
  bool isLoading = true;
  bool hasShownNoDataDialog = false;
  late DateTime selectedDate;
  
  // 차트 관련
  int? selectedChartPointIndex;
  Offset? tooltipPosition;
  double timeOffset = 0.0; // 통합된 드래그 오프셋
  double? _dragStartX;

  // 표시할 3개의 날짜
  List<DateTime> get displayDates {
    return [
      selectedDate.subtract(const Duration(days: 1)),
      selectedDate,
      selectedDate.add(const Duration(days: 1)),
    ];
  }
  
  BloodPressureRecord? get selectedRecord {
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    return bloodPressureRecordsMap[dateKey];
  }
  
  // 오늘인지 확인
  bool _isToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return selectedDate.year == today.year && 
           selectedDate.month == today.month && 
           selectedDate.day == today.day;
  }

  // 시간 범위 계산 (통합 로직)
  Map<String, double> _calculateTimeRange() {
    const maxStartHour = 18; // 24시 - 6시간 = 18시 (7개 라벨)
    final startHour = (timeOffset * maxStartHour).clamp(0.0, maxStartHour.toDouble());
    final endHour = (startHour + 6.0).clamp(6.0, 24.0);
    
    return {'min': startHour, 'max': endHour};
  }

  // 드래그 범위 제한
  double _clampDragOffset(double newOffset) {
    if (_isToday()) {
      // 오늘: 현재 시간 - 4시간까지만
      final now = DateTime.now();
      final currentHour = now.hour;
      final maxStartHour = (currentHour - 4).clamp(0, 18);
      final maxOffset = maxStartHour / 18.0;
      return newOffset.clamp(0.0, maxOffset);
    } else if (selectedPeriod == '월') {
      // 월별: 0부터 최대 오프셋까지 드래그 가능 (왼쪽으로 드래그해서 과거 날짜까지 볼 수 있음)
      final visibleDays = 7;
      final totalDays = 30;
      final maxOffset = (totalDays - visibleDays) / totalDays; // 23/30 = 0.767
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

  // 차트 데이터 생성 (캐시 없이 매번 로드)
  List<Map<String, dynamic>> getChartData() {
    if (selectedPeriod != '일') {
      return _getWeeklyOrMonthlyData();
    }
    
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    
    // 캐시에서 데이터 가져오기 (없으면 빈 배열)
    final dayRecords = dailyRecordsCache[selectedDateStr] ?? [];
    
    dayRecords.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    
    final timeRange = _calculateTimeRange();
    final minHourDiff = timeRange['min']!;
    final maxHourDiff = timeRange['max']!;
    
    List<Map<String, dynamic>> chartData = [];
    
    for (var record in dayRecords) {
      final recordHour = record.measuredAt.hour;
      final recordMinute = record.measuredAt.minute;
      
      // 통합 로직: 모든 데이터 표시 (필터링은 Painter에서)
      final chartPoint = _createChartPoint(record, recordHour, recordMinute, minHourDiff, maxHourDiff);
      chartData.add(chartPoint);
    }
    
    return chartData;
  }


  // 차트 포인트 생성 (통합)
  Map<String, dynamic> _createChartPoint(BloodPressureRecord record, int recordHour, int recordMinute, double minHourDiff, double maxHourDiff) {
    final normalizedMinute = (recordMinute / 5).floor() * 5;
    final minuteRatio = normalizedMinute / 60.0;
    final range = maxHourDiff - minHourDiff;
    
    // 통합 로직: 시작 시간 기준으로 X축 위치 계산
    double xPosition = (recordHour - minHourDiff + minuteRatio) / range;
    xPosition = xPosition.clamp(0.0, 1.0);
    
    String dateStr = '${recordHour.toString().padLeft(2, '0')}:${recordMinute.toString().padLeft(2, '0')}';
    
    return {
      'date': dateStr,
      'hour': recordHour,
      'systolic': record.systolic,
      'diastolic': record.diastolic,
      'record': record,
      'normalizedMinute': normalizedMinute,
      'xPosition': xPosition,
    };
  }

  // 주/월 데이터 생성 (체중과 동일한 방식) - 하루에 최고 수축기 값만 선택
  List<Map<String, dynamic>> _getWeeklyOrMonthlyData() {
    List<Map<String, dynamic>> chartData = [];
    final days = selectedPeriod == '주' ? 7 : 30;
    
    // 선택된 날짜를 기준으로 과거 데이터 생성 (선택된 날짜가 맨 오른쪽)
    final endDate = selectedDate;
    final startDate = endDate.subtract(Duration(days: days - 1));
    
    // 모든 날짜에 대해 데이터 생성 (데이터가 없어도 빈 슬롯 생성)
    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      
      // 해당 날짜의 모든 기록 가져오기 (allRecords에서)
      final dayRecords = allRecords.where((record) {
        final recordDateStr = DateFormat('yyyy-MM-dd').format(record.measuredAt);
        return recordDateStr == dateKey;
      }).toList();
      
      if (dayRecords.isNotEmpty) {
        // 하루 중 수축기가 가장 높은 기록 선택
        dayRecords.sort((a, b) => b.systolic.compareTo(a.systolic));
        final highestSystolicRecord = dayRecords.first;
        
        chartData.add({
          'date': DateFormat('M.d').format(date),
          'systolic': highestSystolicRecord.systolic,
          'diastolic': highestSystolicRecord.diastolic,
          'record': highestSystolicRecord,
          'xPosition': i / days, // X축 위치 (0~1)
        });
      } else {
        // 데이터가 없는 날짜는 null 값으로 추가 (차트에서 제외되지만 위치는 유지)
        chartData.add({
          'date': DateFormat('M.d').format(date),
          'systolic': null,
          'diastolic': null,
          'record': null,
          'xPosition': i / days, // X축 위치 (0~1)
        });
      }
    }
    
    return chartData;
  }

  // X축 라벨 생성 (통합)
  Widget _buildXAxisLabels(List<Map<String, dynamic>> chartData) {
    if (selectedPeriod != '일') {
      return _buildPeriodXAxisLabels(chartData);
    }
    
    final timeRange = _calculateTimeRange();
    final startHour = timeRange['min']!.round();
    
    List<Widget> hourLabels = [];
    
    // 통합 로직: 시작 시간부터 7개 라벨 표시
    for (int i = 0; i < 7; i++) {
      final hour = (startHour + i).clamp(0, 24);
      final hourLabel = hour == 24 ? '24:00' : '${hour.toString().padLeft(2, '0')}:00';
      hourLabels.add(
        Text(hourLabel, style: TextStyle(fontSize: 12, color: Colors.grey))
      );
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: hourLabels,
    );
  }

  // 주/월 X축 라벨 생성
  Widget _buildPeriodXAxisLabels(List<Map<String, dynamic>> chartData) {
    final days = selectedPeriod == '주' ? 7 : 30;
    final endDate = selectedDate;
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
      
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: visibleLabels.map((label) {
          return Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          );
        }).toList(),
      );
    }
  }
  
  // Y축 범위 계산 (고정 범위)
  List<double> getYAxisLabels() {
    return [220, 180, 140, 100, 60, 20];
  }
  
  // 점선 Y축 라벨
  List<double> getDashedYAxisLabels() {
    return [200, 160, 120, 80, 40];
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    
    if (widget.initialDate != null) {
      selectedDate = DateTime(
        widget.initialDate!.year,
        widget.initialDate!.month,
        widget.initialDate!.day,
      );
    } else {
      selectedDate = DateTime(now.year, now.month, now.day);
    }
    
    // 오늘 날짜일 경우: 현재 시간 - 4시간을 시작점으로 초기 timeOffset 설정
    if (_isToday()) {
      final currentHour = now.hour;
      final startHourTarget = (currentHour - 4).clamp(0, 18);
      timeOffset = startHourTarget / 18.0;
    }
    
    // 월별 그래프 초기 오프셋 설정 (오늘 날짜가 맨 오른쪽에 보이도록) jjy
    if (selectedPeriod == '월') {
      final visibleDays = 7;
      final totalDays = 30;
      final maxOffset = (totalDays - visibleDays) / totalDays;
      timeOffset = maxOffset; // 오늘 날짜가 맨 오른쪽에 표시되도록
    }
    
    _loadData();
  }

  // 주/월 데이터 로드 (메모리에서 필터링)
  void _loadPeriodData() {
    // 이미 allRecords에 모든 데이터가 있으므로 UI만 업데이트
    setState(() {});
  }

  // 데이터 로드 (최적화: 전체 데이터를 한 번만 로드)
  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    try {
      currentUser = await AuthService.getUser();
      
      if (currentUser != null) {
        // 전체 혈압 기록 한 번만 로드
        allRecords = await BloodPressureRepository.getBloodPressureRecords(currentUser!.id);
        
        // 메모리에서 날짜별로 캐싱 (API 호출 없이 필터링)
        _cacheRecordsFromMemory();
        
        // 데이터가 없을 때만 다이얼로그 표시 (한 번만)
        if (allRecords.isEmpty && mounted && !hasShownNoDataDialog) {
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

  // 메모리에서 날짜별로 캐싱 (API 호출 없이 필터링)
  void _cacheRecordsFromMemory() {
    dailyRecordsCache.clear();
    bloodPressureRecordsMap.clear();
    
    for (var record in allRecords) {
      final dateKey = DateFormat('yyyy-MM-dd').format(record.measuredAt);
      
      // 날짜별 리스트에 추가
      if (!dailyRecordsCache.containsKey(dateKey)) {
        dailyRecordsCache[dateKey] = [];
      }
      dailyRecordsCache[dateKey]!.add(record);
      
      // 요약 맵 업데이트 (가장 최근 기록)
      if (!bloodPressureRecordsMap.containsKey(dateKey) || 
          record.measuredAt.isAfter(bloodPressureRecordsMap[dateKey]!.measuredAt)) {
        bloodPressureRecordsMap[dateKey] = record;
      }
    }
  }

  // 날짜 변경 시 데이터 로드 (메모리에서 필터링)
  void _loadDataForSelectedDate() {
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    
    // 이미 캐시에 있으면 UI만 업데이트
    if (dailyRecordsCache.containsKey(dateKey)) {
      setState(() {});
      return;
    }
    
    // 메모리에서 필터링하여 캐시에 추가
    final records = allRecords.where((record) {
      final recordDateKey = DateFormat('yyyy-MM-dd').format(record.measuredAt);
      return recordDateKey == dateKey;
    }).toList();
    
    dailyRecordsCache[dateKey] = records;
    
    if (records.isNotEmpty) {
      records.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
      bloodPressureRecordsMap[dateKey] = records.first;
    }
    
    setState(() {});
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
              padding: const EdgeInsets.symmetric(horizontal: 25),  // 좌우 20px 패딩
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DateTopWidget(
                    selectedDate: selectedDate,
                    onDateChanged: (newDate) {
                      setState(() {
                        selectedDate = newDate;
                        selectedChartPointIndex = null;
                        tooltipPosition = null;
                        
                        // 오늘 날짜로 변경 시 현재 시간 기준으로 timeOffset 설정
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final isSelectingToday = newDate.year == today.year && 
                                                 newDate.month == today.month && 
                                                 newDate.day == today.day;
                        
                        if (isSelectingToday) {
                          final currentHour = now.hour;
                          final startHourTarget = (currentHour - 4).clamp(0, 18);
                          timeOffset = startHourTarget / 18.0;
                        } else {
                          timeOffset = 0.0;
                        }
                      });
                      
                      // 새로운 날짜의 데이터 로드
                      _loadDataForSelectedDate();
                    },
                    recordsMap: bloodPressureRecordsMap,
                    primaryColor: Colors.black,
                    secondaryColor: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  _buildBloodPressureDisplay(),
                  const SizedBox(height: 24),
                  _buildPeriodButtons(),
                  const SizedBox(height: 24),
                  _buildChart(),
                  const SizedBox(height: 32),
                  BtnRecord(
                    text: '+ 기록하기',
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
                    backgroundColor: const Color(0xFF2196F3),
                  ),
                ],
              ),
            ),
          ),
    );
  }


  // 혈압 표시
  Widget _buildBloodPressureDisplay() {
    final systolic = selectedRecord?.systolic ?? 0;
    final diastolic = selectedRecord?.diastolic ?? 0;
    final dateStr = DateFormat('yyyy년 M월 d일').format(selectedDate);
    
    return GestureDetector(
      onTap: () async {
        if (selectedRecord != null) {
          final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
          final todayRecords = dailyRecordsCache[selectedDateStr] ?? [];
          
          todayRecords.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
          
          if (todayRecords.length > 1) {
            _showTimeSelectionBottomSheet(todayRecords);
          } else if (todayRecords.length == 1) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BloodPressureInputScreen(record: todayRecords[0]),
              ),
            );
            
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

  // 기간 선택 버튼
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
            // 차트 포인트 선택 초기화
            selectedChartPointIndex = null;
            tooltipPosition = null;
            //jjy 0.7666666666666667
            // 월별 그래프 선택 시 초기 오프셋 설정 jjy 
            if (period == '월') {
              final visibleDays = 7;
              final totalDays = 30;
              final maxOffset = (totalDays - visibleDays) / totalDays;
              timeOffset = maxOffset; // 오늘 날짜가 맨 오른쪽에 보이도록
              print('jjy timeOffset: $timeOffset');
              // timeOffset = 0.0;
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
            } else {
              // 주별 그래프는 초기 오프셋 없음
              timeOffset = 0.0;
            }
          });
          
          // 주/월 탭 선택 시 데이터 다시 로드
          if (period == '주' || period == '월') {
            _loadPeriodData();
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

  // 차트 (단순화)
  Widget _buildChart() {
    final chartData = getChartData();
    final yLabels = getYAxisLabels();
    
    // 주별/월별 차트인 경우 공통 컴포넌트 사용
    if (selectedPeriod != '일') {
      return PeriodChartWidget(
        chartData: chartData,
        yLabels: yLabels,
        selectedPeriod: selectedPeriod,
        selectedDate: selectedDate,
        timeOffset: timeOffset,
        height: 350,
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
        dataType: 'bloodPressure',
        yAxisCount: yLabels.length,
      );
    }
    
    // 일별 차트: API에서 로드된 실제 데이터가 있는지 확인
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final actualRecords = dailyRecordsCache[selectedDateStr] ?? [];
    
    if (actualRecords.isEmpty) {
      return _buildNoDataMessage();
    }
    
    if (chartData.isEmpty) {
      return _buildEmptyChart(yLabels);
    }
    
    return _buildDataChart(chartData, yLabels);
  }

  // 데이터 없음 메시지 빌드
  Widget _buildNoDataMessage() {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Text(
              '해당 기간에 혈압 기록이 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '혈압을 측정해보세요',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 빈 차트 빌드 (격자선이 있는 빈 차트)
  Widget _buildEmptyChart(List<double> yLabels) {
    return _buildDraggableChart([], yLabels, isEmpty: true);
  }

  // 데이터가 있는 차트 빌드
  Widget _buildDataChart(List<Map<String, dynamic>> chartData, List<double> yLabels) {
    return _buildDraggableChart(chartData, yLabels, isEmpty: false);
  }

  // 드래그 가능한 차트 빌드 (통합)
  Widget _buildDraggableChart(List<Map<String, dynamic>> chartData, List<double> yLabels, {required bool isEmpty}) {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: ChartConstants.yAxisLabelWidth,
                      child: Stack(
                        children: yLabels.asMap().entries.map((entry) {
                          final index = entry.key;
                          final label = entry.value;
                          const double topPadding = 20.0;
                          const double bottomPadding = 20.0;
                          final double y = topPadding + (constraints.maxHeight - topPadding - bottomPadding) * index / (yLabels.length - 1);
                          return Positioned(
                            top: y - 10, // Adjust for text vertical alignment
                            right: 0,
                            child: Text(
                              '${label.round()}',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(width: ChartConstants.yAxisSpacing),
                    Expanded(
                      child: _buildChartArea(chartData, constraints, isEmpty),
                    ),
                  ],
                );
              }
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.only(left: ChartConstants.yAxisTotalWidth),
            child: _buildXAxisLabels(chartData),
          ),
        ],
      ),
    );
  }

  // 차트 영역 빌드
  Widget _buildChartArea(List<Map<String, dynamic>> chartData, BoxConstraints constraints, bool isEmpty) {
    return GestureDetector(
      onPanStart: (selectedPeriod == '일' || selectedPeriod == '월') ? (details) => _dragStartX = details.localPosition.dx : null,
      onPanUpdate: (selectedPeriod == '일' || selectedPeriod == '월') ? (details) {
        if (_dragStartX != null) {
          final deltaX = details.localPosition.dx - _dragStartX!;
          final chartWidth = constraints.maxWidth - ChartConstants.yAxisTotalWidth;
          _handleDragUpdate(deltaX, chartWidth);
          _dragStartX = details.localPosition.dx;
        }
      } : null,
      onPanEnd: (selectedPeriod == '일' || selectedPeriod == '월') ? (details) => _dragStartX = null : null,
      onTapDown: isEmpty ? null : (details) {
        _handleChartTapToggle(
          details.localPosition, 
          chartData, 
          20,  // 최소값 (고정)
          220, // 최대값 (고정)
          constraints.maxWidth - ChartConstants.yAxisTotalWidth,
          constraints.maxHeight,
        );
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              child: isEmpty 
                ? CustomPaint(painter: EmptyChartGridPainter())
                : CustomPaint(
                    painter: BloodPressureChartPainter(
                      chartData, 
                      20,  // 최소값 (고정)
                      220, // 최대값 (고정)
                      highlightedIndex: selectedChartPointIndex,
                      isToday: _isToday(),
                      timeOffset: timeOffset,
                    ),
                  ),
            ),
          ),
          if (!isEmpty && selectedChartPointIndex != null && tooltipPosition != null)
            _buildChartTooltip(
              chartData[selectedChartPointIndex!],
              constraints.maxWidth - ChartConstants.yAxisTotalWidth,
              constraints.maxHeight,
            ),
        ],
      ),
    );
  }

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
      if (chartData[i]['systolic'] == null || chartData[i]['diastolic'] == null) continue;
      
      double x;
      if (chartData[i]['xPosition'] != null) {
        // 주별/월별 차트: xPosition 사용
        final xPosition = chartData[i]['xPosition'] as double;
        final selectedPeriod = this.selectedPeriod;
        
        if (selectedPeriod == '월') {
          // 월별: 현재 보이는 7개 날짜만 표시
          final visibleDays = 7;
          final totalDays = 30;
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
          x = leftPadding + (effectiveWidth * adjustedRatio);
        } else {
          // 주별: xPosition 그대로 사용
          x = leftPadding + (effectiveWidth * xPosition);
        }
      } else if (chartData.length == 1) {
        // 일별 차트: 단일 데이터
        x = leftPadding + effectiveWidth / 2;
      } else {
        // 일별 차트: 여러 데이터
        x = leftPadding + (effectiveWidth * i / (chartData.length - 1));
      }
      
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
    
    if (closestIndex != null && minDistance < 1000) {
      setState(() {
        if (selectedChartPointIndex == closestIndex) {
          selectedChartPointIndex = null;
          tooltipPosition = null;
        } else {
          selectedChartPointIndex = closestIndex;
          tooltipPosition = closestPoint;
        }
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
    
    if (data['systolic'] == null || data['diastolic'] == null) {
      return const SizedBox.shrink();
    }
    
    final systolic = data['systolic'] as int;
    final diastolic = data['diastolic'] as int;
    final record = data['record'] as BloodPressureRecord?;
    
    String dateLabel;
    if (selectedPeriod != '일' && record != null) {
      // 주/월 그래프: 날짜 + 시간 형식 (10/20 14:30)
      final dateStr = DateFormat('M/d').format(record.measuredAt);
      final timeStr = DateFormat('HH:mm').format(record.measuredAt);
      dateLabel = '$dateStr $timeStr';
    } else if (record != null) {
      // 일별 그래프: 시간만 표시
      dateLabel = DateFormat('HH:mm').format(record.measuredAt);
    } else {
      // fallback
      dateLabel = data['date'] is String ? data['date'] as String : '시간';
    }
    
    final calculatedTooltipPosition = ChartConstants.calculateTooltipPosition(
      tooltipPosition!,
      ChartConstants.tooltipWidth,
      ChartConstants.tooltipHeight,
      chartWidth,
      chartHeight,
    );
    
    return Positioned(
      left: calculatedTooltipPosition.dx,
      top: calculatedTooltipPosition.dy,
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
              Navigator.pop(context);
            },
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BloodPressureInputScreen(),
                ),
              );
              
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
  final bool isToday;
  final double timeOffset;
  
  BloodPressureChartPainter(
    this.data, 
    this.minValue, 
    this.maxValue, 
    {this.highlightedIndex, required this.isToday, required this.timeOffset}
  );
  
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    const double borderWidth = 0.5;
    const double pointRadius = 8; // 데이터 포인트 최대 반지름
    final chartWidth = size.width - (borderWidth * 2) - (pointRadius * 2); // 좌우 보더와 포인트 반지름 제외
    
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
      const double topPadding = 20.0;
      const double bottomPadding = 20.0;
      double y = topPadding + (size.height - topPadding - bottomPadding) * i / (yValues.length - 1);
      canvas.drawLine(
        Offset(borderWidth + pointRadius, y),
        Offset(chartWidth + borderWidth + pointRadius, y),
        gridPaint,
      );
    }
    
    // 점선 그리드 그리기
    for (int dashedValue in dashedYValues) {
      double normalizedY = (220 - dashedValue) / (220 - 20);
      const double topPadding = 20.0;
      const double bottomPadding = 20.0;
      double y = topPadding + (size.height - topPadding - bottomPadding) * normalizedY;
      
      // 차트 영역 내에서만 점선 그리기
      for (double x = borderWidth + pointRadius; x < chartWidth + borderWidth + pointRadius; x += 4) {
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
    
    // X축 라벨 범위 계산 (7개 라벨 범위) - 일별 차트에서만 적용
    const maxStartHour = 18;
    final startHour = (timeOffset * maxStartHour).clamp(0, maxStartHour).round();
    final endHour = startHour + 6;
    
    for (int i = 0; i < data.length; i++) {
      if (data[i]['systolic'] == null || data[i]['diastolic'] == null) continue;
      
      // 일별 차트에서만 시간 범위 필터링 적용
      final recordHour = data[i]['hour'] as int?;
      if (recordHour != null) {
        if (recordHour < startHour || recordHour > endHour) {
          // 범위 밖 데이터는 세그먼트 종료
          if (currentSystolic.isNotEmpty) {
            systolicSegments.add(List.from(currentSystolic));
            diastolicSegments.add(List.from(currentDiastolic));
            indexSegments.add(List.from(currentIndices));
            currentSystolic.clear();
            currentDiastolic.clear();
            currentIndices.clear();
          }
          continue;
        }
      }
      
      // 월별 차트에서만 현재 보이는 범위 필터링 (주별은 모든 데이터 표시)
      if (data[i]['xPosition'] != null && data.length > 7) { // 월별 차트만 (30일)
        final xPosition = data[i]['xPosition'] as double;
        // 현재 보이는 범위 계산 (7일씩 보여주므로)
        final visibleDays = 7;
        final totalDays = 30;
        final maxOffset = (totalDays - visibleDays) / totalDays;
        final currentOffset = timeOffset.clamp(0.0, maxOffset);
        final startRatio = currentOffset;
        final endRatio = (currentOffset + (visibleDays / totalDays)).clamp(0.0, 1.0);
        
        if (xPosition < startRatio || xPosition > endRatio) {
          // 범위 밖 데이터는 세그먼트 종료
          if (currentSystolic.isNotEmpty) {
            systolicSegments.add(List.from(currentSystolic));
            diastolicSegments.add(List.from(currentDiastolic));
            indexSegments.add(List.from(currentIndices));
            currentSystolic.clear();
            currentDiastolic.clear();
            currentIndices.clear();
          }
          continue;
        }
      }
      
      double x;
      if (data[i]['xPosition'] != null) {
        // 주별/월별 차트: xPosition 사용
        final xPosition = data[i]['xPosition'] as double;
        
        // 월별 차트의 경우 현재 보이는 범위에 맞게 위치 조정
        if (data.length > 7) { // 월별 차트 (30일)
          final visibleDays = 7;
          final totalDays = 30;
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
          x = borderWidth + pointRadius + (chartWidth * adjustedRatio);
        } else {
          // 주별 차트: 그대로 사용 (모든 데이터 표시)
          x = borderWidth + pointRadius + (chartWidth * xPosition);
        }
      } else {
        // 일별 차트: 시간 기반 위치 계산
        x = data.length == 1 
          ? borderWidth + pointRadius + chartWidth / 2 
          : borderWidth + pointRadius + (chartWidth * i / (data.length - 1));
      }
      
      int systolic = data[i]['systolic'];
      int diastolic = data[i]['diastolic'];
      
      const double topPadding = 20.0;
      const double bottomPadding = 20.0;
      double normalizedSystolic = (220 - systolic) / (220 - 20);
      double ySystolic = topPadding + (size.height - topPadding - bottomPadding) * normalizedSystolic;
      
      double normalizedDiastolic = (220 - diastolic) / (220 - 20);
      double yDiastolic = topPadding + (size.height - topPadding - bottomPadding) * normalizedDiastolic;
      
      currentSystolic.add(Offset(x, ySystolic));
      currentDiastolic.add(Offset(x, yDiastolic));
      currentIndices.add(i);
    }
    
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
      if (segment.length == 1) continue;
      
      final path = Path();
      path.moveTo(segment[0].dx, segment[0].dy);
      
      if (segment.length == 2) {
        path.lineTo(segment[1].dx, segment[1].dy);
      } else {
        for (int i = 0; i < segment.length - 1; i++) {
          final p0 = i > 0 ? segment[i - 1] : segment[i];
          final p1 = segment[i];
          final p2 = segment[i + 1];
          final p3 = i < segment.length - 2 ? segment[i + 2] : segment[i + 1];
          
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
      if (segment.length == 1) continue;
      
      final path = Path();
      path.moveTo(segment[0].dx, segment[0].dy);
      
      if (segment.length == 2) {
        path.lineTo(segment[1].dx, segment[1].dy);
      } else {
        for (int i = 0; i < segment.length - 1; i++) {
          final p0 = i > 0 ? segment[i - 1] : segment[i];
          final p1 = segment[i];
          final p2 = segment[i + 1];
          final p3 = i < segment.length - 2 ? segment[i + 2] : segment[i + 1];
          
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

// 빈 차트용 그리드 페인터
class EmptyChartGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;
    
    final dashedGridPaint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 0.5;
    
    final yValues = [220, 180, 140, 100, 60, 20];
    final dashedYValues = [200, 160, 120, 80, 40];
    
    // 실선 그리드 그리기
    for (int i = 0; i < yValues.length; i++) {
      const double topPadding = 20.0;
      const double bottomPadding = 20.0;
      double y = topPadding + (size.height - topPadding - bottomPadding) * i / (yValues.length - 1);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
    
    // 점선 그리드 그리기
    for (int dashedValue in dashedYValues) {
      double normalizedY = (220 - dashedValue) / (220 - 20);
      const double topPadding = 20.0;
      const double bottomPadding = 20.0;
      double y = topPadding + (size.height - topPadding - bottomPadding) * normalizedY;
      
      // 차트 영역 내에서만 점선 그리기
      for (double x = 0; x < size.width; x += 4) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x + 2, y),
          dashedGridPaint,
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}