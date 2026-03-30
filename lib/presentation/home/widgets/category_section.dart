import 'package:flutter/material.dart';

class CategorySection extends StatefulWidget {
  const CategorySection({super.key});

  @override
  State<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<CategorySection>
    with SingleTickerProviderStateMixin {
  static const List<String> _tabs = [
    '다이어트',
    '디톡스',
    '건강/면역',
    '뷰티/코스메틱',
    '헤어/탈모',
  ];
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
                    height: 44,
                    color: const Color(0xFF28171A),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'new',
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
                        'Category',
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
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: EdgeInsets.zero,
                indicatorColor: Color(0xFFFF5A8D),
                indicatorWeight: 2,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                tabs: List.generate(_tabs.length, (index) {
                  final bool selected = _tabController.index == index;
                  return Tab(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _tabs[index],
                            style: TextStyle(
                              color: selected
                                  ? const Color(0xFFFF5A8D)
                                  : const Color(0xFF28171A),
                              fontSize: 14,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          if (index != _tabs.length - 1) ...[
                            const SizedBox(width: 8),
                            const Text(
                              '|',
                              style: TextStyle(
                                color: Color(0xFFBDBDBD),
                                fontSize: 14,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 278,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  const _NewProductCard(
                    title: '보미 다이어트한 신제품 출시!\n보미 다이어트한',
                    discountText: '26%',
                    priceText: '8,888,000원',
                  ),
                  const SizedBox(width: 16),
                  const _NewProductCard(
                    title: '대사 활성화를 위한 보미 다이\n어트한 8단계',
                    discountText: '26%',
                    priceText: '8,888,000원',
                  ),
                  const SizedBox(width: 16),
                  const _NewProductCard(
                    title: '대사 활성화를 위한 보미 다이\n어트한 8단계',
                    discountText: '26%',
                    priceText: '8,888,000원',
                  ),
                  const SizedBox(width: 16),
                  _AddCard(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('디자인중')),
                      );
                    },
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
      width: 192,
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
                      child: Text(
                        _description,
                        maxLines: 3,
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
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddCard({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 192,
      height: 278,
      child: Align(
        alignment: Alignment.topCenter,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: 192,
            height: 160,
            decoration: ShapeDecoration(
              color: const Color(0xFFF9F9F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.add,
                color: Color(0xFFFF5A8D),
                size: 36,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
