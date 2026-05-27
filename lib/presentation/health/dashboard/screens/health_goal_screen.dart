import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../data/repositories/health/health_goal/health_goal_repository.dart';
import '../../../../data/services/auth_service.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../health_common/health_responsive_scale.dart';
import '../../health_common/widgets/health_app_bar.dart';

class HealthGoalScreen extends StatefulWidget {
  const HealthGoalScreen({super.key});

  @override
  State<HealthGoalScreen> createState() => _HealthGoalScreenState();
}

class _HealthGoalScreenState extends State<HealthGoalScreen> {
  static const int _stepMin = 0;
  static const int _stepMax = 20000;
  static const int _stepUnit = 100;
  /// 375 기준 한 줄 높이; 실제 값은 [healthDp]로 스케일.
  static const double _stepsItemExtentBase = 30;
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
      if (!mounted) return;
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
      return;
    }

    final current = _parseWeightField(_currentWeightController.text);
    final target = _parseWeightField(_targetWeightController.text);

    if (current == null || current <= 0) {
      return;
    }
    if (target == null || target <= 0) {
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
      Navigator.pop(context, true);
    }
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
    final textScale = healthTextScaleByWidth(MediaQuery.of(context).size.width);
    return MobileLayoutWrapper(
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: const HealthAppBar(title: '목표설정'),
          body: SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          healthDp(context, 27),
                          healthDp(context, 5),
                          healthDp(context, 27),
                          healthDp(context, 20),
                        ),
                        child: Text(
                          '목표를 설정해주세요.',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            color: const Color(0xFF1A1A1A),
                            fontSize: healthSp(context, 14),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            healthDp(context, 27),
                            healthDp(context, 0),
                            healthDp(context, 27),
                            healthDp(context, 20),
                          ),
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
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  healthDp(context, 10),
                                ),
                                child: Material(
                                  color: _submitting
                                      ? const Color(0xFFFF5A8D)
                                          .withValues(alpha: 0.5)
                                      : const Color(0xFFFF5A8D),
                                  child: InkWell(
                                    onTap:
                                        _submitting ? null : _onRegister,
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: healthDp(context, 16),
                                        vertical: healthDp(context, 10),
                                      ),
                                      child: Center(
                                        child: _submitting
                                            ? SizedBox(
                                                height: healthDp(
                                                    context, 22),
                                                width: healthDp(
                                                    context, 22),
                                                child:
                                                    const CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Text(
                                                '등록',
                                                textScaler:
                                                    TextScaler.noScaling,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: healthSp(
                                                      context, 16),
                                                  fontFamily:
                                                      'Gmarket Sans TTF',
                                                  fontWeight:
                                                      FontWeight.w500,
                                                ),
                                              ),
                                      ),
                                    ),
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
      ),
    );
  }

  Widget _buildStepsPickerSection() {
    final itemExtent = healthDp(context, _stepsItemExtentBase);
    final wheelViewportH = healthDp(context, 120);
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
        SizedBox(height: healthDp(context, 10)),
        Container(
          width: double.infinity,
          height: wheelViewportH,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(healthDp(context, 7)),
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
              itemExtent: itemExtent,
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
                    fontSize = 24;
                    color = const Color(0xFF1A1A1A);
                  } else if (distance == 1) {
                    fontSize = 12;
                    color = const Color(0xFF9A9A9A);
                  } else {
                    fontSize = 8;
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
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: Colors.black,
            fontSize: healthSp(context, 16),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: healthDp(context, 10)),
        _GoalTextField(
          controller: controller,
          hint: hint,
          keyboardType: keyboardType,
        ),
      ],
    );
  }
}

/// 목표설정 체중 입력 — 375 기준 높이 40, [healthDp]로 스케일.
class _GoalTextField extends StatelessWidget {
  const _GoalTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: healthDp(context, 40),
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
      alignment: Alignment.centerLeft,
      clipBehavior: Clip.none,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: const Color(0x7FD2D2D2),
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 7)),
        ),
      ),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.noScaling,
        ),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textAlignVertical: TextAlignVertical.center,
          style: TextStyle(
            color: const Color(0xFF1A1A1A),
            fontSize: healthSp(context, 16),
            height: 1.0,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: const Color(0xFF898383),
              fontSize: healthSp(context, 16),
              height: 1.0,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.only(
              bottom: healthDp(context, 2),
            ),
          ),
        ),
      ),
    );
  }
}
