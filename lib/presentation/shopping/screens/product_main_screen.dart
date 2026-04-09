import 'package:flutter/material.dart';

import '../../common/widgets/appbar_menutap.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';

class ProductMainScreen extends StatelessWidget {
  const ProductMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.black),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        drawer: AppBarMenuTapDrawer(
          onHealthDashboardTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/health');
          },
        ),
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            child: Center(
              child: Transform.translate(
                // Figma 좌표 기반 Stack이라 미세하게 치우쳐 보일 수 있어,
                // 화면 중앙 기준으로 살짝 보정합니다.
                offset: const Offset(-6, 0),
                child: SizedBox(
                  width: 374.94,
                  height: 3110.52,
                  child: ClipRRect(
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned(
                          left: -54.87,
                          top: -49.43,
                          child: Container(
                            width: 478.89,
                            height: 621.63,
                          ),
                        ),
                        const Positioned(
                          left: 323.31,
                          top: 31.67,
                          child: Text(
                            'KR',
                            style: TextStyle(
                              color: Color(0xFFEFEFEF),
                              fontSize: 6.82,
                              fontFamily: 'Cafe24 Danjunghae',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 45.59,
                          top: 179.85,
                          child: Text(
                            '정대진 대표원장이 수년간 직접 몸을 관리하며',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 15.59,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 31.81,
                          top: 202.85,
                          child: Text(
                            '쌓은 다이어트 노하우와 다수의 임상례를 바탕으로',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 15.59,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 63.39,
                          top: 225.85,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '마침내 만들어진 ',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 15.59,
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                                TextSpan(
                                  text: '[보미 다이어트 솔루션]',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 107.43,
                          top: 267.87,
                          child: Text.rich(
                            TextSpan(
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
                          ),
                        ),
                        const Positioned(
                          left: 120.92,
                          top: 290.87,
                          child: Text(
                            '당신의 아름다운 봄을',
                            style: TextStyle(
                              color: Color(0xFFFF5A8D),
                              fontSize: 15.43,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 99.18,
                          top: 313.87,
                          child: Text(
                            '보미오라와 함께 만나보세요.',
                            style: TextStyle(
                              color: Color(0xFFFF5A8D),
                              fontSize: 15.43,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 77.21,
                          top: 1352.76,
                          child: Text(
                            '믿을 수 있는 든든한 주치의가',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 19.29,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 117.44,
                          top: 1382.76,
                          child: Text(
                            '되어드리겠습니다.',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 19.29,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 62.84,
                          top: 1466.68,
                          child: Container(
                            width: 304.22,
                            height: 535.05,
                          ),
                        ),
                        const Positioned(
                          left: 81.09,
                          top: 1804.05,
                          child: Text(
                            '보미오라한의원│대표원장',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12.74,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 173.80,
                          top: 1867.92,
                          child: Text(
                            '약력',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.76,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 156.96,
                          top: 2240.75,
                          child: Text(
                            '대외활동',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.76,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 62.07,
                          top: 1908.73,
                          child: Text(
                            '서울대학교 보건대학원 최고위과정',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 62.07,
                          top: 1929.73,
                          child: Text(
                            '대한한의학회 정회원',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 62.07,
                          top: 1950.73,
                          child: Text(
                            '대한한방비만학회 정회원',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 62.07,
                          top: 1971.73,
                          child: Text(
                            '대한약침학회 정회원',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 62.07,
                          top: 1992.73,
                          child: Text(
                            '대한한방미용성형학회 정회원',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 62.07,
                          top: 2013.73,
                          child: Text(
                            '한의임상피부과학회 정회원',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 62.07,
                          top: 2034.73,
                          child: Text(
                            '척추신경추나학회 정회원',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 62.07,
                          top: 2055.73,
                          child: Text(
                            '대한미병의학회 정회원',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 62.07,
                          top: 2097.73,
                          child: Text(
                            '코로나19 한의진료센터 공로 표창장',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 62.07,
                          top: 2118.73,
                          child: Text(
                            '국민체육진흥공단 스포츠산업 명예 홍보대사',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 62.07,
                          top: 2139.73,
                          child: Text(
                            '대한민국 베스트브랜드 어워즈 [한방다이어트 부문] 대상',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 62.07,
                          top: 2160.73,
                          child: Text(
                            '대한민국 소비자 만족 브랜드 [한방다이어트 부문] 1위',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 62.07,
                          top: 2181.73,
                          child: Text(
                            '메디타임즈 100대 [한방다이어트 부문] 명의 선정',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 62.07,
                          top: 2281.96,
                          child: Text(
                            '몸짱 한의사로 각종 방송 및 대회, 강연 활동 중',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 62.07,
                          top: 2302.96,
                          child: Text(
                            'KBS, MBC, SBS, JTBC 등 다수 건강 프로그램',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 62.07,
                          top: 2323.96,
                          child: Text(
                            '한의학전문의 패널로 출연',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 62.07,
                          top: 2344.96,
                          child: Text(
                            ' - 기분좋은날 / 나는 몸신이다 / 모란봉클럽 등',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 62.07,
                          top: 2365.96,
                          child: Text(
                            '다수 연예인 및 모델 인플루언서 주치의 ',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 62.07,
                          top: 2386.96,
                          child: Text(
                            '피트니스 대회, 모델 대회 심사위원 활동',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 62.07,
                          top: 2407.96,
                          child: Text(
                            ' - 국내 피트니스 및 모델 대회 다수 수상',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        // 다수 수상 문구 밑 회색 가로선
                        const Positioned(
                          left: 20,
                          top: 2432,
                          child: SizedBox(
                            width: 338,
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0xFFD9D9D9),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 548.21,
                          child: Container(
                            width: 378,
                            height: 661.50,
                          ),
                        ),
                        Positioned(
                          left: 192.35,
                          top: 2521.06,
                          child: Container(
                            width: 148.50,
                            height: 228.50,
                          ),
                        ),
                        Positioned(
                          left: 192.35,
                          top: 2752.94,
                          child: Container(
                            width: 147.49,
                            height: 225.40,
                          ),
                        ),
                        Positioned(
                          left: 35.56,
                          top: 2466.06,
                          child: Container(
                            width: 148.50,
                            height: 228.50,
                          ),
                        ),
                        Positioned(
                          left: 35.56,
                          top: 2697.95,
                          child: Container(
                            width: 147.49,
                            height: 224.91,
                          ),
                        ),
                        const Positioned(
                          left: 41.10,
                          top: 111.30,
                          child: Text(
                            '" 다이어트는 처음부터 쉬워야 해요. "',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 143.83,
                          top: 141.81,
                          child: Text(
                            '정대진 │ 대표원장',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.57,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 71.92,
                          top: 931.04,
                          child: Text(
                            '정대진 원장이 직접 개발한 다이어트 & 디톡스환은',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 90.69,
                          top: 945.44,
                          child: Text(
                            '체지방 감소 및 독소 배출에 도움을 줍니다.',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 171.56,
                          top: 831.35,
                          child: Text(
                            'Point 2',
                            style: TextStyle(
                              color: Color(0xFF999999),
                              fontSize: 9.75,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 92.47,
                          top: 898.90,
                          child: Text(
                            '체지방 감소 및 독소 해소',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 19.49,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 82.54,
                          top: 1120.03,
                          child: Text(
                            '개인의 체질을 본질적으로 개선해 주기 때문에',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 80.35,
                          top: 1134.43,
                          child: Text(
                            '요요 없이 건강하게 다이어트를 할 수 있습니다.',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 171.55,
                          top: 1020.33,
                          child: Text(
                            'Point 3',
                            style: TextStyle(
                              color: Color(0xFF999999),
                              fontSize: 9.75,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 150.59,
                          top: 1087.89,
                          child: Text(
                            '체질 개선',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 19.49,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        // 체질개선 섹션 밑 회색 가로선
                        const Positioned(
                          left: 20,
                          top: 1162,
                          child: SizedBox(
                            width: 338,
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0xFFD9D9D9),
                            ),
                          ),
                        ),

                        // 카테고리 아이콘 버튼 (다이어트/디톡스/심신안정/건강/면역)
                        const Positioned(
                          left: 0,
                          right: 0,
                          top: 1246,
                          child: _CategoryIconRow(),
                        ),

                        // 믿을 수 있는 든든한 주치의 문구 위 회색 가로선
                        const Positioned(
                          left: 20,
                          top: 1328,
                          child: SizedBox(
                            width: 338,
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0xFFD9D9D9),
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 100.61,
                          top: 742.06,
                          child: Text(
                            '다이어트는 개개인의 몸상태와 성격이',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 85.75,
                          top: 756.46,
                          child: Text(
                            '모두 다르기 때문에 1:1코칭이 꼭! 필요합니다.',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.70,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 172.58,
                          top: 642.36,
                          child: Text(
                            'Point 1',
                            style: TextStyle(
                              color: Color(0xFF999999),
                              fontSize: 9.75,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 157.58,
                          top: 709.92,
                          child: Text(
                            '1:1 코칭',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 19.49,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 82.72,
                          top: 577.84,
                          child: Text.rich(
                            TextSpan(
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
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryIconRow extends StatelessWidget {
  const _CategoryIconRow();

  @override
  Widget build(BuildContext context) {
    void goToCategory({
      required String categoryId,
      required String categoryName,
    }) {
      Navigator.pushNamed(
        context,
        '/product/',
        arguments: {
          'categoryId': categoryId,
          'categoryName': categoryName,
          'productKind': 'prescription',
        },
      );
    }

    Widget item({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) {
      return SizedBox(
        width: 78,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD9D9D9)),
                  color: Colors.white,
                ),
                child: Icon(icon, size: 20, color: const Color(0xFF676767)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF676767),
                fontSize: 11,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        item(
          icon: Icons.local_fire_department_outlined,
          label: '다이어트',
          onTap: () => goToCategory(categoryId: '10', categoryName: '다이어트'),
        ),
        item(
          icon: Icons.water_drop_outlined,
          label: '디톡스',
          onTap: () => goToCategory(categoryId: '20', categoryName: '디톡스'),
        ),
        item(
          icon: Icons.self_improvement_outlined,
          label: '심신안정',
          onTap: () => goToCategory(categoryId: '80', categoryName: '심신안정'),
        ),
        item(
          icon: Icons.favorite_border,
          label: '건강/면역',
          onTap: () => goToCategory(categoryId: '50', categoryName: '건강/면역'),
        ),
      ],
    );
  }
}
