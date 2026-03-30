import 'package:flutter/material.dart';

class NewProductSection extends StatelessWidget {
  const NewProductSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 2,
                  height: 40,
                  color: const Color(0xFF28171A),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'New',
                      style: TextStyle(
                        color: Color(0x665B3F43),
                        fontSize: 10,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      'Product',
                      style: TextStyle(
                        color: Color(0xFF28171A),
                        fontSize: 20,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFF5A8D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                  child: const Text(
                    '+ More',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 278,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: const [
                _NewProductCard(
                  title: '보미 다이어트한 신제품 출시!\n보미 다이어트한',
                  discountText: '26%',
                  priceText: '8,888,000원',
                ),
                SizedBox(width: 16),
                _NewProductCard(      
                  title: '대사 활성화를 위한 보미 다이\n어트한 8단계',
                  discountText: '26%',
                  priceText: '8,888,000원',
                ),
                SizedBox(width: 16),
                _NewProductCard(
                  title: '대사 활성화를 위한 보미 다이\n어트한 8단계',
                  discountText: '26%',
                  priceText: '8,888,000원',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewProductCard extends StatelessWidget {
  static const String _description =
      '쉬워지는 다이어트 보미 다이어트환 드디어 7~9단계가 출시됐습니다. 기존 단계로 효과를 못보신 분들께 적합합니다.';

  final String title;
  final String discountText;
  final String priceText;

  const _NewProductCard({
    required this.title,
    required this.discountText,
    required this.priceText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // 카드 너비
      width: 320, 
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 2,
            offset: Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: const ColoredBox(
                  color: Color(0xFFFFE9EA),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF28171A),
                        fontSize: 12,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w600,
                        height: 1.33,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _description,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0x665B3F43),
                                fontSize: 10,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                                height: 1.45,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    discountText,
                                    style: const TextStyle(
                                      color: Color(0xFFB80049),
                                      fontSize: 10,
                                      fontFamily: 'Gmarket Sans TTF',
                                      fontWeight: FontWeight.w700,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    priceText,
                                    style: const TextStyle(
                                      color: Color(0xFF28171A),
                                      fontSize: 10,
                                      fontFamily: 'Gmarket Sans TTF',
                                      fontWeight: FontWeight.w700,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
