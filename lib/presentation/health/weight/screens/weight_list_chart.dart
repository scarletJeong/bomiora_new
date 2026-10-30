part of 'weight_list_screen.dart';

extension _WeightListChart on _WeightListScreenState {
  // 4. 기간 선택 버튼
  Widget _buildPeriodButtons({bool plainStyle = false}) {
    return HealthPeriodSelector(
      selectedPeriod: selectedPeriod,
      plainStyle: plainStyle,
      onChanged: (period) {
        _setState(() {
          selectedPeriod = period;
          selectedChartPointIndex = null;
          tooltipPosition = null;

          if (period == '월') {
            timeOffset = 0.0;
          } else if (period == '주') {
            timeOffset = 0.0;
          } else if (period == '일') {
            timeOffset = _dailyOffsetForDate(selectedDate);
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
    double? chartHeight,
    bool expandedChartView = false,
  }) {
    final resolvedChartHeight =
        chartHeight ?? healthDp(context, ChartConstants.weightChartHeight);
    final chartData = getChartData(forExpandedChart: expandedChartView);
    final yLabels =
        expandedChartView ? getYAxisLabelsExpanded() : getYAxisLabelsMain();
    final periodTabs = expandedChartView
        ? const SizedBox.shrink()
        : _buildPeriodButtons(plainStyle: true);
    return WeightChartContent(
      selectedPeriod: selectedPeriod,
      chartData: chartData,
      yLabels: yLabels,
      hasActualDailyData: _hasWeightRecordsOnSelectedDate(),
      chartHeight: resolvedChartHeight,
      showExpandButton: showExpandButton,
      onExpand: _openExpandedChartPage,
      periodSelector: periodTabs,
      dataChartBuilder: (height, tabs) => WeightDataChart(
        selectedPeriod: selectedPeriod,
        chartData: chartData,
        yLabels: yLabels,
        selectedChartPointIndex: selectedChartPointIndex,
        tooltipPosition: tooltipPosition,
        chartHeight: height,
        timeOffset: timeOffset,
        selectedDate: selectedDate,
        periodSelector: tabs,
        forExpandedChart: expandedChartView,
        showYAxisKgHeader: true,
        // 월별은 Y축 범위로 클램프하여 표시(실제값은 툴팁에 유지)
        omitOutOfRangeWeights:
            selectedPeriod == '일' ? !expandedChartView : selectedPeriod == '월',
        onTimeOffsetChanged: (newOffset) {
          _setState(() {
            timeOffset = newOffset;
          });
          _notifyExpandedChart();
        },
        onTooltipChanged: (index, position) {
          _setState(() {
            selectedChartPointIndex = index;
            tooltipPosition = position;
          });
          _notifyExpandedChart();
        },
        chartAreaBuilder: (a, b, c, d) => _buildChartArea(
          a,
          b,
          c,
          d,
          forExpandedChart: expandedChartView,
        ),
        tooltipBuilder: _buildChartTooltip,
      ),
      emptyChartBuilder: (height, tabs) => WeightEmptyChart(
        chartHeight: height,
        selectedPeriod: selectedPeriod,
        selectedDate: selectedDate,
        timeOffset: timeOffset,
        yLabels: yLabels,
        periodSelector: tabs,
        showYAxisKgHeader: true,
      ),
    );
  }

  Future<void> _openExpandedChartPage() async {
    await openHealthChartExpandPage(
      context: context,
      periodSelectorBuilder: (ctx) => HealthExpandedPeriodSelector(
        metrics: healthExpandedMetrics(ctx),
        selectedPeriod: selectedPeriod,
        onChanged: (period) {
          _setState(() {
            selectedPeriod = period;
            selectedChartPointIndex = null;
            tooltipPosition = null;
            if (period == '월') {
              timeOffset = 0.0;
            } else if (period == '주') {
              timeOffset = 0.0;
            } else if (period == '일') {
              timeOffset = _dailyOffsetForDate(
                selectedDate,
                forExpandedChart: true,
              );
            }
          });
          _notifyExpandedChart();
        },
      ),
      chartBuilder: (ctx) {
        final base = Theme.of(ctx);
        final gmarket = base.copyWith(
          textTheme: base.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
          primaryTextTheme:
              base.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            final scaledChartCap = healthExpandedMetrics(context)
                .d(HealthExpandedChartMetrics.chartHeightWithoutLegend);
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
                child: _buildChartContent(
                  showExpandButton: false,
                  chartHeight: safeHeight,
                  expandedChartView: true,
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

  // 차트 영역 빌드
  Widget _buildChartArea(
    List<Map<String, dynamic>> chartData,
    List<double> yLabels,
    BoxConstraints constraints,
    bool omitOutOfRangeWeights, {
    bool forExpandedChart = false,
  }) {
    return GestureDetector(
      onTapDown: (details) {
        _handleChartTap(
          details.localPosition,
          chartData,
          yLabels.last,
          yLabels.first,
          constraints.maxWidth,
          constraints.maxHeight,
          omitOutOfRangeWeights: omitOutOfRangeWeights,
        );
      },
      onPanDown: (details) {
        // 길게 누르지 않아도 바로 툴팁 표시
        _handleChartHover(
          details.localPosition,
          chartData,
          yLabels.last,
          yLabels.first,
          constraints.maxWidth,
          constraints.maxHeight,
          omitOutOfRangeWeights: omitOutOfRangeWeights,
        );
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
            constraints.maxWidth,
            forExpandedChart: forExpandedChart,
          );
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
                topPadding: healthWeightChartVertPad(context),
                bottomPadding: healthWeightChartBottomPlotPad(context),
                barWidth: HealthChartMetrics(
                  healthTextScaleByWidth(MediaQuery.sizeOf(context).width),
                ).barWidth,
                scale: healthTextScaleByWidth(
                  MediaQuery.sizeOf(context).width,
                ),
                forExpandedChart: forExpandedChart,
              ),
              size: Size(
                constraints.maxWidth,
                constraints.maxHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
