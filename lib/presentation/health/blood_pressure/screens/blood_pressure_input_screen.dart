import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../health_common/health_responsive_scale.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../health_common/widgets/health_delete_popup.dart';
import '../../health_common/widgets/health_date_selector.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/login_required_dialog.dart';
import '../../../../data/models/health/blood_pressure/blood_pressure_record_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/repositories/health/blood_pressure/blood_pressure_repository.dart';

class BloodPressureInputScreen extends StatefulWidget {
  final BloodPressureRecord? record; // null이면 새 기록, 있으면 수정
  final DateTime? recordContextDate;

  const BloodPressureInputScreen({super.key, this.record, this.recordContextDate});

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
    } else if (widget.recordContextDate != null) {
      _selectedDateTime =
          healthDefaultNewRecordDateTime(widget.recordContextDate!);
    }
  }

  Future<void> _selectDate() async {
    final latest = DateTime.now();
    final picked = await showHealthDateThenTimePickers(
      context,
      initialDateTime: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: latest,
      latestAllowed: latest,
    );
    if (picked != null) {
      setState(() => _selectedDateTime = picked);
    }
  }

  Future<void> _selectTime() async {
    final now = DateTime.now();
    TimeOfDay? maxTime;
    if (_selectedDateTime.year == now.year &&
        _selectedDateTime.month == now.month &&
        _selectedDateTime.day == now.day) {
      maxTime = TimeOfDay(hour: now.hour, minute: now.minute);
    }
    final time = await showHealthTimePickerDialog(
      context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      maxTime: maxTime,
    );

    if (time != null) {
      setState(() {
        var next = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          time.hour,
          time.minute,
        );
        if (next.isAfter(now)) next = now;
        _selectedDateTime = next;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    if (_selectedDateTime.isAfter(now)) {
      return;
    }

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
          Navigator.pop(context, true); // 성공
        }
      }
    } catch (e) {
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
          Navigator.pop(context, true); // 성공
        }
      }
    } catch (e) {
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
    final textScale =
        healthTextScaleByWidth(MediaQuery.of(context).size.width);

    return Theme(
      data: gmarketTheme,
      child: MobileAppLayoutWrapper(
        appBar: HealthAppBar(
          title: '혈압',
          leadingIconSize: healthDp(context, 24),
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 27),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: healthDp(context, 0)),
                  Text(
                    '오늘의 혈압을 등록해주세요',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: const Color(0xFF1A1A1A),
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 20)),
                  _buildDateTimeCard(),
                  SizedBox(height: healthDp(context, 20)),
                  _buildSystolicInput(),
                  SizedBox(height: healthDp(context, 20)),
                  _buildDiastolicInput(),
                  SizedBox(height: healthDp(context, 20)),
                  _buildPulseInput(),
                  SizedBox(height: healthDp(context, 20)),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeCard() {
    final dateText = DateFormat('yyyy.MM.dd').format(_selectedDateTime);
    final timeText = DateFormat('HH:mm').format(_selectedDateTime);
    final isEditMode = widget.record != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '측정 일시',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: healthDp(context, 5)),
        Row(
          children: [
            Expanded(
              child: _buildDateTimeBox(
                text: dateText,
                onTap: isEditMode ? null : _selectDate,
                isDisabled: isEditMode,
              ),
            ),
            SizedBox(width: healthDp(context, 10)),
            Expanded(
              child: _buildDateTimeBox(
                text: timeText,
                onTap: isEditMode ? null : _selectTime,
                isDisabled: isEditMode,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateTimeBox({
    required String text,
    required VoidCallback? onTap,
    required bool isDisabled,
  }) {
    final fieldFill =
        isDisabled ? const Color(0xFFF2F2F2) : Colors.transparent;
    final fieldBorder =
        isDisabled ? const Color(0xFFDADADA) : const Color(0x7FD2D2D2);
    final fieldText =
        isDisabled ? const Color(0xFF9E9E9E) : const Color(0xFF1A1A1A);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(healthDp(context, 7)),
      child: Container(
        height: healthDp(context, 40),
        padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: fieldFill,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: healthDp(context, 1),
              color: fieldBorder,
            ),
            borderRadius: BorderRadius.circular(healthDp(context, 7)),
          ),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            color: fieldText,
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
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
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: healthDp(context, 10)),
        Container(
          height: healthDp(context, 40),
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: healthDp(context, 1),
                color: const Color(0x7FD2D2D2),
              ),
              borderRadius: BorderRadius.circular(healthDp(context, 7)),
            ),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: validator,
            textAlignVertical: const TextAlignVertical(y: 0.45),
            style: TextStyle(
              color: const Color(0xFF1A1A1A),
              fontSize: 16,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: const Color(0xFF1A1A1A),
                fontSize: 16,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.only(
                top: healthDp(context, 8),
                bottom: healthDp(context, 1),
              ),
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
            height: healthDp(context, 38),
            child: OutlinedButton(
              onPressed: (widget.record != null && !_isSaving)
                  ? _showDeleteConfirmDialog
                  : null,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  width: healthDp(context, 0.5),
                  color: const Color(0xFF898383),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                ),
              ),
              child: Text(
                '삭제',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: 'Gmarket Sans TTF',
                  color: const Color(0xFF898383),
                  fontSize: healthSp(context, 16),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: healthDp(context, 10)),
        Expanded(
          child: SizedBox(
            height: healthDp(context, 38),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5A8D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? SizedBox(
                      width: healthDp(context, 18),
                      height: healthDp(context, 18),
                      child: CircularProgressIndicator(
                        strokeWidth: healthDp(context, 2),
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.record == null ? '등록' : '수정',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontFamily: 'Gmarket Sans TTF',
                        color: Colors.white,
                        fontSize: healthSp(context, 16),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
