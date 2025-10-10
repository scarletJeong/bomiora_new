import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/mobile_layout_wrapper.dart';

class HealthDashboardScreen extends StatefulWidget {
  const HealthDashboardScreen({super.key});

  @override
  State<HealthDashboardScreen> createState() => _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends State<HealthDashboardScreen> {
  // 사용자 정보
  String userName = "고길동(둘리아빠)";
  double targetWeight = 74.0;
  double currentWeight = 91.0;
  double height = 180.0;
  double bmi = 28.09;
  
  // 오늘의 식사 정보
  int consumedCalories = 1500;
  int targetCalories = 2000;
  double caloriePercentage = 0.75;
  
  // 건강 지표
  int steps = 6320;
  int heartRate = 96;
  int bloodSugar = 109;
  int systolicBP = 109;
  int diastolicBP = 82;
  
  // 식사별 칼로리
  Map<String, int> mealCalories = {
    '아침': 206,
    '점심': 622,
    '저녁': 0,
    '간식': 672,
  };

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '건강 대시보드',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 사용자 프로필 섹션
            _buildProfileSection(),
            const SizedBox(height: 20),
            
            // 2. 키, 체중, BMI 섹션
            _buildBodyMetricsSection(),
            const SizedBox(height: 20),
            
            // 3. 오늘의 식사 섹션
            _buildMealSection(),
            const SizedBox(height: 20),
            
            // 4. 건강 지표 섹션
            _buildHealthMetricsSection(),
          ],
        ),
      ),
    );
  }

  // 사용자 프로필 섹션
  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 프로필 사진
              Stack(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 30,
                      color: Colors.grey,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // 사용자 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '목표 체중 : ${targetWeight.toInt()}kg',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '감량 몸무게: -${(currentWeight - targetWeight).toInt()}kg',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 날짜 네비게이션
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '12 일',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '오늘',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '1.14',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 키, 체중, BMI 섹션
  Widget _buildBodyMetricsSection() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard('키(cm)', height.toStringAsFixed(1)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard('체중(kg)', currentWeight.toStringAsFixed(1)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard('BMI', bmi.toStringAsFixed(2)),
        ),
      ],
    );
  }

  // 메트릭 카드
  Widget _buildMetricCard(String title, String value) {
    return GestureDetector(
      onTap: () {
        // 체중 입력 페이지로 이동
        print('Navigate to weight input page');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 오늘의 식사 섹션
  Widget _buildMealSection() {
    return GestureDetector(
      onTap: () {
        // 식사 입력 페이지로 이동
        print('Navigate to meal input page');
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '오늘의 식사',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // 칼로리 원형 그래프
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    children: [
                      CircularProgressIndicator(
                        value: caloriePercentage,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFFF6B6B),
                        ),
                      ),
                      Center(
                        child: Text(
                          '${(caloriePercentage * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // 칼로리 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '섭취 칼로리',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFFF6B6B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${consumedCalories.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}kcal',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF6B6B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '/${targetCalories.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}kcal',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 식사별 칼로리
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMealItem('아침', mealCalories['아침']!, 'assets/images/breakfast.jpg'),
                _buildMealItem('점심', mealCalories['점심']!, 'assets/images/lunch.jpg'),
                _buildMealItem('저녁', mealCalories['저녁']!, null),
                _buildMealItem('간식', mealCalories['간식']!, 'assets/images/snack.jpg'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 식사 아이템
  Widget _buildMealItem(String mealName, int calories, String? imagePath) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: imagePath == null ? Colors.grey[200] : null,
            image: imagePath != null 
                ? const DecorationImage(
                    image: NetworkImage('https://via.placeholder.com/50x50'),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: imagePath == null
              ? const Icon(
                  Icons.add,
                  color: Colors.grey,
                  size: 24,
                )
              : null,
        ),
        const SizedBox(height: 8),
        Text(
          mealName,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          calories > 0 ? '${calories} kcal' : '',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // 건강 지표 섹션
  Widget _buildHealthMetricsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '건강 지표',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildHealthMetricCard(
              '걸음수',
              '${steps.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}걸음',
              '약 ${(steps * 0.04).toInt()}kcal 대용',
              Icons.local_fire_department,
              const Color(0xFFFF6B6B),
            ),
            _buildHealthMetricCard(
              '심박수',
              '${heartRate}bpm',
              '',
              Icons.favorite,
              const Color(0xFFFF6B9D),
            ),
            _buildHealthMetricCard(
              '혈당',
              '${bloodSugar}mg/dL',
              '점심식사 후',
              Icons.water_drop,
              const Color(0xFF4ECDC4),
            ),
            _buildHealthMetricCard(
              '혈압',
              '수축기 ${systolicBP}mmHg',
              '이완기 ${diastolicBP}mmHg',
              Icons.monitor_heart,
              const Color(0xFF45B7D1),
            ),
            _buildHealthMetricCard(
              '생리주기',
              '월경 예정일 3일전',
              '(1/12~1/16)',
              Icons.calendar_today,
              const Color(0xFF96CEB4),
            ),
          ],
        ),
      ],
    );
  }

  // 건강 지표 카드
  Widget _buildHealthMetricCard(String title, String mainValue, String subValue, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        // 해당 지표 입력 페이지로 이동
        print('Navigate to $title input page');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              mainValue,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            if (subValue.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subValue,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}