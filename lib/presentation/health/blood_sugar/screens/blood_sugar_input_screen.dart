import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../../data/models/health/blood_sugar/blood_sugar_record_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/repositories/health/blood_sugar/blood_sugar_repository.dart';

class BloodSugarInputScreen extends StatefulWidget {
  final BloodSugarRecord? record; // null이면 새 기록, 있으면 수정

  const BloodSugarInputScreen({super.key, this.record});

  @override
  State<BloodSugarInputScreen> createState() => _BloodSugarInputScreenState();
}

class _BloodSugarInputScreenState extends State<BloodSugarInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bloodSugarController = TextEditingController();

  DateTime _selectedDateTime = DateTime.now();
  String _selectedMeasurementType = '공복';
  String? _calculatedStatus;
  bool _isSaving = false;

  final List<String> _measurementTypes = ['공복', '식전', '식후', '취침전', '평상시'];

  @override
  void initState() {
    super.initState();
    
    if (widget.record != null) {
      // 수정 모드
      _bloodSugarController.text = widget.record!.bloodSugar.toString();
      _selectedDateTime = widget.record!.measuredAt;
      _selectedMeasurementType = widget.record!.measurementType;
      _calculatedStatus = widget.record!.status;
    }

    // 혈당 변경 시 상태 자동 계산
    _bloodSugarController.addListener(_updateStatus);
  }

  void _updateStatus() {
    final bloodSugar = int.tryParse(_bloodSugarController.text);

    if (bloodSugar != null) {
      setState(() {
        _calculatedStatus = BloodSugarRecord.calculateStatus(bloodSugar, _selectedMeasurementType);
      });
    } else {
      setState(() {
        _calculatedStatus = null;
      });
    }
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ko'),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );

      if (time != null) {
        setState(() {
          _selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = await AuthService.getUser();

      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }

      final bloodSugar = int.parse(_bloodSugarController.text);

      final record = BloodSugarRecord(
        id: widget.record?.id,
        mbId: user.id,
        measuredAt: _selectedDateTime,
        bloodSugar: bloodSugar,
        measurementType: _selectedMeasurementType,
      );

      // API 호출
      bool success;
      if (widget.record == null) {
        // 새 기록 추가
        success = await BloodSugarRepository.addBloodSugarRecord(record);
        print('새 기록 추가 결과: $success');
      } else {
        // 기록 수정
        success = await BloodSugarRepository.updateBloodSugarRecord(record);
        print('기록 수정 결과: $success');
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.record == null ? '기록이 추가되었습니다' : '기록이 수정되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // 성공
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('저장에 실패했습니다. 다시 시도해주세요.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('혈당 기록 삭제'),
        content: const Text('이 혈당 기록을 삭제하시겠습니까?\n삭제된 데이터는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 다이얼로그 닫기
              _deleteRecord(); // 삭제 실행
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  // 혈당 기록 삭제
  Future<void> _deleteRecord() async {
    if (widget.record?.id == null) return;

    setState(() => _isSaving = true);

    try {
      final success = await BloodSugarRepository.deleteBloodSugarRecord(widget.record!.id!);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('기록이 삭제되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // 성공
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('삭제에 실패했습니다. 다시 시도해주세요.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _bloodSugarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: Text(widget.record == null ? '혈당 기록하기' : '혈당 수정하기'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: widget.record != null
            ? [
                // 수정 모드일 때만 삭제 버튼 표시
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _showDeleteConfirmDialog,
                  tooltip: '삭제',
                ),
              ]
            : null,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 측정 일시
              _buildDateTimeCard(),
              const SizedBox(height: 16),

              // 측정 유형 선택
              _buildMeasurementTypeCard(),
              const SizedBox(height: 16),

              // 혈당 수치 입력
              _buildBloodSugarInput(),
              const SizedBox(height: 16),

              // 혈당 상태 표시
              if (_calculatedStatus != null)
                _buildStatusCard(),
              
              const SizedBox(height: 24),

              // 저장 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('저장', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeCard() {
    final dateFormat = DateFormat('yyyy년 M월 d일 (E) HH:mm', 'ko');

    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today),
        title: const Text('측정 일시'),
        subtitle: Text(dateFormat.format(_selectedDateTime)),
        trailing: const Icon(Icons.chevron_right),
        onTap: _selectDateTime,
      ),
    );
  }

  Widget _buildMeasurementTypeCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '측정 유형',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: _measurementTypes.map((type) {
                    final isSelected = _selectedMeasurementType == type;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedMeasurementType = type;
                          });
                          _updateStatus(); // 상태 재계산
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.orange : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? Colors.orange : Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                BloodSugarRecord.getMeasurementTypeIcon(type),
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                BloodSugarRecord.getMeasurementTypeKorean(type),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBloodSugarInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '혈당 (mg/dL)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _bloodSugarController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            hintText: '수치를 입력하세요',
            suffixText: 'mg/dL',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.monitor_heart, color: Colors.red),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '혈당 수치를 입력해주세요';
            }
            final bloodSugar = int.tryParse(value);
            if (bloodSugar == null || bloodSugar < 20 || bloodSugar > 600) {
              return '올바른 혈당 수치를 입력해주세요 (20~600mg/dL)';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    switch (_calculatedStatus) {
      case '정상':
        statusColor = Colors.green;
        break;
      case '당뇨 전단계':
        statusColor = Colors.orange;
        break;
      case '당뇨':
        statusColor = Colors.red;
        break;
      case '저혈당':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '혈당 상태: $_calculatedStatus',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getStatusDescription(_calculatedStatus!),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case '정상':
        return '정상 혈당 범위입니다.';
      case '당뇨 전단계':
        return '당뇨 전단계입니다. 생활습관 개선이 필요합니다.';
      case '당뇨':
        return '당뇨 범위입니다. 의사와 상담하세요.';
      case '저혈당':
        return '저혈당입니다. 즉시 당분을 섭취하세요.';
      default:
        return '';
    }
  }
}
