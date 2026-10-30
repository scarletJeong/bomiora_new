part of 'weight_list_screen.dart';

extension _WeightListInteraction on _WeightListScreenState {
  // 차트 클릭 핸들러 (차트의 점 클릭 감지)
  void _handleChartTap(
    Offset tapPosition,
    List<Map<String, dynamic>> chartData,
    double minWeight,
    double maxWeight,
    double chartWidth,
    double chartHeight, {
    bool omitOutOfRangeWeights = false,
  }) {
    if (chartData.isEmpty) return;

    final topPadChart = healthWeightChartVertPad(context);
    final botPadChart = healthWeightChartBottomPlotPad(context);
    final drawableTop = topPadChart;
    final drawableBottom = chartHeight - botPadChart;
    final hitPadV = healthDp(context, 12);
    final barHitHalfW = healthDp(context, 16);

    // 가장 가까운 점 찾기
    int? closestIndex;
    double minDistance = double.infinity;
    Offset? closestPoint;

    for (int i = 0; i < chartData.length; i++) {
      final data = chartData[i];

      if (selectedPeriod == '일' && data['hourSlotBar'] == true) {
        final minW = (data['minWeight'] as num).toDouble();
        final maxW = (data['maxWeight'] as num).toDouble();
        if (omitOutOfRangeWeights && (maxW < minWeight || minW > maxWeight)) {
          continue;
        }
        final weightRange = maxWeight - minWeight;
        if (weightRange.abs() < 1e-9) continue;

        final xPosition = (data['xPosition'] as double?) ?? 0.5;
        const leftPad = ChartConstants.weightDailyChartInnerPadH;
        const rightPad = ChartConstants.weightDailyChartInnerPadH +
            ChartConstants.weightXAxisUnitReservedWidth;
        final xCenter = leftPad + (chartWidth - leftPad - rightPad) * xPosition;
        final drawableHeight = chartHeight - topPadChart - botPadChart;
        final yHi =
            topPadChart + drawableHeight * ((maxWeight - maxW) / weightRange);
        final yLo =
            topPadChart + drawableHeight * ((maxWeight - minW) / weightRange);
        var yTop = math.min(yHi, yLo);
        var yBottom = math.max(yHi, yLo);
        yTop = yTop.clamp(drawableTop, drawableBottom);
        yBottom = yBottom.clamp(drawableTop, drawableBottom);
        if (yBottom < yTop) {
          final t = yTop;
          yTop = yBottom;
          yBottom = t;
        }
        final cy = (yTop + yBottom) / 2;
        if (tapPosition.dx >= xCenter - barHitHalfW &&
            tapPosition.dx <= xCenter + barHitHalfW &&
            tapPosition.dy >= yTop - hitPadV &&
            tapPosition.dy <= yBottom + hitPadV) {
          final dx = tapPosition.dx - xCenter;
          final dy = tapPosition.dy - cy;
          final distance = dx * dx + dy * dy;
          if (distance < minDistance) {
            minDistance = distance;
            closestIndex = i;
            closestPoint = Offset(xCenter, cy);
          }
        }
        continue;
      }

      final weight = data['weight'];

      if (weight == null) continue; // null 값 스킵

      if (omitOutOfRangeWeights) {
        final w = (weight as num).toDouble();
        if (w < minWeight || w > maxWeight) continue;
      }

      double x;
      if (data['xPosition'] != null) {
        final xPosition = data['xPosition'] as double;
        final leftPad = ChartConstants.weightDailyChartInnerPadH;
        final rightPad = ChartConstants.weightDailyChartInnerPadH +
            ChartConstants.weightXAxisUnitReservedWidth;
        x = leftPad + (chartWidth - leftPad - rightPad) * xPosition;
      } else if (selectedPeriod == '일') {
        final leftPad = ChartConstants.weightDailyChartInnerPadH;
        final rightPad = ChartConstants.weightDailyChartInnerPadH +
            ChartConstants.weightXAxisUnitReservedWidth;
        final effectiveWidth = chartWidth - leftPad - rightPad;
        x = chartData.length == 1
            ? leftPad + effectiveWidth / 2
            : leftPad + effectiveWidth * i / (chartData.length - 1);
      } else {
        final xPosition = data['xPosition'] as double;
        const visibleDays = 7;
        const totalDays = 30;
        final leftPad = ChartConstants.weightDailyChartInnerPadH;
        final rightPad = ChartConstants.weightDailyChartInnerPadH +
            ChartConstants.weightXAxisUnitReservedWidth;
        if (selectedPeriod == '월') {
          final maxOffset = (totalDays - visibleDays) / totalDays;
          final currentOffset = timeOffset.clamp(0.0, maxOffset);
          final startIndex = (currentOffset * totalDays).floor();
          final endIndex = startIndex + visibleDays;
          final dataIndex = (xPosition * totalDays).round();
          if (dataIndex < startIndex || dataIndex >= endIndex) continue;
          final relativeIndex = dataIndex - startIndex;
          final adjustedRatio = relativeIndex / (visibleDays - 1);
          x = leftPad + (chartWidth - leftPad - rightPad) * adjustedRatio;
        } else {
          x = leftPad + (chartWidth - leftPad - rightPad) * xPosition;
        }
      }

      // Y 좌표 계산 (페인터와 동일한 상하 패딩 적용)
      final drawableHeight = chartHeight - topPadChart - botPadChart;
      final wr = maxWeight - minWeight;
      if (wr.abs() < 1e-9) continue;
      final normalizedWeight = (maxWeight - weight) / wr;
      final y = topPadChart + drawableHeight * normalizedWeight;

      // 클릭 위치와 점 사이의 거리 계산
      final dx = tapPosition.dx - x;
      final dy = tapPosition.dy - y;
      final distance = dx * dx + dy * dy; // 제곱 거리

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
        closestPoint = Offset(x, y);
      }
    }

    // 탭 허용 범위를 넓혀 더 빠르고 정확하게 선택
    if (closestIndex != null && minDistance < 1600) {
      _setState(() {
        selectedChartPointIndex = closestIndex;
        tooltipPosition = closestPoint;
      });
      _notifyExpandedChart();
    } else {
      // 가까운 점이 없으면 툴팁 숨기기
      _setState(() {
        selectedChartPointIndex = null;
        tooltipPosition = null;
      });
      _notifyExpandedChart();
    }
  }

  // 차트 호버/드래그 핸들러 (툴팁 표시용)
  void _handleChartHover(
    Offset hoverPosition,
    List<Map<String, dynamic>> chartData,
    double minWeight,
    double maxWeight,
    double chartWidth,
    double chartHeight, {
    bool omitOutOfRangeWeights = false,
  }) {
    if (chartData.isEmpty) return;

    final topPadChart = healthWeightChartVertPad(context);
    final botPadChart = healthWeightChartBottomPlotPad(context);
    final drawableTop = topPadChart;
    final drawableBottom = chartHeight - botPadChart;
    final hitPadV = healthDp(context, 12);
    final barHitHalfW = healthDp(context, 16);

    // 가장 가까운 점 찾기
    int? closestIndex;
    double minDistance = double.infinity;
    Offset? closestPoint;

    for (int i = 0; i < chartData.length; i++) {
      final data = chartData[i];

      if (selectedPeriod == '일' && data['hourSlotBar'] == true) {
        final minW = (data['minWeight'] as num).toDouble();
        final maxW = (data['maxWeight'] as num).toDouble();
        if (omitOutOfRangeWeights && (maxW < minWeight || minW > maxWeight)) {
          continue;
        }
        final weightRange = maxWeight - minWeight;
        if (weightRange.abs() < 1e-9) continue;

        final xPosition = (data['xPosition'] as double?) ?? 0.5;
        const leftPad = ChartConstants.weightDailyChartInnerPadH;
        const rightPad = ChartConstants.weightDailyChartInnerPadH +
            ChartConstants.weightXAxisUnitReservedWidth;
        final xCenter = leftPad + (chartWidth - leftPad - rightPad) * xPosition;
        final drawableHeight = chartHeight - topPadChart - botPadChart;
        final yHi =
            topPadChart + drawableHeight * ((maxWeight - maxW) / weightRange);
        final yLo =
            topPadChart + drawableHeight * ((maxWeight - minW) / weightRange);
        var yTop = math.min(yHi, yLo);
        var yBottom = math.max(yHi, yLo);
        yTop = yTop.clamp(drawableTop, drawableBottom);
        yBottom = yBottom.clamp(drawableTop, drawableBottom);
        if (yBottom < yTop) {
          final t = yTop;
          yTop = yBottom;
          yBottom = t;
        }
        final cy = (yTop + yBottom) / 2;
        if (hoverPosition.dx >= xCenter - barHitHalfW &&
            hoverPosition.dx <= xCenter + barHitHalfW &&
            hoverPosition.dy >= yTop - hitPadV &&
            hoverPosition.dy <= yBottom + hitPadV) {
          final dx = hoverPosition.dx - xCenter;
          final dy = hoverPosition.dy - cy;
          final distance = dx * dx + dy * dy;
          if (distance < minDistance) {
            minDistance = distance;
            closestIndex = i;
            closestPoint = Offset(xCenter, cy);
          }
        }
        continue;
      }

      final weight = data['weight'];

      if (weight == null) continue; // null 값 스킵

      if (omitOutOfRangeWeights) {
        final w = (weight as num).toDouble();
        if (w < minWeight || w > maxWeight) continue;
      }

      double x;
      if (data['xPosition'] != null) {
        final xPosition = data['xPosition'] as double;
        final leftPad = ChartConstants.weightDailyChartInnerPadH;
        final rightPad = ChartConstants.weightDailyChartInnerPadH +
            ChartConstants.weightXAxisUnitReservedWidth;
        x = leftPad + (chartWidth - leftPad - rightPad) * xPosition;
      } else if (selectedPeriod == '일') {
        final leftPad = ChartConstants.weightDailyChartInnerPadH;
        final rightPad = ChartConstants.weightDailyChartInnerPadH +
            ChartConstants.weightXAxisUnitReservedWidth;
        final effectiveWidth = chartWidth - leftPad - rightPad;
        x = chartData.length == 1
            ? leftPad + effectiveWidth / 2
            : leftPad + effectiveWidth * i / (chartData.length - 1);
      } else {
        final xPosition = data['xPosition'] as double;
        const visibleDays = 7;
        const totalDays = 30;
        final leftPad = ChartConstants.weightDailyChartInnerPadH;
        final rightPad = ChartConstants.weightDailyChartInnerPadH +
            ChartConstants.weightXAxisUnitReservedWidth;
        if (selectedPeriod == '월') {
          final maxOffset = (totalDays - visibleDays) / totalDays;
          final currentOffset = timeOffset.clamp(0.0, maxOffset);
          final startIndex = (currentOffset * totalDays).floor();
          final endIndex = startIndex + visibleDays;
          final dataIndex = (xPosition * totalDays).round();
          if (dataIndex < startIndex || dataIndex >= endIndex) continue;
          final relativeIndex = dataIndex - startIndex;
          final adjustedRatio = relativeIndex / (visibleDays - 1);
          x = leftPad + (chartWidth - leftPad - rightPad) * adjustedRatio;
        } else {
          x = leftPad + (chartWidth - leftPad - rightPad) * xPosition;
        }
      }

      // Y 좌표 계산 (페인터와 동일한 상하 패딩 적용)
      final drawableHeight = chartHeight - topPadChart - botPadChart;
      final wr = maxWeight - minWeight;
      if (wr.abs() < 1e-9) continue;
      final normalizedWeight = (maxWeight - weight) / wr;
      final y = topPadChart + drawableHeight * normalizedWeight;

      // 거리 계산
      final dx = hoverPosition.dx - x;
      final dy = hoverPosition.dy - y;
      final distance = dx * dx + dy * dy;

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
        closestPoint = Offset(x, y);
      }
    }

    // hover/드래그 중에도 즉시 따라오도록 허용 반경 확장
    if (closestIndex != null && minDistance < 4900) {
      _setState(() {
        selectedChartPointIndex = closestIndex;
        tooltipPosition = closestPoint;
      });
      _notifyExpandedChart();
    } else {
      _setState(() {
        selectedChartPointIndex = null;
        tooltipPosition = null;
      });
      _notifyExpandedChart();
    }
  }

  // 차트 툴팁 위젯
  Widget _buildChartTooltip(
      Map<String, dynamic> data, double chartWidth, double chartHeight) {
    if (tooltipPosition == null) return const SizedBox.shrink();

    late final String timeLabel;
    late final String weightLine;

    if (data['hourSlotBar'] == true) {
      final minW = (data['minWeight'] as num).toDouble();
      final maxW = (data['maxWeight'] as num).toDouble();
      final hour = data['hour'] as int;
      timeLabel = '$hour시';
      weightLine = minW == maxW
          ? '${minW.toStringAsFixed(1)} kg'
          : '${minW.toStringAsFixed(1)} ~ ${maxW.toStringAsFixed(1)} kg';
    } else {
      final weight = data['weight'];
      final record = data['record'];
      if (weight == null || record == null) return const SizedBox.shrink();

      final weightValue = weight as double;
      final weightRecord = record as WeightRecord;

      String formatKoreanTime(DateTime dt) {
        return '${dt.hour}시';
      }

      timeLabel = selectedPeriod == '일'
          ? formatKoreanTime(weightRecord.measuredAt)
          : DateFormat('M/d HH:mm').format(weightRecord.measuredAt);
      weightLine = '${weightValue.toStringAsFixed(1)} kg';
    }

    // 부모 Positioned(점 위치 기준) 내에서 상대 이동으로 배치
    double tooltipX = tooltipPosition!.dx;
    double tooltipY = tooltipPosition!.dy - 60;
    const tooltipWidth = 110.0;
    const tooltipHeight = 56.0;

    if (tooltipX < 0) tooltipX = 0;
    if (tooltipX > chartWidth - tooltipWidth)
      tooltipX = chartWidth - tooltipWidth;
    if (tooltipY < 0) tooltipY = tooltipPosition!.dy + 20;
    if (tooltipY > chartHeight - tooltipHeight)
      tooltipY = chartHeight - tooltipHeight;

    final timeStyle = TextStyle(
      color: Colors.grey[700],
      fontSize: 12,
      fontWeight: FontWeight.w400,
    );
    final weightStyle = const TextStyle(
      color: Colors.black87,
      fontSize: 14,
      fontWeight: FontWeight.w700,
    );

    return Transform.translate(
      offset: Offset(
        tooltipX - tooltipPosition!.dx,
        tooltipY - tooltipPosition!.dy,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: selectedPeriod == '일'
              ? [
                  Text(timeLabel,
                      style: timeStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(
                    weightLine,
                    style: weightStyle,
                    textAlign: TextAlign.center,
                  ),
                ]
              : [
                  Text(
                    weightLine,
                    style: weightStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(timeLabel,
                      style: timeStyle, textAlign: TextAlign.center),
                ],
        ),
      ),
    );
  }

  // 시간별 기록 선택 바텀시트
  Future<void> _showTimeSelectionBottomSheet(List<WeightRecord> records) async {
    final selectedRecord = await showHealthEditBottomSheet<WeightRecord>(
      context: context,
      items: records
          .map(
            (record) => HealthEditBottomSheetItem<WeightRecord>(
              data: record,
              timeText: DateFormat('HH:mm').format(record.measuredAt),
              buildTrailing: (ctx) => Text.rich(
                textScaler: TextScaler.noScaling,
                TextSpan(
                  children: [
                    TextSpan(
                      text: record.weight.toStringAsFixed(1),
                      style: TextStyle(
                        color: const Color(0xFFFF5A8D),
                        fontSize: healthSp(ctx, 18),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: ' kg',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: healthSp(ctx, 18),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );

    if (selectedRecord == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeightInputScreen(record: selectedRecord),
      ),
    );
  }

  Future<void> _openSelectedDateEditorPopup() async {
    if (selectedRecord == null) return;

    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final todayRecords = allRecords.where((record) {
      final recordDateStr = DateFormat('yyyy-MM-dd').format(record.measuredAt);
      return recordDateStr == selectedDateStr;
    }).toList();

    todayRecords.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    if (todayRecords.isEmpty) return;

    // 공통 수정 팝업(health_edit_bottom_sheet) 사용
    await _showTimeSelectionBottomSheet(todayRecords);
  }
}
