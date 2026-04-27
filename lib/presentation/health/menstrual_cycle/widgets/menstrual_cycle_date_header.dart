import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

/// 공통 달력 팝업과 동일하게 Dialog 폭을 제한합니다.
double _menstrualDialogMaxWidth(
  BuildContext context, {
  required double horizontalInsetTotal,
  double maxCap = 340,
  double minCap = 240,
}) {
  final sw = MediaQuery.sizeOf(context).width;
  final raw = sw - horizontalInsetTotal;
  if (!raw.isFinite || raw <= 0) return minCap;
  return raw.clamp(minCap, maxCap);
}

/// `yyyy년 M월` + 달력 아이콘.
/// - 아이콘 탭 시 "이력 확인용" 달력 팝업(Dialog) 표시
/// - 날짜 클릭 불가(표시만)
/// - 좌우 스와이프 월 이동
/// - 생리일 마킹 유지
class MenstrualCycleDateHeader extends StatelessWidget {
  const MenstrualCycleDateHeader({
    super.key,
    required this.selectedDate,
    required this.periodDayKeys,
    required this.periodEndpointKeys,
    this.monthTextColor = const Color(0xFF898686),
    this.iconColor = const Color(0xFF898686),
  });

  final DateTime selectedDate;
  final Set<String> periodDayKeys;
  final Set<String> periodEndpointKeys;
  final Color monthTextColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(selectedDate.year, selectedDate.month, 1);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        Text(
          DateFormat('yyyy년 M월').format(monthStart),
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
            await showDialog<void>(
              context: context,
              barrierDismissible: true,
              barrierColor: Colors.black.withValues(alpha: 0.2),
              builder: (_) {
                // 공통 달력 팝업과 동일: insetPadding(24/24) 기준 폭 제한
                final cardW = _menstrualDialogMaxWidth(
                  context,
                  horizontalInsetTotal: 48,
                  maxCap: 340,
                  minCap: 240,
                );
                return Dialog(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: cardW),
                    child: _MenstrualCalendarPopup(
                      initialMonth: monthStart,
                      periodDayKeys: periodDayKeys,
                      periodEndpointKeys: periodEndpointKeys,
                    ),
                  ),
                );
              },
            );
          },
          child: Icon(Icons.calendar_today, size: 12, color: iconColor),
        ),
      ],
    );
  }
}

class _MenstrualCalendarPopup extends StatefulWidget {
  const _MenstrualCalendarPopup({
    required this.initialMonth,
    required this.periodDayKeys,
    required this.periodEndpointKeys,
  });

  final DateTime initialMonth;
  final Set<String> periodDayKeys;
  final Set<String> periodEndpointKeys;

  @override
  State<_MenstrualCalendarPopup> createState() => _MenstrualCalendarPopupState();
}

class _MenstrualCalendarPopupState extends State<_MenstrualCalendarPopup> {
  late DateTime _focusedMonth;

  static const Color _kAccentPink = Color(0xFFFF5A8D);
  static const Color _kNavyText = Color(0xFF0E2451);
  static const Color _kWeekdayMuted = Color(0xFF7E818C);
  static const Color _kOutsideDayText = Color(0x4C1A1A1A);
  static const Color _kRangeBarFill = Color(0x26FC6795);
  static const double _kPeriodEndpointDiameter = 25.0;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(widget.initialMonth.year, widget.initialMonth.month);
  }

  int _daysInMonth(DateTime m) => DateTime(m.year, m.month + 1, 0).day;

  /// 일요일 시작: leading 빈 칸 수
  int _leadingBlanks(DateTime monthStart) {
    final w = monthStart.weekday; // Mon=1 .. Sun=7
    return w % 7;
  }

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
  }

  String _dayKey(DateTime day) {
    final d = DateUtils.dateOnly(day);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  bool _inRange(DateTime d) => widget.periodDayKeys.contains(_dayKey(d));
  bool _isEndpoint(DateTime d) =>
      widget.periodEndpointKeys.contains(_dayKey(d));

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(_focusedMonth.year, _focusedMonth.month);
    final dim = _daysInMonth(monthStart);
    final leading = _leadingBlanks(monthStart);
    final totalCells = leading + dim;
    final rows = (totalCells / 7).ceil();

    // 공통 달력 팝업과 동일한 카드 스타일 유지
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v.abs() < 220) return;
        if (v > 0) _prevMonth(); // right swipe
        if (v < 0) _nextMonth(); // left swipe
      },
      child: Container(
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
                      DateFormat('yyyy년 M월', 'ko_KR').format(_focusedMonth),
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
                        onPressed: _prevMonth,
                        icon: const Icon(
                          Icons.chevron_left,
                          color: _kNavyText,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        onPressed: _nextMonth,
                        icon: const Icon(
                          Icons.chevron_right,
                          color: _kNavyText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(
                height: 24,
                thickness: 0.84,
                color: Color(0xFFE4E5E7),
              ),
              Row(
                children: const ['일', '월', '화', '수', '목', '금', '토']
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cellW = constraints.maxWidth / 7;
                      int? firstIdx;
                      int? lastIdx;
                      for (var col = 0; col < 7; col++) {
                        final i = row * 7 + col - leading;
                        if (i < 0 || i >= dim) continue;
                        final day = i + 1;
                        final dt = DateTime(_focusedMonth.year, _focusedMonth.month, day);
                        if (_inRange(dt)) {
                          firstIdx ??= col;
                          lastIdx = col;
                        }
                      }

                      Widget? bar;
                      if (firstIdx != null && lastIdx != null) {
                        final firstDay = DateTime(
                          _focusedMonth.year,
                          _focusedMonth.month,
                          (row * 7 + firstIdx - leading) + 1,
                        );
                        final lastDay = DateTime(
                          _focusedMonth.year,
                          _focusedMonth.month,
                          (row * 7 + lastIdx - leading) + 1,
                        );
                        const d = _kPeriodEndpointDiameter;
                        final firstCx = firstIdx * cellW + cellW / 2;
                        final lastCx = lastIdx * cellW + cellW / 2;
                        final startIsEndpoint = _isEndpoint(firstDay);
                        final endIsEndpoint = _isEndpoint(lastDay);
                        final barLeft =
                            startIsEndpoint ? firstCx - d / 2 : firstIdx * cellW;
                        final barRight = endIsEndpoint
                            ? lastCx + d / 2
                            : (lastIdx + 1) * cellW;
                        final barWidth = math.max(0.0, barRight - barLeft);
                        if (barWidth > 0) {
                          bar = Positioned(
                            left: barLeft,
                            top: 3,
                            width: barWidth,
                            height: 26,
                            child: const IgnorePointer(
                              child: DecoratedBox(
                                decoration: ShapeDecoration(
                                  color: _kRangeBarFill,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(13)),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                      }

                      return SizedBox(
                        height: 32,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (bar != null) bar,
                            Row(
                              children: List.generate(7, (col) {
                                final i = row * 7 + col - leading;
                                if (i < 0 || i >= dim) {
                                  return const Expanded(child: SizedBox(height: 32));
                                }
                                final day = i + 1;
                                final date = DateTime(
                                  _focusedMonth.year,
                                  _focusedMonth.month,
                                  day,
                                );
                                final inRange = _inRange(date);
                                final isEndpoint = _isEndpoint(date);
                                final isToday =
                                    DateUtils.isSameDay(date, DateTime.now());

                                return Expanded(
                                  child: SizedBox(
                                    height: 32,
                                    child: Center(
                                      child: isEndpoint
                                          ? const SizedBox.shrink() // 아래에서 그림
                                          : Text(
                                              '$day',
                                              style: TextStyle(
                                                color: inRange
                                                    ? _kNavyText
                                                    : (isToday
                                                        ? _kNavyText
                                                        : _kOutsideDayText),
                                                fontSize: 14,
                                                fontFamily: 'Gmarket Sans TTF',
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            // Endpoints overlay circles (pink)
                            Row(
                              children: List.generate(7, (col) {
                                final i = row * 7 + col - leading;
                                if (i < 0 || i >= dim) {
                                  return const Expanded(child: SizedBox(height: 32));
                                }
                                final day = i + 1;
                                final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
                                final isEndpoint = _isEndpoint(date);
                                if (!isEndpoint) {
                                  return const Expanded(child: SizedBox(height: 32));
                                }
                                return Expanded(
                                  child: SizedBox(
                                    height: 32,
                                    child: Center(
                                      child: SizedBox(
                                        width: _kPeriodEndpointDiameter,
                                        height: _kPeriodEndpointDiameter,
                                        child: DecoratedBox(
                                          decoration: ShapeDecoration(
                                            color: _kAccentPink,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                          ),
                                          child: Center(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                '$day',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  height: 1.0,
                                                  fontFamily: 'Gmarket Sans TTF',
                                                  fontWeight: FontWeight.w500,
                                                ),
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
                          ],
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
