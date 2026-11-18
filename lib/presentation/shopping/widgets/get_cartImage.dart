import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../core/logging/failure_log.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/cart/cart_item_model.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../common/widgets/app_network_image.dart';

/// 장바구니 줄 썸네일 — 카페24 `원본.jpg` URL이 HTML만 줄 때 상품 상세 API로 한 번 보정합니다.
class CartItemThumbnail extends StatefulWidget {
  const CartItemThumbnail({
    super.key,
    required this.item,
    this.size = 87,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    this.reportImageFailure = false,
  });

  final CartItem item;
  final double size;
  final BorderRadius? borderRadius;

  /// 결제 상품 사진. 실패를 로그에 남기고 아이콘은 `#898686`이다.
  final bool reportImageFailure;

  @override
  State<CartItemThumbnail> createState() => _CartItemThumbnailState();
}

class _CartItemThumbnailState extends State<CartItemThumbnail> {
  static final Set<String> _loggedImageUrls = {};
  static final Set<String> _loggedFallbackIds = {};

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
      if (product == null) {
        _logFallbackFailure('상품을 찾지 못했습니다.');
        return;
      }
      final raw = product.imageUrl;
      final u = raw == null || raw.trim().isEmpty
          ? null
          : ImageUrlHelper.normalizeThumbnailUrl(raw, id);
      if (u == null || u.isEmpty || u == _displayUrl) {
        _logFallbackFailure('상품 사진이 없습니다.');
        return;
      }
      if (!mounted) return;
      setState(() => _displayUrl = u);
    } catch (e) {
      _logFallbackFailure(e);
    }
  }

  void _logImageFailure(String url, Object error) {
    if (!widget.reportImageFailure || !_loggedImageUrls.add(url)) return;
    unawaited(
      FailureLog.record(
        code: 'payment.product.image',
        mbId: AuthService.currentUser?.id ?? '',
        reason: '결제 상품 사진을 불러오지 못했습니다.',
        detail: {
          'url': url,
          'itId': widget.item.itId,
          'error': error.toString(),
        },
      ),
    );
  }

  void _logFallbackFailure(Object error) {
    if (!widget.reportImageFailure) return;
    final id = widget.item.itId.trim();
    if (!_loggedFallbackIds.add(id.isEmpty ? '_' : id)) return;
    unawaited(
      FailureLog.record(
        code: 'payment.product.image',
        mbId: AuthService.currentUser?.id ?? '',
        reason: '결제 상품 사진을 다시 불러오지 못했습니다.',
        detail: {
          'itId': widget.item.itId,
          'error': error.toString(),
        },
      ),
    );
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
      child: widget.reportImageFailure
          ? AppNetworkImage(
              url: url,
              width: w,
              height: w,
              fit: BoxFit.cover,
              decodeWidthLogical: w,
              decodeHeightLogical: w,
              preferHtmlElementOnWeb: false,
              errorBuilder: (_, error, __) {
                _logImageFailure(url, error);
                _fallbackFromProductApi();
                return _placeholder(w);
              },
            )
          : Image.network(
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
        child: Icon(
          Icons.image_not_supported,
          color: widget.reportImageFailure
              ? const Color(0xFF898686)
              : Colors.grey,
        ),
      ),
    );
  }
}

