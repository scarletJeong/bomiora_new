import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../data/repositories/health/health_goal/health_goal_repository.dart';
import '../../../../data/services/auth_service.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';

class HealthGoalScreen extends StatefulWidget {
  const HealthGoalScreen({super.key});

  @override
  State<HealthGoalScreen> createState() => _HealthGoalScreenState();
}

class _HealthGoalScreenState extends State<HealthGoalScreen> {
  static const int _stepMin = 0;
  static const int _stepMax = 20000;
  static const int _stepUnit = 100;
  static const double _stepsItemExtent = 30;
  static const int _wheelTickDebounceMs = 70;

  final TextEditingController _currentWeightController =
      TextEditingController();
  final TextEditingController _targetWeightController =
      TextEditingController();
  late final FixedExtentScrollController _stepsWheelController;

  int _selectedSteps = 6000;
  bool _loading = true;
  bool _submitting = false;
  int _lastStepsWheelTickMs = 0;

  int get _stepsItemCount => ((_stepMax - _stepMin) ~/ _stepUnit) + 1;

  int _stepsFromIndex(int index) => _stepMin + (index * _stepUnit);

  int _indexFromSteps(int steps) =>
      ((steps - _stepMin) ~/ _stepUnit).clamp(0, _stepsItemCount - 1);

  int _snapStepsToGrid(int steps) {
    final rounded =
        ((_stepUnit * (steps / _stepUnit).round()).clamp(_stepMin, _stepMax))
            .toInt();
    return rounded;
  }

  String _formatNumber(int value) => NumberFormat('#,###').format(value);

  void _changeStepsIndexBy(int delta) {
    final idx = _indexFromSteps(_selectedSteps);
    final next = (idx + delta).clamp(0, _stepsItemCount - 1);
    if (next == idx) return;
    setState(() => _selectedSteps = _stepsFromIndex(next));
    if (_stepsWheelController.hasClients) {
      _stepsWheelController.animateToItem(
        next,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _stepsWheelController = FixedExtentScrollController(
      initialItem: _indexFromSteps(_selectedSteps),
    );
    _loadLatestGoal();
  }

  Future<void> _loadLatestGoal() async {
    final user = await AuthService.getUser();
    final mbId = user?.id;
    if (!mounted) return;
    if (mbId == null || mbId.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final latest = await HealthGoalRepository.fetchLatest(mbId);
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (latest != null) {
        if (latest.currentWeight != null) {
          _currentWeightController.text =
              _trimTrailingZeros(latest.currentWeight!);
        }
        if (latest.targetWeight != null) {
          _targetWeightController.text =
              _trimTrailingZeros(latest.targetWeight!);
        }
        if (latest.dailyStepGoal != null) {
          _selectedSteps = _snapStepsToGrid(latest.dailyStepGoal!);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_stepsWheelController.hasClients) return;
      final idx = _indexFromSteps(_selectedSteps);
      _stepsWheelController.jumpToItem(idx);
    });
  }

  String _trimTrailingZeros(double v) {
    final s = v.toStringAsFixed(1);
    if (s.endsWith('.0')) return s.substring(0, s.length - 2);
    return s;
  }

  double? _parseWeightField(String raw) {
    final t = raw.replaceAll(',', '.').trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _onRegister() async {
    final user = await AuthService.getUser();
    final mbId = user?.id;
    if (mbId == null || mbId.isEmpty) {
      _showSnack('로그인이 필요합니다.');
      return;
    }

    final current = _parseWeightField(_currentWeightController.text);
    final target = _parseWeightField(_targetWeightController.text);

    if (current == null || current <= 0) {
      _showSnack('현재 체중을 올바르게 입력해주세요.');
      return;
    }
    if (target == null || target <= 0) {
      _showSnack('목표 체중을 올바르게 입력해주세요.');
      return;
    }

    setState(() => _submitting = true);
    final result = await HealthGoalRepository.register(
      mbId: mbId,
      currentWeight: current,
      targetWeight: target,
      dailyStepGoal: _selectedSteps,
      measuredAt: DateTime.now(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.success) {
      _showSnack(result.message ?? '저장되었습니다.');
      Navigator.pop(context, true);
    } else {
      _showSnack(result.message ?? '저장에 실패했습니다.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _currentWeightController.dispose();
    _targetWeightController.dispose();
    _stepsWheelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileLayoutWrapper(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            '목표설정',
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 27, vertical: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInputSection(
                              title: '현재 체중(kg)',
                              hint: '몸무게를 입력해주세요.',
                              controller: _currentWeightController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                            const SizedBox(height: 20),
                            _buildInputSection(
                              title: '목표 체중(kg)',
                              hint: '몸무게를 입력해주세요.',
                              controller: _targetWeightController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                            const SizedBox(height: 20),
                            _buildStepsPickerSection(),
                            const SizedBox(height: 30),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _submitting ? null : _onRegister,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF5A8D),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      const Color(0xFFFF5A8D)
                                          .withValues(alpha: 0.5),
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _submitting
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        '등록',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontFamily: 'Gmarket Sans TTF',
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildStepsPickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '하루 걸음 수',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x7FD2D2D2)),
            color: Colors.white,
          ),
          child: Listener(
            onPointerSignal: (event) {
              if (!kIsWeb || event is! PointerScrollEvent) return;
              final nowMs = DateTime.now().millisecondsSinceEpoch;
              if (nowMs - _lastStepsWheelTickMs < _wheelTickDebounceMs) {
                return;
              }
              _lastStepsWheelTickMs = nowMs;
              final delta = event.scrollDelta.dy > 0 ? 1 : -1;
              _changeStepsIndexBy(delta);
            },
            child: ListWheelScrollView.useDelegate(
              controller: _stepsWheelController,
              itemExtent: _stepsItemExtent,
              diameterRatio: 2.6,
              perspective: 0.003,
              physics: kIsWeb
                  ? const NeverScrollableScrollPhysics()
                  : const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) {
                final next = _stepsFromIndex(index);
                if (next == _selectedSteps) return;
                setState(() => _selectedSteps = next);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: _stepsItemCount,
                builder: (context, index) {
                  final value = _stepsFromIndex(index);
                  final distance = (value - _selectedSteps).abs() ~/ _stepUnit;

                  double fontSize;
                  Color color;

                  if (distance == 0) {
                    fontSize = 30;
                    color = const Color(0xFF1A1A1A);
                  } else if (distance == 1) {
                    fontSize = 24;
                    color = const Color(0xFF9A9A9A);
                  } else {
                    fontSize = 14;
                    color = const Color(0xFFBEBEBE);
                  }

                  return Center(
                    child: Text(
                      _formatNumber(value),
                      style: TextStyle(
                        color: color,
                        fontSize: fontSize,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                        height: 1.0,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection({
    required String title,
    required String hint,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFF898383),
              fontSize: 16,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(
                width: 1,
                color: Color(0x7FD2D2D2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(
                width: 1.2,
                color: Color(0xFFFF5A8D),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
