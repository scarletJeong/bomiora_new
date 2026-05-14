import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/login_required_dialog.dart';
import '../../health_common/health_responsive_scale.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../health_common/widgets/health_delete_popup.dart';
import '../../health_common/widgets/health_date_selector.dart';
import '../../../../data/models/health/weight/weight_record_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/repositories/health/weight/weight_repository.dart';
import '../../../../core/utils/image_picker_utils.dart';

class WeightInputScreen extends StatefulWidget {
  final WeightRecord? record; // null이면 새 기록, 있으면 수정
  final Map<String, String?>? initialImages; // 초기 이미지 경로
  /// 목록·대시보드에서 보고 있던 날짜(새 기록일 때 기본 측정일시에 반영)
  final DateTime? recordContextDate;

  const WeightInputScreen({
    super.key,
    this.record,
    this.initialImages,
    this.recordContextDate,
  });

  @override
  State<WeightInputScreen> createState() => _WeightInputScreenState();
}

class _WeightInputScreenState extends State<WeightInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDateTime = DateTime.now();
  double? _calculatedBMI;
  bool _isSaving = false;

  // 이미지 관련
  String? _frontImagePath;
  String? _sideImagePath;

  @override
  void initState() {
    super.initState();

    if (widget.record != null) {
      // 수정 모드
      _weightController.text = widget.record!.weight.toString();
      _heightController.text = widget.record!.height?.toString() ?? '';
      _notesController.text = widget.record!.notes ?? '';
      _selectedDateTime = widget.record!.measuredAt;
      _calculatedBMI = widget.record!.bmi;
      _frontImagePath = widget.record!.frontImagePath;
      _sideImagePath = widget.record!.sideImagePath;
    } else {
      // 새 기록 모드: 최신 기록에서 키 가져오기
      _loadLatestHeight();

      if (widget.recordContextDate != null) {
        _selectedDateTime =
            healthDefaultNewRecordDateTime(widget.recordContextDate!);
      }

      // 초기 이미지 설정
      if (widget.initialImages != null) {
        _frontImagePath = widget.initialImages!['front'];
        _sideImagePath = widget.initialImages!['side'];
      }
    }

    // 체중/키 변경 시 BMI 자동 계산
    _weightController.addListener(_updateBMI);
    _heightController.addListener(_updateBMI);
  }

  // 최신 기록에서 키 불러오기
  Future<void> _loadLatestHeight() async {
    try {
      final user = await AuthService.getUser();
      if (user == null) return;

      final latestRecord =
          await WeightRepository.getLatestWeightRecord(user.id);

      if (latestRecord != null && latestRecord.height != null) {
        setState(() {
          _heightController.text = latestRecord.height!.toStringAsFixed(0);
        });
      }
    } catch (e) {
      print('최신 키 정보 로드 오류: $e');
      // 에러가 나도 계속 진행 (키는 선택 사항)
    }
  }

  void _updateBMI() {
    final weight = double.tryParse(_weightController.text);
    final height = double.tryParse(_heightController.text);

    setState(() {
      _calculatedBMI = WeightRecord.calculateBMI(weight ?? 0, height);
    });
  }

  Future<void> _selectDateThenTime() async {
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

  Future<void> _selectTimeOnly() async {
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

      final weight = double.parse(_weightController.text);
      final height = _heightController.text.isNotEmpty
          ? double.parse(_heightController.text)
          : null;
      final bmi = WeightRecord.calculateBMI(weight, height);

      final record = WeightRecord(
        id: widget.record?.id,
        mbId: user.id,
        measuredAt: _selectedDateTime,
        weight: weight,
        height: height,
        bmi: bmi,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        frontImagePath: _frontImagePath,
        sideImagePath: _sideImagePath,
      );

      // API 호출
      bool success;
      if (widget.record == null) {
        // 새 기록 추가
        success = await WeightRepository.addWeightRecord(record);
        print('새 기록 추가 결과: $success');
      } else {
        // 기록 수정
        success = await WeightRepository.updateWeightRecord(record);
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

  // 삭제 확인 팝업 (공통 위젯)
  Future<void> _showDeleteConfirmDialog() async {
    final shouldDelete = await showHealthDeletePopup(
      context: context,
      title: '체중 기록 삭제',
      message: '헤딩 기록을\n삭제하시겠습니까?\n삭제된 데이터는 복구할 수\n없습니다.',
      cancelText: '취소',
      deleteText: '삭제',
    );

    if (shouldDelete == true) {
      _deleteRecord();
    }
  }

  // 체중 기록 삭제
  Future<void> _deleteRecord() async {
    if (widget.record?.id == null) return;

    setState(() => _isSaving = true);

    try {
      final success =
          await WeightRepository.deleteWeightRecord(widget.record!.id!);

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
    _weightController.dispose();
    _heightController.dispose();
    _notesController.dispose();
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
          title: '체중',
          titleFontSize: healthSp(context, 18),
          leadingIconSize: healthDp(context, 24),
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: healthDp(context, 25)),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '당신의 현재 체중을 입력해주세요.',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: const Color(0xFF1A1A1A),
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 20)),
                  _buildDateTimeCard(),
                  SizedBox(height: healthDp(context, 20)),

                  // 키 입력
                  _buildHeightInput(),
                  SizedBox(height: healthDp(context, 20)),

                  // 체중 입력
                  _buildWeightInput(),
                  SizedBox(height: healthDp(context, 20)),

                  // 눈바디 이미지
                  _buildBodyImagesSection(),
                  SizedBox(height: healthDp(context, 20)),

                  _buildActionButtons(),
                  SizedBox(height: healthDp(context, 20)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeCard() {
    final dateStr = DateFormat('yyyy.MM.dd').format(_selectedDateTime);
    final timeStr = DateFormat('HH:mm').format(_selectedDateTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('측정일시'),
        SizedBox(height: healthDp(context, 5)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InkWell(
                onTap: _selectDateThenTime,
                borderRadius: BorderRadius.circular(healthDp(context, 7)),
                child: Container(
                  height: healthDp(context, 40),
                  padding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  decoration: ShapeDecoration(
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: healthDp(context, 1),
                        color: const Color(0x7FD2D2D2),
                      ),
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 7)),
                    ),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    dateStr,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 16,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: healthDp(context, 10)),
            Expanded(
              child: InkWell(
                onTap: _selectTimeOnly,
                borderRadius: BorderRadius.circular(healthDp(context, 7)),
                child: Container(
                  height: healthDp(context, 40),
                  padding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  decoration: ShapeDecoration(
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: healthDp(context, 1),
                        color: const Color(0x7FD2D2D2),
                      ),
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 7)),
                    ),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    timeStr,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 16,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeightInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('키(cm)'),
        SizedBox(height: healthDp(context, 5)),
        _buildNumberInput(
          controller: _heightController,
          hintText: '예: 170',
          suffixText: 'cm',
          inputHeight: healthDp(context, 30),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              final height = double.tryParse(value);
              if (height == null || height <= 0 || height > 250) {
                return '올바른 키를 입력해주세요 (0~250cm)';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildWeightInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('몸무게(kg)'),
        SizedBox(height: healthDp(context, 5)),
        _buildNumberInput(
          controller: _weightController,
          hintText: '예: 65.5',
          suffixText: 'kg',
          inputHeight: healthDp(context, 30),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '체중을 입력해주세요';
            }
            final weight = double.tryParse(value);
            if (weight == null || weight <= 0 || weight > 300) {
              return '올바른 체중을 입력해주세요 (0~300kg)';
            }
            return null;
          },
        ),
      ],
    );
  }

  // 눈바디 이미지 섹션
  Widget _buildBodyImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('눈바디'),
        SizedBox(height: healthDp(context, 5)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: healthDp(context, 158),
              height: healthDp(context, 158),
              child: _buildImageContainer(
                '정면',
                _frontImagePath,
                () => _selectImage('front'),
              ),
            ),
            SizedBox(
              width: healthDp(context, 158),
              height: healthDp(context, 158),
              child: _buildImageContainer(
                '측면',
                _sideImagePath,
                () => _selectImage('side'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String title, [IconData? icon]) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: healthDp(context, 5)),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            SizedBox(
              width: healthDp(context, 16),
              height: healthDp(context, 16),
              child: Icon(
                icon,
                size: healthDp(context, 16),
                color: const Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(width: healthDp(context, 4)),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 16,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberInput({
    required TextEditingController controller,
    required String hintText,
    required String? Function(String?) validator,
    String? suffixText,
    double inputHeight = 40,
  }) {
    final verticalPadding =
        ((inputHeight - healthDp(context, 20)) / 2).clamp(8.0, 28.0);
    final padTop = (verticalPadding - 2).clamp(4.0, 28.0);
    final padBottom = (verticalPadding + 2).clamp(4.0, 28.0);
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
      ],
      validator: validator,
      textAlignVertical: TextAlignVertical.center,
      style: const TextStyle(
        color: Color(0xFF1A1A1A),
        fontSize: 18,
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w300,
      ),
      decoration: InputDecoration(
        constraints: BoxConstraints(minHeight: inputHeight),
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 16,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
        suffixText: suffixText,
        suffixStyle: const TextStyle(
          color: Color(0xFF7C7C7C),
          fontSize: 14,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w400,
        ),
        isDense: false,
        contentPadding: EdgeInsets.only(
          left: healthDp(context, 10),
          right: healthDp(context, 10),
          top: padTop,
          bottom: padBottom,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 7)),
          borderSide: BorderSide(
            width: healthDp(context, 1),
            color: const Color(0x7FD2D2D2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 7)),
          borderSide: BorderSide(
            width: healthDp(context, 1),
            color: const Color(0x7FD2D2D2),
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 7)),
          borderSide: BorderSide(
            width: healthDp(context, 1),
            color: const Color(0xFFFF8DA1),
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 7)),
          borderSide: BorderSide(
            width: healthDp(context, 1),
            color: const Color(0xFFFF8DA1),
          ),
        ),
      ),
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

  // 이미지 컨테이너 위젯
  Widget _buildImageContainer(
      String label, String? imagePath, VoidCallback onTap) {
    final hasImage = imagePath != null &&
        imagePath.isNotEmpty &&
        ImagePickerUtils.isImageFileExists(imagePath);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: hasImage ? Colors.grey[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(healthDp(context, 12)),
          border: Border.all(
            color: hasImage ? Colors.grey[300]! : Colors.grey[200]!,
            width: healthDp(context, 1),
          ),
        ),
        child: hasImage
            ? Stack(
                children: [
                  // 이미지 표시
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(healthDp(context, 12)),
                    child: kIsWeb
                        ? Image.network(
                            imagePath,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildImagePlaceholder(label);
                            },
                          )
                        : Image.file(
                            File(imagePath),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildImagePlaceholder(label);
                            },
                          ),
                  ),
                  // 삭제 버튼
                  Positioned(
                    top: healthDp(context, 4),
                    right: healthDp(context, 4),
                    child: GestureDetector(
                      onTap: () => _deleteImage(imagePath),
                      child: Container(
                        padding: EdgeInsets.all(healthDp(context, 4)),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: healthDp(context, 16),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : _buildImagePlaceholder(label),
      ),
    );
  }

  // 이미지 플레이스홀더
  Widget _buildImagePlaceholder(String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: healthDp(context, 40),
          color: Colors.grey[400],
        ),
        SizedBox(height: healthDp(context, 8)),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Gmarket Sans TTF',
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 이미지 선택
  Future<void> _selectImage(String type) async {
    try {
      await ImagePickerUtils.showImageSourceDialog(context,
          (XFile? image) async {
        if (image != null) {
          String? imagePath;

          if (kIsWeb) {
            // 웹에서는 XFile을 직접 전달
            try {
              imagePath = await WeightRepository.uploadImage(image);
            } catch (e) {
              print('웹 이미지 업로드 실패: $e');
              // 업로드 실패 시 blob URL 사용 (임시)
              imagePath = image.path;
            }
          } else {
            // 모바일에서는 실제 서버 업로드
            final File imageFile = File(image.path);
            imagePath = await WeightRepository.uploadImage(imageFile);
          }

          if (imagePath != null) {
            // 기존 이미지가 있으면 삭제
            if (type == 'front' && _frontImagePath != null) {
              await ImagePickerUtils.deleteImageFile(_frontImagePath);
            } else if (type == 'side' && _sideImagePath != null) {
              await ImagePickerUtils.deleteImageFile(_sideImagePath);
            }

            setState(() {
              if (type == 'front') {
                _frontImagePath = imagePath;
              } else {
                _sideImagePath = imagePath;
              }
            });
          }
        }
      });
    } catch (e) {
      print('이미지 선택 오류: $e');
    }
  }

  // 이미지 삭제
  Future<void> _deleteImage(String imagePath) async {
    try {
      // 확인 다이얼로그
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('이미지 삭제'),
          content: const Text('이미지를 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('삭제'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // 파일 시스템에서 이미지 삭제
        await ImagePickerUtils.deleteImageFile(imagePath);

        setState(() {
          if (imagePath == _frontImagePath) {
            _frontImagePath = null;
          } else if (imagePath == _sideImagePath) {
            _sideImagePath = null;
          }
        });

      }
    } catch (e) {
      print('이미지 삭제 오류: $e');
    }
  }

  Color _getBmiColor(double? bmi) {
    if (bmi == null) return Colors.grey;
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 23) return Colors.green;
    if (bmi < 25) return Colors.orange;
    return Colors.red;
  }
}
