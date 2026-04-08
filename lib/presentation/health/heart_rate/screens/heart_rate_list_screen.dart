import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../data/models/health/heart_rate/heart_rate_record_model.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/repositories/health/heart_rate/heart_rate_repository.dart';
import '../../../../data/services/auth_service.dart';
import '../../../common/chart_layout.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/period_chart_widget.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../health_common/widgets/health_chart_expand_page.dart';
import '../../health_common/widgets/health_chart_y_axis_strip.dart';
import '../../health_common/widgets/health_date_selector.dart';
import '../../health_common/widgets/health_period_selector.dart';
import '../../weight/widgets/weight_chart_section.dart';

class HeartRateListScreen extends StatefulWidget {
  final DateTime? initialDate;

  const HeartRateListScreen({super.key, this.initialDate});

  @override
  State<HeartRateListScreen> createState() => _HeartRateListScreenState();
}

class _HeartRateListScreenState extends State<HeartRateListScreen> {
  String selectedPeriod = '일';
  late DateTime selectedDate;

  UserModel? currentUser;
  bool isLoading = true;
  final List<HeartRateRecord> _allRecords = [];
  int? selectedChartPointIndex;
  Offset? tooltipPosition;
  double timeOffset = 0.0;
  double? _dragStartX;
  VoidCallback? _refreshExpandedChart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedDate = widget.initialDate != null
        ? DateTime(
            widget.initialDate!.year,
            widget.initialDate!.month,
            widget.initialDate!.day,
          )
        : DateTime(now.year, now.month, now.day);
    if (_isToday()) {
      timeOffset = (now.hour - 4).clamp(0, 18) / 18.0;
    }
    _loadData();
  }

  void _setChartState(VoidCallback updates) {
    if (!mounted) return;
    setState(updates);
    _refreshExpandedChart?.call();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      currentUser = await AuthService.getUser();
      if (currentUser != null) {
        final records = await HeartRateRepository.getHeartRateRecords(
          currentUser!.id,
        );
        _allRecords
          ..clear()
          ..addAll(records);
      } else {
        _allRecords.clear();
      }
    } catch (e) {
      _allRecords.clear();
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  bool _isToday() {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  List<HeartRateRecord> _recordsForSelectedDate() {
    final key = DateFormat('yyyy-MM-dd').format(selectedDate);
    return _allRecords
        .where((r) => DateFormat('yyyy-MM-dd').format(r.measuredAt) == key)
        .toList()
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
  }

  List<Map<String, dynamic>> getChartData() {
    if (selectedPeriod == '월') return _getCalendarYearMonthlyHeartData();
    if (selectedPeriod == '주') return _getWeeklyHeartData();

    final records = _recordsForSelectedDate();
    final timeRange = _calculateTimeRange();
    final minHour = timeRange['min']!;
    final maxHour = timeRange['max']!;
    final range = maxHour - minHour;

    return records.map((record) {
      final h = record.measuredAt.hour;
      final m = (record.measuredAt.minute / 5).floor() * 5;
      final xPosition = ((h - minHour) + m / 60.0) / range;
      return {
        'date': DateFormat('HH:mm').format(record.measuredAt),
        'hour': h,
        'bloodSugar': record.heartRate, // 공통 차트 위젯과 키 호환
        'measurementType': record.sourceType,
        'record': record,
        'xPosition': xPosition.clamp(0.0, 1.0),
      };
    }).toList();
  }

  List<Map<String, dynamic>> _getWeeklyHeartData() {
    final chartData = <Map<String, dynamic>>[];
    const days = 7;
    final endDate =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final startDate = endDate.subtract(Duration(days: days - 1));

    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      final dayRecords = _allRecords
          .where((r) => DateFormat('yyyy-MM-dd').format(r.measuredAt) == key)
          .toList();

      if (dayRecords.isEmpty) {
        chartData.add({
          'date': DateFormat('M.d').format(date),
          'heartRate': null,
          'measurementType': null,
          'record': null,
          'xPosition': i / days,
        });
      } else {
        dayRecords.sort((a, b) => b.heartRate.compareTo(a.heartRate));
        final peak = dayRecords.first;
        chartData.add({
          'date': DateFormat('M.d').format(date),
          'heartRate': peak.heartRate,
          'measurementType': peak.sourceType,
          'record': peak,
          'xPosition': i / days,
        });
      }
    }

    return chartData;
  }

  /// 선택 연도 1~12월 (체중 월별 그래프와 동일 축, 드래그로 7개월 창 이동)
  List<Map<String, dynamic>> _getCalendarYearMonthlyHeartData() {
    final chartData = <Map<String, dynamic>>[];
    final year = selectedDate.year;
    for (int month = 1; month <= 12; month++) {
      final dayRecords = _allRecords.where((r) {
        return r.measuredAt.year == year && r.measuredAt.month == month;
      }).toList();
      final xPosition = (month - 1) / 11.0;
      if (dayRecords.isEmpty) {
        chartData.add({
          'date': '$month',
          'heartRate': null,
          'measurementType': null,
          'record': null,
          'xPosition': xPosition,
        });
      } else {
        dayRecords.sort((a, b) => b.heartRate.compareTo(a.heartRate));
        final peak = dayRecords.first;
        chartData.add({
          'date': '$month',
          'heartRate': peak.heartRate,
          'measurementType': peak.sourceType,
          'record': peak,
          'xPosition': xPosition,
        });
      }
    }
    return chartData;
  }

  Map<String, double> _calculateTimeRange() {
    const maxStartHour = 18;
    final startHour =
        (timeOffset * maxStartHour).clamp(0.0, maxStartHour.toDouble());
    final endHour = (startHour + 6.0).clamp(6.0, 24.0);
    return {'min': startHour, 'max': endHour};
  }

  double _clampDragOffset(double newOffset) {
    if (_isToday()) {
      final now = DateTime.now();
      final maxStartHour = (now.hour - 4).clamp(0, 18);
      return newOffset.clamp(0.0, maxStartHour / 18.0);
    }
    if (selectedPeriod == '월') {
      return newOffset.clamp(0.0, 1.0);
    }
    return newOffset.clamp(0.0, 1.0);
  }

  void _handleDragUpdate(double deltaX, double chartWidth) {
    final sensitivity = selectedPeriod == '월' ? 3.0 : 0.5;
    final dataDelta = -(deltaX / chartWidth) * sensitivity;
    _setChartState(() {
      timeOffset = _clampDragOffset(timeOffset + dataDelta);
    });
  }

  List<double> getYAxisLabels() => [250, 200, 150, 100, 50];

  @override
  Widget build(BuildContext context) {
    final todayRecords = _recordsForSelectedDate();
    final minBpm = todayRecords.isEmpty
        ? '-'
        : '${todayRecords.map((e) => e.heartRate).reduce((a, b) => a < b ? a : b)}';
    final maxBpm = todayRecords.isEmpty
        ? '-'
        : '${todayRecords.map((e) => e.heartRate).reduce((a, b) => a > b ? a : b)}';

    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(title: '심박수'),
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
                        _setChartState(() {
                          selectedDate = newDate;
                          selectedChartPointIndex = null;
                          tooltipPosition = null;
                          if (_isToday()) {
                            final now = DateTime.now();
                            timeOffset =
                                (now.hour - 4).clamp(0, 18) / 18.0;
                          } else {
                            timeOffset = 0.0;
                          }
                        });
                      },
                      monthTextColor: const Color(0xFF898686),
                      selectedTextColor: const Color(0xFFFF5A8D),
                      unselectedTextColor: const Color(0xFFB7B7B7),
                      dividerColor: const Color(0xFFD2D2D2),
                      iconColor: const Color(0xFF898686),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _summaryCard('최저 심박수', minBpm)),
                        const SizedBox(width: 10),
                        Expanded(child: _summaryCard('최고 심박수', maxBpm)),
                      ],
                    ),
                    const SizedBox(height: 25),
                    HealthPeriodSelector(
                      selectedPeriod: selectedPeriod,
                      onChanged: (period) {
                        _setChartState(() {
                          selectedPeriod = period;
                          selectedChartPointIndex = null;
                          tooltipPosition = null;
                          if (period == '월') {
                            timeOffset = 0.0;
                          } else if (period == '주') {
                            timeOffset = 0.0;
                          } else if (_isToday()) {
                            final now = DateTime.now();
                            timeOffset =
                                (now.hour - 4).clamp(0, 18) / 18.0;
                          } else {
                            timeOffset = 0.0;
                          }
                        });
                      },
                    ),
                    // 그래프와 기간 선택(일자별/월별) 카드 간격
                    const SizedBox(height: 3),
                    _buildChart(),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        _HeartLegend(
                            color: Color(0xFFFF8686), label: '운동'),
                        SizedBox(width: 10),
                        _HeartLegend(
                            color: Color(0xFF86B0FF), label: '일상'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...todayRecords.reversed.map(_recordTile),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: _loadData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5A8D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '동기화 하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _summaryCard(String title, String value) {
    final bool hasData = value != '-';
    return Container(
      constraints: const BoxConstraints(minHeight: 90),
      padding: const EdgeInsets.only(bottom: 10),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 0.50, color: Color(0x7FD2D2D2)),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 16.67,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20.83,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: hasData ? FontWeight.w700 : FontWeight.w300,
                  ),
                ),
                const TextSpan(
                  text: ' bpm',
                  style: TextStyle(
                    color: Color(0xFF9C9393),
                    fontSize: 13.33,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
          if (!hasData) ...[
            const SizedBox(height: 5),
            const Text(
              '수치를 입력하세요',
              style: TextStyle(
                color: Color(0xFF9C9393),
                fontSize: 10,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _recordTile(HeartRateRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Color(0x19000000), blurRadius: 4.17),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.access_time,
            color: Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('a h:mm', 'ko').format(record.measuredAt),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${record.heartRate}bpm',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(
      {bool showExpandButton = true,
      double chartHeight = ChartConstants.healthChartHeight}) {
    final chartData = getChartData();
    final yLabels = getYAxisLabels();

    Widget chartBody;
    if (selectedPeriod != '일') {
      chartBody = PeriodChartWidget(
        chartData: chartData,
        yLabels: yLabels,
        selectedPeriod: selectedPeriod,
        selectedDate: selectedDate,
        timeOffset: timeOffset,
        height: chartHeight,
        onTimeOffsetChanged: (newOffset) {
          _setChartState(() => timeOffset = newOffset);
        },
        onTooltipChanged: (index, position) {
          _setChartState(() {
            selectedChartPointIndex = index;
            tooltipPosition = position;
          });
        },
        selectedChartPointIndex: selectedChartPointIndex,
        tooltipPosition: tooltipPosition,
        dataType: 'heartRate',
        yAxisCount: yLabels.length,
        showYAxisUnitHeader: true,
        yAxisUnitLabel: '(bpm)',
        useCalendarYearMonths: selectedPeriod == '월',
        padding: ChartConstants.weightChartCardPadding,
      );
    } else if (_recordsForSelectedDate().isEmpty) {
      chartBody = HealthDailyNoDataChartCard(
        chartHeight: chartHeight,
        title: '해당 기간에 심박수 기록이 없습니다',
        subtitle: '심박수를 측정해보세요',
      );
    } else {
      chartBody =
          _buildDailyChart(chartData, yLabels, chartHeight: chartHeight);
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

  Widget _buildDailyChart(
    List<Map<String, dynamic>> chartData,
    List<double> yLabels, {
    double chartHeight = ChartConstants.healthChartHeight,
  }) {
    return Container(
      height: chartHeight,
      padding: ChartConstants.weightChartCardPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalH = constraints.maxHeight;
                final unitBand =
                    yLabels.length > 1 ? totalH / 6.0 : 0.0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildChartYAxisStripWithUnit(
                      yLabels: yLabels,
                      showUnitHeader: yLabels.length > 1,
                      unitLabel: '(bpm)',
                    ),
                    SizedBox(width: ChartConstants.yAxisSpacing),
                    Expanded(
                      child: Column(
                        children: [
                          if (yLabels.length > 1)
                            SizedBox(height: unitBand),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, inner) {
                                final w = inner.maxWidth;
                                final h = inner.maxHeight;
                                if (w <= 0 || h <= 0) {
                                  return const SizedBox.shrink();
                                }
                                // PeriodChartWidget과 동일: 자식 없는 CustomPaint는 size 필수,
                                // 지정 안 하면 영역이 거의 0으로 잡혀 가로 그리드가 세로 띠처럼 보임.
                                return GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onPanStart: (selectedPeriod == '일' ||
                                          selectedPeriod == '월')
                                      ? (details) => _dragStartX =
                                          details.localPosition.dx
                                      : null,
                                  onPanUpdate: (selectedPeriod == '일' ||
                                          selectedPeriod == '월')
                                      ? (details) {
                                          if (_dragStartX != null) {
                                            final deltaX = details
                                                    .localPosition.dx -
                                                _dragStartX!;
                                            _handleDragUpdate(deltaX, w);
                                            _dragStartX =
                                                details.localPosition.dx;
                                          }
                                        }
                                      : null,
                                  onPanEnd: (selectedPeriod == '일' ||
                                          selectedPeriod == '월')
                                      ? (_) => _dragStartX = null
                                      : null,
                                  child: CustomPaint(
                                    size: Size(w, h),
                                    painter: _HeartRateChartPainter(
                                      chartData,
                                      50,
                                      250,
                                      timeOffset: timeOffset,
                                      pointColorFor: (HeartRateRecord? r) {
                                        if (r == null) {
                                          return const Color(0xFF86B0FF);
                                        }
                                        return r.status == '운동'
                                            ? const Color(0xFFFF8686)
                                            : const Color(0xFF86B0FF);
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 43.0),
            child: buildWeightXAxisLabels(
              selectedPeriod: '일',
              selectedDate: selectedDate,
              timeOffset: timeOffset,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openExpandedChartPage() async {
    await openHealthChartExpandPage(
      context: context,
      periodSelectorBuilder: (_) => HealthPeriodSelector(
        selectedPeriod: selectedPeriod,
        onChanged: (period) => _setChartState(() {
          selectedPeriod = period;
          selectedChartPointIndex = null;
          tooltipPosition = null;
          if (period == '월' || period == '주') {
            timeOffset = 0.0;
          } else if (_isToday()) {
            final now = DateTime.now();
            timeOffset = (now.hour - 4).clamp(0, 18) / 18.0;
          } else {
            timeOffset = 0.0;
          }
        }),
      ),
      chartBuilder: (_) => LayoutBuilder(
        builder: (context, constraints) {
          final safeHeight = ChartConstants.healthExpandedChartHeight(
            constraints.maxHeight,
            bottomLegendReserve: 34,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildChart(
                showExpandButton: false,
                chartHeight: safeHeight,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const _HeartLegend(
                    color: Color(0xFFFF8686),
                    label: '운동',
                    compact: true,
                  ),
                  const SizedBox(width: 6),
                  const _HeartLegend(
                    color: Color(0xFF86B0FF),
                    label: '일상',
                    compact: true,
                  ),
                ],
              ),
            ],
          );
        },
      ),
      onRegisterRefresh: (refresh) => _refreshExpandedChart = refresh,
      onDisposeRefresh: () => _refreshExpandedChart = null,
    );
  }
}

class _HeartLegend extends StatelessWidget {
  final Color color;
  final String label;
  final bool compact;

  const _HeartLegend({
    required this.color,
    required this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final dot = compact ? 8.0 : 12.0;
    final gap = compact ? 3.0 : 5.0;
    final fontSize = compact ? 9.0 : 12.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dot,
          height: dot,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: gap),
        Text(
          label,
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _HeartRateChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double minValue;
  final double maxValue;
  final double timeOffset;
  final Color Function(HeartRateRecord? record) pointColorFor;

  _HeartRateChartPainter(
    this.data,
    this.minValue,
    this.maxValue, {
    required this.timeOffset,
    required this.pointColorFor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final leftPad = ChartConstants.weightDailyChartInnerPadH;
    final rightPad = ChartConstants.weightDailyChartInnerPadH;
    const topPad = 20.0;
    const botPad = 20.0;
    final plotH = size.height - topPad - botPad;
    final plotW = size.width - leftPad - rightPad;

    const maxStartHour = 18;
    final startHour =
        (timeOffset * maxStartHour).clamp(0, maxStartHour).round();
    final endHour = startHour + 6;

    // 일자별/월별 PeriodChartPainter와 동일: 가로 그리드만, 좌우 패딩 구간 전체 너비
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    const yAxisCount = 5;
    for (int i = 0; i < yAxisCount; i++) {
      final y = topPad + plotH * i / (yAxisCount - 1);
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );
    }

    if (data.isEmpty) return;

    final spots = <({Offset offset, Color color})>[];

    for (int i = 0; i < data.length; i++) {
      final hour = (data[i]['hour'] as int?) ?? 0;
      if (hour < startHour || hour > endHour) continue;

      final xPosition =
          (data[i]['xPosition'] as double?) ?? (i / (data.length - 1));
      final v = (data[i]['bloodSugar'] as int).toDouble();
      final normalized = (maxValue - v) / (maxValue - minValue);
      final x = leftPad + plotW * xPosition;
      final y = topPad + plotH * normalized;
      final rec = data[i]['record'] as HeartRateRecord?;
      spots.add((offset: Offset(x, y), color: pointColorFor(rec)));
    }

    const dotRadius = 6.0;
    for (final s in spots) {
      canvas.drawCircle(
        s.offset,
        dotRadius,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
