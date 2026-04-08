import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../health_common/widgets/health_date_selector.dart';

/// `yyyy년 M월` + 달력 아이콘. 탭 시 건강 공통 [showHealthDateOnlyPicker] (측정일시 달력과 동일 UI).
class MenstrualCycleDateHeader extends StatelessWidget {
  const MenstrualCycleDateHeader({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    this.monthTextColor = const Color(0xFF898686),
    this.iconColor = const Color(0xFF898686),
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final Color monthTextColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        Text(
          DateFormat('yyyy년 M월').format(selectedDate),
          style: TextStyle(
            color: monthTextColor,
            fontSize: 12,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 3),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showHealthDateOnlyPicker(
              context,
              initialDate: selectedDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(now.year + 10, 12, 31),
            );
            if (picked != null) {
              onDateChanged(picked);
            }
          },
          child: Icon(Icons.calendar_today, size: 12, color: iconColor),
        ),
      ],
    );
  }
}
