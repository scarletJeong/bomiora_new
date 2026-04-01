import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/login_required_dialog.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../../../data/models/health/menstrual_cycle/menstrual_cycle_model.dart';
import '../../../../data/repositories/health/menstrual_cycle/menstrual_cycle_repository.dart';
import '../../../../data/services/auth_service.dart';

class MenstrualCycleInputScreen extends StatefulWidget {
  final MenstrualCycleRecord? existingRecord; // 편집할 기존 데이터

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

  // 달력 관련
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late final PageController _calendarPageController;

  static final DateTime _calendarFirstDay = DateTime.utc(2020, 1, 1);
  static final DateTime _calendarLastDay = DateTime.utc(2030, 12, 31);

  // 선택 모드 (시작일 선택 중인지 종료일 선택 중인지)
  bool _isSelectingStart = true;
  int _clickCount = 0; // 클릭 횟수 추적

  @override
  void initState() {
    super.initState();
    _cycleLengthController = TextEditingController(text: '$_cycleLength');
    _calendarPageController = PageController(
      initialPage: _monthPageIndex(_focusedDay),
      // 1.0에 매우 가깝게 두어, 다음/이전 달이 아주 조금만 보이게 합니다.
      viewportFraction: 1.0,
    );
    _loadExistingData();
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
        _focusedDay = record.lastPeriodStart;
        _selectedDay = record.lastPeriodStart;
        _clickCount = 2; // 기존 데이터가 있으면 이미 시작일과 종료일이 모두 선택된 상태
        _isSelectingStart = false; // 다음 클릭은 새로운 시작일 선택
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_calendarPageController.hasClients) {
          _calendarPageController.jumpToPage(_monthPageIndex(_focusedDay));
        }
      });
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
    return Container(
      child: Column(
        children: [
          _buildCalendarMonthHeader(),
          const SizedBox(height: 0),
          _buildWeekdayHeader(),
          const SizedBox(height: 10),
          SizedBox(
            height: 380,
            child: PageView.builder(
              controller: _calendarPageController,
              scrollDirection: Axis.vertical,
              itemBuilder: (context, index) {
                final monthDay = _monthFromPageIndex(index);
                return TableCalendar<dynamic>(
                  firstDay: _calendarFirstDay,
                  lastDay: _calendarLastDay,
                  focusedDay: monthDay,
                  rowHeight: 60,
                  daysOfWeekVisible: false,
                  headerVisible: false,
                  calendarFormat: _calendarFormat,
                  availableGestures: AvailableGestures.none,
                  onFormatChanged: (format) {
                    if (_calendarFormat != format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    }
                  },
                  onPageChanged: (focusedDay) {
                    if (!mounted) return;
                    setState(() {
                      _focusedDay = DateTime(
                          focusedDay.year, focusedDay.month, 1);
                    });
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    if (!mounted) return;
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                      _clickCount++;
                    });

                    if (_clickCount % 2 == 1) {
                      if (_lastPeriodEnd != null &&
                          selectedDay.isAfter(_lastPeriodEnd!)) {
                        _lastPeriodStart = _lastPeriodEnd;
                        _lastPeriodEnd = selectedDay;
                        _isSelectingStart = false;
                      } else {
                        _lastPeriodStart = selectedDay;
                        _lastPeriodEnd = null;
                        _isSelectingStart = true;
                      }
                    } else {
                      if (_lastPeriodStart != null &&
                          selectedDay.isAfter(_lastPeriodStart!)) {
                        _lastPeriodEnd = selectedDay;
                        _isSelectingStart = false;
                      } else if (_lastPeriodStart != null &&
                          selectedDay.isBefore(_lastPeriodStart!)) {
                        _lastPeriodEnd = _lastPeriodStart;
                        _lastPeriodStart = selectedDay;
                        _isSelectingStart = false;
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('종료일은 시작일보다 늦어야 합니다')),
                        );
                        _clickCount--;
                      }
                    }
                  },
                  selectedDayPredicate: (day) {
                    if (_lastPeriodStart != null && _lastPeriodEnd != null) {
                      return day.isAtSameMomentAs(_lastPeriodStart!) ||
                          day.isAtSameMomentAs(_lastPeriodEnd!) ||
                          (day.isAfter(_lastPeriodStart!) &&
                              day.isBefore(_lastPeriodEnd!));
                    } else if (_lastPeriodStart != null) {
                      return day.isAtSameMomentAs(_lastPeriodStart!);
                    }
                    return false;
                  },
                  rangeStartDay: _lastPeriodStart,
                  rangeEndDay: _lastPeriodEnd,
                  onRangeSelected: (start, end, focusedDay) {
                    if (!mounted) return;
                    setState(() {
                      _lastPeriodStart = start;
                      _lastPeriodEnd = end;
                      _focusedDay = focusedDay;
                    });
                  },
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    weekendTextStyle: const TextStyle(color: Colors.red),
                    holidayTextStyle: const TextStyle(color: Colors.red),
                    selectedDecoration: const BoxDecoration(
                      color: Colors.pink,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: Colors.pink[200],
                      shape: BoxShape.circle,
                    ),
                    rangeHighlightColor: Colors.transparent,
                    withinRangeDecoration: BoxDecoration(
                      color: Colors.pink[50],
                      shape: BoxShape.circle,
                    ),
                    rangeStartDecoration: const BoxDecoration(
                      color: Colors.pink,
                      shape: BoxShape.circle,
                    ),
                    rangeEndDecoration: const BoxDecoration(
                      color: Colors.pink,
                      shape: BoxShape.circle,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) =>
                        _buildCalendarDayCell(day: day),
                    todayBuilder: (context, day, focusedDay) =>
                        _buildCalendarDayCell(
                      day: day,
                      borderColor: const Color(0xFFFF5A8D),
                      textColor: const Color(0xFFFF5A8D),
                    ),
                    selectedBuilder: (context, day, focusedDay) =>
                        _buildCalendarDayCell(
                      day: day,
                      backgroundColor: const Color(0xFFFF5A8D),
                      borderColor: const Color(0xFFFF5A8D),
                      textColor: Colors.white,
                    ),
                    rangeStartBuilder: (context, day, focusedDay) =>
                        _buildCalendarDayCell(
                      day: day,
                      backgroundColor: const Color(0xFFFF5A8D),
                      borderColor: const Color(0xFFFF5A8D),
                      textColor: Colors.white,
                    ),
                    rangeEndBuilder: (context, day, focusedDay) =>
                        _buildCalendarDayCell(
                      day: day,
                      backgroundColor: const Color(0xFFFF5A8D),
                      borderColor: const Color(0xFFFF5A8D),
                      textColor: Colors.white,
                    ),
                    withinRangeBuilder: (context, day, focusedDay) =>
                        _buildCalendarDayCell(
                      day: day,
                      backgroundColor: const Color(0xFFFFEFF4),
                      borderColor: const Color(0xFFD2D2D2),
                      textColor: const Color(0xFF1A1A1A),
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                );
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
      ),
    );
  }

  // 달력 월 헤더
  Widget _buildCalendarMonthHeader() {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _showMonthDropdown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Text(
                  DateFormat('yyyy년 M월').format(_focusedDay),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, size: 18),
              ],
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  // 달력 월 드롭다운
  Future<void> _showMonthDropdown() async {
    final pickedMonth = await showDialog<int>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_focusedDay.year}년',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 12,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.1,
                  ),
                  itemBuilder: (context, index) {
                    final month = index + 1;
                    final isSelected = month == _focusedDay.month;
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => Navigator.of(dialogContext).pop(month),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFFEFF4)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFFF5A8D)
                                : const Color(0xFFD9D9D9),
                          ),
                        ),
                        child: Text(
                          '$month월',
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFFFF5A8D)
                                : const Color(0xFF1A1A1A),
                            fontSize: 13,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
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
      },
    );

    if (pickedMonth == null || !mounted) return;
    _moveToYearMonth(_focusedDay.year, pickedMonth);
  }

  void _moveToYearMonth(int year, int month) {
    final target = DateTime(year, month, 1);
    final page = _monthPageIndex(target);
    _calendarPageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
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
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 14,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCycleLengthSection() {
    return Container(
      width: double.infinity,
      child: Row(
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
      ),
    );
  }

  Widget _buildCalendarDayCell({
    required DateTime day,
    Color borderColor = const Color(0xFFD2D2D2),
    Color textColor = const Color(0xFF1A1A1A),
    Color? backgroundColor,
  }) {
    return Center(
      child: Container(
        width: 33.33,
        height: 54.17,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: backgroundColor,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: 0.42,
              color: borderColor,
            ),
            borderRadius: BorderRadius.circular(18.33),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveMenstrualCycleRecord,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF5A8D),
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
      if (user == null) {
        await showLoginRequiredDialog(
          context,
          message: '건강 기록 입력은 로그인 후 이용할 수 있습니다.',
        );
        return;
      }

      // 생리 기간 길이 계산
      final periodLength =
          _lastPeriodEnd!.difference(_lastPeriodStart!).inDays + 1;

      final record = MenstrualCycleRecord(
        id: widget.existingRecord?.id, // 편집 모드일 때 기존 ID 유지
        mbId: user.id,
        lastPeriodStart: _lastPeriodStart!,
        cycleLength: _cycleLength,
        periodLength: periodLength,
      );

      bool success;
      if (widget.existingRecord != null) {
        // 편집 모드: 업데이트
        success =
            await MenstrualCycleRepository.updateMenstrualCycleRecord(record);
      } else {
        // 새로 추가 모드: 추가
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
          Navigator.pop(context, true); // 성공 시 true 반환
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
