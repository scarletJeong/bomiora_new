import 'dart:ui';

import 'package:flutter/material.dart';

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
      const contentSidePadding = 27.0;
      final wrapperOuterInset =
          screenWidth > wrapperWidth ? (screenWidth - wrapperWidth) / 2 : 0.0;
      final horizontalInset = wrapperOuterInset + contentSidePadding;

      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(horizontal: horizontalInset),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 22,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 15,
                        height: 1.5,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F1F1)),
              SizedBox(
                height: 62,
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.pop(context, false),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                        ),
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: const ShapeDecoration(
                            color: Color(0xFFF8F8F8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(20),
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
                                style: const TextStyle(
                                  color: Color(0xFF898686),
                                  fontSize: 16,
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
                        borderRadius: const BorderRadius.only(
                          bottomRight: Radius.circular(20),
                        ),
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: const ShapeDecoration(
                            color: Color(0xFFFF5A8D),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                bottomRight: Radius.circular(20),
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
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
          ),
        ),
      ),
    );
  }
}
