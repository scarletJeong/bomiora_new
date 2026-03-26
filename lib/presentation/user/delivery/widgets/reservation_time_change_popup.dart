import 'package:flutter/material.dart';
import '../../../../data/models/shop_default/reservation_settings_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/delivery_service.dart' as order_service;
import '../../../../data/services/shop_default_service.dart';

class ReservationTimeChangePopup extends StatefulWidget {
  final String orderId;
  final String currentDate;
  final String currentTime;

  const ReservationTimeChangePopup({
    super.key,
    required this.orderId,
    required this.currentDate,
    required this.currentTime,
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
    try {
      if (widget.currentDate.contains('T') || widget.currentDate.contains('-')) {
        _selectedDate = DateTime.parse(widget.currentDate);
      }
      _selectedTime = widget.currentTime;
    } catch (_) {}
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

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: SizedBox(
          width: 300,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '예약시간 변경',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _kInk,
                          fontSize: 20,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: ShapeDecoration(
                          color: const Color(0x33D2D2D2),
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(width: 1, color: _kBorder),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('예약정보', style: TextStyle(fontSize: 14, fontFamily: 'Gmarket Sans TTF', fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Text('예약번호: ${widget.orderId}', style: const TextStyle(fontSize: 10, fontFamily: 'Gmarket Sans TTF')),
                            const SizedBox(height: 4),
                            Text('예약일자: ${widget.currentDate}', style: const TextStyle(fontSize: 10, fontFamily: 'Gmarket Sans TTF')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '새 예약 날짜 선택',
                        style: TextStyle(color: _kMuted, fontSize: 14, fontFamily: 'Gmarket Sans TTF', fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 54,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: days.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (context, i) {
                            final d = days[i];
                            final selected = _selectedDate != null &&
                                d.year == _selectedDate!.year &&
                                d.month == _selectedDate!.month &&
                                d.day == _selectedDate!.day;
                            const w = ['월', '화', '수', '목', '금', '토', '일'];
                            return InkWell(
                              onTap: () => setState(() {
                                _selectedDate = d;
                                _selectedTime = null;
                              }),
                              child: Container(
                                width: 40,
                                decoration: BoxDecoration(
                                  color: selected ? const Color(0x0CFF5A8D) : Colors.white,
                                  border: Border.all(color: selected ? _kPink : _kBorder),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('${d.day}', style: TextStyle(fontSize: 12, fontFamily: 'Gmarket Sans TTF', color: selected ? _kPink : _kInk, fontWeight: FontWeight.w700)),
                                    Text(w[d.weekday - 1], style: TextStyle(fontSize: 10, fontFamily: 'Gmarket Sans TTF', color: selected ? _kPink : _kInk, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '희망 시간 선택',
                        style: TextStyle(color: _kMuted, fontSize: 14, fontFamily: 'Gmarket Sans TTF', fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      if (_selectedDate == null)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            '먼저 날짜를 선택해주세요.',
                            style: TextStyle(
                              color: _kMuted,
                              fontSize: 11,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 210),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const AlwaysScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 5,
                              crossAxisSpacing: 5,
                              childAspectRatio: 2.2,
                            ),
                            itemCount: times.length,
                            itemBuilder: (context, i) {
                              final t = times[i];
                              final selected = t == _selectedTime;
                              return InkWell(
                                onTap: () => setState(() => _selectedTime = t),
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: selected ? const Color(0x0CFF5A8D) : Colors.white,
                                    border: Border.all(color: selected ? _kPink : _kBorder),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    t,
                                    style: TextStyle(
                                      color: selected ? _kPink : _kInk,
                                      fontSize: 12,
                                      fontFamily: 'Gmarket Sans TTF',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                SizedBox(
                  height: 50,
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: const Color(0xFFF7F7F7),
                          child: InkWell(
                            onTap: () => Navigator.pop(context, false),
                            child: const Center(
                              child: Text(
                                '취소',
                                style: TextStyle(
                                  color: _kMuted,
                                  fontSize: 16,
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
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text(
                                      '변경',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
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
    );
  }
}
