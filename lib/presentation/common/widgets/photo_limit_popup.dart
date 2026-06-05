import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';

/// 사진 최대 장수 초과 시 표시하는 안내 팝업
class PhotoLimitPopup extends StatelessWidget {
  const PhotoLimitPopup({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PhotoLimitPopup(),
    );
  }

  @override
  Widget build(BuildContext context) {
    const kInk = Color(0xFF1A1A1E);
    const kMuted = Color(0xFF898686);
    const kPink = Color(0xFFFF5A8D);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: healthDp(context, 24)),
      child: Container(
        width: healthDp(context, 272),
        padding: EdgeInsets.all(healthDp(context, 20)),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 20)),
          ),
          shadows: const [
            BoxShadow(
              color: Color(0x19000000),
              blurRadius: 8.14,
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
              '사진 추가 제한',
              style: TextStyle(
                color: kInk,
                fontSize: healthSp(context, 20),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: healthDp(context, 20)),
            Text(
              '사진을 등록할 수 없습니다.\n사진등록은 최대 3장까지 가능합니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kMuted,
                fontSize: healthSp(context, 14),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                height: 1.57,
              ),
            ),
            SizedBox(height: healthDp(context, 20)),
            SizedBox(
              width: double.infinity,
              height: healthDp(context, 40),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: kPink,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.all(healthDp(context, 10)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 10)),
                  ),
                ),
                child: Text(
                  '확인',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: healthSp(context, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
