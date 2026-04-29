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
  /// true이면 정렬·제외 후 노출할 상품이 없을 때 제목·리스트 전체를 그리지 않음
  final bool hideWhenEmpty;
  /// 섹션 표시 시 상단 여백 (hideWhenEmpty로 숨길 때는 적용 안 함)
  final double topSpacingBefore;
  final bool useGrid2;

  const RecommendProductSection({
    super.key,
    required this.excludedProductNames,
    required this.products,
    required this.onProductTap,
    this.title = '추가 상품 구매하기',
    this.showLeadingBar = true,
    this.hideWhenEmpty = false,
    this.topSpacingBefore = 0,
    this.useGrid2 = false,
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

  _RecommendGroup? _groupFromCategoryId(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) return null;
    if (categoryId.startsWith('10')) return _RecommendGroup.diet;
    if (categoryId.startsWith('20')) return _RecommendGroup.detox;
    if (categoryId.startsWith('80')) return _RecommendGroup.calm;
    return null;
  }

  _RecommendGroup? _groupFromProduct(Product product) {
    // 이름 기반 매칭 누락 케이스를 막기 위해 카테고리 ID를 우선 사용
    return _groupFromCategoryId(product.categoryId) ?? _groupFromName(product.name);
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
      final group = _groupFromProduct(product);
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
    if (widget.hideWhenEmpty && recommended.isEmpty) {
      return const SizedBox.shrink();
    }
    final hasHeader = widget.showLeadingBar || widget.title.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.topSpacingBefore > 0)
          SizedBox(height: widget.topSpacingBefore),
        if (hasHeader) ...[
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
              if (widget.showLeadingBar) const SizedBox(width: 6),
              if (widget.title.trim().isNotEmpty)
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
        ],
        if (recommended.isEmpty)
          Container(
            width: double.infinity,
            height: 120,
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
        else if (widget.useGrid2)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recommended.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              // 카드가 셀을 꽉 채우도록 비율 조정
              childAspectRatio: 0.90,
            ),
            itemBuilder: (context, index) => _RecommendCard(
              product: recommended[index],
              onTap: () => widget.onProductTap(recommended[index]),
            ),
          )
        else
          SizedBox(
            height: 198,
            child: ScrollConfiguration(
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

  String _stripHtml(String? value) {
    if (value == null) return '';
    return value
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Widget _placeholder() {
    return const ColoredBox(
      color: Color(0xFFEFEFEF),
      child: Center(
        child: Icon(Icons.image_not_supported, color: Color(0xFFBDBDBD)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, itemConstraints) {
        final screenW = MediaQuery.sizeOf(context).width;
        final tScale = (screenW / 390.0).clamp(0.88, 1.18);
        const gmarket = 'Gmarket Sans TTF';
        const brandPink = Color(0xFFFF5A8D);

        final namePlain = _stripHtml(product.name);
        final subjectPlain =
            _stripHtml(product.additionalInfo?['it_subject']?.toString());

        final nameFs = (12.5 * tScale).clamp(11.0, 15.0);
        final subjectFs = (10.0 * tScale).clamp(9.0, 12.0);
        final origFs = (10.5 * tScale).clamp(9.5, 12.5);
        final discFs = (11.5 * tScale).clamp(10.5, 14.0);
        final priceFs = (13.5 * tScale).clamp(12.0, 16.0);

        final imageHeight = itemConstraints.hasBoundedHeight
            ? itemConstraints.maxHeight * 2 / 3
            : 220.0;

        return GestureDetector(
          onTap: onTap,
          child: Card(
            elevation: 2,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: imageHeight,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: (product.imageUrl ?? '').trim().isEmpty
                        ? _placeholder()
                        : Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              );
                            },
                          ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              if (subjectPlain.isNotEmpty) ...[
                                Text(
                                  subjectPlain,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: subjectFs,
                                    fontWeight: FontWeight.w400,
                                    fontFamily: gmarket,
                                  ),
                                ),
                                SizedBox(height: 3 * tScale),
                              ],
                              Text(
                                namePlain,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xFF231F20),
                                  fontSize: nameFs,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: gmarket,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (product.originalPrice != null &&
                            product.originalPrice! > product.price) ...[
                          Text(
                            PriceFormatter.format(product.originalPrice!),
                            style: TextStyle(
                              fontSize: origFs,
                              color: Colors.grey[600],
                              decoration: TextDecoration.lineThrough,
                              fontFamily: gmarket,
                            ),
                          ),
                          SizedBox(height: 4 * tScale),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (product.originalPrice != null &&
                                product.originalPrice! > product.price)
                              Text(
                                '${(((product.originalPrice! - product.price) / product.originalPrice!) * 100).round()}%',
                                style: TextStyle(
                                  fontSize: discFs,
                                  color: brandPink,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: gmarket,
                                ),
                              ),
                            if (product.originalPrice != null &&
                                product.originalPrice! > product.price)
                              SizedBox(width: 5 * tScale),
                            Expanded(
                              child: Text(
                                PriceFormatter.format(product.price),
                                style: TextStyle(
                                  fontSize: priceFs,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  fontFamily: gmarket,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if ((product.rating ?? 0) > 0 ||
                                (product.reviewCount ?? 0) > 0) ...[
                              SizedBox(width: 6 * tScale),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: (12.5 * tScale).clamp(11.0, 14.0),
                                    color: const Color(0xFFFFCC00),
                                  ),
                                  SizedBox(width: 2 * tScale),
                                  Text(
                                    '${(product.rating ?? 0).toStringAsFixed(1)}'
                                    '(${product.reviewCount ?? 0})',
                                    style: TextStyle(
                                      fontSize:
                                          (10.5 * tScale).clamp(9.5, 12.0),
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                      fontFamily: gmarket,
                                      height: 1.1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ],
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
      },
    );
  }
}
