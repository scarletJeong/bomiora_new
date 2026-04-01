import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../health_common/widgets/health_delete_popup.dart';
import '../../health_common/widgets/health_measurement_datetime_dialogs.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/login_required_dialog.dart';
import '../../../../data/models/health/blood_pressure/blood_pressure_record_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/repositories/health/blood_pressure/blood_pressure_repository.dart';

class BloodPressureInputScreen extends StatefulWidget {
  final BloodPressureRecord? record; // null이면 새 기록, 있으면 수정

  const BloodPressureInputScreen({super.key, this.record});

  @override
  State<BloodPressureInputScreen> createState() =>
      _BloodPressureInputScreenState();
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
        _calculatedStatus =
            BloodPressureRecord.calculateStatus(systolic, diastolic);
      });
    } else {
      setState(() {
        _calculatedStatus = null;
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showHealthDateThenTimePickers(
      context,
      initialDateTime: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDateTime = picked);
    }
  }

  Future<void> _selectTime() async {
    final time = await showHealthTimePickerDialog(
      context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );

    if (time != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = await AuthService.getUser();

      if (user == null) {
        await showLoginRequiredDialog(
          context,
          message: '건강 기록 입력은 로그인 후 이용할 수 있습니다.',
        );
        return;
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
        success =
            await BloodPressureRepository.updateBloodPressureRecord(record);
        print('기록 수정 결과: $success');
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(widget.record == null ? '기록이 추가되었습니다' : '기록이 수정되었습니다'),
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
  Future<void> _showDeleteConfirmDialog() async {
    final shouldDelete = await showHealthDeletePopup(
      context: context,
      title: '혈압 기록 삭제',
      message: '이 혈압 기록을\n삭제하시겠습니까?\n삭제된 데이터는 복구할 수\n없습니다.',
      cancelText: '취소',
      deleteText: '삭제',
    );

    if (shouldDelete == true) {
      _deleteRecord();
    }
  }

  // 혈압 기록 삭제
  Future<void> _deleteRecord() async {
    if (widget.record?.id == null) return;

    setState(() => _isSaving = true);

    try {
      final success = await BloodPressureRepository.deleteBloodPressureRecord(
          widget.record!.id!);

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
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );

    return Theme(
      data: gmarketTheme,
      child: MobileAppLayoutWrapper(
        appBar: HealthAppBar(
          title: widget.record == null ? '혈압 기록하기' : '혈압 수정하기',
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateTimeCard(),
                const SizedBox(height: 20),
                _buildSystolicInput(),
                const SizedBox(height: 20),
                _buildDiastolicInput(),
                const SizedBox(height: 20),
                _buildPulseInput(),
                const SizedBox(height: 24),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeCard() {
    final dateText = DateFormat('yyyy.MM.dd').format(_selectedDateTime);
    final timeText = DateFormat('HH:mm').format(_selectedDateTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '측정 일시',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildDateTimeBox(text: dateText, onTap: _selectDate),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDateTimeBox(text: timeText, onTap: _selectTime),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateTimeBox({
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 1, color: Color(0x7FD2D2D2)),
            borderRadius: BorderRadius.circular(7),
          ),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 16,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSystolicInput() {
    return _buildLabeledInput(
      label: '수축기(mmHg)',
      controller: _systolicController,
      hintText: '수치를 입력하세요',
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
    );
  }

  Widget _buildLabeledInput({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: Color(0x7FD2D2D2)),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: validator,
            textAlignVertical: const TextAlignVertical(y: 0.45),
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 18,
              fontWeight: FontWeight.w300,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 16,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.only(top: 8, bottom: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiastolicInput() {
    return _buildLabeledInput(
      label: '이완기(mmHg)',
      controller: _diastolicController,
      hintText: '수치를 입력하세요',
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
    );
  }

  Widget _buildPulseInput() {
    return _buildLabeledInput(
      label: '심박수(bpm)',
      controller: _pulseController,
      hintText: '수치를 입력하세요',
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
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: (widget.record != null && !_isSaving)
                  ? _showDeleteConfirmDialog
                  : null,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                  width: 0.5,
                  color: Color(0xFF898383),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: Color(0xFF898383),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5A8D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.record == null ? '등록' : '수정',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
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
