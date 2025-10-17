import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../../data/models/health/weight_record_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/repositories/health/weight_repository.dart';

class WeightInputScreen extends StatefulWidget {
  final WeightRecord? record; // null이면 새 기록, 있으면 수정

  const WeightInputScreen({super.key, this.record});

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
    } else {
      // 새 기록 모드: 최신 기록에서 키 가져오기
      _loadLatestHeight();
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

              // 키 입력
              _buildHeightInput(),
              const SizedBox(height: 24),

              // 체중 입력
              _buildWeightInput(),
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



// 추후에 눈바디 사진 업로드 기능 개발해야함.


  Color _getBmiColor(double? bmi) {
    if (bmi == null) return Colors.grey;
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 23) return Colors.green;
    if (bmi < 25) return Colors.orange;
    return Colors.red;
  }
}

