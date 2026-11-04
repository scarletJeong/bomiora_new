import '../../../core/utils/node_value_parser.dart';

/// 최근 본 상품 한 건. 서버 JSON과 기기 저장 JSON의 키 이름 차이를 여기서만 읽는다.
class RecentViewItem {
  final String itId;
  final String kind;
  final String name;
  final String brand;
  final String imageUrl;
  final int salePrice;
  final int listPrice;

  const RecentViewItem({
    required this.itId,
    required this.kind,
    required this.name,
    required this.brand,
    required this.imageUrl,
    required this.salePrice,
    required this.listPrice,
  });

  /// 상품 번호와 판매가가 있는 항목만 메뉴에 보여 준다.
  bool get isDisplayable => itId.trim().isNotEmpty && salePrice > 0;

  factory RecentViewItem.fromMap(Map<String, dynamic> item) {
    return RecentViewItem(
      itId: _text(item, const ['it_id']),
      kind: _text(item, const ['it_kind', 'product_kind']),
      name: _text(item, const ['product_name', 'it_name']),
      brand: _text(item, const [
        'it_subject',
        'itSubject',
        'it_maker',
        'it_brand',
      ]),
      imageUrl: _text(item, const ['image_url', 'it_img', 'it_img1']),
      salePrice: _won(item, const ['it_price', 'product_price', 'price']),
      listPrice: _won(item, const [
        'it_cust_price',
        'originalPrice',
        'original_price',
      ]),
    );
  }

  static String _text(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = NodeValueParser.asString(item[key])?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static int _won(Map<String, dynamic> item, List<String> keys) {
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
}
