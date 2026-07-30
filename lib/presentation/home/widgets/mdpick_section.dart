import 'package:flutter/material.dart';

import '../../../data/models/product/product_model.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../shopping/widgets/recommend_product.dart';

/// 홈/쇼핑 MD's Pick 섹션.
///
/// 조건: `/md-pick` API(it_type5) + `it_kind = general` + `ca_id ≠ a0`, 최대 4개.
/// 홈 노출: 상품이 **4개 이상**일 때만 섹션 표시.
class MdPickSection extends StatefulWidget {
  const MdPickSection({
    super.key,
    this.limit = 4,
    this.padding,
    this.hideWhenEmpty = true,
  });

  final int limit;
  final EdgeInsetsGeometry? padding;
  final bool hideWhenEmpty;

  @override
  State<MdPickSection> createState() => _MdPickSectionState();
}

class _MdPickSectionState extends State<MdPickSection> {
  static const String _font = 'Gmarket Sans TTF';

  List<Product> _products = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final products = await ProductRepository.getMdPickProducts(
        limit: widget.limit,
        productKind: 'general',
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
    final kind = (product.productKind ?? 'general').trim().toLowerCase();
    if (kind == 'prescription') {
      Navigator.pushNamed(context, '/product/${product.id}');
    } else {
      Navigator.pushNamed(context, '/product-general/${product.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink();
    }
    // MD's Pick: 최소 4개 있어야 섹션 노출 (신상품은 2개)
    if (widget.hideWhenEmpty && _products.length < 4) {
      return const SizedBox.shrink();
    }

    final pad = widget.padding ??
        EdgeInsets.symmetric(horizontal: healthDp(context, 27));

    return Padding(
      padding: pad,
      child: RecommendProductSection(
        title: "MD's Pick",
        showLeadingBar: true,
        leadingBarHeight: healthDp(context, 18),
        titleStyle: TextStyle(
          color: Colors.black,
          fontSize: healthSp(context, 16),
          fontFamily: _font,
          fontWeight: FontWeight.w700,
          letterSpacing: healthSp(context, -1.44),
        ),
        excludedProductNames: const [],
        products: _products,
        onProductTap: _openProduct,
        prescriptionGroupOrdering: false,
        maxItems: widget.limit,
        itemsPerViewport: 2.1,
        horizontalGap: healthDp(context, 5),
        hideWhenEmpty: widget.hideWhenEmpty,
      ),
    );
  }
}
