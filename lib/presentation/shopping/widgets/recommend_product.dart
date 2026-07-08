import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../../data/models/product/product_model.dart';
import '../../common/widgets/product_card.dart';
import '../../health/health_common/health_responsive_scale.dart';

/// 상품 상세 tail·추천상품 등 섹션 제목 공통 스타일
TextStyle shoppingSectionTitleStyle(BuildContext context) => TextStyle(
      color: const Color(0xFF1A1A1A),
      fontSize: healthSp(context, 16),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w300,
      letterSpacing: healthSp(context, -1.44),
    );

/// [ProductListScreen] 그리드와 동일 비율: 열 간격 `healthDp(12)`, `childAspectRatio: 0.58`.
/// 부모가 이미 좌우 패딩을 두었으므로 여기서는 `maxWidth` 전체로 2열 폭을 맞춤.
({double cellWidth, double cellHeight, double crossGap})
    _recommendCatalogMetrics(BuildContext context, double maxWidth) {
  final crossGap = healthDp(context, 12);
  final inner = maxWidth.clamp(0.0, double.infinity);
  final cellWidth = inner > crossGap
      ? (inner - crossGap) / 2
      : (inner * 0.45).clamp(80.0, 200.0);
  final cellHeight = ProductCatalogCard.preferredMainAxisExtent(context);
  return (
    cellWidth: cellWidth,
    cellHeight: cellHeight,
    crossGap: crossGap,
  );
}

enum _RecommendGroup { diet, detox, calm }

class RecommendProductSection extends StatefulWidget {
  final List<String> excludedProductNames;
  final List<Product> products;
  final ValueChanged<Product> onProductTap;
  final String title;
  final bool showLeadingBar;
  final TextStyle? titleStyle;
  /// true이면 정렬·제외 후 노출할 상품이 없을 때 제목·리스트 전체를 그리지 않음
  final bool hideWhenEmpty;
  /// 섹션 표시 시 상단 여백 (hideWhenEmpty로 숨길 때는 적용 안 함)
  final double topSpacingBefore;
  final bool useGrid2;
  /// true이면 1열 세로 리스트 (상품 상세 하단 추천 등)
  final bool useVerticalList;
  /// false이면 [products]를 처방 그룹 정렬 없이 그대로 노출 (일반 MD Pick 등)
  final bool prescriptionGroupOrdering;
  /// 가로 리스트 최대 개수
  final int? maxItems;
  /// 가로 한 화면에 보이는 카드 수 (기본 2.0, MD Pick은 2.1 등)
  final double? itemsPerViewport;
  /// 가로 카드 사이 간격 (null이면 목록 그리드와 동일 12)
  final double? horizontalGap;
  /// 가로 카드 축소 비율 (1.0=기본, 2/3=1/3 축소)
  final double cardScale;

  const RecommendProductSection({
    super.key,
    required this.excludedProductNames,
    required this.products,
    required this.onProductTap,
    this.title = '추가 상품 구매하기',
    this.showLeadingBar = true,
    this.titleStyle,
    this.hideWhenEmpty = false,
    this.topSpacingBefore = 0,
    this.useGrid2 = false,
    this.useVerticalList = false,
    this.prescriptionGroupOrdering = true,
    this.maxItems,
    this.itemsPerViewport,
    this.horizontalGap,
    this.cardScale = 1.0,
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
    if (!widget.prescriptionGroupOrdering) {
      var list = widget.products;
      final limit = widget.maxItems;
      if (limit != null && limit > 0) {
        list = list.take(limit).toList();
      }
      return list;
    }

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.showLeadingBar)
                Container(
                  width: 1,
                  height: 14,
                  margin: const EdgeInsets.only(right: 6),
                  color: const Color(0xFF1A1A1A),
                ),
              if (widget.title.trim().isNotEmpty)
                Text(
                  widget.title,
                  style:
                      widget.titleStyle ?? shoppingSectionTitleStyle(context),
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
        else if (widget.useVerticalList)
          Column(
            children: [
              for (var i = 0; i < recommended.length; i++) ...[
                if (i > 0) SizedBox(height: healthDp(context, 16)),
                ProductCatalogCard(
                  product: recommended[i],
                  onTap: () => widget.onProductTap(recommended[i]),
                ),
              ],
            ],
          )
        else if (widget.useGrid2)
          LayoutBuilder(
            builder: (context, constraints) {
              final m =
                  _recommendCatalogMetrics(context, constraints.maxWidth);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recommended.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: m.crossGap,
                  mainAxisSpacing: healthDp(context, 16),
                  mainAxisExtent:
                      ProductCatalogCard.preferredMainAxisExtent(context),
                ),
                itemBuilder: (context, index) => ProductCatalogCard(
                  product: recommended[index],
                  onTap: () => widget.onProductTap(recommended[index]),
                ),
              );
            },
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final crossGap =
                  widget.horizontalGap ?? healthDp(context, 12);
              final inner = constraints.maxWidth.clamp(0.0, double.infinity);
              final perView = widget.itemsPerViewport;
              final scale = widget.cardScale.clamp(0.4, 1.0);
              final baseCellWidth = perView != null && perView > 0
                  ? inner / perView
                  : (inner > crossGap
                      ? (inner - crossGap) / 2
                      : (inner * 0.45).clamp(80.0, 200.0));
              final baseCellHeight =
                  ProductCatalogCard.preferredMainAxisExtent(context);
              final cellWidth = baseCellWidth * scale;
              final cellHeight = baseCellHeight * scale;
              return SizedBox(
                height: cellHeight,
                child: ScrollConfiguration(
                  behavior: const _HorizontalDragScrollBehavior(),
                  child: Scrollbar(
                    controller: _horizontalScroll,
                    thumbVisibility: true,
                    child: ListView.separated(
                      controller: _horizontalScroll,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        return SizedBox(
                          width: cellWidth,
                          height: cellHeight,
                          child: Transform.scale(
                            scale: scale,
                            alignment: Alignment.topLeft,
                            child: SizedBox(
                              width: baseCellWidth,
                              height: baseCellHeight,
                              child: ProductCatalogCard(
                                product: recommended[index],
                                onTap: () =>
                                    widget.onProductTap(recommended[index]),
                              ),
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) =>
                          SizedBox(width: crossGap * scale),
                      itemCount: recommended.length,
                    ),
                  ),
                ),
              );
            },
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
