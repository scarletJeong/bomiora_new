import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  static const _bg = Color(0xFFF7F7F7);
  static const _text = Color(0xFF676767);
  static const _font = 'Gmarket Sans TTF';
  static const double _fontSize = 12;
  static const double _fontSizeSmall = 11;
  static const double _footerIconHeight = 22;
  /// 본문·아이콘·약관·저작권 공통 왼쪽 들여쓰기
  static const double _contentInsetLeft = 60;

  TextStyle get _rowStyle => const TextStyle(
        color: _text,
        fontSize: _fontSize,
        fontFamily: _font,
        fontWeight: FontWeight.w500,
        height: 1.5,
        letterSpacing: -0.36,
      );

  /// `라벨 값` — 고정 라벨 칸 없음. 좁으면 값이 다음 줄로 넘어감.
  Widget _pairLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.start,
        spacing: 6,
        runSpacing: 4,
        children: [
          Text(label, style: _rowStyle, textAlign: TextAlign.start),
          Text(value, style: _rowStyle, textAlign: TextAlign.start),
        ],
      ),
    );
  }

  /// 한 쌍을 가로로 꼭 붙여야 할 때(고객센터+번호 | 팩스+번호).
  Widget _pairInline(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _rowStyle, textAlign: TextAlign.start),
        const SizedBox(width: 6),
        Text(value, style: _rowStyle, textAlign: TextAlign.start),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: _bg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _contentInsetLeft,
              14,
              16,
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
                      height: _footerIconHeight,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 5),
                    SvgPicture.asset(
                      AppAssets.footerIcon2,
                      height: 12,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _pairLine('상호명', '주식회사 보미오라'),
                _pairLine('대표이사', '정대진'),
                _pairLine('사업자번호', '356-87-02862'),
                _pairLine('통신판매업신고', '제2023-서울강남-02582호'),
                _pairLine('건강기능식품판매업신고', '제2023-0138695호'),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    children: [
                      _pairInline('고객센터', '02-546-1031'),
                      _pairInline('팩스', '02-547-1031'),
                    ],
                  ),
                ),
                _pairLine('이메일', 'official@bomiora.kr'),
                _pairLine('주소', '서울 강남구 봉은사로 109, 6층(논현동)'),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const Divider(
            color: Colors.black,
            height: 0.1,
            thickness: 0.1,
            indent: 30,
            endIndent: 30,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _contentInsetLeft,
              8,
              16,
              14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    children: [
                      Text(
                        '이용약관',
                        textAlign: TextAlign.start,
                        style: _rowStyle.copyWith(fontSize: _fontSizeSmall),
                      ),
                      Text(
                        '개인정보처리방침',
                        textAlign: TextAlign.start,
                        style: _rowStyle.copyWith(fontSize: _fontSizeSmall),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    'ⓒ2026 bomiara, All rights reserved.',
                    textAlign: TextAlign.start,
                    style: _rowStyle.copyWith(fontSize: _fontSizeSmall),
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
