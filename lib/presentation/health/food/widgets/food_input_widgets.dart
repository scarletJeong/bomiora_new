import 'package:flutter/material.dart';

/// 칼로리 검색 입력 + 검색 결과 카드 블록 (각 식사 카드 아래에 배치)
class CalorieSearchBlock extends StatelessWidget {
  const CalorieSearchBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '칼로리 검색',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          height: 35,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(width: 1, color: const Color(0xFFD2D2D2)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Expanded(
                child: Text(
                  '음식을 입력하세요..',
                  style: TextStyle(
                    color: Color(0xFF898383),
                    fontSize: 14,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              Icon(Icons.search, color: Color(0xFF898383), size: 18),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SearchResultCard(
          name: '치킨 샐러드',
          kcal: 135,
          desc: '(지방 2g, 단백질 11g)',
        ),
        const SizedBox(height: 6),
        SearchResultCard(
          name: '아몬드 브리즈(190ml)',
          kcal: 60,
          desc: '(단백질 1.2g)',
        ),
      ],
    );
  }
}

class SearchResultCard extends StatelessWidget {
  final String name;
  final int kcal;
  final String desc;

  const SearchResultCard({
    super.key,
    required this.name,
    required this.kcal,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Color(0x19000000), blurRadius: 4.17),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$kcal kcal',
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 10,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 8,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.add, size: 14, color: Color(0xFF898383)),
        ],
      ),
    );
  }
}

class MacroLegend extends StatelessWidget {
  final Color color;
  final String label;

  const MacroLegend({
    super.key,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16.23,
          height: 16.23,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 10,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}
