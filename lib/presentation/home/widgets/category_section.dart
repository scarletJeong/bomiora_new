import 'package:flutter/material.dart';

import '../../../data/models/product/product_model.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../common/responsive_scale.dart';
import '../../common/widgets/web_dragscroll.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../shopping/utils/get_product.dart';

class CategorySection extends StatefulWidget {
  const CategorySection({super.key});

  @override
  State<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<CategorySection>
    with SingleTickerProviderStateMixin {
  static const String _productKind = 'prescription';
  static final List<ProductCategoryItem> _tabs = productPrescriptionCategoryList;

  late final TabController _tabController;
  final Map<String, List<Product>> _productsByCategory = {};
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {});
      _loadProductsForCurrentTab();
    });
    _loadProductsForCurrentTab();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProductsForCurrentTab() async {
    final categoryId = _tabs[_tabController.index].categoryId;
    if (_productsByCategory.containsKey(categoryId)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final products = await ProductRepository.getProductsByCategory(
        categoryId: categoryId,
        productKind: _productKind,
        page: 1,
        pageSize: 10,
      );
      if (!mounted) return;
      setState(() {
        _productsByCategory[categoryId] = products;
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
    final tab = _tabs[_tabController.index];
    Navigator.pushNamed(
      context,
      '/product/',
      arguments: <String, dynamic>{
        'categoryId': tab.categoryId,
        'categoryName': tab.label,
        'productKind': _productKind,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final m = _CategoryHomeLayout.fromWidth(w);
    final selectedCategory = _tabs[_tabController.index];
    final products =
        _productsByCategory[selectedCategory.categoryId] ?? const <Product>[];

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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < _tabs.length; i++) ...[
                        if (i > 0) SizedBox(width: m.tabGap),
                        _CategoryTabChip(
                          label: _tabs[i].label,
                          selected: _tabController.index == i,
                          layout: m,
                          onTap: () {
                            if (_tabController.index != i) {
                              _tabController.animateTo(i);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: m.tabsToCarouselGap),
                SizedBox(
                  height: m.carouselHeight,
                  child: _buildCarouselBody(
                    context: context,
                    products: products,
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
    required List<Product> products,
    required _CategoryHomeLayout layout,
  }) {
    if (_isLoading && products.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
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
        itemCount: products.length + 1,
        separatorBuilder: (_, __) => SizedBox(width: layout.cardSpacing),
        itemBuilder: (context, index) {
          if (index == products.length) {
            final thumbUrl = products.isNotEmpty &&
                    (products.first.imageUrl?.isNotEmpty ?? false)
                ? products.first.imageUrl
                : null;
            return _CategoryMoreCard(
              layout: layout,
              backgroundImageUrl: thumbUrl,
              onTap: _openCategoryProductList,
            );
          }
          final product = products[index];
          return _CategoryProductCard(
            product: product,
            layout: layout,
            onTap: () =>
                Navigator.pushNamed(context, '/product/${product.id}'),
          );
        },
      ),
    );
  }
}

/// Figma 375 기준 + `lerpByWidth375_650`로 넓은 폭 보간.
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
    required this.tabGap,
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
  final double tabGap;
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

  double get descLetterSpacing => homeCardBodyLetterSpacing(descFs);

  factory _CategoryHomeLayout.fromWidth(double w) {
    final titleSubFs = lerpByWidth375_650(width: w, v375: 15, v650: 22);
    final titleMainFs = lerpByWidth375_650(width: w, v375: 16, v650: 24);
    final titleLineGap = lerpByWidth375_650(width: w, v375: 1.15, v650: 2);
    final accentH =
        titleSubFs * 1.2 + titleLineGap + titleMainFs * 1.2;

    return _CategoryHomeLayout(
      headerTitleBarW: lerpByWidth375_650(width: w, v375: 0.58, v650: 1),
      headerRowGap: lerpByWidth375_650(width: w, v375: 10, v650: 14),
      headerAccentHeight: accentH,
      titleSubFs: titleSubFs,
      titleMainFs: titleMainFs,
      titleLineGap: titleLineGap,
      headerToBodyGap: lerpByWidth375_650(width: w, v375: 20, v650: 28),
      tabsToCarouselGap: lerpByWidth375_650(width: w, v375: 12, v650: 18),
      tabGap: lerpByWidth375_650(width: w, v375: 8, v650: 10),
      tabFontSize: lerpByWidth375_650(width: w, v375: 12, v650: 14),
      carouselHeight: lerpByWidth375_650(width: w, v375: 277.5, v650: 400),
      cardSpacing: lerpByWidth375_650(width: w, v375: 12, v650: 16),
      cardW: lerpByWidth375_650(width: w, v375: 154.62, v650: 268),
      imageW: lerpByWidth375_650(width: w, v375: 150, v650: 260),
      imageH: lerpByWidth375_650(width: w, v375: 170, v650: 280),
      radius: lerpByWidth375_650(width: w, v375: 11.54, v650: 20),
      gapImageText: lerpByWidth375_650(width: w, v375: 12, v650: 16),
      titleDescGap: lerpByWidth375_650(width: w, v375: 4, v650: 6),
      titleFs: lerpByWidth375_650(width: w, v375: 14, v650: 20),
      descFs: lerpByWidth375_650(width: w, v375: 10, v650: 14),
      priceFs: lerpByWidth375_650(width: w, v375: 14, v650: 20),
      descMaxW: lerpByWidth375_650(width: w, v375: 154.62, v650: 268),
      titleMaxW: lerpByWidth375_650(width: w, v375: 150, v650: 260),
      moreIconBox: lerpByWidth375_650(width: w, v375: 46.02, v650: 56),
      moreIconPadding: lerpByWidth375_650(width: w, v375: 5.77, v650: 8),
      moreTextGap: lerpByWidth375_650(width: w, v375: 6, v650: 8),
      moreFontSize: lerpByWidth375_650(width: w, v375: 12, v650: 14),
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
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.only(bottom: 2),
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
            height: 1.25,
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
  });

  final Product product;
  final _CategoryHomeLayout layout;
  final VoidCallback onTap;

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
                child: (product.imageUrl?.isNotEmpty ?? false)
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFFFFE9EA),
                        ),
                      )
                    : const ColoredBox(color: Color(0xFFFFE9EA)),
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
                        Text(
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
                        SizedBox(height: m.titleDescGap),
                        Expanded(
                          child: desc.isEmpty
                              ? const SizedBox.shrink()
                              : Align(
                                  alignment: Alignment.topLeft,
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

class _CategoryMoreCard extends StatelessWidget {
  const _CategoryMoreCard({
    required this.layout,
    this.backgroundImageUrl,
    required this.onTap,
  });

  final _CategoryHomeLayout layout;
  final String? backgroundImageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = layout;
    final thumb = backgroundImageUrl?.trim();
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: thumb != null && thumb.isNotEmpty
                          ? Image.network(
                              thumb,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const ColoredBox(
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
                            height: m.moreIconBox * (46.23 / 46.02),
                            padding: EdgeInsets.all(m.moreIconPadding),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: m.moreIconBox - m.moreIconPadding * 2,
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
                ),
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
                        Text(
                          '보미 다이어트환 9단계 프로맥스',
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
                        SizedBox(height: m.titleDescGap),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              '다이어트의 시작. 다이어트 스텐다드 라인업으로 쉬워지는 다이어트를 경험하세요.',
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
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '26%  ',
                            style: TextStyle(
                              color: const Color(0xFFFF5A8D),
                              fontSize: m.priceFs,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                            ),
                          ),
                          TextSpan(
                            text: '8,888,000원',
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
