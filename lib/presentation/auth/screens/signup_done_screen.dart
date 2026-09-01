import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../../data/services/pending_product_checkout.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../../user/healthprofile/screens/health_profile_list_screen.dart';

class SignupDoneScreen extends StatelessWidget {
  const SignupDoneScreen({super.key});

  void _goHome(BuildContext context) {
    if (PendingProductCheckout.navigateAfterAuth(context)) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/enter-home', (route) => false);
  }

  void _goHealthDashboard(BuildContext context) {
    Navigator.of(context).pushNamed('/health');
  }

  void _goHealthQuestionnaire(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const HealthProfileListScreen()),
    );
  }

  void _goShoppingMall(BuildContext context) {
    if (PendingProductCheckout.navigateAfterAuth(context)) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/enter-home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );
    final textScale =
        healthTextScaleByWidth(MediaQuery.sizeOf(context).width);

    return Theme(
      data: gmarketTheme,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            fontFamily: 'Gmarket Sans TTF',
            color: Color(0xFF1A1A1A),
          ),
          child: MobileAppLayoutWrapper(
            backgroundColor: Colors.white,
            appBar: HealthAppBar(
              title: '회원가입',
              onBack: () => _goHome(context),
              titleFontSize: healthSp(context, 16),
              leadingIconSize: healthDp(context, 24),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  healthDp(context, 20),
                  healthDp(context, 20),
                  healthDp(context, 20),
                  healthDp(context, 20),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '회원 가입 완료 !',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: healthSp(context, 20),
                                      fontFamily: 'Gmarket Sans TTF',
                                      fontWeight: FontWeight.w500,
                                      height: 1,
                                    ),
                                  ),
                                  SizedBox(height: healthDp(context, 4)),
                                  Text(
                                    '회원가입을 진심으로 축하드립니다.\n보미오라만의 다양한 서비스를 만나보세요.',
                                    style: TextStyle(
                                      color: const Color(0xFF898686),
                                      fontSize: healthSp(context, 14),
                                      fontFamily: 'Gmarket Sans TTF',
                                      fontWeight: FontWeight.w300,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: healthDp(context, 20)),
                            _BenefitCard(
                              title: '문진표',
                              subtitle: '나의 건강 상태 확인하기',
                              iconAsset: AppAssets.signupComplete,
                              iconBackground: const Color(0xFFEFF6FF),
                              onTap: () => _goHealthQuestionnaire(context),
                            ),
                            SizedBox(height: healthDp(context, 10)),
                            const _BenefitCard(
                              title: '비대면 진료',
                              subtitle: '집에서 편하게 받는 진료',
                              iconAsset: AppAssets.signupCompleteHealthProduct,
                              iconBackground: Color(0xFFECFDF5),
                            ),
                            SizedBox(height: healthDp(context, 10)),
                            _BenefitCard(
                              title: '쇼핑몰',
                              subtitle: '맞춤 영양제 및 건강 용품',
                              iconAsset: AppAssets.signupCompleteShopping,
                              iconBackground: const Color(0xFFFFF7ED),
                              onTap: () => _goShoppingMall(context),
                            ),
                            SizedBox(height: healthDp(context, 10)),
                            _BenefitCard(
                              title: '건강 대시보드',
                              subtitle: '나의 건강 데이터를 한눈에',
                              iconAsset: AppAssets.signupCompleteHealthDashboard,
                              iconBackground: const Color(0xFFFAF5FF),
                              onTap: () => _goHealthDashboard(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: healthDp(context, 20)),
                    SizedBox(
                      width: double.infinity,
                      height: healthDp(context, 40),
                      child: ElevatedButton(
                        onPressed: () => _goHome(context),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFFFF5A8D),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              healthDp(context, 10),
                            ),
                          ),
                        ),
                        child: Text(
                          '홈으로 이동',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: healthSp(context, 16),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String iconAsset;
  final Color iconBackground;
  final VoidCallback? onTap;

  const _BenefitCard({
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.iconBackground,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(healthDp(context, 10)),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: healthDp(context, 1),
              color: const Color(0xFFD2D2D2),
            ),
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(healthDp(context, 12)),
              decoration: ShapeDecoration(
                color: iconBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 12)),
                ),
              ),
              child: SvgPicture.asset(
                iconAsset,
                width: healthDp(context, 24),
                height: healthDp(context, 24),
              ),
            ),
            SizedBox(width: healthDp(context, 16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: const Color(0xFF1E293B),
                      fontSize: healthSp(context, 16),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                      height: 1.75,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: const Color(0xFF94A3B8),
                      fontSize: healthSp(context, 12),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                      height: 1.67,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: healthDp(context, 24),
              color: const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}
