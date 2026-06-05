import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/shop_default/reservation_settings_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/delivery_service.dart' as order_service;
import '../../../../data/services/shop_default_service.dart';
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
    this.title = '예약시간 변경',
    this.confirmLabel = '변경',
  });

  @override
  State<ReservationTimeChangePopup> createState() => _ReservationTimeChangePopupState();
}

class _ReservationTimeChangePopupState extends State<ReservationTimeChangePopup> {
  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kInk = Color(0xFF1A1A1A);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kBorder = Color(0xFFD2D2D2);

  DateTime? _selectedDate;
  String? _selectedTime;
  ReservationSettingsModel? _settings;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _parseCurrentDate();
    _loadSettings();
  }

  void _parseCurrentDate() {
    _selectedDate =
        DateDisplayFormatter.tryParseYmdFlexible(widget.currentDate) ??
            _tryParseCurrentDateStrict();
    _selectedTime = widget.currentTime;
  }

  DateTime? _tryParseCurrentDateStrict() {
    try {
      if (widget.currentDate.contains('T') || widget.currentDate.contains('-')) {
        return DateTime.parse(widget.currentDate);
      }
    } catch (_) {}
    return null;
  }

  String _formatYmdWeekdayParen(DateTime d) {
    const w = ['월', '화', '수', '목', '금', '토', '일'];
    final y = d.year;
    final mo = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y.$mo.$day(${w[d.weekday - 1]})';
  }

  String _formatMeridiemTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return hhmm;
    var h = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1].length >= 2 ? parts[1].substring(0, 2) : parts[1];
    final isPm = h >= 12;
    final label = isPm ? '오후' : '오전';
    var h12 = h % 12;
    if (h12 == 0) h12 = 12;
    return '$label $h12:$minute';
  }

  static const List<String> _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  bool _isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  TextStyle _dayChipTextStyle(
    BuildContext context, {
    required Color color,
    required double fontSize,
    required FontWeight fontWeight,
  }) {
    return TextStyle(
      color: color,
      fontSize: healthSp(context, fontSize),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: fontWeight,
      height: 1,
    );
  }

  Widget _buildDayChip(BuildContext context, DateTime d, DateTime todayBase, bool selected) {
    final isToday = _isSameCalendarDay(d, todayBase);
    final ink = selected ? _kPink : _kInk;
    final chipH = healthDp(context, 54);
    final chipRadius = healthDp(context, 18.33);
    final dayWeekdayGap = healthDp(context, 5);
    final decoration = BoxDecoration(
      color: selected ? const Color(0x0CFF5A8D) : Colors.white,
      border: Border.all(
        width: healthDp(context, 1),
        color: selected ? _kPink : _kBorder,
      ),
      borderRadius: BorderRadius.circular(chipRadius),
    );

    if (isToday) {
      return Container(
        width: healthDp(context, 32),
        height: chipH,
        clipBehavior: Clip.antiAlias,
        decoration: decoration,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '오늘',
              style: _dayChipTextStyle(context, color: ink, fontSize: 10, fontWeight: FontWeight.w300),
            ),
            SizedBox(height: healthDp(context, 2)),
            Text(
              '${d.day}',
              style: _dayChipTextStyle(context, color: ink, fontSize: 12, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: healthDp(context, 2)),
            Text(
              _weekdayLabels[d.weekday - 1],
              style: _dayChipTextStyle(context, color: ink, fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Container(
      width: healthDp(context, 32),
      height: chipH,
      clipBehavior: Clip.antiAlias,
      decoration: decoration,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${d.day}',
            style: _dayChipTextStyle(context, color: ink, fontSize: 12, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: dayWeekdayGap),
          Text(
            _weekdayLabels[d.weekday - 1],
            style: _dayChipTextStyle(context, color: ink, fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedReservationPreviewCard(BuildContext context) {
    if (_selectedDate == null) return const SizedBox.shrink();
    final d = _selectedDate!;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 10)),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _kBorder),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset(
            AppAssets.reservationCalendarIcon,
            width: healthDp(context, 18),
            height: healthDp(context, 20),
          ),
          SizedBox(height: healthDp(context, 5)),
          Text(
            '진료 예약일자',
            style: TextStyle(
              color: _kInk,
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          Text(
            _formatYmdWeekdayParen(d),
            style: TextStyle(
              color: _kPink,
              fontSize: healthSp(context, 14),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          if (_selectedTime != null) ...[
            SizedBox(height: healthDp(context, 5)),
            Text(
              _formatMeridiemTime(_selectedTime!),
              style: TextStyle(
                color: _kInk,
                fontSize: healthSp(context, 14),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
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
    if (!day.active || day.startTime == null || day.endTime == null) return [];

    final start = day.startTime!.split(':');
    final end = day.endTime!.split(':');
    int hour = int.parse(start[0]);
    int minute = int.parse(start[1]);
    final endHour = int.parse(end[0]);
    final endMinute = int.parse(end[1]);

    int? lunchStart;
    int? lunchEnd;
    if (_settings!.lunch.startTime != null && _settings!.lunch.endTime != null) {
      final ls = _settings!.lunch.startTime!.split(':');
      final le = _settings!.lunch.endTime!.split(':');
      lunchStart = int.parse(ls[0]) * 60 + int.parse(ls[1]);
      lunchEnd = int.parse(le[0]) * 60 + int.parse(le[1]);
    }

    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final minimum = isToday ? now.add(const Duration(minutes: 30)) : null;
    final list = <String>[];

    while (hour < endHour || (hour == endHour && minute < endMinute)) {
      final total = hour * 60 + minute;
      final inLunch = lunchStart != null && lunchEnd != null && total >= lunchStart && total < lunchEnd;
      final beforeNow = minimum != null && total < (minimum.hour * 60 + minimum.minute);
      if (!inLunch && !beforeNow) {
        list.add('${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
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
    if (_selectedDate == null || _selectedTime == null || _isSubmitting) return;

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
    Navigator.pop(context, result['success'] == true);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    final days = List.generate(7, (i) => base.add(Duration(days: i)));
    final times = _selectedDate == null ? <String>[] : _timesFor(_selectedDate!);

    final popupW = healthDp(context, 332);
    final popupRadius = healthDp(context, 20);
    final pad20 = healthDp(context, 20);
    final pad10 = healthDp(context, 10);
    final gap5 = healthDp(context, 5);
    final chipListH = healthDp(context, 54);
    final btnH = healthDp(context, 50);
    final maxPopupH = MediaQuery.sizeOf(context).height - healthDp(context, 48);

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: popupW,
            maxHeight: maxPopupH,
          ),
          child: SizedBox(
            width: popupW,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(popupRadius),
              child: Material(
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(top: pad20, left: pad20, right: pad20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _kInk,
                          fontSize: healthSp(context, 20),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: pad20),
                      Container(
                        padding: EdgeInsets.all(pad10),
                        decoration: ShapeDecoration(
                          color: const Color(0x33D2D2D2),
                          shape: RoundedRectangleBorder(
                            side: BorderSide(width: healthDp(context, 1), color: _kBorder),
                            borderRadius: BorderRadius.circular(healthDp(context, 10)),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '예약정보',
                              style: TextStyle(
                                fontSize: healthSp(context, 14),
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: pad10),
                            Text(
                              '예약번호: ${widget.orderId}',
                              style: TextStyle(
                                fontSize: healthSp(context, 10),
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w300,
                                color: _kInk,
                              ),
                            ),
                            SizedBox(height: gap5),
                            Text(
                              '예약일자: ${DateDisplayFormatter.formatKoreanDateFromString(widget.currentDate)}',
                              style: TextStyle(
                                fontSize: healthSp(context, 10),
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w300,
                                color: _kInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: pad20),
                      _buildSelectedReservationPreviewCard(context),
                      SizedBox(height: pad20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '새 예약일자 선택',
                            style: TextStyle(
                              color: _kMuted,
                              fontSize: healthSp(context, 14),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '*최대 7일 이내 선택 가능',
                            style: TextStyle(
                              color: _kMuted,
                              fontSize: healthSp(context, 10),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                              height: 2.20,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: gap5),
                      SizedBox(
                        height: chipListH,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: days.length,
                          separatorBuilder: (_, __) => SizedBox(width: pad10),
                          itemBuilder: (ctx, i) {
                            final d = days[i];
                            final selected = _selectedDate != null && _isSameCalendarDay(d, _selectedDate!);
                            return InkWell(
                              onTap: () => setState(() {
                                _selectedDate = d;
                                _selectedTime = null;
                              }),
                              child: _buildDayChip(context, d, base, selected),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: pad20),
                      Text(
                        '시간 선택',
                        style: TextStyle(
                          color: _kMuted,
                          fontSize: healthSp(context, 14),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 10),
                      if (_selectedDate == null)
                        Padding(
                          padding: EdgeInsets.only(bottom: healthDp(context, 10)),
                          child: Text(
                            '먼저 날짜를 선택해주세요.',
                            style: TextStyle(
                              color: _kMuted,
                              fontSize: healthSp(context, 11),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      if (_isLoading)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: healthDp(context, 16)),
                          child: const Center(child: CircularProgressIndicator()),
                        )
                      else
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: healthDp(context, 210)),
                          child: SingleChildScrollView(
                            child: Wrap(
                              spacing: pad10,
                              runSpacing: pad10,
                              children: times.map((t) {
                                final selected = t == _selectedTime;
                                return SizedBox(
                                  width: healthDp(context, 62.8),
                                  height: healthDp(context, 34),
                                  child: InkWell(
                                    onTap: () => setState(() => _selectedTime = t),
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: selected ? const Color(0x0CFF5A8D) : Colors.white,
                                        border: Border.all(
                                          width: healthDp(context, 1),
                                          color: selected ? _kPink : _kBorder,
                                        ),
                                        borderRadius: BorderRadius.circular(healthDp(context, 10)),
                                      ),
                                      child: Text(
                                        t,
                                        style: TextStyle(
                                          color: selected ? _kPink : _kInk,
                                          fontSize: healthSp(context, 12),
                                          fontFamily: 'Gmarket Sans TTF',
                                          fontWeight: FontWeight.w500,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      SizedBox(height: pad20),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      height: btnH,
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
                                style: TextStyle(
                                  color: _kMuted,
                                  fontSize: healthSp(context, 16),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Material(
                          color: _kPink,
                          child: InkWell(
                            onTap: (_selectedDate != null && _selectedTime != null && !_isSubmitting) ? _submit : null,
                            child: Center(
                              child: _isSubmitting
                                  ? SizedBox(
                                      width: healthDp(context, 20),
                                      height: healthDp(context, 20),
                                      child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(
                                      widget.confirmLabel,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: healthSp(context, 16),
                                        fontFamily: 'Gmarket Sans TTF',
                                        fontWeight: FontWeight.w500,
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
      ),
    ),
    );
  }
}
