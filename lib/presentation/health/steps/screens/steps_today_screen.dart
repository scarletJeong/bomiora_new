import 'package:flutter/material.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../health_common/health_responsive_scale.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../../common/widgets/date_top_widget.dart';
import '../../../common/widgets/btn_record.dart';
import '../../../../data/models/health/steps/steps_record_model.dart';
import '../../../../data/repositories/health/steps/steps_repository.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../core/utils/price_formatter.dart';
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
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textScale = healthTextScaleByWidth(MediaQuery.sizeOf(context).width);
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      appBar: HealthAppBar(
        title: '총 걸음 수',
        actions: [
          healthAppBarAction(
            context: context,
            icon: Icons.refresh,
            tooltip: '새로고침',
            onPressed: isLoading ? null : _loadData,
          ),
        ],
      ),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  SizedBox(height: healthDp(context, 16)),
                  Text(
                    '데이터를 불러오는 중...',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(fontSize: healthSp(context, 14)),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: healthDp(context, 20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentStatusSection(),
            SizedBox(height: healthDp(context, 24)),
            _buildTotalStepsCard(),
            SizedBox(height: healthDp(context, 20)),
            _buildSummaryCards(),
            SizedBox(height: healthDp(context, 24)),
            _buildChartSection(),
          ],
        ),
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
              _loadData();
            },
            secondaryColor: Colors.grey[400],
          ),
          SizedBox(height: healthDp(context, 16)),
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
      padding: EdgeInsets.all(healthDp(context, 24)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(healthDp(context, 16)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: healthDp(context, 8),
            offset: Offset(0, healthDp(context, 2)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              '오늘 총 걸음 수',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: healthSp(context, 16),
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: healthDp(context, 16)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${PriceFormatter.format(totalSteps)} 걸음',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: healthSp(context, 32),
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              if (stepsDiff != 0) ...[
                SizedBox(height: healthDp(context, 8)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 8),
                    vertical: healthDp(context, 4),
                  ),
                  decoration: BoxDecoration(
                    color: isIncrease ? Colors.red[50] : Colors.blue[50],
                    borderRadius: BorderRadius.circular(healthDp(context, 8)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isIncrease ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: healthDp(context, 16),
                        color: isIncrease ? Colors.red : Colors.blue,
                      ),
                      SizedBox(width: healthDp(context, 2)),
                      Text(
                        '전날 대비 ${PriceFormatter.format(stepsDiff.abs())} ${isIncrease ? '↑' : '↓'}',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: healthSp(context, 12),
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
        SizedBox(width: healthDp(context, 12)),
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
      padding: EdgeInsets.all(healthDp(context, 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(healthDp(context, 12)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: healthDp(context, 8),
            offset: Offset(0, healthDp(context, 2)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: healthDp(context, 24),
          ),
          SizedBox(height: healthDp(context, 8)),
          Text(
            value,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontSize: healthSp(context, 18),
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          if (comparison != null) ...[
            SizedBox(height: healthDp(context, 4)),
            Text(
              comparison,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: healthSp(context, 12),
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
      padding: EdgeInsets.all(healthDp(context, 20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(healthDp(context, 16)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: healthDp(context, 8),
            offset: Offset(0, healthDp(context, 2)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildChartTypeButton('시간별', 'hourly'),
              SizedBox(width: healthDp(context, 8)),
              _buildChartTypeButton('일별', 'daily'),
              SizedBox(width: healthDp(context, 8)),
              _buildChartTypeButton('월별', 'monthly'),
            ],
          ),
          SizedBox(height: healthDp(context, 20)),
          SizedBox(
            height: healthDp(context, 200),
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
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 16),
          vertical: healthDp(context, 8),
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[100],
          borderRadius: BorderRadius.circular(healthDp(context, 8)),
        ),
        child: Text(
          label,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: healthSp(context, 14),
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
