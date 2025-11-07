import 'package:flutter/material.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/models/shop_default/reservation_settings_model.dart';
import '../../../../data/services/shop_default_service.dart';
import '../../../user/healthprofile/models/health_profile_model.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import 'prescription_contact_screen.dart';

/// 진료 시간 선택 화면
class PrescriptionTimeScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final Map<String, dynamic>? selectedOptions;
  final Map<String, dynamic> formData;
  final HealthProfileModel? existingProfile;
  
  const PrescriptionTimeScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.selectedOptions,
    required this.formData,
    this.existingProfile,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('진료 날짜와 시간을 선택해주세요')),
      );
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
        ),
      ),
    );
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
    final availableTimes = _selectedDate != null ? _generateTimeSlots(_selectedDate!) : <String>[];
    
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: const Text(
          '처방예약하기',
          style: TextStyle(
            fontSize: 18,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      child: Column(
        children: [
          // 진행률 표시
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '03 진료시간선택',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFFF3787),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: List.generate(4, (index) {
                    final stepIndex = index + 1;
                    final isActive = stepIndex == 3; // 진료시간선택은 3번
                    final isCompleted = stepIndex < 3; // 2번까지 완료
                    return Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive ? const Color(0xFFFF3787) : 
                                   isCompleted ? const Color(0xFFFF3787) : Colors.grey[300],
                          ),
                          child: Center(
                            child: Text(
                              '$stepIndex',
                              style: TextStyle(
                                color: (isActive || isCompleted) ? Colors.white : Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        if (index < 3) const SizedBox(width: 8),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
          // 페이지 컨텐츠
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 가능한 날짜를 선택해주세요
                  const Text(
                    '1. 가능한 날짜를 선택해주세요',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: availableDates.length,
                    itemBuilder: (context, index) {
                      final date = availableDates[index];
                      final isSelected = _selectedDate != null &&
                          _selectedDate!.year == date.year &&
                          _selectedDate!.month == date.month &&
                          _selectedDate!.day == date.day;
                      
                      final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
                      final weekday = weekdays[date.weekday - 1];
                      
                      return InkWell(
                        onTap: () => setState(() {
                          _selectedDate = date;
                          _selectedTime = null; // 날짜 변경 시 시간 초기화
                        }),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFFF0F5) : Colors.white,
                            border: Border.all(
                              color: isSelected ? const Color(0xFFFF3787) : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${date.month}/${date.day}($weekday)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? const Color(0xFFFF3787) : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  
                  // 2. 시간을 선택해주세요
                  const Text(
                    '2. 시간을 선택해주세요',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_selectedDate == null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          '먼저 날짜를 선택해주세요',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                  else if (availableTimes.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          '예약 가능한 시간이 없습니다',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 2.5,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: availableTimes.length,
                      itemBuilder: (context, index) {
                        final time = availableTimes[index];
                        final isSelected = _selectedTime == time;
                        
                        return InkWell(
                          onTap: () => setState(() => _selectedTime = time),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFFF0F5) : Colors.white,
                              border: Border.all(
                                color: isSelected ? const Color(0xFFFF3787) : Colors.grey[300]!,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                time,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? const Color(0xFFFF3787) : Colors.black,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          // 하단 버튼
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: const Text(
                      '이전',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3787),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '다음',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

