import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_assets.dart';

import '../../../../data/models/health/blood_pressure/blood_pressure_record_model.dart';
import '../../../../data/models/health/blood_sugar/blood_sugar_record_model.dart';
import '../../../../data/models/health/health_goal_record_model.dart';
import '../../../../data/models/health/heart_rate/heart_rate_record_model.dart';
import '../../../../data/models/health/menstrual_cycle/menstrual_cycle_model.dart';
import '../../../../data/models/health/steps/steps_record_model.dart';
import '../../../common/widgets/login_required_dialog.dart';
import '../../blood_pressure/screens/blood_pressure_list_screen.dart';
import '../../blood_sugar/screens/blood_sugar_list_screen.dart';
import '../../health_common/health_responsive_scale.dart';
import '../../health_common/widgets/health_status_label.dart';
import '../../heart_rate/screens/heart_rate_list_screen.dart';
import '../../menstrual_cycle/screens/menstrual_cycle_list_screen.dart';
import '../../steps/screens/steps_list_screen.dart';

/// 건강 대시보드 — 「오늘의 건강기록」 블록(혈당·혈압·걸음·심박·생리).
class TodayHealthRecordSection extends StatelessWidget {
  const TodayHealthRecordSection({
    super.key,
    required this.isLoggedIn,
    required this.selectedDate,
    required this.latestBloodSugarRecord,
    required this.latestBloodPressureRecord,
    required this.latestStepsRecord,
    required this.latestHeartRateRecord,
    required this.latestMenstrualCycleRecord,
    required this.latestHealthGoal,
    required this.systolicBP,
    required this.diastolicBP,
    required this.steps,
    required this.heartRate,
  });

  final bool isLoggedIn;
  final DateTime selectedDate;
  final BloodSugarRecord? latestBloodSugarRecord;
  final BloodPressureRecord? latestBloodPressureRecord;
  final StepsRecord? latestStepsRecord;
  final HeartRateRecord? latestHeartRateRecord;
  final MenstrualCycleRecord? latestMenstrualCycleRecord;
  final HealthGoalRecordModel? latestHealthGoal;
  final int systolicBP;
  final int diastolicBP;
  final int steps;
  final int heartRate;

  @override
  Widget build(BuildContext context) {
    final double stepsPad = healthDp(context, 10);
    final double stepsRing = healthDp(context, 65.6);
    // 카드 내부 좌우 패딩 + 링(375 기준 65.6) 이상이어야 링이 FittedBox에 축소되지 않음
    final double stepsColumnWidth =
        math.max(healthDp(context, 65.6), 2 * stepsPad + stepsRing);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: healthDp(context, 2),
                height: healthDp(context, 22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(healthDp(context, 1)),
                  ),
                ),
              ),
              SizedBox(width: healthDp(context, 8)),
              RichText(
                textScaler: TextScaler.noScaling,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: healthSp(context, 16),
                    color: const Color(0xFF1A1A1A),
                    height: 1.13,
                  ),
                  children: const [
                    TextSpan(
                      text: '오늘의 ',
                      style: TextStyle(
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    TextSpan(
                      text: '건강기록',
                      style: TextStyle(
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: healthDp(context, 14)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildRecordCard(
                            context,
                            title: '혈당',
                            value: latestBloodSugarRecord != null
                                ? '${BloodSugarRecord.getMeasurementTypeKorean(latestBloodSugarRecord!.measurementType)}\n'
                                    '${latestBloodSugarRecord!.bloodSugar.toStringAsFixed(1)} mg/dL'
                                : '입력하세요.',
                            subtitle: '',
                            statusText: _bloodSugarStatusLabel(
                              latestBloodSugarRecord,
                            ),
                            iconAsset: AppAssets.mainCardIconBloodSugar,
                            compact: true,
                            compactAfterHeaderGap: healthDp(context, 5),
                            titleFontSize: 14,
                            valueFontSize: 12,
                            statusFontSize: 10,
                            onMore: () {
                              if (!isLoggedIn) {
                                showLoginRequiredDialog(
                                  context,
                                  message: '건강 대시보드 입력은 로그인 후 이용할 수 있습니다.',
                                );
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BloodSugarListScreen(
                                    initialDate: selectedDate,
                                  ),
                                ),
                              );
                            },
                          ),
                          SizedBox(height: healthDp(context, 5)),
                          _buildRecordCard(
                            context,
                            title: '혈압',
                            value: latestBloodPressureRecord != null
                                ? '수축기 $systolicBP mmHg\n이완기 $diastolicBP mmHg'
                                : '입력하세요.\n입력하세요.',
                            subtitle: '',
                            statusText: _bloodPressureStatusLabel(
                              latestBloodPressureRecord,
                              systolicBP,
                              diastolicBP,
                            ),
                            iconAsset: AppAssets.mainCardIconBloodPressure,
                            compact: true,
                            compactAfterHeaderGap: healthDp(context, 10.53),
                            titleFontSize: 14,
                            valueFontSize: 12,
                            statusFontSize: 10,
                            onMore: () {
                              if (!isLoggedIn) {
                                showLoginRequiredDialog(
                                  context,
                                  message: '건강 대시보드 입력은 로그인 후 이용할 수 있습니다.',
                                );
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BloodPressureListScreen(
                                    initialDate: selectedDate,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: healthDp(context, 5)),
                    SizedBox(
                      width: stepsColumnWidth,
                      child: _buildStepsCard(
                        context,
                        dashboardLayout: true,
                        isLoggedIn: isLoggedIn,
                        selectedDate: selectedDate,
                        latestStepsRecord: latestStepsRecord,
                        latestHealthGoal: latestHealthGoal,
                        steps: steps,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: healthDp(context, 5)),
              SizedBox(
                height: healthDp(context, 64.53),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildBottomRecordCard(
                        context,
                        title: '심박수',
                        titleIconAsset: AppAssets.mainCardIconHeartRate,
                        value: latestHeartRateRecord != null ? null : '입력하세요.',
                        valueWidget: latestHeartRateRecord != null
                            ? Text(
                                '$heartRate bpm',
                                textScaler: TextScaler.noScaling,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: TextStyle(
                                  color: const Color(0xFF8C8888),
                                  fontSize: healthSp(context, 12),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: -1.08,
                                ),
                              )
                            : null,
                        titleFontSize: 14,
                        valueFontSize: 12,
                        dashboardStyle: true,
                        onMore: () {
                          if (!isLoggedIn) {
                            showLoginRequiredDialog(
                              context,
                              message: '건강 대시보드 입력은 로그인 후 이용할 수 있습니다.',
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HeartRateListScreen(
                                initialDate: selectedDate,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(width: healthDp(context, 5)),
                    Expanded(
                      child: _buildBottomRecordCard(
                        context,
                        title: '생리주기',
                        titleIconAsset: AppAssets.mainCardIconMenstrual,
                        valueWidget: Text(
                          _periodText(
                            latestMenstrualCycleRecord,
                            selectedDate,
                          ),
                          textScaler: TextScaler.noScaling,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: TextStyle(
                            color: const Color(0xFF8C8888),
                            fontSize: healthSp(context, 12),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w300,
                            letterSpacing: -1.08,
                          ),
                        ),
                        titleFontSize: 14,
                        valueFontSize: 12,
                        dashboardStyle: true,
                        onMore: () {
                          if (!isLoggedIn) {
                            showLoginRequiredDialog(
                              context,
                              message: '건강 대시보드 입력은 로그인 후 이용할 수 있습니다.',
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MenstrualCycleInfoScreen(
                                initialDate: selectedDate,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _periodText(
  MenstrualCycleRecord? latestMenstrualCycleRecord,
  DateTime selectedDate,
) {
  if (latestMenstrualCycleRecord == null) {
    return '입력하세요.';
  }

  final int dday = latestMenstrualCycleRecord.nextPeriodStart
      .difference(selectedDate)
      .inDays;
  final DateTime lastPeriodEnd = latestMenstrualCycleRecord.lastPeriodStart
      .add(Duration(days: latestMenstrualCycleRecord.periodLength - 1));
  final String cycleRange =
      '${DateFormat('M/d').format(latestMenstrualCycleRecord.lastPeriodStart)}-${DateFormat('M/d').format(lastPeriodEnd)}';

  return '${dday.abs()}일전($cycleRange)';
}

String _bloodPressureStatusLabel(
  BloodPressureRecord? latestBloodPressureRecord,
  int systolicBP,
  int diastolicBP,
) {
  if (latestBloodPressureRecord == null) return '모름';
  if (systolicBP >= 140 || diastolicBP >= 90) return '고혈압';
  if (systolicBP < 90 || diastolicBP < 60) return '전단계';
  return '정상';
}

String _bloodSugarStatusLabel(BloodSugarRecord? latestBloodSugarRecord) {
  if (latestBloodSugarRecord == null) return '모름';
  final int sugar = latestBloodSugarRecord.bloodSugar;
  if (sugar < 70) return '주의';
  if (sugar <= 140) return '정상';
  return '의심';
}

Widget _buildMainCardIcon(BuildContext context, String assetPath) {
  final box = healthDp(context, 28);
  final icon = healthDp(context, 18);
  return Container(
    width: box,
    height: box,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(healthDp(context, 15)),
      border: Border.all(
        color: const Color(0x7FD2D2D2),
        width: 0.5,
      ),
    ),
    child: Center(
      child: SvgPicture.asset(
        assetPath,
        width: icon,
        height: icon,
        fit: BoxFit.contain,
      ),
    ),
  );
}

Widget _buildRecordCard(
  BuildContext context, {
  required String title,
  required String value,
  required String subtitle,
  required String statusText,
  required String iconAsset,
  required VoidCallback onMore,
  bool compact = false,
  double? compactAfterHeaderGap,
  double titleFontSize = 14,
  double valueFontSize = 12,
  double? subtitleFontSize,
  double statusFontSize = 10,
}) {
  if (compact) {
    final double gap = compactAfterHeaderGap ?? healthDp(context, 5);
    return GestureDetector(
      onTap: onMore,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 10),
          vertical: healthDp(context, 5),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
          border: Border.all(
            color: const Color(0x7FD2D2D2),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildMainCardIcon(context, iconAsset),
                SizedBox(width: healthDp(context, 5)),
                Text(
                  title,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: 'Gmarket Sans TTF',
                    fontSize: healthSp(context, 14),
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            SizedBox(height: gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    value,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: const Color(0xFF8C8888),
                      fontSize: healthSp(context, 12),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                      letterSpacing: -1.08,
                      height: 1.2,
                    ),
                  ),
                ),
                HealthStatusLabel(
                  label: statusText,
                  fontSize: healthSp(context, 10),
                  chipBorderRadius: healthDp(context, 16),
                  chipPadding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 8),
                    vertical: healthDp(context, 4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  final pad = 14.0;
  final iconBox = 30.0;
  final iconSz = 18.0;
  const afterHeader = 10.0;
  final subtitleFs = subtitleFontSize ?? 12.0;

  return GestureDetector(
    onTap: onMore,
    child: Container(
      width: double.infinity,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: iconBox,
                height: iconBox,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: SvgPicture.asset(
                  iconAsset,
                  width: iconSz,
                  height: iconSz,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Gmarket Sans TTF',
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: afterHeader),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: TextStyle(
                color: const Color(0xFF8C8888),
                fontSize: subtitleFs,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
                letterSpacing: -1.08,
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: const Color(0xFF6B7280),
                    fontSize: valueFontSize,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                    height: 1.2,
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, 2),
                child: HealthStatusLabel(
                  label: statusText,
                  fontSize: statusFontSize,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildStepsCard(
  BuildContext context, {
  required bool dashboardLayout,
  required bool isLoggedIn,
  required DateTime selectedDate,
  required StepsRecord? latestStepsRecord,
  required HealthGoalRecordModel? latestHealthGoal,
  required int steps,
}) {
  final double pad =
      dashboardLayout ? healthDp(context, 10) : healthDp(context, 10);
  final double ringSize =
      dashboardLayout ? healthDp(context, 65.6) : healthDp(context, 72);
  final double strokeW =
      dashboardLayout ? healthDp(context, 5) : healthDp(context, 7);
  final Color trackCol =
      dashboardLayout ? const Color(0x7FD9D9D9) : const Color(0xFFF3F4F6);
  final double titleSz =
      dashboardLayout ? healthSp(context, 14) : healthSp(context, 15);

  if (latestStepsRecord == null) {
    return GestureDetector(
      onTap: () {
        if (!isLoggedIn) {
          showLoginRequiredDialog(
            context,
            message: '건강 대시보드 입력은 로그인 후 이용할 수 있습니다.',
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StepsTodayScreen(initialDate: selectedDate),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            dashboardLayout ? healthDp(context, 10) : 18,
          ),
          border: Border.all(
            color: dashboardLayout
                ? const Color(0xFFD9D9D9)
                : const Color(0xFFF0F0F0),
            width: dashboardLayout ? 0.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '걸음수',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: titleSz,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
            SizedBox(height: healthDp(context, 5)),
            Expanded(
              child: Center(
                child: Text(
                  '입력하세요.',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: const Color(0xFF8C8888),
                    fontSize: healthSp(context, 12),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  final int targetSteps = (latestHealthGoal?.dailyStepGoal != null &&
          latestHealthGoal!.dailyStepGoal! > 0)
      ? latestHealthGoal.dailyStepGoal!
      : 0;
  final double ratio =
      (targetSteps <= 0) ? 0.0 : (steps / targetSteps).clamp(0.0, 1.0);
  final fmt = NumberFormat('#,###');

  return GestureDetector(
    onTap: () {
      if (!isLoggedIn) {
        showLoginRequiredDialog(
          context,
          message: '건강 대시보드 입력은 로그인 후 이용할 수 있습니다.',
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StepsTodayScreen(initialDate: selectedDate),
        ),
      );
    },
    child: Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          dashboardLayout ? healthDp(context, 10) : healthDp(context, 18),
        ),
        border: Border.all(
          color: dashboardLayout
              ? const Color(0xFFD9D9D9)
              : const Color(0xFFF0F0F0),
          width: dashboardLayout ? 0.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.center,
            child: Text(
              '걸음수',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: healthSp(context, 14),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
          SizedBox(height: healthDp(context, 5)),
          Expanded(
            child: Center(
              child: SizedBox.square(
                dimension: ringSize,
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      painter: _StepsGoalRingPainter(
                        progress: ratio,
                        trackColor: trackCol,
                        progressColor: const Color(0xFFFF5A8D),
                        strokeWidth: strokeW,
                      ),
                    ),
                    Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              fmt.format(steps),
                              textAlign: TextAlign.center,
                              textScaler: TextScaler.noScaling,
                              style: TextStyle(
                                fontFamily: 'Gmarket Sans TTF',
                                fontSize: healthSp(context, 12),
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFFF5A8D),
                                height: 1.1,
                              ),
                            ),
                            Text(
                              targetSteps > 0
                                  ? '/${fmt.format(targetSteps)}'
                                  : '/-',
                              textAlign: TextAlign.center,
                              textScaler: TextScaler.noScaling,
                              style: TextStyle(
                                fontFamily: 'Gmarket Sans TTF',
                                fontSize: healthSp(context, 9),
                                fontWeight: FontWeight.w300,
                                color: const Color(0xB2FF5A8D),
                                height: 1.1,
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
        ],
      ),
    ),
  );
}

Widget _buildBottomRecordCard(
  BuildContext context, {
  required String title,
  String? value,
  Widget? valueWidget,
  required VoidCallback onMore,
  required String titleIconAsset,
  double titleFontSize = 16,
  double valueFontSize = 20,
  bool dashboardStyle = false,
}) {
  assert(value != null || valueWidget != null);
  if (dashboardStyle) {
    return GestureDetector(
      onTap: onMore,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 10),
          vertical: healthDp(context, 5),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
          border: Border.all(
            color: const Color(0x7FD2D2D2),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildMainCardIcon(context, titleIconAsset),
                SizedBox(width: healthDp(context, 5)),
                Text(
                  title,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            SizedBox(height: healthDp(context, 8.53)),
            Align(
              alignment: Alignment.centerLeft,
              child: valueWidget ??
                  Text(
                    value!,
                    textScaler: TextScaler.noScaling,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF8C8888),
                      fontSize: healthSp(context, 12),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                      letterSpacing: -1.08,
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  return GestureDetector(
    onTap: onMore,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SvgPicture.asset(
                titleIconAsset,
                width: 18,
                height: 18,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.53),
          Align(
            alignment: Alignment.centerLeft,
            child: valueWidget ??
                Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    color: const Color(0xFF9CA3AF),
                    fontSize: valueFontSize,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
          ),
        ],
      ),
    ),
  );
}

class _StepsGoalRingPainter extends CustomPainter {
  _StepsGoalRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, track);

    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;

    final sweep = -math.pi * 2 * p;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _StepsGoalRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
