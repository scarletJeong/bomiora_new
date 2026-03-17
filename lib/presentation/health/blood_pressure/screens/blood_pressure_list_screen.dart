import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/btn_record.dart';
import '../../../common/chart_layout.dart';
import '../../../common/widgets/period_chart_widget.dart';
import '../../health_common/widgets/health_edit_bottom_sheet.dart';
import '../../health_common/widgets/health_period_selector.dart';
import '../../health_common/widgets/health_chart_expand_page.dart';
import '../../health_common/widgets/health_date_selector.dart';
import '../../../../data/models/health/blood_pressure/blood_pressure_record_model.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/repositories/health/blood_pressure/blood_pressure_repository.dart';
import '../../../../data/services/auth_service.dart';
import 'blood_pressure_input_screen.dart';
import '../widgets/blood_pressure_chart_section.dart';

class BloodPressureListScreen extends StatefulWidget {
  final DateTime? initialDate;

  const BloodPressureListScreen({super.key, this.initialDate});

  @override
  State<BloodPressureListScreen> createState() =>
      _BloodPressureListScreenState();
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
  VoidCallback? _refreshExpandedChart;

  void _setChartState(VoidCallback updates) {
    if (!mounted) return;
    setState(updates);
    _refreshExpandedChart?.call();
  }

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
    final startHour =
        (timeOffset * maxStartHour).clamp(0.0, maxStartHour.toDouble());
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

    _setChartState(() {
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

    // 시간 내림차순 정렬 (최신 시간이 먼저)
    dayRecords.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));

    final timeRange = _calculateTimeRange();
    final minHourDiff = timeRange['min']!;
    final maxHourDiff = timeRange['max']!;

    List<Map<String, dynamic>> chartData = [];

    for (var record in dayRecords) {
      final recordHour = record.measuredAt.hour;
      final recordMinute = record.measuredAt.minute;

      // 통합 로직: 모든 데이터 표시 (필터링은 Painter에서)
      final chartPoint = _createChartPoint(
          record, recordHour, recordMinute, minHourDiff, maxHourDiff);
      chartData.add(chartPoint);
    }

    return chartData;
  }

  // 차트 포인트 생성 (통합)
  Map<String, dynamic> _createChartPoint(
      BloodPressureRecord record,
      int recordHour,
      int recordMinute,
      double minHourDiff,
      double maxHourDiff) {
    final normalizedMinute = (recordMinute / 5).floor() * 5;
    final minuteRatio = normalizedMinute / 60.0;
    final range = maxHourDiff - minHourDiff;

    // 통합 로직: 시작 시간 기준으로 X축 위치 계산
    double xPosition = (recordHour - minHourDiff + minuteRatio) / range;
    xPosition = xPosition.clamp(0.0, 1.0);

    String dateStr =
        '${recordHour.toString().padLeft(2, '0')}:${recordMinute.toString().padLeft(2, '0')}';

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
        final recordDateStr =
            DateFormat('yyyy-MM-dd').format(record.measuredAt);
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
      final hourLabel = hour.toString().padLeft(2, '0');
      hourLabels.add(
          Text(hourLabel, style: TextStyle(fontSize: 12, color: Colors.grey)));
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
      final endIndex =
          (startIndex + visibleDays).clamp(0, allDateLabels.length);

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
    return [250, 200, 150, 100, 50];
  }

  // 점선 Y축 라벨
  List<double> getDashedYAxisLabels() {
    return [225, 175, 125, 75];
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
        allRecords = await BloodPressureRepository.getBloodPressureRecords(
            currentUser!.id);

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
          record.measuredAt
              .isAfter(bloodPressureRecordsMap[dateKey]!.measuredAt)) {
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
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );

    return Theme(
      data: gmarketTheme,
      child: MobileAppLayoutWrapper(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.chevron_left),
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
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 27),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HealthDateSelector(
                        selectedDate: selectedDate,
                        onDateChanged: (newDate) {
                          setState(() {
                            selectedDate = newDate;
                            selectedChartPointIndex = null;
                            tooltipPosition = null;

                            // 오늘 날짜로 변경 시 현재 시간 기준으로 timeOffset 설정
                            final now = DateTime.now();
                            final today =
                                DateTime(now.year, now.month, now.day);
                            final isSelectingToday =
                                newDate.year == today.year &&
                                    newDate.month == today.month &&
                                    newDate.day == today.day;

                            if (isSelectingToday) {
                              final currentHour = now.hour;
                              final startHourTarget =
                                  (currentHour - 4).clamp(0, 18);
                              timeOffset = startHourTarget / 18.0;
                            } else {
                              timeOffset = 0.0;
                            }
                          });

                          // 새로운 날짜의 데이터 로드
                          _loadDataForSelectedDate();
                        },
                        monthTextColor: const Color(0xFF898686),
                        selectedTextColor: const Color(0xFFFF5A8D),
                        unselectedTextColor: const Color(0xFFB7B7B7),
                        dividerColor: const Color(0xFFD2D2D2),
                        iconColor: const Color(0xFF898686),
                      ),
                      const SizedBox(height: 16),
                      _buildBloodPressureDisplay(),
                      const SizedBox(height: 25),
                      _buildPeriodButtons(),
                      const SizedBox(height: 8),
                      _buildChart(),
                      const SizedBox(height: 14),
                      const Row(
                        children: [
                          _GraphSeriesLegend(
                              color: Color(0xFF86B0FF), label: '수축기'),
                          SizedBox(width: 12),
                          _GraphSeriesLegend(
                              color: Color(0xFFFFC686), label: '이완기'),
                        ],
                      ),
                      const SizedBox(height: 60),
                      BtnRecord(
                        text: '+기록하기',
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const BloodPressureInputScreen(),
                            ),
                          );

                          if (result == true) {
                            _loadData();
                          }
                        },
                        backgroundColor: const Color(0xFFFF5A8D),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // 혈압 상태 표시
  Widget _buildBloodPressureDisplay() {
    final systolic = selectedRecord?.systolic ?? 0;
    final diastolic = selectedRecord?.diastolic ?? 0;
    final previousDateKey = DateFormat('yyyy-MM-dd')
        .format(selectedDate.subtract(const Duration(days: 1)));
    final previousRecord = bloodPressureRecordsMap[previousDateKey];
    final int? systolicDiff = (selectedRecord != null && previousRecord != null)
        ? systolic - previousRecord.systolic
        : null;
    final int? diastolicDiff =
        (selectedRecord != null && previousRecord != null)
            ? diastolic - previousRecord.diastolic
            : null;

    return GestureDetector(
      onTap: _openSelectedRecordEditor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [          
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildPressureSummaryCardNew(
                  label: '수축기',
                  value: systolic > 0 ? '$systolic' : '-',
                  headerColor: _pressureHeaderColor(systolic > 0 ? systolic : null, '수축기'),
                  diffText: _diffText(systolicDiff),
                  diffUp: _isUp(systolicDiff),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPressureSummaryCardNew(
                  label: '이완기',
                  value: diastolic > 0 ? '$diastolic' : '-',
                  headerColor: _pressureHeaderColor(diastolic > 0 ? diastolic : null, '이완기'),
                  diffText: _diffText(diastolicDiff),
                  diffUp: _isUp(diastolicDiff),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _PressureLegend(color: Color(0xFF71D375), label: '정상'),
                    _PressureLegend(color: Color(0xFFFFE78B), label: '주의혈압'),
                    _PressureLegend(color: Color(0xFFFEAF8E), label: '전단계'),
                    _PressureLegend(color: Color(0xFFFF6161), label: '고혈압'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _openSelectedRecordEditor,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5A8D),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '수정하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openSelectedRecordEditor() async {
    if (selectedRecord == null) return;

    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final todayRecords = dailyRecordsCache[selectedDateStr] ?? [];
    todayRecords.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));

    // 1개여도 바텀시트로 선택 후 수정
    _showTimeSelectionBottomSheet(todayRecords);
  }

  String _diffText(int? diff) {
    if (diff == null) return '전날 대비 -';
    return '전날 대비 ${diff.abs()} mmHg';
  }

  bool _isUp(int? diff) => diff != null && diff > 0;

  // 혈압상태색상 정하는 곳 (정상: 0xFF71D375, 주의혈압: 0xFFFFE78B, 전단계: 0xFFFEAF8E, 고혈압: 0xFFFF6161)
  // 사용처: 수축기/이완기 카드 상단 헤더(_buildPressureSummaryCardNew의 headerColor), 아래 범례(_PressureLegend)
  Color _pressureHeaderColor(int? value, String type) {
    if (value == null || value <= 0) return const Color(0xFF71D375);
    if (type == '수축기') {
      if (value < 120) return const Color(0xFF71D375); // 정상
      if (value <= 129) return const Color(0xFFFFE78B); // 주의혈압
      if (value <= 139) return const Color(0xFFFEAF8E); // 전단계
      return const Color(0xFFFF6161); // 고혈압
    }
    // 이완기
    if (value < 80) return const Color(0xFF71D375); // 정상
    if (value <= 84) return const Color(0xFFFFE78B); // 주의혈압
    if (value <= 89) return const Color(0xFFFEAF8E); // 전단계
    return const Color(0xFFFF6161); // 고혈압
  }

  Widget _buildPressureSummaryCardNew({
    required String label,
    required String value,
    required Color headerColor,
    required String diffText,
    required bool diffUp,
  }) {
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 0.50, color: Color(0x7FD2D2D2)),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: ShapeDecoration(
              color: headerColor,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16.67,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20.83,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'mmHg',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 12,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    diffText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 8,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    diffUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    size: 10,
                    color: const Color(0xFF1A1A1A),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPressureSummaryCard({
    required String label,
    required String value,
    required Color cardColor,
    required String diffText,
    required bool diffUp,
    double labelFontSize = 16,
    double diffFontSize = 10,
    double diffIconSize = 12.5,
  }) {
    // 혈압 요약 카드 컨테이너
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 4,
            offset: Offset(0, 0),
          ),
        ],
      ),
      // 카드 내부 세로 레이아웃
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 수축기/이완기 라벨 텍스트
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF1A1A1A),
              fontSize: 18,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w700,
            ),
          ),
          // 라벨-값 간 간격
          const SizedBox(height: 4),
          // 혈압 값 + 단위 행
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 혈압 숫자 값
              Text(
                value,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20.83,
                  fontWeight: FontWeight.w700,
                ),
              ),
              // 값-단위 간 간격
              const SizedBox(width: 2),
              // 단위 텍스트
              const Text(
                'mmHg',
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
          // 값-전일대비 간 간격
          const SizedBox(height: 2),
          // 전일 대비 텍스트 + 방향 아이콘 행
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 전일 대비 값 텍스트
              Text(
                diffText,
                style: TextStyle(
                  color: const Color(0xFF1A1A1A),
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
              ),
              // 텍스트-아이콘 간 간격
              const SizedBox(width: 4),
              // 증감 방향 아이콘
              Icon(
                diffUp ? Icons.arrow_upward : Icons.arrow_downward,
                size: diffIconSize,
                color:
                    diffUp ? const Color(0xFFFF0000) : const Color(0xFF002BFF),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 기간 선택 버튼
  Widget _buildPeriodButtons() {
    return HealthPeriodSelector(
      selectedPeriod: selectedPeriod,
      onChanged: (period) {
        _setChartState(() {
          selectedPeriod = period;
          selectedChartPointIndex = null;
          tooltipPosition = null;
          if (period == '월') {
            final visibleDays = 7;
            final totalDays = 30;
            final maxOffset = (totalDays - visibleDays) / totalDays;
            timeOffset = maxOffset;
          } else if (period == '주') {
            timeOffset = 0.0;
          } else if (period == '일') {
            if (_isToday()) {
              final now = DateTime.now();
              final currentHour = now.hour;
              final startHourTarget = (currentHour - 4).clamp(0, 18);
              timeOffset = startHourTarget / 18.0;
            } else {
              timeOffset = 0.0;
            }
          } else {
            timeOffset = 0.0;
          }
        });

        if (period == '주' || period == '월') {
          _loadPeriodData();
        }
      },
    );
  }

  // 차트 (단순화)
  Widget _buildChart({bool showExpandButton = true, double chartHeight = 350}) {
    final chartData = getChartData();
    final yLabels = getYAxisLabels();

    Widget chartBody;

    // 주별/월별 차트인 경우 공통 컴포넌트 사용
    if (selectedPeriod != '일') {
      chartBody = PeriodChartWidget(
        chartData: chartData,
        yLabels: yLabels,
        selectedPeriod: selectedPeriod,
        selectedDate: selectedDate,
        timeOffset: timeOffset,
        height: chartHeight,
        onTimeOffsetChanged: (newOffset) {
          _setChartState(() {
            timeOffset = newOffset;
          });
        },
        onTooltipChanged: (index, position) {
          _setChartState(() {
            selectedChartPointIndex = index;
            tooltipPosition = position;
          });
        },
        selectedChartPointIndex: selectedChartPointIndex,
        tooltipPosition: tooltipPosition,
        dataType: 'bloodPressure',
        yAxisCount: yLabels.length,
      );
    } else {
      // 일별 차트: API에서 로드된 실제 데이터가 있는지 확인
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      final actualRecords = dailyRecordsCache[selectedDateStr] ?? [];

      if (actualRecords.isEmpty) {
        chartBody = _buildNoDataMessage(chartHeight: chartHeight);
      } else if (chartData.isEmpty) {
        chartBody = _buildEmptyChart(yLabels, chartHeight: chartHeight);
      } else {
        chartBody =
            _buildDataChart(chartData, yLabels, chartHeight: chartHeight);
      }
    }

    if (!showExpandButton) return chartBody;

    return Stack(
      children: [
        chartBody,
        Positioned(
          right: 8,
          top: 8,
          child: GestureDetector(
            onTap: _openExpandedChartPage,
            child: Container(
              width: 16,
              height: 16,
              decoration: ShapeDecoration(
                color: const Color(0x7FD2D2D2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              child: const Icon(
                Icons.open_in_full,
                size: 12,
                color: Color(0xFF4B5563),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 데이터 없음 메시지 빌드
  Widget _buildNoDataMessage({double chartHeight = 350}) {
    return Container(
      height: chartHeight,
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
  Widget _buildEmptyChart(List<double> yLabels, {double chartHeight = 350}) {
    return _buildDraggableChart([], yLabels,
        isEmpty: true, chartHeight: chartHeight);
  }

  // 데이터가 있는 차트 빌드
  Widget _buildDataChart(
      List<Map<String, dynamic>> chartData, List<double> yLabels,
      {double chartHeight = 350}) {
    return _buildDraggableChart(
      chartData,
      yLabels,
      isEmpty: false,
      chartHeight: chartHeight,
    );
  }

  // 드래그 가능한 차트 빌드 (통합)
  Widget _buildDraggableChart(
      List<Map<String, dynamic>> chartData, List<double> yLabels,
      {required bool isEmpty, double chartHeight = 350}) {
    return Container(
      height: chartHeight,
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
            child: LayoutBuilder(builder: (context, constraints) {
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
                        final double y = topPadding +
                            (constraints.maxHeight -
                                    topPadding -
                                    bottomPadding) *
                                index /
                                (yLabels.length - 1);
                        return Positioned(
                          top: y - 10,
                          right: 0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (index == 0)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    '(mmHg)',
                                    style: TextStyle(
                                      fontSize: 6,
                                      color: Color(0xFF898383),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              Text(
                                '${label.round()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1A1A1A),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
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
            }),
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
  Widget _buildChartArea(List<Map<String, dynamic>> chartData,
      BoxConstraints constraints, bool isEmpty) {
    return GestureDetector(
      onPanStart: (selectedPeriod == '일' || selectedPeriod == '월')
          ? (details) => _dragStartX = details.localPosition.dx
          : null,
      onPanUpdate: (selectedPeriod == '일' || selectedPeriod == '월')
          ? (details) {
              if (_dragStartX != null) {
                final deltaX = details.localPosition.dx - _dragStartX!;
                final chartWidth =
                    constraints.maxWidth - ChartConstants.yAxisTotalWidth;
                _handleDragUpdate(deltaX, chartWidth);
                _dragStartX = details.localPosition.dx;
              }
            }
          : null,
      onPanEnd: (selectedPeriod == '일' || selectedPeriod == '월')
          ? (details) => _dragStartX = null
          : null,
      onTapDown: isEmpty
          ? null
          : (details) {
              _handleChartTapToggle(
                details.localPosition,
                chartData,
                50, // 최소값 (고정)
                250, // 최대값 (고정)
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
                        50, // 최소값 (고정)
                        250, // 최대값 (고정)
                        highlightedIndex: selectedChartPointIndex,
                        isToday: _isToday(),
                        timeOffset: timeOffset,
                      ),
                    ),
            ),
          ),
          if (!isEmpty &&
              selectedChartPointIndex != null &&
              tooltipPosition != null)
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
      if (chartData[i]['systolic'] == null || chartData[i]['diastolic'] == null)
        continue;

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
      double normalizedValue = (250 - systolic) / (250 - 50);
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
      _setChartState(() {
        if (selectedChartPointIndex == closestIndex) {
          selectedChartPointIndex = null;
          tooltipPosition = null;
        } else {
          selectedChartPointIndex = closestIndex;
          tooltipPosition = closestPoint;
        }
      });
    } else {
      _setChartState(() {
        selectedChartPointIndex = null;
        tooltipPosition = null;
      });
    }
  }

  Future<void> _openExpandedChartPage() async {
    await openHealthChartExpandPage(
      context: context,
      periodSelectorBuilder: (_) => _buildPeriodButtons(),
      chartBuilder: (_) =>
          _buildChart(showExpandButton: false, chartHeight: 260),
      onRegisterRefresh: (refresh) {
        _refreshExpandedChart = refresh;
      },
      onDisposeRefresh: () {
        _refreshExpandedChart = null;
      },
    );
  }

  // 차트 툴팁 위젯
  Widget _buildChartTooltip(
      Map<String, dynamic> data, double chartWidth, double chartHeight) {
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
  void _showTimeSelectionBottomSheet(List<BloodPressureRecord> records) async {
    final items = records
        .map(
          (record) => HealthEditBottomSheetItem<BloodPressureRecord>(
            data: record,
            timeText: DateFormat('HH:mm').format(record.measuredAt),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 16,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: ShapeDecoration(
                        color: const Color(0xFF85B0FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(19),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          '수',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${record.systolic}',
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 16,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Row(
                  children: [
                    Container(
                      width: 16,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: ShapeDecoration(
                        color: const Color(0xFFFFBC71),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(19),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          '이',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${record.diastolic}',
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 16,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
        .toList();

    final selected = await showHealthEditBottomSheet<BloodPressureRecord>(
      context: context,
      items: items,
    );

    if (selected == null || !mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BloodPressureInputScreen(record: selected),
      ),
    );

    if (result == true && mounted) {
      _loadData();
    }
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

class _PressureLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _PressureLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphSeriesLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _GraphSeriesLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
