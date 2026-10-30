part of 'steps_list_screen.dart';

extension _StepsListExpand on _StepsTodayScreenState {
  Future<void> _openExpandedChartPage() async {
    await openHealthChartExpandPage(
      context: context,
      periodSelectorBuilder: (ctx) => HealthExpandedPeriodSelector(
        metrics: healthExpandedMetrics(ctx),
        selectedPeriod: selectedPeriod,
        onChanged: (period) {
          _setState(() {
            selectedPeriod = period;
            if (period == '일') {
              timeOffset = _isToday()
                  ? _defaultDailyTimeOffset(forExpandedChart: true)
                  : 0.0;
            } else if (period == '월') {
              timeOffset = 0.0;
            } else {
              timeOffset = 0.0;
            }
          });
          _notifyExpandedChart();
        },
      ),
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
                .d(HealthExpandedChartMetrics.chartHeightWithoutLegend);
            final scaledChartMin = healthDp(context, 160);
            final h = ChartConstants.healthExpandedChartHeight(
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
                child: _buildChartCard(
                  showExpandButton: false,
                  chartPeriodTabsInCard: false,
                  forExpandedChart: true,
                  chartHeight: h,
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
