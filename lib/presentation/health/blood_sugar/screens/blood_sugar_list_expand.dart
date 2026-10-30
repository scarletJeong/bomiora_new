part of 'blood_sugar_list_screen.dart';

extension _BloodSugarListExpand on _BloodSugarListScreenState {
  Future<void> _openExpandedChartPage() async {
    var expandedPeriod = selectedPeriod;
    var expandedTimeOffset = timeOffset;
    var expandedSelectedChartPointIndex = selectedChartPointIndex;
    var expandedTooltipPosition = tooltipPosition;
    var expandedMeasurementFilter = selectedMeasurementFilter;

    double monthlyOffsetForSelectedDate() =>
        healthMonthlyTimeOffsetForSelectedMonth(
          selectedDate.month,
          forExpandedChart: true,
        );

    double dailyInitialOffset() {
      if (!_isToday()) return 0.0;
      return healthDailyTimeOffsetForToday(forExpandedChart: true);
    }

    void refreshExpanded() => _refreshExpandedChart?.call();

    await openHealthChartExpandPage(
      context: context,
      periodSelectorBuilder: (ctx) => HealthExpandedPeriodSelector(
        metrics: healthExpandedMetrics(ctx),
        selectedPeriod: expandedPeriod,
        onChanged: (period) {
          expandedPeriod = period;
          expandedSelectedChartPointIndex = null;
          expandedTooltipPosition = null;
          if (period == '월') {
            expandedTimeOffset = monthlyOffsetForSelectedDate();
          } else if (period == '일') {
            expandedTimeOffset = dailyInitialOffset();
          } else {
            expandedTimeOffset = 0.0;
          }
          refreshExpanded();
        },
      ),
      legendBuilder: (ctx) {
        final m = healthExpandedMetrics(ctx);
        final gap = m.d(17.62);
        const legends = [
          (Color(0xFF4F82E0), '공복'),
          (Color(0xFFFC8B3A), '식전'),
          (Color(0xFF38B769), '식후'),
          (Color(0xFF4FD1E0), '취침전'),
          (Color(0xFFB24FE0), '평상시'),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: m.d(8.81),
          children: [
            for (final e in legends)
              HealthExpandedChartLegendItem(
                metrics: m,
                color: e.$1,
                label: e.$2,
              ),
          ],
        );
      },
      chartBuilder: (_) {
        final base = Theme.of(context);
        final gmarket = base.copyWith(
          textTheme: base.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
          primaryTextTheme:
              base.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            final scaledChartCap = healthExpandedMetrics(context)
                .d(HealthExpandedChartMetrics.chartHeightWithLegend);
            final scaledChartMin = healthDp(context, 160);
            final safeHeight = ChartConstants.healthExpandedChartHeight(
              constraints.maxHeight,
              bottomLegendReserve: 0,
              maxChartHeight: scaledChartCap,
              minChartHeight: scaledChartMin,
            );
            final expandScale =
                healthTextScaleByWidth(MediaQuery.of(context).size.width);
            return Theme(
              data: gmarket,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(expandScale),
                ),
                child: BloodSugarChartSection(
                  selectedPeriod: expandedPeriod,
                  selectedDate: selectedDate,
                  timeOffset: expandedTimeOffset,
                  selectedChartPointIndex: expandedSelectedChartPointIndex,
                  tooltipPosition: expandedTooltipPosition,
                  isToday: _isToday(),
                  chartData: getChartData(
                    period: expandedPeriod,
                    offset: expandedTimeOffset,
                    forExpandedChart: true,
                  ),
                  yLabels: getYAxisLabelsExpanded(),
                  hasActualDailyData: (dailyRecordsCache[
                              DateFormat('yyyy-MM-dd').format(selectedDate)] ??
                          [])
                      .isNotEmpty,
                  showPeriodSelector: false,
                  showLegend: false,
                  forExpandedChart: true,
                  showExpandButton: false,
                  selectedMeasurementFilter: expandedMeasurementFilter,
                  onMeasurementFilterChanged: (value) {
                    expandedMeasurementFilter = value;
                    expandedSelectedChartPointIndex = null;
                    expandedTooltipPosition = null;
                    refreshExpanded();
                  },
                  chartHeight: safeHeight,
                  onDragUpdate: (deltaX, chartWidth) {
                    final sensitivity =
                        _getDragSensitivity(period: expandedPeriod);
                    final dataDelta = -(deltaX / chartWidth) * sensitivity;
                    expandedTimeOffset = _clampDragOffset(
                      expandedTimeOffset + dataDelta,
                      period: expandedPeriod,
                      forExpandedChart: true,
                    );
                    expandedSelectedChartPointIndex = null;
                    expandedTooltipPosition = null;
                    refreshExpanded();
                  },
                  onSelectionChanged: (index, position) {
                    expandedSelectedChartPointIndex = index;
                    expandedTooltipPosition = position;
                    refreshExpanded();
                  },
                ),
              ),
            );
          },
        );
      },
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
            buildTrailing: (ctx) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${record.bloodSugar}',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: const Color(0xFF1A1A1A),
                    fontSize: healthSp(ctx, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: healthDp(ctx, 8)),
                SizedBox(
                  width: _sugarMeasurementTypeBadgeWidth(ctx),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(ctx, 3),
                      vertical: healthDp(ctx, 3),
                    ),
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: _sugarStatusBadgeColor(record),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(healthDp(ctx, 4)),
                      ),
                    ),
                    child: Text(
                      record.measurementType,
                      textAlign: TextAlign.center,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: const Color(0xFF1A1A1A),
                        fontSize: healthSp(ctx, 10),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        letterSpacing: healthDp(ctx, -0.3),
                      ),
                    ),
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

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BloodSugarInputScreen(record: selected),
      ),
    );
  }

  /// 바텀시트 측정 유형 배지 너비 — 3글자(취침전) 기준, 식후·공복 등 2글자도 동일 폭.
  double _sugarMeasurementTypeBadgeWidth(BuildContext context) {
    final style = TextStyle(
      fontSize: healthSp(context, 10),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w500,
      letterSpacing: healthDp(context, -0.3),
    );
    final painter = TextPainter(
      text: TextSpan(text: '취침전', style: style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    return painter.width + healthDp(context, 6);
  }

  /// 수정 바텀시트·상태 배지. 목록 헤더와 같은 판정.
  Color _sugarStatusBadgeColor(BloodSugarRecord record) {
    return HealthVitalStatus.background(HealthVitalStatus.bloodSugar(record));
  }
}
