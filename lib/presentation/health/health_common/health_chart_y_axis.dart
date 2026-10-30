import 'package:flutter/material.dart';

import '../../common/chart_layout.dart';
import 'health_chart_axis_style.dart';
import 'health_responsive_scale.dart';

/// `(mmHg)` 상단 밴드 높이 (375 기준 16).
double bloodPressureYAxisUnitBandHeight(BuildContext context) =>
    healthDp(context, 16);

/// 체중 그래프 Y축 스트립과 동일 레이아웃: 상단 단위 밴드 + 숫자 눈금
Widget buildBloodPressureYAxisStrip({
  required List<double> yLabels,
  required bool showYAxisHeader,
  String unitLabel = '(mmHg)',
  double tickFontSize = 12,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final totalH = constraints.maxHeight;
      final unitBand = showYAxisHeader && yLabels.length > 1
          ? bloodPressureYAxisUnitBandHeight(context)
          : 0.0;

      Widget numericLabels(double forHeight) {
        final n = yLabels.length;
        if (n < 2) return const SizedBox.shrink();
        return SizedBox(
          height: forHeight,
          child: LayoutBuilder(
            builder: (context, lc) {
              // 플롯 그리드와 Y축 숫자 위치를 일치시킨다.
              final plotTopPad = healthWeightChartVertPad(context);
              final plotBottomPad = healthWeightChartBottomPlotPad(context);
              final labelHalf = healthDp(context, 8);
              final h = lc.maxHeight - plotTopPad - plotBottomPad;
              return Stack(
                clipBehavior: Clip.none,
                children: yLabels.asMap().entries.map((e) {
                  final i = e.key;
                  final label = e.value;
                  final y = plotTopPad + h * i / (n - 1);
                  return Positioned(
                    top: y - labelHalf,
                    left: 0,
                    right: 0,
                    child: Text(
                      label.toStringAsFixed(0),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: healthChartAxisTickTextStyle(
                        context,
                        fontSize: tickFontSize,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        );
      }

      final yAxisW = healthDp(
        context,
        ChartConstants.weightChartYAxisWidth,
      );
      return SizedBox(
        width: yAxisW,
        child: showYAxisHeader && yLabels.length > 1
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: unitBand,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          unitLabel,
                          maxLines: 1,
                          softWrap: false,
                          style: healthChartAxisUnitTextStyle(context),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, inner) {
                        return numericLabels(inner.maxHeight);
                      },
                    ),
                  ),
                ],
              )
            : numericLabels(totalH),
      );
    },
  );
}
