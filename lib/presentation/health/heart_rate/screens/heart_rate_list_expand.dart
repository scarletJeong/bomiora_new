part of 'heart_rate_list_screen.dart';

extension _HeartRateListExpand on _HeartRateListScreenState {
  Future<void> _openExpandedChartPage() async {
    await openHealthChartExpandPage(
      context: context,
      periodSelectorBuilder: (ctx) => HealthExpandedPeriodSelector(
        metrics: healthExpandedMetrics(ctx),
        selectedPeriod: selectedPeriod,
        onChanged: (period) => _setChartState(() {
          selectedPeriod = period;
          selectedChartPointIndex = null;
          tooltipPosition = null;
          _dailyChartTooltip = null;
          if (period == '월' || period == '주') {
            timeOffset = 0.0;
          } else if (_isToday()) {
            timeOffset = _dailyOffsetForToday(forExpandedChart: true);
          } else {
            timeOffset = 0.0;
          }
        }),
      ),
      legendBuilder: (ctx) {
        final m = healthExpandedMetrics(ctx);
        final gap = m.d(17.62);
        return Row(
          children: [
            HealthExpandedChartLegendItem(
              metrics: m,
              color: const Color(0xFFFF8686),
              label: '운동',
            ),
            SizedBox(width: gap),
            HealthExpandedChartLegendItem(
              metrics: m,
              color: const Color(0xFF86B0FF),
              label: '일상',
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
                  chartPeriodTabsInCard: false,
                  chartHeight: safeHeight,
                ),
              ),
            );
          },
        );
      },
      onRegisterRefresh: (refresh) => _refreshExpandedChart = refresh,
      onDisposeRefresh: () => _refreshExpandedChart = null,
    );
  }
}
