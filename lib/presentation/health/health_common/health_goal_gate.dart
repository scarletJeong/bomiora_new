import 'package:flutter/material.dart';

import '../../../data/models/health/health_goal_record_model.dart';
import '../dashboard/screens/health_goal_screen.dart';

bool isHealthGoalConfigured(HealthGoalRecordModel? goal) {
  if (goal == null) return false;
  return (goal.targetWeight ?? 0) > 0 &&
      (goal.currentWeight ?? 0) > 0 &&
      (goal.dailyStepGoal ?? 0) > 0;
}

/// 목표 미설정 시 안내 후 [HealthGoalScreen]으로 이동.
/// 저장에 성공하면 `true`.
Future<bool> showHealthGoalRequiredDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 272,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    '목표설정 안내',
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Text(
                    '목표를 설정하고 기록을 시작하세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF898686),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.57,
                    ),
                  ),
                ),
                SizedBox(
                  height: 50,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Material(
                          color: const Color(0xFFF7F7F7),
                          child: InkWell(
                            onTap: () => Navigator.of(dialogContext).pop(false),
                            child: const Center(
                              child: Text(
                                '취소',
                                style: TextStyle(
                                  color: Color(0xFF898686),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Material(
                          color: const Color(0xFFFF5A8D),
                          child: InkWell(
                            onTap: () => Navigator.of(dialogContext).pop(true),
                            child: const Center(
                              child: Text(
                                '확인',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  if (result != true || !context.mounted) return false;

  final saved = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => const HealthGoalScreen()),
  );
  return saved == true;
}
