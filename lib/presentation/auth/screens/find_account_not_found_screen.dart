import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';

/// 아이디/비밀번호 찾기 공통 — 일치 회원 없음
/// 인자: `retryTab` `'password'` | `'id'` (생략 시 `'id'`), 하위 호환으로 `mode: 'password'` 도 동일 처리
class FindAccountNotFoundScreen extends StatelessWidget {
  const FindAccountNotFoundScreen({
    super.key,
    this.findAccountInfo,
  });

  final Map<String, dynamic>? findAccountInfo;

  bool get _openPasswordTabOnRetry {
    final info = findAccountInfo;
    if (info == null) return false;
    final retry = (info['retryTab'] ?? '').toString().toLowerCase();
    if (retry == 'password') return true;
    return (info['mode'] ?? '').toString() == 'password';
  }

  void _onRetry(BuildContext context) {
    Navigator.pushReplacementNamed(
      context,
      '/find-account',
      arguments: _openPasswordTabOnRetry ? {'tab': 'password'} : null,
    );
  }

  void _onSignup(BuildContext context) {
    Navigator.pushNamed(context, '/signup');
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
              title: '아이디/비밀번호찾기',
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
                            Builder(
                              builder: (context) {
                                final circle = healthDp(context, 128);
                                final iconW = healthDp(context, 50);
                                final iconH = iconW * 85 / 89;
                                return SizedBox(
                                  width: circle,
                                  height: circle,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      const DecoratedBox(
                                        decoration: ShapeDecoration(
                                          color: Color(0x19FF5C8F),
                                          shape: CircleBorder(),
                                        ),
                                        child: SizedBox.expand(),
                                      ),
                                      SvgPicture.asset(
                                        AppAssets.loginFail,
                                        width: iconW,
                                        height: iconH,
                                        fit: BoxFit.contain,
                                        alignment: Alignment.center,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            SizedBox(height: healthDp(context, 10)),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(healthDp(context, 10)),
                              child: Column(
                                children: [
                                  Text(
                                    '일치하는 정보가 없습니다.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: healthSp(context, 16),
                                      fontFamily: 'Gmarket Sans TTF',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: healthDp(context, 10)),
                                  Text(
                                    '입력하신 정보로 가입된 아이디를\n찾을 수 없습니다. 다시 확인해 주세요.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: healthSp(context, 14),
                                      fontFamily: 'Gmarket Sans TTF',
                                      fontWeight: FontWeight.w300,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: healthDp(context, 20)),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: healthDp(context, 40),
                            child: OutlinedButton(
                              onPressed: () => _onRetry(context),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  width: healthDp(context, 0.5),
                                  color: const Color(0xFFD2D2D2),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    healthDp(context, 10),
                                  ),
                                ),
                              ),
                              child: Text(
                                '다시 찾기',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFF898686),
                                  fontSize: healthSp(context, 16),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: healthDp(context, 20)),
                        Expanded(
                          child: SizedBox(
                            height: healthDp(context, 40),
                            child: ElevatedButton(
                              onPressed: () => _onSignup(context),
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
                                '회원가입 하기',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: healthSp(context, 16),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
