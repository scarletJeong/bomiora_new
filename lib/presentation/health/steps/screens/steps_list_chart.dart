part of 'steps_list_screen.dart';

extension _StepsListChart on _StepsTodayScreenState {
  Widget _buildTotalStepsCard() {
    final totalSteps = todayStepsRecord?.totalSteps ?? 0;
    final int? goalSteps = latestHealthGoal?.dailyStepGoal;
    final ratio = (goalSteps == null || goalSteps <= 0)
        ? 0.0
        : (totalSteps / goalSteps).clamp(0.0, 1.0);
    final diff = todayStepsRecord?.stepsDifference ??
        stepsStatistics?.stepsDifference ??
        0;
    final diffUp = diff > 0;

    // 링 지름 375 기준 188 — CustomPaint도 동일 크기
    final ringSize = healthDp(context, 188);
    final ringScale =
        healthTextScaleByWidth(MediaQuery.sizeOf(context).width);
    final strokeW = 18 * ringScale;
    return Container(
      padding: EdgeInsets.only(left: healthDp(context, 16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Expanded 안에 두면 flex 3/5 폭(~173dp)에 링이 갇혀 실제로는 안 커짐
              Transform.translate(
                offset: Offset(-healthDp(context, 18), 0),
                child: SizedBox(
                  width: ringSize,
                  height: ringSize,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      CustomPaint(
                        size: Size(ringSize, ringSize),
                        painter: _StepsGoalRingPainter(
                          progress: ratio,
                          trackColor: const Color(0x7FD9D9D9),
                          progressColor: const Color(0xFFFF5A8D),
                          strokeWidth: strokeW,
                          progressStrokeWidth: strokeW,
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(0, -healthDp(context, 4)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '총 걸음 수',
                              style: TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontSize: 20,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            SizedBox(height: healthDp(context, 2)),
                            Text(
                              '$totalSteps',
                              style: const TextStyle(
                                color: Color(0xFFFF5A8D),
                                fontSize: 32,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          '목표 걸음수',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: const Color(0xFF1A1A1A),
                            fontSize: healthSp(context, 20),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: healthDp(context, 5)),
                    Text(
                      goalSteps != null ? '$goalSteps' : '-',
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 20,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: healthDp(context, 20)),
                    const Text(
                      '전날 대비',
                      style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 20,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    SizedBox(height: healthDp(context, 6)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (diff == 0)
                          const Text(
                            '-',
                            style: TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 20,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        else ...[
                          Text(
                            NumberFormat('#,###').format(diff.abs()),
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 20,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: healthDp(context, 4)),
                          SizedBox(
                            width: healthDp(context, 16),
                            height: healthDp(context, 16),
                            child: SvgPicture.asset(
                              diffUp
                                  ? AppAssets.stepsUp
                                  : AppAssets.stepsDown,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String unitSmall,
    required String iconAsset,
    required String value,
    required String valueUnit,
  }) {
    return SizedBox(
      height: healthDp(context, 85),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 10),
          vertical: healthDp(context, 8),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
          border: Border.all(
            width: healthDp(context, 0.5),
            color: const Color(0xFFD9D9D9),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          height: 1.0,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      Text(
                        unitSmall,
                        style: const TextStyle(
                          color: Color(0xFF898686),
                          fontSize: 10,
                          height: 1.0,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: healthDp(context, 30),
                  height: healthDp(context, 30),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF2F8),
                    borderRadius: BorderRadius.circular(healthDp(context, 9999)),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      iconAsset,
                      width: healthDp(context, 16),
                      height: healthDp(context, 16),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFFFF5A8D),
                    fontSize: 20,
                    height: 1.0,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: healthDp(context, 5)),
                Text(
                  valueUnit,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 12,
                    height: 1.0,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({
    bool showExpandButton = true,
    bool chartPeriodTabsInCard = true,
    bool forExpandedChart = false,
    double? chartHeight,
  }) {
    final h =
        chartHeight ?? healthDp(context, ChartConstants.weightChartHeight);
    final showYHeader = _buildYAxisTicks().length > 1;
    final headerBand =
        showYHeader ? bloodPressureYAxisUnitBandHeight(context) : 0.0;
    final padTop = healthChartCardPadding(context).top;
    final tabH =
        healthDp(context, ChartConstants.weightChartPeriodTabBarHeight);
    final gap = healthDp(context, ChartConstants.weightChartTabToPlotGap);
    final iconSize = healthDp(context, 20);
    final expandH = HealthChartExpandControl.blockHeight(context, iconSize);
    final topExpand = chartPeriodTabsInCard
        ? padTop + tabH + gap + headerBand / 2 - expandH / 2
        : padTop + headerBand / 2 - expandH / 2;

    return Stack(
      children: [
        Container(
          height: h,
          padding: forExpandedChart
              ? EdgeInsets.zero
              : healthChartCardPadding(context),
          decoration: forExpandedChart
              ? null
              : BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(healthDp(context, 12)),
                  border: Border.all(color: Colors.grey[200]!),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (chartPeriodTabsInCard && !forExpandedChart) ...[
                HealthPeriodSelector(
                  selectedPeriod: selectedPeriod,
                  onChanged: (period) {
                    _setState(() {
                      selectedPeriod = period;
                      if (period == '일') {
                        timeOffset =
                            _isToday() ? _defaultDailyTimeOffset() : 0.0;
                      } else if (period == '월') {
                        timeOffset = 0.0;
                      } else {
                        timeOffset = 0.0;
                      }
                    });
                    _notifyExpandedChart();
                  },
                  plainStyle: true,
                ),
                SizedBox(
                    height: healthDp(
                        context, ChartConstants.weightChartTabToPlotGap)),
              ],
              Expanded(
                child: _buildBarChartPlotArea(
                  forExpandedChart: forExpandedChart,
                ),
              ),
              SizedBox(
                height: forExpandedChart
                    ? healthDp(context, 30)
                    : healthDp(context, 30),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: healthDp(
                      context,
                      ChartConstants.weightChartYAxisStripWidth,
                    ),
                  ),
                  child: _buildXAxisLabelRow(
                    context,
                    _buildXAxisLabels(
                      forExpandedChart: forExpandedChart,
                    ),
                    forExpandedChart: forExpandedChart,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showExpandButton)
          Positioned(
            top: topExpand,
            right: healthChartCardPadding(context).right,
            child: HealthChartExpandControl(
              onTap: _openExpandedChartPage,
              iconSize: iconSize,
            ),
          ),
      ],
    );
  }

  Widget _buildBarChartPlotArea({bool forExpandedChart = false}) {
    final data = _buildPeriodChartData();
    final maxValue = _chartMaxValue();
    final yTicks = _buildYAxisTicks();
    final yTickDoubles = yTicks.map((e) => e.toDouble()).toList();
    final showYHeader = yTickDoubles.length > 1;
    final headerBand =
        showYHeader ? bloodPressureYAxisUnitBandHeight(context) : 0.0;
    final ySpacing = healthDp(context, ChartConstants.weightChartYAxisPlotGap);
    final chartScale =
        healthTextScaleByWidth(MediaQuery.sizeOf(context).width);
    final chartMetrics = HealthChartMetrics(chartScale);
    // 막대 width: Painter에서 375 기준 5 × [chartScale] (일·주·월 동일)
    final xUnitReserved = healthDp(
      context,
      ChartConstants.weightXAxisUnitReservedWidth,
    );
    final chartPadTop = healthWeightChartVertPad(context);
    final chartPadBottom = healthWeightChartBottomPlotPad(context);
    final barCornerR = math.min(
      _StepsBarChartPainter.barWidthFor(scale: chartScale) / 2,
      healthDp(context, 10),
    );

    final visibleData =
        _buildVisibleChartData(data, forExpandedChart: forExpandedChart);
    final forceWhiteBg = selectedPeriod == '일' || selectedPeriod == '월';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildBloodPressureYAxisStrip(
          yLabels: yTickDoubles,
          showYAxisHeader: showYHeader,
          unitLabel: _yAxisUnitLabel(),
          tickFontSize: selectedPeriod == '일' ||
                  (forExpandedChart &&
                      (selectedPeriod == '주' || selectedPeriod == '월'))
              ? 12
              : 10,
        ),
        SizedBox(width: ySpacing),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showYHeader) SizedBox(height: headerBand),
              Expanded(
                child: ColoredBox(
                  color: forceWhiteBg ? Colors.white : Colors.transparent,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _clearTooltip,
                    child: LayoutBuilder(
                      builder: (context, plotConstraints) {
                        final plotW = plotConstraints.maxWidth;
                        final plotH = plotConstraints.maxHeight;

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) {
                            if (visibleData.isEmpty) return;
                            final localX =
                                d.localPosition.dx.clamp(0.0, plotW);
                            final idx = _hitVisibleBarIndex(
                              localX,
                              visibleData.length,
                              plotW,
                              chartScale,
                              xUnitReserved,
                              forExpandedChart: forExpandedChart,
                            );
                            if (visibleData[idx].value <= 0) {
                              _setState(() {
                                _tooltipIndex = null;
                                _tooltipPosition = null;
                              });
                              return;
                            }
                            _setState(() {
                              _tooltipIndex = idx;
                              _tooltipPosition = Offset(
                                _visibleBarCenterX(
                                  idx,
                                  visibleData.length,
                                  plotW,
                                  chartScale,
                                  xUnitReserved,
                                  forExpandedChart: forExpandedChart,
                                ),
                                healthDp(context, 30),
                              );
                            });
                          },
                          onPanUpdate: selectedPeriod == '일' ||
                                  selectedPeriod == '월'
                              ? (details) {
                                  final next = timeOffset -
                                      (details.delta.dx /
                                              math.max(plotW, 1)) *
                                          (selectedPeriod == '일' ? 2.4 : 1.8);
                                  _setState(() {
                                    timeOffset = _clampTimeOffset(
                                      next,
                                      forExpandedChart: forExpandedChart,
                                    );
                                  });
                                  _notifyExpandedChart();
                                }
                              : null,
                          child: Stack(
                            children: [
                              CustomPaint(
                                painter: _StepsBarChartPainter(
                                  data: visibleData,
                                  maxValue: maxValue,
                                  yTickCount: yTicks.length,
                                  isDailyHalfHour: selectedPeriod == '일',
                                  scale: chartScale,
                                  xUnitReservedWidth: xUnitReserved,
                                  topPadding: chartPadTop,
                                  bottomPadding: chartPadBottom,
                                  dailyStartSlot: selectedPeriod == '일'
                                      ? _dailyStartSlot(
                                          forExpandedChart: forExpandedChart,
                                        )
                                      : 0,
                                  barCornerRadius: barCornerR,
                                  gridStrokeWidth: chartMetrics.gridStroke,
                                ),
                                size: Size(plotW, plotH),
                              ),
                              StepsChartTooltip(
                                selectedPeriod: selectedPeriod,
                                data: _tooltipDataForVisible(
                                  visibleData: visibleData,
                                  visibleIndex: _tooltipIndex,
                                ),
                                tooltipPosition: _tooltipPosition,
                                chartWidth: plotW,
                                chartHeight: plotH,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _tooltipDataForVisible({
    required List<_StepsBarData> visibleData,
    required int? visibleIndex,
  }) {
    if (visibleIndex == null ||
        visibleIndex < 0 ||
        visibleIndex >= visibleData.length) {
      return const {};
    }
    final bar = visibleData[visibleIndex];
    final steps = bar.value;
    if (steps <= 0) return const {};

    if (selectedPeriod == '일') {
      final parts = bar.label.split(':');
      final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
      final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
      return {
        'slotHour': hour,
        'slotMinute': minute,
        'steps': steps,
      };
    }

    if (selectedPeriod == '주') {
      final end =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final start = end.subtract(const Duration(days: 6));
      final d = start.add(Duration(days: visibleIndex));
      return {
        'slotDate': d,
        'steps': steps,
      };
    }

    final month = int.tryParse(bar.label) ?? 1;
    return {
      'slotYear': selectedDate.year,
      'slotMonth': month,
      'steps': steps,
    };
  }

  int _hitVisibleBarIndex(
    double localX,
    int visibleLength,
    double plotWidth,
    double scale,
    double xUnitReservedWidth, {
    bool forExpandedChart = false,
  }) {
    if (visibleLength <= 1) return 0;
    if (selectedPeriod == '일') {
      final startParity =
          _dailyStartSlot(forExpandedChart: forExpandedChart).isOdd ? 1 : 0;
      final relHalf = _stepsDailyRelHalfFromLocalX(
        localX,
        plotWidth,
        scale: scale,
        xUnitReservedWidth: xUnitReservedWidth,
      );
      return (relHalf - startParity).round().clamp(0, visibleLength - 1);
    }
    final plotW = _stepsWeekMonthPlotWidth(
      plotWidth,
      xUnitReservedWidth: xUnitReservedWidth,
    );
    final barW = _StepsBarChartPainter.barWidthFor(scale: scale);
    final halfW = math.max(barW / 2 + healthDp(context, 4), 8.0);
    var best = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < visibleLength; i++) {
      final cx = _stepsWeekMonthSlotCenterX(
        index: i,
        slotCount: visibleLength,
        plotContentWidth: plotW,
      );
      final d = (localX - cx).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    if (bestDist <= halfW) return best;
    return (localX / math.max(plotW, 1) * visibleLength)
        .floor()
        .clamp(0, visibleLength - 1);
  }

  double _visibleBarCenterX(
    int index,
    int visibleLength,
    double plotWidth,
    double scale,
    double xUnitReservedWidth, {
    bool forExpandedChart = false,
  }) {
    return _stepsBarSlotCenterX(
      index: index,
      slotCount: visibleLength,
      plotWidth: plotWidth,
      scale: scale,
      xUnitReservedWidth: xUnitReservedWidth,
      isDailyHalfHour: selectedPeriod == '일',
      dailyStartSlot: _dailyStartSlot(
        forExpandedChart: forExpandedChart,
      ),
    );
  }

  List<_StepsBarData> _buildPeriodChartData() {
    if (selectedPeriod == '일') {
      final raw = todayStepsRecord?.halfHourSteps ?? const <int>[];
      return List<_StepsBarData>.generate(48, (i) {
        final hour = i ~/ 2;
        final minute = i.isEven ? '00' : '30';
        final value = i < raw.length ? raw[i] : 0;
        return _StepsBarData(label: '$hour:$minute', value: value);
      });
    }

    if (selectedPeriod == '주') {
      final end =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final start = end.subtract(const Duration(days: 6));
      return List<_StepsBarData>.generate(7, (i) {
        final d = start.add(Duration(days: i));
        final key =
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        return _StepsBarData(
          label: '${d.day}',
          value: weekStepsByDate[key] ?? 0,
        );
      });
    }

    return List<_StepsBarData>.generate(
      12,
      (i) => _StepsBarData(
        label: '${i + 1}',
        value: i < monthSteps12.length ? monthSteps12[i] : 0,
      ),
    );
  }

  int _chartMaxValue() {
    // 요청 스케일 고정
    // - 시간대별(일): 0~5,000 (1,000 단위)
    // - 일자별(주): 0~50,000 (10,000 단위)
    // - 월별(월): 0~500,000 (100,000 단위)
    if (selectedPeriod == '일') return 5000;
    if (selectedPeriod == '주') return 50000;
    return 500000;
  }

  List<int> _buildYAxisTicks() {
    final cap = _chartMaxValue();
    final step = (cap / 5).round();
    return List<int>.generate(5, (i) => cap - (step * i));
  }

  String _yAxisUnitLabel() => '(보)';

  List<String> _buildXAxisLabels({bool forExpandedChart = false}) {
    if (selectedPeriod == '일') {
      final startIndex = _dailyStartSlot(forExpandedChart: forExpandedChart);
      final labelCount = forExpandedChart ? 12 : 7;
      return List<String>.generate(labelCount, (i) {
        final hour = ((startIndex + (i * 2)) ~/ 2).toString().padLeft(2, '0');
        return hour;
      });
    }
    if (selectedPeriod == '월') {
      final visibleMonths = healthMonthlySlotCount(forExpandedChart);
      final maxStart = healthMonthlyMaxStartIndex(forExpandedChart);
      final startIndex = (timeOffset * maxStart).round().clamp(0, maxStart);
      return List<String>.generate(
          visibleMonths, (i) => '${startIndex + i + 1}');
    }
    return _buildPeriodChartData().map((item) => item.label).toList();
  }

  List<_StepsBarData> _buildVisibleChartData(
    List<_StepsBarData> data, {
    bool forExpandedChart = false,
  }) {
    if (selectedPeriod == '일') {
      final visibleSlots = _dailyVisibleSlots(forExpandedChart: forExpandedChart);
      final startIndex = _dailyStartSlot(forExpandedChart: forExpandedChart);
      return data.sublist(startIndex, startIndex + visibleSlots);
    }
    if (selectedPeriod == '월') {
      final visibleMonths = healthMonthlySlotCount(forExpandedChart);
      final maxStart = data.length - visibleMonths;
      final startIndex = (timeOffset * maxStart).round().clamp(0, maxStart);
      return data.sublist(startIndex, startIndex + visibleMonths);
    }
    return data;
  }

  int _dailyStartSlot({bool forExpandedChart = false}) {
    final maxStart = _dailyMaxStartSlot(forExpandedChart: forExpandedChart);
    return (timeOffset * maxStart).round().clamp(0, maxStart);
  }

  Widget _buildXAxisLabelRow(
    BuildContext context,
    List<String> labels, {
    bool forExpandedChart = false,
  }) {
    final unit = selectedPeriod == '일'
        ? '(시)'
        : selectedPeriod == '주'
            ? '(일)'
            : '(월)';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selDay =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final isTodaySel = selDay == today;
    final currentHour = now.hour;

    late final List<Widget> rowChildren;
    if (selectedPeriod == '일') {
      final startIndex = _dailyStartSlot(forExpandedChart: forExpandedChart);
      final labelCount = forExpandedChart ? 12 : 7;
      rowChildren = List.generate(labelCount, (i) {
        final hour = (startIndex + (i * 2)) ~/ 2;
        final hourLabel = hour.toString().padLeft(2, '0');
        final isCurrent = isTodaySel && hour == currentHour;
        return Expanded(
          child: Center(
            child: Text(
              hourLabel,
              style: healthChartAxisTickTextStyle(
                context,
                color: isCurrent ? healthChartAxisCurrentHourColor : null,
              ),
            ),
          ),
        );
      });
    } else {
      rowChildren = labels
          .map(
            (label) => Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: healthChartAxisTickTextStyle(context),
              ),
            ),
          )
          .toList();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(
            right: healthDp(
              context,
              ChartConstants.weightXAxisUnitReservedWidth,
            ),
          ),
          child: Row(children: rowChildren),
        ),
        Positioned(
          right: -healthDp(context, 10),
          top: 1,
          bottom: 0,
          child: Align(
            alignment: Alignment.center,
            child: Text(
              unit,
              style: healthChartAxisUnitTextStyle(context),
            ),
          ),
        ),
      ],
    );
  }
}
