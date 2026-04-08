import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/chart_layout.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/btn_record.dart';
import '../../health_common/widgets/health_edit_bottom_sheet.dart';
import '../../health_common/widgets/health_chart_expand_page.dart';
import '../../health_common/widgets/health_date_selector.dart';
import '../../../../data/models/health/blood_sugar/blood_sugar_record_model.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/repositories/health/blood_sugar/blood_sugar_repository.dart';
import '../../../../data/services/auth_service.dart';
import '../widgets/blood_sugar_chart_section.dart';
import 'blood_sugar_input_screen.dart';

class BloodSugarListScreen extends StatefulWidget {
  final DateTime? initialDate;

  const BloodSugarListScreen({super.key, this.initialDate});

  @override
  State<BloodSugarListScreen> createState() => _BloodSugarListScreenState();
}

class _BloodSugarListScreenState extends State<BloodSugarListScreen> {
  String selectedPeriod = '일';
  UserModel? currentUser;
  List<BloodSugarRecord> allRecords = []; // 전체 혈당 기록
  Map<String, BloodSugarRecord> bloodSugarRecordsMap = {}; // 날짜별 요약 기록
  Map<String, List<BloodSugarRecord>> dailyRecordsCache = {}; // 날짜별 상세 기록 캐시
  bool isLoading = true;
  bool hasShownNoDataDialog = false;
  late DateTime selectedDate;

  // 차트 관련
  int? selectedChartPointIndex;
  Offset? tooltipPosition;
  double timeOffset = 0.0; // 통합된 드래그 오프셋
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

  BloodSugarRecord? get selectedRecord {
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    return bloodSugarRecordsMap[dateKey];
  }

  // 오늘인지 확인
  bool _isToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;
  }

  // 오늘의 혈당 데이터 가져오기
  List<BloodSugarRecord> getTodayRecords() {
    final today =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    return allRecords.where((record) {
      final recordDate = DateTime(record.measuredAt.year,
          record.measuredAt.month, record.measuredAt.day);
      return recordDate.isAtSameMomentAs(today);
    }).toList();
  }

  // 시간 범위 계산 (통합 로직)
  Map<String, double> _calculateTimeRange() {
    const maxStartHour = 18; // 24시 - 6시간 = 18시 (7개 라벨)
    final startHour =
        (timeOffset * maxStartHour).clamp(0.0, maxStartHour.toDouble());
    final endHour = (startHour + 6.0).clamp(6.0, 24.0);

    return {'min': startHour, 'max': endHour};
  }

  /// 일별 그래프: 기본 timeOffset이 6시간 창 밖에 기록이 있으면(오후 식후 등) 안 보임.
  /// 해당 날 기록의 최소·최대 시각이 한 창에 들어가도록 timeOffset을 맞춘다.
  void _syncTimeOffsetForSelectedDayRecords() {
    if (selectedPeriod != '일') return;

    final key = DateFormat('yyyy-MM-dd').format(selectedDate);
    final dayRecords = dailyRecordsCache[key] ?? [];
    if (dayRecords.isEmpty) return;

    var minH = 24;
    var maxH = 0;
    for (final r in dayRecords) {
      final h = r.measuredAt.hour;
      if (h < minH) minH = h;
      if (h > maxH) maxH = h;
    }

    var start = minH.clamp(0, 18);
    if (start + 6 < maxH) {
      start = (maxH - 6).clamp(0, 18);
    }
    timeOffset = start / 18.0;

    // 오늘은 드래그 상한(현재 시각 − 4시간)과 동일하게 맞춤
    if (_isToday()) {
      final now = DateTime.now();
      final maxStartHour = (now.hour - 4).clamp(0, 18);
      final maxOffset = maxStartHour / 18.0;
      if (timeOffset > maxOffset) timeOffset = maxOffset;
    }
  }

  // 드래그 범위 제한
  double _clampDragOffset(double newOffset) {
    if (selectedPeriod == '월') {
      // 체중·혈압과 동일: 12개월 중 7개월 창 (timeOffset 0~1)
      return newOffset.clamp(0.0, 1.0);
    }
    if (selectedPeriod == '일' && _isToday()) {
      final now = DateTime.now();
      final maxStartHour = (now.hour - 4).clamp(0, 18);
      final maxOffset = maxStartHour / 18.0;
      return newOffset.clamp(0.0, maxOffset);
    }
    return newOffset.clamp(0.0, 1.0);
  }

  /// 월별: 선택 날짜의 달이 보이도록 7개월 창 시작 위치
  void _syncMonthlyTimeOffsetForSelectedDate() {
    if (selectedPeriod != '월') return;
    const totalMonths = 12;
    const visibleMonths = 7;
    final maxStart = totalMonths - visibleMonths;
    if (maxStart <= 0) {
      timeOffset = 0.0;
      return;
    }
    final targetStart =
        (selectedDate.month - visibleMonths).clamp(0, maxStart);
    timeOffset = targetStart / maxStart;
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

    dayRecords.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

    final timeRange = _calculateTimeRange();
    final minHourDiff = timeRange['min']!;
    final maxHourDiff = timeRange['max']!;
    final range = maxHourDiff - minHourDiff;
    final windowStartHour = minHourDiff.round();
    if (range <= 0) return [];

    final byHour = <int, List<BloodSugarRecord>>{};
    for (final record in dayRecords) {
      byHour.putIfAbsent(record.measuredAt.hour, () => []).add(record);
    }
    final sortedHours = byHour.keys.toList()..sort();

    final chartData = <Map<String, dynamic>>[];
    for (final hour in sortedHours) {
      final hourRecords = List<BloodSugarRecord>.from(byHour[hour]!)
        ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

      // 같은 시간대라도 측정유형별로 분리해서 그린다.
      // (겹쳐도 허용) -> 범례 색상(공복/식전/식후/취침전/평상시)이 모두 보이도록.
      final byType = <String, List<BloodSugarRecord>>{};
      for (final r in hourRecords) {
        final t = r.measurementType.trim().isEmpty ? '기타' : r.measurementType.trim();
        byType.putIfAbsent(t, () => []).add(r);
      }

      final typeEntries = byType.entries.toList()
        ..sort((a, b) => _measurementTypeOrder(a.key).compareTo(_measurementTypeOrder(b.key)));

      for (final e in typeEntries) {
        final typed = List<BloodSugarRecord>.from(e.value)
          ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
        if (typed.length >= 2) {
          final minSugar = typed
              .map((r) => r.bloodSugar)
              .reduce((a, b) => a < b ? a : b);
          final maxSugar = typed
              .map((r) => r.bloodSugar)
              .reduce((a, b) => a > b ? a : b);
          final xPosition = (hour - windowStartHour) / 6.0;
          chartData.add({
            'date': '${hour.toString().padLeft(2, '0')}:00',
            'bloodSugar': null,
            'minBloodSugar': minSugar,
            'maxBloodSugar': maxSugar,
            'barColor': _measurementTypeColor(e.key),
            'hourSlotBar': true,
            'hour': hour,
            'measurementType': e.key,
            'xPosition': xPosition.clamp(0.0, 1.0),
            'record': typed.last,
            'records': typed,
            'count': typed.length,
          });
        } else {
          final record = typed.single;
          final recordHour = record.measuredAt.hour;
          final recordMinute = record.measuredAt.minute;
          final chartPoint = _createChartPoint(
              record, recordHour, recordMinute, minHourDiff, maxHourDiff);
          chartData.add(chartPoint);
        }
      }
    }

    return chartData;
  }

  // 차트 포인트 생성 (통합)
  Map<String, dynamic> _createChartPoint(
      BloodSugarRecord record,
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
      'bloodSugar': record.bloodSugar,
      'measurementType': record.measurementType,
      'record': record,
      'normalizedMinute': normalizedMinute,
      'xPosition': xPosition,
    };
  }

  // 주/월 데이터 — 주: 7일, 월: 체중·혈압과 동일 연도 1~12월 중 7개월 창
  List<Map<String, dynamic>> _getWeeklyOrMonthlyData() {
    if (selectedPeriod == '주') {
      return _buildWeeklyBloodSugarData();
    }
    return _buildMonthlyBloodSugarData();
  }

  /// 주별: 각 날짜·측정유형별로 그날 해당 유형 수치의 최댓값 1점 (여러 점이 평면 리스트로 전달됨)
  List<Map<String, dynamic>> _buildWeeklyBloodSugarData() {
    const days = 7;
    final chartPoints = <Map<String, dynamic>>[];
    final endDate = selectedDate;
    final startDate = endDate.subtract(Duration(days: days - 1));

    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final dayRecords = allRecords.where((record) {
        final recordDateStr =
            DateFormat('yyyy-MM-dd').format(record.measuredAt);
        return recordDateStr == dateKey;
      }).toList();

      final xPos = days <= 1 ? 0.5 : i / (days - 1);
      final dateLabel = DateFormat('M.d').format(date);

      if (dayRecords.isEmpty) continue;

      final byType = <String, List<BloodSugarRecord>>{};
      for (final r in dayRecords) {
        final key = r.measurementType.trim().isEmpty
            ? '_기타'
            : r.measurementType.trim();
        byType.putIfAbsent(key, () => []).add(r);
      }

      for (final e in byType.entries) {
        final list = e.value;
        list.sort((a, b) => b.bloodSugar.compareTo(a.bloodSugar));
        final best = list.first;
        chartPoints.add({
          'date': dateLabel,
          'slotIndex': i,
          'bloodSugar': best.bloodSugar,
          'measurementType': best.measurementType.trim().isEmpty
              ? '기타'
              : best.measurementType.trim(),
          'record': best,
          'xPosition': xPos,
          'useSlotDateTooltip': true,
        });
      }
    }

    chartPoints.sort((a, b) {
      final si = a['slotIndex'] as int;
      final sj = b['slotIndex'] as int;
      if (si != sj) return si.compareTo(sj);
      return _measurementTypeOrder(a['measurementType'] as String?)
          .compareTo(_measurementTypeOrder(b['measurementType'] as String?));
    });
    return chartPoints;
  }

  /// 월별: 각 월·측정유형별로 해당 월 해당 유형 수치의 최댓값 1점
  List<Map<String, dynamic>> _buildMonthlyBloodSugarData() {
    const totalMonths = 12;
    const visibleMonths = 7;
    final year = selectedDate.year;
    final maxStart = totalMonths - visibleMonths;
    final startMonthIndex =
        (timeOffset * maxStart).round().clamp(0, maxStart);

    final chartPoints = <Map<String, dynamic>>[];
    for (int i = 0; i < visibleMonths; i++) {
      final month = startMonthIndex + i + 1;
      final monthRecords = allRecords
          .where(
            (r) => r.measuredAt.year == year && r.measuredAt.month == month,
          )
          .toList();

      final xPos = visibleMonths <= 1 ? 0.5 : i / (visibleMonths - 1);
      final label = '$month월';

      if (monthRecords.isEmpty) continue;

      final byType = <String, List<BloodSugarRecord>>{};
      for (final r in monthRecords) {
        final key = r.measurementType.trim().isEmpty
            ? '_기타'
            : r.measurementType.trim();
        byType.putIfAbsent(key, () => []).add(r);
      }

      for (final e in byType.entries) {
        final list = e.value;
        list.sort((a, b) => b.bloodSugar.compareTo(a.bloodSugar));
        final best = list.first;
        chartPoints.add({
          'date': label,
          'chartYear': year,
          'slotIndex': i,
          'bloodSugar': best.bloodSugar,
          'measurementType': best.measurementType.trim().isEmpty
              ? '기타'
              : best.measurementType.trim(),
          'record': best,
          'xPosition': xPos,
          'useSlotDateTooltip': true,
        });
      }
    }

    chartPoints.sort((a, b) {
      final si = a['slotIndex'] as int;
      final sj = b['slotIndex'] as int;
      if (si != sj) return si.compareTo(sj);
      return _measurementTypeOrder(a['measurementType'] as String?)
          .compareTo(_measurementTypeOrder(b['measurementType'] as String?));
    });
    return chartPoints;
  }

  static int _measurementTypeOrder(String? type) {
    const order = ['공복', '식전', '식후', '취침전', '평상시'];
    final t = type ?? '';
    final i = order.indexOf(t);
    return i >= 0 ? i : 50;
  }

  // 메인 그래프 Y축: 기존 유지 (50~250)
  List<double> getYAxisLabelsMain() {
    return const [250, 200, 150, 100, 50];
  }

  // 확대 그래프 Y축: 요청 반영 (20~200, 20단위 10개)
  List<double> getYAxisLabelsExpanded() {
    return const [200, 180, 160, 140, 120, 100, 80, 60, 40, 20];
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

    if (selectedPeriod == '월') {
      _syncMonthlyTimeOffsetForSelectedDate();
    } else if (_isToday()) {
      final currentHour = now.hour;
      final startHourTarget = (currentHour - 4).clamp(0, 18);
      timeOffset = startHourTarget / 18.0;
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
        // 전체 혈당 기록 한 번만 로드
        allRecords =
            await BloodSugarRepository.getBloodSugarRecords(currentUser!.id);

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
          _syncTimeOffsetForSelectedDayRecords();
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // 메모리에서 날짜별로 캐싱 (API 호출 없이 필터링)
  void _cacheRecordsFromMemory() {
    dailyRecordsCache.clear();
    bloodSugarRecordsMap.clear();

    for (var record in allRecords) {
      final dateKey = DateFormat('yyyy-MM-dd').format(record.measuredAt);

      // 날짜별 리스트에 추가
      if (!dailyRecordsCache.containsKey(dateKey)) {
        dailyRecordsCache[dateKey] = [];
      }
      dailyRecordsCache[dateKey]!.add(record);

      // 요약 맵 업데이트 (가장 최근 기록)
      if (!bloodSugarRecordsMap.containsKey(dateKey) ||
          record.measuredAt
              .isAfter(bloodSugarRecordsMap[dateKey]!.measuredAt)) {
        bloodSugarRecordsMap[dateKey] = record;
      }
    }
  }

  // 날짜 변경 시 데이터 로드 (메모리에서 필터링)
  void _loadDataForSelectedDate() {
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);

    // 이미 캐시에 있으면 UI만 업데이트
    if (dailyRecordsCache.containsKey(dateKey)) {
      setState(() {
        _syncTimeOffsetForSelectedDayRecords();
      });
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
      bloodSugarRecordsMap[dateKey] = records.first;
    }

    setState(() {
      _syncTimeOffsetForSelectedDayRecords();
    });
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
            '혈당',
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
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
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

                            if (selectedPeriod == '월') {
                              _syncMonthlyTimeOffsetForSelectedDate();
                            } else if (selectedPeriod == '일') {
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
                      _buildBloodSugarDisplay(),
                      const SizedBox(height: 20),
                      BloodSugarChartSection(
                        selectedPeriod: selectedPeriod,
                        selectedDate: selectedDate,
                        timeOffset: timeOffset,
                        selectedChartPointIndex: selectedChartPointIndex,
                        tooltipPosition: tooltipPosition,
                        isToday: _isToday(),
                        chartData: getChartData(),
                        yLabels: getYAxisLabelsMain(),
                        hasActualDailyData: (dailyRecordsCache[
                                    DateFormat('yyyy-MM-dd')
                                        .format(selectedDate)] ??
                                [])
                            .isNotEmpty,
                        onPeriodChanged: (period) {
                          _setChartState(() {
                            selectedPeriod = period;
                            selectedChartPointIndex = null;
                            tooltipPosition = null;

                            if (period == '월') {
                              _syncMonthlyTimeOffsetForSelectedDate();
                            } else if (period == '주') {
                              timeOffset = 0.0;
                            } else if (period == '일') {
                              if (_isToday()) {
                                final now = DateTime.now();
                                final currentHour = now.hour;
                                final startHourTarget =
                                    (currentHour - 4).clamp(0, 18);
                                timeOffset = startHourTarget / 18.0;
                              } else {
                                timeOffset = 0.0;
                              }
                            } else {
                              timeOffset = 0.0;
                            }

                            if (period == '일' && !_isToday()) {
                              _syncTimeOffsetForSelectedDayRecords();
                            }
                          });

                          if (period == '주' || period == '월') {
                            _loadPeriodData();
                          }
                        },
                        onDragUpdate: _handleDragUpdate,
                        onSelectionChanged: (index, position) {
                          _setChartState(() {
                            selectedChartPointIndex = index;
                            tooltipPosition = position;
                          });
                        },
                        onExpand: _openExpandedChartPage,
                      ),
                      const SizedBox(height: 16),
                    ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(27, 0, 27, 20),
                    child: BtnRecord(
                      text: '+기록하기',
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                BloodSugarInputScreen(
                                  recordContextDate: selectedDate,
                                ),
                          ),
                        );

                        if (result == true || result == null) {
                          await _loadData();
                        }
                      },
                      backgroundColor: const Color(0xFFFF5A8D),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // 혈당 표시
  Widget _buildBloodSugarDisplay() {
    final todayRecords = getTodayRecords();
    final fastingRecord = _latestRecordByType(todayRecords, '공복');
    final postMealRecord = _latestRecordByType(todayRecords, '식후');
    final previousDate =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day - 1);
    final previousDayRecords = _recordsForDate(previousDate);
    final previousFasting = _latestRecordByType(previousDayRecords, '공복');
    final previousPostMeal = _latestRecordByType(previousDayRecords, '식후');

    final int? fastingDiff = (fastingRecord != null && previousFasting != null)
        ? fastingRecord.bloodSugar - previousFasting.bloodSugar
        : null;
    final int? postDiff = (postMealRecord != null && previousPostMeal != null)
        ? postMealRecord.bloodSugar - previousPostMeal.bloodSugar
        : null;

    return GestureDetector(
      onTap: _openSelectedSugarRecordEditor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildSugarSummaryCardNew(
                  label: '공복',
                  value: fastingRecord?.bloodSugar.toString() ?? '-',
                  headerColor: _sugarHeaderColor(fastingRecord?.bloodSugar, '공복'),
                  diffText: _sugarDiffText(fastingDiff),
                  diffUp: _isDiffUp(fastingDiff),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSugarSummaryCardNew(
                  label: '식후',
                  value: postMealRecord?.bloodSugar.toString() ?? '-',
                  headerColor: _sugarHeaderColor(postMealRecord?.bloodSugar, '식후'),
                  diffText: _sugarDiffText(postDiff),
                  diffUp: _isDiffUp(postDiff),
                ),
              ),
            ],
          ),
          // 공복/식후 카드 ui 와 혈당 상태 색상 notice 부분 간격
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _SugarLegend(color: Color(0xFF71D375), label: '정상'),
                    _SugarLegend(color: Color(0xFFFFE78B), label: '전단계'),
                    _SugarLegend(color: Color(0xFFFF6161), label: '의심'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _openSelectedSugarRecordEditor,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5A8D),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '수정하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
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

  List<BloodSugarRecord> _recordsForDate(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    return dailyRecordsCache[key] ?? [];
  }

  BloodSugarRecord? _latestRecordByType(
      List<BloodSugarRecord> records, String type) {
    final filtered = records.where((r) => r.measurementType == type).toList();
    if (filtered.isEmpty) return null;
    filtered.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    return filtered.first;
  }

  String _sugarDiffText(int? diff) {
    if (diff == null) return '수치를 입력하세요';
    return '전날 대비 ${diff.abs()} mg/dL';
  }

  bool _isDiffUp(int? diff) => diff != null && diff > 0;

  /// 혈당 상태별 헤더 색상: 정상 #71D375, 전단계 #FFE78B, 의심 #FF6161.
  /// 사용처: 공복/식후 카드 헤더(_buildSugarSummaryCardNew의 headerColor), 아래 범례(_SugarLegend)와 동일 구간 색상.
  Color _sugarHeaderColor(int? bloodSugar, String type) {
    if (bloodSugar == null) return const Color(0xFF71D375);
    if (type == '공복') {
      if (bloodSugar < 100) return const Color(0xFF71D375); // 정상
      if (bloodSugar <= 125) return const Color(0xFFFFE78B); // 전단계
      return const Color(0xFFFF6161); // 의심
    }
    // 식후
    if (bloodSugar < 140) return const Color(0xFF71D375);
    if (bloodSugar <= 199) return const Color(0xFFFFE78B);
    return const Color(0xFFFF6161);
  }

  Future<void> _openSelectedSugarRecordEditor() async {
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final todayRecords = dailyRecordsCache[selectedDateStr] ?? [];
    if (todayRecords.isEmpty) return;

    todayRecords.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

    if (todayRecords.length > 1) {
      _showTimeSelectionBottomSheet(todayRecords);
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BloodSugarInputScreen(record: todayRecords[0]),
      ),
    );

    if (result == true || result == null) {
      await _loadData();
    }
  }

  Widget _buildSugarSummaryCardNew({
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
                    style: TextStyle(
                      color: const Color(0xFF1A1A1A),
                      fontSize: 20.83,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: value == '-' ? FontWeight.w300 : FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'mg/dl',
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

  Future<void> _openExpandedChartPage() async {
    await openHealthChartExpandPage(
      context: context,
      periodSelectorBuilder: (_) => BloodSugarPeriodSelector(
        selectedPeriod: selectedPeriod,
        onChanged: (period) {
          _setChartState(() {
            selectedPeriod = period;
            selectedChartPointIndex = null;
            tooltipPosition = null;

            if (period == '월') {
              _syncMonthlyTimeOffsetForSelectedDate();
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
      ),
      chartBuilder: (_) => LayoutBuilder(
        builder: (context, constraints) {
          final safeHeight = ChartConstants.healthExpandedChartHeight(
            constraints.maxHeight,
            bottomLegendReserve: 34,
          );

          return BloodSugarChartSection(
            selectedPeriod: selectedPeriod,
            selectedDate: selectedDate,
            timeOffset: timeOffset,
            selectedChartPointIndex: selectedChartPointIndex,
            tooltipPosition: tooltipPosition,
            isToday: _isToday(),
            chartData: getChartData(),
            yLabels: getYAxisLabelsExpanded(),
            hasActualDailyData:
                (dailyRecordsCache[
                            DateFormat('yyyy-MM-dd').format(selectedDate)] ??
                        [])
                    .isNotEmpty,
            showPeriodSelector: false,
            showLegend: true,
            compactLegend: true,
            showExpandButton: false,
            chartHeight: safeHeight,
            onDragUpdate: _handleDragUpdate,
            onSelectionChanged: (index, position) {
              _setChartState(() {
                selectedChartPointIndex = index;
                tooltipPosition = position;
              });
            },
          );
        },
      ),
      onRegisterRefresh: (refresh) {
        _refreshExpandedChart = refresh;
      },
      onDisposeRefresh: () {
        _refreshExpandedChart = null;
      },
    );
  }

  // 시간별 기록 선택 바텀시트
  void _showTimeSelectionBottomSheet(List<BloodSugarRecord> records) async {
    final items = records
        .map(
          (record) => HealthEditBottomSheetItem<BloodSugarRecord>(
            data: record,
            timeText: DateFormat('HH:mm').format(record.measuredAt),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: ShapeDecoration(
                    color: _measurementTypeColor(record.measurementType),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(19),
                    ),
                  ),
                  child: Text(
                    record.measurementType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${record.bloodSugar}',
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 16,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                const Text(
                  'mg/dL',
                  style: TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 12,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();

    final selected = await showHealthEditBottomSheet<BloodSugarRecord>(
      context: context,
      items: items,
    );

    if (selected == null || !mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BloodSugarInputScreen(record: selected),
      ),
    );

    if ((result == true || result == null) && mounted) {
      await _loadData();
    }
  }

  Color _measurementTypeColor(String measurementType) {
    switch (measurementType) {
      case '공복':
        return const Color(0xFF4F82E0);
      case '식전':
        return const Color(0xFFFC8B3A);
      case '식후':
        return const Color(0xFF38B769);
      case '취침전':
        return const Color(0xFF4FD1E0);
      case '평상시':
        return const Color(0xFFB24FE0);
      default:
        return const Color(0xFFE91E63);
    }
  }

  // 데이터 없을 때 다이얼로그 표시
  void _showNoDataDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('혈당 기록 없음'),
        content: const Text(
          '아직 혈당 기록이 없습니다.\n지금 혈당을 입력해주세요!',
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
                  builder: (context) => BloodSugarInputScreen(
                        recordContextDate: selectedDate,
                      ),
                ),
              );

              // 기록 후 항상 데이터 새로고침
              if ((result == true || result == null) && mounted) {
                await _loadData();
              }
            },
            child: const Text('혈당 입력하기'),
          ),
        ],
      ),
    );
  }
}

class _SugarLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _SugarLegend({required this.color, required this.label});

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
              shape: BoxShape.circle,
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
