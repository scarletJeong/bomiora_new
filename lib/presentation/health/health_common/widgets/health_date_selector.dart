import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_assets.dart';
import '../health_responsive_scale.dart';

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
  double maxCapBase = 360,
  double minCapBase = 200,
}) {
  final maxCap = healthDp(context, maxCapBase);
  final minCap = healthDp(context, minCapBase);
  final sw = MediaQuery.sizeOf(context).width;
  final raw = sw - horizontalInsetTotal;
  if (!raw.isFinite || raw <= 0) return minCap;
  return raw.clamp(minCap, maxCap);
}

/// 날짜·시간 선택 Dialog — 뒤 화면 블러 + 딤 처리.
Future<T?> _showHealthPickerDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final blurSigma = healthDp(dialogContext, 1.8);
      return Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                behavior: HitTestBehavior.opaque,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.20),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: Offset(0, -healthDp(dialogContext, 60)),
                child: builder(dialogContext),
              ),
            ),
          ],
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ),
        child: child,
      );
    },
  );
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

  final pickedDate = await _showHealthPickerDialog<DateTime>(
    context: context,
    builder: (ctx) => _HealthDatePickerDialog(
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    ),
  );

  if (pickedDate == null || !context.mounted) return null;

  TimeOfDay? maxTime;
  if (latestAllowed != null && DateUtils.isSameDay(pickedDate, latestAllowed)) {
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
  return _showHealthPickerDialog<TimeOfDay>(
    context: context,
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

  return _showHealthPickerDialog<DateTime>(
    context: context,
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
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
      _syncSelectionToFocusedMonth();
    });
  }

  void _nextMonth() {
    if (!_canNextMonth) return;
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
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
    final firstNext = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    return !firstNext.isAfter(widget.lastDate);
  }

  @override
  Widget build(BuildContext context) {
    final dialogInset = healthDp(context, 24);
    // insetPadding horizontal 24 + 24
    final cardW = _healthDialogMaxWidth(
      context,
      horizontalInsetTotal: dialogInset * 2,
      maxCapBase: 340,
      minCapBase: 240,
    );

    final monthStart = DateTime(_focusedMonth.year, _focusedMonth.month);
    final dim = _daysInMonth(monthStart);
    final leading = _leadingBlanks(monthStart);
    final totalCells = leading + dim;
    final rows = (totalCells / 7).ceil();

    final cardRadius = healthDp(context, 17);
    final cardPad = EdgeInsets.fromLTRB(
      healthDp(context, 20),
      healthDp(context, 20),
      healthDp(context, 20),
      healthDp(context, 16),
    );
    final monthTitleFs = healthSp(context, 14);
    final navBtnSize = healthDp(context, 36);
    final navIconSize = healthDp(context, 24);
    final dividerH = healthDp(context, 24);
    final dividerThickness = healthDp(context, 0.84);
    final weekdayFs = healthSp(context, 10);
    final weekGap = healthDp(context, 8);
    final rowBottomPad = healthDp(context, 6);
    final rowH = healthDp(context, 32);
    final dayCellSize = healthDp(context, 30);
    final dayFs = healthSp(context, 14);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: dialogInset,
        vertical: dialogInset,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cardW),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(cardRadius),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x1C959595),
                    blurRadius: healthDp(context, 23),
                    offset: Offset(healthDp(context, 8), healthDp(context, 3)),
                    spreadRadius: healthDp(context, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: cardPad,
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
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(
                              color: _kNavyText,
                              fontSize: monthTitleFs,
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
                              constraints: BoxConstraints(
                                minWidth: navBtnSize,
                                minHeight: navBtnSize,
                              ),
                              onPressed: _canPrevMonth ? _prevMonth : null,
                              icon: Icon(
                                Icons.chevron_left,
                                size: navIconSize,
                                color: _canPrevMonth
                                    ? _kNavyText
                                    : _kWeekdayMuted.withValues(alpha: 0.4),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(
                                minWidth: navBtnSize,
                                minHeight: navBtnSize,
                              ),
                              onPressed: _canNextMonth ? _nextMonth : null,
                              icon: Icon(
                                Icons.chevron_right,
                                size: navIconSize,
                                color: _canNextMonth
                                    ? _kNavyText
                                    : _kWeekdayMuted.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Divider(
                      height: dividerH,
                      thickness: dividerThickness,
                      color: const Color(0xFFE4E5E7),
                    ),
                    Row(
                      children: ['일', '월', '화', '수', '목', '금', '토']
                          .map(
                            (d) => Expanded(
                              child: Text(
                                d,
                                textAlign: TextAlign.center,
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  color: _kWeekdayMuted,
                                  fontSize: weekdayFs,
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    SizedBox(height: weekGap),
                    ...List.generate(rows, (row) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: rowBottomPad),
                        child: Row(
                          children: List.generate(7, (col) {
                            final i = row * 7 + col - leading;
                            if (i < 0 || i >= dim) {
                              return Expanded(
                                child: SizedBox(height: rowH),
                              );
                            }
                            final day = i + 1;
                            final date = DateTime(
                                _focusedMonth.year, _focusedMonth.month, day);
                            final selectable = _isSelectable(date);
                            final isSel =
                                DateUtils.isSameDay(date, _selectedDate);
                            final isToday =
                                DateUtils.isSameDay(date, DateTime.now());

                            return Expanded(
                              child: SizedBox(
                                height: rowH,
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
                                        width: dayCellSize,
                                        height: dayCellSize,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isSel ? _kAccentPink : null,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '$day',
                                          textScaler: TextScaler.noScaling,
                                          style: TextStyle(
                                            color: !selectable
                                                ? _kWeekdayMuted.withValues(
                                                    alpha: 0.35)
                                                : isSel
                                                    ? const Color(0xFFFCFCFC)
                                                    : isToday
                                                        ? _kNavyText
                                                        : _kNavyText,
                                            fontSize: dayFs,
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
  State<_HealthTimePickerDialog> createState() =>
      _HealthTimePickerDialogState();
}

class _HealthTimePickerDialogState extends State<_HealthTimePickerDialog> {
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
    final dialogInsetH = healthDp(context, 16);
    final dialogInsetV = healthDp(context, 24);
    final wheelAreaH = healthDp(context, 200);
    final itemExtent = healthDp(context, 44);
    final wheelVisibleRows = 4;
    final cardPad = EdgeInsets.fromLTRB(
      healthDp(context, 13),
      healthDp(context, 18),
      healthDp(context, 13),
      healthDp(context, 18),
    );
    final cardRadius = healthDp(context, 16);
    final wheelBorderW = healthDp(context, 0.5);
    final wheelColW = healthDp(context, 48);
    final colonGapW = healthDp(context, 60);
    final wheelsStripW = wheelColW * 2 + colonGapW;
    final btnGap = healthDp(context, 10);
    final btnRowH = healthDp(context, 38);
    final btnRadius = healthDp(context, 10);
    final btnFontSize = healthSp(context, 16);
    final actionsTopGap = healthDp(context, 16);
    final wheelExtraH = wheelAreaH - itemExtent * wheelVisibleRows;

    // insetPadding horizontal 16 + 16 — cardW가 이 값보다 크면 RenderFlex 오버플로(약 12px 등) 발생
    final cardW = _healthDialogMaxWidth(
      context,
      horizontalInsetTotal: dialogInsetH * 2,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: dialogInsetH,
        vertical: dialogInsetV,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cardW),
        child: Container(
          padding: cardPad,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(cardRadius),
            boxShadow: [
              BoxShadow(
                color: const Color(0x24000000),
                blurRadius: healthDp(context, 16),
                offset: Offset(0, healthDp(context, 6)),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: wheelAreaH,
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final highlightBorder = BorderSide(
                      color: _kTimeBorder,
                      width: wheelBorderW,
                    );
                    return Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        IgnorePointer(
                          child: Center(
                            child: Container(
                              height: itemExtent,
                              width: wheelsStripW,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                  top: highlightBorder,
                                  bottom: highlightBorder,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: wheelColW,
                                height: itemExtent * wheelVisibleRows,
                                child: Listener(
                                  onPointerSignal: (event) {
                                    if (!kIsWeb || event is! PointerScrollEvent)
                                      return;
                                    final nowMs =
                                        DateTime.now().millisecondsSinceEpoch;
                                    if (nowMs - _lastHourWheelTickMs <
                                        _wheelTickDebounceMs) {
                                      return;
                                    }
                                    _lastHourWheelTickMs = nowMs;
                                    final delta =
                                        event.scrollDelta.dy > 0 ? 1 : -1;
                                    _changeHourBy(delta);
                                  },
                                  child: ListWheelScrollView.useDelegate(
                                    controller: _hourController,
                                    itemExtent: itemExtent,
                                    physics: kIsWeb
                                        ? const NeverScrollableScrollPhysics()
                                        : const FixedExtentScrollPhysics(),
                                    perspective: 0.003,
                                    diameterRatio: 1.6,
                                    onSelectedItemChanged: (i) {
                                      final nextHour =
                                          i.clamp(0, _hourCount - 1);
                                      if (nextHour == _hour) return;
                                      final beforeCount =
                                          _minuteCountForHour(_hour);
                                      setState(() {
                                        _hour = nextHour;
                                        final afterCount =
                                            _minuteCountForHour(_hour);
                                        if (_minute >= afterCount) {
                                          _minute = afterCount - 1;
                                        }
                                      });
                                      final afterCount =
                                          _minuteCountForHour(_hour);
                                      if (beforeCount != afterCount) {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          if (!mounted) return;
                                          if (_minuteController.hasClients) {
                                            _minuteController
                                                .jumpToItem(_minute);
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
                                            style: _timeRowStyle(context, dist),
                                            overflow: TextOverflow.clip,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: colonGapW,
                                child: Center(
                                  child: Text(
                                    ':',
                                    textScaler: TextScaler.noScaling,
                                    style: _timeRowStyle(context, 0),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: wheelColW,
                                height: itemExtent * wheelVisibleRows,
                                child: Listener(
                                  onPointerSignal: (event) {
                                    if (!kIsWeb || event is! PointerScrollEvent)
                                      return;
                                    final nowMs =
                                        DateTime.now().millisecondsSinceEpoch;
                                    if (nowMs - _lastMinuteWheelTickMs <
                                        _wheelTickDebounceMs) {
                                      return;
                                    }
                                    _lastMinuteWheelTickMs = nowMs;
                                    final delta =
                                        event.scrollDelta.dy > 0 ? 1 : -1;
                                    _changeMinuteBy(delta);
                                  },
                                  child: ListWheelScrollView.useDelegate(
                                    controller: _minuteController,
                                    itemExtent: itemExtent,
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
                                            style: _timeRowStyle(context, dist),
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
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(height: actionsTopGap),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: btnRowH,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kBorderGray,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide(
                            color: _kBorderGray,
                            width: wheelBorderW,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(btnRadius),
                          ),
                        ),
                        child: Text(
                          '닫기',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontSize: btnFontSize,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: btnGap),
                  Expanded(
                    child: SizedBox(
                      height: btnRowH,
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
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(btnRadius),
                          ),
                        ),
                        child: Text(
                          '등록',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontSize: btnFontSize,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
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

  TextStyle _timeRowStyle(BuildContext context, int distanceFromSelection) {
    final isSelected = distanceFromSelection == 0;
    return TextStyle(
      color: isSelected
          ? const Color(0xFF1A1A1A)
          : const Color(0xFF1A1A1A).withValues(alpha: 0.58),
      fontSize: healthSp(context, 22),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: isSelected ? FontWeight.w500 : FontWeight.w300,
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
    this.topGapBase = 20,
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
  final double topGapBase;

  List<DateTime> get _displayDates => [
        selectedDate.subtract(const Duration(days: 1)),
        selectedDate,
        selectedDate.add(const Duration(days: 1)),
      ];

  @override
  Widget build(BuildContext context) {
    // AppBar 하단 ↔ 년·월 밴드 = 20, 년·월 ↔ 날짜 숫자 행 = 5 (375 기준)
    final appBarToMonthGap = healthDp(context, topGapBase);
    final monthFontSize = healthSp(context, 12);
    final monthIconGap = healthDp(context, 3);
    final monthToDateGap = healthDp(context, 5);
    final dateRowH = healthDp(context, 36);
    final dateChipGap = healthDp(context, 8);
    final dateChipFontSize = healthSp(context, 16);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: appBarToMonthGap),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              DateFormat('yyyy년 M월').format(selectedDate),
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: monthTextColor,
                fontSize: monthFontSize,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                height: 1.15,
              ),
            ),
            SizedBox(width: monthIconGap),
            InkWell(
              borderRadius: BorderRadius.circular(healthDp(context, 20)),
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
              child: SizedBox(
                width: healthDp(context, 12),
                height: healthDp(context, 12),
                child: SvgPicture.asset(
                  AppAssets.calendarIcon,
                  width: healthDp(context, 12),
                  height: healthDp(context, 12),
                  fit: BoxFit.contain,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: monthToDateGap),
        SizedBox(
          width: double.infinity,
          height: dateRowH,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
                child: Row(
                  children: [
                    _buildDateText(
                      context,
                      date: _displayDates[0],
                      isSelected: false,
                      fontSize: dateChipFontSize,
                    ),
                    SizedBox(width: dateChipGap),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: dividerColor.withValues(alpha: 0.45),
                      ),
                    ),
                    SizedBox(width: dateChipGap),
                    _buildDateText(
                      context,
                      date: _displayDates[1],
                      isSelected: true,
                      fontSize: dateChipFontSize,
                    ),
                    SizedBox(width: dateChipGap),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: dividerColor.withValues(alpha: 0.45),
                      ),
                    ),
                    SizedBox(width: dateChipGap),
                    _buildDateText(
                      context,
                      date: _displayDates[2],
                      isSelected: false,
                      fontSize: dateChipFontSize,
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

  Widget _buildDateText(
    BuildContext context, {
    required DateTime date,
    required bool isSelected,
    required double fontSize,
  }) {
    final text = '${DateFormat('M.d').format(date)} ${_weekdayLabel(date)}';
    return GestureDetector(
      onTap: () => onDateChanged(date),
      child: Text(
        text,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: isSelected ? selectedTextColor : unselectedTextColor,
          fontSize: fontSize,
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
