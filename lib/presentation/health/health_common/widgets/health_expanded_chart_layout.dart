import 'package:flutter/material.dart';

/// 확대 차트 레이아웃 수치 — Figma·참고 코드 기준 폭 **650**.
///
/// 웹 팝업 외곽은 1300px이어도, 탭·버튼·범례 수치는 **650 논리 폭** 기준으로만
/// 스케일합니다. (1300에 다시 곱하지 않음)
class HealthExpandedChartMetrics {
  const HealthExpandedChartMetrics(this.layoutWidth);

  static const double designWidth = 650;

  /// 기간 탭 라벨 — 650 기준 20
  static const double periodTabFontSize = 20;

  /// 축소 버튼 — 650 기준 (탭보다 작게)
  static const double shrinkButtonFontSize = 16;
  static const double shrinkButtonHPadding = 10;
  static const double shrinkButtonVPadding = 5;
  static const double shrinkButtonRadius = 10;
  static const double shrinkButtonBarHeight = 26;
  static const double shrinkButtonBarWidth = 2.5;
  static const double shrinkButtonLeadingGap = 10;

  /// X축 라벨 하단 ~ 범례 상단 (650 기준)
  static const double chartToLegendGap = 17;

  /// 범례가 있는 확대 그래프 차트 높이 (650 기준)
  static const double chartHeightWithLegend = 495;

  /// 범례가 없는 확대 그래프 차트 높이 (650 기준)
  static const double chartHeightWithoutLegend = 537;

  final double layoutWidth;

  double get scale => layoutWidth / designWidth;

  /// [atDesign650]: 650px 레이아웃 기준 수치.
  double d(double atDesign650) => atDesign650 * scale;
}

/// 탭·축소·범례용 metrics (폭 375~650으로 클램프)
HealthExpandedChartMetrics healthExpandedChartMetrics(double rawLayoutWidth) {
  return HealthExpandedChartMetrics(
    rawLayoutWidth.clamp(375.0, HealthExpandedChartMetrics.designWidth),
  );
}

/// 확대 화면 기간 탭 (시간대별 | 일자별 | 월별)
class HealthExpandedPeriodSelector extends StatelessWidget {
  final String selectedPeriod;
  final ValueChanged<String> onChanged;
  final List<String> periods;
  final Map<String, String> periodLabels;
  final HealthExpandedChartMetrics metrics;

  const HealthExpandedPeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.onChanged,
    required this.metrics,
    this.periods = const ['일', '주', '월'],
    this.periodLabels = const {
      '일': '시간대별',
      '주': '일자별',
      '월': '월별',
    },
  });

  @override
  Widget build(BuildContext context) {
    final tabGap = metrics.d(35.23);
    final dividerW = metrics.d(0.88);
    final dividerH = metrics.d(19.38);
    final tabBottomPad = metrics.d(8.81);
    final borderW = metrics.d(1.76);
    final fontSize = metrics.d(HealthExpandedChartMetrics.periodTabFontSize);

    final tabs = <Widget>[];
    for (var i = 0; i < periods.length; i++) {
      final key = periods[i];
      final selected = selectedPeriod == key;
      tabs.add(
        GestureDetector(
          onTap: () => onChanged(key),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: EdgeInsets.only(bottom: tabBottomPad),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  width: borderW,
                  color:
                      selected ? const Color(0xFFFF5A8D) : Colors.transparent,
                ),
              ),
            ),
            child: Text(
              periodLabels[key] ?? key,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: selected
                    ? const Color(0xFFFF5A8D)
                    : const Color(0xFF898383),
                fontSize: fontSize,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
      if (i != periods.length - 1) {
        tabs.add(SizedBox(width: tabGap));
        tabs.add(
          Container(
            width: dividerW,
            height: dividerH,
            color: const Color(0xFFD2D2D2),
          ),
        );
        tabs.add(SizedBox(width: tabGap));
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: tabs,
    );
  }
}

/// 확대 화면 「축소」 버튼
class HealthExpandedShrinkButton extends StatelessWidget {
  final VoidCallback onPressed;
  final HealthExpandedChartMetrics metrics;

  const HealthExpandedShrinkButton({
    super.key,
    required this.onPressed,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final barW = metrics.d(HealthExpandedChartMetrics.shrinkButtonBarWidth);
    final barH = metrics.d(HealthExpandedChartMetrics.shrinkButtonBarHeight);
    final gap = metrics.d(HealthExpandedChartMetrics.shrinkButtonLeadingGap);
    final hPad = metrics.d(HealthExpandedChartMetrics.shrinkButtonHPadding);
    final vPad = metrics.d(HealthExpandedChartMetrics.shrinkButtonVPadding);
    final radius = metrics.d(HealthExpandedChartMetrics.shrinkButtonRadius);
    final fontSize = metrics.d(HealthExpandedChartMetrics.shrinkButtonFontSize);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: barW,
          height: barH,
          color: const Color(0xFFD9D9D9),
        ),
        SizedBox(width: gap),
        Material(
          color: const Color(0xFFFF5A8D),
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(radius),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
              child: Text(
                '축소',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 확대 화면 범례 한 항목
class HealthExpandedChartLegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final HealthExpandedChartMetrics metrics;

  const HealthExpandedChartLegendItem({
    super.key,
    required this.color,
    required this.label,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final dot = metrics.d(21.14);
    final gap = metrics.d(8.81);
    final fontSize = metrics.d(21.14);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: dot,
          height: dot,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: gap),
        Text(
          label,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
