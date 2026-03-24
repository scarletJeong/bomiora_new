import 'package:flutter/material.dart';

import '../../../common/chart_layout.dart';

/// 체중·심박수 일간 그래프용: Y축 상단 단위 밴드 + 숫자 눈금 ([PeriodChartWidget]·체중 차트와 동일 레이아웃)
Widget buildChartYAxisStripWithUnit({
  required List<double> yLabels,
  required bool showUnitHeader,
  String unitLabel = '(kg)',
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final totalH = constraints.maxHeight;
      final unitBand =
          showUnitHeader && yLabels.length > 1 ? totalH / 6.0 : 0.0;

      Widget numericLabels(double forHeight) {
        final n = yLabels.length;
        if (n < 2) return const SizedBox.shrink();
        return SizedBox(
          height: forHeight,
          child: LayoutBuilder(
            builder: (context, lc) {
              const topPad = 6.0;
              const botPad = 6.0;
              final h = lc.maxHeight - topPad - botPad;
              return Stack(
                clipBehavior: Clip.none,
                children: yLabels.asMap().entries.map((e) {
                  final i = e.key;
                  final label = e.value;
                  final y = topPad + h * i / (n - 1);
                  return Positioned(
                    top: y - 8,
                    left: 0,
                    right: 0,
                    child: Text(
                      label.toStringAsFixed(0),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        );
      }

      return SizedBox(
        width: ChartConstants.weightChartYAxisWidth,
        child: showUnitHeader && yLabels.length > 1
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: unitBand,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Text(
                        unitLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
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
