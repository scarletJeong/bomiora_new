part of 'weight_list_screen.dart';

extension _WeightListSummary on _WeightListScreenState {
  Widget _buildTopWeightSummaryCard() {
    final weight = selectedRecord?.weight ?? 0.0;
    final height = selectedRecord?.height ?? 0.0;
    final targetWeight = latestHealthGoal?.targetWeight ?? 0.0;
    // 목표 설정 때 저장한 현재 체중. 오늘 체중을 입력해도 이 값은 바꾸지 않는다.
    final goalCurrentWeight = latestHealthGoal?.currentWeight ?? 0.0;
    final lostWeight = (weight > 0 && goalCurrentWeight > 0)
        ? (weight - goalCurrentWeight)
        : 0.0;
    final progressRatio = (weight <= 0 || targetWeight <= 0)
        ? 0.0
        : weightTowardGoalRatio(weight, targetWeight, goalCurrentWeight);
    // 오늘의 체중 흰 카드 바깥 패딩 없음. 349 안 좌우는 논리 10. 세로: healthDp(18)·원193·10·수정·10·메트릭·10.
    final squareSide = healthDp(context, 349);
    final chartDiameter = healthDp(context, 193);
    final ringStroke = healthDp(context, 18); // 원형차트 굵기기
    final chartTopGap = healthDp(context, 38);
    const double chartToButtonGap = 10;
    final chartBandH = chartTopGap + chartDiameter + chartToButtonGap;
    final buttonBandH = healthDp(context, 22);

    /// 수정하기 ↔ 메트릭 / 메트릭 ↔ 하단 (스케일 없이 10).
    const double gapBeforeMetricsBand = 10;
    const double gapAfterMetricsBand = 10;

    /// 301 정사각형 안 메트릭 행 최소 높이 (375 기준 66).
    final metricsBandH = healthDp(context, 66);
    final innerContentH = chartBandH +
        buttonBandH +
        gapBeforeMetricsBand +
        metricsBandH +
        gapAfterMetricsBand;
    final innerDesignH = innerContentH;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x19000000),
            blurRadius: healthDp(context, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: squareSide,
            height: squareSide,
            child: innerDesignH > squareSide + 0.5
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return ClipRect(
                          child: FittedBox(
                            fit: BoxFit.fitWidth,
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: constraints.maxWidth,
                              height: innerDesignH,
                              child: _topWeightSummarySquareContent(
                                context: context,
                                chartDiameter: chartDiameter,
                                ringStroke: ringStroke,
                                progressRatio: progressRatio,
                                weight: weight,
                                heightCm: height,
                                targetWeight: targetWeight,
                                lostWeight: lostWeight,
                                chartBandH: chartBandH,
                                chartTopGap: chartTopGap,
                                chartToButtonGap: chartToButtonGap,
                                buttonBandH: buttonBandH,
                                gapBeforeMetricsBand: gapBeforeMetricsBand,
                                metricsBandH: metricsBandH,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: _topWeightSummarySquareContent(
                          context: context,
                          chartDiameter: chartDiameter,
                          ringStroke: ringStroke,
                          progressRatio: progressRatio,
                          weight: weight,
                          heightCm: height,
                          targetWeight: targetWeight,
                          lostWeight: lostWeight,
                          chartBandH: chartBandH,
                          chartTopGap: chartTopGap,
                          chartToButtonGap: chartToButtonGap,
                          buttonBandH: buttonBandH,
                          gapBeforeMetricsBand: gapBeforeMetricsBand,
                          metricsBandH: metricsBandH,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// 301 정사각형 내부 세로 스택(좌우 10은 부모 [Padding]에서만 적용).
  Widget _topWeightSummarySquareContent({
    required BuildContext context,
    required double chartDiameter,
    required double ringStroke,
    required double progressRatio,
    required double weight,
    required double heightCm,
    required double targetWeight,
    required double lostWeight,
    required double chartBandH,
    required double chartTopGap,
    required double chartToButtonGap,
    required double buttonBandH,
    required double gapBeforeMetricsBand,
    required double metricsBandH,
  }) {
    final goalRingActive = targetWeight > 0 &&
        (latestHealthGoal?.currentWeight ?? 0) > 0 &&
        weight > 0;
    final knobEnd = goalRingActive
        ? _weightGoalRingProgressEndOffset(
            boxSize: chartDiameter,
            strokeWidth: ringStroke,
            progress: progressRatio,
          )
        : Offset.zero;
    final knobSize = healthDp(context, 32);
    final knobCornerR = healthDp(context, 17.5);
    final knobDeltaText = !goalRingActive
        ? '-'
        : (weight <= 0
            ? '-'
            : (lostWeight == 0
                ? '0'
                : '${lostWeight > 0 ? '+' : '-'}${lostWeight.abs().toStringAsFixed(1)}'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: chartBandH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: chartTopGap),
                  Center(
                    child: SizedBox(
                      width: chartDiameter,
                      height: chartDiameter,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: Size(chartDiameter, chartDiameter),
                            painter: _WeightGoalRingPainter(
                              progress: progressRatio,
                              trackColor: const Color(0x7FD9D9D9),
                              progressColor: const Color(0xFFFF5A8D),
                              strokeWidth: ringStroke,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '오늘의 체중',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 20,
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                              Text(
                                weight > 0
                                    ? '${weight.toStringAsFixed(1)}kg'
                                    : '-',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 32,
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          // 오늘 체중 미입력 시 감량 몸무게(흰 원) 숨김
                          if (goalRingActive && weight > 0)
                            Positioned(
                              left: knobEnd.dx - knobSize / 2,
                              top: knobEnd.dy - knobSize / 2,
                              child: Container(
                                width: knobSize,
                                height: knobSize,
                                decoration: ShapeDecoration(
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(knobCornerR),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    knobDeltaText,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 10,
                                      fontFamily: 'Gmarket Sans TTF',
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: chartToButtonGap),
                ],
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: healthDp(context, 8)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '목표체중',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        Text(
                          targetWeight > 0
                              ? '${targetWeight.toStringAsFixed(1)}kg'
                              : '-',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        CustomPaint(
                          size: Size(
                            healthDp(context, 7),
                            healthDp(context, 7),
                          ),
                          painter: const _GoalTargetDownTrianglePainter(
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: buttonBandH,
          child: Align(
            alignment: Alignment.centerRight,
            child: selectedRecord == null
                ? const SizedBox.shrink()
                : HealthListEditButton(
                    onTap: _openSelectedDateEditorPopup,
                  ),
          ),
        ),
        SizedBox(height: gapBeforeMetricsBand),
        SizedBox(
          height: metricsBandH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: healthDp(context, 0.5),
                width: double.infinity,
                child: const ColoredBox(
                  color: Color(0x7FD2D2D2),
                ),
              ),
              SizedBox(height: healthDp(context, 10)),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildTopMetricCell(
                      title: '키',
                      value: heightCm > 0 ? '${heightCm.toInt()}' : '-',
                      unit: 'cm',
                    ),
                    _buildVerticalDivider(),
                    _buildTopMetricCell(
                      title: '목표 체중',
                      value: targetWeight > 0
                          ? '${targetWeight.toStringAsFixed(1)}'
                          : '-',
                      unit: 'kg',
                    ),
                    _buildVerticalDivider(),
                    _buildTopMetricCell(
                      title: '감량 몸무게',
                      value: lostWeight != 0
                          ? '${lostWeight > 0 ? '+' : '-'}${lostWeight.abs().toStringAsFixed(1)}'
                          : '0',
                      unit: 'kg',
                      valueColor: const Color(0xFFFF5A8D),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildTopMetricCell({
    required String title,
    required String value,
    required String unit,
    Color valueColor = Colors.black,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Text(
              title,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: const Color(0xFF1A1A1A),
                fontSize: healthSp(context, 10),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
              ),
            ),
            SizedBox(height: healthDp(context, 8)),
            RichText(
              textScaler: TextScaler.noScaling,
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: valueColor,
                      fontSize: healthSp(context, 20),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      color: const Color(0xFF9C9393),
                      fontSize: healthSp(context, 12),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: healthDp(context, 0.5),
      height: healthDp(context, 46),
      color: const Color(0x7FD2D2D2),
    );
  }

  Widget _buildBmiSummaryCard() {
    final bmi = selectedRecord?.resolvedBmi ?? 0.0;
    final bmiStatus = selectedRecord?.bmiStatus ?? '';
    final Color statusAccent =
        bmi > 0 ? _getBmiStatusColor(bmi) : const Color(0xFF9C9393);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 10)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x19000000),
            blurRadius: healthDp(context, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'BMI',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: const Color(0xFF1A1A1A),
                  fontSize: healthSp(context, 16),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (bmiStatus.isNotEmpty)
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 28)),
                        border: Border.all(color: statusAccent),
                      ),
                      child: Text(
                        bmiStatus,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          color: statusAccent,
                          fontSize: healthSp(context, 12),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
              Text(
                bmi > 0 ? bmi.toStringAsFixed(2) : '-',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: const Color(0xFF1A1A1A),
                  fontSize: healthSp(context, 16),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (bmi > 0) ...[
            SizedBox(height: healthDp(context, 10)),
            _buildBmiColorBar(),
          ],
        ],
      ),
    );
  }

  // 1. 오늘의 체중
  Widget _buildWeightDisplay() {
    final weight = selectedRecord?.weight ?? 0.0;
    final dateStr = DateFormat('yyyy년 M월 d일').format(selectedDate);

    return GestureDetector(
      onTap: _openSelectedDateEditorPopup,
      child: Center(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                if (selectedRecord != null) // 기록이 있으면 편집 아이콘 표시
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.edit,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: weight > 0 ? weight.toStringAsFixed(1) : '-',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  TextSpan(
                    text: weight > 0 ? ' kg' : '',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (selectedRecord != null) // 기록이 있으면 힌트 표시
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '탭하여 수정',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 2. 키 / BMI
  Widget _buildHeightBmiRow() {
    final height = selectedRecord?.height ?? 0.0;
    final bmi = selectedRecord?.resolvedBmi ?? 0.0;
    final bmiStatus = selectedRecord?.bmiStatus ?? '';

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Text(
                '키(cm)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                height > 0 ? '${height.toInt()} cm' : '-',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 1,
          height: 40,
          color: Colors.grey[300],
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                'BMI(신체질량지수)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: bmi > 0 ? bmi.toStringAsFixed(1) : '-',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    if (bmiStatus.isNotEmpty)
                      TextSpan(
                        text: ' $bmiStatus',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getBmiStatusColor(bmi),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // BMI 상태 색상 (상태 배지·구간 라벨 등 글자 강조 통일)
  Color _getBmiStatusColor(double _) {
    return const Color(0xFFFF5A8D);
  }

  // 3. BMI 컬러 바
  Widget _buildBmiColorBar() {
    final bmi = selectedRecord?.resolvedBmi ?? 0.0;

    if (bmi <= 0) {
      return const SizedBox.shrink();
    }

    // BMI 위치 계산 (15 ~ 35 범위로 정규화)
    double minBmi = 15.0;
    double maxBmi = 35.0;
    double position = ((bmi - minBmi) / (maxBmi - minBmi)).clamp(0.0, 1.0);

    return Column(
      children: [
        LayoutBuilder(
          builder: (ctx, constraints) {
            // 바의 실제 너비 사용
            final barWidth = constraints.maxWidth;
            final hBar = healthDp(ctx, 8);
            final rBar = healthDp(ctx, 4);
            final indTop = -healthDp(ctx, 8);
            final indW = healthDp(ctx, 2);
            final indH = healthDp(ctx, 28);
            final dot = healthDp(ctx, 8);

            return Stack(
              children: [
                // 그라데이션 바
                Container(
                  height: hBar,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(rBar),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF4FC3F7), // 하늘색 (저체중)
                        Color(0xFF4CAF50), // 초록색 (정상)
                        Color(0xFFFF9800), // 주황색 (과체중)
                        Color(0xFFE91E63), // 분홍색 (비만)
                        Color(0xFFF44336), // 빨간색 (과체중·고BMI 구간)
                      ],
                    ),
                  ),
                ),
                // 인디케이터
                Positioned(
                  left: (barWidth * position - healthDp(ctx, 10))
                      .clamp(0.0, barWidth - healthDp(ctx, 20)),
                  top: indTop,
                  child: Column(
                    children: [
                      Container(
                        width: indW,
                        height: indH,
                        color: Colors.white,
                      ),
                      Container(
                        width: dot,
                        height: dot,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        SizedBox(height: healthDp(context, 4)),
        // BMI 범위 텍스트
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '저체중',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: healthSp(context, 8),
                color: const Color(0xFF94A3B8),
                fontFamily: 'Gmarket Sans TTF',
              ),
            ),
            Text(
              '정상',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: healthSp(context, 8),
                color: const Color(0xFF94A3B8),
                fontFamily: 'Gmarket Sans TTF',
              ),
            ),
            Text(
              '과체중',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: healthSp(context, 8),
                color: const Color(0xFF94A3B8),
                fontFamily: 'Gmarket Sans TTF',
              ),
            ),
            Text(
              '비만',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: healthSp(context, 8),
                color: const Color(0xFF94A3B8),
                fontFamily: 'Gmarket Sans TTF',
              ),
            ),
            Text(
              '과체중',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: healthSp(context, 8),
                color: const Color(0xFF94A3B8),
                fontFamily: 'Gmarket Sans TTF',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
