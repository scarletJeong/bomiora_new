import 'package:flutter/material.dart';

import '../../../data/models/product/product_model.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../common/widgets/web_dragscroll.dart';
import '../../health/health_common/health_responsive_scale.dart';
import 'home_section_widgets.dart';

/// 홈 New Product — API 정렬 기준 최대 4개.
/// 카드 UI는 CategorySection(건강을 채우는 시간)과 동일 치수.
class ProductSection extends StatefulWidget {
  const ProductSection({super.key});

  static const int _kLimit = 4;

  @override
  State<ProductSection> createState() => _ProductSectionState();
}

class _ProductSectionState extends State<ProductSection> {
  List<Product> _products = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final products = await ProductRepository.getNewProducts(
        limit: ProductSection._kLimit,
      );
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _products = const [];
        _loading = false;
      });
    }
  }

  void _openProduct(Product product) {
    Navigator.pushNamed(context, '/product-general/${product.id}');
  }

  @override
  Widget build(BuildContext context) {
    // 2개 미만이면 섹션 미표출
    if (!_loading && _products.length < 2) {
      return const SizedBox.shrink();
    }

    final w = MediaQuery.sizeOf(context).width;
    final m = _NewProductCardLayout.fromWidth(w);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: healthDp(context, 24)),
            child: const HomeSectionTitleRow(
              line1: 'New',
              line2: 'Product',
            ),
          ),
          SizedBox(height: healthDp(context, 12)),
          SizedBox(
            height: m.carouselHeight,
            child: _loading
                ? Center(
                    child: SizedBox(
                      width: healthDp(context, 20),
                      height: healthDp(context, 20),
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : WebDragScrollConfiguration(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 24),
                      ),
                      itemCount: _products.length,
                      separatorBuilder: (_, __) =>
                          SizedBox(width: m.cardSpacing),
                      itemBuilder: (_, index) {
                        final product = _products[index];
                        return _NewProductCard(
                          product: product,
                          layout: m,
                          onTap: () => _openProduct(product),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 건강을 채우는 시간 카드와 동일 (Figma 375 기준).
class _NewProductCardLayout {
  _NewProductCardLayout({
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
  });

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

  double get descLetterSpacing => -0.05 * descFs;

  factory _NewProductCardLayout.fromWidth(double w) {
    final s = healthTextScaleByWidth(w);
    double sc(double base375) => base375 * s;

    final cardW = sc(154.62);
    return _NewProductCardLayout(
      carouselHeight: sc(277.5),
      cardSpacing: sc(12),
      cardW: cardW,
      imageW: sc(150),
      imageH: sc(170),
      radius: sc(11.54),
      gapImageText: sc(12),
      titleDescGap: sc(4),
      titleFs: sc(14),
      descFs: sc(10),
      priceFs: sc(14),
      descMaxW: cardW,
      titleMaxW: sc(150),
    );
  }
}

class _NewProductCard extends StatelessWidget {
  const _NewProductCard({
    required this.product,
    required this.layout,
    required this.onTap,
  });

  final Product product;
  final _NewProductCardLayout layout;
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
