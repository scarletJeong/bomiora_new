part of 'blood_pressure_list_screen.dart';

extension _BloodPressureListChart on _BloodPressureListScreenState {
  // 기간 선택 버튼
  Widget _buildPeriodButtons({bool plainStyle = false}) {
    return HealthPeriodSelector(
      selectedPeriod: selectedPeriod,
      plainStyle: plainStyle,
      onChanged: (period) {
        _setChartState(() {
          selectedPeriod = period;
          selectedChartPointIndex = null;
          tooltipPosition = null;
          if (period == '월') {
            timeOffset = 0.0;
          } else if (period == '주') {
            timeOffset = 0.0;
          } else if (period == '일') {
            if (_isToday()) {
              timeOffset = healthDailyTimeOffsetForToday();
            } else {
              timeOffset = 0.0;
            }
            _ensureHourlyWindowShowsData();
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

  // 차트
  Widget _buildChart(
      {bool showExpandButton = true,
      bool forExpandedChart = false,
      double chartHeight = ChartConstants.weightChartHeight}) {
    final chartData = getChartData(forExpandedChart: forExpandedChart);
    final yLabels = getYAxisLabels(forExpandedChart: forExpandedChart);

    Widget chartBody;

    if (_shouldShowBloodPressureNoDataCard()) {
      chartBody = _buildNoDataMessage(
        chartHeight: chartHeight,
        forExpandedChart: forExpandedChart,
      );
    } else {
      chartBody = _buildDataChart(
        chartData,
        yLabels,
        chartHeight: chartHeight,
        forExpandedChart: forExpandedChart,
      );
    }

    if (!showExpandButton) return chartBody;

    final showYHeader = yLabels.length > 1;
    final headerBand =
        showYHeader ? bloodPressureYAxisUnitBandHeight(context) : 0.0;
    final padTop = healthChartCardPadding(context).top;
    final tabH =
        healthDp(context, ChartConstants.weightChartPeriodTabBarHeight);
    final iconSize = healthDp(context, 20);
    final expandH = HealthChartExpandControl.blockHeight(context, iconSize);
    final topExpand = padTop +
        tabH +
        healthDp(context, ChartConstants.weightChartTabToPlotGap) +
        headerBand / 2 -
        expandH / 2;

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

  // 데이터 없음 메시지 빌드
  Widget _buildNoDataMessage({
    double chartHeight = ChartConstants.weightChartHeight,
    bool forExpandedChart = false,
  }) {
    return HealthDailyNoDataChartCard(
      chartHeight: chartHeight,
      title: '해당 기간에 혈압 기록이 없습니다',
      subtitle: '혈압을 측정해보세요',
      header: forExpandedChart ? null : _buildPeriodButtons(plainStyle: true),
      showBorder: !forExpandedChart,
    );
  }

  // 데이터가 있는 차트 빌드
  Widget _buildDataChart(
      List<Map<String, dynamic>> chartData, List<double> yLabels,
      {double chartHeight = ChartConstants.weightChartHeight,
      bool forExpandedChart = false}) {
    return _buildDraggableChart(
      chartData,
      yLabels,
      isEmpty: false,
      chartHeight: chartHeight,
      forExpandedChart: forExpandedChart,
    );
  }

  // 드래그 가능한 차트 빌드 (체중 그래프와 동일 패딩·Y축·X축 단위)
  Widget _buildDraggableChart(
      List<Map<String, dynamic>> chartData, List<double> yLabels,
      {required bool isEmpty,
      double chartHeight = ChartConstants.weightChartHeight,
      bool forExpandedChart = false}) {
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
          if (!forExpandedChart) ...[
            _buildPeriodButtons(plainStyle: true),
            SizedBox(
                height:
                    healthDp(context, ChartConstants.weightChartTabToPlotGap)),
          ],
          Expanded(
            child: LayoutBuilder(builder: (context, outerConstraints) {
              final showYHeader = yLabels.length > 1;
              final headerBand =
                  showYHeader ? bloodPressureYAxisUnitBandHeight(context) : 0.0;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buildBloodPressureYAxisStrip(
                    yLabels: yLabels,
                    showYAxisHeader: showYHeader,
                  ),
                  SizedBox(
                      width: healthDp(
                          context, ChartConstants.weightChartYAxisPlotGap)),
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
                                yLabels,
                                forExpandedChart: forExpandedChart,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
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
              child: _buildBloodPressureXAxisLabels(
                forExpandedChart: forExpandedChart,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 차트 영역 빌드
  Widget _buildChartArea(
    List<Map<String, dynamic>> chartData,
    BoxConstraints constraints,
    bool isEmpty,
    List<double> yLabels, {
    bool forExpandedChart = false,
  }) {
    _bpLastPlotWidth = constraints.maxWidth;
    final chartW = constraints.maxWidth;
    final chartH = constraints.maxHeight;

    // 체중 주간·월간과 동일: GestureDetector가 차트+툴팁 Stack을 감싸 onTapDown이 바로 동작
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (selectedPeriod == '일' || selectedPeriod == '월')
          ? (details) {
              _setChartState(() {
                selectedChartPointIndex = null;
                tooltipPosition = null;
              });
              _dragStartX = details.localPosition.dx;
            }
          : null,
      onPanUpdate: (selectedPeriod == '일' || selectedPeriod == '월')
          ? (details) {
              if (_dragStartX != null) {
                final deltaX = details.localPosition.dx - _dragStartX!;
                _handleDragUpdate(
                  deltaX,
                  constraints.maxWidth,
                  forExpandedChart: forExpandedChart,
                );
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
                yLabels.last,
                yLabels.first,
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
                    painter: EmptyChartGridPainter(
                      yLabels: yLabels,
                      topPlotPad: healthWeightChartVertPad(context),
                      bottomPlotPad: healthWeightChartBottomPlotPad(context),
                    ),
                  )
                : CustomPaint(
                    painter: BloodPressureChartPainter(
                      chartData,
                      yLabels.last,
                      yLabels.first,
                      yLabels: yLabels,
                      highlightedIndex: selectedChartPointIndex,
                      isToday: _isToday(),
                      timeOffset: timeOffset,
                      cellCenterXSlots: true,
                      topPlotPad: healthWeightChartVertPad(context),
                      scale: healthTextScaleByWidth(
                          MediaQuery.of(context).size.width),
                      xUnitReservedWidth: healthDp(
                          context, ChartConstants.weightXAxisUnitReservedWidth),
                      bottomPlotPad: healthWeightChartBottomPlotPad(context),
                    ),
                  ),
          ),
          if (!isEmpty &&
              selectedChartPointIndex != null &&
              tooltipPosition != null &&
              selectedChartPointIndex! >= 0 &&
              selectedChartPointIndex! < chartData.length)
            Positioned(
              left: tooltipPosition!.dx,
              top: tooltipPosition!.dy,
              child: buildBloodPressureChartTooltip(
                context: context,
                data: chartData[selectedChartPointIndex!],
                tooltipAnchor: tooltipPosition!,
                chartWidth: chartW,
                chartHeight: chartH,
                selectedPeriod: selectedPeriod,
                selectedDate: selectedDate,
              ),
            ),
        ],
      ),
    );
  }

  // 차트 탭 핸들러 - 툴팁 토글 (히트 테스트는 blood_pressure_chart_tooltip.dart)
  void _handleChartTapToggle(
    Offset tapPosition,
    List<Map<String, dynamic>> chartData,
    double minValue,
    double maxValue,
    double chartWidth,
    double chartHeight,
  ) {
    final hit = hitTestBloodPressureChartSlot(
      tapPosition: tapPosition,
      chartData: chartData,
      minValue: minValue,
      maxValue: maxValue,
      chartWidth: chartWidth,
      chartHeight: chartHeight,
      cellCenterXSlots: true,
      topPadding: healthWeightChartVertPad(context),
      bottomPadding: healthWeightChartBottomPlotPad(context),
      scale: healthTextScaleByWidth(MediaQuery.of(context).size.width),
      xUnitReservedWidth:
          healthDp(context, ChartConstants.weightXAxisUnitReservedWidth),
    );
    _setChartState(() {
      if (hit == null) {
        selectedChartPointIndex = null;
        tooltipPosition = null;
      } else if (selectedChartPointIndex == hit.index) {
        selectedChartPointIndex = null;
        tooltipPosition = null;
      } else {
        selectedChartPointIndex = hit.index;
        tooltipPosition = hit.anchor;
      }
    });
  }

  Future<void> _openExpandedChartPage() async {
    await openHealthChartExpandPage(
      context: context,
      periodSelectorBuilder: (ctx) => HealthExpandedPeriodSelector(
        metrics: healthExpandedMetrics(ctx),
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
            } else if (period == '일') {
              if (_isToday()) {
                timeOffset = healthDailyTimeOffsetForToday(
                  forExpandedChart: true,
                );
              } else {
                timeOffset = 0.0;
              }
              _ensureHourlyWindowShowsData(forExpandedChart: true);
            } else {
              timeOffset = 0.0;
            }
          });
        },
      ),
      legendBuilder: (ctx) {
        final m = healthExpandedMetrics(ctx);
        final gap = m.d(12.62);
        return Row(
          children: [
            HealthExpandedChartLegendItem(
              metrics: m,
              color: const Color(0xFF86B0FF),
              label: '수축기',
            ),
            SizedBox(width: gap),
            HealthExpandedChartLegendItem(
              metrics: m,
              color: const Color(0xFFFFC686),
              label: '이완기',
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
                child: _buildChart(
                  showExpandButton: false,
                  forExpandedChart: true,
                  chartHeight: safeHeight,
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
}
