import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../health_common/widgets/health_delete_popup.dart';
import '../../health_common/widgets/health_measurement_datetime_dialogs.dart';
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
        _calculatedStatus = BloodSugarRecord.calculateStatus(
            bloodSugar, _selectedMeasurementType);
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
      title: '혈당 기록 삭제',
      message: '이 혈당 기록을\n삭제하시겠습니까?\n삭제된 데이터는 복구할 수\n없습니다.',
      cancelText: '취소',
      deleteText: '삭제',
    );

    if (shouldDelete == true) {
      _deleteRecord();
    }
  }

  // 혈당 기록 삭제
  Future<void> _deleteRecord() async {
    if (widget.record?.id == null) return;

    setState(() => _isSaving = true);

    try {
      final success =
          await BloodSugarRepository.deleteBloodSugarRecord(widget.record!.id!);

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
          title: widget.record == null ? '혈당 기록하기' : '혈당 수정하기',
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
                _buildMeasurementTypeCard(),
                const SizedBox(height: 20),
                _buildBloodSugarInput(),
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

  Widget _buildMeasurementTypeCard() {
    return Row(
      children: _measurementTypes.map((type) {
        final isSelected = _selectedMeasurementType == type;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedMeasurementType = type;
              });
              _updateStatus();
            },
            child: Container(
              height: 35,
              margin: const EdgeInsets.only(right: 8),
              decoration: ShapeDecoration(
                color: isSelected ? const Color(0xFFFF5A8D) : Colors.white,
                shape: RoundedRectangleBorder(
                  side: isSelected
                      ? BorderSide.none
                      : const BorderSide(width: 1, color: Color(0xFFD2D2D2)),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Center(
                child: Text(
                  type,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF898383),
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBloodSugarInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '혈당(mg/dL)',
          style: TextStyle(
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
            controller: _bloodSugarController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
            textAlignVertical: const TextAlignVertical(y: 0.45),
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 16,
              fontWeight: FontWeight.w300,
            ),
            decoration: const InputDecoration(
              hintText: '수치를 입력하세요',
              hintStyle: TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 16,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.only(top: 8, bottom: 1),
            ),
          ),
        ),
      ],
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
                side: const BorderSide(width: 0.5, color: Color(0xFF898383)),
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
          Icon(Icons.chevron_left),
          //Icon(Icons.info_outline, color: statusColor),
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
