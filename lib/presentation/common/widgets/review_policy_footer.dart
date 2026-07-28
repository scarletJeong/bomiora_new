import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';

/// 리뷰 작성 화면 하단 — 보미오라 리뷰 정책 (AppFooter 톤)
class ReviewPolicyFooter extends StatelessWidget {
  const ReviewPolicyFooter({super.key});

  static const _bg = Color(0xFFF7F7F7);
  static const _text = Color(0xFF676767);
  static const _font = 'Gmarket Sans TTF';

  static const _intro =
      '다음 금지행위에 해당되는 리뷰는 고객에게 통보없이 삭제 또는 블라인드 처리 될 수있으며, '
      '지급된 포인트 또한 회수 될 수 있습니다.';

  static const _rules = <String>[
    '허위/과장된 내용 또는 직접 작성하지 않았거나 구매한 상품/의약품과는 관련 없는 내용 게시',
    '정당한 권한 없이 타인의 권리 (개인정보, 지식재산권, 소유권, 명예, 신용 등)을 침해하는 내용 게시',
    '욕설, 폭언, 비방 등 타인에 불쾌하거나 위협이 되는 내용 게시',
    '음란물 또는 청소년 유해 매체물, 범죄행위나 불법적인 행동을 전시 또는 조장하는 내용 게시',
    '정보통신기기의 오작동을 일으킬 수 있는 악성코드나 데이터를 포함하는 내용 게시',
    '사기성 상품, 서비스, 사업 계획 등을 판촉하는 내용 게시',
    '주관적인 느낌, 감정 또는 사실관계가 제대로 확인되지 않거나 입증되지 않은 추측성의 부정적인 내용 게시',
    '\'피해자\',\'피해 보시는 분들\' 등의 상대방을 가해자로 규정하는 내용 게시',
    '기타 관련법령 및 이용약관, 운영정책에 위배되는 리뷰 게시',
  ];

  TextStyle _bodyStyle(BuildContext context) {
    final t = healthTextScaleByWidth(MediaQuery.sizeOf(context).width);
    return TextStyle(
      color: _text,
      fontSize: healthSp(context, 9),
      fontFamily: _font,
      fontWeight: FontWeight.w300,
      height: 1.45,
      letterSpacing: -0.3 * t,
    );
  }

  TextStyle _titleStyle(BuildContext context) {
    return _bodyStyle(context).copyWith(
      fontSize: healthSp(context, 10),
      fontWeight: FontWeight.w500,
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _bodyStyle(context);
    final title = _titleStyle(context);
    final padH = healthDp(context, 16);
    final padV = healthDp(context, 14);
    final gap = healthDp(context, 8);
    final ruleGap = healthDp(context, 4);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: _bg),
      padding: EdgeInsets.fromLTRB(padH, padV, padH, padV),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('보미오라 리뷰 정책', style: title),
          SizedBox(height: gap),
          Text(_intro, style: body),
          SizedBox(height: gap),
          Text('<리뷰 작성시 금지행위>', style: title),
          SizedBox(height: healthDp(context, 6)),
          for (var i = 0; i < _rules.length; i++) ...[
            if (i > 0) SizedBox(height: ruleGap),
            Text('${i + 1}. ${_rules[i]}', style: body),
          ],
        ],
      ),
    );
  }
}
