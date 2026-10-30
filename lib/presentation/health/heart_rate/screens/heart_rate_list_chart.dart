part of 'heart_rate_list_screen.dart';

extension _HeartRateListChart on _HeartRateListScreenState {
  Widget _buildChart({
    bool showExpandButton = true,
    bool chartPeriodTabsInCard = true,
    double chartHeight = ChartConstants.weightChartHeight,
  }) {
    final forExpandedChart = !chartPeriodTabsInCard && !showExpandButton;
    final yLabels = getYAxisLabels(forExpandedChart: forExpandedChart);

    Widget chartBody;
    if (selectedPeriod != '일') {
      chartBody = HeartRateChartWidget(
        chartData: getChartData(),
        yLabels: yLabels,
        selectedPeriod: selectedPeriod,
        selectedDate: selectedDate,
        timeOffset: timeOffset,
        height: chartHeight,
        onTimeOffsetChanged: (newOffset) {
          _setChartState(() => timeOffset = newOffset);
        },
        onTooltipChanged: (index, position) {
          if (!mounted) return;
          _setChartState(() {
            selectedChartPointIndex = index;
            tooltipPosition = position;
          });
        },
        selectedChartPointIndex: selectedChartPointIndex,
        tooltipPosition: tooltipPosition,
        yAxisCount: yLabels.length,
        useCalendarYearMonths: selectedPeriod == '월',
        showPeriodSelector: chartPeriodTabsInCard,
        onPeriodChanged: chartPeriodTabsInCard ? _handlePeriodChanged : null,
        cardBackgroundColor: Colors.white,
        forExpandedChart: !chartPeriodTabsInCard && !showExpandButton,
      );
    } else if (_recordsForSelectedDate().isEmpty) {
      chartBody = HealthDailyNoDataChartCard(
        chartHeight: chartHeight,
        title: '해당 기간에 심박수 기록이 없습니다',
        subtitle: '심박수를 측정해보세요',
        header: chartPeriodTabsInCard
            ? HealthPeriodSelector(
                selectedPeriod: selectedPeriod,
                onChanged: _handlePeriodChanged,
                plainStyle: true,
              )
            : null,
        showBorder: chartPeriodTabsInCard,
      );
    } else {
      chartBody = _buildDailyChart(
        yLabels,
        chartPeriodTabsInCard: chartPeriodTabsInCard,
        chartHeight: chartHeight,
        forExpandedChart: !chartPeriodTabsInCard && !showExpandButton,
      );
    }

    if (!showExpandButton) return chartBody;

    final showYHeader = yLabels.length > 1;
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
        chartBody,
        Positioned(
          right: healthChartCardPadding(context).right,
          top: topExpand,
          child: HealthChartExpandControl(
            onTap: _openExpandedChartPage,
            iconSize: iconSize,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyChart(
    List<double> yLabels, {
    required bool chartPeriodTabsInCard,
    double chartHeight = ChartConstants.weightChartHeight,
    bool forExpandedChart = false,
  }) {
    final dailyVisuals =
        _buildDailyHeartVisuals(forExpandedChart: forExpandedChart);
    final chartMinBpm = forExpandedChart ? 20.0 : 50.0;
    final chartMaxBpm = forExpandedChart ? 200.0 : 250.0;
    final topPad = healthWeightChartVertPad(context);
    final botPad = healthWeightChartBottomPlotPad(context);
    final xAxisLabelHeight =
        forExpandedChart ? healthDp(context, 14.23) : healthDp(context, 30);
    return Container(
      height: chartHeight,
      padding:
          forExpandedChart ? EdgeInsets.zero : healthChartCardPadding(context),
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
          if (chartPeriodTabsInCard) ...[
            HealthPeriodSelector(
              selectedPeriod: selectedPeriod,
              onChanged: _handlePeriodChanged,
              plainStyle: true,
            ),
            SizedBox(
                height:
                    healthDp(context, ChartConstants.weightChartTabToPlotGap)),
          ],
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showYHeader = yLabels.length > 1;
                final headerBand = showYHeader
                    ? bloodPressureYAxisUnitBandHeight(context)
                    : 0.0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildBloodPressureYAxisStrip(
                      yLabels: yLabels,
                      showYAxisHeader: showYHeader,
                      unitLabel: '(bpm)',
                    ),
                    SizedBox(
                        width: healthDp(
                            context, ChartConstants.weightChartYAxisPlotGap)),
                    Expanded(
                      child: ColoredBox(
                        color: Colors.white,
                        child: Column(
                          children: [
                            if (showYHeader) SizedBox(height: headerBand),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, inner) {
                                  final w = inner.maxWidth;
                                  final h = inner.maxHeight;
                                  if (w <= 0 || h <= 0) {
                                    return const SizedBox.shrink();
                                  }
                                  final tooltipPad = healthDp(context, 6);
                                  final tooltipLift = healthDp(context, 92);
                                  final tooltipBottomReserve =
                                      healthDp(context, 110);
                                  final tooltipMinW = healthDp(context, 88);
                                  final tooltipMaxWCap = healthDp(context, 240);
                                  Widget? dailyTooltipOverlay;
                                  if (_dailyChartTooltip != null) {
                                    final double anchorLeft =
                                        _dailyChartTooltip!.chartLocal.dx
                                            .clamp(
                                              tooltipPad,
                                              math.max(
                                                tooltipPad,
                                                w - tooltipPad,
                                              ),
                                            )
                                            .toDouble();

                                    /// [HeartRateTooltip._positionedCard]와 동일
                                    final double maxTooltipW =
                                        (w - anchorLeft - tooltipPad)
                                            .clamp(
                                              tooltipMinW,
                                              tooltipMaxWCap,
                                            )
                                            .toDouble();
                                    final double topY =
                                        (_dailyChartTooltip!.chartLocal.dy -
                                                tooltipLift)
                                            .clamp(
                                              tooltipPad,
                                              math.max(
                                                tooltipPad,
                                                h -
                                                    tooltipBottomReserve -
                                                    tooltipPad,
                                              ),
                                            )
                                            .toDouble();
                                    dailyTooltipOverlay = Positioned(
                                      left: anchorLeft,
                                      top: topY,
                                      child: FractionalTranslation(
                                        translation: const Offset(-0.5, 0),
                                        child: Material(
                                          type: MaterialType.transparency,
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              minWidth: tooltipMinW,
                                              maxWidth: maxTooltipW,
                                            ),
                                            child: _buildDailyTooltipBubble(
                                              _dailyChartTooltip!,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      GestureDetector(
                                        behavior: HitTestBehavior.translucent,
                                        onTapDown: (details) {
                                          _handleDailyChartTap(
                                            details.localPosition,
                                            Size(w, h),
                                            dailyVisuals,
                                            forExpandedChart: forExpandedChart,
                                          );
                                        },
                                        onPanStart: (selectedPeriod == '일' ||
                                                selectedPeriod == '월')
                                            ? (details) {
                                                _setChartState(
                                                  () =>
                                                      _dailyChartTooltip = null,
                                                );
                                                _dragStartX =
                                                    details.localPosition.dx;
                                              }
                                            : null,
                                        onPanUpdate: (selectedPeriod == '일' ||
                                                selectedPeriod == '월')
                                            ? (details) {
                                                if (_dragStartX != null) {
                                                  final deltaX =
                                                      details.localPosition.dx -
                                                          _dragStartX!;
                                                  _handleDragUpdate(
                                                    deltaX,
                                                    w,
                                                    forExpandedChart:
                                                        forExpandedChart,
                                                  );
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
                                            visuals: dailyVisuals,
                                            minValue: chartMinBpm,
                                            maxValue: chartMaxBpm,
                                            topPlotPad: topPad,
                                            bottomPlotPad: botPad,
                                            scale: healthTextScaleByWidth(
                                                MediaQuery.of(context)
                                                    .size
                                                    .width),
                                            xUnitReservedWidth: healthDp(
                                              context,
                                              ChartConstants
                                                  .weightXAxisUnitReservedWidth,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (dailyTooltipOverlay != null)
                                        dailyTooltipOverlay,
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(
            height: xAxisLabelHeight,
            child: Padding(
              padding: EdgeInsets.only(
                left: healthDp(
                  context,
                  ChartConstants.weightChartYAxisStripWidth,
                ),
              ),
              child: buildHeartRateXAxisLabels(
                context: context,
                selectedPeriod: '일',
                selectedDate: selectedDate,
                timeOffset: timeOffset,
                forExpandedChart: forExpandedChart,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
