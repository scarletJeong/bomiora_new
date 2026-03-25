import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color _kAccentPink = Color(0xFFFF5A8D);
const Color _kNavyText = Color(0xFF0E2451);
const Color _kWeekdayMuted = Color(0xFF7E818C);
const Color _kBorderGray = Color(0xFF898383);
const Color _kTimeMuted = Color(0xFF898686);
const Color _kTimeBorder = Color(0xFF8B8B8B);

/// [Dialog.insetPadding] 좌우 합만큼 뺀 뒤, [maxCap]을 넘지 않게 함 (최소 너비 강제로 오버플로 방지)
double _healthDialogMaxWidth(
  BuildContext context, {
  required double horizontalInsetTotal,
  double maxCap = 360,
  double minCap = 200,
}) {
  final sw = MediaQuery.sizeOf(context).width;
  final raw = sw - horizontalInsetTotal;
  if (!raw.isFinite || raw <= 0) return minCap;
  return raw.clamp(minCap, maxCap);
}

/// 측정일시: 날짜 선택 후 이어서 시간 선택 다이얼로그를 띄웁니다.
Future<DateTime?> showHealthDateThenTimePickers(
  BuildContext context, {
  required DateTime initialDateTime,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final first = DateUtils.dateOnly(firstDate ?? DateTime(2020));
  final last = DateUtils.dateOnly(lastDate ?? DateTime.now());
  var initial = DateUtils.dateOnly(initialDateTime);
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;

  final pickedDate = await showDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.2),
    builder: (ctx) => _HealthDatePickerDialog(
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    ),
  );

  if (pickedDate == null || !context.mounted) return null;

  final pickedTime = await showHealthTimePickerDialog(
    context,
    initialTime: TimeOfDay.fromDateTime(initialDateTime),
  );

  if (pickedTime == null) return null;

  return DateTime(
    pickedDate.year,
    pickedDate.month,
    pickedDate.day,
    pickedTime.hour,
    pickedTime.minute,
  );
}

/// 시간만 선택 (기존 날짜는 호출 측에서 유지)
Future<TimeOfDay?> showHealthTimePickerDialog(
  BuildContext context, {
  required TimeOfDay initialTime,
}) {
  return showDialog<TimeOfDay>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.2),
    builder: (ctx) => _HealthTimePickerDialog(initialTime: initialTime),
  );
}

// --- 날짜 ---

class _HealthDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const _HealthDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_HealthDatePickerDialog> createState() =>
      _HealthDatePickerDialogState();
}

class _HealthDatePickerDialogState extends State<_HealthDatePickerDialog> {
  late DateTime _focusedMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _focusedMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
  }

  int _daysInMonth(DateTime m) => DateTime(m.year, m.month + 1, 0).day;

  /// 일요일 시작: leading 빈 칸 수
  int _leadingBlanks(DateTime monthStart) {
    final w = monthStart.weekday; // Mon=1 .. Sun=7
    return w % 7;
  }

  bool _isSelectable(DateTime d) =>
      !d.isBefore(widget.firstDate) && !d.isAfter(widget.lastDate);

  DateTime _firstSelectableInFocusedMonth() {
    final dim = _daysInMonth(_focusedMonth);
    for (var d = 1; d <= dim; d++) {
      final dt = DateTime(_focusedMonth.year, _focusedMonth.month, d);
      if (_isSelectable(dt)) return dt;
    }
    return widget.firstDate;
  }

  void _syncSelectionToFocusedMonth() {
    if (_selectedDate.year == _focusedMonth.year &&
        _selectedDate.month == _focusedMonth.month) {
      if (_isSelectable(_selectedDate)) return;
      _selectedDate = _firstSelectableInFocusedMonth();
      return;
    }
    _selectedDate = _firstSelectableInFocusedMonth();
  }

  void _prevMonth() {
    if (!_canPrevMonth) return;
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month - 1);
      _syncSelectionToFocusedMonth();
    });
  }

  void _nextMonth() {
    if (!_canNextMonth) return;
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + 1);
      _syncSelectionToFocusedMonth();
    });
  }

  /// 이전 달 마지막 날이 firstDate 이상이면 이동 가능
  bool get _canPrevMonth {
    final lastPrev = DateTime(_focusedMonth.year, _focusedMonth.month, 0);
    return !lastPrev.isBefore(widget.firstDate);
  }

  /// 다음 달 1일이 lastDate 이하이면 이동 가능
  bool get _canNextMonth {
    final firstNext =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    return !firstNext.isAfter(widget.lastDate);
  }

  @override
  Widget build(BuildContext context) {
    // insetPadding horizontal 24 + 24
    final cardW = _healthDialogMaxWidth(
      context,
      horizontalInsetTotal: 48,
      maxCap: 340,
      minCap: 240,
    );

    final monthStart = DateTime(_focusedMonth.year, _focusedMonth.month);
    final dim = _daysInMonth(monthStart);
    final leading = _leadingBlanks(monthStart);
    final totalCells = leading + dim;
    final rows = (totalCells / 7).ceil();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cardW),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1C959595),
                    blurRadius: 23,
                    offset: Offset(8, 3),
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat('yyyy년 M월', 'ko_KR')
                                .format(_focusedMonth),
                            textAlign: TextAlign.start,
                            style: const TextStyle(
                              color: _kNavyText,
                              fontSize: 15,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.15,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              onPressed: _canPrevMonth ? _prevMonth : null,
                              icon: Icon(
                                Icons.chevron_left,
                                color: _canPrevMonth
                                    ? _kNavyText
                                    : _kWeekdayMuted.withValues(alpha: 0.4),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              onPressed: _canNextMonth ? _nextMonth : null,
                              icon: Icon(
                                Icons.chevron_right,
                                color: _canNextMonth
                                    ? _kNavyText
                                    : _kWeekdayMuted.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24, thickness: 0.84, color: Color(0xFFE4E5E7)),
                    Row(
                      children: ['일', '월', '화', '수', '목', '금', '토']
                          .map(
                            (d) => Expanded(
                              child: Text(
                                d,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _kWeekdayMuted,
                                  fontSize: 11,
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(rows, (row) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: List.generate(7, (col) {
                            final i = row * 7 + col - leading;
                            if (i < 0 || i >= dim) {
                              return const Expanded(
                                child: SizedBox(height: 32),
                              );
                            }
                            final day = i + 1;
                            final date =
                                DateTime(_focusedMonth.year, _focusedMonth.month, day);
                            final selectable = _isSelectable(date);
                            final isSel = DateUtils.isSameDay(date, _selectedDate);
                            final isToday = DateUtils.isSameDay(date, DateTime.now());

                            return Expanded(
                              child: SizedBox(
                                height: 32,
                                child: Center(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: selectable
                                          ? () =>
                                              setState(() => _selectedDate = date)
                                          : null,
                                      customBorder: const CircleBorder(),
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isSel ? _kAccentPink : null,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '$day',
                                          style: TextStyle(
                                            color: !selectable
                                                ? _kWeekdayMuted
                                                    .withValues(alpha: 0.35)
                                                : isSel
                                                    ? const Color(0xFFFCFCFC)
                                                    : isToday
                                                        ? _kNavyText
                                                        : _kNavyText,
                                            fontSize: 14,
                                            fontFamily: 'Gmarket Sans TTF',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _kBorderGray,
                              side: const BorderSide(
                                color: _kBorderGray,
                                width: 0.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              '닫기',
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.pop(context, _selectedDate),
                            style: FilledButton.styleFrom(
                              backgroundColor: _kAccentPink,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              '등록',
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 시간 ---

class _HealthTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;

  const _HealthTimePickerDialog({required this.initialTime});

  @override
  State<_HealthTimePickerDialog> createState() => _HealthTimePickerDialogState();
}

class _HealthTimePickerDialogState extends State<_HealthTimePickerDialog> {
  static const double _itemExtent = 44;

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // insetPadding horizontal 16 + 16 — cardW가 이 값보다 크면 RenderFlex 오버플로(약 12px 등) 발생
    final cardW = _healthDialogMaxWidth(
      context,
      horizontalInsetTotal: 32,
      maxCap: 360,
      minCap: 200,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cardW),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 16, 13, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _itemExtent * 4 + 8,
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final innerW = constraints.maxWidth;
                    return Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        IgnorePointer(
                          child: Center(
                            child: Container(
                              height: _itemExtent,
                              width: innerW * 0.88,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _kTimeBorder,
                                  width: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: _itemExtent * 4,
                                child: ListWheelScrollView.useDelegate(
                                  controller: _hourController,
                                  itemExtent: _itemExtent,
                                  physics: const FixedExtentScrollPhysics(),
                                  perspective: 0.003,
                                  diameterRatio: 1.6,
                                  onSelectedItemChanged: (i) {
                                    setState(() => _hour = i.clamp(0, 23));
                                  },
                                  childDelegate:
                                      ListWheelChildBuilderDelegate(
                                    childCount: 24,
                                    builder: (context, index) {
                                      final dist = (index - _hour)
                                          .abs()
                                          .clamp(0, 2);
                                      final style = _timeRowStyle(dist);
                                      return Center(
                                        child: Text(
                                          index.toString().padLeft(2, '0'),
                                          style: style,
                                          overflow: TextOverflow.clip,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                ':',
                                style: _timeRowStyle(0),
                              ),
                            ),
                            Expanded(
                              child: SizedBox(
                                height: _itemExtent * 4,
                                child: ListWheelScrollView.useDelegate(
                                  controller: _minuteController,
                                  itemExtent: _itemExtent,
                                  physics: const FixedExtentScrollPhysics(),
                                  perspective: 0.003,
                                  diameterRatio: 1.6,
                                  onSelectedItemChanged: (i) {
                                    setState(
                                        () => _minute = i.clamp(0, 59));
                                  },
                                  childDelegate:
                                      ListWheelChildBuilderDelegate(
                                    childCount: 60,
                                    builder: (context, index) {
                                      final dist = (index - _minute)
                                          .abs()
                                          .clamp(0, 2);
                                      final style = _timeRowStyle(dist);
                                      return Center(
                                        child: Text(
                                          index.toString().padLeft(2, '0'),
                                          style: style,
                                          overflow: TextOverflow.clip,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kBorderGray,
                        side: const BorderSide(
                          color: _kBorderGray,
                          width: 0.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        '닫기',
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          TimeOfDay(hour: _hour, minute: _minute),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _kAccentPink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        '등록',
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _timeRowStyle(int distanceFromSelection) {
    switch (distanceFromSelection) {
      case 0:
        return const TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 24,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        );
      case 1:
        return const TextStyle(
          color: _kTimeMuted,
          fontSize: 20,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w300,
        );
      default:
        return const TextStyle(
          color: _kTimeMuted,
          fontSize: 16,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w300,
        );
    }
  }
}
