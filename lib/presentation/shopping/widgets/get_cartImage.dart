import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/cart/cart_item_model.dart';
import '../../../data/repositories/product/product_repository.dart';

/// 장바구니 줄 썸네일 — 카페24 `원본.jpg` URL이 HTML만 줄 때 상품 상세 API로 한 번 보정합니다.
class CartItemThumbnail extends StatefulWidget {
  const CartItemThumbnail({
    super.key,
    required this.item,
    this.size = 87,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
  });

  final CartItem item;
  final double size;
  final BorderRadius? borderRadius;

  @override
  State<CartItemThumbnail> createState() => _CartItemThumbnailState();
}

class _CartItemThumbnailState extends State<CartItemThumbnail> {
  String? _displayUrl;
  bool _askedProductApi = false;

  @override
  void initState() {
    super.initState();
    _displayUrl = _normalizeCartImage(widget.item);
  }

  @override
  void didUpdateWidget(covariant CartItemThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.ctId != widget.item.ctId ||
        oldWidget.item.imageUrl != widget.item.imageUrl) {
      _askedProductApi = false;
      _displayUrl = _normalizeCartImage(widget.item);
    }
  }

  String? _normalizeCartImage(CartItem item) {
    if (item.imageUrl != null && item.imageUrl!.trim().isNotEmpty) {
      return ImageUrlHelper.normalizeThumbnailUrl(item.imageUrl, item.itId);
    }
    return ImageUrlHelper.normalizeThumbnailUrl('no_img.png', item.itId) ??
        '${ImageUrlHelper.imageBaseUrl}/data/item/${item.itId}/no_img.png';
  }

  Future<void> _fallbackFromProductApi() async {
    if (_askedProductApi) return;
    final id = widget.item.itId.trim();
    if (id.isEmpty) return;
    _askedProductApi = true;
    try {
      final product = await ProductRepository.getProductDetail(id);
      if (!mounted || product == null) return;
      final raw = product.imageUrl;
      if (raw == null || raw.trim().isEmpty) return;
      final u = ImageUrlHelper.normalizeThumbnailUrl(raw, id);
      if (!mounted || u == null || u.isEmpty) return;
      if (u != _displayUrl) {
        setState(() => _displayUrl = u);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final url = _displayUrl ?? '';
    final w = widget.size;
    final int? cacheDim = kIsWeb ? null : w.round();

    if (url.isEmpty) {
      return _placeholder(w);
    }

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: Image.network(
        url,
        width: w,
        height: w,
        fit: BoxFit.cover,
        cacheWidth: cacheDim,
        cacheHeight: cacheDim,
        errorBuilder: (_, __, ___) {
          _fallbackFromProductApi();
          return _placeholder(w);
        },
      ),
    );
  }

  Widget _placeholder(double w) {
    return SizedBox(
      width: w,
      height: w,
      child: ColoredBox(
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      ),
    );
  }
}

