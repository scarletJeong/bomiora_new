import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../../data/models/health/weight/weight_record_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/repositories/health/weight/weight_repository.dart';
import '../../../../core/utils/image_picker_utils.dart';

class WeightInputScreen extends StatefulWidget {
  final WeightRecord? record; // null이면 새 기록, 있으면 수정
  final Map<String, String?>? initialImages; // 초기 이미지 경로

  const WeightInputScreen({super.key, this.record, this.initialImages});

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

      final latestRecord = await WeightRepository.getLatestWeightRecord(user.id);
      
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
        title: const Text('체중 기록 삭제'),
        content: const Text('이 체중 기록을 삭제하시겠습니까?\n삭제된 데이터는 복구할 수 없습니다.'),
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

  // 체중 기록 삭제
  Future<void> _deleteRecord() async {
    if (widget.record?.id == null) return;

    setState(() => _isSaving = true);

    try {
      final success = await WeightRepository.deleteWeightRecord(widget.record!.id!);

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
    _weightController.dispose();
    _heightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: Text(widget.record == null ? '체중 기록하기' : '체중 수정하기'),
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

              // 키 입력
              _buildHeightInput(),
              const SizedBox(height: 24),

              // 체중 입력
              _buildWeightInput(),
              const SizedBox(height: 24),

              // 눈바디 이미지
              _buildBodyImagesSection(),
              const SizedBox(height: 16),

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



  Widget _buildHeightInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '키 (cm)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _heightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
          ],
          decoration: InputDecoration(
            hintText: '예: 170',
            suffixText: 'cm',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.height),
          ),
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
        const Text(
          '체중 (kg)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
          ],
          decoration: InputDecoration(
            hintText: '예: 65.5',
            suffixText: 'kg',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.monitor_weight),
          ),
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
        const Text(
          '눈바디 이미지',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // 정면 이미지
            Expanded(
              child: _buildImageContainer(
                '정면',
                _frontImagePath,
                () => _selectImage('front'),
              ),
            ),
            const SizedBox(width: 12),
            // 측면 이미지
            Expanded(
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

  // 이미지 컨테이너 위젯
  Widget _buildImageContainer(String label, String? imagePath, VoidCallback onTap) {
    final hasImage = imagePath != null && imagePath.isNotEmpty && ImagePickerUtils.isImageFileExists(imagePath);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: hasImage ? Colors.grey[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasImage ? Colors.grey[300]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: hasImage
            ? Stack(
                children: [
                  // 이미지 표시
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
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
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _deleteImage(imagePath),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
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
          size: 40,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
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
      await ImagePickerUtils.showImageSourceDialog(context, (XFile? image) async {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 선택 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미지가 삭제되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('이미지 삭제 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이미지 삭제 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

