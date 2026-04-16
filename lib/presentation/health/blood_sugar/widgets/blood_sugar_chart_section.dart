import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../../common/chart_layout.dart';
import '../../../../core/constants/app_assets.dart';
import '../../health_common/widgets/health_period_selector.dart';
import '../../blood_pressure/widgets/blood_pressure_chart_section.dart'
    show buildBloodPressureYAxisStrip, bloodPressureYAxisUnitBandHeight;
import 'blood_sugar_tooltip.dart';

/// 반지름 [r]인 두 원의 교차 면적이 π·r²·[minAreaFraction] 이상일 때의 최대 중심거리 (이하이면 겹침으로 본다).
double _maxCenterDistanceForCircleOverlapFraction(
  double r, {
  double minAreaFraction = 1.0 / 3.0,
}) {
  if (r <= 0) return 0;
  final target = minAreaFraction * math.pi * r * r;
  var lo = 0.0;
  var hi = 2 * r;
  for (var k = 0; k < 48; k++) {
    final mid = (lo + hi) / 2;
    final area = _circleIntersectionAreaSameR(r, mid);
    if (area >= target) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}

double _circleIntersectionAreaSameR(double r, double d) {
  if (d <= 0) return math.pi * r * r;
  if (d >= 2 * r) return 0;
  final half = d / 2;
  return 2 * r * r * math.acos(half / r) -
      half * math.sqrt(4 * r * r - d * d);
}

/// 겹침(+) 마커 테두리·플러스 색
const Color bloodSugarOverlapAccentColor = Color(0xFFFF5A8D);

/// 주/월 차트에서 겹침으로 묶인 점 그룹(데이터 인덱스 + 플롯 중심, CustomPaint 좌표).
class BloodSugarOverlapCluster {
  BloodSugarOverlapCluster({
    required this.dataIndices,
    required this.centroid,
  });

  final List<int> dataIndices;
  final Offset centroid;
}

int _tooltipMeasurementTypeOrder(String? type) {
  const order = ['공복', '식전', '식후', '취침전', '평상시'];
  final t = type ?? '';
  final i = order.indexOf(t);
  return i >= 0 ? i : 50;
}

/// Painter·탭·툴팁이 동일한 겹침 그룹/중심을 쓰도록 공통 계산.
List<BloodSugarOverlapCluster> bloodSugarComputeWeekMonthOverlapClusters(
  List<Map<String, dynamic>> data,
  Size size,
  double minValue,
  double maxValue,
) {
  final indices = <int>[];
  for (var i = 0; i < data.length; i++) {
    if (data[i]['bloodSugar'] != null) indices.add(i);
  }
  if (indices.isEmpty) return [];

  const double overlapCircleRadiusPx = 5.0;
  final maxMergeDist = _maxCenterDistanceForCircleOverlapFraction(
    overlapCircleRadiusPx,
    minAreaFraction: 1.0 / 3.0,
  );
  final maxMergeDistSq = maxMergeDist * maxMergeDist;

  const double borderWidth = 0.5;
  const double pointRadius = 8;
  final x0 = borderWidth + pointRadius;
  final chartWidth = size.width -
      (borderWidth * 2) -
      (pointRadius * 2) -
      ChartConstants.weightXAxisUnitReservedWidth;

  const plotTop = 20.0;
  const plotBottom = 20.0;

  double yForValue(int v) {
    final clamped = v.clamp(minValue.toInt(), maxValue.toInt()).toDouble();
    final normalized = (maxValue - clamped) / (maxValue - minValue);
    return plotTop + (size.height - plotTop - plotBottom) * normalized;
  }

  Offset offsetForIndex(int i) {
    final xPosition = data[i]['xPosition'] as double;
    final x = x0 + chartWidth * xPosition;
    final y = yForValue(data[i]['bloodSugar'] as int);
    return Offset(x, y);
  }

  String typeOf(int i) => data[i]['measurementType']?.toString() ?? '';

  final n = indices.length;
  final uf = List<int>.generate(n, (i) => i);
  int find(int i) {
    if (uf[i] != i) uf[i] = find(uf[i]);
    return uf[i];
  }

  void union(int a, int b) {
    final ra = find(a);
    final rb = find(b);
    if (ra != rb) uf[ra] = rb;
  }

  for (var a = 0; a < n; a++) {
    for (var b = a + 1; b < n; b++) {
      final ia = indices[a];
      final ib = indices[b];
      if (typeOf(ia) == typeOf(ib)) continue;
      final da = offsetForIndex(ia);
      final db = offsetForIndex(ib);
      final dx = da.dx - db.dx;
      final dy = da.dy - db.dy;
      if (dx * dx + dy * dy <= maxMergeDistSq) {
        union(a, b);
      }
    }
  }

  final buckets = <int, List<int>>{};
  for (var k = 0; k < n; k++) {
    final root = find(k);
    buckets.putIfAbsent(root, () => []).add(k);
  }

  final rawGroups = <List<int>>[];
  for (final members in buckets.values) {
    if (members.length < 2) continue;
    final types = members.map((k) => typeOf(indices[k])).toSet();
    if (types.length >= 2) rawGroups.add(members);
  }

  final result = <BloodSugarOverlapCluster>[];
  for (final members in rawGroups) {
    final dataIndices = members.map((k) => indices[k]).toList();
    var sx = 0.0;
    var sy = 0.0;
    for (final di in dataIndices) {
      final o = offsetForIndex(di);
      sx += o.dx;
      sy += o.dy;
    }
    final nMembers = dataIndices.length;
    result.add(BloodSugarOverlapCluster(
      dataIndices: dataIndices,
      centroid: Offset(sx / nMembers, sy / nMembers),
    ));
  }

  int minSlotCount(List<int> di) {
    var m = 1 << 30;
    for (final i in di) {
      final s = data[i]['slotIndex'];
      if (s is int && s < m) m = s;
    }
    return m == 1 << 30 ? 0 : m;
  }

  result.sort((a, b) {
    final sa = minSlotCount(a.dataIndices);
    final sb = minSlotCount(b.dataIndices);
    if (sa != sb) return sa.compareTo(sb);
    final ia = a.dataIndices.reduce(math.min);
    final ib = b.dataIndices.reduce(math.min);
    return ia.compareTo(ib);
  });

  return result;
}

class BloodSugarPeriodSelector extends StatelessWidget {
  final String selectedPeriod;
  final ValueChanged<String> onChanged;

  const BloodSugarPeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return HealthPeriodSelector(
      selectedPeriod: selectedPeriod,
      onChanged: onChanged,
    );
  }
}

class BloodSugarChartSection extends StatefulWidget {
  static const List<String> measurementFilters = [
    '전체',
    '공복',
    '식전/식후',
    '취침전',
    '평상시',
  ];

  final String selectedPeriod;
  final DateTime selectedDate;
  final double timeOffset;
  final int? selectedChartPointIndex;
  final Offset? tooltipPosition;
  final bool isToday;
  final bool showPeriodSelector;
  final bool showLegend;
  /// 확대 화면 등에서 범례를 더 작게 표시
  final bool compactLegend;
  final bool showExpandButton;
  final bool showMeasurementFilter;
  final double chartHeight;
  final String selectedMeasurementFilter;
  final List<Map<String, dynamic>> chartData;
  final List<double> yLabels;
  final bool hasActualDailyData;
  final VoidCallback? onExpand;
  final ValueChanged<String>? onPeriodChanged;
  final ValueChanged<String>? onMeasurementFilterChanged;
  final void Function(double deltaX, double chartWidth) onDragUpdate;
  final void Function(int? index, Offset? position) onSelectionChanged;

  const BloodSugarChartSection({
    super.key,
    required this.selectedPeriod,
    required this.selectedDate,
    required this.timeOffset,
    required this.selectedChartPointIndex,
    required this.tooltipPosition,
    required this.isToday,
    required this.chartData,
    required this.yLabels,
    required this.hasActualDailyData,
    required this.onDragUpdate,
    required this.onSelectionChanged,
    this.showPeriodSelector = true,
    this.showLegend = true,
    this.compactLegend = false,
    this.showExpandButton = true,
    this.showMeasurementFilter = true,
    this.chartHeight = ChartConstants.healthChartHeight,
    this.selectedMeasurementFilter = '전체',
    this.onExpand,
    this.onPeriodChanged,
    this.onMeasurementFilterChanged,
  });

  @override
  State<BloodSugarChartSection> createState() => _BloodSugarChartSectionState();
}

class _BloodSugarChartSectionState extends State<BloodSugarChartSection> {
  double? _dragStartX;
  final GlobalKey _filterAnchorKey = GlobalKey();
  OverlayEntry? _filterMenuEntry;
  ScrollController? _filterScrollController;
  String? _hoveredFilter;

  List<Map<String, dynamic>> _filteredChartData(List<Map<String, dynamic>> source) {
    final selected = widget.selectedMeasurementFilter.trim();
    if (selected.isEmpty || selected == '전체') return source;
    if (selected == '식전/식후') {
      return source.where((row) {
        final type = (row['measurementType']?.toString() ?? '').trim();
        return type == '식전' || type == '식후';
      }).toList();
    }
    return source
        .where((row) => (row['measurementType']?.toString() ?? '').trim() == selected)
        .toList();
  }

  @override
  void dispose() {
    _closeMeasurementFilterMenu();
    super.dispose();
  }

  void _closeMeasurementFilterMenu() {
    _filterMenuEntry?.remove();
    _filterMenuEntry = null;
    _filterScrollController?.dispose();
    _filterScrollController = null;
    if (_hoveredFilter != null && mounted) {
      setState(() => _hoveredFilter = null);
    }
  }

  void _toggleMeasurementFilterMenu() {
    if (_filterMenuEntry != null) {
      _closeMeasurementFilterMenu();
      return;
    }
    _openMeasurementFilterMenu();
  }

  void _openMeasurementFilterMenu() {
    final anchorContext = _filterAnchorKey.currentContext;
    final anchorBox = anchorContext?.findRenderObject() as RenderBox?;
    if (anchorBox == null || !anchorBox.attached) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (overlayBox == null) return;

    const menuWidth = 153.0;
    const rowHeight = 24.0;
    const visibleRows = 3;
    const menuPadTop = 10.0;
    const menuPadBottom = 5.0;
    final menuHeight = menuPadTop + menuPadBottom + (rowHeight * visibleRows);

    final anchorTopLeft = anchorBox.localToGlobal(Offset.zero);
    var left = anchorTopLeft.dx;
    var top = anchorTopLeft.dy + anchorBox.size.height + 4;
    left = left.clamp(8.0, overlayBox.size.width - menuWidth - 8.0);
    top = top.clamp(8.0, overlayBox.size.height - menuHeight - 8.0);

    final selectedIndex = BloodSugarChartSection.measurementFilters
        .indexOf(widget.selectedMeasurementFilter);
    final maxStartIndex =
        (BloodSugarChartSection.measurementFilters.length - visibleRows)
            .clamp(0, BloodSugarChartSection.measurementFilters.length);
    final startIndex = (selectedIndex - 1).clamp(0, maxStartIndex);
    _filterScrollController = ScrollController(initialScrollOffset: startIndex * rowHeight);

    _filterMenuEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeMeasurementFilterMenu,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: Material(
              color: Colors.transparent,
              child: Container(
                clipBehavior: Clip.antiAlias,
                width: menuWidth,
                padding: const EdgeInsets.only(top: menuPadTop, bottom: menuPadBottom),
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(width: 0.50, color: Color(0xFFD2D2D2)),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                child: SizedBox(
                  height: rowHeight * visibleRows,
                  child: ListView.builder(
                    controller: _filterScrollController,
                    padding: EdgeInsets.zero,
                    itemCount: BloodSugarChartSection.measurementFilters.length,
                    itemBuilder: (context, index) {
                      final label = BloodSugarChartSection.measurementFilters[index];
                      final hovered = _hoveredFilter == label;
                      final hasThinBorder =
                          index < BloodSugarChartSection.measurementFilters.length - 1;
                      return MouseRegion(
                        onEnter: (_) {
                          _hoveredFilter = label;
                          _filterMenuEntry?.markNeedsBuild();
                        },
                        onExit: (_) {
                          _hoveredFilter = null;
                          _filterMenuEntry?.markNeedsBuild();
                        },
                        child: InkWell(
                          onTap: () {
                            _closeMeasurementFilterMenu();
                            if (label == widget.selectedMeasurementFilter) return;
                            widget.onSelectionChanged(null, null);
                            widget.onMeasurementFilterChanged?.call(label);
                          },
                          child: Container(
                            width: double.infinity,
                            height: rowHeight,
                            padding: const EdgeInsets.all(5),
                            decoration: ShapeDecoration(
                              shape: RoundedRectangleBorder(
                                side: hasThinBorder
                                    ? const BorderSide(
                                        width: 0.30,
                                        color: Color(0x7FD2D2D2),
                                      )
                                    : BorderSide.none,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: hovered
                                    ? const Color(0xFFFF5A8D)
                                    : Colors.black,
                                fontSize: 10,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_filterMenuEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final chart = _buildChart(
      showExpandButton: widget.showExpandButton,
      chartHeight: widget.chartHeight,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showPeriodSelector) ...[
          const SizedBox(height: 25),
          BloodSugarPeriodSelector(
            selectedPeriod: widget.selectedPeriod,
            onChanged: (period) => widget.onPeriodChanged?.call(period),
          ),
          // 그래프와 기간 선택(일자별/월별) 카드 간격
          const SizedBox(height: 3),
        ],
        chart,
        if (widget.showLegend) ...[
          SizedBox(height: widget.compactLegend ? 6 : 14),
          Row(
            children: [
              _GlucoseSeriesLegend(
                  color: const Color(0xFF4F82E0),
                  label: '공복',
                  compact: widget.compactLegend),
              SizedBox(width: widget.compactLegend ? 6 : 10),
              _GlucoseSeriesLegend(
                  color: const Color(0xFFFC8B3A),
                  label: '식전',
                  compact: widget.compactLegend),
              SizedBox(width: widget.compactLegend ? 6 : 10),
              _GlucoseSeriesLegend(
                  color: const Color(0xFF38B769),
                  label: '식후',
                  compact: widget.compactLegend),
              SizedBox(width: widget.compactLegend ? 6 : 10),
              _GlucoseSeriesLegend(
                  color: const Color(0xFF4FD1E0),
                  label: '취침전',
                  compact: widget.compactLegend),
              SizedBox(width: widget.compactLegend ? 6 : 10),
              _GlucoseSeriesLegend(
                  color: const Color(0xFFB24FE0),
                  label: '평상시',
                  compact: widget.compactLegend),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildChart(
      {bool showExpandButton = true,
      double chartHeight = ChartConstants.healthChartHeight}) {
    final filteredData = _filteredChartData(widget.chartData);
    final effectiveChartHeight =
        chartHeight + (widget.showMeasurementFilter ? 40.0 : 0.0);
    Widget chartBody;
    if (widget.selectedPeriod == '일' && !widget.hasActualDailyData) {
      chartBody = _buildNoDataMessage(chartHeight: effectiveChartHeight);
    } else if (filteredData.isEmpty) {
      chartBody = _buildDraggableChart(
        [],
        widget.yLabels,
        isEmpty: true,
        chartHeight: effectiveChartHeight,
      );
    } else {
      chartBody = _buildDraggableChart(
        filteredData,
        widget.yLabels,
        isEmpty: false,
        chartHeight: effectiveChartHeight,
      );
    }

    if (!showExpandButton && !widget.showMeasurementFilter) return chartBody;

    return Stack(
      children: [
        chartBody,
        Positioned(
          right: 4,
          top: 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (showExpandButton)
                GestureDetector(
                  onTap: widget.onExpand,
                  behavior: HitTestBehavior.opaque,
                  child: SvgPicture.asset(
                    AppAssets.healthZoomin,
                    width: 20,
                    height: 20,
                    fit: BoxFit.contain,
                  ),
                ),
              if (widget.showMeasurementFilter) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  key: _filterAnchorKey,
                  onTap: _toggleMeasurementFilterMenu,
                  child: Container(
                    width: 164,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: ShapeDecoration(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(
                          width: 0.50,
                          color: Color(0x7FD2D2D2),
                        ),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          widget.selectedMeasurementFilter,
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 10,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoDataMessage(
      {double chartHeight = ChartConstants.healthChartHeight}) {
    return HealthDailyNoDataChartCard(
      chartHeight: chartHeight,
      title: '해당 기간에 혈당 기록이 없습니다',
      subtitle: '혈당을 측정해보세요',
    );
  }

  Widget _buildDraggableChart(
    List<Map<String, dynamic>> chartData,
    List<double> yLabels, {
    required bool isEmpty,
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
          if (widget.showMeasurementFilter) const SizedBox(height: 34),
          Expanded(
            child: LayoutBuilder(
              builder: (context, outerConstraints) {
                final showYHeader = yLabels.length > 1;
                final headerBand =
                    showYHeader ? bloodPressureYAxisUnitBandHeight : 0.0;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildBloodPressureYAxisStrip(
                      yLabels: yLabels,
                      showYAxisHeader: showYHeader,
                      unitLabel: '(mg/dL)',
                    ),
                    SizedBox(width: ChartConstants.yAxisSpacing),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showYHeader) SizedBox(height: headerBand),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, plotConstraints) {
                                return _buildChartArea(
                                  chartData,
                                  plotConstraints,
                                  isEmpty,
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
          const SizedBox(height: 6),
          SizedBox(
            height: 20,
            child: Padding(
              padding: EdgeInsets.only(
                left: ChartConstants.weightChartYAxisStripWidth,
              ),
              child: buildBloodSugarXAxisLabels(
                selectedPeriod: widget.selectedPeriod,
                selectedDate: widget.selectedDate,
                timeOffset: widget.timeOffset,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartArea(List<Map<String, dynamic>> chartData,
      BoxConstraints constraints, bool isEmpty) {
    final chartW = constraints.maxWidth;
    final chartH = constraints.maxHeight;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (widget.selectedPeriod == '일' || widget.selectedPeriod == '월')
          ? (details) {
              // 혈압 그래프와 동일하게: 드래그 시작 시 기존 툴팁 닫기
              widget.onSelectionChanged(null, null);
              _dragStartX = details.localPosition.dx;
            }
          : null,
      onPanUpdate:
          (widget.selectedPeriod == '일' || widget.selectedPeriod == '월')
              ? (details) {
                  if (_dragStartX != null) {
                    final deltaX = details.localPosition.dx - _dragStartX!;
                    widget.onDragUpdate(deltaX, chartW);
                    _dragStartX = details.localPosition.dx;
                  }
                }
              : null,
      onPanEnd: (widget.selectedPeriod == '일' || widget.selectedPeriod == '월')
          ? (details) => _dragStartX = null
          : null,
      onTapDown: isEmpty
          ? null
          : (details) {
              _handleChartTapToggle(
                details.localPosition,
                chartData,
                chartW,
                chartH,
              );
            },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: isEmpty
                ? CustomPaint(
                    painter: EmptyBloodSugarChartGridPainter(
                      yLabels: widget.yLabels,
                      minValue: widget.yLabels.last,
                      maxValue: widget.yLabels.first,
                    ),
                  )
                : CustomPaint(
                    painter: BloodSugarChartPainter(
                      chartData,
                      widget.yLabels.last,
                      widget.yLabels.first,
                      yLabels: widget.yLabels,
                      highlightedIndex: widget.selectedChartPointIndex,
                      isToday: widget.isToday,
                      timeOffset: widget.timeOffset,
                      selectedPeriod: widget.selectedPeriod,
                    ),
                  ),
          ),
          if (!isEmpty &&
              widget.selectedChartPointIndex != null &&
              widget.tooltipPosition != null)
            BloodSugarTooltip(
              data: _tooltipRowForChartIndex(
                chartData,
                widget.selectedChartPointIndex!,
                chartW,
                chartH,
                widget.yLabels.last,
                widget.yLabels.first,
              ),
              selectedPeriod: widget.selectedPeriod,
              selectedDate: widget.selectedDate,
              tooltipPosition: widget.tooltipPosition,
              chartWidth: chartW,
              chartHeight: chartH,
            ),
        ],
      ),
    );
  }

  void _handleChartTapToggle(
    Offset tapPosition,
    List<Map<String, dynamic>> chartData,
    double chartWidth,
    double chartHeight,
  ) {
    if (chartData.isEmpty) return;

    const double leftPadding = 0.0;
    final double effectiveWidth = chartWidth - leftPadding;

    int? closestIndex;
    double minDistance = double.infinity;
    Offset? closestPoint;

    void considerPoint(
      double x,
      double y,
      int selectionIndex, {
      required double maxDistanceSq,
      double xHitSlop = 0,
      double yHitSlop = 0,
    }) {
      final dx = tapPosition.dx - x;
      final dy = tapPosition.dy - y;
      if (xHitSlop > 0 && yHitSlop > 0) {
        final inRect = dx.abs() <= xHitSlop && dy.abs() <= yHitSlop;
        if (!inRect) return;
      }
      final distance = dx * dx + dy * dy;
      if (distance > maxDistanceSq) return;
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = selectionIndex;
        closestPoint = Offset(x, y);
      }
    }

    final inOverlapDataIndex = <int>{};
    if (widget.selectedPeriod == '주' || widget.selectedPeriod == '월') {
      final occ = bloodSugarComputeWeekMonthOverlapClusters(chartData,
          Size(chartWidth, chartHeight), widget.yLabels.last, widget.yLabels.first);
      for (var ci = 0; ci < occ.length; ci++) {
        final c = occ[ci];
        for (final di in c.dataIndices) {
          inOverlapDataIndex.add(di);
        }
        considerPoint(
          c.centroid.dx,
          c.centroid.dy,
          -(ci + 1),
          maxDistanceSq: 18 * 18,
          xHitSlop: 18,
          yHitSlop: 18,
        );
      }
    }

    for (int i = 0; i < chartData.length; i++) {
      if (widget.selectedPeriod == '일' && chartData[i]['hourSlotBar'] == true) {
        final minSugar = chartData[i]['minBloodSugar'] as int?;
        final maxSugar = chartData[i]['maxBloodSugar'] as int?;
        if (minSugar == null || maxSugar == null) continue;
        final xPosition = (chartData[i]['xPosition'] as double?) ?? 0.5;
        final x = leftPadding + (effectiveWidth * xPosition);
        const double topPadding = 20.0;
        const double bottomPadding = 20.0;
        final clampedMin =
            minSugar.clamp(widget.yLabels.last.toInt(), widget.yLabels.first.toInt());
        final clampedMax =
            maxSugar.clamp(widget.yLabels.last.toInt(), widget.yLabels.first.toInt());
        final normalizedMin = (widget.yLabels.first - clampedMin) /
            (widget.yLabels.first - widget.yLabels.last);
        final normalizedMax = (widget.yLabels.first - clampedMax) /
            (widget.yLabels.first - widget.yLabels.last);
        final yMin = topPadding +
            (chartHeight - topPadding - bottomPadding) * normalizedMin;
        final yMax = topPadding +
            (chartHeight - topPadding - bottomPadding) * normalizedMax;
        final yTop = math.min(yMin, yMax);
        final yBottom = math.max(yMin, yMax);
        final yCenter = (yTop + yBottom) / 2;
        const halfW = 14.0;
        final inBand = tapPosition.dx >= x - halfW &&
            tapPosition.dx <= x + halfW &&
            tapPosition.dy >= yTop - 10 &&
            tapPosition.dy <= yBottom + 10;
        if (!inBand) continue;
        minDistance = 0.0;
        closestIndex = i;
        closestPoint = Offset(x, yCenter);
        continue;
      }
      if (chartData[i]['bloodSugar'] == null) continue;
      if (inOverlapDataIndex.contains(i)) continue;

      late final double x;
      if (chartData[i]['xPosition'] != null) {
        final xPosition = chartData[i]['xPosition'] as double;
        x = leftPadding + (effectiveWidth * xPosition);
      } else if (chartData.length == 1) {
        x = leftPadding + effectiveWidth / 2;
      } else {
        x = leftPadding + (effectiveWidth * i / (chartData.length - 1));
      }

      final int bloodSugar = chartData[i]['bloodSugar'] as int;
      const double topPadding = 20.0;
      const double bottomPadding = 20.0;
      final clamped =
          bloodSugar.clamp(widget.yLabels.last.toInt(), widget.yLabels.first.toInt());
      final double normalizedValue =
          (widget.yLabels.first - clamped) / (widget.yLabels.first - widget.yLabels.last);
      final double y = topPadding +
          (chartHeight - topPadding - bottomPadding) * normalizedValue;
      considerPoint(
        x,
        y,
        i,
        maxDistanceSq: 20 * 20,
        xHitSlop: 20,
        yHitSlop: 20,
      );
    }

    if (closestIndex != null) {
      if (widget.selectedChartPointIndex == closestIndex) {
        widget.onSelectionChanged(null, null);
      } else {
        widget.onSelectionChanged(closestIndex, closestPoint);
      }
    } else {
      widget.onSelectionChanged(null, null);
    }
  }
}

Map<String, dynamic> _tooltipRowForChartIndex(
  List<Map<String, dynamic>> chartData,
  int index,
  double chartWidth,
  double chartHeight,
  double minValue,
  double maxValue,
) {
  if (index < 0) {
    final ci = -index - 1;
    final clusters = bloodSugarComputeWeekMonthOverlapClusters(
      chartData,
      Size(chartWidth, chartHeight),
      minValue,
      maxValue,
    );
    if (ci < 0 || ci >= clusters.length) {
      return chartData.isNotEmpty ? chartData[0] : {};
    }
    final raw = clusters[ci].dataIndices.map((di) {
      final row = chartData[di];
      return <String, dynamic>{
        'measurementType': row['measurementType']?.toString() ?? '',
        'bloodSugar': row['bloodSugar'],
        'record': row['record'],
        'date': row['date']?.toString() ?? '',
      };
    }).toList();
    raw.sort((a, b) => _tooltipMeasurementTypeOrder(
          a['measurementType'] as String?,
        ).compareTo(
          _tooltipMeasurementTypeOrder(b['measurementType'] as String?),
        ));
    final firstDi = clusters[ci].dataIndices.first;
    final firstRow = chartData[firstDi];
    final slotDate = raw.isNotEmpty ? (raw.first['date'] as String? ?? '') : '';
    return {
      'bloodSugarOverlapCluster': true,
      'overlapEntries': raw,
      'date': slotDate,
      'chartYear': firstRow['chartYear'],
      'record': firstRow['record'],
    };
  }
  if (index >= 0 && index < chartData.length) return chartData[index];
  return chartData.isNotEmpty ? chartData[0] : {};
}

Widget buildBloodSugarXAxisLabels({
  required String selectedPeriod,
  required DateTime selectedDate,
  required double timeOffset,
}) {
  if (selectedPeriod != '일') {
    return _buildBloodSugarPeriodXAxisLabels(
      selectedPeriod: selectedPeriod,
      selectedDate: selectedDate,
      timeOffset: timeOffset,
    );
  }

  const maxStartHour = 18;
  final startHour = (timeOffset * maxStartHour).clamp(0.0, 18.0).round();

  final hourLabels = <Widget>[];
  for (int i = 0; i < 7; i++) {
    final hour = (startHour + i).clamp(0, 24);
    final hourLabel = hour == 24 ? '24' : hour.toString().padLeft(2, '0');
    hourLabels.add(
      Text(
        hourLabel,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
    );
  }

  return _buildBloodSugarXAxisWithUnit(
    labelRow: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: hourLabels,
    ),
    unitText: '(시)',
  );
}

Widget _buildBloodSugarPeriodXAxisLabels({
  required String selectedPeriod,
  required DateTime selectedDate,
  required double timeOffset,
}) {
  if (selectedPeriod == '월') {
    const totalMonths = 12;
    const visibleMonths = 7;
    final maxStart = totalMonths - visibleMonths;
    final startIndex = (timeOffset * maxStart).round().clamp(0, maxStart);

    return _buildBloodSugarXAxisWithUnit(
      labelRow: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(visibleMonths, (i) {
          final m = startIndex + i + 1;
          return Expanded(
            child: Text(
              '$m',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          );
        }),
      ),
      unitText: '(월)',
    );
  }

  const days = 7;
  final endDate =
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  final startDate = endDate.subtract(Duration(days: days - 1));

  final allDateLabels = <String>[];
  for (int i = 0; i < days; i++) {
    final date = startDate.add(Duration(days: i));
    allDateLabels.add(DateFormat('M.d').format(date));
  }

  final dateRow = Row(
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

  return _buildBloodSugarXAxisWithUnit(
    labelRow: dateRow,
    unitText: '(일)',
  );
}

Widget _buildBloodSugarXAxisWithUnit({
  required Widget labelRow,
  required String unitText,
}) {
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Padding(
        padding: const EdgeInsets.only(
          right: ChartConstants.weightXAxisUnitReservedWidth,
        ),
        child: labelRow,
      ),
      Positioned(
        right: -10,
        top: 1,
        bottom: 0,
        child: Align(
          alignment: Alignment.center,
          child: Text(
            unitText,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    ],
  );
}

class _GlucoseSeriesLegend extends StatelessWidget {
  final Color color;
  final String label;
  final bool compact;

  const _GlucoseSeriesLegend({
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
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class BloodSugarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double minValue;
  final double maxValue;
  final List<double>? yLabels;
  final int? highlightedIndex;
  final bool isToday;
  final double timeOffset;
  final String selectedPeriod;

  BloodSugarChartPainter(
    this.data,
    this.minValue,
    this.maxValue, {
    this.yLabels,
    this.highlightedIndex,
    required this.isToday,
    required this.timeOffset,
    required this.selectedPeriod,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const double borderWidth = 0.5;
    const double pointRadius = 8;
    final x0 = borderWidth + pointRadius;
    final chartWidth = size.width -
        (borderWidth * 2) -
        (pointRadius * 2) -
        ChartConstants.weightXAxisUnitReservedWidth;

    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;
    final dashedGridPaint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 0.5;
    final yValues = (yLabels != null && yLabels!.length >= 2)
        ? yLabels!
        : [maxValue, minValue];

    for (int i = 0; i < yValues.length; i++) {
      const topPadding = 20.0;
      const bottomPadding = 20.0;
      final y = topPadding +
          (size.height - topPadding - bottomPadding) * i / (yValues.length - 1);
      canvas.drawLine(Offset(x0, y), Offset(x0 + chartWidth, y), gridPaint);
    }

    for (int i = 0; i < yValues.length - 1; i++) {
      final normalizedY = (i + 0.5) / (yValues.length - 1);
      const topPadding = 20.0;
      const bottomPadding = 20.0;
      final y =
          topPadding + (size.height - topPadding - bottomPadding) * normalizedY;
      for (double x = x0; x < x0 + chartWidth; x += 4) {
        canvas.drawLine(Offset(x, y), Offset(x + 2, y), dashedGridPaint);
      }
    }

    if (selectedPeriod == '일') {
      _paintDailySeries(canvas, size, x0, chartWidth);
    } else {
      _paintWeekMonthSeries(canvas, size, x0, chartWidth);
    }
  }

  static const double _plotTopPadding = 20.0;
  static const double _plotBottomPadding = 20.0;

  void _paintDailySeries(
    Canvas canvas,
    Size size,
    double x0,
    double chartWidth,
  ) {
    const maxStartHour = 18;
    final startHour =
        (timeOffset * maxStartHour).clamp(0, maxStartHour).round();
    final endHour = startHour + 6;
    final points = <Offset>[];
    final pointIndices = <int>[];
    final barPaint = Paint()..style = PaintingStyle.fill;
    const barWidth = 10.0;

    for (int i = 0; i < data.length; i++) {
      if (data[i]['hourSlotBar'] == true) {
        final minSugar = data[i]['minBloodSugar'] as int?;
        final maxSugar = data[i]['maxBloodSugar'] as int?;
        final recordHour = data[i]['hour'] as int?;
        if (minSugar == null || maxSugar == null || recordHour == null) continue;
        if (recordHour < startHour || recordHour > endHour) continue;
        final xPosition = (data[i]['xPosition'] as double?) ?? 0.5;
        final xCenter = x0 + (chartWidth * xPosition);
        final clampedMin = minSugar.clamp(minValue.toInt(), maxValue.toInt()).toDouble();
        final clampedMax = maxSugar.clamp(minValue.toInt(), maxValue.toInt()).toDouble();
        final minNorm = (maxValue - clampedMin) / (maxValue - minValue);
        final maxNorm = (maxValue - clampedMax) / (maxValue - minValue);
        final yMin = _plotTopPadding +
            (size.height - _plotTopPadding - _plotBottomPadding) * minNorm;
        final yMax = _plotTopPadding +
            (size.height - _plotTopPadding - _plotBottomPadding) * maxNorm;
        final yTop = math.min(yMin, yMax);
        final yBottom = math.max(yMin, yMax);
        final centerY = (yTop + yBottom) / 2;
        final barHeight = math.max(yBottom - yTop, 4.0);
        final isHighlighted = highlightedIndex != null && highlightedIndex == i;
        final barColor = data[i]['barColor'] is Color
            ? data[i]['barColor'] as Color
            : const Color(0xFFFF5A8D);
        barPaint.color = barColor;
        final w = isHighlighted ? barWidth + 3 : barWidth;
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(xCenter, centerY),
            width: w,
            height: barHeight,
          ),
          Radius.circular(w / 2),
        );
        canvas.drawRRect(rect, barPaint);
        if (isHighlighted) {
          canvas.drawRRect(
            rect,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
        continue;
      }
      if (data[i]['bloodSugar'] == null) continue;
      final recordHour = data[i]['hour'] as int?;
      if (recordHour != null &&
          (recordHour < startHour || recordHour > endHour)) {
        continue;
      }

      double x;
      if (data[i]['xPosition'] != null) {
        final xPosition = data[i]['xPosition'] as double;
        x = x0 + (chartWidth * xPosition);
      } else {
        x = data.length == 1
            ? x0 + chartWidth / 2
            : x0 + (chartWidth * i / (data.length - 1));
      }

      final bloodSugar = data[i]['bloodSugar'] as int;
      final clamped = bloodSugar.clamp(minValue.toInt(), maxValue.toInt()).toDouble();
      final normalized = (maxValue - clamped) / (maxValue - minValue);
      final y = _plotTopPadding +
          (size.height - _plotTopPadding - _plotBottomPadding) * normalized;

      points.add(Offset(x, y));
      pointIndices.add(i);
    }

    for (int i = 0; i < points.length; i++) {
      final originalIndex = pointIndices[i];
      final isHighlighted = highlightedIndex != null && highlightedIndex == originalIndex;
      final pointPaint = Paint()
        ..color = _seriesColorForDataIndex(originalIndex)
        ..style = PaintingStyle.fill;
      if (isHighlighted) {
        canvas.drawCircle(points[i], 8, pointPaint);
        canvas.drawCircle(
          points[i],
          8,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        canvas.drawCircle(points[i], 5, pointPaint);
      }
    }
  }

  /// 주/월: 측정유형별로 같은 유형의 점만 연결.
  /// 서로 다른 측정유형인데 점(반지름 5)이 원 면적 기준 1/3 이상 겹치면 흰 원+핑크 테두리+플러스 1개.
  void _paintWeekMonthSeries(
    Canvas canvas,
    Size size,
    double x0,
    double chartWidth,
  ) {
    final indices = <int>[];
    for (int i = 0; i < data.length; i++) {
      if (data[i]['bloodSugar'] != null) indices.add(i);
    }
    if (indices.isEmpty) return;

    final overlapRender = bloodSugarComputeWeekMonthOverlapClusters(
      data,
      size,
      minValue,
      maxValue,
    );

    double yForValue(int v) {
      final clamped = v.clamp(minValue.toInt(), maxValue.toInt()).toDouble();
      final normalized = (maxValue - clamped) / (maxValue - minValue);
      return _plotTopPadding +
          (size.height - _plotTopPadding - _plotBottomPadding) * normalized;
    }

    Offset offsetForIndex(int i) {
      final xPosition = data[i]['xPosition'] as double;
      final x = x0 + chartWidth * xPosition;
      final y = yForValue(data[i]['bloodSugar'] as int);
      return Offset(x, y);
    }

    final inOverlap = <int>{};
    for (final c in overlapRender) {
      for (final di in c.dataIndices) {
        inOverlap.add(di);
      }
    }

    final byType = <String, List<int>>{};
    for (final i in indices) {
      final t = data[i]['measurementType']?.toString() ?? '';
      byType.putIfAbsent(t, () => []).add(i);
    }

    final lineBase = Paint()
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final type in byType.keys) {
      final idxs = List<int>.from(byType[type]!);
      idxs.sort((a, b) {
        final sa = data[a]['slotIndex'];
        final sb = data[b]['slotIndex'];
        if (sa is int && sb is int && sa != sb) return sa.compareTo(sb);
        return a.compareTo(b);
      });
      if (idxs.length <= 1) continue;
      final c = _seriesColorForType(type);
      lineBase.color = c;
      for (int k = 0; k < idxs.length - 1; k++) {
        canvas.drawLine(
          offsetForIndex(idxs[k]),
          offsetForIndex(idxs[k + 1]),
          lineBase,
        );
      }
    }

    for (final i in indices) {
      if (inOverlap.contains(i)) continue;
      final o = offsetForIndex(i);
      final isHighlighted =
          highlightedIndex != null && highlightedIndex == i;
      final pointPaint = Paint()
        ..color = _seriesColorForDataIndex(i)
        ..style = PaintingStyle.fill;
      if (isHighlighted) {
        canvas.drawCircle(o, 8, pointPaint);
        canvas.drawCircle(
          o,
          8,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        canvas.drawCircle(o, 5, pointPaint);
      }
    }

    for (var ci = 0; ci < overlapRender.length; ci++) {
      final cluster = overlapRender[ci];
      final o = cluster.centroid;
      final clusterTapIndex = -(ci + 1);
      final highlighted = highlightedIndex != null &&
          (highlightedIndex == clusterTapIndex ||
              cluster.dataIndices.contains(highlightedIndex));
      final r = highlighted ? 8.0 : 5.0;
      canvas.drawCircle(
        o,
        r,
        Paint()..color = Colors.white..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        o,
        r,
        Paint()
          ..color = bloodSugarOverlapAccentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final arm = r * 0.45;
      final plus = Paint()
        ..color = bloodSugarOverlapAccentColor
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(o + Offset(-arm, 0), o + Offset(arm, 0), plus);
      canvas.drawLine(o + Offset(0, -arm), o + Offset(0, arm), plus);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  Color _seriesColorForDataIndex(int index) {
    if (index < 0 || index >= data.length) {
      return const Color(0xFFE91E63);
    }
    return _seriesColorForType(data[index]['measurementType']?.toString() ?? '');
  }

  Color _seriesColorForType(String type) {
    switch (type) {
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
}

class EmptyBloodSugarChartGridPainter extends CustomPainter {
  final List<double>? yLabels;
  final double minValue;
  final double maxValue;

  EmptyBloodSugarChartGridPainter({
    this.yLabels,
    this.minValue = 20,
    this.maxValue = 200,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const x0 = 8.5;
    final plotRight =
        size.width - ChartConstants.weightXAxisUnitReservedWidth - x0;
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;
    final dashedGridPaint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 0.5;
    final yValues = (yLabels != null && yLabels!.length >= 2)
        ? yLabels!
        : [maxValue, minValue];

    for (int i = 0; i < yValues.length; i++) {
      const topPadding = 20.0;
      const bottomPadding = 20.0;
      final y = topPadding +
          (size.height - topPadding - bottomPadding) * i / (yValues.length - 1);
      canvas.drawLine(Offset(x0, y), Offset(x0 + plotRight, y), gridPaint);
    }

    for (int i = 0; i < yValues.length - 1; i++) {
      final normalizedY = (i + 0.5) / (yValues.length - 1);
      const topPadding = 20.0;
      const bottomPadding = 20.0;
      final y =
          topPadding + (size.height - topPadding - bottomPadding) * normalizedY;
      for (double x = x0; x < x0 + plotRight; x += 4) {
        canvas.drawLine(Offset(x, y), Offset(x + 2, y), dashedGridPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
