import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../data/repositories/product/product_category_catalog.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../utils/get_product.dart';

/// 상품 리스트 상단 카테고리 바로가기
class ProductMainCategoryTap extends StatefulWidget {
  /// 'prescription' | 'general'
  final String productKind;

  /// `true`이면 동그라미·아이콘을 더 작게(상품 목록 상단 등).
  final bool compact;

  const ProductMainCategoryTap({
    super.key,
    required this.productKind,
    this.compact = false,
  });

  @override
  State<ProductMainCategoryTap> createState() => _ProductMainCategoryTapState();
}

class _ProductMainCategoryTapState extends State<ProductMainCategoryTap> {
  static const _lineColor = Color(0xFFD9D9D9);

  List<ProductCategoryItem> _generalCategories =
      List<ProductCategoryItem>.from(productGeneralCategoryListFallback);
  List<ProductCategoryItem> _prescriptionCategories =
      List<ProductCategoryItem>.from(productPrescriptionCategoryListFallback);
  bool _categoriesReady = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (widget.productKind == 'general') {
      final categories = await ProductCategoryCatalog.generalCategories();
      if (!mounted) return;
      setState(() {
        _generalCategories = categories;
        _categoriesReady = true;
      });
      return;
    }

    if (widget.productKind == 'prescription') {
      final categories = await ProductCategoryCatalog.prescriptionCategories();
      if (!mounted) return;
      setState(() {
        _prescriptionCategories = categories;
        _categoriesReady = true;
      });
      return;
    }

    if (mounted) setState(() => _categoriesReady = true);
  }

  List<ProductCategoryItem> get _categories => widget.productKind == 'general'
      ? _generalCategories
      : _prescriptionCategories;

  String _iconAssetFor(ProductCategoryItem category, int index) {
    if (widget.productKind == 'general') {
      return productGeneralCategoryIconAsset(category.categoryId);
    }
    return productPrescriptionCategoryIconAsset(category.categoryId);
  }

  @override
  Widget build(BuildContext context) {
    if (!_categoriesReady) {
      return SizedBox(
        height: healthDp(context, widget.compact ? 72 : 100),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final circleDiameter = healthDp(context, widget.compact ? 56 : 80);
    final svgSize = healthDp(context, widget.compact ? 17 : 24);
    final hGap = healthDp(context, widget.compact ? 16 : 22);
    final isGeneral = widget.productKind == 'general';
    final categories = _categories;

    void goToCategory({
      required String categoryId,
      required String categoryName,
    }) {
      Navigator.pushNamed(
        context,
        isGeneral ? '/product-general/' : '/product/',
        arguments: {
          'categoryId': categoryId,
          'categoryName': categoryName,
          'productKind': isGeneral ? 'general' : 'prescription',
        },
      );
    }

    Widget item({
      required String svgAsset,
      required String label,
      required VoidCallback onTap,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: circleDiameter,
            height: circleDiameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: _lineColor,
                width: healthDp(context, 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: healthDp(context, 8),
                  offset: Offset(0, healthDp(context, 2)),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              healthDp(context, widget.compact ? 4 : 6),
              healthDp(context, widget.compact ? 6 : 10),
              healthDp(context, widget.compact ? 4 : 6),
              healthDp(context, widget.compact ? 5 : 8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                SvgPicture.asset(
                  svgAsset,
                  width: svgSize,
                  height: svgSize,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: healthDp(context, widget.compact ? 2 : 4)),
                Text(
                  isGeneral
                      ? productGeneralCategoryChipLabel(label)
                      : productPrescriptionCategoryMenuLabel(label),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF676767),
                    fontSize: healthSp(context, widget.compact ? 7.5 : 8),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final grayLineWidth =
            ((maxW * 3 / 4 + circleDiameter) * 0.58).clamp(140.0, maxW);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: maxW,
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: healthDp(context, 12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(categories.length, (i) {
                        final c = categories[i];
                        return Padding(
                          padding: EdgeInsets.only(
                            right: i == categories.length - 1 ? 0 : hGap,
                          ),
                          child: item(
                            svgAsset: _iconAssetFor(c, i),
                            label: c.label,
                            onTap: () => goToCategory(
                              categoryId: c.categoryId,
                              categoryName: c.label,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: healthDp(context, 20)),
            Center(
              child: SizedBox(
                width: grayLineWidth,
                child: const Divider(
                  height: 1,
                  thickness: 1,
                  color: _lineColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
