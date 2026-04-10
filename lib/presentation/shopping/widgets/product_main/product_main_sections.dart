import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_assets.dart';
import 'product_main_category_icon_row.dart';

const _sectionLineColor = Color(0xFFD9D9D9);

/// 약력 / 대외활동 — 양옆 동일 길이 회색선
Widget _titleWithSideLines(String title) {
  const titleStyle = TextStyle(
    color: Colors.black,
    fontSize: 11.76,
    fontFamily: 'Gmarket Sans TTF',
    fontWeight: FontWeight.w300,
  );
  return Row(
    children: [
      const Expanded(
        child: Divider(
          height: 1,
          thickness: 1,
          color: _sectionLineColor,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(title, style: titleStyle),
      ),
      const Expanded(
        child: Divider(
          height: 1,
          thickness: 1,
          color: _sectionLineColor,
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// 비대면 처방 메인 — 섹션 단위 (한 파일에서 관리)
// ---------------------------------------------------------------------------

/// 다이어트는 처음부터 ~ (히어로 이미지 + 인용 + 소개 + 핑크 문구)
class ProductMainQuoteSection extends StatelessWidget {
  const ProductMainQuoteSection({super.key});

  @override
  Widget build(BuildContext context) {
    final extend = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Transform.translate(
              offset: Offset(0, -extend),
              child: SizedBox(
                width: w,
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    Image.asset(
                      AppAssets.productMain,
                      width: w,
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, __, ___) =>
                          ColoredBox(color: Colors.grey[200]!),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.06),
                              Colors.transparent,
                              Colors.white.withOpacity(0.42),
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '" 다이어트는 처음부터 쉬워야 해요. "',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '정대진 │ 대표원장',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 11.57,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    '정대진 대표원장이 수년간 직접 몸을 관리하며',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 15.59,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '쌓은 다이어트 노하우와 다수의 임상례를 바탕으로',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 15.59,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 15.59,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                        color: Colors.black,
                      ),
                      children: const [
                        TextSpan(text: '마침내 만들어진 '),
                        TextSpan(
                          text: '[보미 다이어트 솔루션]',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text.rich(
                    const TextSpan(
                      children: [
                        TextSpan(
                          text: '보미 다이어트 솔루션',
                          style: TextStyle(
                            color: Color(0xFFFF5A8D),
                            fontSize: 15.43,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: '으로',
                          style: TextStyle(
                            color: Color(0xFFFF5A8D),
                            fontSize: 16,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '당신의 아름다운 봄을',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFFF5A8D),
                      fontSize: 15.43,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '보미오라와 함께 만나보세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFFF5A8D),
                      fontSize: 15.43,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 보미 솔루션 Check Point (Point 1~3, 아이콘은 제목 위)
class ProductMainCheckpointSection extends StatelessWidget {
  const ProductMainCheckpointSection({super.key});

  static const _pointLabelStyle = TextStyle(
    color: Color(0xFF999999),
    fontSize: 9.75,
    fontFamily: 'Gmarket Sans TTF',
    fontWeight: FontWeight.w300,
  );
  static const _titleStyle = TextStyle(
    color: Colors.black,
    fontSize: 19.49,
    fontFamily: 'Gmarket Sans TTF',
    fontWeight: FontWeight.w700,
  );
  static const _bodyStyle = TextStyle(
    color: Colors.black,
    fontSize: 11.70,
    fontFamily: 'Gmarket Sans TTF',
    fontWeight: FontWeight.w300,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text.rich(
            const TextSpan(
              children: [
                TextSpan(
                  text: '보미 솔루션',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 19.29,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
                TextSpan(
                  text: 'Check Point',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _pointColumn(
                  pointLabel: 'Point 1',
                  iconAsset: AppAssets.productMainIcon1,
                  title: '1:1 코칭',
                  bodies: const [
                    '다이어트는 개개인의 몸상태와 성격이',
                    '모두 다르기 때문에 1:1코칭이 꼭! 필요합니다.',
                  ],
                ),
                const SizedBox(height: 28),
                _pointColumn(
                  pointLabel: 'Point 2',
                  iconAsset: AppAssets.productMainIcon2,
                  title: '체지방 감소 및 독소 해소',
                  bodies: const [
                    '정대진 원장이 직접 개발한 다이어트 & 디톡스환은',
                    '체지방 감소 및 독소 배출에 도움을 줍니다.',
                  ],
                ),
                const SizedBox(height: 28),
                _pointColumn(
                  pointLabel: 'Point 3',
                  iconAsset: AppAssets.productMainIcon3,
                  title: '체질 개선',
                  bodies: const [
                    '개인의 체질을 본질적으로 개선해 주기 때문에',
                    '요요 없이 건강하게 다이어트를 할 수 있습니다.',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pointColumn({
    required String pointLabel,
    required String iconAsset,
    required String title,
    required List<String> bodies,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(pointLabel, style: _pointLabelStyle, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        SizedBox(
          width: 56,
          height: 56,
          child: SvgPicture.asset(iconAsset, fit: BoxFit.contain),
        ),
        const SizedBox(height: 12),
        Text(title, style: _titleStyle, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        ...bodies.map(
          (line) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              line,
              style: _bodyStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

/// 믿을 수 있는 든든한 ~ (분홍 구분선 + 카테고리 + 회색 구분선 + 카피)
class ProductMainTrustSection extends StatelessWidget {
  const ProductMainTrustSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFFF5A8D),
          ),
        ),
        const SizedBox(height: 20),
        const ProductMainCategoryIconRow(),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFD9D9D9),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          '믿을 수 있는 든든한 주치의가',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 19.29,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '되어드리겠습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 19.29,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// 원장 사진 영역 + 약력 + 대외활동 + 하단 2×2 이미지
class ProductMainPhotoBioSection extends StatelessWidget {
  const ProductMainPhotoBioSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 304),
              height: 280,
              color: const Color(0xFFF0F0F0),
              alignment: Alignment.center,
              child: Icon(Icons.person_outline, size: 72, color: Colors.grey[400]),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '보미오라한의원│대표원장',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontSize: 12.74,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 24),
          _titleWithSideLines('약력'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _cvLines
                  .map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        t,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 11.70,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          _titleWithSideLines('대외활동'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _activityLines
                  .map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        t,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 11.70,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 60),
          _StaggeredBottomGrid(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static const _cvLines = [
    '서울대학교 보건대학원 최고위과정',
    '대한한의학회 정회원',
    '대한한방비만학회 정회원',
    '대한약침학회 정회원',
    '대한한방미용성형학회 정회원',
    '한의임상피부과학회 정회원',
    '척추신경추나학회 정회원',
    '대한미병의학회 정회원',
    '코로나19 한의진료센터 공로 표창장',
    '국민체육진흥공단 스포츠산업 명예 홍보대사',
    '대한민국 베스트브랜드 어워즈 [한방다이어트 부문] 대상',
    '대한민국 소비자 만족 브랜드 [한방다이어트 부문] 1위',
    '메디타임즈 100대 [한방다이어트 부문] 명의 선정',
  ];

  static const _activityLines = [
    '몸짱 한의사로 각종 방송 및 대회, 강연 활동 중',
    'KBS, MBC, SBS, JTBC 등 다수 건강 프로그램',
    '한의학전문의 패널로 출연',
    ' - 기분좋은날 / 나는 몸신이다 / 모란봉클럽 등',
    '다수 연예인 및 모델 인플루언서 주치의 ',
    '피트니스 대회, 모델 대회 심사위원 활동',
    ' - 국내 피트니스 및 모델 대회 다수 수상',
  ];
}

class _StaggeredBottomGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const colW = 158.0;
    const gap = 10.0;
    const cellH = 210.0;
    const stagger = 32.0;
    const rowGap = 12.0;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final leftW = (w - gap) / 2;
        final scale = leftW / colW;
        final h = cellH * scale;
        final g = gap;
        final rg = rowGap * scale;
        final st = stagger * scale;

        Widget cell(String asset) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: leftW / h,
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    ColoredBox(color: Colors.grey[200]!),
              ),
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  cell(AppAssets.productMainBottom1),
                  SizedBox(height: rg),
                  cell(AppAssets.productMainBottom3),
                ],
              ),
            ),
            SizedBox(width: g),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: st),
                child: Column(
                  children: [
                    cell(AppAssets.productMainBottom2),
                    SizedBox(height: rg),
                    cell(AppAssets.productMainBottom4),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
