import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateTopWidget extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateChanged;
  final Map<String, dynamic>? recordsMap; // 날짜별 데이터가 있는지 확인용
  final String? recordKey; // 데이터 확인용 키 (예: 'blood_pressure', 'weight' 등)
  final Color? primaryColor;
  final Color? secondaryColor;

  const DateTopWidget({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    this.recordsMap,
    this.recordKey,
    this.primaryColor,
    this.secondaryColor,
  });

  // 표시할 3개의 날짜
  List<DateTime> get displayDates {
    return [
      selectedDate.subtract(const Duration(days: 1)),
      selectedDate,
      selectedDate.add(const Duration(days: 1)),
    ];
  }

  // 오늘인지 확인
  bool _isToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return selectedDate.year == today.year && 
           selectedDate.month == today.month && 
           selectedDate.day == today.day;
  }

  // 특정 날짜에 데이터가 있는지 확인
  bool _hasRecord(DateTime date) {
    if (recordsMap == null) return false;
    
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    return recordsMap!.containsKey(dateKey);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = _isToday();

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildDateItem(displayDates[0], false),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDateItem(displayDates[1], true),
              if (isToday)
                Container(
                  margin: const EdgeInsets.only(left: 0),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: primaryColor ?? Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '오늘',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          _buildDateItem(displayDates[2], false),
        ],
      ),
    );
  }

  // 날짜 아이템 위젯
  Widget _buildDateItem(DateTime date, bool isCenter) {
    final hasRecord = _hasRecord(date);
    final dateStr = DateFormat('M.d').format(date);
    
    return GestureDetector(
      onTap: () {
        onDateChanged(date);
      },
      child: Container(
        width: isCenter ? 80 : 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dateStr,
              style: TextStyle(
                fontSize: isCenter ? 18 : 14,
                fontWeight: isCenter ? FontWeight.bold : FontWeight.normal,
                color: isCenter 
                    ? (primaryColor ?? Colors.black)
                    : (secondaryColor ?? Colors.grey[400]),
              ),
            ),
            if (hasRecord)
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isCenter 
                      ? (primaryColor ?? Colors.black)
                      : (secondaryColor ?? Colors.grey[400]),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
