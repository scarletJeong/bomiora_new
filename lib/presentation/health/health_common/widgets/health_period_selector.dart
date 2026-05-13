import 'package:flutter/material.dart';

class HealthPeriodSelector extends StatelessWidget {
  final String selectedPeriod;
  final ValueChanged<String> onChanged;
  final List<String> periods;
  final Map<String, String> periodLabels;
  /// true면 테두리·캡슐 배경 없음, 탭 사이 `|` 만 구분
  final bool plainStyle;

  const HealthPeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.onChanged,
    this.periods = const ['일', '주', '월'],
    this.periodLabels = const {
      '일': '시간대별',
      '주': '일자별',
      '월': '월별',
    },
    this.plainStyle = false,
  });

  Widget _tabCell(String periodKey) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(periodKey),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: plainStyle ? 0 : 6,
          ),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                periodLabels[periodKey] ?? periodKey,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 13.33,
                  fontWeight: selectedPeriod == periodKey
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: selectedPeriod == periodKey
                      ? const Color(0xFFFF5A8D)
                      : const Color(0xFF898383),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rowChildren = <Widget>[];
    for (var i = 0; i < periods.length; i++) {
      rowChildren.add(_tabCell(periods[i]));
      if (i != periods.length - 1) {
        if (plainStyle) {
          rowChildren.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '|',
                style: TextStyle(
                  fontSize: 13.33,
                  color: const Color(0xFFB7B7B7),
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          );
        } else {
          rowChildren.add(const SizedBox(width: 6));
        }
      }
    }

    final row = Row(children: rowChildren);

    if (plainStyle) {
      return row;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: row,
    );
  }
}
