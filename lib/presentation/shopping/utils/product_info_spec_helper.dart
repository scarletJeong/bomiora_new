import '../../../core/utils/point_helper.dart';

/// 제품 정보 섹션(탭 위) 스펙 행 — DB `additionalInfo` 값만 표시
class ProductInfoSpecHelper {
  ProductInfoSpecHelper._();

  /// HTML/공백 정리 후 표시용 평문
  static String plainText(dynamic raw) {
    if (raw == null) return '';
    var s = raw.toString().trim();
    if (s.isEmpty) return '';
    s = s
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .trim();
    return s;
  }

  static void _add(
    List<Map<String, String>> specs,
    String label,
    dynamic raw,
  ) {
    final value = plainText(raw);
    if (value.isEmpty) return;
    specs.add({'label': label, 'value': value});
  }

  static int _toInt(dynamic raw) {
    if (raw == null) return 0;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString().replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;
  }

  static String _formatWon(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return '${buf.toString()}원';
  }

  /// it_sc_type / 쇼핑몰 기본설정 기반 배송비 문구
  /// (API `shippingFeeLabel` 우선, 없으면 클라이언트 폴백)
  static String shippingFeeLabel(Map<String, dynamic>? info) {
    if (info == null) return '';
    final fromApi = plainText(info['shippingFeeLabel']);
    if (fromApi.isNotEmpty) return fromApi;

    final type = _toInt(info['it_sc_type']);
    final minimum = _toInt(info['it_sc_minimum']);
    final price = _toInt(info['it_sc_price']);

    if (type == 1) return '무료배송';
    if (type == 3) return '유료배송';
    if (type == 2) {
      if (minimum > 0) {
        return '조건부 무료배송 (${_formatWon(minimum)} 이상 무료)';
      }
      if (price > 0) return '조건부 무료배송 (${_formatWon(price)})';
      return '조건부 무료배송';
    }
    return '';
  }

  /// 값이 있는 항목만 반환. 표시 순서 고정.
  static List<Map<String, String>> buildSpecs({
    required Map<String, dynamic>? info,
    required int price,
    bool usePoint = true,
    bool isInfluencerProduct = false,
  }) {
    final specs = <Map<String, String>>[];
    if (info == null) return specs;

    // 중량/용량 → 처방단위 → 복용방법 → 패키지구성 → 제조사 → 원산지 → 브랜드
    // → 적립포인트 → 배송비결제
    _add(specs, '중량/용량', info['it_weight']);
    _add(specs, '처방단위', info['it_prescription']);
    _add(specs, '복용방법', info['it_takeway']);
    _add(specs, '패키지구성', info['it_package']);
    _add(specs, '제조사', info['it_maker']);
    _add(specs, '원산지', info['it_origin']);
    _add(specs, '브랜드', info['it_brand']);

    if (!isInfluencerProduct) {
      final pointText = PointHelper.calculatePointText(
        pointType: info['it_point_type'],
        point: info['it_point'],
        usePoint: usePoint,
        price: price,
      );
      if (pointText != null && pointText.trim().isNotEmpty) {
        specs.add({'label': '적립포인트', 'value': pointText.trim()});
      }
    }

    _add(specs, '배송비', shippingFeeLabel(info));

    return specs;
  }
}
