import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';

/// 새 측정 기록: 목록에서 보고 있는 날짜에 맞춘 기본 시각 (당일이면 지금, 과거 날짜면 그 날짜+현재 시·분, 미래는 항상 금지).
DateTime healthDefaultNewRecordDateTime(DateTime contextDay) {
  final day = DateUtils.dateOnly(contextDay);
  final now = DateTime.now();
  final today = DateUtils.dateOnly(now);
  if (day == today) return now;
  final candidate =
      DateTime(day.year, day.month, day.day, now.hour, now.minute);
  return candidate.isAfter(now) ? now : candidate;
}

const Color _kAccentPink = Color(0xFFFF5A8D);
const Color _kNavyText = Color(0xFF0E2451);
const Color _kWeekdayMuted = Color(0xFF7E818C);
const Color _kBorderGray = Color(0xFF898383);
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
  /// 선택한 날짜·시간이 이 시각을 넘지 않도록 제한 (보통 `DateTime.now()`: 오늘은 미래 시각 선택 불가).
  DateTime? latestAllowed,
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

  TimeOfDay? maxTime;
  if (latestAllowed != null &&
      DateUtils.isSameDay(pickedDate, latestAllowed)) {
    maxTime = TimeOfDay(
      hour: latestAllowed.hour,
      minute: latestAllowed.minute,
    );
  }
  final pickedTime = await showHealthTimePickerDialog(
    context,
    initialTime: TimeOfDay.fromDateTime(initialDateTime),
    maxTime: maxTime,
  );

  if (pickedTime == null) return null;

  var result = DateTime(
    pickedDate.year,
    pickedDate.month,
    pickedDate.day,
    pickedTime.hour,
    pickedTime.minute,
  );
  if (latestAllowed != null && result.isAfter(latestAllowed)) {
    result = latestAllowed;
  }
  return result;
}

/// 시간만 선택 (기존 날짜는 호출 측에서 유지)
Future<TimeOfDay?> showHealthTimePickerDialog(
  BuildContext context, {
  required TimeOfDay initialTime,
  /// 오늘 날짜일 때 상한(포함). null이면 23:59까지 선택 가능.
  TimeOfDay? maxTime,
}) {
  return showDialog<TimeOfDay>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.2),
    builder: (ctx) =>
        _HealthTimePickerDialog(initialTime: initialTime, maxTime: maxTime),
  );
}

/// 날짜만 선택 (목록·대시보드 헤더 등). [showHealthDateThenTimePickers]와 동일한 달력 UI.
Future<DateTime?> showHealthDateOnlyPicker(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final first = DateUtils.dateOnly(firstDate ?? DateTime(2020));
  final last = DateUtils.dateOnly(lastDate ?? DateTime.now());
  var initial = DateUtils.dateOnly(initialDate);
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;

  return showDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.2),
    builder: (ctx) => _HealthDatePickerDialog(
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    ),
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
                                          ? () {
                                              // 날짜 1회 탭 즉시 선택 + 팝업 닫기
                                              _selectedDate = date;
                                              Navigator.of(context).pop(date);
                                            }
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
  final TimeOfDay? maxTime;

  const _HealthTimePickerDialog({
    required this.initialTime,
    this.maxTime,
  });

  @override
  State<_HealthTimePickerDialog> createState() => _HealthTimePickerDialogState();
}

class _HealthTimePickerDialogState extends State<_HealthTimePickerDialog> {
  static const double _itemExtent = 44;
  static const int _wheelTickDebounceMs = 70;

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late int _hour;
  late int _minute;
  int _lastHourWheelTickMs = 0;
  int _lastMinuteWheelTickMs = 0;

  int get _hourCount {
    final m = widget.maxTime;
    if (m == null) return 24;
    return (m.hour + 1).clamp(1, 24);
  }

  int _minuteCountForHour(int hour) {
    final m = widget.maxTime;
    if (m == null) return 60;
    if (hour < m.hour) return 60;
    return (m.minute + 1).clamp(1, 60);
  }

  void _clampSelectionToMax() {
    final m = widget.maxTime;
    if (m == null) return;
    if (_hour > m.hour) _hour = m.hour;
    final maxMin = _minuteCountForHour(_hour) - 1;
    if (_minute > maxMin) _minute = maxMin;
  }

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _clampSelectionToMax();
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
                                child: Listener(
                                  onPointerSignal: (event) {
                                    if (!kIsWeb || event is! PointerScrollEvent) return;
                                    final nowMs =
                                        DateTime.now().millisecondsSinceEpoch;
                                    if (nowMs - _lastHourWheelTickMs <
                                        _wheelTickDebounceMs) {
                                      return;
                                    }
                                    _lastHourWheelTickMs = nowMs;
                                    final delta = event.scrollDelta.dy > 0 ? 1 : -1;
                                    _changeHourBy(delta);
                                  },
                                  child: ListWheelScrollView.useDelegate(
                                    controller: _hourController,
                                    itemExtent: _itemExtent,
                                    physics: kIsWeb
                                        ? const NeverScrollableScrollPhysics()
                                        : const FixedExtentScrollPhysics(),
                                    perspective: 0.003,
                                    diameterRatio: 1.6,
                                    onSelectedItemChanged: (i) {
                                      final nextHour = i.clamp(0, _hourCount - 1);
                                      if (nextHour == _hour) return;
                                      final beforeCount = _minuteCountForHour(_hour);
                                      setState(() {
                                        _hour = nextHour;
                                        final afterCount = _minuteCountForHour(_hour);
                                        if (_minute >= afterCount) {
                                          _minute = afterCount - 1;
                                        }
                                      });
                                      final afterCount = _minuteCountForHour(_hour);
                                      if (beforeCount != afterCount) {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          if (!mounted) return;
                                          if (_minuteController.hasClients) {
                                            _minuteController.jumpToItem(_minute);
                                          }
                                        });
                                      }
                                    },
                                    childDelegate:
                                        ListWheelChildBuilderDelegate(
                                      childCount: _hourCount,
                                      builder: (context, index) {
                                        final dist = (index - _hour).abs();
                                        return Center(
                                          child: Text(
                                            index.toString().padLeft(2, '0'),
                                            style: _timeRowStyle(dist),
                                            overflow: TextOverflow.clip,
                                          ),
                                        );
                                      },
                                    ),
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
                                child: Listener(
                                  onPointerSignal: (event) {
                                    if (!kIsWeb || event is! PointerScrollEvent) return;
                                    final nowMs =
                                        DateTime.now().millisecondsSinceEpoch;
                                    if (nowMs - _lastMinuteWheelTickMs <
                                        _wheelTickDebounceMs) {
                                      return;
                                    }
                                    _lastMinuteWheelTickMs = nowMs;
                                    final delta = event.scrollDelta.dy > 0 ? 1 : -1;
                                    _changeMinuteBy(delta);
                                  },
                                  child: ListWheelScrollView.useDelegate(
                                    controller: _minuteController,
                                    itemExtent: _itemExtent,
                                    physics: kIsWeb
                                        ? const NeverScrollableScrollPhysics()
                                        : const FixedExtentScrollPhysics(),
                                    perspective: 0.003,
                                    diameterRatio: 1.6,
                                    onSelectedItemChanged: (i) {
                                      final mc = _minuteCountForHour(_hour);
                                      final nextMinute = i.clamp(0, mc - 1);
                                      if (nextMinute == _minute) return;
                                      setState(() => _minute = nextMinute);
                                    },
                                    childDelegate:
                                        ListWheelChildBuilderDelegate(
                                      childCount: _minuteCountForHour(_hour),
                                      builder: (context, index) {
                                        final dist = (index - _minute).abs();
                                        return Center(
                                          child: Text(
                                            index.toString().padLeft(2, '0'),
                                            style: _timeRowStyle(dist),
                                            overflow: TextOverflow.clip,
                                          ),
                                        );
                                      },
                                    ),
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
    final isSelected = distanceFromSelection == 0;
    return TextStyle(
      color: isSelected
          ? const Color(0xFF1A1A1A)
          : const Color(0xFF1A1A1A).withValues(alpha: 0.58),
      fontSize: 22,
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w300,
    );
  }

  void _changeHourBy(int delta) {
    final nextHour = (_hour + delta).clamp(0, _hourCount - 1);
    if (nextHour == _hour) return;
    final beforeCount = _minuteCountForHour(_hour);
    setState(() {
      _hour = nextHour;
      final afterCount = _minuteCountForHour(_hour);
      if (_minute >= afterCount) {
        _minute = afterCount - 1;
      }
    });
    if (_hourController.hasClients) {
      _hourController.animateToItem(
        _hour,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
      );
    }
    final afterCount = _minuteCountForHour(_hour);
    if (beforeCount != afterCount && _minuteController.hasClients) {
      _minuteController.jumpToItem(_minute);
    }
  }

  void _changeMinuteBy(int delta) {
    final maxMinute = _minuteCountForHour(_hour) - 1;
    final nextMinute = (_minute + delta).clamp(0, maxMinute);
    if (nextMinute == _minute) return;
    setState(() => _minute = nextMinute);
    if (_minuteController.hasClients) {
      _minuteController.animateToItem(
        _minute,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
      );
    }
  }
}

// --- 목록 상단: 월 표시 + 어제/오늘/내일 + 달력 아이콘 ---

class HealthDateSelector extends StatelessWidget {
  const HealthDateSelector({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    this.monthTextColor = const Color(0xFF898686),
    this.selectedTextColor = const Color(0xFFFF5A8D),
    this.unselectedTextColor = const Color(0xFFD3D3D3),
    this.dividerColor = const Color(0xFFDCDCDC),
    this.iconColor = const Color(0xFF898686),
    this.pickerFirstDate,
    this.pickerLastDate,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final Color monthTextColor;
  final Color selectedTextColor;
  final Color unselectedTextColor;
  final Color dividerColor;
  final Color iconColor;
  /// null이면 [showHealthDateOnlyPicker] 기본값(2020 ~ 오늘)
  final DateTime? pickerFirstDate;
  final DateTime? pickerLastDate;

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
                final picked = await showHealthDateOnlyPicker(
                  context,
                  initialDate: selectedDate,
                  firstDate: pickerFirstDate,
                  lastDate: pickerLastDate,
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
                        color: dividerColor.withValues(alpha: 0.45),
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
                        color: dividerColor.withValues(alpha: 0.45),
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
                        Colors.white.withValues(alpha: 0.28),
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.28),
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
