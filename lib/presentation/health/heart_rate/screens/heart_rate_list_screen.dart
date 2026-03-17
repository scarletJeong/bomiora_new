import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../data/models/health/heart_rate/heart_rate_record_model.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/repositories/health/heart_rate/heart_rate_repository.dart';
import '../../../../data/services/auth_service.dart';
import '../../../common/chart_layout.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/period_chart_widget.dart';
import '../../health_common/widgets/health_chart_expand_page.dart';
import '../../health_common/widgets/health_date_selector.dart';
import '../../health_common/widgets/health_period_selector.dart';

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
    if (selectedPeriod != '일') return _getWeeklyOrMonthlyData();

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

  List<Map<String, dynamic>> _getWeeklyOrMonthlyData() {
    final chartData = <Map<String, dynamic>>[];
    final days = selectedPeriod == '주' ? 7 : 30;
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
          'bloodSugar': null,
          'measurementType': null,
          'record': null,
          'xPosition': i / days,
        });
      } else {
        dayRecords.sort((a, b) => b.heartRate.compareTo(a.heartRate));
        final peak = dayRecords.first;
        chartData.add({
          'date': DateFormat('M.d').format(date),
          'bloodSugar': peak.heartRate,
          'measurementType': peak.sourceType,
          'record': peak,
          'xPosition': i / days,
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
      const maxOffset = (30 - 7) / 30.0;
      return newOffset.clamp(0.0, maxOffset);
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '심박수',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
        padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 20),
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
                    timeOffset = (now.hour - 4).clamp(0, 18) / 18.0;
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
            const SizedBox(height: 20),
            const Center(
              child: Text(
                '오늘의 심박수',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _summaryCard('최저 심박수', minBpm)),
                const SizedBox(width: 10),
                Expanded(child: _summaryCard('최고 심박수', maxBpm)),
              ],
            ),
            const SizedBox(height: 14),
            HealthPeriodSelector(
              selectedPeriod: selectedPeriod,
              onChanged: (period) {
                _setChartState(() {
                  selectedPeriod = period;
                  selectedChartPointIndex = null;
                  tooltipPosition = null;
                  if (period == '월') {
                    timeOffset = (30 - 7) / 30.0;
                  } else if (period == '주') {
                    timeOffset = 0.0;
                  } else if (_isToday()) {
                    final now = DateTime.now();
                    timeOffset = (now.hour - 4).clamp(0, 18) / 18.0;
                  } else {
                    timeOffset = 0.0;
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            _buildChart(),
            const SizedBox(height: 12),
            const Row(
              children: [
                _HeartLegend(color: Color(0xFFFF8686), label: '혈압 연동'),
                SizedBox(width: 10),
                _HeartLegend(color: Color(0xFF86B0FF), label: '헬스 연동'),
              ],
            ),
            const SizedBox(height: 16),
            ...todayRecords.reversed.map(_recordTile),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String title, String value) {
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Color(0x19000000), blurRadius: 4.17),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 20.83,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
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
          const Icon(Icons.favorite, color: Color(0xFFFF5A8D), size: 20),
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

  Widget _buildChart({bool showExpandButton = true, double chartHeight = 350}) {
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
        dataType: 'bloodSugar',
        yAxisCount: yLabels.length,
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
    double chartHeight = 350,
  }) {
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
                        children: yLabels
                            .map(
                              (e) => Text(
                                e.round().toString(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onPanStart:
                            (selectedPeriod == '일' || selectedPeriod == '월')
                                ? (details) =>
                                    _dragStartX = details.localPosition.dx
                                : null,
                        onPanUpdate: (selectedPeriod == '일' ||
                                selectedPeriod == '월')
                            ? (details) {
                                if (_dragStartX != null) {
                                  final deltaX =
                                      details.localPosition.dx - _dragStartX!;
                                  final chartWidth = constraints.maxWidth -
                                      ChartConstants.yAxisTotalWidth;
                                  _handleDragUpdate(deltaX, chartWidth);
                                  _dragStartX = details.localPosition.dx;
                                }
                              }
                            : null,
                        onPanEnd:
                            (selectedPeriod == '일' || selectedPeriod == '월')
                                ? (_) => _dragStartX = null
                                : null,
                        child: CustomPaint(
                          painter: _HeartRateChartPainter(
                            chartData,
                            50,
                            250,
                            timeOffset: timeOffset,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding:
                EdgeInsets.only(left: ChartConstants.yAxisTotalWidth),
            child: _buildXAxisLabels(),
          ),
        ],
      ),
    );
  }

  Widget _buildXAxisLabels() {
    final timeRange = _calculateTimeRange();
    final startHour = timeRange['min']!.round();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(
        7,
        (i) => Text(
          '${(startHour + i).clamp(0, 24)}',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
      ),
    );
  }

  Future<void> _openExpandedChartPage() async {
    await openHealthChartExpandPage(
      context: context,
      periodSelectorBuilder: (_) => HealthPeriodSelector(
        selectedPeriod: selectedPeriod,
        onChanged: (period) => _setChartState(() => selectedPeriod = period),
      ),
      chartBuilder: (_) =>
          _buildChart(showExpandButton: false, chartHeight: 260),
      onRegisterRefresh: (refresh) => _refreshExpandedChart = refresh,
      onDisposeRefresh: () => _refreshExpandedChart = null,
    );
  }
}

class _HeartLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _HeartLegend({required this.color, required this.label});

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

  _HeartRateChartPainter(
    this.data,
    this.minValue,
    this.maxValue, {
    required this.timeOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final gridPaint = Paint()
      ..color = const Color(0xFFD9D9D9)
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 4; i++) {
      final y = 20 + (size.height - 40) * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final pointPaint = Paint()
      ..color = const Color(0xFFE91E63)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = const Color(0xFFE91E63)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final points = <Offset>[];
    const maxStartHour = 18;
    final startHour =
        (timeOffset * maxStartHour).clamp(0, maxStartHour).round();
    final endHour = startHour + 6;

    for (int i = 0; i < data.length; i++) {
      final hour = (data[i]['hour'] as int?) ?? 0;
      if (hour < startHour || hour > endHour) continue;

      final xPosition =
          (data[i]['xPosition'] as double?) ?? (i / (data.length - 1));
      final v = (data[i]['bloodSugar'] as int).toDouble();
      final normalized = (maxValue - v) / (maxValue - minValue);
      final x = 8 + (size.width - 16) * xPosition;
      final y = 20 + (size.height - 40) * normalized;
      points.add(Offset(x, y));
    }

    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, linePaint);
    }

    for (final point in points) {
      canvas.drawCircle(point, 5, pointPaint);
      canvas.drawCircle(point, 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
