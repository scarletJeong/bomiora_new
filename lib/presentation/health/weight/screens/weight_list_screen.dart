import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/btn_record.dart';
import '../../../common/chart_layout.dart';
import '../../health_common/widgets/health_date_selector.dart';
import '../../health_common/widgets/health_edit_bottom_sheet.dart';
import '../../health_common/widgets/health_chart_expand_page.dart';
import '../../health_common/widgets/health_period_selector.dart';
import '../../../../data/models/health/weight/weight_record_model.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/repositories/health/weight/weight_repository.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../core/utils/image_picker_utils.dart';
import '../widgets/weight_chart_section.dart';
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
      selectedDate, // 오늘 (선택된 날짜)
      selectedDate.add(const Duration(days: 1)), // 내일
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
  VoidCallback? _refreshExpandedChart;

  void _notifyExpandedChart() {
    _refreshExpandedChart?.call();
  }

  bool _isToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;
  }

  // 드래그 범위: 월 고정 / 일별은 6시간 창 슬라이드(오늘은 현재시각 기준)
  double _clampDragOffset(double newOffset) {
    if (selectedPeriod == '월') {
      return newOffset.clamp(0.0, 1.0);
    }
    if (selectedPeriod == '일' && _isToday()) {
      final now = DateTime.now();
      final currentHour = now.hour;
      final maxStartHour = (currentHour - 4).clamp(0, 18);
      final maxOffset = maxStartHour / 18.0;
      return newOffset.clamp(0.0, maxOffset);
    }
    if (selectedPeriod == '일') {
      return newOffset.clamp(0.0, 1.0);
    }
    return newOffset.clamp(0.0, 1.0);
  }

  // 드래그 민감도
  double _getDragSensitivity() {
    return 0.5;
  }

  // 공통 드래그 핸들러
  void _handleDragUpdate(double deltaX, double chartWidth) {
    final sensitivity = _getDragSensitivity();
    final dataDelta = -(deltaX / chartWidth) * sensitivity;
    final newOffset = timeOffset + dataDelta;

    setState(() {
      timeOffset = _clampDragOffset(newOffset);
    });
    _notifyExpandedChart();
  }

  /// 혈압 일그래프와 동일: 6시간 뷰 시작·끝 시각
  Map<String, double> _calculateTimeRange() {
    const maxStartHour = 18;
    final startHour =
        (timeOffset * maxStartHour).clamp(0.0, maxStartHour.toDouble());
    final endHour = (startHour + 6.0).clamp(6.0, 24.0);
    return {'min': startHour, 'max': endHour};
  }

  // 차트 데이터 생성
  List<Map<String, dynamic>> getChartData() {
    if (selectedPeriod == '월') {
      return _getCalendarYearMonthlyWeightData();
    }
    if (selectedPeriod == '주') {
      return _getSevenDayWeightChartData();
    }

    // 일: 선택일 당일 기록만, 시간 순
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final todayRecords = allRecords.where((record) {
      final recordDateStr = DateFormat('yyyy-MM-dd').format(record.measuredAt);
      return recordDateStr == selectedDateStr;
    }).toList();

    todayRecords.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

    final timeRange = _calculateTimeRange();
    final minHourDiff = timeRange['min']!;
    final maxHourDiff = timeRange['max']!;
    final range = maxHourDiff - minHourDiff;
    if (range <= 0) {
      return [];
    }

    final chartData = <Map<String, dynamic>>[];
    for (final record in todayRecords) {
      final recordHour = record.measuredAt.hour;
      final recordMinute = record.measuredAt.minute;
      final normalizedMinute = (recordMinute / 5).floor() * 5;
      final minuteRatio = normalizedMinute / 60.0;
      double xPosition = (recordHour - minHourDiff + minuteRatio) / range;
      xPosition = xPosition.clamp(0.0, 1.0);

      chartData.add({
        'date': DateFormat('HH:mm').format(record.measuredAt),
        'weight': record.weight,
        'record': record,
        'hour': recordHour,
        'normalizedMinute': normalizedMinute,
        'xPosition': xPosition,
      });
    }

    return chartData;
  }

  /// 주별: 선택일 포함 최근 7일 (날짜별 최신값·min/max·개수)
  List<Map<String, dynamic>> _getSevenDayWeightChartData() {
    List<Map<String, dynamic>> chartData = [];
    const days = 7;

    final endDate =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final startDate = endDate.subtract(Duration(days: days - 1));

    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);

      final dayRecords = allRecords.where((record) {
        final recordDateStr =
            DateFormat('yyyy-MM-dd').format(record.measuredAt);
        return recordDateStr == dateKey;
      }).toList();

      if (dayRecords.isNotEmpty) {
        dayRecords.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
        final latestRecord = dayRecords.last;
        final minWeight = dayRecords
            .map((record) => record.weight)
            .reduce((a, b) => a < b ? a : b);
        final maxWeight = dayRecords
            .map((record) => record.weight)
            .reduce((a, b) => a > b ? a : b);

        chartData.add({
          'date': DateFormat('M.d').format(date),
          'weight': latestRecord.weight,
          'record': latestRecord,
          'minWeight': minWeight,
          'maxWeight': maxWeight,
          'count': dayRecords.length,
          'xPosition': i / days,
        });
      } else {
        chartData.add({
          'date': DateFormat('M.d').format(date),
          'weight': null,
          'record': null,
          'minWeight': null,
          'maxWeight': null,
          'count': 0,
          'xPosition': i / days,
        });
      }
    }

    return chartData;
  }

  /// 월별: [selectedDate]의 연도 기준 1~12월, 월 단위 최소·최대 체중 (주간 막대와 동일 개념)
  List<Map<String, dynamic>> _getCalendarYearMonthlyWeightData() {
    final year = selectedDate.year;
    final chartData = <Map<String, dynamic>>[];

    for (int m = 1; m <= 12; m++) {
      final monthRecords = allRecords.where((record) {
        return record.measuredAt.year == year && record.measuredAt.month == m;
      }).toList();

      if (monthRecords.isNotEmpty) {
        monthRecords.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
        final minWeight = monthRecords
            .map((record) => record.weight)
            .reduce((a, b) => a < b ? a : b);
        final maxWeight = monthRecords
            .map((record) => record.weight)
            .reduce((a, b) => a > b ? a : b);
        final latestRecord = monthRecords.last;

        chartData.add({
          'date': '$m월',
          'weight': latestRecord.weight,
          'record': latestRecord,
          'minWeight': minWeight,
          'maxWeight': maxWeight,
          'count': monthRecords.length,
          'xPosition': (m - 1) / 11.0,
          'month': m,
          'year': year,
        });
      } else {
        chartData.add({
          'date': '$m월',
          'weight': null,
          'record': null,
          'minWeight': null,
          'maxWeight': null,
          'count': 0,
          'xPosition': (m - 1) / 11.0,
          'month': m,
          'year': year,
        });
      }
    }

    return chartData;
  }

  /// 메인 체중 그래프 Y축: 정수 중심 c 기준 c-2 ~ c+2 (5개 숫자 눈금, 위→아래).
  /// 데이터가 한눈에 들어오면 c를 조정해 [c-2, c+2] 안에 모두 포함.
  List<double> getYAxisLabelsMain() {
    final chartData = getChartData();
    const fallback = <double>[67, 66, 65, 64, 63];

    if (chartData.isEmpty) return fallback;

    final weights = <double>[];
    for (final data in chartData) {
      if (selectedPeriod == '주' || selectedPeriod == '월') {
        final minW = data['minWeight'] as double?;
        final maxW = data['maxWeight'] as double?;
        if (minW != null) weights.add(minW);
        if (maxW != null) weights.add(maxW);
      } else {
        final w = data['weight'] as double?;
        if (w != null) weights.add(w);
      }
    }

    if (weights.isEmpty) return fallback;

    final minW = weights.reduce((a, b) => a < b ? a : b);
    final maxW = weights.reduce((a, b) => a > b ? a : b);
    final sum = weights.fold<double>(0, (a, b) => a + b);
    final avg = sum / weights.length;
    int c = avg.round();

    if (maxW - minW <= 4) {
      final cMin = (maxW - 2).ceil();
      final cMax = (minW + 2).floor();
      if (cMin <= cMax) {
        c = c.clamp(cMin, cMax);
      } else {
        c = ((minW + maxW) / 2).round();
      }

      return [
        (c + 2).toDouble(),
        (c + 1).toDouble(),
        c.toDouble(),
        (c - 1).toDouble(),
        (c - 2).toDouble(),
      ];
    }

    // 범위가 넓을 때도 눈금선은 정수(.0) 기준으로 고정
    final span = maxW - minW;
    final stepInt = (span / 4.0).ceil().clamp(1, 100);
    int topInt = ((maxW / stepInt).ceil()) * stepInt;
    while ((topInt - 4 * stepInt) > minW) {
      topInt -= stepInt;
    }
    return List<double>.generate(5, (i) => (topInt - i * stepInt).toDouble());
  }

  /// 확대 화면 전용: 현재 그래프에 쓰인 체중들의 평균을 가운데(4번째 눈금)로,
  /// ±3kg 간격으로 Y축 라벨 7개 (상단 avg+3 → 하단 avg-3).
  List<double> getYAxisLabelsExpanded() {
    final chartData = getChartData();
    const fallback = <double>[69, 68, 67, 66, 65, 64, 63];

    if (chartData.isEmpty) return fallback;

    final weights = <double>[];
    for (final data in chartData) {
      if (selectedPeriod == '주' || selectedPeriod == '월') {
        final minW = data['minWeight'] as double?;
        final maxW = data['maxWeight'] as double?;
        if (minW != null) weights.add(minW);
        if (maxW != null) weights.add(maxW);
      } else {
        final w = data['weight'] as double?;
        if (w != null) weights.add(w);
      }
    }

    if (weights.isEmpty) return fallback;

    final minW = weights.reduce((a, b) => a < b ? a : b);
    final maxW = weights.reduce((a, b) => a > b ? a : b);

    if (maxW - minW > 6) {
      // 확대 그래프도 정수(.0) 눈금 기준
      final span = maxW - minW;
      final stepInt = (span / 6.0).ceil().clamp(1, 100);
      int topInt = ((maxW / stepInt).ceil()) * stepInt;
      while ((topInt - 6 * stepInt) > minW) {
        topInt -= stepInt;
      }
      return List<double>.generate(7, (i) => (topInt - i * stepInt).toDouble());
    }

    final sum = weights.fold<double>(0, (a, b) => a + b);
    final avg = sum / weights.length;
    final center = avg.round();
    return List<double>.generate(7, (i) => (center + (3 - i)).toDouble());
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

    if (_isToday()) {
      final now = DateTime.now();
      final startHourTarget = (now.hour - 4).clamp(0, 18);
      timeOffset = startHourTarget / 18.0;
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
        final records =
            await WeightRepository.getWeightRecords(currentUser!.id);

        // 모든 기록 저장 (시간 정보 포함)
        allRecords = records;

        // 날짜를 키로 하는 맵으로 변환 (각 날짜의 마지막 기록)
        weightRecordsMap.clear();
        for (var record in records) {
          final dateKey = DateFormat('yyyy-MM-dd').format(DateTime(
              record.measuredAt.year,
              record.measuredAt.month,
              record.measuredAt.day));
          // 같은 날짜에 여러 기록이 있으면 가장 최근 것만 저장
          if (!weightRecordsMap.containsKey(dateKey) ||
              record.measuredAt
                  .isAfter(weightRecordsMap[dateKey]!.measuredAt)) {
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
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '체중',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Gmarket Sans TTF',
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
                    // 0. 날짜 선택 공통 위젯
                    HealthDateSelector(
                      selectedDate: selectedDate,
                      onDateChanged: (newDate) {
                        setState(() {
                          selectedDate = newDate;
                          selectedChartPointIndex = null;
                          tooltipPosition = null;

                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final isSelectingToday = newDate.year == today.year &&
                              newDate.month == today.month &&
                              newDate.day == today.day;

                          if (isSelectingToday) {
                            final startHourTarget = (now.hour - 4).clamp(0, 18);
                            timeOffset = startHourTarget / 18.0;
                          } else {
                            timeOffset = 0.0;
                          }
                        });
                        _notifyExpandedChart();
                        _loadData();
                      },
                      monthTextColor: const Color(0xFF898686),
                      selectedTextColor: const Color(0xFFFF5A8D),
                      unselectedTextColor: const Color(0xFFB7B7B7),
                      dividerColor: const Color(0xFFD2D2D2),
                      iconColor: const Color(0xFF898686),
                    ),
                    const SizedBox(height: 16),

                    // 1~3. 상단 요약 카드 영역 (시안 기준)
                    _buildTopWeightSummaryCard(),
                    const SizedBox(height: 16),
                    _buildBmiSummaryCard(),
                    const SizedBox(height: 24),

                    // 4~5. 기간 선택 + 차트
                    WeightChartSection(
                      periodSelector: _buildPeriodButtons(),
                      chartContent: _buildChartContent(),
                    ),
                    const SizedBox(height: 30),

                    // 6. 눈바디 이미지
                    _buildBodyImages(),
                    const SizedBox(height: 24),

                    // 7. 기록하기 버튼
                    BtnRecord(
                      text: '+ 기록하기',
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
                      backgroundColor: const Color(0xFFFF3787),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTopWeightSummaryCard() {
    final weight = selectedRecord?.weight ?? 0.0;
    final height = selectedRecord?.height ?? 0.0;
    const targetWeight = 50.0;
    final lostWeight =
        (weight > 0 && targetWeight > 0) ? (weight - targetWeight) : 0.0;
    final progressRatio = (weight <= 0 || targetWeight <= 0)
        ? 0.0
        : ((weight / targetWeight).clamp(0.0, 1.0));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 193,
            height: 193,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 193,
                  height: 193,
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 12,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0x7FD9D9D9)),
                  ),
                ),
                SizedBox(
                  width: 193,
                  height: 193,
                  child: CircularProgressIndicator(
                    value: progressRatio,
                    strokeWidth: 12,
                    color: const Color(0xFFFF5A8D),
                    backgroundColor: Colors.transparent,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '오늘의 체중',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      weight > 0 ? '${weight.toStringAsFixed(1)}kg' : '-',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 36,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: _openSelectedDateEditorPopup,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5A8D),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '수정하기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              border: const Border(
                top: BorderSide(width: 0.5, color: Color(0x7FD2D2D2)),
              ),
            ),
            child: Row(
              children: [
                _buildTopMetricCell(
                  title: '키',
                  value: height > 0 ? '${height.toInt()}' : '-',
                  unit: 'cm',
                ),
                _buildVerticalDivider(),
                _buildTopMetricCell(
                  title: '목표 체중',
                  value: targetWeight > 0 ? '${targetWeight.toInt()}' : '-',
                  unit: 'kg',
                ),
                _buildVerticalDivider(),
                _buildTopMetricCell(
                  title: '감량 몸무게',
                  value: lostWeight != 0
                      ? '${lostWeight > 0 ? '+' : ''}${lostWeight.toInt()}'
                      : '-',
                  unit: 'kg',
                  valueColor: const Color(0xFFFF5A8D),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopMetricCell({
    required String title,
    required String value,
    required String unit,
    Color valueColor = Colors.black,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 10,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 10),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: valueColor,
                      fontSize: 20,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      color: Color(0xFF9C9393),
                      fontSize: 12,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 0.5, height: 46, color: const Color(0x7FD2D2D2));
  }

  Widget _buildBmiSummaryCard() {
    final bmi = selectedRecord?.bmi ?? 0.0;
    final bmiStatus = selectedRecord?.bmiStatus ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Color(0x19000000), blurRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'BMI',
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 16,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                ),
              ),
              Expanded(
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5A8D),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Text(
                      bmiStatus.isNotEmpty ? bmiStatus : '측정필요',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                bmi > 0 ? bmi.toStringAsFixed(2) : '-',
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 16,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildBmiColorBar(),
        ],
      ),
    );
  }

  // 1. 오늘의 체중
  Widget _buildWeightDisplay() {
    final weight = selectedRecord?.weight ?? 0.0;
    final dateStr = DateFormat('yyyy년 M월 d일').format(selectedDate);

    return GestureDetector(
      onTap: _openSelectedDateEditorPopup,
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
            Text(
              '저체중',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontFamily: 'Gmarket Sans TTF',
              ),
            ),
            Text(
              '정상',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontFamily: 'Gmarket Sans TTF',
              ),
            ),
            Text(
              '과체중',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontFamily: 'Gmarket Sans TTF',
              ),
            ),
            Text(
              '비만',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontFamily: 'Gmarket Sans TTF',
              ),
            ),
            Text(
              '고도비만',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontFamily: 'Gmarket Sans TTF',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 4. 기간 선택 버튼
  Widget _buildPeriodButtons() {
    return HealthPeriodSelector(
      selectedPeriod: selectedPeriod,
      onChanged: (period) {
        setState(() {
          selectedPeriod = period;
          selectedChartPointIndex = null;
          tooltipPosition = null;

          if (period == '월') {
            timeOffset = 0.0;
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
          }
        });
        _notifyExpandedChart();

        if (period == '주' || period == '월') {
          _loadData();
        }
      },
    );
  }

  // 5. 차트
  Widget _buildChartContent({
    bool showExpandButton = true,
    double chartHeight = ChartConstants.healthChartHeight,
    bool expandedChartView = false,
  }) {
    final chartData = getChartData();
    final yLabels = expandedChartView
        ? getYAxisLabelsExpanded()
        : getYAxisLabelsMain();
    return WeightChartContent(
      selectedPeriod: selectedPeriod,
      chartData: chartData,
      yLabels: yLabels,
      chartHeight: chartHeight,
      showExpandButton: showExpandButton,
      onExpand: _openExpandedChartPage,
      dataChartBuilder: (height) => WeightDataChart(
        selectedPeriod: selectedPeriod,
        chartData: chartData,
        yLabels: yLabels,
        selectedChartPointIndex: selectedChartPointIndex,
        tooltipPosition: tooltipPosition,
        chartHeight: height,
        timeOffset: timeOffset,
        selectedDate: selectedDate,
        showYAxisKgHeader: true,
        // 메인에서도 월/주는 범위 밖 잘림 없이 표시(확대와 동일 동작)
        omitOutOfRangeWeights: selectedPeriod == '일' ? !expandedChartView : false,
        onTimeOffsetChanged: (newOffset) {
          setState(() {
            timeOffset = newOffset;
          });
          _notifyExpandedChart();
        },
        onTooltipChanged: (index, position) {
          setState(() {
            selectedChartPointIndex = index;
            tooltipPosition = position;
          });
          _notifyExpandedChart();
        },
        chartAreaBuilder: (a, b, c, d) => _buildChartArea(a, b, c, d),
        tooltipBuilder: _buildChartTooltip,
      ),
      emptyChartBuilder: (height) => WeightEmptyChart(
        chartHeight: height,
        selectedPeriod: selectedPeriod,
        selectedDate: selectedDate,
        timeOffset: timeOffset,
        yLabels: yLabels,
        showYAxisKgHeader: true,
      ),
    );
  }

  Future<void> _openExpandedChartPage() async {
    await openHealthChartExpandPage(
      context: context,
      periodSelectorBuilder: (_) => _buildPeriodButtons(),
      chartBuilder: (_) => _buildChartContent(
            showExpandButton: false,
            chartHeight: ChartConstants.healthChartHeight,
            expandedChartView: true,
          ),
      onRegisterRefresh: (refresh) {
        _refreshExpandedChart = refresh;
      },
      onDisposeRefresh: () {
        _refreshExpandedChart = null;
      },
    );
  }

  // 차트 영역 빌드
  Widget _buildChartArea(
    List<Map<String, dynamic>> chartData,
    List<double> yLabels,
    BoxConstraints constraints,
    bool omitOutOfRangeWeights,
  ) {
    return GestureDetector(
      onTapDown: (details) {
        _handleChartTap(
          details.localPosition,
          chartData,
          yLabels.last,
          yLabels.first,
          constraints.maxWidth - ChartConstants.weightChartYAxisStripWidth,
          constraints.maxHeight,
          omitOutOfRangeWeights: omitOutOfRangeWeights,
        );
      },
      onLongPressStart: (details) {
        _handleChartHover(
          details.localPosition,
          chartData,
          yLabels.last,
          yLabels.first,
          constraints.maxWidth - ChartConstants.weightChartYAxisStripWidth,
          constraints.maxHeight,
          omitOutOfRangeWeights: omitOutOfRangeWeights,
        );
      },
      onLongPressMoveUpdate: (details) {
        _handleChartHover(
          details.localPosition,
          chartData,
          yLabels.last,
          yLabels.first,
          constraints.maxWidth - ChartConstants.weightChartYAxisStripWidth,
          constraints.maxHeight,
          omitOutOfRangeWeights: omitOutOfRangeWeights,
        );
      },
      onLongPressEnd: (details) {
        setState(() {
          selectedChartPointIndex = null;
          tooltipPosition = null;
        });
        _notifyExpandedChart();
      },
      // 드래그: 일별(6시간 창)·월별
      onPanStart: (details) {
        if (selectedPeriod == '일' || selectedPeriod == '월') {
          _dragStartX = details.localPosition.dx;
        }
      },
      onPanUpdate: (details) {
        if (selectedPeriod == '일' || selectedPeriod == '월') {
          final deltaX = details.localPosition.dx - (_dragStartX ?? 0);
          _handleDragUpdate(
              deltaX,
              constraints.maxWidth -
                  ChartConstants.weightChartYAxisStripWidth);
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
                omitOutOfRangeWeights: omitOutOfRangeWeights,
              ),
              size: Size(
                constraints.maxWidth -
                    ChartConstants.weightChartYAxisStripWidth,
                constraints.maxHeight,
              ),
            ),
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
  Widget _buildImageContainer(
      String label, String? imagePath, VoidCallback onTap) {
    final hasImage = imagePath != null &&
        imagePath.isNotEmpty &&
        ImagePickerUtils.isImageFileExists(imagePath);

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
      await ImagePickerUtils.showImageSourceDialog(context,
          (XFile? image) async {
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
            } else if (type == 'side' &&
                selectedRecord?.sideImagePath != null) {
              // TODO: 기존 이미지 파일 삭제
            }

            // 데이터베이스 업데이트
            if (selectedRecord != null) {
              final updatedRecord = selectedRecord!.copyWith(
                frontImagePath:
                    type == 'front' ? imageUrl : selectedRecord!.frontImagePath,
                sideImagePath:
                    type == 'side' ? imageUrl : selectedRecord!.sideImagePath,
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
          frontImagePath: imagePath == selectedRecord!.frontImagePath
              ? null
              : selectedRecord!.frontImagePath,
          sideImagePath: imagePath == selectedRecord!.sideImagePath
              ? null
              : selectedRecord!.sideImagePath,
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

  // 차트 클릭 핸들러 (차트의 점 클릭 감지)
  void _handleChartTap(
    Offset tapPosition,
    List<Map<String, dynamic>> chartData,
    double minWeight,
    double maxWeight,
    double chartWidth,
    double chartHeight, {
    bool omitOutOfRangeWeights = false,
  }) {
    if (chartData.isEmpty) return;

    // 가장 가까운 점 찾기
    int? closestIndex;
    double minDistance = double.infinity;
    Offset? closestPoint;

    for (int i = 0; i < chartData.length; i++) {
      final data = chartData[i];
      final weight = data['weight'];

      if (weight == null) continue; // null 값 스킵

      if (omitOutOfRangeWeights) {
        final w = (weight as num).toDouble();
        if (w < minWeight || w > maxWeight) continue;
      }

      if (selectedPeriod == '일') {
        final timeRange = _calculateTimeRange();
        final minHour = timeRange['min']!;
        final maxHour = timeRange['max']!;
        final recordHour = data['hour'] as int?;
        if (recordHour != null &&
            (recordHour < minHour.round() || recordHour > maxHour.round())) {
          continue;
        }
      }

      double x;
      if (data['xPosition'] != null) {
        final xPosition = data['xPosition'] as double;
        final leftPad = ChartConstants.weightDailyChartInnerPadH;
        final rightPad = ChartConstants.weightDailyChartInnerPadH +
            ChartConstants.weightXAxisUnitReservedWidth;
        x = leftPad + (chartWidth - leftPad - rightPad) * xPosition;
      } else if (selectedPeriod == '일') {
        final leftPad = ChartConstants.weightDailyChartInnerPadH;
        final rightPad = ChartConstants.weightDailyChartInnerPadH +
            ChartConstants.weightXAxisUnitReservedWidth;
        final effectiveWidth = chartWidth - leftPad - rightPad;
        x = chartData.length == 1
            ? leftPad + effectiveWidth / 2
            : leftPad + effectiveWidth * i / (chartData.length - 1);
      } else {
        final xPosition = data['xPosition'] as double;
        const visibleDays = 7;
        const totalDays = 30;
        final leftPad = ChartConstants.weightDailyChartInnerPadH;
        final rightPad = ChartConstants.weightDailyChartInnerPadH +
            ChartConstants.weightXAxisUnitReservedWidth;
        if (selectedPeriod == '월') {
          final maxOffset = (totalDays - visibleDays) / totalDays;
          final currentOffset = timeOffset.clamp(0.0, maxOffset);
          final startIndex = (currentOffset * totalDays).floor();
          final endIndex = startIndex + visibleDays;
          final dataIndex = (xPosition * totalDays).round();
          if (dataIndex < startIndex || dataIndex >= endIndex) continue;
          final relativeIndex = dataIndex - startIndex;
          final adjustedRatio = relativeIndex / (visibleDays - 1);
          x = leftPad + (chartWidth - leftPad - rightPad) * adjustedRatio;
        } else {
          x = leftPad + (chartWidth - leftPad - rightPad) * xPosition;
        }
      }

      // Y 좌표 계산 (페인터와 동일한 상하 패딩 적용)
      const topPadding = 20.0;
      const bottomPadding = 20.0;
      final drawableHeight = chartHeight - topPadding - bottomPadding;
      final normalizedWeight = (maxWeight - weight) / (maxWeight - minWeight);
      final y = topPadding + drawableHeight * normalizedWeight;

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
      _notifyExpandedChart();
    } else {
      // 가까운 점이 없으면 툴팁 숨기기
      setState(() {
        selectedChartPointIndex = null;
        tooltipPosition = null;
      });
      _notifyExpandedChart();
    }
  }

  // 차트 호버/드래그 핸들러 (툴팁 표시용)
  void _handleChartHover(
    Offset hoverPosition,
    List<Map<String, dynamic>> chartData,
    double minWeight,
    double maxWeight,
    double chartWidth,
    double chartHeight, {
    bool omitOutOfRangeWeights = false,
  }) {
    if (chartData.isEmpty) return;

    // 가장 가까운 점 찾기
    int? closestIndex;
    double minDistance = double.infinity;
    Offset? closestPoint;

    for (int i = 0; i < chartData.length; i++) {
      final data = chartData[i];
      final weight = data['weight'];

      if (weight == null) continue; // null 값 스킵

      if (omitOutOfRangeWeights) {
        final w = (weight as num).toDouble();
        if (w < minWeight || w > maxWeight) continue;
      }

      if (selectedPeriod == '일') {
        final timeRange = _calculateTimeRange();
        final minHour = timeRange['min']!;
        final maxHour = timeRange['max']!;
        final recordHour = data['hour'] as int?;
        if (recordHour != null &&
            (recordHour < minHour.round() || recordHour > maxHour.round())) {
          continue;
        }
      }

      double x;
      if (data['xPosition'] != null) {
        final xPosition = data['xPosition'] as double;
        final leftPad = ChartConstants.weightDailyChartInnerPadH;
        final rightPad = ChartConstants.weightDailyChartInnerPadH +
            ChartConstants.weightXAxisUnitReservedWidth;
        x = leftPad + (chartWidth - leftPad - rightPad) * xPosition;
      } else if (selectedPeriod == '일') {
        final leftPad = ChartConstants.weightDailyChartInnerPadH;
        final rightPad = ChartConstants.weightDailyChartInnerPadH +
            ChartConstants.weightXAxisUnitReservedWidth;
        final effectiveWidth = chartWidth - leftPad - rightPad;
        x = chartData.length == 1
            ? leftPad + effectiveWidth / 2
            : leftPad + effectiveWidth * i / (chartData.length - 1);
      } else {
        final xPosition = data['xPosition'] as double;
        const visibleDays = 7;
        const totalDays = 30;
        final leftPad = ChartConstants.weightDailyChartInnerPadH;
        final rightPad = ChartConstants.weightDailyChartInnerPadH +
            ChartConstants.weightXAxisUnitReservedWidth;
        if (selectedPeriod == '월') {
          final maxOffset = (totalDays - visibleDays) / totalDays;
          final currentOffset = timeOffset.clamp(0.0, maxOffset);
          final startIndex = (currentOffset * totalDays).floor();
          final endIndex = startIndex + visibleDays;
          final dataIndex = (xPosition * totalDays).round();
          if (dataIndex < startIndex || dataIndex >= endIndex) continue;
          final relativeIndex = dataIndex - startIndex;
          final adjustedRatio = relativeIndex / (visibleDays - 1);
          x = leftPad + (chartWidth - leftPad - rightPad) * adjustedRatio;
        } else {
          x = leftPad + (chartWidth - leftPad - rightPad) * xPosition;
        }
      }

      // Y 좌표 계산 (페인터와 동일한 상하 패딩 적용)
      const topPadding = 20.0;
      const bottomPadding = 20.0;
      final drawableHeight = chartHeight - topPadding - bottomPadding;
      final normalizedWeight = (maxWeight - weight) / (maxWeight - minWeight);
      final y = topPadding + drawableHeight * normalizedWeight;

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
      _notifyExpandedChart();
    } else {
      setState(() {
        selectedChartPointIndex = null;
        tooltipPosition = null;
      });
      _notifyExpandedChart();
    }
  }

  // 차트 툴팁 위젯
  Widget _buildChartTooltip(
      Map<String, dynamic> data, double chartWidth, double chartHeight) {
    if (tooltipPosition == null) return const SizedBox.shrink();

    final weight = data['weight'];
    final record = data['record'];

    // null 값 체크
    if (weight == null || record == null) return const SizedBox.shrink();

    final weightValue = weight as double;
    final weightRecord = record as WeightRecord;

    String formatKoreanTime(DateTime dt) {
      final rounded = ((dt.minute / 5).round()) * 5;
      final hour = rounded == 60 ? (dt.hour + 1) % 24 : dt.hour;
      final minute = rounded == 60 ? 0 : rounded;
      return '$hour시 ${minute.toString().padLeft(2, '0')}분';
    }

    final String timeLabel = selectedPeriod == '일'
        ? formatKoreanTime(weightRecord.measuredAt)
        : DateFormat('M/d HH:mm').format(weightRecord.measuredAt);

    // 부모 Positioned(점 위치 기준) 내에서 상대 이동으로 배치
    double tooltipX = tooltipPosition!.dx;
    double tooltipY = tooltipPosition!.dy - 60;
    const tooltipWidth = 110.0;
    const tooltipHeight = 56.0;

    if (tooltipX < 0) tooltipX = 0;
    if (tooltipX > chartWidth - tooltipWidth) tooltipX = chartWidth - tooltipWidth;
    if (tooltipY < 0) tooltipY = tooltipPosition!.dy + 20;
    if (tooltipY > chartHeight - tooltipHeight) tooltipY = chartHeight - tooltipHeight;

    final timeStyle = TextStyle(
      color: Colors.grey[700],
      fontSize: 12,
      fontWeight: FontWeight.w400,
    );
    final weightStyle = const TextStyle(
      color: Colors.black87,
      fontSize: 14,
      fontWeight: FontWeight.w700,
    );

    return Transform.translate(
      offset: Offset(
        tooltipX - tooltipPosition!.dx,
        tooltipY - tooltipPosition!.dy,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: selectedPeriod == '일'
              ? [
                  Text(timeLabel, style: timeStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(
                    '${weightValue.toStringAsFixed(1)} kg',
                    style: weightStyle,
                    textAlign: TextAlign.center,
                  ),
                ]
              : [
                  Text(
                    '${weightValue.toStringAsFixed(1)} kg',
                    style: weightStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(timeLabel, style: timeStyle, textAlign: TextAlign.center),
                ],
        ),
      ),
    );
  }

  // 시간별 기록 선택 바텀시트
  Future<void> _showTimeSelectionBottomSheet(List<WeightRecord> records) async {
    final selectedRecord = await showHealthEditBottomSheet<WeightRecord>(
      context: context,
      items: records
          .map(
            (record) => HealthEditBottomSheetItem<WeightRecord>(
              data: record,
              timeText: DateFormat('HH:mm').format(record.measuredAt),
              trailing: Text(
                '${record.weight.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  color: Color(0xFFFF5A8D),
                  fontSize: 18,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(),
    );

    if (selectedRecord == null || !mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeightInputScreen(record: selectedRecord),
      ),
    );

    if (result == true && mounted) {
      _loadData();
    }
  }

  Future<void> _openSelectedDateEditorPopup() async {
    if (selectedRecord == null) return;

    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final todayRecords = allRecords.where((record) {
      final recordDateStr = DateFormat('yyyy-MM-dd').format(record.measuredAt);
      return recordDateStr == selectedDateStr;
    }).toList();

    todayRecords.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    if (todayRecords.isEmpty) return;

    // 공통 수정 팝업(health_edit_bottom_sheet) 사용
    await _showTimeSelectionBottomSheet(todayRecords);
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

// 체중 차트 Painter
class WeightChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> chartData;
  final List<double> yLabels;
  final double timeOffset;
  final String selectedPeriod;
  final int? selectedPointIndex;
  final bool omitOutOfRangeWeights;

  WeightChartPainter({
    required this.chartData,
    required this.yLabels,
    required this.timeOffset,
    required this.selectedPeriod,
    this.selectedPointIndex,
    this.omitOutOfRangeWeights = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (chartData.isEmpty || yLabels.length < 2) return;

    final minWeight = yLabels.last; // 최소값 (하단)
    final maxWeight = yLabels.first; // 최대값 (상단)
    final weightRange = maxWeight - minWeight;
    if (weightRange == 0) return;

    // 그리드 선 그리기 (패딩 적용)
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    const double leftPadding = ChartConstants.weightDailyChartInnerPadH;
    const double rightPadding = ChartConstants.weightDailyChartInnerPadH +
        ChartConstants.weightXAxisUnitReservedWidth;
    const double topPadding = 20.0;
    const double bottomPadding = 20.0;
    final gridSegments = yLabels.length - 1;

    for (int i = 0; i <= gridSegments; i++) {
      final y = topPadding +
          (size.height - topPadding - bottomPadding) * i / gridSegments;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
    }

    // 데이터 포인트 계산 및 필터링
    List<Offset> points = [];
    List<int> validIndices = [];
    const maxStartHour = 18;
    final startHour =
        (timeOffset * maxStartHour).clamp(0, maxStartHour).round();
    final endHour = startHour + 6;

    for (int i = 0; i < chartData.length; i++) {
      final data = chartData[i];
      final weight = data['weight'];

      if (weight == null) continue; // null 값 스킵

      final w = (weight as num).toDouble();
      if (omitOutOfRangeWeights &&
          (w < minWeight || w > maxWeight)) {
        continue;
      }

      if (selectedPeriod == '일') {
        final recordHour = data['hour'] as int?;
        if (recordHour != null &&
            (recordHour < startHour || recordHour > endHour)) {
          continue;
        }
      }

      double x;
      if (selectedPeriod == '일') {
        final xPosition = (data['xPosition'] as double?) ?? 0.5;
        x = leftPadding +
            (size.width - leftPadding - rightPadding) * xPosition;
      } else {
        if (data['xPosition'] == null) continue;
        final xPosition = data['xPosition'] as double;
        const visibleDays = 7;
        const totalDays = 30;
        if (selectedPeriod == '월') {
          final maxOffset = (totalDays - visibleDays) / totalDays;
          final currentOffset = timeOffset.clamp(0.0, maxOffset);
          final startIndex = (currentOffset * totalDays).floor();
          final endIndex = startIndex + visibleDays;
          final dataIndex = (xPosition * totalDays).round();
          if (dataIndex < startIndex || dataIndex >= endIndex) continue;
          final relativeIndex = dataIndex - startIndex;
          final adjustedRatio = relativeIndex / (visibleDays - 1);
          x = leftPadding +
              (size.width - leftPadding - rightPadding) * adjustedRatio;
        } else {
          x = leftPadding +
              (size.width - leftPadding - rightPadding) * xPosition;
        }
      }

      // Y 좌표 계산
      const double topPadding = 20.0;
      const double bottomPadding = 20.0;
      final normalizedWeight = (maxWeight - w) / weightRange;
      final y = topPadding +
          (size.height - topPadding - bottomPadding) * normalizedWeight;

      points.add(Offset(x, y));
      validIndices.add(i);
    }

    // 포인트만 그리기 (선 없음), 점은 꽉 찬 색 - 그래프 점
    final pointPaint = Paint()
      ..color = const Color(0xFFFF5A8D)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final originalIndex = validIndices[i];
      final isSelected =
          selectedPointIndex != null && selectedPointIndex == originalIndex;

      if (isSelected) {
        // 선택된 점 - 더 크게, 꽉 찬 원 + 흰색 외곽선
        canvas.drawCircle(point, 8, pointPaint);
        canvas.drawCircle(
          point,
          8,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        // 일반 점 - 꽉 찬 원
        canvas.drawCircle(point, 5, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
