class PriceFormatter {
  /// 정수를 천 단위 콤마 문자열로 변환
  /// 예) 1234567 -> 1,234,567
  static String format(int? price) {
    final value = price ?? 0;
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
