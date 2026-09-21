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
    final r = healthDp(context, 20);
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: healthDp(context, 24)),
      child: Container(
        width: healthDp(context, 300),
        padding: EdgeInsets.all(healthDp(context, 20)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(r),
          boxShadow: [
            BoxShadow(
              color: const Color(0x26000000),
              blurRadius: healthDp(context, 20),
              offset: Offset(0, healthDp(context, 8)),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: healthDp(context, 44),
              height: healthDp(context, 44),
              decoration: const BoxDecoration(
                color: Color(0x14FF5A8D),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: const Color(0xFFFF5A8D),
                size: healthDp(context, 24),
              ),
            ),
            SizedBox(height: healthDp(context, 14)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF1A1A1E),
                fontSize: healthSp(context, 18),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: healthDp(context, 10)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF898686),
                fontSize: healthSp(context, 13),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
            SizedBox(height: healthDp(context, 20)),
            Row(
              children: [
                Expanded(
                  child: _PopupButton(
                    label: cancelText,
                    backgroundColor: const Color(0xFFF2F2F2),
                    textColor: const Color(0xFF666666),
                    onTap: () => Navigator.pop(context, false),
                  ),
                ),
                SizedBox(width: healthDp(context, 8)),
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
      height: healthDp(context, 44),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: healthSp(context, 14),
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
