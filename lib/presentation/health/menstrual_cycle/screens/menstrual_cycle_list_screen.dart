import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../../common/widgets/btn_record.dart';
import '../widgets/menstrual_cycle_date_header.dart';
import '../../../../data/models/health/menstrual_cycle/menstrual_cycle_model.dart';
import '../../../../data/repositories/health/menstrual_cycle/menstrual_cycle_repository.dart';
import '../../../../data/services/auth_service.dart';
import 'menstrual_cycle_input_screen.dart';

/// 배란일이 오늘일 때 링 위 날짜 마커만 채우는 색
const Color _kOvulationTodayMarkerFill = Color(0xFFFEA38E);

class MenstrualCycleInfoScreen extends StatefulWidget {
  const MenstrualCycleInfoScreen({super.key});

  @override
  State<MenstrualCycleInfoScreen> createState() =>
      _MenstrualCycleInfoScreenState();
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

      final record =
          await MenstrualCycleRepository.getLatestMenstrualCycleRecord(user.id);
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
      backgroundColor: Colors.white,
      appBar: const HealthAppBar(title: '생리주기'),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20), // 좌우 20px 패딩
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 현재 상태 섹션
                      _buildCurrentStatusSection(),
                      const SizedBox(height: 0),

                      // 생리주기 원형 차트
                      _buildCycleChart(),
                      const SizedBox(height: 10),
                      _buildPhaseLegend(),
                      const SizedBox(height: 20),

                      // 현재 단계별 추천사항
                      _buildPhaseRecommendations(),
                      const SizedBox(height: 30),

                      // 생리기간/가임기/배란일 카드
                      _buildExpectedDatesSection(),
                      const SizedBox(height: 30),

                      // 기록하기 버튼
                      BtnRecord(
                        text: '+ 기록하기',
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const MenstrualCycleInputScreen(),
                            ),
                          );
                          if (result == true) {
                            _loadMenstrualCycleData();
                          }
                        },
                      ),
                      const SizedBox(height: 30),
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
          MenstrualCycleDateHeader(
            selectedDate: selectedDate,
            onDateChanged: (d) => setState(() => selectedDate = d),
          ),
          const SizedBox(height: 16),
        ],
      ),
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

    final cycleLength = _currentRecord!.cycleLength;

    // 생리주기 완료 시 자동으로 다음 생리주기 생성
    _checkAndCreateNextCycle();

    final elapsedDays =
        selectedDate.difference(_currentRecord!.lastPeriodStart).inDays + 1;
    final boundedElapsedDays = elapsedDays.clamp(0, cycleLength);
    final daySweep = (3.141592653589793 * 2) / cycleLength;
    final markerAngle = -3.141592653589793 / 2 - (daySweep * boundedElapsedDays);
    const chartSize = 260.0;
    final innerSize = chartSize * (156 / 200);
    final chartScale = chartSize / MenstrualCyclePainter.kDesignChartDiameter;
    final scaledRingStroke =
        MenstrualCyclePainter.kDesignRingStroke * chartScale;
    final scaledArcInset =
        MenstrualCyclePainter.kDesignArcInset * chartScale;
    // 날짜 마커 크기 (링 두께에 맞춤)
    final markerDotSize = scaledRingStroke + 8.0 * chartScale;
    final center = chartSize / 2;
    // Painter arc 중심선 반지름과 동일하게 맞춰 끝점 정렬
    final markerRadius = (chartSize / 2 - scaledArcInset);
    final markerX = center + markerRadius * cos(markerAngle);
    final markerY = center + markerRadius * sin(markerAngle);
    final todayLabel = DateFormat('M/d').format(selectedDate);

    final now = DateTime.now();
    final ovulation = _currentRecord!.ovulationDate;
    final fillTodayMarkerWithOvulationColor = DateUtils.isSameDay(now, ovulation) &&
        DateUtils.isSameDay(selectedDate, now);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 원형 차트
          Center(
            child: SizedBox(
              width: chartSize,
              height: chartSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 원 기본색은 흰색
                  Container(
                    width: chartSize,
                    height: chartSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        width: 0.5,
                        color: const Color(0x7FD9D9D9),
                      ),
                    ),
                  ),
                  // 날짜 경과 채움 (반시계 방향)
                  CustomPaint(
                    size: Size(chartSize, chartSize),
                    painter: MenstrualCyclePainter(
                      layoutDiameter: chartSize,
                      cycleLength: cycleLength,
                      elapsedDays: boundedElapsedDays,
                      cycleStartDate: _currentRecord!.lastPeriodStart,
                      periodLength: _currentRecord!.periodLength,
                      fertileWindowStart: _currentRecord!.fertileWindowStart,
                      fertileWindowEnd: _currentRecord!.fertileWindowEnd,
                      ovulationDate: _currentRecord!.ovulationDate,
                    ),
                  ),
                  // 내부 원
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        // 선택한 날짜에 맞는 레코드 찾기
                        final recordForDate =
                            await _getRecordForDate(selectedDate);
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
                        width: innerSize,
                        height: innerSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFFB3B3B3),
                            width: 0.2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '생리 예정일',
                              style: TextStyle(
                                fontSize: 18,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w300,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              DateFormat('MM.dd')
                                  .format(_currentRecord!.nextPeriodStart),
                              style: const TextStyle(
                                fontSize: 36,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: markerX - (markerDotSize / 2),
                    top: markerY - (markerDotSize / 2),
                    child: Container(
                      width: markerDotSize,
                      height: markerDotSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: fillTodayMarkerWithOvulationColor
                            ? _kOvulationTodayMarkerFill
                            : Colors.white,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 4,
                            offset: Offset(0, 1.5),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Text(
                        todayLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: fillTodayMarkerWithOvulationColor
                              ? Colors.white
                              : const Color(0xFF1A1A1A),
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
            '${phaseInfo.name}',
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

  Widget _buildPhaseLegend() {
    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: const [
          _PhaseLegendItem(color: Color(0xFFFFDFC3), label: '가임기',isCircle: true ),
          SizedBox(width: 10),
          _PhaseLegendItem(color: Color(0xFFFEA38E), label: '배란기', isCircle: true),
          SizedBox(width: 10),
          _PhaseLegendItem(color: Color(0xFFFF5A8D), label: '생리기간', isCircle: true),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(
      String category, String content, IconData icon, Color color) {
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
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateRangeCard(
            title: '예상 가임기',
            date:
                '${DateFormat('M월 d일').format(_currentRecord!.fertileWindowStart)} - ${DateFormat('M월 d일').format(_currentRecord!.fertileWindowEnd)}',
            color: const Color(0xFFFFDFC3),
          ),
          const SizedBox(height: 10),
          _buildDateRangeCard(
            title: '예상 배란일',
            date: _ovulationRangeText(),
            color: const Color(0xFFFEA38E),
          ),
          const SizedBox(height: 10),
           _buildDateRangeCard(
            title: '생리기간',
            date:
                '${DateFormat('M월 d일').format(_currentRecord!.nextPeriodStart)} - ${DateFormat('M월 d일').format(_currentRecord!.nextPeriodEnd)}',
            color: const Color(0xFFFF5A8D),
          ),
        ],
      ),
    );
  }

  String _ovulationRangeText() {
    return DateFormat('M월 d일').format(_currentRecord!.ovulationDate);
  }

  Widget _buildDateRangeCard({
    required String title,
    required String date,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: const Color(0xFFF9F9F9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 107,
            height: 40,
            color: color,
            alignment: Alignment.center,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                date,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 선택한 날짜에 맞는 레코드 찾기
  Future<MenstrualCycleRecord?> _getRecordForDate(DateTime selectedDate) async {
    try {
      final user = await AuthService.getUser();
      if (user == null) return null;

      // 모든 생리주기 레코드 가져오기
      final records =
          await MenstrualCycleRepository.getMenstrualCycleRecords(user.id);

      // 선택한 날짜에 해당하는 레코드 찾기
      for (final record in records) {
        final daysSinceStart =
            selectedDate.difference(record.lastPeriodStart).inDays;

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

    final daysSinceLastPeriod =
        selectedDate.difference(_currentRecord!.lastPeriodStart).inDays;
    final cycleDay = (daysSinceLastPeriod % _currentRecord!.cycleLength) + 1;

    // 현재 생리주기가 완료되었는지 확인 (생리주기 길이를 초과)
    if (daysSinceLastPeriod >= _currentRecord!.cycleLength) {
      // 다음 생리주기 시작일 계산
      final nextPeriodStart = _currentRecord!.lastPeriodStart
          .add(Duration(days: _currentRecord!.cycleLength));

      // 현재 날짜가 다음 생리주기 시작일 이후인지 확인
      if (selectedDate.isAfter(nextPeriodStart) ||
          selectedDate.isAtSameMomentAs(nextPeriodStart)) {
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
          final success =
              await MenstrualCycleRepository.addMenstrualCycleRecord(newRecord);

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
}

// 생리주기 사분면별 진행을 그리는 CustomPainter
class MenstrualCyclePainter extends CustomPainter {
  /// 200×200 기준 레이아웃(링 두께·인셋 스케일 기준)
  static const double kDesignChartDiameter = 200.0;
  static const double kDesignArcInset = 11.0;
  static const double kDesignRingStroke = 20.0;
  static const double kDesignPhaseMarkerStroke = 1.4;

  final double layoutDiameter;
  final int cycleLength;
  final int elapsedDays;
  final DateTime cycleStartDate;
  final int periodLength;
  final DateTime fertileWindowStart;
  final DateTime fertileWindowEnd;
  final DateTime ovulationDate;

  MenstrualCyclePainter({
    required this.layoutDiameter,
    required this.cycleLength,
    required this.elapsedDays,
    required this.cycleStartDate,
    required this.periodLength,
    required this.fertileWindowStart,
    required this.fertileWindowEnd,
    required this.ovulationDate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / kDesignChartDiameter;
    final arcInset = kDesignArcInset * scale;
    final ringStrokeWidth = kDesignRingStroke * scale;
    final phaseMarkerStroke = kDesignPhaseMarkerStroke * scale;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - arcInset;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (cycleLength <= 0 || elapsedDays <= 0) return;

    final daySweep = (3.141592653589793 * 2) / cycleLength;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringStrokeWidth // 회색 바깥원 안쪽에 맞는 두께
      // 일수 길이를 정확히 맞추기 위해 캡 확장을 제거
      ..strokeCap = StrokeCap.butt;

    // 우선순위: 배란기 > 가임기 > 생리기간 > 회색
    // 따라서 그리기 순서는 회색 -> 생리기간 -> 가임기 -> 배란기
    _drawSegments(
      canvas: canvas,
      rect: rect,
      daySweep: daySweep,
      paint: stroke,
      color: const Color(0xFFECECEC),
      shouldPaintDay: (_) => true,
    );

    _drawSegments(
      canvas: canvas,
      rect: rect,
      daySweep: daySweep,
      paint: stroke,
      color: const Color(0xFFFF5A8D),
      roundEndCap: true,
      shouldPaintDay: (dayDate) {
        final dayIndex = dayDate.difference(cycleStartDate).inDays + 1;
        return dayIndex >= 1 && dayIndex <= periodLength;
      },
    );

    _drawSegments(
      canvas: canvas,
      rect: rect,
      daySweep: daySweep,
      paint: stroke,
      color: const Color(0xFFFFDFC3),
      shouldPaintDay: (dayDate) =>
          !_isBeforeDate(dayDate, fertileWindowStart) &&
          !_isAfterDate(dayDate, fertileWindowEnd),
    );

    // 배란일은 1일만 표시
    final ovulationStart = ovulationDate;
    final ovulationEnd = ovulationDate;
    final ovulationStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringStrokeWidth
      ..strokeCap = StrokeCap.round;
    _drawSegments(
      canvas: canvas,
      rect: rect,
      daySweep: daySweep,
      paint: ovulationStroke,
      color: const Color(0xFFFEA38E),
      // 원형차드 배란기 표시 넓이 조절
      trimSweepEachSide: daySweep * 0.45,
      shouldPaintDay: (dayDate) =>
          !_isBeforeDate(dayDate, ovulationStart) &&
          !_isAfterDate(dayDate, ovulationEnd),
    );

    // 가임기 시작일 위치 표시선
    _drawPhaseMarker(
      canvas: canvas,
      center: center,
      radius: radius,
      daySweep: daySweep,
      ringStrokeWidth: ringStrokeWidth,
      phaseMarkerStroke: phaseMarkerStroke,
      markerDate: fertileWindowStart,
      roundEnd: false,
    );

    // 가임기 종료 경계(종료일 다음날 시작점) 표시선
    _drawPhaseMarker(
      canvas: canvas,
      center: center,
      radius: radius,
      daySweep: daySweep,
      ringStrokeWidth: ringStrokeWidth,
      phaseMarkerStroke: phaseMarkerStroke,
      markerDate: fertileWindowEnd.add(const Duration(days: 1)),
      roundEnd: false,
    );

  }

  void _drawPhaseMarker({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double daySweep,
    required double ringStrokeWidth,
    required double phaseMarkerStroke,
    required DateTime markerDate,
    bool roundEnd = false,
  }) {
    final normalizedStart = DateTime(
      cycleStartDate.year,
      cycleStartDate.month,
      cycleStartDate.day,
    );
    final normalizedMarker = DateTime(
      markerDate.year,
      markerDate.month,
      markerDate.day,
    );
    final markerIndex = normalizedMarker.difference(normalizedStart).inDays;
    if (markerIndex < 0 || markerIndex >= cycleLength) return;

    final markerAngle = -3.141592653589793 / 2 - (daySweep * markerIndex);

    final outerR = radius + (ringStrokeWidth / 2) - 0.5;
    final innerR = radius - (ringStrokeWidth / 2) + 2.0;
    final start = Offset(
      center.dx + outerR * cos(markerAngle),
      center.dy + outerR * sin(markerAngle),
    );
    final end = Offset(
      center.dx + innerR * cos(markerAngle),
      center.dy + innerR * sin(markerAngle),
    );

    final markerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF303030)
      ..strokeWidth = phaseMarkerStroke
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = false;
    canvas.drawLine(start, end, markerPaint);

    if (roundEnd) {
      final capPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF303030)
        ..isAntiAlias = true;
      canvas.drawCircle(end, markerPaint.strokeWidth / 2, capPaint);
    }
  }

  void _drawSegments({
    required Canvas canvas,
    required Rect rect,
    required double daySweep,
    required Paint paint,
    required Color color,
    required bool Function(DateTime dayDate) shouldPaintDay,
    double trimSweepEachSide = 0.0,
    /// 생리기간 등: 호 끝만 둥글게(선 마커 없음). 시작은 butt 유지.
    bool roundEndCap = false,
  }) {
    int? segmentStart;

    for (int i = 0; i < elapsedDays; i++) {
      final dayDate = DateTime(
        cycleStartDate.year,
        cycleStartDate.month,
        cycleStartDate.day + i,
      );
      final matched = shouldPaintDay(dayDate);

      if (matched && segmentStart == null) {
        segmentStart = i;
      }

      final isLast = i == elapsedDays - 1;
      if ((!matched || isLast) && segmentStart != null) {
        final endIndex = (matched && isLast) ? i : i - 1;
        final segmentLength = endIndex - segmentStart + 1;
        if (segmentLength > 0) {
          paint.color = color;
          final rawSweep = daySweep * segmentLength;
          final canTrim = trimSweepEachSide > 0 &&
              rawSweep > (trimSweepEachSide * 2 + 0.0001);
          final startAngle = -3.141592653589793 / 2 -
              (daySweep * segmentStart) -
              (canTrim ? trimSweepEachSide : 0.0);
          final sweep = -(rawSweep - (canTrim ? trimSweepEachSide * 2 : 0.0));
          canvas.drawArc(
            rect,
            startAngle,
            sweep,
            false,
            paint,
          );
          if (roundEndCap) {
            final ringRadius = rect.width / 2;
            final endAngle = startAngle + sweep;
            final capCenter = Offset(
              rect.center.dx + ringRadius * cos(endAngle),
              rect.center.dy + ringRadius * sin(endAngle),
            );
            final capPaint = Paint()
              ..style = PaintingStyle.fill
              ..color = color
              ..isAntiAlias = true;
            canvas.drawCircle(capCenter, paint.strokeWidth / 2, capPaint);
          }
        }
        segmentStart = null;
      }
    }
  }

  bool _isBeforeDate(DateTime a, DateTime b) {
    final aa = DateTime(a.year, a.month, a.day);
    final bb = DateTime(b.year, b.month, b.day);
    return aa.isBefore(bb);
  }

  bool _isAfterDate(DateTime a, DateTime b) {
    final aa = DateTime(a.year, a.month, a.day);
    final bb = DateTime(b.year, b.month, b.day);
    return aa.isAfter(bb);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is MenstrualCyclePainter &&
        (oldDelegate.layoutDiameter != layoutDiameter ||
            oldDelegate.cycleLength != cycleLength ||
            oldDelegate.elapsedDays != elapsedDays ||
            oldDelegate.periodLength != periodLength ||
            oldDelegate.cycleStartDate != cycleStartDate ||
            oldDelegate.fertileWindowStart != fertileWindowStart ||
            oldDelegate.fertileWindowEnd != fertileWindowEnd ||
            oldDelegate.ovulationDate != ovulationDate);
  }
}

class _PhaseLegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isCircle;

  const _PhaseLegendItem({
    required this.color,
    required this.label,
    this.isCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16.23,
          height: 16.23,
          decoration: ShapeDecoration(
            color: color,
            shape: isCircle
                ? const OvalBorder()
                : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3),
                  ),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 8,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}
