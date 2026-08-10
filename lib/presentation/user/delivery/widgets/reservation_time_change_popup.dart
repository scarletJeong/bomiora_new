import 'package:flutter/material.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/shop_default/reservation_settings_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/delivery_service.dart' as order_service;
import '../../../../data/services/shop_default_service.dart';
import '../../../common/widgets/app_toast_overlay.dart';
import '../../../health/health_common/health_responsive_scale.dart';

/// [ReservationTimeChangePopup.pickOnly] true 시 API 없이 선택만 반환
class ReservationPickResult {
  final DateTime date;
  final String time;

  const ReservationPickResult({required this.date, required this.time});
}

class ReservationTimeChangePopup extends StatefulWidget {
  final String orderId;
  final String currentDate;
  final String currentTime;

  /// true: 예약 변경 API 호출 없이 날짜·시간만 반환 (교환/환불 상담 예약 등)
  final bool pickOnly;
  final String title;
  final String confirmLabel;

  const ReservationTimeChangePopup({
    super.key,
    required this.orderId,
    required this.currentDate,
    required this.currentTime,
    this.pickOnly = false,
    this.title = '예약 시간 변경',
    this.confirmLabel = '변경',
  });

  @override
  State<ReservationTimeChangePopup> createState() =>
      _ReservationTimeChangePopupState();
}

class _ReservationTimeChangePopupState
    extends State<ReservationTimeChangePopup> {
  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kInk = Color(0xFF1A1A1E);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kBorder = Color(0xFFD2D2D2);
  static const String _font = 'Gmarket Sans TTF';
  static const List<String> _weekdayLabels = [
    '월',
    '화',
    '수',
    '목',
    '금',
    '토',
    '일',
  ];

  /// 새로 고른 날짜·시간 (둘 다 있어야 「새로운 예약 일정」표시)
  DateTime? _selectedDate;
  String? _selectedTime;
  ReservationSettingsModel? _settings;
  bool _isLoading = true;
  bool _isSubmitting = false;

  DateTime? get _currentDateParsed =>
      DateDisplayFormatter.tryParseYmdFlexible(widget.currentDate) ??
      _tryParseCurrentDateStrict();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  DateTime? _tryParseCurrentDateStrict() {
    try {
      if (widget.currentDate.contains('T') ||
          widget.currentDate.contains('-')) {
        return DateTime.parse(widget.currentDate);
      }
    } catch (_) {}
    return null;
  }

  bool _isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _endTimeFor(String startHhmm) {
    final parts = startHhmm.split(':');
    if (parts.length < 2) return startHhmm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final relay = _settings?.relayTime ?? 30;
    final total = h * 60 + m + relay;
    final eh = (total ~/ 60) % 24;
    final em = total % 60;
    return '${eh.toString().padLeft(2, '0')}:${em.toString().padLeft(2, '0')}';
  }

  /// 예: `06월 11일(수)  14:30 ~15:00`
  String _formatScheduleLine(DateTime d, String startTime) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final wd = _weekdayLabels[d.weekday - 1];
    final end = _endTimeFor(startTime);
    return '$mm월 $dd일($wd)  $startTime ~$end';
  }

  Future<void> _loadSettings() async {
    final settings = await ShopDefaultService.getReservationSettings();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _isLoading = false;
    });
  }

  List<String> _timesFor(DateTime date) {
    if (_settings == null) return [];
    final day = _settings!.getSettingsForDay(date.weekday);
    if (!day.active || day.startTime == null || day.endTime == null) {
      return [];
    }

    final start = day.startTime!.split(':');
    final end = day.endTime!.split(':');
    var hour = int.parse(start[0]);
    var minute = int.parse(start[1]);
    final endHour = int.parse(end[0]);
    final endMinute = int.parse(end[1]);

    int? lunchStart;
    int? lunchEnd;
    if (_settings!.lunch.startTime != null &&
        _settings!.lunch.endTime != null) {
      final ls = _settings!.lunch.startTime!.split(':');
      final le = _settings!.lunch.endTime!.split(':');
      lunchStart = int.parse(ls[0]) * 60 + int.parse(ls[1]);
      lunchEnd = int.parse(le[0]) * 60 + int.parse(le[1]);
    }

    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final minimum = isToday ? now.add(const Duration(minutes: 30)) : null;
    final list = <String>[];

    while (hour < endHour || (hour == endHour && minute < endMinute)) {
      final total = hour * 60 + minute;
      final inLunch = lunchStart != null &&
          lunchEnd != null &&
          total >= lunchStart &&
          total < lunchEnd;
      final beforeNow =
          minimum != null && total < (minimum.hour * 60 + minimum.minute);
      if (!inLunch && !beforeNow) {
        list.add(
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
        );
      }
      minute += _settings!.relayTime;
      if (minute >= 60) {
        minute -= 60;
        hour++;
      }
    }
    return list;
  }

  Future<void> _submit() async {
    if (_selectedDate == null || _selectedTime == null || _isSubmitting) {
      return;
    }

    if (widget.pickOnly) {
      Navigator.pop(
        context,
        ReservationPickResult(date: _selectedDate!, time: _selectedTime!),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final user = await AuthService.getUser();
    if (user == null) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      return;
    }

    final day =
        '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
    final result = await order_service.OrderService.changeReservationTime(
      odId: widget.orderId,
      mbId: user.id,
      reservationDate: day,
      reservationTime: _selectedTime!,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (result['success'] == true) {
      AppToastOverlay.show(context, '예약시간이 변경되었습니다.');
      Navigator.pop(context, true);
    }
  }

  Widget _buildScheduleBanner({
    required BuildContext context,
    required Color background,
    required Color labelColor,
    required Color valueColor,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      height: healthDp(context, 46),
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 21)),
      color: background,
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: healthSp(context, 12),
              fontFamily: _font,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          SizedBox(width: healthDp(context, 8)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: healthSp(context, 12),
                fontFamily: _font,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayChip(
    BuildContext context,
    DateTime d,
    DateTime todayBase,
    bool selected,
  ) {
    final isToday = _isSameCalendarDay(d, todayBase);
    final ink = selected ? _kPink : _kInk;
    final mutedLabel = selected ? _kPink : _kMuted;

    return Container(
      width: healthDp(context, 32),
      height: healthDp(context, isToday ? 58 : 54),
      decoration: ShapeDecoration(
        color: selected ? const Color(0x0CFF5A8D) : Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1.11),
            color: selected ? _kPink : _kBorder,
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 18)),
        ),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: healthDp(context, 4)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isToday) ...[
                Text(
                  '오늘',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: mutedLabel,
                    fontSize: healthSp(context, 10),
                    fontFamily: _font,
                    fontWeight: FontWeight.w300,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: healthDp(context, 1)),
              ],
              Text(
                '${d.day}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ink,
                  fontSize: healthSp(context, 12),
                  fontFamily: _font,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              SizedBox(height: healthDp(context, 1)),
              Text(
                _weekdayLabels[d.weekday - 1],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ink,
                  fontSize: healthSp(context, 10),
                  fontFamily: _font,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeChip(BuildContext context, String time, bool selected) {
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTime = time),
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 5),
            vertical: healthDp(context, 10),
          ),
          decoration: ShapeDecoration(
            color: selected ? const Color(0x0CFF5A8D) : Colors.transparent,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: 1,
                color: selected ? _kPink : _kBorder,
              ),
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            time,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? _kPink : _kInk,
              fontSize: healthSp(context, 12),
              fontFamily: _font,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTimeRows(BuildContext context, List<String> times) {
    final rows = <Widget>[];
    for (var i = 0; i < times.length; i += 4) {
      final chunk = times.sublist(i, (i + 4).clamp(0, times.length));
      rows.add(
        Row(
          children: [
            for (var j = 0; j < 4; j++) ...[
              if (j > 0) SizedBox(width: healthDp(context, 10)),
              if (j < chunk.length)
                _buildTimeChip(context, chunk[j], chunk[j] == _selectedTime)
              else
                const Expanded(child: SizedBox()),
            ],
          ],
        ),
      );
      if (i + 4 < times.length) {
        rows.add(SizedBox(height: healthDp(context, 10)));
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    final days = List.generate(7, (i) => base.add(Duration(days: i)));
    final times =
        _selectedDate == null ? <String>[] : _timesFor(_selectedDate!);

    final currentDate = _currentDateParsed;
    final currentTime = widget.currentTime.trim();
    final currentSchedule = (currentDate != null && currentTime.isNotEmpty)
        ? _formatScheduleLine(currentDate, currentTime)
        : '-';

    final showNewSchedule =
        _selectedDate != null && (_selectedTime ?? '').isNotEmpty;
    final newSchedule = showNewSchedule
        ? _formatScheduleLine(_selectedDate!, _selectedTime!)
        : null;

    final popupW = healthDp(context, 321);
    final popupRadius = healthDp(context, 20);
    final maxPopupH = MediaQuery.sizeOf(context).height - healthDp(context, 48);
    final canSubmit =
        _selectedDate != null && _selectedTime != null && !_isSubmitting;

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: popupW,
            maxHeight: maxPopupH,
          ),
          child: Container(
            width: popupW,
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(popupRadius),
              ),
              shadows: const [
                BoxShadow(
                  color: Color(0x21000000),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            top: healthDp(context, 20),
                            bottom: healthDp(context, 20),
                            left: healthDp(context, 20),
                            right: healthDp(context, 20),
                          ),
                          child: Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _kInk,
                              fontSize: healthSp(context, 20),
                              fontFamily: _font,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                        ),
                        _buildScheduleBanner(
                          context: context,
                          background: const Color(0xFFF6F6F6),
                          labelColor: _kInk,
                          valueColor: Colors.black,
                          label: '현재 예약 일정 :',
                          value: currentSchedule,
                        ),
                        if (showNewSchedule)
                          _buildScheduleBanner(
                            context: context,
                            background: const Color(0x0CFF5A8D),
                            labelColor: _kPink,
                            valueColor: _kPink,
                            label: '새로운 예약 일정 :',
                            value: newSchedule!,
                          ),
                        Padding(
                          padding: EdgeInsets.only(
                            top: healthDp(context, 20),
                            left: healthDp(context, 20),
                            right: healthDp(context, 20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '날짜 선택',
                                    style: TextStyle(
                                      color: _kMuted,
                                      fontSize: healthSp(context, 14),
                                      fontFamily: _font,
                                      fontWeight: FontWeight.w500,
                                      height: 1.57,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '*최대 7일 이내 선택 가능',
                                    style: TextStyle(
                                      color: _kMuted,
                                      fontSize: healthSp(context, 10),
                                      fontFamily: _font,
                                      fontWeight: FontWeight.w300,
                                      height: 2.2,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: healthDp(context, 5)),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  for (final d in days)
                                    InkWell(
                                      onTap: () => setState(() {
                                        _selectedDate = d;
                                        _selectedTime = null;
                                      }),
                                      borderRadius: BorderRadius.circular(
                                        healthDp(context, 18),
                                      ),
                                      child: _buildDayChip(
                                        context,
                                        d,
                                        base,
                                        _selectedDate != null &&
                                            _isSameCalendarDay(
                                              d,
                                              _selectedDate!,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: healthDp(context, 20)),
                              Text(
                                '시간 선택',
                                style: TextStyle(
                                  color: _kMuted,
                                  fontSize: healthSp(context, 14),
                                  fontFamily: _font,
                                  fontWeight: FontWeight.w500,
                                  height: 1.57,
                                ),
                              ),
                              SizedBox(height: healthDp(context, 10)),
                              if (_selectedDate == null)
                                SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    '날짜를 먼저 선택해주세요.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _kMuted,
                                      fontSize: healthSp(context, 11),
                                      fontFamily: _font,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                )
                              else if (_isLoading)
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: healthDp(context, 16),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else if (times.isEmpty)
                                Text(
                                  '선택 가능한 시간이 없습니다.',
                                  style: TextStyle(
                                    color: _kMuted,
                                    fontSize: healthSp(context, 11),
                                    fontFamily: _font,
                                    fontWeight: FontWeight.w400,
                                  ),
                                )
                              else
                                ..._buildTimeRows(context, times),
                              SizedBox(height: healthDp(context, 20)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: healthDp(context, 50),
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: const Color(0xFFF7F7F7),
                          child: InkWell(
                            onTap: () => Navigator.pop(context, false),
                            child: Center(
                              child: Text(
                                '취소',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _kMuted,
                                  fontSize: healthSp(context, 16),
                                  fontFamily: _font,
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Material(
                          color: canSubmit
                              ? _kPink
                              : _kPink.withValues(alpha: 0.45),
                          child: InkWell(
                            onTap: canSubmit ? _submit : null,
                            child: Center(
                              child: _isSubmitting
                                  ? SizedBox(
                                      width: healthDp(context, 20),
                                      height: healthDp(context, 20),
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      widget.confirmLabel,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: healthSp(context, 16),
                                        fontFamily: _font,
                                        fontWeight: FontWeight.w500,
                                        height: 1.5,
                                      ),
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
      ),
    );
  }
}
