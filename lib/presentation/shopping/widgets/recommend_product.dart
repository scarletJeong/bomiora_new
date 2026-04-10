import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../../core/utils/price_formatter.dart';
import '../../../data/models/product/product_model.dart';

enum _RecommendGroup { diet, detox, calm }

class RecommendProductSection extends StatefulWidget {
  final List<String> excludedProductNames;
  final List<Product> products;
  final ValueChanged<Product> onProductTap;
  final String title;
  final bool showLeadingBar;

  const RecommendProductSection({
    super.key,
    required this.excludedProductNames,
    required this.products,
    required this.onProductTap,
    this.title = '추가 상품 구매하기',
    this.showLeadingBar = true,
  });

  @override
  State<RecommendProductSection> createState() => _RecommendProductSectionState();
}

class _RecommendProductSectionState extends State<RecommendProductSection> {
  final ScrollController _horizontalScroll = ScrollController();

  @override
  void dispose() {
    _horizontalScroll.dispose();
    super.dispose();
  }

  _RecommendGroup? _groupFromName(String name) {
    final normalized = name.replaceAll(' ', '');
    if (normalized.contains('다이어트')) return _RecommendGroup.diet;
    if (normalized.contains('디톡스')) return _RecommendGroup.detox;
    if (normalized.contains('심신안정')) return _RecommendGroup.calm;
    return null;
  }

  List<Product> _buildOrderedRecommendations() {
    final selectedGroups = <_RecommendGroup>{};
    for (final productName in widget.excludedProductNames) {
      final group = _groupFromName(productName);
      if (group != null) {
        selectedGroups.add(group);
      }
    }

    final desiredOrder = <_RecommendGroup>[
      _RecommendGroup.diet,
      _RecommendGroup.detox,
      _RecommendGroup.calm,
    ];

    final byGroup = <_RecommendGroup, List<Product>>{};
    for (final product in widget.products) {
      final group = _groupFromName(product.name);
      if (group == null) continue;
      if (selectedGroups.contains(group)) continue;
      byGroup.putIfAbsent(group, () => <Product>[]).add(product);
    }

    final ordered = <Product>[];
    for (final group in desiredOrder) {
      if (selectedGroups.contains(group)) continue;
      ordered.addAll(byGroup[group] ?? const <Product>[]);
    }
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final recommended = _buildOrderedRecommendations();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (widget.showLeadingBar)
              const Text(
                '|',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            const SizedBox(width: 6),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 198,
          child: recommended.isEmpty
              ? Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x7FD2D2D2)),
                  ),
                  child: const Text(
                    '추천 상품이 없습니다.',
                    style: TextStyle(fontSize: 13),
                  ),
                )
              : ScrollConfiguration(
                  behavior: const _HorizontalDragScrollBehavior(),
                  child: Scrollbar(
                    controller: _horizontalScroll,
                    thumbVisibility: true,
                    child: ListView.separated(
                      controller: _horizontalScroll,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) => _RecommendCard(
                        product: recommended[index],
                        onTap: () => widget.onProductTap(recommended[index]),
                      ),
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemCount: recommended.length,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _HorizontalDragScrollBehavior extends MaterialScrollBehavior {
  const _HorizontalDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class _RecommendCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _RecommendCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 156,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x7FD2D2D2), width: 0.5),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              child: Image.network(
                product.imageUrl ?? '',
                width: 156,
                height: 128,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 156,
                  height: 128,
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.ctKind == 'prescription' ? '한의약품' : '일반상품',
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    PriceFormatter.format(product.price),
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
