import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../health/health_common/health_responsive_scale.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  static const _bg = Color(0xFFF7F7F7);
  static const _text = Color(0xFF676767);
  static const _font = 'Gmarket Sans TTF';

  TextStyle _rowStyle(BuildContext context) {
    final t = healthTextScaleByWidth(MediaQuery.sizeOf(context).width);
    return TextStyle(
      color: _text,
      fontSize: healthSp(context, 12),
      fontFamily: _font,
      fontWeight: FontWeight.w500,
      height: 1.5,
      letterSpacing: -0.36 * t,
    );
  }

  TextStyle _rowStyleSmall(BuildContext context) =>
      _rowStyle(context).copyWith(fontSize: healthSp(context, 11));

  /// `라벨 값` — 고정 라벨 칸 없음. 좁으면 값이 다음 줄로 넘어감.
  Widget _pairLine(
    BuildContext context,
    String label,
    String value,
    TextStyle rowStyle,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: healthDp(context, 6)),
      child: Wrap(
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.start,
        spacing: healthDp(context, 6),
        runSpacing: healthDp(context, 4),
        children: [
          Text(label, style: rowStyle, textAlign: TextAlign.start),
          Text(value, style: rowStyle, textAlign: TextAlign.start),
        ],
      ),
    );
  }

  /// 한 쌍을 가로로 꼭 붙여야 할 때(고객센터+번호 | 팩스+번호).
  Widget _pairInline(
    BuildContext context,
    String label,
    String value,
    TextStyle rowStyle,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: rowStyle, textAlign: TextAlign.start),
        SizedBox(width: healthDp(context, 6)),
        Text(value, style: rowStyle, textAlign: TextAlign.start),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final insetL = healthDp(context, 60);
    final padR = healthDp(context, 16);
    final padTop = healthDp(context, 14);
    final padBottom = healthDp(context, 14);
    final padMidTop = healthDp(context, 8);
    final iconH1 = healthDp(context, 22);
    final iconH2 = healthDp(context, 12);
    final gapIcons = healthDp(context, 5);
    final gapAfterIcons = healthDp(context, 10);
    final gapSmall = healthDp(context, 4);
    final gapBeforeCopyright = healthDp(context, 8);
    final dividerIndent = healthDp(context, 30);
    final dividerThickness = healthDp(context, 0.1);
    final rowStyle = _rowStyle(context);
    final rowStyleSmall = _rowStyleSmall(context);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: _bg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              insetL,
              padTop,
              padR,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      AppAssets.footerIcon1,
                      height: iconH1,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(width: gapIcons),
                    SvgPicture.asset(
                      AppAssets.footerIcon2,
                      height: iconH2,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
                SizedBox(height: gapAfterIcons),
                _pairLine(context, '상호명', '주식회사 보미오라', rowStyle),
                _pairLine(context, '대표이사', '정대진', rowStyle),
                _pairLine(context, '사업자번호', '356-87-02862', rowStyle),
                _pairLine(context, '통신판매업신고', '제2023-서울강남-02582호', rowStyle),
                _pairLine(context, '건강기능식품판매업신고', '제2023-0138695호', rowStyle),
                SizedBox(height: gapSmall),
                Padding(
                  padding: EdgeInsets.only(bottom: healthDp(context, 6)),
                  child: Wrap(
                    spacing: healthDp(context, 6),
                    runSpacing: healthDp(context, 2),
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    children: [
                      _pairInline(context, '고객센터', '02-546-1031', rowStyle),
                      _pairInline(context, '팩스', '02-547-1031', rowStyle),
                    ],
                  ),
                ),
                _pairLine(context, '이메일', 'official@bomiora.kr', rowStyle),
                _pairLine(context, '주소', '서울 강남구 봉은사로 109, 6층(논현동)', rowStyle),
                SizedBox(height: gapBeforeCopyright),
              ],
            ),
          ),
          Divider(
            color: Colors.black,
            height: dividerThickness,
            thickness: dividerThickness,
            indent: dividerIndent,
            endIndent: dividerIndent,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              insetL,
              padMidTop,
              padR,
              padBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    spacing: healthDp(context, 12),
                    runSpacing: healthDp(context, 4),
                    crossAxisAlignment: WrapCrossAlignment.start,
                    children: [
                      Text(
                        '이용약관',
                        textAlign: TextAlign.start,
                        style: rowStyleSmall,
                      ),
                      Text(
                        '개인정보처리방침',
                        textAlign: TextAlign.start,
                        style: rowStyleSmall,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: gapBeforeCopyright),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    'ⓒ2026 bomiara, All rights reserved.',
                    textAlign: TextAlign.start,
                    style: rowStyleSmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
