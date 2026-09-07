import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';

class CancelMemberDoneScreen extends StatelessWidget {
  const CancelMemberDoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void goHome() {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }

    return MobileAppLayoutWrapper(
      appBar: HealthAppBar(
        title: '회원 탈퇴',
        titleFontSize: healthSp(context, 16),
        leadingIconSize: healthDp(context, 24),
        onBack: goHome,
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            goHome();
          },
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                healthDp(context, 20),
                healthDp(context, 10),
                healthDp(context, 20),
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: healthDp(context, 160),
                      height: healthDp(context, 160),
                      decoration: ShapeDecoration(
                        color: const Color(0x19FF5C8F),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 100)),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: healthDp(context, 100),
                        height: healthDp(context, 100),
                        child: SvgPicture.asset(
                          AppAssets.cancelMemberIcon,
                          width: healthDp(context, 100),
                          height: healthDp(context, 100),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: healthDp(context, 20)),
                  Text(
                    '탈퇴가 완료되었습니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF1A1A1A),
                      fontSize: healthSp(context, 18),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 10)),
                  Text(
                    '그동안 보미오라를 이용해 주셔서 감사합니다.\n더 발전된 모습으로 다시 만날 수 있기를 바랍니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF898686),
                      fontSize: healthSp(context, 12),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 48)),
                  SizedBox(
                    height: healthDp(context, 40),
                    child: ElevatedButton(
                      onPressed: goHome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5A8D),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 10)),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        '메인으로 이동',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: healthSp(context, 16),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
