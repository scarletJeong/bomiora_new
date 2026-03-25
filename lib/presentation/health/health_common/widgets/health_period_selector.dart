import 'package:flutter/material.dart';

class HealthPeriodSelector extends StatelessWidget {
  final String selectedPeriod;
  final ValueChanged<String> onChanged;
  final List<String> periods;
  final Map<String, String> periodLabels;

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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < periods.length; i++) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(periods[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        periodLabels[periods[i]] ?? periods[i],
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 13.33,
                          fontWeight: selectedPeriod == periods[i]
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selectedPeriod == periods[i]
                              ? const Color(0xFFFF5A8D)
                              : const Color(0xFF898383),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (i != periods.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}
