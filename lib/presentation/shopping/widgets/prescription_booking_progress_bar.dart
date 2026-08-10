import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';

/// 처방 예약 플로우 단계 (문진표 → 날짜/시간 → 결제 → 결제 완료)
abstract final class PrescriptionBookingSteps {
  static const int questionnaire = 0;
  static const int dateTime = 1;
  static const int payment = 2;
  static const int complete = 3;
  static const int count = 4;
}

/// 앱바 하단 4단 프로그레스. [currentStep]까지는 완료, 현재 단계는 [stepProgress]만큼 핑크 채움.
class PrescriptionBookingProgressBar extends StatelessWidget {
  static const Color trackColor = Color(0xFFF6F6F6);
  static const Color fillColor = Color(0xFFFF5A8D);

  /// PreferredSize용 트랙 높이 (375 기준, 기존 2에서 살짝 키움).
  static const double preferredHeight = 4;

  final int currentStep;
  final double stepProgress;

  const PrescriptionBookingProgressBar({
    super.key,
    required this.currentStep,
    this.stepProgress = 0,
  });

  static PreferredSizeWidget asAppBarBottom({
    required int currentStep,
    double stepProgress = 0,
  }) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(preferredHeight),
      child: PrescriptionBookingProgressBar(
        currentStep: currentStep,
        stepProgress: stepProgress,
      ),
    );
  }

  double _fillForIndex(int index) {
    if (index < currentStep) return 1;
    if (index > currentStep) return 0;
    return stepProgress.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    const h = preferredHeight;
    final gap = healthDp(context, 4);

    return SizedBox(
      width: double.infinity,
      height: h,
      child: Row(
        children: List.generate(PrescriptionBookingSteps.count, (index) {
          final fill = _fillForIndex(index);
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : gap / 2,
                right: index == PrescriptionBookingSteps.count - 1 ? 0 : gap / 2,
              ),
              child: _ProgressSegment(height: h, fill: fill),
            ),
          );
        }),
      ),
    );
  }
}

class _ProgressSegment extends StatelessWidget {
  final double height;
  final double fill;

  const _ProgressSegment({
    required this.height,
    required this.fill,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: PrescriptionBookingProgressBar.trackColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              widthFactor: fill.clamp(0.0, 1.0),
              heightFactor: 1,
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: PrescriptionBookingProgressBar.fillColor,
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [ScrollNotification]에서 세로 스크롤 진행률(0~1)을 계산합니다.
double prescriptionBookingScrollProgress(ScrollMetrics metrics) {
  final max = metrics.maxScrollExtent;
  if (max <= 0) return 1;
  return (metrics.pixels / max).clamp(0.0, 1.0);
}

/// 날짜/시간 화면 마일스톤 진행률
/// (날짜 → 시간 → 의료법 체크 → 확인 팝업).
double prescriptionDateTimeMilestoneProgress({
  required bool hasDate,
  required bool hasTime,
  required bool agreedPolicy,
  required bool confirmDialogOpen,
}) {
  if (confirmDialogOpen) return 1;
  if (agreedPolicy) return 3 / 4;
  if (hasTime) return 2 / 4;
  if (hasDate) return 1 / 4;
  return 0;
}
