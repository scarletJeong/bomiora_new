import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/models/health/weight/weight_record_model.dart';
import '../../../../data/models/health/blood_pressure/blood_pressure_record_model.dart';
import '../../../../data/repositories/health/weight/weight_repository.dart';
import '../../../../data/repositories/health/blood_pressure/blood_pressure_repository.dart';
import '../../weight/screens/weight_list_screen.dart';
import '../../weight/screens/weight_input_screen.dart';
import '../../blood_pressure/screens/blood_pressure_list_screen.dart';
import '../../blood_pressure/screens/blood_pressure_input_screen.dart';

class HealthDashboardScreen extends StatefulWidget {
  const HealthDashboardScreen({super.key});

  @override
  State<HealthDashboardScreen> createState() => _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends State<HealthDashboardScreen> {
  // 사용자 정보
  UserModel? currentUser;
  WeightRecord? latestWeightRecord;
  BloodPressureRecord? latestBloodPressureRecord;
  
  // 체중 관련 (기본값)
  double targetWeight = 74.0;
  double currentWeight = 0.0;
  double height = 170.0;
  double bmi = 0.0;
  
  // 로딩 상태
  bool isLoading = true;
  
  // 날짜 관련
  DateTime selectedDate = DateTime.now();
  
  // 오늘의 식사 정보
  int consumedCalories = 1500;
  int targetCalories = 2000;
  double caloriePercentage = 0.75;
  
  // 건강 지표
  int steps = 6320;
  int heartRate = 96;
  int bloodSugar = 109;
  int systolicBP = 0;  // 혈압 데이터에서 가져올 예정
  int diastolicBP = 0; // 혈압 데이터에서 가져올 예정
  
  // 식사별 칼로리
  Map<String, int> mealCalories = {
    '아침': 206,
    '점심': 622,
    '저녁': 0,
    '간식': 672,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    
    try {
      // 사용자 정보 가져오기
      final user = await AuthService.getUser();
      
      if (user == null) {
        // 로그인되지 않은 경우
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다')),
          );
          Navigator.pop(context);
        }
        return;
      }
      
      // 최신 체중 기록과 혈압 기록을 병렬로 가져오기 (성능 최적화)
      final results = await Future.wait([
        WeightRepository.getLatestWeightRecord(user.id),
        BloodPressureRepository.getLatestBloodPressureRecord(user.id).catchError((e) {
          print('혈압 기록 가져오기 오류: $e');
          return null;
        }),
      ]);
      
      final weightRecord = results[0] as WeightRecord?;
      final bloodPressureRecord = results[1] as BloodPressureRecord?;
      
      setState(() {
        currentUser = user;
        latestWeightRecord = weightRecord;
        latestBloodPressureRecord = bloodPressureRecord;
        
        if (weightRecord != null) {
          currentWeight = weightRecord.weight;
          height = weightRecord.height ?? 170.0;
          bmi = weightRecord.bmi ?? 0.0;
        }
        
        if (bloodPressureRecord != null) {
          systolicBP = bloodPressureRecord.systolic;
          diastolicBP = bloodPressureRecord.diastolic;
        }
        
        isLoading = false;
      });
    } catch (e) {
      print('데이터 로딩 오류: $e');
      setState(() => isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터 로딩 실패: $e')),
        );
      }
    }
  }

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
        actions: [
          // 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : _loadData,
          ),
        ],
      ),
      child: isLoading 
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('데이터를 불러오는 중...'),
              ],
            ),
          )
        : SingleChildScrollView(
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
                    child: Text(
                      currentUser?.name.isNotEmpty == true 
                          ? currentUser!.name[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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
                      currentUser?.name ?? '사용자',
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
          _buildDateNavigation(),
        ],
      ),
    );
  }

  // 날짜 네비게이션 위젯
  Widget _buildDateNavigation() {
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year && 
                   selectedDate.month == now.month && 
                   selectedDate.day == now.day;
    
    final yesterday = selectedDate.subtract(const Duration(days: 1));
    final tomorrow = selectedDate.add(const Duration(days: 1));
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 이전 날짜
        GestureDetector(
          onTap: () {
            setState(() {
              selectedDate = yesterday;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chevron_left, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${yesterday.month}.${yesterday.day.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // 현재 선택된 날짜
        GestureDetector(
          onTap: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (pickedDate != null) {
              setState(() {
                selectedDate = pickedDate;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black, // 검정색으로 통일
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${selectedDate.month}.${selectedDate.day.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        
        // 다음 날짜 (오늘 이후는 비활성화)
        GestureDetector(
          onTap: tomorrow.isAfter(now) ? null : () {
            setState(() {
              selectedDate = tomorrow;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: tomorrow.isAfter(now) ? Colors.grey[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${tomorrow.month}.${tomorrow.day.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 14,
                    color: tomorrow.isAfter(now) ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right, 
                  size: 16, 
                  color: tomorrow.isAfter(now) ? Colors.grey[400] : Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ],
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
      onTap: () async {
        // 키, 체중, BMI 카드 클릭 시 체중 기록 목록 페이지로 이동 (선택된 날짜 전달)
        if (title == '키(cm)' || title == '체중(kg)' || title == 'BMI') {
          if (!mounted) return;
          
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WeightListScreen(initialDate: selectedDate),
            ),
          );
          
          // 체중 목록 페이지에서 돌아왔을 때 데이터 새로고침
          if (result == true && mounted) {
            _loadData();
          }
        }
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
        child: Stack(
          children: [
            Column(
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
              latestBloodPressureRecord != null 
                ? '수축기 ${systolicBP}mmHg'
                : '데이터 없음',
              latestBloodPressureRecord != null 
                ? '이완기 ${diastolicBP}mmHg'
                : '혈압을 측정해주세요',
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
        if (title == '혈압') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BloodPressureListScreen(initialDate: selectedDate),
            ),
          );
        } else {
          print('Navigate to $title input page');
        }
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
                  fontSize: title == '혈압' ? 16 : 12,
                  fontWeight: title == '혈압' ? FontWeight.bold : FontWeight.normal,
                  color: title == '혈압' ? Colors.black : Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
}