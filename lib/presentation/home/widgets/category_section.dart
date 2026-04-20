import 'package:flutter/material.dart';

import '../../../data/models/product/product_model.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../common/widgets/web_dragscroll.dart';
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

  @override
  Widget build(BuildContext context) {
    final selectedCategory = _tabs[_tabController.index];
    final products =
        _productsByCategory[selectedCategory.categoryId] ?? const <Product>[];

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
              indicatorColor: const Color(0xFFFF5A8D),
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
                          _tabs[index].label,
                          style: TextStyle(
                            color: selected
                                ? const Color(0xFFFF5A8D)
                                : const Color(0xFF28171A),
                            fontSize: 14,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
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
            child: _buildCategoryBody(
              context: context,
              products: products,
            ),
          ),
        ],
      ),
    );
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

  Widget _buildCategoryBody({
    required BuildContext context,
    required List<Product> products,
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
          style: const TextStyle(
            color: Color(0x665B3F43),
            fontSize: 12,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }

    if (products.isEmpty) {
      return const Center(
        child: Text(
          '등록된 상품이 없습니다.',
          style: TextStyle(
            color: Color(0x665B3F43),
            fontSize: 12,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }

    return WebDragScrollConfiguration(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final product = products[index];
          return _CategoryProductCard(
            product: product,
            onTap: () => Navigator.pushNamed(context, '/product/${product.id}'),
          );
        },
      ),
    );
  }
}

class _CategoryProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _CategoryProductCard({
    required this.product,
    required this.onTap,
  });

  String _sanitizeDescription(String? raw) {
    final source = (raw ?? '').trim();
    if (source.isEmpty) return '';
    return source
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
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
    final hasDiscount = product.discountRate != null && product.discountRate! > 0;
    final sanitizedDescription = _resolveCardDescription(product);
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                  child: (product.imageUrl?.isNotEmpty ?? false)
                      ? Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: Color(0xFFFFE9EA),
                          ),
                        )
                      : const ColoredBox(
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
                        product.name,
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
                        child: sanitizedDescription.isEmpty
                            ? const SizedBox.shrink()
                            : Text(
                                sanitizedDescription,
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
                          if (hasDiscount)
                            Text(
                              '${product.discountRate!.round()}%',
                              style: const TextStyle(
                                color: Color(0xFFB80049),
                                fontSize: 10,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w700,
                                height: 1.5,
                              ),
                            ),
                          if (hasDiscount) const SizedBox(width: 4),
                          Text(
                            product.formattedPrice,
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
      ),
    );
  }
}
