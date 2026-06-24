import 'package:flutter/material.dart';
import '../../../../data/models/shop_default/reservation_settings_model.dart';
import '../../../../data/services/shop_default_service.dart';
import '../../../user/healthprofile/models/health_profile_model.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import 'prescription_contact_screen.dart';

/// 진료 시간 선택 화면
class PrescriptionTimeScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final dynamic selectedOptions; // List<Map<String, dynamic>> 또는 Map<String, dynamic>? (하위 호환성)
  final Map<String, dynamic> formData;
  final HealthProfileModel? existingProfile;
  final List<int>? tempCartCtIdsToClearOnSuccess;

  const PrescriptionTimeScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.selectedOptions,
    required this.formData,
    this.existingProfile,
    this.tempCartCtIdsToClearOnSuccess,
  });

  @override
  State<PrescriptionTimeScreen> createState() => _PrescriptionTimeScreenState();
}

class _PrescriptionTimeScreenState extends State<PrescriptionTimeScreen> {
  DateTime? _selectedDate;
  String? _selectedTime;
  ReservationSettingsModel? _settings;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    final settings = await ShopDefaultService.getReservationSettings();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _isLoading = false;
    });
  }
  
  List<String> _generateTimeSlots(DateTime date) {
    if (_settings == null) return [];
    
    final daySettings = _settings!.getSettingsForDay(date.weekday);
    
    if (!daySettings.active || daySettings.startTime == null || daySettings.endTime == null) {
      return [];
    }
    
    final slots = <String>[];
    final relayTime = _settings!.relayTime;
    
    // 시작 시간 파싱 (HH:mm 형식)
    final startParts = daySettings.startTime!.split(':');
    int currentHour = int.parse(startParts[0]);
    int currentMinute = int.parse(startParts[1]);
    
    // 종료 시간 파싱
    final endParts = daySettings.endTime!.split(':');
    final endHour = int.parse(endParts[0]);
    final endMinute = int.parse(endParts[1]);
    
    // 점심시간 파싱
    int? lunchStartHour, lunchStartMinute, lunchEndHour, lunchEndMinute;
    if (_settings!.lunch.startTime != null && _settings!.lunch.endTime != null) {
      final lunchStartParts = _settings!.lunch.startTime!.split(':');
      lunchStartHour = int.parse(lunchStartParts[0]);
      lunchStartMinute = int.parse(lunchStartParts[1]);
      
      final lunchEndParts = _settings!.lunch.endTime!.split(':');
      lunchEndHour = int.parse(lunchEndParts[0]);
      lunchEndMinute = int.parse(lunchEndParts[1]);
    }
    
    // 오늘 날짜인 경우, 현재 시각 + 30분을 기준 시각으로 설정
    DateTime? minimumTime;
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    
    if (isToday) {
      minimumTime = now.add(const Duration(minutes: 30));
    }
    
    while (currentHour < endHour || (currentHour == endHour && currentMinute < endMinute)) {
      final timeStr = '${currentHour.toString().padLeft(2, '0')}:${currentMinute.toString().padLeft(2, '0')}';
      
      // 점심시간 체크
      bool isLunchTime = false;
      if (lunchStartHour != null && lunchEndHour != null) {
        final currentTimeInMinutes = currentHour * 60 + currentMinute;
        final lunchStartInMinutes = lunchStartHour * 60 + lunchStartMinute!;
        final lunchEndInMinutes = lunchEndHour * 60 + lunchEndMinute!;
        
        if (currentTimeInMinutes >= lunchStartInMinutes && currentTimeInMinutes < lunchEndInMinutes) {
          isLunchTime = true;
        }
      }
      
      // 오늘 날짜인 경우, 최소 시간 이후만 추가
      bool isValid = true;
      if (isToday && minimumTime != null) {
        final slotTime = DateTime(date.year, date.month, date.day, currentHour, currentMinute);
        if (slotTime.isBefore(minimumTime)) {
          isValid = false;
        }
      }
      
      if (!isLunchTime && isValid) {
        slots.add(timeStr);
      }
      
      // 다음 슬롯으로 이동
      currentMinute += relayTime;
      if (currentMinute >= 60) {
        currentHour += currentMinute ~/ 60;
        currentMinute = currentMinute % 60;
      }
    }
    
    return slots;
  }
  
  void _nextStep() {
    if (_selectedDate == null || _selectedTime == null) {
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrescriptionContactScreen(
          productId: widget.productId,
          productName: widget.productName,
          selectedOptions: widget.selectedOptions,
          formData: widget.formData,
          existingProfile: widget.existingProfile,
          selectedDate: _selectedDate!,
          selectedTime: _selectedTime!,
          tempCartCtIdsToClearOnSuccess: widget.tempCartCtIdsToClearOnSuccess,
        ),
      ),
    );
  }

  String _buildReservationGuideText() {
    if (_selectedDate == null || _selectedTime == null) return '';
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[_selectedDate!.weekday - 1];
    final parts = _selectedTime!.split(':');
    if (parts.length != 2) {
      return '${_selectedDate!.month.toString().padLeft(2, '0')}월 ${_selectedDate!.day.toString().padLeft(2, '0')}일 ($weekday) $_selectedTime ';
    }
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final end = DateTime(2000, 1, 1, h, m).add(const Duration(minutes: 30));
    final endText =
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    return '${_selectedDate!.month.toString().padLeft(2, '0')}월 ${_selectedDate!.day.toString().padLeft(2, '0')}일 ($weekday) $_selectedTime ~ $endText ';
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MobileAppLayoutWrapper(
        appBar: null,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    // 예약 가능한 날짜 생성 (오늘부터 7일)
    final availableDates = List.generate(7, (index) {
      final date = DateTime.now().add(Duration(days: index));
      return date;
    });
    
    // 선택된 날짜의 예약 가능한 시간
    final availableTimes =
        _selectedDate != null ? _generateTimeSlots(_selectedDate!) : <String>[];
    final hasSelectedDateTime = _selectedDate != null && _selectedTime != null;
    
    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(
        title: '03 진료 시간 예약', centerTitle: false,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context)
              .textTheme
              .apply(fontFamily: 'Gmarket Sans TTF'),
          primaryTextTheme: Theme.of(context)
              .primaryTextTheme
              .apply(fontFamily: 'Gmarket Sans TTF'),
        ),
        child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(healthDp(context, 20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. 가능한 날짜를 선택해주세요',
                    style: TextStyle(
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 12)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: availableDates.take(7).map((date) {
                      final isSelected = _selectedDate != null &&
                          _selectedDate!.year == date.year &&
                          _selectedDate!.month == date.month &&
                          _selectedDate!.day == date.day;
                      final isToday = DateUtils.isSameDay(date, DateTime.now());
                      final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
                      final weekday = weekdays[date.weekday - 1];
                      return InkWell(
                        onTap: () => setState(() {
                          _selectedDate = date;
                          _selectedTime = null;
                        }),
                        borderRadius: BorderRadius.circular(healthDp(context, 18.33)),
                        child: Container(
                          width: healthDp(context, 40),
                          height: healthDp(context, 54.17),
                          decoration: ShapeDecoration(
                            color: isSelected
                                ? const Color(0x0CFF5A8D)
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(
                                width: isSelected
                                    ? healthDp(context, 1)
                                    : healthDp(context, 0.5),
                                color: isSelected
                                    ? const Color(0xFFFF5A8D)
                                    : const Color(0xFFD2D2D2),
                              ),
                              borderRadius: BorderRadius.circular(healthDp(context, 18.33)),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isToday)
                                Text(
                                  '오늘',
                                  style: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFFFF5A8D)
                                        : const Color(0xFF1A1A1A),
                                    fontSize: healthSp(context, 10),
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                              if (isToday) SizedBox(height: healthDp(context, 2)),
                              Text(
                                '${date.day}',
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFFFF5A8D)
                                      : const Color(0xFF1A1A1A),
                                  fontSize: healthSp(context, 12),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: healthDp(context, 5)),
                              Text(
                                weekday,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFFFF5A8D)
                                      : const Color(0xFF1A1A1A),
                                  fontSize: healthSp(context, 10),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: healthDp(context, 32)),
                  Text(
                    '2. 시간을 선택해주세요',
                    style: TextStyle(
                      fontSize: healthSp(context, 14),
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Gmarket Sans TTF',
                    ),
                  ),
                  SizedBox(height: healthDp(context, 12)),
                  if (_selectedDate == null)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(healthDp(context, 16)),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(healthDp(context, 10)),
                      ),
                      child: Center(
                        child: Text(
                          '날짜를 먼저 선택해주세요',
                          style: TextStyle(
                            fontSize: healthSp(context, 14),
                            color: Colors.grey,
                            fontFamily: 'Gmarket Sans TTF',
                          ),
                        ),
                      ),
                    )
                  else if (availableTimes.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(healthDp(context, 16)),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(healthDp(context, 10)),
                      ),
                      child: Center(
                        child: Text(
                          '예약 가능한 시간이 없습니다',
                          style: TextStyle(
                            fontSize: healthSp(context, 14),
                            color: Colors.grey,
                            fontFamily: 'Gmarket Sans TTF',
                          ),
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisExtent: healthDp(context, 42),
                        crossAxisSpacing: healthDp(context, 10),
                        mainAxisSpacing: healthDp(context, 10),
                      ),
                      itemCount: availableTimes.length,
                      itemBuilder: (context, index) {
                        final time = availableTimes[index];
                        final isSelected = _selectedTime == time;
                        return InkWell(
                          onTap: () => setState(() => _selectedTime = time),
                          borderRadius: BorderRadius.circular(healthDp(context, 10)),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: healthDp(context, 5),
                              vertical: healthDp(context, 10),
                            ),
                            decoration: ShapeDecoration(
                              color: isSelected
                                  ? const Color(0x0CFF5A8D)
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  width: healthDp(context, 1),
                                  color: isSelected
                                      ? const Color(0xFFFF5A8D)
                                      : const Color(0xFFD2D2D2),
                                ),
                                borderRadius: BorderRadius.circular(healthDp(context, 10)),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  time,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFFFF5A8D)
                                        : const Color(0xFF1A1A1A),
                                    fontSize: healthSp(context, 12),
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  SizedBox(height: healthDp(context, 30)),
                  if (!hasSelectedDateTime)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 5),
                        vertical: healthDp(context, 15),
                      ),
                      decoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            width: healthDp(context, 1),
                            color: const Color(0xFFD2D2D2),
                          ),
                          borderRadius: BorderRadius.circular(healthDp(context, 10)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '날짜',
                                  style: TextStyle(
                                    color: const Color(0xFFFF5A8D),
                                    fontSize: healthSp(context, 12),
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                TextSpan(
                                  text: '와 ',
                                  style: TextStyle(
                                    color: const Color(0xFF1A1A1A),
                                    fontSize: healthSp(context, 12),
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                TextSpan(
                                  text: '시간',
                                  style: TextStyle(
                                    color: const Color(0xFFFF5A8D),
                                    fontSize: healthSp(context, 12),
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                TextSpan(
                                  text: '을 선택해 주세요.',
                                  style: TextStyle(
                                    color: const Color(0xFF1A1A1A),
                                    fontSize: healthSp(context, 12),
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 5),
                        vertical: healthDp(context, 15),
                      ),
                      decoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            width: healthDp(context, 1),
                            color: const Color(0xFFD2D2D2),
                          ),
                          borderRadius: BorderRadius.circular(healthDp(context, 10)),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '‘결제 완료’',
                                  style: TextStyle(
                                    color: const Color(0xFF1A1A1A),
                                    fontSize: healthSp(context, 12),
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: '를 하셔야 예약이 확정됩니다.',
                                  style: TextStyle(
                                    color: const Color(0xFF1A1A1A),
                                    fontSize: healthSp(context, 12),
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '상담전화는 ',
                                  style: TextStyle(
                                    color: const Color(0xFF1A1A1A),
                                    fontSize: healthSp(context, 12),
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                TextSpan(
                                  text: _buildReservationGuideText(),
                                  style: TextStyle(
                                    color: const Color(0xFFFF5A8D),
                                    fontSize: healthSp(context, 12),
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: '사이에 \n드리겠습니다',
                                  style: TextStyle(
                                    color: const Color(0xFF1A1A1A),
                                    fontSize: healthSp(context, 12),
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              healthDp(context, 27),
              0,
              healthDp(context, 27),
              healthDp(context, 20),
            ),
            color: Colors.white,
            child: Row(
              children: [
                SizedBox(
                  width: healthDp(context, 72),
                  height: healthDp(context, 34),
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      minimumSize: Size(
                        healthDp(context, 72),
                        healthDp(context, 34),
                      ),
                      maximumSize: Size(
                        healthDp(context, 72),
                        healthDp(context, 34),
                      ),
                      padding: EdgeInsets.zero,
                      backgroundColor: const Color(0x26D2D2D2),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 7)),
                      ),
                    ),
                    child: Text(
                      '이전',
                      style: TextStyle(
                        color: const Color(0xFF898686),
                        fontSize: healthSp(context, 14),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: healthDp(context, 10)),
                Expanded(
                  child: SizedBox(
                    height: healthDp(context, 34),
                    child: ElevatedButton(
                      onPressed: hasSelectedDateTime ? _nextStep : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(
                          double.infinity,
                          healthDp(context, 34),
                        ),
                        maximumSize: Size(
                          double.infinity,
                          healthDp(context, 34),
                        ),
                        padding: EdgeInsets.zero,
                        backgroundColor: const Color(0xFFFF5A8D),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            const Color(0xFFFF5A8D).withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 7)),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        '다음',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: healthSp(context, 14),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
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
    );
  }
}
