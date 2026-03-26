import 'package:flutter/material.dart';

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
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: width,
        decoration: const ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          shadows: [
            BoxShadow(
              color: Color(0x19000000),
              blurRadius: 8.14,
              offset: Offset(0, 0),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    top: showDivider ? 22 : 20,
                    left: 20,
                    right: 20,
                    bottom: showDivider ? 18 : 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: showDivider ? 14 : 20),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF898686),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.57,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showDivider) Container(height: 1, color: const Color(0xFFF1F1F1)),
                SizedBox(
                  height: 50,
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
                              style: const TextStyle(
                                color: Color(0xFF898686),
                                fontSize: 16,
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
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
    );
  }
}

