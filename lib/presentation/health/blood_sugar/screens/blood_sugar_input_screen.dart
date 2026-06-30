import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../health_common/health_responsive_scale.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../health_common/widgets/health_delete_popup.dart';
import '../../health_common/widgets/health_date_selector.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/login_required_dialog.dart';
import '../../../../data/models/health/blood_sugar/blood_sugar_record_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/repositories/health/blood_sugar/blood_sugar_repository.dart';

class BloodSugarInputScreen extends StatefulWidget {
  final BloodSugarRecord? record; // null이면 새 기록, 있으면 수정
  final DateTime? recordContextDate;

  const BloodSugarInputScreen({super.key, this.record, this.recordContextDate});

  @override
  State<BloodSugarInputScreen> createState() => _BloodSugarInputScreenState();
}

class _BloodSugarInputScreenState extends State<BloodSugarInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bloodSugarController = TextEditingController();

  DateTime _selectedDateTime = DateTime.now();
  String _selectedMeasurementType = '공복';
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
      } else {
        // 기록 수정
        success = await BloodSugarRepository.updateBloodSugarRecord(record);
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

  void _onDeletePressed() {
    if (_isSaving) return;
    if (widget.record == null) {
      Navigator.pop(context);
      return;
    }
    _showDeleteConfirmDialog();
  }

  // 삭제 확인 다이얼로그
  Future<void> _showDeleteConfirmDialog() async {
    final shouldDelete = await showHealthDeletePopup(
      context: context,
      title: '혈당 기록 삭제',
      message: '해당 기록을\n삭제하시겠습니까?\n삭제된 데이터는 복구할 수\n없습니다.',
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
    final textScale =
        healthTextScaleByWidth(MediaQuery.of(context).size.width);

    return Theme(
      data: gmarketTheme,
      child: MobileAppLayoutWrapper(
        appBar: HealthAppBar(
          title: '혈당',
          leadingIconSize: healthDp(context, 24),
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 27),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: healthDp(context, 5)),
                        Text(
                          '오늘의 혈당을 등록해주세요.',
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
                        _buildMeasurementTypeCard(),
                        SizedBox(height: healthDp(context, 20)),
                        _buildBloodSugarInput(),
                        SizedBox(height: healthDp(context, 20)),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    healthDp(context, 27),
                    healthDp(context, 8),
                    healthDp(context, 27),
                    healthDp(context, 16),
                  ),
                  child: _buildActionButtons(),
                ),
              ),
            ],
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
            },
            child: Container(
              height: healthDp(context, 35),
              margin: EdgeInsets.only(right: healthDp(context, 8)),
              decoration: ShapeDecoration(
                color: isSelected ? const Color(0xFFFF5A8D) : Colors.white,
                shape: RoundedRectangleBorder(
                  side: isSelected
                      ? BorderSide.none
                      : BorderSide(
                          width: healthDp(context, 1),
                          color: const Color(0xFFD2D2D2),
                        ),
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                ),
              ),
              child: Center(
                child: Text(
                  type,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF898383),
                    fontSize: 16,
                    fontFamily: 'Gmarket Sans TTF',
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
        Text(
          '혈당(mg/dL)',
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
            style: TextStyle(
              color: const Color(0xFF1A1A1A),
              fontSize: 16,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
            decoration: InputDecoration(
              hintText: '수치를 입력하세요',
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

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: healthDp(context, 38),
            child: OutlinedButton(
              onPressed: _isSaving ? null : _onDeletePressed,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: const Color(0xFF898383),
                disabledBackgroundColor: Colors.transparent,
                disabledForegroundColor: const Color(0xFF898383),
                splashFactory: NoSplash.splashFactory,
                overlayColor: Colors.transparent,
                side: BorderSide(
                  width: healthDp(context, 0.5),
                  color: const Color(0xFF898383),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                ),
              ),
              child: Text(
                widget.record == null ? '취소' : '삭제',
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
