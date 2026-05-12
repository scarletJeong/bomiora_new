import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';
import 'btn_more.dart';

/// 홈 섹션 공용 위젯: [HomeSectionTitleRow], 공지·이벤트용 [HomeListSectionHeader] / 행·구분선.

/// 홈 섹션 상단 라벨(검은 세로 띠 + 2줄 타이틀) — Figma 375 기준, [healthDp] / [healthSp] 스케일.
class HomeSectionTitleRow extends StatelessWidget {
  const HomeSectionTitleRow({
    super.key,
    required this.line1,
    required this.line2,
    this.trailing,
  });

  final String line1;
  final String line2;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final barW = healthDp(context, 0.58);
    final gapBarToTitle = healthDp(context, 10);
    final titleLineGap = healthDp(context, 1.15);
    final lineFs = healthSp(context, 16);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: barW,
                color: Colors.black,
              ),
              SizedBox(width: gapBarToTitle),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line1,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: lineFs,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: titleLineGap),
                  Text(
                    line2,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: lineFs,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// 공지 / 이벤트 리스트 상단: 좌측 검은 띠 + 한 줄 타이틀, 우측 `More` 칩.
class HomeListSectionHeader extends StatelessWidget {
  const HomeListSectionHeader({
    super.key,
    required this.title,
    this.onMoreTap,
  });

  final String title;
  final VoidCallback? onMoreTap;

  @override
  Widget build(BuildContext context) {
    final barW = healthDp(context, 0.58);
    final gapBarToTitle = healthDp(context, 10);
    final titleFs = healthSp(context, 16);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: barW,
                color: Colors.black,
              ),
              SizedBox(width: gapBarToTitle),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: titleFs,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        BtnMore(onTap: onMoreTap),
      ],
    );
  }
}

/// 한 줄 제목 + 날짜. [highlight]이면 제목·날짜 모두 핑크.
class HomeListSectionRow extends StatelessWidget {
  const HomeListSectionRow({
    super.key,
    required this.title,
    required this.date,
    this.highlight = false,
    this.onTap,
  });

  final String title;
  final String date;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final titleFs = healthSp(context, 12);
    final dateFs = healthSp(context, 10);
    final fg = highlight ? const Color(0xFFFF5A8D) : Colors.black;

    final rowPad = homeListSectionRowVerticalPadding(context);

    final row = Padding(
      padding: EdgeInsets.symmetric(vertical: rowPad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: titleFs,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                height: 1.33,
              ),
            ),
          ),
          Text(
            date,
            style: TextStyle(
              color: fg,
              fontSize: dateFs,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
    final tap = onTap;
    if (tap == null) return row;
    return InkWell(onTap: tap, child: row);
  }
}

/// Figma 375: 행 블록 내부 세로 여백 (spacing 10.38의 절반에 가깝게).
double homeListSectionRowVerticalPadding(BuildContext context) {
  return healthDp(context, 10.38) / 2;
}

/// 행 사이 점선 구분 (---- 스타일).
class HomeListSectionDashedDivider extends StatelessWidget {
  const HomeListSectionDashedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    const lineColor = Color(0xFFE4BDC2);
    return SizedBox(
      height: healthDp(context, 6),
      width: double.infinity,
      child: CustomPaint(
        painter: _HomeListDashedLinePainter(color: lineColor),
      ),
    );
  }
}

class _HomeListDashedLinePainter extends CustomPainter {
  _HomeListDashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dashLen = 4.0;
    const gapLen = 3.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      final end = (x + dashLen).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(covariant _HomeListDashedLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// 첫 행이 아니면 [homeListSectionRowGap]에 맞춰 위·아래 여백 + 점선.
List<Widget> homeListSectionRowLeadingSeparators(
  BuildContext context,
  int index,
) {
  if (index <= 0) return const <Widget>[];
  final dashH = healthDp(context, 6);
  final gap = homeListSectionRowGap(context);
  final remainder = gap - dashH;
  final half = remainder > 0 ? remainder / 2 : 3.0;
  return <Widget>[
    SizedBox(height: half),
    const HomeListSectionDashedDivider(),
    SizedBox(height: half),
  ];
}

/// 헤더와 리스트 사이 · 행 사이 간격 (Figma 375: 20 / 7.5).
double homeListSectionHeaderBodyGap(BuildContext context) {
  return healthDp(context, 20);
}

double homeListSectionRowGap(BuildContext context) {
  return healthDp(context, 7.5);
}
