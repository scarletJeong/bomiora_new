import 'package:flutter/material.dart';

class AgreementPopupDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final String body;

  const AgreementPopupDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        width: 355,
        height: 607,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 1,
              color: const Color(0x7FD2D2D2),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      body,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [AgreementPopupDialog]와 동일한 컨테이너·타이포 스타일의 확인용 다이얼로그
class AgreementStyleConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;

  const AgreementStyleConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.cancelLabel = '취소',
    this.confirmLabel = '확인',
  });

  static const String _fontFamily = 'Gmarket Sans TTF';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 355),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontFamily: _fontFamily,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 1,
              color: const Color(0x7FD2D2D2),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontFamily: _fontFamily,
                fontWeight: FontWeight.w300,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Color(0xFFD2D2D2)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      cancelLabel,
                      style: const TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
