import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/date_top_widget.dart';
import '../../../common/widgets/btn_record.dart';
import '../../../../data/models/health/menstrual_cycle/menstrual_cycle_model.dart';
import '../../../../data/repositories/health/menstrual_cycle/menstrual_cycle_repository.dart';
import '../../../../data/services/auth_service.dart';
import 'menstrual_cycle_input_screen.dart';

class MenstrualCycleInfoScreen extends StatefulWidget {
  const MenstrualCycleInfoScreen({super.key});

  @override
  State<MenstrualCycleInfoScreen> createState() => _MenstrualCycleInfoScreenState();
}

class _MenstrualCycleInfoScreenState extends State<MenstrualCycleInfoScreen> {
  MenstrualCycleRecord? _currentRecord;
  bool _isLoading = true;
  DateTime selectedDate = DateTime.now(); // 선택된 날짜 추가

  @override
  void initState() {
    super.initState();
    _loadMenstrualCycleData();
  }

  Future<void> _loadMenstrualCycleData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await AuthService.getUser();
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }

      final record = await MenstrualCycleRepository.getLatestMenstrualCycleRecord(user.id);
      setState(() {
        _currentRecord = record;
        _isLoading = false;
      });
    } catch (e) {
      print('생리주기 데이터 로딩 오류: $e');
      setState(() {
        _isLoading = false;
      });
      
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
          '생리주기',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _isLoading ? null : _loadMenstrualCycleData,
          ),
        ],
      ),
      child: _isLoading
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
          : _currentRecord == null
              ? _buildNoDataView()
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),  // 좌우 20px 패딩
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 현재 상태 섹션
                      _buildCurrentStatusSection(),
                      const SizedBox(height: 0),
                      
                      // 생리주기 원형 차트
                      _buildCycleChart(),
                      const SizedBox(height: 10),
                      
                      // 현재 단계별 추천사항
                      _buildPhaseRecommendations(),
                      const SizedBox(height: 20),
                      
                      // 예상 날짜들
                      _buildExpectedDatesSection(),
                      const SizedBox(height: 30),
                      
                      // 기록하기 버튼
                      BtnRecord(
                        text: '+ 기록하기',
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MenstrualCycleInputScreen(),
                            ),
                          );
                          if (result == true) {
                            _loadMenstrualCycleData();
                          }
                        },
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildNoDataView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              '생리주기 정보가 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '첫 번째 생리주기 정보를 입력해주세요',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 32),
            BtnRecord(
              text: '+ 기록하기',
              onPressed: () async {
                // 선택한 날짜에 맞는 레코드 찾기
                final recordForDate = await _getRecordForDate(selectedDate);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MenstrualCycleInputScreen(
                      existingRecord: recordForDate,
                    ),
                  ),
                );
                if (result == true) {
                  _loadMenstrualCycleData();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

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
          
          // 현재 상태 정보
          _buildCurrentStatusInfo(),
        ],
      ),
    );
  }

  Widget _buildCurrentStatusInfo() {
    // selectedDate를 기준으로 현재 주기 일차 계산
    final daysSinceLastPeriod = selectedDate.difference(_currentRecord!.lastPeriodStart).inDays;
    final cycleDay = (daysSinceLastPeriod % _currentRecord!.cycleLength) + 1;
    
    // selectedDate를 기준으로 현재 단계 계산
    MenstrualPhase currentPhase;
    if (cycleDay <= _currentRecord!.periodLength) {
      currentPhase = MenstrualPhase.menstrual; // 월경기
    } else if (cycleDay <= 14) {
      currentPhase = MenstrualPhase.follicular; // 난포기
    } else if (cycleDay <= 17) {
      currentPhase = MenstrualPhase.ovulation; // 배란기
    } else {
      currentPhase = MenstrualPhase.luteal; // 황체기
    }
    
    final phaseInfo = MenstrualPhaseInfo.getPhaseInfo(currentPhase);
    
    return Column(
      children: [
        const SizedBox(height: 4),
        Center(
          child: RichText(
            text: TextSpan(
              children: [
                const TextSpan(
                  text: '오늘은 ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                TextSpan(
                  text: phaseInfo.name,
                  style: const TextStyle(
                    fontSize: 20, // 글씨 크기 변경
                    fontWeight: FontWeight.bold,
                    color: Colors.pink, // 글씨 색상 변경
                  ),
                ),
                const TextSpan(
                  text: ' 기간입니다.',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCycleChart() {
    if (_currentRecord == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: const Center(
          child: Text('생리주기 데이터가 없습니다'),
        ),
      );
    }

    // selectedDate를 기준으로 현재 주기 일차 계산
    final daysSinceLastPeriod = selectedDate.difference(_currentRecord!.lastPeriodStart).inDays;
    final cycleDay = (daysSinceLastPeriod % _currentRecord!.cycleLength) + 1;
    final cycleLength = _currentRecord!.cycleLength;
    
    // 생리주기 완료 시 자동으로 다음 생리주기 생성
    _checkAndCreateNextCycle();
    
    // 31일 기준으로 현재 일차 계산 (최대 31일)
    final currentDay = cycleDay > 31 ? 31 : cycleDay;
    final progress = currentDay / 31.0;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 원형 차트
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                children: [
                  // 배경 원
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[100],
                    ),
                  ),
                  // 배경 원
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[200],
                    ),
                  ),
                  // 사분면별 진행 원
                  CustomPaint(
                    size: const Size(200, 200),
                    painter: MenstrualCyclePainter(
                      progress: progress,
                      cycleDay: currentDay,
                      periodLength: _currentRecord?.periodLength ?? 5,
                    ),
                  ),
                  // 내부 원
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        // 선택한 날짜에 맞는 레코드 찾기
                        final recordForDate = await _getRecordForDate(selectedDate);
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MenstrualCycleInputScreen(
                              existingRecord: recordForDate,
                            ),
                          ),
                        );
                        if (result == true) {
                          _loadMenstrualCycleData();
                        }
                      },
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '생리 예정일',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('M.d').format(_currentRecord!.nextPeriodStart),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '탭하여 수정',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPhaseIndicator() {
    final phase = _currentRecord!.currentPhase;
    final phaseInfo = MenstrualPhaseInfo.getPhaseInfo(phase);
    
    Color phaseColor;
    switch (phase) {
      case MenstrualPhase.menstrual:
        phaseColor = Colors.red;
        break;
      case MenstrualPhase.follicular:
        phaseColor = Colors.green;
        break;
      case MenstrualPhase.ovulation:
        phaseColor = Colors.orange;
        break;
      case MenstrualPhase.luteal:
        phaseColor = Colors.purple;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: phaseColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: phaseColor.withOpacity(0.3)),
      ),
      child: Text(
        phaseInfo.name,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: phaseColor,
        ),
      ),
    );
  }

  Widget _buildPhaseRecommendations() {
    final phase = _currentRecord!.currentPhase;
    final phaseInfo = MenstrualPhaseInfo.getPhaseInfo(phase);
    
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
          Text(
            '${phaseInfo.name} 추천사항',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          _buildRecommendationItem(
            '음식',
            phaseInfo.foodRecommendations.first,
            Icons.restaurant,
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildRecommendationItem(
            '건강',
            phaseInfo.healthRecommendations.first,
            Icons.favorite,
            Colors.red,
          ),
          const SizedBox(height: 12),
          _buildRecommendationItem(
            '관리',
            phaseInfo.managementRecommendations.first,
            Icons.spa,
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String category, String content, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  
  Widget _buildExpectedDatesSection() {
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
          _buildDateItem(
            '생리 기간',
            '${DateFormat('M월 d일').format(_currentRecord!.nextPeriodStart)}~${DateFormat('M월 d일').format(_currentRecord!.nextPeriodEnd)}',
            Colors.red,
          ),
          const SizedBox(height: 12),
          _buildDateItem(
            '예상 가임기',
            '${DateFormat('M월 d일').format(_currentRecord!.fertileWindowStart)}~${DateFormat('M월 d일').format(_currentRecord!.fertileWindowEnd)}',
            Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildDateItem(
            '예상 배란일',
            DateFormat('M월 d일').format(_currentRecord!.ovulationDate),
            Colors.pink,
          ),
        ],
      ),
    );
  }

  Widget _buildDateItem(String title, String date, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
            ),
          ),
        ),
        Text(
          date,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // 선택한 날짜에 맞는 레코드 찾기
  Future<MenstrualCycleRecord?> _getRecordForDate(DateTime selectedDate) async {
    try {
      final user = await AuthService.getUser();
      if (user == null) return null;
      
      // 모든 생리주기 레코드 가져오기
      final records = await MenstrualCycleRepository.getMenstrualCycleRecords(user.id);
      
      // 선택한 날짜에 해당하는 레코드 찾기
      for (final record in records) {
        final daysSinceStart = selectedDate.difference(record.lastPeriodStart).inDays;
        
        // 선택한 날짜가 이 레코드의 생리주기 범위 내에 있는지 확인
        if (daysSinceStart >= 0 && daysSinceStart < record.cycleLength) {
          return record;
        }
      }
      
      // 해당 날짜에 맞는 레코드가 없으면 최신 레코드 반환
      return records.isNotEmpty ? records.first : null;
    } catch (e) {
      print('레코드 조회 중 오류: $e');
      return _currentRecord;
    }
  }

  // 생리주기 완료 시 자동으로 다음 생리주기 생성
  Future<void> _checkAndCreateNextCycle() async {
    if (_currentRecord == null) return;
    
    final daysSinceLastPeriod = selectedDate.difference(_currentRecord!.lastPeriodStart).inDays;
    final cycleDay = (daysSinceLastPeriod % _currentRecord!.cycleLength) + 1;
    
    // 현재 생리주기가 완료되었는지 확인 (생리주기 길이를 초과)
    if (daysSinceLastPeriod >= _currentRecord!.cycleLength) {
      // 다음 생리주기 시작일 계산
      final nextPeriodStart = _currentRecord!.lastPeriodStart.add(Duration(days: _currentRecord!.cycleLength));
      
      // 현재 날짜가 다음 생리주기 시작일 이후인지 확인
      if (selectedDate.isAfter(nextPeriodStart) || selectedDate.isAtSameMomentAs(nextPeriodStart)) {
        try {
          final user = await AuthService.getUser();
          if (user == null) return;
          
          // 새로운 생리주기 레코드 생성
          final newRecord = MenstrualCycleRecord(
            mbId: user.id,
            lastPeriodStart: nextPeriodStart,
            cycleLength: _currentRecord!.cycleLength,
            periodLength: _currentRecord!.periodLength,
          );
          
          // 새로운 레코드 저장
          final success = await MenstrualCycleRepository.addMenstrualCycleRecord(newRecord);
          
          if (success) {
            // 데이터 새로고침
            _loadMenstrualCycleData();
          }
        } catch (e) {
          print('다음 생리주기 생성 중 오류: $e');
        }
      }
    }
  }

  // 생리주기 단계별 색상 반환
  List<Color> _getPhaseColors() {
    return [
      // 월경기 (1~5일) - 빨간색 계열
      Colors.red[300]!,
      Colors.red[400]!,
      Colors.red[500]!,
      Colors.red[600]!,
      Colors.red[700]!,
      
      // 난포기 (6~14일) - 주황색 계열
      Colors.orange[300]!,
      Colors.orange[400]!,
      Colors.orange[500]!,
      Colors.orange[600]!,
      Colors.orange[700]!,
      Colors.orange[800]!,
      Colors.orange[900]!,
      Colors.deepOrange[300]!,
      Colors.deepOrange[400]!,
      
      // 배란기 (15~17일) - 노란색 계열
      Colors.yellow[400]!,
      Colors.yellow[500]!,
      Colors.yellow[600]!,
      
      // 황체기 (18~28일) - 분홍색 계열
      Colors.pink[300]!,
      Colors.pink[400]!,
      Colors.pink[500]!,
      Colors.pink[600]!,
      Colors.pink[700]!,
      Colors.pink[800]!,
      Colors.pink[900]!,
      Colors.purple[300]!,
      Colors.purple[400]!,
      Colors.purple[500]!,
      
      // 다음 주기 준비 (29~31일) - 회색 계열
      Colors.grey[400]!,
      Colors.grey[500]!,
      Colors.grey[600]!,
    ];
  }

  // 생리주기 단계별 구간 반환 (31일 기준)
  List<double> _getPhaseStops() {
    return [
      0.0,    // 시작
      0.16,   // 월경기 끝 (5/31)
      0.45,   // 난포기 끝 (14/31)
      0.55,   // 배란기 끝 (17/31)
      0.90,   // 황체기 끝 (28/31)
      1.0,    // 끝
    ];
  }

  // 현재 단계의 색상 반환
  Color _getCurrentPhaseColor() {
    final daysSinceLastPeriod = selectedDate.difference(_currentRecord!.lastPeriodStart).inDays;
    final cycleDay = (daysSinceLastPeriod % _currentRecord!.cycleLength) + 1;
    
    if (cycleDay <= 5) {
      // 월경기 (1~5일) - 빨간색
      return Colors.red[500]!;
    } else if (cycleDay <= 14) {
      // 난포기 (6~14일) - 주황색
      return Colors.orange[500]!;
    } else if (cycleDay <= 17) {
      // 배란기 (15~17일) - 노란색
      return Colors.yellow[500]!;
    } else if (cycleDay <= 28) {
      // 황체기 (18~28일) - 분홍색
      return Colors.pink[500]!;
    } else {
      // 다음 주기 준비 (29일~) - 회색
      return Colors.grey[500]!;
    }
  }
}

// 생리주기 사분면별 진행을 그리는 CustomPainter
class MenstrualCyclePainter extends CustomPainter {
  final double progress;
  final int cycleDay;
  final int periodLength;

  MenstrualCyclePainter({
    required this.progress,
    required this.cycleDay,
    required this.periodLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 각 사분면별 색상과 일수 정의 (순서대로)
    final phases = [
      // 1사분면 (0도~90도) - 난포기 (6~14일) - 연핑크색
      PhaseInfo(
        startAngle: -90.0, // 0도 위치를 오른쪽으로 설정
        endAngle: 0.0,
        color: Colors.pink[300]!,
        startDay: 6,
        endDay: 14,
      ),
      // 4사분면 (270도~360도) - 배란기 (15~17일) - 연핑크색
      PhaseInfo(
        startAngle: 0.0,
        endAngle: 90.0,
        color: Colors.pink[300]!,
        startDay: 15,
        endDay: 17,
      ),
      // 3사분면 (180도~270도) - 황체기 (18~28일) - 연핑크색
      PhaseInfo(
        startAngle: 90.0,
        endAngle: 180.0,
        color: Colors.pink[300]!,
        startDay: 18,
        endDay: 28,
      ),
      // 2사분면 (90도~180도) - 월경기 (1~5일) - 연핑크색
      PhaseInfo(
        startAngle: 180.0,
        endAngle: 270.0,
        color: Colors.pink[300]!,
        startDay: 1,
        endDay: 5,
      ),
    ];

    // 각 사분면을 그리기
    for (final phase in phases) {
      _drawPhase(canvas, center, radius, phase);
    }
  }

  void _drawPhase(Canvas canvas, Offset center, double radius, PhaseInfo phase) {
    final paint = Paint()
      ..color = phase.color
      ..style = PaintingStyle.fill;

    // 월경기인 경우
    if (phase.startDay == 1) {
      if (cycleDay >= 1 && cycleDay <= periodLength) {
        // 월경 기간 중: 점진적으로 채우기
        final daysInPeriod = cycleDay;
        final phaseProgress = daysInPeriod / periodLength;
        final sweepAngle = (phase.endAngle - phase.startAngle) * phaseProgress;
        
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          phase.startAngle * (3.14159 / 180),
          sweepAngle * (3.14159 / 180),
          true,
          paint,
        );
      }
    } else {
      // 다른 단계들: 월경 중일 때는 이전 주기의 단계들로 간주하여 모두 채우기
      if (cycleDay >= 1 && cycleDay <= periodLength) {
        // 월경 중: 이전 주기의 단계들은 모두 채워진 상태
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          phase.startAngle * (3.14159 / 180),
          (phase.endAngle - phase.startAngle) * (3.14159 / 180),
          true,
          paint,
        );
      } else if (cycleDay > periodLength) {
        // 월경이 끝난 후: 해당 단계가 지나갔다면 전체 채우기
        if (cycleDay >= phase.startDay && cycleDay <= phase.endDay) {
          // 현재 단계: 점진적으로 채우기
          final daysInPhase = cycleDay - phase.startDay + 1;
          final totalDaysInPhase = phase.endDay - phase.startDay + 1;
          final phaseProgress = daysInPhase / totalDaysInPhase;
          final sweepAngle = (phase.endAngle - phase.startAngle) * phaseProgress;
          
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            phase.startAngle * (3.14159 / 180),
            sweepAngle * (3.14159 / 180),
            true,
            paint,
          );
        } else if (cycleDay > phase.endDay) {
          // 이미 지나간 단계: 전체 채우기
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            phase.startAngle * (3.14159 / 180),
            (phase.endAngle - phase.startAngle) * (3.14159 / 180),
            true,
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is MenstrualCyclePainter &&
        (oldDelegate.progress != progress || 
         oldDelegate.cycleDay != cycleDay ||
         oldDelegate.periodLength != periodLength);
  }
}

// 생리주기 단계 정보 클래스
class PhaseInfo {
  final double startAngle;
  final double endAngle;
  final Color color;
  final int startDay;
  final int endDay;

  PhaseInfo({
    required this.startAngle,
    required this.endAngle,
    required this.color,
    required this.startDay,
    required this.endDay,
  });
}