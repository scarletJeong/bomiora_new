import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StatsSection extends StatefulWidget {
  const StatsSection({super.key});

  @override
  State<StatsSection> createState() => _StatsSectionState();
}

class _StatsSectionState extends State<StatsSection>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  // 현재 월별 통계 데이터
  final Map<int, List<dynamic>> statsData = {
    1: [0, 0, 82.7, 91.5],
    2: [0, 0, 82.7, 91.5],
    3: [0, 0, 82.7, 91.5],
    4: [6437308, 66364, 82.2, 91.5],
    5: [6538808, 67864, 82.5, 92.0],
    6: [6640308, 69364, 82.5, 92.5],
    7: [6741808, 70864, 82.8, 92.5],
    8: [6944300, 73356, 82.8, 92.5],
    9: [7146792, 75848, 83.0, 93.0],
    10: [7349284, 78340, 83.0, 93.0],
    11: [7551776, 80832, 83.2, 93.5],
    12: [7754268, 83324, 83.5, 93.5],
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    // 위젯이 화면에 나타날 때 애니메이션 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentData = statsData[currentMonth] ?? [0, 0, 0, 0];
    final formattedDate = DateFormat('yyyy . MM 기준').format(now);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey[50]!,
            Colors.white,
          ],
        ),
      ),
      child: Column(
        children: [
          // 날짜와 타이틀
          Text(
            formattedDate,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/bomiora-logo.png',
                height: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                '누적 집계 현황',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          
          // 통계 컨테이너
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            '누 / 적 / 처 / 방 / 량',
                            (currentData[0] * _animation.value).toInt(),
                            '포',
                            true,
                          ),
                        ),
                        _buildDivider(),
                        Expanded(
                          child: _buildStatItem(
                            '누 / 적 / 처 / 방 / 건',
                            (currentData[1] * _animation.value).toInt(),
                            '건',
                            true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            '재 / 구 / 매 / 율',
                            currentData[2] * _animation.value,
                            '%',
                            false,
                          ),
                        ),
                        _buildDivider(),
                        Expanded(
                          child: _buildStatItem(
                            '구 / 매 / 만 / 족 / 도',
                            currentData[3] * _animation.value,
                            '%',
                            false,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 30),
          
          // 하단 텍스트
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  '600만포 돌파! 및 6만 5천여 건의 누적 처방으로 증명된',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: '보미오라 다이어트 솔루션',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF007FAE),
                        ),
                      ),
                      TextSpan(
                        text: ' 지금 바로 체험하세요.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, dynamic value, String unit, bool isInteger) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            letterSpacing: 1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: isInteger 
                    ? NumberFormat('#,###').format(value)
                    : value.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextSpan(
                text: unit,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF007FAE),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.grey[300],
      margin: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
