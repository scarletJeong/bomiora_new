import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/login_required_dialog.dart';
import '../../health_common/health_responsive_scale.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../health_common/widgets/health_date_selector.dart';
import '../widgets/health_year_month_picker_dialog.dart';
import '../../../../data/models/health/menstrual_cycle/menstrual_cycle_model.dart';
import '../../../../data/repositories/health/menstrual_cycle/menstrual_cycle_repository.dart';
import '../../../../data/services/auth_service.dart';

class MenstrualCycleInputScreen extends StatefulWidget {
  final MenstrualCycleRecord? existingRecord;

  const MenstrualCycleInputScreen({super.key, this.existingRecord});

  @override
  State<MenstrualCycleInputScreen> createState() =>
      _MenstrualCycleInputScreenState();
}

class _MenstrualCycleInputScreenState extends State<MenstrualCycleInputScreen> {
  DateTime? _lastPeriodStart;
  DateTime? _lastPeriodEnd;
  int _cycleLength = 28;
  bool _isLoading = false;
  late final TextEditingController _cycleLengthController;
  List<MenstrualCycleRecord> _historyRecords = const [];
  /// 달력에서 이력 범위를 탭해 고른 행(또는 화면 진입 시 existing). 저장 시 이 id로 update.
  int? _explicitEditRecordId;

  DateTime _focusedDay = DateTime.now();
  late final PageController _calendarPageController;

  static final DateTime _calendarFirstDay = DateTime(2020, 1, 1);
  static final DateTime _calendarLastDay = DateTime(2030, 12, 31);

  static const Color _kOutsideDayText = Color(0x4C1A1A1A);
  static const Color _kFutureDayText = Color(0xFFB3B3B3);
  static const Color _kRangeBarFill = Color(0x26FC6795);
  static const Color _kAccentPink = Color(0xFFFF5A8D);
  /// 예정 생리 기간(연한 표시) — 바·끝 원 동일 색 (입력 화면에서만 사용)
  static const Color _kPredictedPeriodFill = Color(0x14FC6795);
  /// 시작·끝 동그라미 지름(바는 이 원 바깥으로 나가지 않게 계산)
  static const double _kPeriodEndpointDiameter = 25.0;

  @override
  void initState() {
    super.initState();
    _cycleLengthController = TextEditingController(text: '$_cycleLength');
    _calendarPageController = PageController(
      initialPage: _monthPageIndex(_focusedDay),
      viewportFraction: 1.0,
    );
    _loadExistingData();
    _loadHistoryRecords();
  }

  void _loadExistingData() {
    if (widget.existingRecord != null) {
      final record = widget.existingRecord!;
      setState(() {
        // 편집 모드: "표시용" 시작/끝을 수정(계산용 값은 그대로 유지)
        _lastPeriodStart = record.displayPeriodStart;
        _lastPeriodEnd = record.displayPeriodEnd;
        _explicitEditRecordId = record.id;
        _cycleLength = record.cycleLength;
        _cycleLengthController.text = '$_cycleLength';
        _focusedDay = DateTime(
            record.lastPeriodStart.year, record.lastPeriodStart.month, 1);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_calendarPageController.hasClients) {
          _calendarPageController.jumpToPage(_monthPageIndex(_focusedDay));
        }
      });
    }
  }

  Future<void> _loadHistoryRecords() async {
    try {
      final user = await AuthService.getUser();
      if (user == null || !mounted) return;
      final records =
          await MenstrualCycleRepository.getMenstrualCycleRecords(user.id);
      if (!mounted) return;
      setState(() {
        _historyRecords = records;
      });
    } catch (_) {
      // 기록 화면은 입력이 우선이므로 조회 실패 시 조용히 무시
    }
  }

  @override
  void dispose() {
    _calendarPageController.dispose();
    _cycleLengthController.dispose();
    super.dispose();
  }

  int _monthPageIndex(DateTime day) =>
      (day.year - _calendarFirstDay.year) * 12 +
      (day.month - _calendarFirstDay.month);

  DateTime _monthFromPageIndex(int index) =>
      DateTime(_calendarFirstDay.year, _calendarFirstDay.month + index, 1);

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _inFocusedMonth(DateTime d, DateTime monthStart) =>
      d.year == monthStart.year && d.month == monthStart.month;

  String _dayKey(DateTime day) {
    final d = DateUtils.dateOnly(day);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Set<String> _allPeriodDayKeys() {
    final keys = <String>{};

    void addRange(DateTime start, DateTime end) {
      var current = DateUtils.dateOnly(start);
      final last = DateUtils.dateOnly(end);
      while (!current.isAfter(last)) {
        keys.add(_dayKey(current));
        current = current.add(const Duration(days: 1));
      }
    }

    for (final r in _historyRecords) {
      // 편집 중인 행은 DB에 남아 있는 옛 구간을 다시 그리지 않음 → 새로 고른 시작/끝만 보이게
      if (r.id != null &&
          _explicitEditRecordId != null &&
          r.id == _explicitEditRecordId) {
        continue;
      }
      final start = DateUtils.dateOnly(r.displayPeriodStart);
      final end = DateUtils.dateOnly(r.displayPeriodEnd);
      addRange(start, end);
    }

    if (_lastPeriodStart != null) {
      final start = DateUtils.dateOnly(_lastPeriodStart!);
      final end = DateUtils.dateOnly(_lastPeriodEnd ?? _lastPeriodStart!);
      addRange(start, end);
    }
    return keys;
  }

  bool _isHistoricalEndpoint(DateTime d) {
    final dd = DateUtils.dateOnly(d);
    for (final r in _historyRecords) {
      if (r.id != null &&
          _explicitEditRecordId != null &&
          r.id == _explicitEditRecordId) {
        continue;
      }
      final start = DateUtils.dateOnly(r.displayPeriodStart);
      final end = DateUtils.dateOnly(r.displayPeriodEnd);
      if (_sameDate(dd, start) || _sameDate(dd, end)) return true;
    }
    return false;
  }

  bool _inPeriodRange(DateTime d) {
    return _allPeriodDayKeys().contains(_dayKey(d));
  }

  MenstrualCycleRecord? _nearestRecordByDisplayStart(DateTime day) {
    if (_historyRecords.isEmpty) return null;
    final target = DateUtils.dateOnly(day);
    MenstrualCycleRecord? best;
    int? bestDiff;
    for (final r in _historyRecords) {
      final start = DateUtils.dateOnly(r.displayPeriodStart);
      final diff = target.difference(start).inDays.abs();
      if (best == null || diff < bestDiff!) {
        best = r;
        bestDiff = diff;
        continue;
      }
      if (diff == bestDiff) {
        // 동률이면 최근 기록 우선
        final bestStart = DateUtils.dateOnly(best.lastPeriodStart);
        final currentStart = DateUtils.dateOnly(r.lastPeriodStart);
        if (currentStart.isAfter(bestStart)) {
          best = r;
          bestDiff = diff;
        }
      }
    }
    return best;
  }

  /// 입력 중(신규): 현재 선택한 시작일 기준으로 예정일 표시
  /// 수정 중: 기존 계산용 start(lastPeriodStart) 기준으로 예정일 표시 (표시용 기간 변경은 계산에 영향 없음)
  ({DateTime start, DateTime end})? _predictedRange() {
    // 기준 레코드 선택
    DateTime? baseStart;
    int baseCycle = _cycleLength;
    int basePeriod = 1;

    if (widget.existingRecord != null) {
      baseStart = widget.existingRecord!.lastPeriodStart;
      baseCycle = widget.existingRecord!.cycleLength;
      basePeriod = widget.existingRecord!.periodLength;
    } else if (_lastPeriodStart != null) {
      baseStart = _lastPeriodStart;
      baseCycle = _cycleLength;
      basePeriod = (_lastPeriodEnd ?? _lastPeriodStart)!.difference(_lastPeriodStart!).inDays + 1;
    } else if (_historyRecords.isNotEmpty) {
      final sorted = [..._historyRecords]..sort((a, b) => b.lastPeriodStart.compareTo(a.lastPeriodStart));
      final r = sorted.first;
      baseStart = r.lastPeriodStart;
      baseCycle = r.cycleLength;
      basePeriod = r.periodLength;
    }

    if (baseStart == null || baseCycle <= 0 || basePeriod <= 0) return null;
    final s = DateUtils.dateOnly(baseStart.add(Duration(days: baseCycle)));
    final e = DateUtils.dateOnly(s.add(Duration(days: basePeriod - 1)));
    return (start: s, end: e);
  }

  bool _inPredictedRange(DateTime d) {
    final pr = _predictedRange();
    if (pr == null) return false;
    final dd = DateUtils.dateOnly(d);
    return !dd.isBefore(pr.start) && !dd.isAfter(pr.end);
  }

  bool _isPredictedEndpoint(DateTime d) {
    final pr = _predictedRange();
    if (pr == null) return false;
    final dd = DateUtils.dateOnly(d);
    return _sameDate(dd, pr.start) || _sameDate(dd, pr.end);
  }

  List<List<DateTime>> _weeksForMonth(DateTime monthStart) {
    final y = monthStart.year;
    final m = monthStart.month;
    final first = DateTime(y, m, 1);
    final lastDay = DateTime(y, m + 1, 0).day;
    final leading = first.weekday % 7;
    final days = <DateTime>[];
    for (var i = 0; i < leading; i++) {
      days.add(first.subtract(Duration(days: leading - i)));
    }
    for (var d = 1; d <= lastDay; d++) {
      days.add(DateTime(y, m, d));
    }
    while (days.length % 7 != 0) {
      days.add(days.last.add(const Duration(days: 1)));
    }
    final weeks = <List<DateTime>>[];
    for (var i = 0; i < days.length; i += 7) {
      weeks.add(days.sublist(i, i + 7));
    }
    return weeks;
  }

  void _onDayTapped(DateTime rawDay) {
    if (!mounted) return;
    final selectedDay = DateUtils.dateOnly(rawDay);
    final today = DateUtils.dateOnly(DateTime.now());
    if (selectedDay.isBefore(DateUtils.dateOnly(_calendarFirstDay)) ||
        selectedDay.isAfter(DateUtils.dateOnly(_calendarLastDay))) {
      return;
    }
    if (selectedDay.isAfter(today)) {
      return;
    }

    final hits = <MenstrualCycleRecord>[];
    for (final r in _historyRecords) {
      final start = DateUtils.dateOnly(r.displayPeriodStart);
      final end = DateUtils.dateOnly(r.displayPeriodEnd);
      if (!selectedDay.isBefore(start) && !selectedDay.isAfter(end)) {
        hits.add(r);
      }
    }
    final MenstrualCycleRecord? hit = hits.isEmpty
        ? null
        : (hits.length == 1
            ? hits.first
            : _nearestRecordByDisplayStart(selectedDay));

    // 입력(신규) 화면에서는 과거 이력 수정/선택을 막는다.
    if (widget.existingRecord == null && hit != null) {
      return;
    }

    // 과거 이력 범위를 탭한 경우:
    // - 같은 이력(id)을 이미 편집 중이고 종료일 미선택이면 2번째 탭을 종료일로 인정
    // - 그 외에는 해당 이력을 편집 대상으로 잡고 시작일부터 다시 선택
    if (hit != null) {
      final sameEditingRecord = _explicitEditRecordId != null &&
          hit.id != null &&
          _explicitEditRecordId == hit.id;
      if (sameEditingRecord &&
          _lastPeriodStart != null &&
          _lastPeriodEnd == null) {
        final start = DateUtils.dateOnly(_lastPeriodStart!);
        if (_sameDate(selectedDay, start)) return;
        setState(() {
          if (selectedDay.isAfter(start)) {
            _lastPeriodEnd = selectedDay;
          } else {
            _lastPeriodEnd = start;
            _lastPeriodStart = selectedDay;
          }
        });
        return;
      }
      setState(() {
        _explicitEditRecordId = hit!.id;
        _lastPeriodStart = selectedDay;
        _lastPeriodEnd = null;
      });
      return;
    }

    // 범위 밖 날짜를 눌러도, displayPeriodStart가 가장 가까운 이력을 편집 대상으로 맞춘다.
    if (widget.existingRecord != null) {
      final nearest = _nearestRecordByDisplayStart(selectedDay);
      if (nearest?.id != null) {
        _explicitEditRecordId = nearest!.id;
      }
    }

    if (_lastPeriodStart == null || _lastPeriodEnd != null) {
      setState(() {
        // 이력(id) 수정 중에 범위 밖 날짜로 "다시 시작일" 고를 때는 id 유지 → 저장 시 update
        // (여기서 explicit을 지우면 시작일이 DB와 달라 insert로 새 row가 생김)
        _lastPeriodStart = selectedDay;
        _lastPeriodEnd = null;
      });
      return;
    }

    final start = DateUtils.dateOnly(_lastPeriodStart!);
    if (_sameDate(selectedDay, start)) {
      return;
    }

    setState(() {
      if (selectedDay.isAfter(start)) {
        _lastPeriodEnd = selectedDay;
      } else {
        _lastPeriodEnd = start;
        _lastPeriodStart = selectedDay;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );
    final textScale =
        healthTextScaleByWidth(MediaQuery.sizeOf(context).width);

    return Theme(
      data: gmarketTheme,
      child: MobileAppLayoutWrapper(
        backgroundColor: Colors.white,
        appBar: HealthAppBar(
          title: '생리주기',
          leadingIconSize: healthDp(context, 24),
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              healthDp(context, 27),
              healthDp(context, 5),
              healthDp(context, 27),
              healthDp(context, 20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '마지막 생리는 언제였나요?',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
                SizedBox(height: healthDp(context, 20)),
                _buildCalendar(),
                SizedBox(height: healthDp(context, 20)),
                _buildCycleLengthSection(),
                SizedBox(height: healthDp(context, 20)),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final focusedMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final focusedWeeks = _weeksForMonth(focusedMonth).length;
    final calendarGridHeight =
        healthDp(context, focusedWeeks * 54 + (focusedWeeks - 1) * 8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCalendarMonthHeader(),
        SizedBox(height: healthDp(context, 4)),
        _buildWeekdayHeader(),
        SizedBox(height: healthDp(context, 8)),
        SizedBox(
          height: calendarGridHeight,
          child: PageView.builder(
            controller: _calendarPageController,
            scrollDirection: Axis.vertical,
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            itemCount: (_calendarLastDay.year - _calendarFirstDay.year) * 12 +
                (_calendarLastDay.month - _calendarFirstDay.month) +
                1,
            itemBuilder: (context, index) {
              final monthDay = _monthFromPageIndex(index);
              return _buildMonthGrid(monthDay);
            },
            onPageChanged: (index) {
              final monthDay = _monthFromPageIndex(index);
              if (!mounted) return;
              setState(() {
                _focusedDay = monthDay;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthGrid(DateTime monthStart) {
    final weeks = _weeksForMonth(monthStart);
    return ClipRect(
      child: SingleChildScrollView(
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: weeks
              .asMap()
              .entries
              .map((entry) => Padding(
                    padding: EdgeInsets.only(
                      bottom: entry.key == weeks.length - 1
                          ? 0
                          : healthDp(context, 8),
                    ),
                    child: _buildWeekRow(entry.value, monthStart),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildWeekRow(List<DateTime> weekDays, DateTime focusedMonth) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cellW = w / 7;
        final showPredicted = widget.existingRecord == null;
        int? firstIdx;
        int? lastIdx;
        int? predFirstIdx;
        int? predLastIdx;
        for (var i = 0; i < 7; i++) {
          if (_inPeriodRange(weekDays[i])) {
            firstIdx ??= i;
            lastIdx = i;
          }
          if (showPredicted && _inPredictedRange(weekDays[i])) {
            predFirstIdx ??= i;
            predLastIdx = i;
          }
        }
        return SizedBox(
          height: healthDp(context, 54),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topLeft,
            children: [
              // 예정(연한) 바를 먼저 그림 → 실제 바가 위로 오게
              if (showPredicted && predFirstIdx != null && predLastIdx != null)
                _rangeBarForWeekRow(
                  context,
                  weekDays: weekDays,
                  firstIdx: predFirstIdx,
                  lastIdx: predLastIdx,
                  cellW: cellW,
                  fillColor: _kPredictedPeriodFill,
                  endpointMatcher: _isPredictedEndpoint,
                ),
              if (firstIdx != null && lastIdx != null)
                _rangeBarForWeekRow(
                  context,
                  weekDays: weekDays,
                  firstIdx: firstIdx,
                  lastIdx: lastIdx,
                  cellW: cellW,
                  fillColor: _kRangeBarFill,
                  endpointMatcher: (d) =>
                      (_lastPeriodStart != null && _sameDate(d, _lastPeriodStart!)) ||
                      (_lastPeriodEnd != null && _sameDate(d, _lastPeriodEnd!)) ||
                      _isHistoricalEndpoint(d),
                ),
              Row(
                children: List.generate(
                  7,
                  (i) => Expanded(
                    child: _buildDayCell(context, weekDays[i], focusedMonth),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 주 단위 연한 핑크 바. 여러 주에 걸친 기간은 행 끝·다음 행 시작까지 이어짐.
  /// 시작·끝 칸에서는 바를 원 지름까지 포함해 그려 동그라미와 한 줄로 이어지게 함(원은 위 레이어).
  Widget _rangeBarForWeekRow(
    BuildContext context, {
    required List<DateTime> weekDays,
    required int firstIdx,
    required int lastIdx,
    required double cellW,
    required Color fillColor,
    required bool Function(DateTime day) endpointMatcher,
  }) {
    final d = healthDp(context, _kPeriodEndpointDiameter);
    final firstDay = weekDays[firstIdx];
    final lastDay = weekDays[lastIdx];
    final firstCx = firstIdx * cellW + cellW / 2;
    final lastCx = lastIdx * cellW + cellW / 2;

    final double barLeft;
    final double barRight;
    final startIsEndpoint = endpointMatcher(firstDay);
    final endIsEndpoint = endpointMatcher(lastDay);

    // 종료일 미선택이더라도 "이전 내역" 범위 바는 끝점 원과 자연스럽게 이어져야 함
    barLeft = startIsEndpoint ? firstCx - d / 2 : firstIdx * cellW;
    barRight = endIsEndpoint ? lastCx + d / 2 : (lastIdx + 1) * cellW;

    final barWidth = math.max(0.0, barRight - barLeft);
    if (barWidth <= 0) return const SizedBox.shrink();
    return Positioned(
      left: barLeft,
      top: healthDp(context, 14),
      width: barWidth,
      height: healthDp(context, 26),
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: fillColor,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(healthDp(context, 13)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime day,
    DateTime focusedMonth,
  ) {
    final showPredicted = widget.existingRecord == null;
    final today = DateUtils.dateOnly(DateTime.now());
    final isFuture = DateUtils.dateOnly(day).isAfter(today);
    final inMonth = _inFocusedMonth(day, focusedMonth);
    final rangeStart =
        _lastPeriodStart != null && _sameDate(day, _lastPeriodStart!);
    final rangeEnd =
        _lastPeriodEnd != null && _sameDate(day, _lastPeriodEnd!);
    final isCurrentPeriodEndpoint = rangeStart || rangeEnd;
    final isPeriodEndpoint = isCurrentPeriodEndpoint || _isHistoricalEndpoint(day);
    final inRange = _inPeriodRange(day);
    final predictedEndpoint =
        showPredicted && !isPeriodEndpoint && _isPredictedEndpoint(day);
    final predictedInRange = showPredicted && !inRange && _inPredictedRange(day);

    final plainTextColor = isFuture
        ? _kFutureDayText
        : (inMonth ? const Color(0xFF1A1A1A) : _kOutsideDayText);
    final plainWeight =
        inRange && !isPeriodEndpoint ? FontWeight.w500 : FontWeight.w300;

    final endpointD = healthDp(context, _kPeriodEndpointDiameter);
    final endpointRadius = healthDp(context, 20);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onDayTapped(day),
      child: SizedBox(
        height: healthDp(context, 54),
        child: Center(
          child: isPeriodEndpoint
              ? SizedBox(
                  width: endpointD,
                  height: endpointD,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: _kAccentPink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(endpointRadius),
                      ),
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${day.day}',
                          textAlign: TextAlign.center,
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
                )
              : predictedEndpoint
                  ? SizedBox(
                      width: endpointD,
                      height: endpointD,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: _kPredictedPeriodFill,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(endpointRadius),
                          ),
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${day.day}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: plainTextColor,
                                fontSize: 14,
                                height: 1.0,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: plainWeight,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
              : Text(
                  '${day.day}',
                  style: TextStyle(
                    color: isFuture
                        ? _kFutureDayText
                        : (predictedInRange
                            ? const Color(0xFF1A1A1A)
                            : plainTextColor),
                    fontSize: 14,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: plainWeight,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCalendarMonthHeader() {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(healthDp(context, 8)),
          splashFactory: NoSplash.splashFactory,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          focusColor: Colors.transparent,
          onTap: _openMonthFromHealthPicker,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 4)
            ),
            child: Row(
              children: [
                Text(
                  DateFormat('yyyy년 M월').format(_focusedDay),
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 16,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
                SizedBox(width: healthDp(context, 3)),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: healthDp(context, 18),
                ),
              ],
            ),
          ),
        ),
        //const Spacer(),
      ],
    );
  }

  Future<void> _openMonthFromHealthPicker() async {
    final now = DateTime.now();
    final picked = await showHealthYearMonthPickerDialog(
      context,
      initialDate: DateTime(_focusedDay.year, _focusedDay.month, 1),
      firstDate: _calendarFirstDay,
      lastDate: DateTime(now.year, now.month, 1),
    );
    if (picked == null || !mounted) return;
    _moveToYearMonth(picked.year, picked.month);
  }

  void _moveToYearMonth(int year, int month) {
    final target = DateTime(year, month, 1);
    final page = _monthPageIndex(target);
    if (_calendarPageController.hasClients) {
      _calendarPageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
    setState(() {
      _focusedDay = target;
    });
  }

  Widget _buildWeekdayHeader() {
    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    return SizedBox(
      height: healthDp(context, 46),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              width: healthDp(context, 1),
              color: const Color(0x7FD2D2D2),
            ),
            bottom: BorderSide(
              width: healthDp(context, 1),
              color: const Color(0x7FD2D2D2),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: labels
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 14,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildCycleLengthSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: EdgeInsets.only(left: healthDp(context, 10)),
          child: const Text(
            '최근 생리주기는 며칠인가요?',
            style: TextStyle(
              color: Colors.black,
              fontSize: 10,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
        SizedBox(
          height: healthDp(context, 20),
          child: Row(
          children: [
            Container(
              width: healthDp(context, 52),
              height: healthDp(context, 20),
              padding: EdgeInsets.fromLTRB(
                healthDp(context, 19),
                0,
                healthDp(context, 19),
                healthDp(context, 6),
              ),
              clipBehavior: Clip.antiAlias,
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 5)),
                ),
                shadows: [
                  BoxShadow(
                    color: const Color(0x19000000),
                    blurRadius: healthDp(context, 2),
                    offset: Offset.zero,
                    spreadRadius: 0,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Center(
                child: TextField(
                  controller: _cycleLengthController,
                  textAlign: TextAlign.center,
                  textAlignVertical: TextAlignVertical.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null && parsed > 0) {
                      _cycleLength = parsed;
                    }
                  },
                ),
              ),
            ),
            SizedBox(width: healthDp(context, 5)),
            const Text(
              '일',
              style: TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Center(
      child: SizedBox(
        width: healthDp(context, 113),
        height: healthDp(context, 30),
        child: ElevatedButton(
        onPressed: _isLoading ? null : _onSavePressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kAccentPink,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
                width: healthDp(context, 20),
                height: healthDp(context, 20),
                child: CircularProgressIndicator(
                  strokeWidth: healthDp(context, 2),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Center(
                child: Text(
                  '저장',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: healthSp(context, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                  ),
                ),
              ),
      ),
      ),
    );
  }

  Future<void> _onSavePressed() async {
    // “수정하기” 진입(기존 기록 기반)인 경우만 확인 팝업 노출
    final isEditFlow = widget.existingRecord != null;
    if (isEditFlow) {
      final ok = await _showEditConfirmDialog();
      if (ok != true) return;
    }
    await _saveMenstrualCycleRecord();
  }

  Future<bool?> _showEditConfirmDialog() {
    final w = healthDp(context, 272);
    final padTop = healthDp(context, 20);
    final padH = healthDp(context, 20);
    final radius = healthDp(context, 20);
    final gap = healthDp(context, 20);
    final btnH = healthDp(context, 50);
    final shadowBlur = healthDp(context, 8.14);
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.25),
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: w,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(radius),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x19000000),
                    blurRadius: shadowBlur,
                    offset: const Offset(0, 0),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    // 상단 컨텐츠만 좌우 패딩 적용 (버튼은 전체 폭 사용)
                    padding:
                        EdgeInsets.only(top: padTop, left: padH, right: padH),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '생리 기록 수정',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            color: const Color(0xFF1A1A1A),
                            fontSize: healthSp(ctx, 20),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
                        ),
                        SizedBox(height: gap),
                        Text(
                          // Figma 문자열의 들여쓰기는 실제 렌더링에 불리해 2줄 중앙 정렬로 통일
                          '해당 기록을\n수정하시겠습니까?',
                          textAlign: TextAlign.center,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            color: const Color(0xFF898686),
                            fontSize: healthSp(ctx, 14),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            height: 1.57,
                          ),
                        ),
                        SizedBox(height: gap),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: btnH,
                    child: Row(
                      children: [
                        SizedBox(
                          width: w / 2,
                          child: InkWell(
                            onTap: () => Navigator.pop(ctx, false),
                            child: Container(
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F7F7),
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(radius),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '취소',
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  color: const Color(0xFF898686),
                                  fontSize: healthSp(ctx, 16),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: w / 2,
                          child: InkWell(
                            onTap: () => Navigator.pop(ctx, true),
                            child: Container(
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5A8D),
                                borderRadius: BorderRadius.only(
                                  bottomRight: Radius.circular(radius),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '수정',
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: healthSp(ctx, 16),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveMenstrualCycleRecord() async {
    if (_lastPeriodStart == null) {
      return;
    }

    if (_lastPeriodEnd == null) {
      return;
    }

    final cycleLength = int.tryParse(_cycleLengthController.text);
    if (cycleLength == null || cycleLength <= 0) {
      return;
    }
    _cycleLength = cycleLength;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await AuthService.getUser();
      if (!mounted) return;
      if (user == null) {
        await showLoginRequiredDialog(
          context,
          message: '건강 기록 입력은 로그인 후 이용할 수 있습니다.',
        );
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      MenstrualCycleRecord? _recordById(int id) {
        if (widget.existingRecord?.id == id) return widget.existingRecord;
        for (final r in _historyRecords) {
          if (r.id == id) return r;
        }
        return null;
      }

      MenstrualCycleRecord? _matchExistingRecordForEdit(DateTime start) {
        final s = DateUtils.dateOnly(start);
        MenstrualCycleRecord? byCalcStart;
        MenstrualCycleRecord? byDisplayStart;
        final all = <MenstrualCycleRecord>[
          if (widget.existingRecord != null) widget.existingRecord!,
          ..._historyRecords,
        ];
        for (final r in all) {
          if (r.id == null) continue;
          if (DateUtils.isSameDay(DateUtils.dateOnly(r.lastPeriodStart), s)) {
            byCalcStart ??= r;
          }
          if (DateUtils.isSameDay(DateUtils.dateOnly(r.displayPeriodStart), s)) {
            byDisplayStart ??= r;
          }
        }
        // 계산용 시작일 매칭을 우선(안정적)
        return byCalcStart ?? byDisplayStart;
      }

      bool success;
      MenstrualCycleRecord? _latestByCalcStart(List<MenstrualCycleRecord> list) {
        if (list.isEmpty) return null;
        final sorted = [...list]
          ..sort((a, b) => b.lastPeriodStart.compareTo(a.lastPeriodStart));
        return sorted.first;
      }
      final MenstrualCycleRecord? matched = _explicitEditRecordId != null
          ? (_recordById(_explicitEditRecordId!) ??
              _matchExistingRecordForEdit(_lastPeriodStart!))
          : _matchExistingRecordForEdit(_lastPeriodStart!);
      if (matched != null) {
        final periodLength =
            _lastPeriodEnd!.difference(_lastPeriodStart!).inDays + 1;
        final allForLatest = <MenstrualCycleRecord>[
          ..._historyRecords,
          if (widget.existingRecord != null &&
              !_historyRecords.any((r) => r.id == widget.existingRecord!.id))
            widget.existingRecord!,
        ];
        final latest = _latestByCalcStart(allForLatest);
        final isLatestRecord =
            latest != null && matched.id != null && latest.id == matched.id;

        // 최신 기록 수정은 계산 기준(lastPeriodStart)도 함께 변경해 재계산 반영.
        // 과거 기록 수정은 표시용 날짜만 변경해 기존 계산 흐름 유지.
        final record = isLatestRecord
            ? matched.copyWith(
                mbId: user.id,
                lastPeriodStart: _lastPeriodStart,
                periodStartDate: _lastPeriodStart,
                periodEndDate: _lastPeriodEnd,
                cycleLength: _cycleLength,
                periodLength: periodLength,
              )
            : matched.copyWith(
                mbId: user.id,
                periodStartDate: _lastPeriodStart,
                periodEndDate: _lastPeriodEnd,
              );
        success =
            await MenstrualCycleRepository.updateMenstrualCycleRecord(record);
      } else {
        // 매칭되는 기존 시작일이 없으면 신규 입력
        final periodLength =
            _lastPeriodEnd!.difference(_lastPeriodStart!).inDays + 1;
        final record = MenstrualCycleRecord(
          mbId: user.id,
          lastPeriodStart: _lastPeriodStart!,
          periodStartDate: _lastPeriodStart,
          periodEndDate: _lastPeriodEnd,
          cycleLength: _cycleLength,
          periodLength: periodLength,
        );
        success = await MenstrualCycleRepository.addMenstrualCycleRecord(record);
      }

      if (success) {
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        throw Exception(
            matched != null ? '수정에 실패했습니다' : '저장에 실패했습니다');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
