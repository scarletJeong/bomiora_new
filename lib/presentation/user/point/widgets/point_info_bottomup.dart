import 'package:flutter/material.dart';

import '../../../common/widgets/app_blur_backdrop.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../health/health_common/health_responsive_scale.dart';

Future<void> showPointInfoBottomUp(BuildContext context) {
  final contentW = MobileAppLayoutWrapper.contentWidthOf(context);
  final media = MediaQuery.of(context);
  return showAppBlurSheet<void>(
    context: context,
    child: SizedBox(
      width: contentW,
      child: MediaQuery(
        data: media.copyWith(size: Size(contentW, media.size.height)),
        child: const PointInfoBottomUp(),
      ),
    ),
  );
}

class PointInfoBottomUp extends StatelessWidget {
  const PointInfoBottomUp({super.key});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomPad = media.padding.bottom;
    final maxHeight = media.size.height - media.padding.top;

    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.deferToChild,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          width: double.infinity,
          clipBehavior: Clip.hardEdge,
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
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(height: healthDp(context, 20)),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    _line(
                      context,
                      '*100P = 100원 입니다.(1P = 1원)',
                    ),
                    SizedBox(height: healthDp(context, 10)),
                    _line(
                      context,
                      '*2025년 8월 8일 이후 지급된 포인트는 지급일자 기준으로 1년 후 자동소멸됩니다.',
                    ),
                    SizedBox(height: healthDp(context, 10)),
                    _line(
                      context,
                      '*할인 적용 및 프로모션 페이지를 통한 결제 시 포인트 사용이 불가합니다.(중복 할인 불가)',
                      color: const Color(0xFFEF4444),
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

  Widget _line(BuildContext context, String text, {Color color = const Color(0xFF1A1A1E)}) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        text,
        softWrap: true,
        style: TextStyle(
          color: color,
          fontSize: healthSp(context, 14),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w300,
          height: 1.4,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
