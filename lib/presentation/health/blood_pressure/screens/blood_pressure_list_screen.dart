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
  final DateTime? initialDate;
  
  const BloodPressureListScreen({super.key, this.initialDate});

  @override
  State<BloodPressureListScreen> createState() => _BloodPressureListScreenState();
}

class _BloodPressureListScreenState extends State<BloodPressureListScreen> {
  String selectedPeriod = '일';
  UserModel? currentUser;
  Map<String, BloodPressureRecord> bloodPressureRecordsMap = {}; // 날짜별 요약 기록
  Map<String, List<BloodPressureRecord>> dailyRecordsCache = {}; // 날짜별 상세 기록 캐시
  Set<String> loadingDates = {}; // 로딩 중인 날짜들
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

  // 특정 날짜가 로딩 중인지 확인
  bool _isLoadingDate(String dateKey) {
    return loadingDates.contains(dateKey);
  }

  // 시간 범위 계산 (공통 로직)
  Map<String, double> _calculateTimeRange() {
    if (_isToday()) {
      final now = DateTime.now();
      final currentHour = now.hour;
      final minHourDiff = (-4.0 + timeOffset).clamp(-currentHour.toDouble(), 0.0);
      final maxHourDiff = (2.0 + timeOffset).clamp(-4.0, 0.0);
      return {'min': minHourDiff, 'max': maxHourDiff};
    } else {
      final minHourDiff = (timeOffset * 12.0).clamp(0.0, 12.0);
      final maxHourDiff = (minHourDiff + 12.0).clamp(12.0, 23.0);
      return {'min': minHourDiff, 'max': maxHourDiff};
    }
  }

  // 드래그 범위 제한 (공통 로직)
  double _clampDragOffset(double newOffset) {
    if (_isToday()) {
      final now = DateTime.now();
      final currentHour = now.hour;
      final maxPastOffset = -currentHour.toDouble();
      return newOffset.clamp(maxPastOffset, 0.0);
    } else {
      return newOffset.clamp(0.0, 0.916); // 0.916 = 11/12, 최대 23시까지만
    }
  }

  // 드래그 민감도 계산 (공통 로직)
  double _getDragSensitivity() {
    return _isToday() ? 6.0 : 0.5;
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
    
    // 로딩 중이면 빈 배열 반환
    if (loadingDates.contains(selectedDateStr)) {
      return [];
    }
    
    // 캐시에서 데이터 가져오기 (없으면 빈 배열)
    final dayRecords = dailyRecordsCache[selectedDateStr] ?? [];
    
    dayRecords.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    
    final timeRange = _calculateTimeRange();
    final minHourDiff = timeRange['min']!;
    final maxHourDiff = timeRange['max']!;
    
    print('⏰ [DEBUG] 시간 범위: ${minHourDiff} ~ ${maxHourDiff}');
    print('📅 [DEBUG] 오늘 여부: ${_isToday()}');
    
    List<Map<String, dynamic>> chartData = [];
    
    for (var record in dayRecords) {
      final recordHour = record.measuredAt.hour;
      final recordMinute = record.measuredAt.minute;
      
      if (_isToday()) {
        // 오늘: 드래그 범위에 따라 필터링
        if (_isRecordInTimeRange(recordHour, minHourDiff, maxHourDiff)) {
          final chartPoint = _createChartPoint(record, recordHour, recordMinute, minHourDiff, maxHourDiff);
          chartData.add(chartPoint);
        }
      } else {
        // 과거: 드래그 범위에 따라 필터링
        if (_isRecordInTimeRange(recordHour, minHourDiff, maxHourDiff)) {
          final chartPoint = _createChartPoint(record, recordHour, recordMinute, minHourDiff, maxHourDiff);
          chartData.add(chartPoint);
          print('✅ [DEBUG] 과거 기록 추가: ${recordHour}:${recordMinute.toString().padLeft(2, '0')} (범위: ${minHourDiff}~${maxHourDiff})');
        } else {
          print('❌ [DEBUG] 과거 기록 제외: ${recordHour}:${recordMinute.toString().padLeft(2, '0')} (범위: ${minHourDiff}~${maxHourDiff})');
        }
      }
    }
    
    return chartData;
  }

  // 기록이 시간 범위 내에 있는지 확인
  bool _isRecordInTimeRange(int recordHour, double minHourDiff, double maxHourDiff) {
    if (_isToday()) {
      final now = DateTime.now();
      final currentHour = now.hour;
      final hourDiff = recordHour - currentHour;
      return hourDiff >= minHourDiff && hourDiff <= maxHourDiff && hourDiff <= 0;
    } else {
      // 과거: 드래그 범위 내의 시간인지 확인
      return recordHour >= minHourDiff && recordHour <= maxHourDiff;
    }
  }

  // 차트 포인트 생성
  Map<String, dynamic> _createChartPoint(BloodPressureRecord record, int recordHour, int recordMinute, double minHourDiff, double maxHourDiff) {
    final normalizedMinute = (recordMinute / 5).floor() * 5;
    final minuteRatio = normalizedMinute / 60.0;
    final range = maxHourDiff - minHourDiff;
    
    double xPosition;
    String dateStr;
    
    if (_isToday()) {
      final now = DateTime.now();
      final currentHour = now.hour;
      final hourDiff = recordHour - currentHour;
      xPosition = (hourDiff - minHourDiff) / range;
      dateStr = '${recordHour.toString().padLeft(2, '0')}시';
    } else {
      // 과거: 드래그 범위 내에서 상대적 위치 계산 (분 포함)
      xPosition = (recordHour - minHourDiff + minuteRatio) / range;
      dateStr = '${recordHour.toString().padLeft(2, '0')}:${recordMinute.toString().padLeft(2, '0')}';
    }
    
    // 오늘만 추가 분 조정
    if (_isToday()) {
      xPosition += minuteRatio / range;
    }
    
    xPosition = xPosition.clamp(0.0, 1.0);
    
    return {
      'date': dateStr,
      'hour': recordHour,
      'systolic': record.systolic,
      'diastolic': record.diastolic,
      'record': record,
      'actualHour': recordHour,
      'actualMinute': recordMinute,
      'normalizedMinute': normalizedMinute,
      'xPosition': xPosition,
    };
  }

  // 주/월 데이터 생성 (최적화)
  List<Map<String, dynamic>> _getWeeklyOrMonthlyData() {
    List<Map<String, dynamic>> chartData = [];
    final days = selectedPeriod == '주' ? 7 : 30;
    final endDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final startDate = endDate.subtract(Duration(days: days - 1));
    
    // 필요한 날짜들 로드
    List<DateTime> datesToLoad = [];
    for (int i = 0; i < days; i++) {
      datesToLoad.add(startDate.add(Duration(days: i)));
    }
    _loadRecordsForDates(datesToLoad);
    
    for (int i = 0; i < days; i++) {
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
    
    return chartData;
  }

  // X축 라벨 생성 (통합)
  Widget _buildXAxisLabels(List<Map<String, dynamic>> chartData) {
    if (selectedPeriod != '일') {
      return _buildPeriodXAxisLabels(chartData);
    }
    
    final timeRange = _calculateTimeRange();
    final minHourDiff = timeRange['min']!.round();
    final maxHourDiff = timeRange['max']!.round();
    
    List<Widget> hourLabels = [];
    
    if (_isToday()) {
      // 오늘: 현재 시간 기준으로 라벨 생성
      final now = DateTime.now();
      final currentHour = now.hour;
      
      for (int i = minHourDiff; i <= maxHourDiff; i++) {
        final targetHour = currentHour + i;
        if (targetHour >= 0) {
          final hourLabel = '${targetHour.toString().padLeft(2, '0')}시';
          hourLabels.add(
            Text(hourLabel, style: TextStyle(fontSize: 10, color: Colors.grey[600]))
          );
        }
      }
    } else {
      // 과거: 드래그 범위에 맞는 라벨 표시
      final startHour = minHourDiff.clamp(0, 23);
      final endHour = maxHourDiff.clamp(0, 23);
      
      // 드래그 범위에 맞는 시간 라벨 표시
      for (int hour = startHour; hour <= endHour; hour++) {
        final hourLabel = '${hour.toString().padLeft(2, '0')}시';
        hourLabels.add(
          Text(hourLabel, style: TextStyle(fontSize: 10, color: Colors.grey[600]))
        );
      }
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: hourLabels,
    );
  }

  // 주/월 X축 라벨 생성
  Widget _buildPeriodXAxisLabels(List<Map<String, dynamic>> chartData) {
    if (chartData.isEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('시간', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          Text('시간', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          Text('시간', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      );
    }
    
    if (chartData.length <= 7) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: chartData.where((data) => data['date'] != null).map((data) {
          final dateStr = data['date'];
          return Text(
            dateStr is String ? dateStr : '시간',
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          );
        }).toList(),
      );
    }
    
    // 안전하게 인덱스 접근
    final firstDate = chartData.isNotEmpty ? chartData.first['date'] : '시간';
    final middleDate = chartData.length > 1 ? chartData[chartData.length ~/ 2]['date'] : '시간';
    final lastDate = chartData.isNotEmpty ? chartData.last['date'] : '시간';
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          firstDate is String ? firstDate : '시간',
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        Text(
          middleDate is String ? middleDate : '시간',
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        Text(
          lastDate is String ? lastDate : '시간',
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
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

  // 데이터 로드 (최적화: 필요한 날짜만 로드)
  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    try {
      currentUser = await AuthService.getUser();
      
      if (currentUser != null) {
        // 현재 선택된 날짜와 주변 날짜들만 로드
        await _loadRecordsForDates(displayDates);
        
        // 데이터가 없으면 다이얼로그 표시 (한 번만)
        if (bloodPressureRecordsMap.isEmpty && mounted && !hasShownNoDataDialog) {
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

  // 특정 날짜들의 기록 로드 (캐시 없이 매번 DB에서 가져오기)
  Future<void> _loadRecordsForDates(List<DateTime> dates) async {
    if (currentUser == null) return;

    for (var date in dates) {
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      
      // 로딩 중이면 스킵 (동시 로딩 방지)
      if (loadingDates.contains(dateKey)) {
        continue;
      }
      
      // 로딩 상태 추가
      loadingDates.add(dateKey);
      
      try {
        // 해당 날짜의 기록만 가져오기
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
        
        final records = await BloodPressureRepository.getBloodPressureRecordsByDateRange(
          currentUser!.id,
          startOfDay,
          endOfDay,
        );
        
        print('📥 [API] $dateKey: ${records.length}개 기록 로드');
        
        // 캐시에 저장
        dailyRecordsCache[dateKey] = records;
        
        // 요약 맵 업데이트 (가장 최근 기록)
        if (records.isNotEmpty) {
          records.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
          bloodPressureRecordsMap[dateKey] = records.first;
        }
      } catch (e) {
        print('❌ API 오류 ($dateKey): $e');
        dailyRecordsCache[dateKey] = [];
      } finally {
        // 로딩 상태 제거
        loadingDates.remove(dateKey);
      }
    }
  }

  // 날짜 변경 시 추가 데이터 로드 (캐시 없이 매번 DB에서 가져오기)
  Future<void> _loadDataForSelectedDate() async {
    if (currentUser == null) return;
    
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    
    // 로딩 중이면 스킵 (동시 로딩 방지)
    if (loadingDates.contains(dateKey)) {
      return;
    }
    
    // 로딩 상태 추가
    loadingDates.add(dateKey);
    
    try {
      final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final endOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);
      
      final records = await BloodPressureRepository.getBloodPressureRecordsByDateRange(
        currentUser!.id,
        startOfDay,
        endOfDay,
      );
      
      print('📥 [API] $dateKey: ${records.length}개 기록 로드');
      
      // 매번 새로 로드 (캐시에 저장)
      dailyRecordsCache[dateKey] = records;
      
      if (records.isNotEmpty) {
        records.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
        bloodPressureRecordsMap[dateKey] = records.first;
      }
      
      setState(() {}); // UI 업데이트
    } catch (e) {
      print('❌ API 오류 ($dateKey): $e');
      dailyRecordsCache[dateKey] = [];
    } finally {
      // 로딩 상태 제거
      loadingDates.remove(dateKey);
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
                  _buildDateSelector(),
                  const SizedBox(height: 16),
                  _buildBloodPressureDisplay(),
                  const SizedBox(height: 24),
                  _buildPeriodButtons(),
                  const SizedBox(height: 24),
                  _buildChart(),
                  const SizedBox(height: 32),
                  _buildAddButton(),
                ],
              ),
            ),
          ),
    );
  }

  // 날짜 선택 슬라이더
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
          _buildDateItem(displayDates[0], false),
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
           timeOffset = 0.0;
           selectedChartPointIndex = null;
           tooltipPosition = null;
         });
         
         // 새로운 날짜의 데이터 로드
         _loadDataForSelectedDate();
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

  // 차트 (단순화)
  Widget _buildChart() {
    final chartData = getChartData();
    final yLabels = getYAxisLabels();
    
    // API에서 로드된 실제 데이터가 있는지 확인
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
            Icon(
              Icons.favorite_border,
              size: 48,
              color: Colors.grey[400],
            ),
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
      onPanStart: (details) => _dragStartX = details.localPosition.dx,
      onPanUpdate: (details) {
        if (_dragStartX != null) {
          final deltaX = details.localPosition.dx - _dragStartX!;
          final chartWidth = constraints.maxWidth - ChartConstants.yAxisTotalWidth;
          _handleDragUpdate(deltaX, chartWidth);
          _dragStartX = details.localPosition.dx;
        }
      },
      onPanEnd: (details) => _dragStartX = null,
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
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!, width: 0.5),
              ),
              child: isEmpty 
                ? CustomPaint(painter: EmptyChartGridPainter())
                : CustomPaint(
                    painter: BloodPressureChartPainter(
                      chartData, 
                      20,  // 최소값 (고정)
                      220, // 최대값 (고정)
                      highlightedIndex: selectedChartPointIndex,
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
        final xPosition = chartData[i]['xPosition'] as double;
        x = leftPadding + (effectiveWidth * xPosition);
      } else if (chartData.length == 1) {
        x = leftPadding + effectiveWidth / 2;
      } else {
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
    
    final dateLabel = record != null 
        ? DateFormat('HH:mm').format(record.measuredAt)
        : (data['date'] is String ? data['date'] as String : '시간');
    
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

  // 기록하기 버튼
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
      double normalizedY = (220 - dashedValue) / (220 - 20);
      double y = size.height * normalizedY;
      
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
      if (data[i]['systolic'] == null || data[i]['diastolic'] == null) continue;
      
      double x;
      if (data[i]['xPosition'] != null) {
        final xPosition = data[i]['xPosition'] as double;
        x = leftPadding + (chartWidth * xPosition);
      } else {
        x = data.length == 1 
          ? leftPadding + chartWidth / 2 
          : leftPadding + (chartWidth * i / (data.length - 1));
      }
      
      int systolic = data[i]['systolic'];
      int diastolic = data[i]['diastolic'];
      
      double normalizedSystolic = (220 - systolic) / (220 - 20);
      double ySystolic = size.height * normalizedSystolic;
      
      double normalizedDiastolic = (220 - diastolic) / (220 - 20);
      double yDiastolic = size.height * normalizedDiastolic;
      
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
      double y = size.height * i / (yValues.length - 1);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
    
    // 점선 그리드 그리기
    for (int dashedValue in dashedYValues) {
      double normalizedY = (220 - dashedValue) / (220 - 20);
      double y = size.height * normalizedY;
      
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