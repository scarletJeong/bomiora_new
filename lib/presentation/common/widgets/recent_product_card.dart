import 'package:flutter/material.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/node_value_parser.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../data/models/product/product_model.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../health/health_common/health_responsive_scale.dart';

/// 사이드 메뉴 등에서 쓰는 최근 본 상품 카드
class RecentProductCard extends StatelessWidget {
  static const String _fontFamily = 'Gmarket Sans TTF';

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const RecentProductCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  String get _title =>
      NodeValueParser.asString(item['product_name'])?.trim() ??
      NodeValueParser.asString(item['it_name'])?.trim() ??
      '상품';

  String get _brand {
    final raw = NodeValueParser.asString(item['it_subject']) ??
        NodeValueParser.asString(item['itSubject']) ??
        NodeValueParser.asString(item['it_maker']) ??
        NodeValueParser.asString(item['it_brand']) ??
        '';
    return raw.trim();
  }

  Product? get _preview {
    final id = NodeValueParser.asString(item['it_id'])?.trim() ?? '';
    if (id.isEmpty) return null;
    return ProductRepository.getProductPreview(id);
  }

  int get _salePrice {
    final fromItem = _firstWon([
      'it_price',
      'product_price',
      'price',
    ]);
    if (fromItem > 0) return fromItem;
    return _preview?.price ?? 0;
  }

  int get _listPrice {
    final fromItem = _firstWon([
      'it_cust_price',
      'originalPrice',
      'original_price',
    ]);
    if (fromItem > 0) return fromItem;
    return _preview?.originalPrice ?? 0;
  }

  /// MD Pick과 동일: (정가 it_cust_price - 판매가 it_price) / 정가
  int get _discountPercent {
    final sale = _salePrice;
    final list = _listPrice;
    if (sale <= 0 || list <= 0 || list <= sale) return 0;
    return (((list - sale) / list) * 100).round();
  }

  String get _price => '${PriceFormatter.format(_salePrice)}원';

  int _firstWon(List<String> keys) {
    for (final key in keys) {
      final n = _parseWon(item[key]);
      if (n != null && n > 0) return n;
    }
    return 0;
  }

  static int? _parseWon(dynamic raw) {
    final normalized = NodeValueParser.normalize(raw);
    if (normalized == null) return null;
    if (normalized is int) return normalized;
    if (normalized is num) return normalized.round();
    final text = normalized.toString().replaceAll(',', '').trim();
    if (text.isEmpty || text == 'null') return null;
    return int.tryParse(text) ?? double.tryParse(text)?.round();
  }

  String get _imageUrl {
    final raw = NodeValueParser.asString(item['image_url']) ??
        NodeValueParser.asString(item['it_img']) ??
        NodeValueParser.asString(item['it_img1']) ??
        '';
    return raw.trim();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl;
    final discount = _discountPercent;
    final radius = healthDp(context, 10);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: ColoredBox(
                  color: const Color(0xFFE8E8E8),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          ImageUrlHelper.getImageUrl(imageUrl),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.image_outlined,
                            color: Colors.grey.shade500,
                            size: healthDp(context, 32),
                          ),
                        )
                      : Icon(
                          Icons.image_outlined,
                          color: Colors.grey.shade500,
                          size: healthDp(context, 32),
                        ),
                ),
              ),
            ),
            SizedBox(height: healthDp(context, 10)),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_brand.isNotEmpty) ...[
                      Text(
                        _brand,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF898686),
                          fontSize: healthSp(context, 10),
                          fontFamily: _fontFamily,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: healthDp(context, 4)),
                    ],
                    SizedBox(
                      height: (healthSp(context, 14) * 1.2).ceilToDouble() * 2,
                      width: double.infinity,
                      child: Text(
                        _title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF1A1A1E),
                          fontSize: healthSp(context, 14),
                          fontFamily: _fontFamily,
                          fontWeight: FontWeight.w500,
                          letterSpacing: healthSp(context, -1.26),
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: healthDp(context, 6)),
                Row(
                  children: [
                    if (discount > 0) ...[
                      Text(
                        '$discount%',
                        style: TextStyle(
                          color: const Color(0xFFFF5A8D),
                          fontSize: healthSp(context, 14),
                          fontFamily: _fontFamily,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: healthDp(context, 4)),
                    ],
                    Flexible(
                      child: Text(
                        _price,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF1A1A1E),
                          fontSize: healthSp(context, 14),
                          fontFamily: _fontFamily,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
