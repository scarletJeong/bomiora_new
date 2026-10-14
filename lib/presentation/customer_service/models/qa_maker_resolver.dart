import '../../../data/models/product/product_model.dart';
import '../../../data/repositories/product/product_repository.dart';

/// 문의 카드에 없는 제조사를 상품 상세의 `it_subject`로 채운다.
abstract final class QaMakerResolver {
  static final Map<String, String?> _cache = {};

  static String? itIdFromImage(String? imageUrl) {
    final raw = (imageUrl ?? '').trim();
    if (raw.isEmpty) return null;
    final path = raw.split('?').first;
    for (final part in path.split('/')) {
      if (RegExp(r'^\d{6,}$').hasMatch(part)) return part;
    }
    return null;
  }

  static String? labelFromProduct(Product? product, {String? productName}) {
    if (product == null) return null;
    final subject = (product.itSubject ?? '').trim();
    final name = (productName ?? product.name).trim();
    if (subject.isNotEmpty && subject != name) return subject;
    return null;
  }

  static Future<Map<String, String>> labelsFor(Iterable<String> ids) async {
    final unique = ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final missing = unique.where((id) => !_cache.containsKey(id)).toList();
    await Future.wait(missing.map((id) async {
      try {
        final product = await ProductRepository.getProductDetail(id);
        _cache[id] = labelFromProduct(product);
      } catch (_) {
        _cache[id] = null;
      }
    }));
    return {
      for (final id in unique)
        if ((_cache[id] ?? '').isNotEmpty) id: _cache[id]!,
    };
  }
}
