import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../../data/models/health/blood_pressure/blood_pressure_record_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/repositories/health/blood_pressure/blood_pressure_repository.dart';

class BloodPressureInputScreen extends StatefulWidget {
  final BloodPressureRecord? record; // null이면 새 기록, 있으면 수정

  const BloodPressureInputScreen({super.key, this.record});

  @override
  State<BloodPressureInputScreen> createState() => _BloodPressureInputScreenState();
}

class _BloodPressureInputScreenState extends State<BloodPressureInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _pulseController = TextEditingController();

  DateTime _selectedDateTime = DateTime.now();
  String? _calculatedStatus;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.record != null) {
      // 수정 모드
      _systolicController.text = widget.record!.systolic.toString();
      _diastolicController.text = widget.record!.diastolic.toString();
      _pulseController.text = widget.record!.pulse.toString();
      _selectedDateTime = widget.record!.measuredAt;
      _calculatedStatus = widget.record!.status;
    }

    // 혈압 변경 시 상태 자동 계산
    _systolicController.addListener(_updateStatus);
    _diastolicController.addListener(_updateStatus);
  }

  void _updateStatus() {
    final systolic = int.tryParse(_systolicController.text);
    final diastolic = int.tryParse(_diastolicController.text);

    if (systolic != null && diastolic != null) {
      setState(() {
        _calculatedStatus = BloodPressureRecord.calculateStatus(systolic, diastolic);
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

      final systolic = int.parse(_systolicController.text);
      final diastolic = int.parse(_diastolicController.text);
      final pulse = int.parse(_pulseController.text);

      final record = BloodPressureRecord(
        id: widget.record?.id,
        mbId: user.id,
        measuredAt: _selectedDateTime,
        systolic: systolic,
        diastolic: diastolic,
        pulse: pulse,
      );

      // API 호출
      bool success;
      if (widget.record == null) {
        // 새 기록 추가
        success = await BloodPressureRepository.addBloodPressureRecord(record);
        print('새 기록 추가 결과: $success');
      } else {
        // 기록 수정
        success = await BloodPressureRepository.updateBloodPressureRecord(record);
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
        title: const Text('혈압 기록 삭제'),
        content: const Text('이 혈압 기록을 삭제하시겠습니까?\n삭제된 데이터는 복구할 수 없습니다.'),
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

  // 혈압 기록 삭제
  Future<void> _deleteRecord() async {
    if (widget.record?.id == null) return;

    setState(() => _isSaving = true);

    try {
      final success = await BloodPressureRepository.deleteBloodPressureRecord(widget.record!.id!);

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
    _systolicController.dispose();
    _diastolicController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: Text(widget.record == null ? '혈압 기록하기' : '혈압 수정하기'),
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
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 측정 일시
              _buildDateTimeCard(),
              const SizedBox(height: 16),

              // 수축기 혈압 입력
              _buildSystolicInput(),
              const SizedBox(height: 16),

              // 이완기 혈압 입력
              _buildDiastolicInput(),
              const SizedBox(height: 16),

              // 심박수 
              _buildPulseInput(),
              const SizedBox(height: 16),

              // 혈압 상태 표시
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

  Widget _buildSystolicInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '수축기 혈압 (mmHg)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _systolicController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            hintText: '예: 120',
            suffixText: 'mmHg',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.favorite, color: Colors.red),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '수축기 혈압을 입력해주세요';
            }
            final systolic = int.tryParse(value);
            if (systolic == null || systolic < 50 || systolic > 250) {
              return '올바른 수축기 혈압을 입력해주세요 (50~250mmHg)';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDiastolicInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '이완기 혈압 (mmHg)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _diastolicController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            hintText: '예: 80',
            suffixText: 'mmHg',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.favorite, color: Colors.blue),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '이완기 혈압을 입력해주세요';
            }
            final diastolic = int.tryParse(value);
            if (diastolic == null || diastolic < 30 || diastolic > 150) {
              return '올바른 이완기 혈압을 입력해주세요 (30~150mmHg)';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPulseInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '심박수 (bpm)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _pulseController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            hintText: '예: 72',
            suffixText: 'bpm',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.monitor_heart),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '심박수를 입력해주세요';
            }
            final pulse = int.tryParse(value);
            if (pulse == null || pulse < 30 || pulse > 200) {
              return '올바른 심박수수을 입력해주세요 (30~200bpm)';
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
      case '주의':
        statusColor = Colors.yellow[700]!;
        break;
      case '고혈압 전단계':
        statusColor = Colors.orange;
        break;
      case '1단계 고혈압':
      case '2단계 고혈압':
        statusColor = Colors.red;
        break;
      case '고혈압 위기':
        statusColor = Colors.red[900]!;
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
                  '혈압 상태: $_calculatedStatus',
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
        return '정상 혈압 범위입니다.';
      case '주의':
        return '약간 높은 편입니다. 생활습관 개선이 필요합니다.';
      case '고혈압 전단계':
        return '고혈압 전단계입니다. 관리가 필요합니다.';
      case '1단계 고혈압':
        return '1단계 고혈압입니다. 의사와 상담하세요.';
      case '2단계 고혈압':
        return '2단계 고혈압입니다. 즉시 의사와 상담하세요.';
      case '고혈압 위기':
        return '고혈압 위기! 응급 상황입니다. 즉시 병원에 가세요.';
      default:
        return '';
    }
  }
}

