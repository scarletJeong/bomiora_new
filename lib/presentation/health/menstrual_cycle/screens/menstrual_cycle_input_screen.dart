import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/login_required_dialog.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../health_common/widgets/health_date_selector.dart';
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

  DateTime _focusedDay = DateTime.now();
  late final PageController _calendarPageController;

  static final DateTime _calendarFirstDay = DateTime(2020, 1, 1);
  static final DateTime _calendarLastDay = DateTime(2030, 12, 31);

  static const Color _kOutsideDayText = Color(0x4C1A1A1A);
  static const Color _kRangeBarFill = Color(0x26FC6795);
  static const Color _kAccentPink = Color(0xFFFF5A8D);
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
        _lastPeriodStart = record.lastPeriodStart;
        _lastPeriodEnd =
            record.lastPeriodStart.add(Duration(days: record.periodLength - 1));
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
      if (widget.existingRecord != null &&
          r.id != null &&
          r.id == widget.existingRecord!.id) {
        continue;
      }
      final start = DateUtils.dateOnly(r.lastPeriodStart);
      final end = start.add(Duration(days: r.periodLength - 1));
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
      if (widget.existingRecord != null &&
          r.id != null &&
          r.id == widget.existingRecord!.id) {
        continue;
      }
      final start = DateUtils.dateOnly(r.lastPeriodStart);
      final end = start.add(Duration(days: r.periodLength - 1));
      if (_sameDate(dd, start) || _sameDate(dd, end)) return true;
    }
    return false;
  }

  bool _inPeriodRange(DateTime d) {
    return _allPeriodDayKeys().contains(_dayKey(d));
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
    if (selectedDay.isBefore(DateUtils.dateOnly(_calendarFirstDay)) ||
        selectedDay.isAfter(DateUtils.dateOnly(_calendarLastDay))) {
      return;
    }

    if (_lastPeriodStart == null || _lastPeriodEnd != null) {
      setState(() {
        _lastPeriodStart = selectedDay;
        _lastPeriodEnd = null;
      });
      return;
    }

    final start = DateUtils.dateOnly(_lastPeriodStart!);
    if (_sameDate(selectedDay, start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('종료일은 시작일보다 늦어야 합니다')),
      );
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
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      appBar: HealthAppBar(
        title: widget.existingRecord != null ? '생리주기 수정' : '생리주기 입력',
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '마지막 생리는 언제였나요?',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 6),
            _buildCalendar(),
            const SizedBox(height: 0),
            _buildCycleLengthSection(),
            const SizedBox(height: 30),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCalendarMonthHeader(),
        const SizedBox(height: 8),
        _buildWeekdayHeader(),
        const SizedBox(height: 10),
        SizedBox(
          height: 380,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: weeks
          .map((week) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildWeekRow(week, monthStart),
              ))
          .toList(),
    );
  }

  Widget _buildWeekRow(List<DateTime> weekDays, DateTime focusedMonth) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cellW = w / 7;
        int? firstIdx;
        int? lastIdx;
        for (var i = 0; i < 7; i++) {
          if (_inPeriodRange(weekDays[i])) {
            firstIdx ??= i;
            lastIdx = i;
          }
        }
        return SizedBox(
          height: 54,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topLeft,
            children: [
              if (firstIdx != null && lastIdx != null)
                _rangeBarForWeekRow(
                  weekDays: weekDays,
                  firstIdx: firstIdx,
                  lastIdx: lastIdx,
                  cellW: cellW,
                ),
              Row(
                children: List.generate(
                  7,
                  (i) => Expanded(
                    child: _buildDayCell(weekDays[i], focusedMonth),
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
  Widget _rangeBarForWeekRow({
    required List<DateTime> weekDays,
    required int firstIdx,
    required int lastIdx,
    required double cellW,
  }) {
    const d = _kPeriodEndpointDiameter;
    final firstDay = weekDays[firstIdx];
    final lastDay = weekDays[lastIdx];
    final firstCx = firstIdx * cellW + cellW / 2;
    final lastCx = lastIdx * cellW + cellW / 2;

    final double barLeft;
    final double barRight;
    final startIsEndpoint = (_lastPeriodStart != null &&
            _sameDate(firstDay, _lastPeriodStart!)) ||
        _isHistoricalEndpoint(firstDay);
    final endIsEndpoint =
        (_lastPeriodEnd != null && _sameDate(lastDay, _lastPeriodEnd!)) ||
            _isHistoricalEndpoint(lastDay);

    // 종료일 미선택이더라도 "이전 내역" 범위 바는 끝점 원과 자연스럽게 이어져야 함
    barLeft = startIsEndpoint ? firstCx - d / 2 : firstIdx * cellW;
    barRight = endIsEndpoint ? lastCx + d / 2 : (lastIdx + 1) * cellW;

    final barWidth = math.max(0.0, barRight - barLeft);
    if (barWidth <= 0) return const SizedBox.shrink();
    return Positioned(
      left: barLeft,
      top: 14,
      width: barWidth,
      height: 26,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: _kRangeBarFill,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayCell(DateTime day, DateTime focusedMonth) {
    final inMonth = _inFocusedMonth(day, focusedMonth);
    final rangeStart =
        _lastPeriodStart != null && _sameDate(day, _lastPeriodStart!);
    final rangeEnd =
        _lastPeriodEnd != null && _sameDate(day, _lastPeriodEnd!);
    final isCurrentPeriodEndpoint = rangeStart || rangeEnd;
    final isPeriodEndpoint = isCurrentPeriodEndpoint || _isHistoricalEndpoint(day);
    final inRange = _inPeriodRange(day);

    final plainTextColor =
        inMonth ? const Color(0xFF1A1A1A) : _kOutsideDayText;
    final plainWeight =
        inRange && !isPeriodEndpoint ? FontWeight.w500 : FontWeight.w300;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onDayTapped(day),
      child: SizedBox(
        height: 54,
        child: Center(
          child: isPeriodEndpoint
              ? SizedBox(
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
              : Text(
                  '${day.day}',
                  style: TextStyle(
                    color: plainTextColor,
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
          borderRadius: BorderRadius.circular(8),
          onTap: _openMonthFromHealthPicker,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Text(
                  DateFormat('yyyy년 M월').format(_focusedDay),
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 15,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.keyboard_arrow_down, size: 18),
              ],
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Future<void> _openMonthFromHealthPicker() async {
    final picked = await showHealthDateOnlyPicker(
      context,
      initialDate: DateTime(_focusedDay.year, _focusedDay.month, 15),
      firstDate: _calendarFirstDay,
      lastDate: _calendarLastDay,
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
    return Container(
      width: double.infinity,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(
            width: 1,
            color: Color(0x7FD2D2D2),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: labels
            .map(
              (label) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
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
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCycleLengthSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          '최근 생리주기는 며칠인가요?',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          children: [
            Container(
              width: 51,
              clipBehavior: Clip.antiAlias,
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                shadows: const [
                  BoxShadow(
                    color: Color(0x19000000),
                    blurRadius: 2,
                    offset: Offset(0, 0),
                    spreadRadius: 0,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: TextField(
                controller: _cycleLengthController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  isDense: true,
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
            const SizedBox(width: 5),
            const Text(
              '일',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveMenstrualCycleRecord,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kAccentPink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 146, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                '저장하기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }

  Future<void> _saveMenstrualCycleRecord() async {
    if (_lastPeriodStart == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('마지막 생리 시작일을 선택해주세요')),
      );
      return;
    }

    if (_lastPeriodEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('생리 종료일을 선택해주세요')),
      );
      return;
    }

    final cycleLength = int.tryParse(_cycleLengthController.text);
    if (cycleLength == null || cycleLength <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('생리주기 일수를 입력해주세요')),
      );
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

      final periodLength =
          _lastPeriodEnd!.difference(_lastPeriodStart!).inDays + 1;

      final record = MenstrualCycleRecord(
        id: widget.existingRecord?.id,
        mbId: user.id,
        lastPeriodStart: _lastPeriodStart!,
        cycleLength: _cycleLength,
        periodLength: periodLength,
      );

      bool success;
      if (widget.existingRecord != null) {
        success =
            await MenstrualCycleRepository.updateMenstrualCycleRecord(record);
      } else {
        success =
            await MenstrualCycleRepository.addMenstrualCycleRecord(record);
      }

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(widget.existingRecord != null
                    ? '생리주기 정보가 수정되었습니다'
                    : '생리주기 정보가 저장되었습니다')),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception(
            widget.existingRecord != null ? '수정에 실패했습니다' : '저장에 실패했습니다');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
