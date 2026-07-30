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

/// 추천 상품 카탈로그 종류
enum RecommendCatalogKind {
  /// 비대면: 다이어트 → 디톡스 → 체험분 → 단백질쉐이크 → 심신안정 → MD픽
  prescription,

  /// 일반: 다이어트 → 디톡스 → 단백질쉐이크
  general,
}

enum _RecommendSlot {
  diet,
  detox,
  dietTrial,
  detoxTrial,
  proteinShake,
  calm,
  mdPick,
  influencer,
}

/// 추천 상품 노출 순서 규칙 (상세/장바구니 공통)
///
/// 【공통】현재 상품 + 장바구니 상품 ID는 추천에서 제외
///        (비대면·일반·인플루언서 전부)
/// 【공통】장바구니에 있는 카테고리 슬롯은 스킵
///
/// 비대면 기본: 다이어트 → 디톡스 → 체험(다/디) → 단백질 → 심신안정 → MD (최대 3)
/// 담은 조합별 분기는 [_prescriptionSlotOrder] / 백엔드 buildPrescriptionRecommendSlotOrder
/// 일반 + 단백질 미보유: 단백질 → 다 → 디 → …
/// 인플루언서: 최근 본 인프 순 다른 상품 → (갯수에 따라) 다체험·디체험·단백질·심신·MD
///   `influencer_101` 은 목록에서 제외. 101만 있으면 MD만.
///   진행 2개 이하: … → 다체험 → 디체험 → 단백질 → 심신 → MD
///   진행 3개 이상: … → 다체험 → 디체험 → MD
abstract final class RecommendProductOrdering {
  RecommendProductOrdering._();

  static const String specialMdOnlyInfluencerMbId = 'influencer_101';
  static const int defaultMaxItems = 3;

  static List<Product> build({
    required List<Product> products,
    RecommendCatalogKind catalogKind = RecommendCatalogKind.prescription,
    String? influencerMbId,
    List<String> excludedProductNames = const [],
    Set<String> excludedProductIds = const {},
    Product? currentProduct,
    List<Product> ownedProducts = const [],
    int maxItems = defaultMaxItems,
  }) {
    final excludedGroups = <_RecommendSlot>{};
    for (final name in excludedProductNames) {
      final g = _slotFromName(name);
      if (g != null) excludedGroups.add(g);
    }
    // 장바구니(owned) 슬롯 스킵.
    // 장바구니가 비어 있지 않으면 지금 보는 상품 슬롯도 스킵
    // (예: 다체험+디톡스 담김 + 다이어트 상세 → 디체험→단백질→심신→MD)
    for (final p in ownedProducts) {
      final g = _slotFromProduct(p);
      if (g != null) excludedGroups.add(g);
    }
    if (ownedProducts.isNotEmpty && currentProduct != null) {
      final g = _slotFromProduct(currentProduct);
      if (g != null) excludedGroups.add(g);
    }

    final ownedIds = {
      ...excludedProductIds,
      ...ownedProducts.map((p) => p.id),
      if (currentProduct != null) currentProduct.id,
    };

    final pool = products.where((p) => !ownedIds.contains(p.id)).toList();

    final influencerOrder = _influencerOrderRecentFirst(
      currentProduct: currentProduct,
      ownedProducts: ownedProducts,
      fallbackMbId: influencerMbId,
    );

    if (influencerOrder.isNotEmpty) {
      final counts = _influencerProductCounts(products);
      return _buildInfluencerOrder(
        pool: pool,
        influencerOrder: influencerOrder,
        influencerCounts: counts,
        excludedGroups: excludedGroups,
      );
    }

    final currentInf = _mbInfOf(currentProduct) ?? (influencerMbId ?? '').trim();
    if (currentInf == specialMdOnlyInfluencerMbId) {
      return _pickFirstPerSlots(
        pool: pool,
        slots: const [_RecommendSlot.mdPick],
        excludedGroups: excludedGroups,
        maxItems: maxItems,
        generalCatalog: false,
      );
    }

    // 일반·비대면: 슬롯 순서는 카탈로그에 따라 분기
    // 일반 + 단백질 미보유 → 단백질 우선 / 비대면 → 다→디→체험→단백질…
    return _pickFirstPerSlots(
      pool: pool,
      slots: _prescriptionSlotOrder(
        excludedGroups,
        currentSlot: currentProduct != null
            ? _slotFromProduct(currentProduct)
            : null,
        proteinFirstIfEmpty: catalogKind == RecommendCatalogKind.general,
      ),
      excludedGroups: excludedGroups,
      maxItems: maxItems,
      generalCatalog: catalogKind == RecommendCatalogKind.general,
    );
  }

  static String? _mbInfOf(Product? p) {
    if (p == null) return null;
    final mb = Product.readItMbInfFromMap({
      if (p.additionalInfo != null) ...p.additionalInfo!,
      'additionalInfo': p.additionalInfo,
    });
    return (mb ?? '').trim();
  }

  static List<String> _influencerOrderRecentFirst({
    Product? currentProduct,
    required List<Product> ownedProducts,
    String? fallbackMbId,
  }) {
    const hide = specialMdOnlyInfluencerMbId;
    final order = <String>[];
    final seen = <String>{};

    void push(String? raw) {
      final id = (raw ?? '').trim();
      if (id.isEmpty || id == '0' || id == hide || seen.contains(id)) return;
      seen.add(id);
      order.add(id);
    }

    push(_mbInfOf(currentProduct));
    for (var i = ownedProducts.length - 1; i >= 0; i--) {
      push(_mbInfOf(ownedProducts[i]));
    }
    if (order.isEmpty) push(fallbackMbId);
    return order;
  }

  static Map<String, int> _influencerProductCounts(List<Product> products) {
    final counts = <String, int>{};
    for (final p in products) {
      final mb = _mbInfOf(p);
      if (mb == null || mb.isEmpty || mb == specialMdOnlyInfluencerMbId) {
        continue;
      }
      counts[mb] = (counts[mb] ?? 0) + 1;
    }
    return counts;
  }

  /// 기본: 다 → 디 → 다체험 → 디체험 → 단백질 → 심신 → MD
  /// 호출측에서 [skip](보유 슬롯) 제외.
  ///
  /// 예외:
  ///  1) 일반 + 비대면 없음 + 단백질 없음 → 단백질 우선
  ///  2) 다+디 + 현재≠다계열 → 디체험 ↔ 다체험
  ///  3) 다+단백질(디 없음) → 디체험 ↔ 다체험
  static List<_RecommendSlot> _prescriptionSlotOrder(
    Set<_RecommendSlot> skip, {
    _RecommendSlot? currentSlot,
    bool proteinFirstIfEmpty = false,
  }) {
    bool has(_RecommendSlot s) => skip.contains(s);
    final hasDiet = has(_RecommendSlot.diet);
    final hasDetox = has(_RecommendSlot.detox);
    final hasProtein = has(_RecommendSlot.proteinShake);
    final hasAnyRx = hasDiet ||
        hasDetox ||
        has(_RecommendSlot.dietTrial) ||
        has(_RecommendSlot.detoxTrial) ||
        has(_RecommendSlot.calm);

    const base = [
      _RecommendSlot.diet,
      _RecommendSlot.detox,
      _RecommendSlot.dietTrial,
      _RecommendSlot.detoxTrial,
      _RecommendSlot.proteinShake,
      _RecommendSlot.calm,
      _RecommendSlot.mdPick,
    ];

    // 예외 1: 일반 상세 + 비대면 없음 + 단백질 없음
    if (!hasAnyRx && !hasProtein && proteinFirstIfEmpty) {
      return const [
        _RecommendSlot.proteinShake,
        _RecommendSlot.diet,
        _RecommendSlot.detox,
        _RecommendSlot.dietTrial,
        _RecommendSlot.detoxTrial,
        _RecommendSlot.calm,
        _RecommendSlot.mdPick,
      ];
    }

    var order = List<_RecommendSlot>.from(base);

    List<_RecommendSlot> swapTrials(List<_RecommendSlot> arr) {
      final i1 = arr.indexOf(_RecommendSlot.dietTrial);
      final i2 = arr.indexOf(_RecommendSlot.detoxTrial);
      if (i1 < 0 || i2 < 0) return arr;
      final next = List<_RecommendSlot>.from(arr);
      next[i1] = _RecommendSlot.detoxTrial;
      next[i2] = _RecommendSlot.dietTrial;
      return next;
    }

    // 예외 2: 다+디 → 현재가 다 계열이 아니면 디체험 우선
    if (hasDiet && hasDetox) {
      final dietFamily = currentSlot == _RecommendSlot.diet ||
          currentSlot == _RecommendSlot.dietTrial;
      if (!dietFamily) order = swapTrials(order);
    } else if (hasDiet && hasProtein && !hasDetox) {
      // 예외 3: 다+단백질(디 없음) → 디체험 우선
      order = swapTrials(order);
    }

    return order;
  }

  static Product? _firstMatching(
    List<Product> pool,
    Set<String> used,
    _RecommendSlot slot, {
    required bool generalCatalog,
  }) {
    for (final p in pool) {
      if (used.contains(p.id)) continue;
      if (_matchesSlot(p, slot: slot, generalCatalog: generalCatalog)) return p;
    }
    return null;
  }

  static List<Product> _buildInfluencerOrder({
    required List<Product> pool,
    required List<String> influencerOrder,
    required Map<String, int> influencerCounts,
    required Set<_RecommendSlot> excludedGroups,
  }) {
    final out = <Product>[];
    final used = <String>{};

    for (final infId in influencerOrder) {
      for (final p in pool) {
        if (used.contains(p.id)) continue;
        final mb = _mbInfOf(p);
        if (mb != infId) continue;
        if (_isTrial(p.name)) continue;
        out.add(p);
        used.add(p.id);
      }
    }

    final anyHasThreeOrMore =
        influencerOrder.any((id) => (influencerCounts[id] ?? 0) >= 3);

    late final List<_RecommendSlot> fillSlots;
    if (influencerOrder.length <= 1) {
      final cnt = influencerCounts[influencerOrder.first] ?? 0;
      fillSlots = cnt >= 3
          ? const [
              _RecommendSlot.dietTrial,
              _RecommendSlot.detoxTrial,
              _RecommendSlot.mdPick,
            ]
          : const [
              _RecommendSlot.dietTrial,
              _RecommendSlot.detoxTrial,
              _RecommendSlot.proteinShake,
              _RecommendSlot.calm,
              _RecommendSlot.mdPick,
            ];
    } else if (anyHasThreeOrMore) {
      fillSlots = const [
        _RecommendSlot.dietTrial,
        _RecommendSlot.detoxTrial,
        _RecommendSlot.mdPick,
      ];
    } else {
      fillSlots = const [
        _RecommendSlot.dietTrial,
        _RecommendSlot.detoxTrial,
        _RecommendSlot.proteinShake,
        _RecommendSlot.calm,
        _RecommendSlot.mdPick,
      ];
    }

    void addSlot(_RecommendSlot slot) {
      if (excludedGroups.contains(slot)) return;
      final hit = _firstMatching(
        pool,
        used,
        slot,
        generalCatalog: false,
      );
      if (hit == null) return;
      out.add(hit);
      used.add(hit.id);
    }

    for (final slot in fillSlots) {
      addSlot(slot);
    }
    return out;
  }

  static List<Product> _pickFirstPerSlots({
    required List<Product> pool,
    required List<_RecommendSlot> slots,
    required Set<_RecommendSlot> excludedGroups,
    required int maxItems,
    required bool generalCatalog,
  }) {
    final out = <Product>[];
    final used = <String>{};

    for (final slot in slots) {
      if (out.length >= maxItems) break;
      if (excludedGroups.contains(slot)) continue;
      final hit = _firstMatching(
        pool,
        used,
        slot,
        generalCatalog: generalCatalog,
      );
      if (hit == null) continue;
      out.add(hit);
      used.add(hit.id);
    }
    return out;
  }

  static bool _isTrial(String name) {
    final n = name.replaceAll(' ', '');
    return n.contains('체험분') || n.contains('체험');
  }

  static bool _isProteinShake(Product p) {
    // 다이어트(ca 10)처럼 단백질 카테고리(a0)만
    final ca = p.categoryId.trim().toLowerCase();
    return ca == 'a0' || ca.startsWith('a0');
  }

  static bool _isMdPick(Product p) {
    final info = p.additionalInfo;
    final raw = info?['it_type5'] ?? info?['itType5'] ?? info?['is_md_product'];
    if (raw == true) return true;
    final s = raw?.toString().trim() ?? '';
    if (s == '1' || s.toLowerCase() == 'true') return true;
    return false;
  }

  static bool _isDietTrial(Product p) {
    if (!_isTrial(p.name)) return false;
    final ca = p.categoryId.trim().toLowerCase();
    final n = p.name.replaceAll(' ', '');
    return n.contains('다이어트') ||
        ca.startsWith('10') ||
        ca.startsWith('11');
  }

  static bool _isDetoxTrial(Product p) {
    if (!_isTrial(p.name)) return false;
    final ca = p.categoryId.trim().toLowerCase();
    final n = p.name.replaceAll(' ', '');
    return n.contains('디톡스') ||
        ca.startsWith('20') ||
        ca.startsWith('21');
  }

  static _RecommendSlot? _slotFromName(String name) {
    final n = name.replaceAll(' ', '');
    final trial = _isTrial(name);
    if (trial) {
      if (n.contains('디톡스')) return _RecommendSlot.detoxTrial;
      if (n.contains('다이어트')) return _RecommendSlot.dietTrial;
      return null;
    }
    if (n.contains('단백질') || n.contains('쉐이크') || n.contains('셰이크')) {
      return _RecommendSlot.proteinShake;
    }
    if (n.contains('심신안정')) return _RecommendSlot.calm;
    if (n.contains('디톡스')) return _RecommendSlot.detox;
    if (n.contains('다이어트')) return _RecommendSlot.diet;
    return null;
  }

  static _RecommendSlot? _slotFromProduct(Product p) {
    if (_isDetoxTrial(p)) return _RecommendSlot.detoxTrial;
    if (_isDietTrial(p)) return _RecommendSlot.dietTrial;
    if (_isTrial(p.name)) return null;
    if (_isProteinShake(p)) return _RecommendSlot.proteinShake;
    final ca = p.categoryId.trim().toLowerCase();
    final n = p.name.replaceAll(' ', '');
    if (ca.startsWith('80') || n.contains('심신안정')) {
      return _RecommendSlot.calm;
    }
    if (ca.startsWith('20') || ca.startsWith('21') || n.contains('디톡스')) {
      return _RecommendSlot.detox;
    }
    if (ca.startsWith('10') || ca.startsWith('11') || n.contains('다이어트')) {
      return _RecommendSlot.diet;
    }
    if (_isMdPick(p)) return _RecommendSlot.mdPick;
    return null;
  }

  static bool _matchesSlot(
    Product p, {
    required _RecommendSlot slot,
    required bool generalCatalog,
  }) {
    final ca = p.categoryId.trim().toLowerCase();
    final kind = (p.productKind ?? '').trim().toLowerCase();

    switch (slot) {
      case _RecommendSlot.diet:
        if (_isTrial(p.name) || _isProteinShake(p)) return false;
        if (generalCatalog) {
          return ca.startsWith('11') ||
              (kind == 'general' &&
                  p.name.replaceAll(' ', '').contains('다이어트'));
        }
        return ca.startsWith('10') ||
            (kind != 'general' &&
                p.name.replaceAll(' ', '').contains('다이어트') &&
                !_isTrial(p.name));
      case _RecommendSlot.detox:
        if (_isTrial(p.name) || _isProteinShake(p)) return false;
        if (generalCatalog) {
          return ca.startsWith('21') ||
              (kind == 'general' &&
                  p.name.replaceAll(' ', '').contains('디톡스'));
        }
        return ca.startsWith('20') ||
            (kind != 'general' &&
                p.name.replaceAll(' ', '').contains('디톡스') &&
                !_isTrial(p.name));
      case _RecommendSlot.dietTrial:
        return _isDietTrial(p);
      case _RecommendSlot.detoxTrial:
        return _isDetoxTrial(p);
      case _RecommendSlot.proteinShake:
        return _isProteinShake(p);
      case _RecommendSlot.calm:
        if (_isTrial(p.name)) return false;
        return ca.startsWith('80') ||
            p.name.replaceAll(' ', '').contains('심신안정');
      case _RecommendSlot.mdPick:
        return _isMdPick(p);
      case _RecommendSlot.influencer:
        return p.isInfluencerProduct;
    }
  }
}

// 목륵을 uj 로 그리는 곳?
class RecommendProductSection extends StatefulWidget {
  final List<String> excludedProductNames;
  final List<Product> products;
  final ValueChanged<Product> onProductTap;
  final String title;
  final bool showLeadingBar;
  final TextStyle? titleStyle;
  final bool hideWhenEmpty;
  final double topSpacingBefore;
  final bool useGrid2;
  final bool useVerticalList;
  /// false이면 [products]를 그룹 정렬 없이 그대로 노출 (홈 MD Pick 등)
  final bool prescriptionGroupOrdering;
  final RecommendCatalogKind catalogKind;
  final String? influencerMbId;
  /// 현재 상세 상품 — 해당 카테고리 슬롯 제외
  final Product? currentProduct;
  /// 장바구니 보유 상품 — 각 카테고리 슬롯도 제외
  final List<Product> ownedProducts;
  final int? maxItems;
  final double? itemsPerViewport;
  final double? horizontalGap;
  final double cardScale;
  final double? leadingBarHeight;

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
    this.catalogKind = RecommendCatalogKind.prescription,
    this.influencerMbId,
    this.currentProduct,
    this.ownedProducts = const [],
    this.maxItems,
    this.itemsPerViewport,
    this.horizontalGap,
    this.cardScale = 1.0,
    this.leadingBarHeight,
  });

  @override
  State<RecommendProductSection> createState() =>
      _RecommendProductSectionState();
}

class _RecommendProductSectionState extends State<RecommendProductSection> {
  final ScrollController _horizontalScroll = ScrollController();

  @override
  void dispose() {
    _horizontalScroll.dispose();
    super.dispose();
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

    return RecommendProductOrdering.build(
      products: widget.products,
      catalogKind: widget.catalogKind,
      influencerMbId: widget.influencerMbId,
      excludedProductNames: widget.excludedProductNames,
      currentProduct: widget.currentProduct,
      ownedProducts: widget.ownedProducts,
      maxItems: widget.maxItems ?? RecommendProductOrdering.defaultMaxItems,
    );
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
                  width: healthDp(context, 1),
                  height: widget.leadingBarHeight ?? healthDp(context, 14),
                  margin: EdgeInsets.only(right: healthDp(context, 6)),
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
