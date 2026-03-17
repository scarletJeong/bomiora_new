import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HealthDateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final Color monthTextColor;
  final Color selectedTextColor;
  final Color unselectedTextColor;
  final Color dividerColor;
  final Color iconColor;
  final Color selectedDayBackgroundColor;

  const HealthDateSelector({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    this.monthTextColor = const Color(0xFF898686),
    this.selectedTextColor = const Color(0xFFFF5A8D),
    this.unselectedTextColor = const Color(0xFFD3D3D3),
    this.dividerColor = const Color(0xFFDCDCDC),
    this.iconColor = const Color(0xFF898686),
    this.selectedDayBackgroundColor = const Color(0xFFFF5A8D),
  });

  List<DateTime> get _displayDates => [
        selectedDate.subtract(const Duration(days: 1)),
        selectedDate,
        selectedDate.add(const Duration(days: 1)),
      ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
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
                final picked = await showDialog<DateTime>(
                  context: context,
                  barrierColor: Colors.white.withOpacity(0.45),
                  builder: (dialogContext) {
                    return _HealthMiniCalendarDialog(
                      initialDate: selectedDate,
                      selectedDayBackgroundColor: selectedDayBackgroundColor,
                    );
                  },
                );
                if (picked != null) {
                  onDateChanged(picked);
                }
              },
              child: Icon(Icons.calendar_today, size: 12, color: iconColor),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _buildDateText(
                      date: _displayDates[0],
                      isSelected: false,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: dividerColor.withOpacity(0.45),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildDateText(
                      date: _displayDates[1],
                      isSelected: true,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: dividerColor.withOpacity(0.45),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildDateText(
                      date: _displayDates[2],
                      isSelected: false,
                    ),
                  ],
                ),
              ),
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white.withOpacity(0.28),
                        Colors.white.withOpacity(0.10),
                        Colors.white.withOpacity(0.0),
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.28),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateText({
    required DateTime date,
    required bool isSelected,
  }) {
    final text = '${DateFormat('M.d').format(date)} ${_weekdayLabel(date)}';
    return GestureDetector(
      onTap: () => onDateChanged(date),
      child: Text(
        text,
        style: TextStyle(
          color: isSelected ? selectedTextColor : unselectedTextColor,
          fontSize: isSelected ? 20 : 16,
          height: 1.0,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w300,
        ),
      ),
    );
  }

  String _weekdayLabel(DateTime date) {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return labels[date.weekday - 1];
  }
}

class _HealthMiniCalendarDialog extends StatefulWidget {
  final DateTime initialDate;
  final Color selectedDayBackgroundColor;

  const _HealthMiniCalendarDialog({
    required this.initialDate,
    required this.selectedDayBackgroundColor,
  });

  @override
  State<_HealthMiniCalendarDialog> createState() =>
      _HealthMiniCalendarDialogState();
}

class _HealthMiniCalendarDialogState extends State<_HealthMiniCalendarDialog> {
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    _displayMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
  }

  @override
  Widget build(BuildContext context) {
    final cells = _buildCells();
    const weekdays = ['일', '월', '화', '수', '목', '금', '토'];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        width: 220,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0x1C959595),
              blurRadius: 12,
              offset: const Offset(4, 2),
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _displayMonth =
                          DateTime(_displayMonth.year, _displayMonth.month - 1);
                    });
                  },
                  icon: const Icon(Icons.chevron_left, size: 16),
                  visualDensity:
                      const VisualDensity(horizontal: -4, vertical: -4),
                ),
                Expanded(
                  child: Text(
                    DateFormat('yyyy년 M월').format(_displayMonth),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF0E2451),
                      fontSize: 11,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _displayMonth =
                          DateTime(_displayMonth.year, _displayMonth.month + 1);
                    });
                  },
                  icon: const Icon(Icons.chevron_right, size: 16),
                  visualDensity:
                      const VisualDensity(horizontal: -4, vertical: -4),
                ),
              ],
            ),
            const Divider(height: 1, color: Color(0xFFE4E5E7)),
            const SizedBox(height: 6),
            Row(
              children: weekdays
                  .map(
                    (day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: const TextStyle(
                            color: Color(0xFF7E818C),
                            fontSize: 10,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cells.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1.2,
              ),
              itemBuilder: (context, index) {
                final cell = cells[index];
                if (!cell.inMonth) return const SizedBox.shrink();

                final isSelected = _isSameDate(cell.date!, widget.initialDate);
                return InkWell(
                  onTap: () => Navigator.of(context).pop(cell.date),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? widget.selectedDayBackgroundColor
                          : Colors.transparent,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${cell.date!.day}',
                      style: TextStyle(
                        color:
                            isSelected ? Colors.white : const Color(0xFF0E2451),
                        fontSize: 11,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<_CalendarCell> _buildCells() {
    final firstDay = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final firstWeekdaySundayBase = firstDay.weekday % 7; // 일=0
    final daysInMonth =
        DateTime(_displayMonth.year, _displayMonth.month + 1, 0).day;

    final cells = <_CalendarCell>[];
    for (int i = 0; i < 42; i++) {
      final day = i - firstWeekdaySundayBase + 1;
      if (day < 1 || day > daysInMonth) {
        cells.add(const _CalendarCell(inMonth: false, date: null));
      } else {
        cells.add(
          _CalendarCell(
            inMonth: true,
            date: DateTime(_displayMonth.year, _displayMonth.month, day),
          ),
        );
      }
    }
    return cells;
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _CalendarCell {
  final bool inMonth;
  final DateTime? date;

  const _CalendarCell({
    required this.inMonth,
    required this.date,
  });
}
