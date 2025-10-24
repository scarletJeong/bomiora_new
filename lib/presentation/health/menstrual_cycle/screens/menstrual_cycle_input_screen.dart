import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../../data/models/health/menstrual_cycle/menstrual_cycle_model.dart';
import '../../../../data/repositories/health/menstrual_cycle/menstrual_cycle_repository.dart';
import '../../../../data/services/auth_service.dart';

class MenstrualCycleInputScreen extends StatefulWidget {
  final MenstrualCycleRecord? existingRecord; // 편집할 기존 데이터
  
  const MenstrualCycleInputScreen({super.key, this.existingRecord});

  @override
  State<MenstrualCycleInputScreen> createState() => _MenstrualCycleInputScreenState();
}

class _MenstrualCycleInputScreenState extends State<MenstrualCycleInputScreen> {
  DateTime? _lastPeriodStart;
  DateTime? _lastPeriodEnd;
  int _cycleLength = 28;
  bool _isLoading = false;
  
  // 달력 관련
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // 선택 모드 (시작일 선택 중인지 종료일 선택 중인지)
  bool _isSelectingStart = true;
  int _clickCount = 0; // 클릭 횟수 추적

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    if (widget.existingRecord != null) {
      final record = widget.existingRecord!;
      setState(() {
        _lastPeriodStart = record.lastPeriodStart;
        _lastPeriodEnd = record.lastPeriodStart.add(Duration(days: record.periodLength - 1));
        _cycleLength = record.cycleLength;
        _focusedDay = record.lastPeriodStart;
        _selectedDay = record.lastPeriodStart;
        _clickCount = 2; // 기존 데이터가 있으면 이미 시작일과 종료일이 모두 선택된 상태
        _isSelectingStart = false; // 다음 클릭은 새로운 시작일 선택
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.existingRecord != null ? '생리주기 수정' : '생리주기 입력',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSelectionStatus(),
            const SizedBox(height: 20),
            _buildCalendar(),
            const SizedBox(height: 20),
            _buildQuestionCard(
              '생리주기는 몇 일인가요?',
              _buildCycleLengthSelector(),
            ),
            const SizedBox(height: 20),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '선택된 날짜',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isSelectingStart ? '달력에서 시작일을 선택하세요' : '달력에서 종료일을 선택하세요',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isSelectingStart ? Colors.pink[50] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isSelectingStart ? Colors.pink : Colors.grey[300]!,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '시작일',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isSelectingStart ? Colors.pink : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _lastPeriodStart != null 
                            ? DateFormat('M월 d일').format(_lastPeriodStart!)
                            : '선택하세요',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isSelectingStart ? Colors.pink : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: !_isSelectingStart ? Colors.pink[50] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: !_isSelectingStart ? Colors.pink : Colors.grey[300]!,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '종료일',
                        style: TextStyle(
                          fontSize: 12,
                          color: !_isSelectingStart ? Colors.pink : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _lastPeriodEnd != null 
                            ? DateFormat('M월 d일').format(_lastPeriodEnd!)
                            : '선택하세요',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: !_isSelectingStart ? Colors.pink : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_lastPeriodStart != null && _lastPeriodEnd != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Text(
                    '${_lastPeriodEnd!.difference(_lastPeriodStart!).inDays + 1}일간',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.pink[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TableCalendar<dynamic>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        onFormatChanged: (format) {
          if (_calendarFormat != format) {
            setState(() {
              _calendarFormat = format;
            });
          }
        },
        onDaySelected: (selectedDay, focusedDay) {
          if (!mounted) return;
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
            _clickCount++;
          });
          
          // 홀수 클릭: 시작일 선택
          if (_clickCount % 2 == 1) {
            // 기존 종료일이 있고, 새로 선택한 시작일이 종료일보다 늦으면 순서 바꾸기
            if (_lastPeriodEnd != null && selectedDay.isAfter(_lastPeriodEnd!)) {
              // 기존 종료일을 새로운 시작일로, 새로 선택한 날짜를 종료일로
              _lastPeriodStart = _lastPeriodEnd;
              _lastPeriodEnd = selectedDay;
              _isSelectingStart = false; // 다음은 종료일 선택
            } else {
              _lastPeriodStart = selectedDay;
              _lastPeriodEnd = null; // 시작일이 바뀌면 종료일 초기화
              _isSelectingStart = true;
            }
          } else {
            // 짝수 클릭: 종료일 선택
            if (_lastPeriodStart != null && selectedDay.isAfter(_lastPeriodStart!)) {
              _lastPeriodEnd = selectedDay;
              _isSelectingStart = false;
            } else if (_lastPeriodStart != null && selectedDay.isBefore(_lastPeriodStart!)) {
              // 종료일이 시작일보다 이전이면 순서 바꾸기
              _lastPeriodEnd = _lastPeriodStart;
              _lastPeriodStart = selectedDay;
              _isSelectingStart = false;
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('종료일은 시작일보다 늦어야 합니다')),
              );
              // 잘못된 선택이면 클릭 카운트 되돌리기
              _clickCount--;
            }
          }
        },
        selectedDayPredicate: (day) {
          if (_lastPeriodStart != null && _lastPeriodEnd != null) {
            return day.isAtSameMomentAs(_lastPeriodStart!) ||
                   day.isAtSameMomentAs(_lastPeriodEnd!) ||
                   (day.isAfter(_lastPeriodStart!) && day.isBefore(_lastPeriodEnd!));
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
          selectedDecoration: BoxDecoration(
            color: Colors.pink,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: Colors.pink[200],
            shape: BoxShape.circle,
          ),
          rangeHighlightColor: Colors.pink[100]!,
          withinRangeDecoration: BoxDecoration(
            color: Colors.pink[50],
            shape: BoxShape.circle,
          ),
          rangeStartDecoration: BoxDecoration(
            color: Colors.pink,
            shape: BoxShape.circle,
          ),
          rangeEndDecoration: BoxDecoration(
            color: Colors.pink,
            shape: BoxShape.circle,
          ),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
        ),
      ),
    );
  }

  Widget _buildQuestionCard(String question, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildCycleLengthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              if (_cycleLength > 21) _cycleLength--;
            });
          },
          icon: const Icon(Icons.remove_circle_outline),
          color: Colors.pink,
        ),
        Text(
          '$_cycleLength 일',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              if (_cycleLength < 35) _cycleLength++;
            });
          },
          icon: const Icon(Icons.add_circle_outline),
          color: Colors.pink,
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveMenstrualCycleRecord,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
            : Text(
                widget.existingRecord != null ? '수정하기' : '저장하기',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
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

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await AuthService.getUser();
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 생리 기간 길이 계산
      final periodLength = _lastPeriodEnd!.difference(_lastPeriodStart!).inDays + 1;

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
        success = await MenstrualCycleRepository.updateMenstrualCycleRecord(record);
      } else {
        // 새로 추가 모드: 추가
        success = await MenstrualCycleRepository.addMenstrualCycleRecord(record);
      }

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.existingRecord != null 
                ? '생리주기 정보가 수정되었습니다' 
                : '생리주기 정보가 저장되었습니다')),
          );
          Navigator.pop(context, true); // 성공 시 true 반환
        }
      } else {
        throw Exception(widget.existingRecord != null ? '수정에 실패했습니다' : '저장에 실패했습니다');
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