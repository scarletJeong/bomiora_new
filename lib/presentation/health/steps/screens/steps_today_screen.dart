import 'package:flutter/material.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/date_top_widget.dart';
import '../../../common/widgets/btn_record.dart';
import '../../../../data/models/health/steps/steps_record_model.dart';
import '../../../../data/repositories/health/steps/steps_repository.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../widgets/hourly_steps_chart.dart';

class StepsTodayScreen extends StatefulWidget {
  final DateTime? initialDate;
  
  const StepsTodayScreen({super.key, this.initialDate});

  @override
  State<StepsTodayScreen> createState() => _StepsTodayScreenState();
}

class _StepsTodayScreenState extends State<StepsTodayScreen> {
  UserModel? currentUser;
  StepsRecord? todayStepsRecord;
  StepsStatistics? stepsStatistics;
  DateTime selectedDate = DateTime.now();
  bool isLoading = true;
  String chartType = 'hourly'; // hourly, daily, monthly

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      selectedDate = widget.initialDate!;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    
    try {
      // 사용자 정보 가져오기
      final user = await AuthService.getUser();
      
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다')),
          );
          Navigator.pop(context);
        }
        return;
      }

      // 걸음수 데이터와 통계를 병렬로 가져오기
      final results = await Future.wait([
        StepsRepository.getStepsRecordByDate(int.parse(user.id), selectedDate),
        StepsRepository.getStepsStatistics(int.parse(user.id)),
      ]);

      setState(() {
        currentUser = user;
        todayStepsRecord = results[0] as StepsRecord?;
        stepsStatistics = results[1] as StepsStatistics?;
        isLoading = false;
      });
    } catch (e) {
      print('걸음수 데이터 로딩 오류: $e');
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '총 걸음 수',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
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
        padding: const EdgeInsets.symmetric(horizontal: 20),  // 좌우 20px 패딩
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜 네비게이션
            _buildCurrentStatusSection(),
            const SizedBox(height: 24),
            
            // 오늘의 총 걸음수
            _buildTotalStepsCard(),
            const SizedBox(height: 20),
            
            // 거리와 칼로리 카드
            _buildSummaryCards(),
            const SizedBox(height: 24),
            
            // 시간별 차트
            _buildChartSection(),
          ],
        ),
      ),
    );
  }

  // 날짜 네비게이션
  Widget _buildCurrentStatusSection() {
    return Container(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜 선택 위젯
          DateTopWidget(
            selectedDate: selectedDate,
            onDateChanged: (newDate) {
              setState(() {
                selectedDate = newDate;
              });
            },
            secondaryColor: Colors.grey[400],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  
  // 오늘의 총 걸음수 카드
  Widget _buildTotalStepsCard() {
    final totalSteps = todayStepsRecord?.totalSteps ?? 0;
    final stepsDiff = stepsStatistics?.stepsDifference ?? 0;
    final isIncrease = stepsDiff > 0;
    
    return Container(
      padding: const EdgeInsets.all(24),
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
          const Center(
            child: Text(
              '오늘 총 걸음 수',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${totalSteps.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} 걸음',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              if (stepsDiff != 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isIncrease ? Colors.red[50] : Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isIncrease ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 16,
                        color: isIncrease ? Colors.red : Colors.blue,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '전날 대비 ${stepsDiff.abs().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} ${isIncrease ? '↑' : '↓'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isIncrease ? Colors.red : Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // 거리와 칼로리 요약 카드
  Widget _buildSummaryCards() {
    final distance = todayStepsRecord?.distance ?? 0.0;
    final calories = todayStepsRecord?.calories ?? 0;
    final distanceDiff = stepsStatistics?.distanceDifference ?? 0.0;
    final caloriesDiff = stepsStatistics?.caloriesDifference ?? 0;
    
    return Row(
      children: [
        // 거리 카드
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.directions_walk,
            iconColor: Colors.black,
            title: '거리',
            value: '${distance.toStringAsFixed(2)}km',
            comparison: distanceDiff != 0 
              ? '전날 대비 ${distanceDiff.abs().toStringAsFixed(1)}km ${distanceDiff > 0 ? '↑' : '↓'}'
              : null,
            comparisonColor: distanceDiff > 0 ? Colors.red : Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        // 칼로리 카드
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.local_fire_department,
            iconColor: Colors.orange,
            title: '칼로리',
            value: '${calories}kcal',
            comparison: caloriesDiff != 0 
              ? '전날 대비 ${caloriesDiff.abs()}kcal ${caloriesDiff > 0 ? '↑' : '↓'}'
              : null,
            comparisonColor: caloriesDiff > 0 ? Colors.red : Colors.blue,
          ),
        ),
      ],
    );
  }

  // 요약 카드 위젯
  Widget _buildSummaryCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    String? comparison,
    Color? comparisonColor,
  }) {
    return Container(
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
          Icon(
            icon,
            color: iconColor,
            size: 24,
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
          if (comparison != null) ...[
            const SizedBox(height: 4),
            Text(
              comparison,
              style: TextStyle(
                fontSize: 12,
                color: comparisonColor ?? Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 차트 섹션
  Widget _buildChartSection() {
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
          // 차트 타입 선택 버튼
          Row(
            children: [
              _buildChartTypeButton('시간별', 'hourly'),
              const SizedBox(width: 8),
              _buildChartTypeButton('일별', 'daily'),
              const SizedBox(width: 8),
              _buildChartTypeButton('월별', 'monthly'),
            ],
          ),
          const SizedBox(height: 20),
          
          // 차트
          SizedBox(
            height: 200,
            child: HourlyStepsChart(
              hourlySteps: todayStepsRecord?.hourlySteps ?? [],
              chartType: chartType,
            ),
          ),
        ],
      ),
    );
  }

  // 차트 타입 선택 버튼
  Widget _buildChartTypeButton(String label, String type) {
    final isSelected = chartType == type;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          chartType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
