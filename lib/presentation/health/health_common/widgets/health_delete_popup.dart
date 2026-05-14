import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:bomiora_app/presentation/health/health_common/health_responsive_scale.dart';

Future<bool?> showHealthDeletePopup({
  required BuildContext context,
  required String title,
  required String message,
  String cancelText = '취소',
  String deleteText = '삭제',
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: const Color(0x73000000),
    builder: (dialogContext) {
      final screenWidth = MediaQuery.of(dialogContext).size.width;
      const wrapperWidth = 600.0;
      final contentSidePadding = healthDp(dialogContext, 27);
      final wrapperOuterInset =
          screenWidth > wrapperWidth ? (screenWidth - wrapperWidth) / 2 : 0.0;
      final horizontalInset = wrapperOuterInset + contentSidePadding;

      final availW = screenWidth - 2 * horizontalInset;
      final popupW = math.min(healthDp(dialogContext, 272), availW);
      final popupH = healthDp(dialogContext, 221);

      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(horizontal: horizontalInset),
        child: SizedBox(
          width: popupW,
          height: popupH,
          child: HealthDeletePopup(
            title: title,
            message: message,
            cancelText: cancelText,
            deleteText: deleteText,
          ),
        ),
      );
    },
  );
}

class HealthDeletePopup extends StatelessWidget {
  final String title;
  final String message;
  final String cancelText;
  final String deleteText;

  const HealthDeletePopup({
    super.key,
    required this.title,
    required this.message,
    this.cancelText = '취소',
    this.deleteText = '삭제',
  });

  @override
  Widget build(BuildContext context) {
    final r = healthDp(context, 32);
    final rBtn = healthDp(context, 20);
    return ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: healthDp(context, 8),
            sigmaY: healthDp(context, 8),
          ),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x24000000),
                  blurRadius: healthDp(context, 24),
                  offset: Offset(0, healthDp(context, 8)),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final top = healthDp(context, 20);
                final titleSlot = healthDp(context, 20);
                final gapTitleMsg = healthDp(context, 20);
                final msgBox = healthDp(context, 88);
                final gapMsgBtnBase = healthDp(context, 20);
                final btnRow = healthDp(context, 50);

                final fixedSum =
                    top + titleSlot + gapTitleMsg + msgBox + gapMsgBtnBase + btnRow;
                final slack =
                    (constraints.maxHeight - fixedSum).clamp(0.0, double.infinity);
                final gapMsgBtn = gapMsgBtnBase + slack;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: top),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 24),
                      ),
                      child: SizedBox(
                        height: titleSlot,
                        width: double.infinity,
                        child: Center(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFF1F2937),
                              fontSize: healthSp(context, 20),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: gapTitleMsg),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 24),
                      ),
                      child: SizedBox(
                        height: msgBox,
                        width: double.infinity,
                        child: ClipRect(
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: Text(
                              message,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: const Color(0xFF6B7280),
                                fontSize: healthSp(context, 14),
                                height: 1.5,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: gapMsgBtn),
                    SizedBox(
                      height: btnRow,
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => Navigator.pop(context, false),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(rBtn),
                              ),
                              child: Container(
                                width: double.infinity,
                                height: double.infinity,
                                decoration: ShapeDecoration(
                                  color: const Color(0xFFF8F8F8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(rBtn),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      cancelText,
                                      style: TextStyle(
                                        color: const Color(0xFF898686),
                                        fontSize: healthSp(context, 16),
                                        fontFamily: 'Gmarket Sans TTF',
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => Navigator.pop(context, true),
                              borderRadius: BorderRadius.only(
                                bottomRight: Radius.circular(rBtn),
                              ),
                              child: Container(
                                width: double.infinity,
                                height: double.infinity,
                                decoration: ShapeDecoration(
                                  color: const Color(0xFFFF5A8D),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.only(
                                      bottomRight: Radius.circular(rBtn),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      deleteText,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: healthSp(context, 16),
                                        fontFamily: 'Gmarket Sans TTF',
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
                  ],
                );
              },
            ),
          ),
        ),
    );
  }
}
