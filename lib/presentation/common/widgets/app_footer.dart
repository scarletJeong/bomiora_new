import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../settings/policy/screens/privacy_policy_screen.dart';
import '../../settings/policy/screens/terms_of_service_screen.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  static const _bg = Color(0xFFF7F7F7);
  static const _text = Color(0xFF676767);
  static const _font = 'Gmarket Sans TTF';

  TextStyle _rowStyle(BuildContext context, {double fontBase = 10, double height = 1.73, double letterBase = -0.50}) {
    return TextStyle(
      color: _text,
      fontSize: healthSp(context, fontBase),
      fontFamily: _font,
      fontWeight: FontWeight.w500,
      height: height,
      letterSpacing: healthSp(context, letterBase),
    );
  }

  Widget _pair(
    BuildContext context,
    String label,
    String value, {
    TextStyle? labelStyle,
    TextStyle? valueStyle,
    double gapBase = 11.54,
    bool expand = true,
  }) {
    final style = _rowStyle(context);
    final valueText = Text(value, style: valueStyle ?? style);
    return Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle ?? style),
        SizedBox(width: healthDp(context, gapBase)),
        if (expand) Expanded(child: valueText) else valueText,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final outerH = healthDp(context, 20);
    final outerV = healthDp(context, 28.85);
    final innerH = healthDp(context, 17.31);
    final iconH = healthDp(context, 21.06);
    final infoStyle = _rowStyle(context);
    final faxLabelStyle = _rowStyle(
      context,
      fontBase: 10.38,
      height: 1.67,
      letterBase: -0.52,
    );
    final linkStyle = TextStyle(
      color: _text,
      fontSize: healthSp(context, 10),
      fontFamily: _font,
      fontWeight: FontWeight.w500,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: outerH, vertical: outerV),
      decoration: const BoxDecoration(color: _bg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: innerH),
            child: SizedBox(
              height: iconH,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    AppAssets.footerIcon1,
                    height: iconH,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(width: healthDp(context, 3.29)),
                  SvgPicture.asset(
                    AppAssets.footerIcon2,
                    height: healthDp(context, 12),
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: healthDp(context, 11.54)),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: innerH,
              vertical: healthDp(context, 5.77),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pair(context, '상호명', '주식회사 보미오라'),
                SizedBox(height: healthDp(context, 5.77)),
                _pair(context, '대표이사', '정대진'),
                SizedBox(height: healthDp(context, 5.77)),
                _pair(context, '사업자번호', '356-87-02862'),
                SizedBox(height: healthDp(context, 5.77)),
                _pair(context, '통신판매업신고', '제2023-서울강남-02582호'),
                SizedBox(height: healthDp(context, 5.77)),
                _pair(context, '건강기능식품판매업신고', '제2023-0138695호'),
                SizedBox(height: healthDp(context, 5.77)),
                Wrap(
                  spacing: healthDp(context, 6),
                  runSpacing: healthDp(context, 4),
                  crossAxisAlignment: WrapCrossAlignment.start,
                  children: [
                    _pair(context, '고객센터', '02-546-1031', expand: false),
                    _pair(
                      context,
                      '팩스',
                      '02-547-1031',
                      labelStyle: faxLabelStyle,
                      valueStyle: infoStyle,
                      expand: false,
                    ),
                  ],
                ),
                SizedBox(height: healthDp(context, 5.77)),
                _pair(context, '이메일', 'official@bomiora.kr'),
                SizedBox(height: healthDp(context, 5.77)),
                _pair(context, '주소', '서울 강남구 봉은사로 109, 6층(논현동)'),
              ],
            ),
          ),
          SizedBox(height: healthDp(context, 6.92)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: innerH),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const TermsOfServiceScreen(),
                      ),
                    );
                  },
                  child: Text('이용약관', style: linkStyle),
                ),
                SizedBox(width: healthDp(context, 11.54)),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
                  child: Text('개인정보처리방침', style: linkStyle),
                ),
              ],
            ),
          ),
          SizedBox(height: healthDp(context, 14.42)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: innerH),
            child: Text(
              'ⓒ2026 bomiara, All rights reserved.',
              style: linkStyle,
            ),
          ),
        ],
      ),
    );
  }
}
