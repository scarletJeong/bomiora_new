import 'package:flutter/material.dart';
import '../../../data/models/shop_default/reservation_settings_model.dart';
import '../../../data/services/shop_default_service.dart';
import '../../../data/services/delivery_service.dart' as OrderService;
import '../../../data/services/auth_service.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';

/// 예약 시간 변경 화면
class ReservationTimeChangeScreen extends StatefulWidget {
  final String orderId; // String으로 변경 (큰 숫자 정밀도 손실 방지)
  final String currentDate;
  final String currentTime;

  const ReservationTimeChangeScreen({
    super.key,
    required this.orderId,
    required this.currentDate,
    required this.currentTime,
  });

  @override
  State<ReservationTimeChangeScreen> createState() => _ReservationTimeChangeScreenState();
}

class _ReservationTimeChangeScreenState extends State<ReservationTimeChangeScreen> {
  DateTime? _selectedDate;
  String? _selectedTime;
  ReservationSettingsModel? _settings;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _parseCurrentDateTime();
  }

  /// 현재 예약 날짜/시간 파싱
  void _parseCurrentDateTime() {
    try {
      // ISO 8601 형식 또는 다른 형식 파싱
      DateTime date;
      if (widget.currentDate.contains('T')) {
        date = DateTime.parse(widget.currentDate);
      } else if (widget.currentDate.contains('-')) {
        date = DateTime.parse(widget.currentDate);
      } else {
        return;
      }
      
      setState(() {
        _selectedDate = date;
        _selectedTime = widget.currentTime;
      });
    } catch (e) {
      print('❌ 예약 날짜 파싱 오류: $e');
    }
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
      if (lunchStartHour != null && lunchStartMinute != null && 
          lunchEndHour != null && lunchEndMinute != null) {
        final currentTimeInMinutes = currentHour * 60 + currentMinute;
        final lunchStartInMinutes = lunchStartHour! * 60 + lunchStartMinute!;
        final lunchEndInMinutes = lunchEndHour! * 60 + lunchEndMinute!;
        
        if (currentTimeInMinutes >= lunchStartInMinutes && currentTimeInMinutes < lunchEndInMinutes) {
          isLunchTime = true;
        }
      }
      
      // 최소 시간 체크 (오늘 날짜인 경우)
      bool isBeforeMinimum = false;
      if (isToday && minimumTime != null) {
        final currentTimeInMinutes = currentHour * 60 + currentMinute;
        final minimumTimeInMinutes = minimumTime.hour * 60 + minimumTime.minute;
        if (currentTimeInMinutes < minimumTimeInMinutes) {
          isBeforeMinimum = true;
        }
      }
      
      // 점심시간이 아니고 최소 시간 이후인 경우만 추가
      if (!isLunchTime && !isBeforeMinimum) {
        slots.add(timeStr);
      }
      
      // 다음 시간으로 이동
      currentMinute += relayTime;
      if (currentMinute >= 60) {
        currentMinute -= 60;
        currentHour++;
      }
    }
    
    return slots;
  }

  /// 예약 시간 변경 제출
  Future<void> _submitChange() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('날짜와 시간을 선택해주세요')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = await AuthService.getUser();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다')),
          );
        }
        return;
      }

      // 예약 시간 변경 API 호출 (날짜는 yyyy-MM-dd 형식으로 전송)
      final dateString = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
      
      final result = await OrderService.OrderService.changeReservationTime(
        odId: widget.orderId,
        mbId: user.id,
        reservationDate: dateString,
        reservationTime: _selectedTime!,
      );

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '예약 시간이 변경되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // 변경 완료 플래그 반환
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '예약 시간 변경에 실패했습니다'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ 예약 시간 변경 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('예약 시간 변경 중 오류가 발생했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
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
          '예약 시간 변경',
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 현재 예약 정보 표시
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '현재 예약: ${_formatDate(widget.currentDate)} ${widget.currentTime}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 1. 가능한 날짜를 선택해주세요
                  const Text(
                    '1. 변경할 날짜를 선택해주세요',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  /* 0211 추가 */
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
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
                                fontSize: 12,
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
                    '2. 변경할 시간을 선택해주세요',
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
                      /* 0211 추가 */
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
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
                                  fontSize: 12,
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
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_selectedDate != null && _selectedTime != null && !_isSubmitting)
                      ? _submitChange
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3787),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '예약 시간 변경',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 날짜 포맷팅
  String _formatDate(String dateStr) {
    try {
      DateTime date;
      if (dateStr.contains('T')) {
        date = DateTime.parse(dateStr);
      } else if (dateStr.contains('-')) {
        date = DateTime.parse(dateStr);
      } else {
        return dateStr;
      }
      
      return '${date.year}년 ${date.month}월 ${date.day}일';
    } catch (e) {
      return dateStr;
    }
  }
}

