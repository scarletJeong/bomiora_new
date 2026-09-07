import 'package:flutter/material.dart';

import '../../../common/widgets/app_blur_backdrop.dart';
import '../../../health/health_common/health_responsive_scale.dart';

Future<void> showPointInfoBottomUp(BuildContext context) {
  return showAppBlurSheet<void>(
    context: context,
    child: const PointInfoBottomUp(),
  );
}

class PointInfoBottomUp extends StatelessWidget {
  const PointInfoBottomUp({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.deferToChild,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          healthDp(context, 30),
          healthDp(context, 16),
          healthDp(context, 30),
          healthDp(context, 24) + bottomPad,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(healthDp(context, 16)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: healthDp(context, 45),
              height: healthDp(context, 4),
              decoration: ShapeDecoration(
                color: const Color(0xFFD2D2D2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                ),
              ),
            ),
            SizedBox(height: healthDp(context, 20)),
            Text(
              '포인트 이용 안내',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF1A1A1E),
                fontSize: healthSp(context, 16),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: healthDp(context, 20)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '*100P = 100원 입니다.(1P = 1원)',
                  style: TextStyle(
                    color: const Color(0xFF1A1A1E),
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
                SizedBox(height: healthDp(context, 10)),
                Text(
                  '*2025년 8월 8일 이후 지급된 포인트는 지급일자 기준으로 1년 후 자동소멸됩니다.',
                  style: TextStyle(
                    color: const Color(0xFF1A1A1E),
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
                SizedBox(height: healthDp(context, 10)),
                Text(
                  '*할인 적용 및 프로모션 페이지를 통한 결제 시 \n포인트 사용이 불가합니다.(중복 할인 불가)',
                  style: TextStyle(
                    color: const Color(0xFFEF4444),
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
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
