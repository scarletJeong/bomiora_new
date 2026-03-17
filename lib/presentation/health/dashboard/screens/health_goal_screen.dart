import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../common/widgets/mobile_layout_wrapper.dart';

class HealthGoalScreen extends StatefulWidget {
  const HealthGoalScreen({super.key});

  @override
  State<HealthGoalScreen> createState() => _HealthGoalScreenState();
}

// 하루 걸음 수 휠 스크롤 픽커
class _HealthGoalScreenState extends State<HealthGoalScreen> {
  static const int _stepMin = 0;
  static const int _stepMax = 20000;
  static const int _stepUnit = 100;

  late final FixedExtentScrollController _stepsWheelController;
  int _selectedSteps = 6000;

  int get _stepsItemCount => ((_stepMax - _stepMin) ~/ _stepUnit) + 1;

  int _stepsFromIndex(int index) => _stepMin + (index * _stepUnit);

  int _indexFromSteps(int steps) => ((steps - _stepMin) ~/ _stepUnit);

  String _formatNumber(int value) => NumberFormat('#,###').format(value);

  @override
  void initState() {
    super.initState();
    _stepsWheelController = FixedExtentScrollController(
      initialItem: _indexFromSteps(_selectedSteps),
    );
  }

  @override
  void dispose() {
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputSection(
                  title: '현재 체중(kg)',
                  hint: '몸무게를 입력해주세요.',
                ),
                const SizedBox(height: 20),
                _buildInputSection(
                  title: '목표 체중(kg)',
                  hint: '몸무게를 입력해주세요.',
                ),
                const SizedBox(height: 20),
                _buildStepsPickerSection(),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5A8D),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      '등록',
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
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
          child: ListWheelScrollView.useDelegate(
            controller: _stepsWheelController,
            itemExtent: 30,
            diameterRatio: 2.6,
            perspective: 0.003,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (index) {
              setState(() {
                _selectedSteps = _stepsFromIndex(index);
              });
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
      ],
    );
  }

  Widget _buildInputSection({
    required String title,
    required String hint,
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
