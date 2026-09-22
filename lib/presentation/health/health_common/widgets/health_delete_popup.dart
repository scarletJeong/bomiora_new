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
    barrierDismissible: false,
    barrierColor: const Color(0x73000000),
    builder: (_) => HealthDeletePopup(
      title: title,
      message: message,
      cancelText: cancelText,
      deleteText: deleteText,
    ),
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
    final r = healthDp(context, 23.1);
    final contentPadding = healthDp(context, 23.1);
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: healthDp(context, 20)),
      child: Container(
        width: healthDp(context, 314.3),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(r),
          boxShadow: [
            BoxShadow(
              color: const Color(0x19000000),
              blurRadius: healthDp(context, 9.4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                contentPadding,
                contentPadding,
                contentPadding,
                contentPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF1A1A1A),
                      fontSize: healthSp(context, 23.1),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 23.1)),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF898686),
                      fontSize: healthSp(context, 16.2),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                      height: 1.57,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _PopupButton(
                    label: cancelText,
                    backgroundColor: const Color(0xFFF7F7F7),
                    textColor: const Color(0xFF898686),
                    onTap: () => Navigator.pop(context, false),
                  ),
                ),
                Expanded(
                  child: _PopupButton(
                    label: deleteText,
                    backgroundColor: const Color(0xFFFF5A8D),
                    textColor: Colors.white,
                    onTap: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PopupButton extends StatelessWidget {
  const _PopupButton({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: healthDp(context, 57.8),
      child: Material(
        color: backgroundColor,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: healthSp(context, 18.5),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
