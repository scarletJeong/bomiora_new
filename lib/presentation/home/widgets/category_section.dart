import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/models/product/product_model.dart';
import '../../../data/repositories/product/product_category_catalog.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../common/widgets/web_dragscroll.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../shopping/utils/get_product.dart';

class CategorySection extends StatefulWidget {
  const CategorySection({super.key});

  @override
  State<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<CategorySection> {
  static const int _initialVisibleCount = 5;
  static const int _expandStep = 5;
  static const int _maxCarouselProducts = 10;

  List<ProductCategoryItem> _tabs =
      List<ProductCategoryItem>.from(productGeneralCategoryListFallback);
  int _selectedTabIndex = 0;
  int _tabsRequestToken = 0;
  final Map<String, List<Product>> _productsByCategory = {};
  final Map<String, int> _visibleCountByCategory = {};
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProductsForCurrentTab();
    _refreshTabsFromApi();
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _tabs.length || index == _selectedTabIndex) {
      return;
    }
    final cacheKey = _cacheKeyForTab(_tabs[index]);
    final products = _productsByCategory[cacheKey];
    if (products != null) {
      _visibleCountByCategory[cacheKey] =
          _initialVisibleCountFor(products.length);
    }
    setState(() => _selectedTabIndex = index);
    _loadProductsForCurrentTab();
  }

  Future<void> _refreshTabsFromApi() async {
    final requestToken = ++_tabsRequestToken;
    final tabs = await ProductCategoryCatalog.generalCategories();
    if (!mounted || requestToken != _tabsRequestToken) return;
    if (tabs.isEmpty) return;

    final previousIndex = _selectedTabIndex;
    setState(() {
      _tabs = tabs;
      _selectedTabIndex = previousIndex.clamp(0, tabs.length - 1);
    });
    _loadProductsForCurrentTab();
  }

  @override
  void dispose() {
    _tabsRequestToken++;
    super.dispose();
  }

  String _cacheKeyForTab(ProductCategoryItem tab) =>
      '${tab.productKind}:${tab.categoryId}';

  int _initialVisibleCountFor(int productCount) =>
      math.min(_initialVisibleCount, productCount);

  int _visibleCountFor(String cacheKey, List<Product> products) =>
      _visibleCountByCategory[cacheKey] ??
      _initialVisibleCountFor(products.length);

  int _maxVisibleFor(List<Product> products) =>
      math.min(products.length, _maxCarouselProducts);

  Future<void> _loadProductsForCurrentTab() async {
    if (_tabs.isEmpty) return;

    final tab = _tabs[_selectedTabIndex];
    final cacheKey = _cacheKeyForTab(tab);
    if (_productsByCategory.containsKey(cacheKey)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final products = await ProductRepository.getProductsByCategory(
        categoryId: tab.categoryId,
        productKind: tab.productKind,
        page: 1,
        pageSize: 10,
      );
      if (!mounted) return;
      setState(() {
        _productsByCategory[cacheKey] = products;
        _visibleCountByCategory[cacheKey] =
            _initialVisibleCountFor(products.length);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '상품을 불러오지 못했습니다.';
      });
    }
  }

  void _openCategoryProductList() {
    if (_tabs.isEmpty) return;

    final tab = _tabs[_selectedTabIndex];
    Navigator.pushNamed(
      context,
      '/product-general/',
      arguments: <String, dynamic>{
        'categoryId': tab.categoryId,
        'categoryName': tab.label,
        'productKind': 'general',
      },
    );
  }

  void _openProductDetail(Product product) {
    Navigator.pushNamed(context, '/product-general/${product.id}');
  }

  void _onMoreTap(String cacheKey, List<Product> products) {
    final visible = _visibleCountFor(cacheKey, products);
    final maxVisible = _maxVisibleFor(products);

    if (visible < maxVisible) {
      setState(() {
        _visibleCountByCategory[cacheKey] =
            math.min(visible + _expandStep, maxVisible);
      });
      return;
    }
    _openCategoryProductList();
  }

  @override
  Widget build(BuildContext context) {
    if (_tabs.isEmpty) {
      return SizedBox(
        height: healthDp(context, 280),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final w = MediaQuery.sizeOf(context).width;
    final m = _CategoryHomeLayout.fromWidth(w);
    final selectedCategory = _tabs[_selectedTabIndex];
    final cacheKey = _cacheKeyForTab(selectedCategory);
    final products =
        _productsByCategory[cacheKey] ?? const <Product>[];
    final visibleCount = _visibleCountFor(cacheKey, products);
    final displayProducts = products.take(visibleCount).toList();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: healthDp(context, 24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: m.headerTitleBarW,
                  height: m.headerAccentHeight,
                  color: Colors.black,
                ),
                SizedBox(width: m.headerRowGap),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '건강을',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: m.titleSubFs,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: m.titleLineGap),
                    Text(
                      '채우는 시간',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: m.titleMainFs,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: m.headerToBodyGap),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                WebDragScrollConfiguration(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _tabs.length; i++) ...[
                          if (i > 0) ...[
                            SizedBox(width: healthDp(context, 4)),
                            Text(
                              '|',
                              style: TextStyle(
                                color: const Color(0xFFC9C9C9),
                                fontSize: m.tabFontSize * 0.62,
                                height: 1.0,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            SizedBox(width: healthDp(context, 4)),
                          ],
                          _CategoryTabChip(
                            label: _tabs[i].label,
                            selected: _selectedTabIndex == i,
                            layout: m,
                            onTap: () => _selectTab(i),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: m.tabsToCarouselGap),
                SizedBox(
                  height: m.carouselHeight,
                  child: _buildCarouselBody(
                    context: context,
                    cacheKey: cacheKey,
                    products: products,
                    displayProducts: displayProducts,
                    layout: m,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselBody({
    required BuildContext context,
    required String cacheKey,
    required List<Product> products,
    required List<Product> displayProducts,
    required _CategoryHomeLayout layout,
  }) {
    if (_isLoading && products.isEmpty) {
      return Center(
        child: SizedBox(
          width: healthDp(context, 20),
          height: healthDp(context, 20),
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_errorMessage != null && products.isEmpty) {
      return Center(
        child: Text(
          _errorMessage!,
          style: TextStyle(
            color: const Color(0x665B3F43),
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }

    if (products.isEmpty) {
      return Center(
        child: Text(
          '등록된 상품이 없습니다.',
          style: TextStyle(
            color: const Color(0x665B3F43),
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }

    return WebDragScrollConfiguration(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: displayProducts.length,
        separatorBuilder: (_, __) => SizedBox(width: layout.cardSpacing),
        itemBuilder: (context, index) {
          final product = displayProducts[index];
          final isLast = index == displayProducts.length - 1;
          return _CategoryProductCard(
            product: product,
            layout: layout,
            showMoreOverlay: isLast,
            onTap: isLast
                ? () => _onMoreTap(cacheKey, products)
                : () => _openProductDetail(product),
          );
        },
      ),
    );
  }
}

/// Figma **375** 기준 수치에 [healthTextScaleByWidth]를 곱해 375~650과 동일 배율로 스케일
/// ([healthDp]/[healthSp]와 같은 규칙 — Figma 650 카드와 일치).
class _CategoryHomeLayout {
  _CategoryHomeLayout({
    required this.headerTitleBarW,
    required this.headerRowGap,
    required this.headerAccentHeight,
    required this.titleSubFs,
    required this.titleMainFs,
    required this.titleLineGap,
    required this.headerToBodyGap,
    required this.tabsToCarouselGap,
    required this.tabFontSize,
    required this.carouselHeight,
    required this.cardSpacing,
    required this.cardW,
    required this.imageW,
    required this.imageH,
    required this.radius,
    required this.gapImageText,
    required this.titleDescGap,
    required this.titleFs,
    required this.descFs,
    required this.priceFs,
    required this.descMaxW,
    required this.titleMaxW,
    required this.moreIconBox,
    required this.moreIconPadding,
    required this.moreTextGap,
    required this.moreFontSize,
  });

  final double headerTitleBarW;
  final double headerRowGap;
  final double headerAccentHeight;
  final double titleSubFs;
  final double titleMainFs;
  final double titleLineGap;
  final double headerToBodyGap;
  final double tabsToCarouselGap;
  final double tabFontSize;
  final double carouselHeight;
  final double cardSpacing;
  final double cardW;
  final double imageW;
  final double imageH;
  final double radius;
  final double gapImageText;
  final double titleDescGap;
  final double titleFs;
  final double descFs;
  final double priceFs;
  final double descMaxW;
  final double titleMaxW;
  final double moreIconBox;
  final double moreIconPadding;
  final double moreTextGap;
  final double moreFontSize;

  double get descLetterSpacing => -0.05 * descFs;

  factory _CategoryHomeLayout.fromWidth(double w) {
    final s = healthTextScaleByWidth(w);
    double sc(double base375) => base375 * s;

    final titleSubFs = sc(15);
    final titleMainFs = sc(16);
    final titleLineGap = sc(1.15);
    final accentH = titleSubFs * 1.2 + titleLineGap + titleMainFs * 1.2;

    final cardW = sc(154.62);
    final imageW = sc(150);
    final imageH = sc(170);

    return _CategoryHomeLayout(
      headerTitleBarW: sc(0.58),
      headerRowGap: sc(10),
      headerAccentHeight: accentH,
      titleSubFs: titleSubFs,
      titleMainFs: titleMainFs,
      titleLineGap: titleLineGap,
      headerToBodyGap: sc(20),
      tabsToCarouselGap: sc(12),
      tabFontSize: sc(12),
      carouselHeight: sc(277.5),
      cardSpacing: sc(12),
      cardW: cardW,
      imageW: imageW,
      imageH: imageH,
      radius: sc(11.54),
      gapImageText: sc(12),
      titleDescGap: sc(4),
      titleFs: sc(14),
      descFs: sc(10),
      priceFs: sc(14),
      descMaxW: cardW,
      titleMaxW: sc(150),
      moreIconBox: sc(46.02),
      moreIconPadding: sc(5.77),
      moreTextGap: sc(6),
      moreFontSize: sc(12),
    );
  }
}

class _CategoryTabChip extends StatelessWidget {
  const _CategoryTabChip({
    required this.label,
    required this.selected,
    required this.layout,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final _CategoryHomeLayout layout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(healthDp(context, 4)),
      child: Container(
        padding: EdgeInsets.only(bottom: healthDp(context, 1)),
        decoration: BoxDecoration(
          border: selected
              ? const Border(
                  bottom: BorderSide(
                    width: 1,
                    color: Color(0xFFFF5A8D),
                  ),
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? const Color(0xFFFF5A8D)
                : const Color(0xFF383838),
            fontSize: layout.tabFontSize,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            height: 1.08,
          ),
        ),
      ),
    );
  }
}

class _CategoryProductCard extends StatelessWidget {
  const _CategoryProductCard({
    required this.product,
    required this.layout,
    required this.onTap,
    this.showMoreOverlay = false,
  });

  final Product product;
  final _CategoryHomeLayout layout;
  final VoidCallback onTap;
  final bool showMoreOverlay;

  String _sanitizeDescription(String? raw) {
    final source = (raw ?? '').trim();
    if (source.isEmpty) return '';
    return source
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _resolveCardDescription(Product product) {
    final info = product.additionalInfo;
    final basic = info == null ? null : info['it_basic']?.toString();
    final basicText = _sanitizeDescription(basic);
    if (basicText.isNotEmpty) return basicText;
    return _sanitizeDescription(product.description);
  }

  @override
  Widget build(BuildContext context) {
    final m = layout;
    final hasDiscount =
        product.discountRate != null && product.discountRate! > 0;
    final desc = _resolveCardDescription(product);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: m.cardW,
        height: m.carouselHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(m.radius),
              child: SizedBox(
                width: m.imageW,
                height: m.imageH,
                child: showMoreOverlay
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Positioned.fill(
                            child: (product.imageUrl?.isNotEmpty ?? false)
                                ? Image.network(
                                    product.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const ColoredBox(
                                      color: Color(0xFFFFE9EA),
                                    ),
                                  )
                                : const ColoredBox(color: Color(0xFFFFE9EA)),
                          ),
                          const ColoredBox(
                            color: Color(0x40FF5A8D),
                          ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: m.moreIconBox,
                                  height:
                                      m.moreIconBox * (46.23 / 46.02),
                                  padding:
                                      EdgeInsets.all(m.moreIconPadding),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.add_rounded,
                                    color: Colors.white,
                                    size: m.moreIconBox -
                                        m.moreIconPadding * 2,
                                  ),
                                ),
                                SizedBox(height: m.moreTextGap),
                                Text(
                                  'More',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: m.moreFontSize,
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ((product.imageUrl?.isNotEmpty ?? false)
                        ? Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                              color: Color(0xFFFFE9EA),
                            ),
                          )
                        : const ColoredBox(color: Color(0xFFFFE9EA))),
              ),
            ),
            SizedBox(height: m.gapImageText),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: m.titleMaxW,
                          child: Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: m.titleFs,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                            ),
                          ),
                        ),
                        SizedBox(height: m.titleDescGap),
                        Expanded(
                          child: desc.isEmpty
                              ? const SizedBox.shrink()
                              : Align(
                                  alignment: Alignment.topLeft,
                                  child: SizedBox(
                                width: m.descMaxW,
                                child: Text(
                                  desc,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: const Color(0xFF666666),
                                    fontSize: m.descFs,
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: m.descLetterSpacing,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: hasDiscount
                        ? Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text:
                                      '${product.discountRate!.round()}%  ',
                                  style: TextStyle(
                                    color: const Color(0xFFFF5A8D),
                                    fontSize: m.priceFs,
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w500,
                                    height: 1.25,
                                  ),
                                ),
                                TextSpan(
                                  text: product.formattedPrice,
                                  style: TextStyle(
                                    color: const Color(0xFF231F20),
                                    fontSize: m.priceFs,
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w500,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Text(
                            product.formattedPrice,
                            style: TextStyle(
                              color: const Color(0xFF231F20),
                              fontSize: m.priceFs,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                            ),
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
