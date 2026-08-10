import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';

/// 확인 버튼만 있는 알림 다이얼로그
class AppAlertDialog extends StatelessWidget {
  const AppAlertDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = '확인',
    this.width = 272,
  });

  final String title;
  final String message;
  final String confirmText;
  final double width;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = '확인',
    double width = 272,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppAlertDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        width: width,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final margin = healthDp(context, 24);
    final maxByScreen = math.max(0.0, screenW - margin * 2);
    final designScaled = healthDp(context, width);
    final byFraction = screenW * 0.88;
    final dialogW =
        math.min(designScaled, math.min(byFraction, maxByScreen));

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 16),
        vertical: healthDp(context, 24),
      ),
      child: Container(
        width: dialogW,
        padding: EdgeInsets.only(
          top: healthDp(context, 20),
          left: healthDp(context, 20),
          right: healthDp(context, 20),
        ),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 20)),
          ),
          shadows: [
            BoxShadow(
              color: const Color(0x19000000),
              blurRadius: healthDp(context, 8.14),
              offset: Offset.zero,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF1A1A1E),
                fontSize: healthSp(context, 20),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: healthDp(context, 20)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF898686),
                fontSize: healthSp(context, 14),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                height: 1.57,
              ),
            ),
            SizedBox(height: healthDp(context, 20)),
            SizedBox(
              width: double.infinity,
              height: healthDp(context, 50),
              child: Material(
                color: const Color(0xFFFF5A8D),
                borderRadius: BorderRadius.circular(healthDp(context, 10)),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                  child: Center(
                    child: Text(
                      confirmText,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: healthSp(context, 16),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: healthDp(context, 20)),
          ],
        ),
      ),
    );
  }
}
