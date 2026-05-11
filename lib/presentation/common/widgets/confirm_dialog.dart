import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';

/// 재사용 가능한 확인/취소 다이얼로그(디자인 토대)
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.cancelText = '취소',
    this.confirmText = '확인',
    this.width = 300,
    this.showDivider = true,
  });

  final String title;
  final String message;
  final String cancelText;
  final String confirmText;
  final double width;
  final bool showDivider;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String cancelText = '취소',
    String confirmText = '확인',
    double width = 300,
    bool showDivider = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConfirmDialog(
        title: title,
        message: message,
        cancelText: cancelText,
        confirmText: confirmText,
        width: width,
        showDivider: showDivider,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final margin = healthDp(context, 24);
    final maxByScreen = math.max(0.0, screenW - margin * 2);
    final designScaled = healthDp(context, width);
    // 가용 폭의 대부분 사용 (Material Dialog 기본 maxWidth 560 제한을 Theme으로 완화)
    final byFraction = screenW * 0.88;
    final dialogW =
        math.min(math.max(designScaled, byFraction), maxByScreen);
    final r = healthDp(context, 20);
    final theme = Theme.of(context);
    // Flutter 기본 Dialog 가로 상한(보통 560)보다 넓게 허용
    final dialogConstraints = BoxConstraints(
      minWidth: 280,
      maxWidth: math.max(560.0, dialogW),
    );
    return Theme(
      data: theme.copyWith(
        dialogTheme: theme.dialogTheme.copyWith(
          constraints: dialogConstraints,
        ),
      ),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 16),
          vertical: healthDp(context, 24),
        ),
        child: Container(
          width: dialogW,
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(r)),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(r),
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      top: healthDp(context, showDivider ? 22 : 20),
                      left: healthDp(context, 20),
                      right: healthDp(context, 20),
                      bottom: healthDp(context, showDivider ? 18 : 20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            color: const Color(0xFF1A1A1A),
                            fontSize: healthSp(context, 20),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(
                          height: healthDp(context, showDivider ? 14 : 20),
                        ),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            color: const Color(0xFF898686),
                            fontSize: healthSp(context, 14),
                            fontWeight: FontWeight.w500,
                            height: 1.57,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showDivider)
                    Container(
                      height: healthDp(context, 1),
                      color: const Color(0xFFF1F1F1),
                    ),
                  SizedBox(
                    height: healthDp(context, 50),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => Navigator.pop(context, false),
                            child: Container(
                              height: double.infinity,
                              color: const Color(0xFFF7F7F7),
                              alignment: Alignment.center,
                              child: Text(
                                cancelText,
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  color: const Color(0xFF898686),
                                  fontSize: healthSp(context, 16),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => Navigator.pop(context, true),
                            child: Container(
                              height: double.infinity,
                              color: const Color(0xFFFF5A8D),
                              alignment: Alignment.center,
                              child: Text(
                                confirmText,
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: healthSp(context, 16),
                                  fontWeight: FontWeight.w500,
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
        ),
      ),
    );
  }
}

