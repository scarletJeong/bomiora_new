import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';

class AgreementPopupDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final String body;

  /// 375 기준 팝업 높이 (기존 607 → 520).
  static const double _heightBase = 520;
  static const double _widthBase = 355;

  const AgreementPopupDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final popupH = healthDp(context, _heightBase);
    final popupW = healthDp(context, _widthBase);
    final screenH = MediaQuery.sizeOf(context).height;
    final height = popupH.clamp(0.0, screenH - healthDp(context, 48));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 18),
        vertical: healthDp(context, 24),
      ),
      child: Container(
        width: popupW,
        height: height,
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 20),
          vertical: healthDp(context, 20),
        ),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
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
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: healthSp(context, 20),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, size: healthDp(context, 24)),
                ),
              ],
            ),
            SizedBox(height: healthDp(context, 8)),
            Container(
              width: double.infinity,
              height: healthDp(context, 1),
              color: const Color(0x7FD2D2D2),
            ),
            SizedBox(height: healthDp(context, 16)),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: healthSp(context, 16),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: healthDp(context, 12)),
                    Text(
                      body,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: healthSp(context, 14),
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
      insetPadding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 18),
        vertical: healthDp(context, 24),
      ),
      child: Container(
        constraints: BoxConstraints(maxWidth: healthDp(context, 355)),
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 20),
          vertical: healthDp(context, 20),
        ),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
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
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: healthSp(context, 20),
                      fontFamily: _fontFamily,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: Icon(Icons.close, size: healthDp(context, 24)),
                ),
              ],
            ),
            SizedBox(height: healthDp(context, 8)),
            Container(
              width: double.infinity,
              height: healthDp(context, 1),
              color: const Color(0x7FD2D2D2),
            ),
            SizedBox(height: healthDp(context, 16)),
            Text(
              message,
              style: TextStyle(
                color: Colors.black,
                fontSize: healthSp(context, 14),
                fontFamily: _fontFamily,
                fontWeight: FontWeight.w300,
                height: 1.6,
              ),
            ),
            SizedBox(height: healthDp(context, 24)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Color(0xFFD2D2D2)),
                      padding: EdgeInsets.symmetric(
                        vertical: healthDp(context, 12),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(healthDp(context, 8)),
                      ),
                    ),
                    child: Text(
                      cancelLabel,
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: healthSp(context, 14),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: healthDp(context, 10)),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: healthDp(context, 12),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(healthDp(context, 8)),
                      ),
                    ),
                    child: Text(
                      confirmLabel,
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: healthSp(context, 14),
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
