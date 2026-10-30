part of 'heart_rate_list_screen.dart';

extension _HeartRateListSummary on _HeartRateListScreenState {
  Widget _summaryCard(BuildContext context, String title, String value) {
    final bool hasData = value != '-';
    final hPad = healthDp(context, 11.3);
    final vPad = healthDp(context, 6.67);
    return SizedBox(
      height: healthDp(context, 83.33),
      child: Container(
        padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad),
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: healthDp(context, 0.5),
              color: const Color(0x7FD2D2D2),
            ),
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: const Color(0xFF1A1A1A),
                fontSize: healthSp(context, 16),
                height: 1.0,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: healthDp(context, 8.33)),
            RichText(
              textScaler: TextScaler.noScaling,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: healthSp(context, 20.83),
                      height: 1.0,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: hasData ? FontWeight.w700 : FontWeight.w300,
                    ),
                  ),
                  TextSpan(
                    text: ' bpm',
                    style: TextStyle(
                      color: const Color(0xFF9C9393),
                      fontSize: healthSp(context, 12),
                      height: 1.0,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
            if (!hasData) ...[
              SizedBox(height: healthDp(context, 4)),
              Text(
                '수치를 입력하세요',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: const Color(0xFF1A1A1A),
                  fontSize: healthSp(context, 8),
                  height: 1.0,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recordTile(HeartRateRecord record) {
    final textStyle = TextStyle(
      color: Colors.black,
      fontSize: healthSp(context, 16),
      height: 1.0,
      fontFamily: 'Gmarket Sans TTF',
    );
    return Container(
      height: healthDp(context, 44),
      margin: EdgeInsets.only(bottom: healthDp(context, 20)),
      padding: EdgeInsets.symmetric(
        vertical: healthDp(context, 10),
        horizontal: healthDp(context, 12),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
        border: Border.all(
          color: const Color(0x7FD2D2D2),
          width: healthDp(context, 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            color: Colors.grey,
            size: healthDp(context, 16),
          ),
          SizedBox(width: healthDp(context, 12)),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('a h:mm', 'ko').format(record.measuredAt),
                  textScaler: TextScaler.noScaling,
                  style: textStyle.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${record.heartRate}bpm',
                  textScaler: TextScaler.noScaling,
                  style: textStyle.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handlePeriodChanged(String period) {
    _setChartState(() {
      selectedPeriod = period;
      _recordsCacheDateKey = null;
      _recordsCacheForDate = null;
      selectedChartPointIndex = null;
      tooltipPosition = null;
      _dailyChartTooltip = null;
      if (period == '월') {
        timeOffset = 0.0;
      } else if (period == '주') {
        timeOffset = 0.0;
      } else if (_isToday()) {
        timeOffset = _dailyOffsetForToday();
      } else {
        timeOffset = 0.0;
      }
    });
  }
}
