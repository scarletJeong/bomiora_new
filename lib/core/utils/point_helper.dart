/// 적립포인트 계산 및 표시를 위한 헬퍼 클래스
class PointHelper {
  /// 적립포인트 텍스트 생성
  ///
  /// [pointType] - it_point_type
  ///   0: 설정금액, 1: 판매가기준 비율, 2: 구매가기준 비율
  /// [point] - it_point 값
  /// [usePoint] - cf_use_point (포인트 사용 가능 여부)
  /// [price] - 제품 가격 (포인트 계산용, type 1)
  ///
  /// 반환: "결제금액의 X% 적립" 또는 "X점" 형식의 문자열
  static String? calculatePointText({
    required dynamic pointType,
    required dynamic point,
    required bool? usePoint,
    int? price,
  }) {
    if (usePoint != true) {
      return null;
    }

    if (point == null) {
      return null;
    }

    final intPointType = _parseInt(pointType) ?? 0;
    final intPoint = _parseInt(point);

    if (intPoint == null || intPoint == 0) {
      return null;
    }

    // 구매가 비율: 웹 상품 상세와 동일하게 비율 문구
    if (intPointType == 2) {
      return '결제금액의 $intPoint% 적립';
    }

    // 판매가 비율: 가격이 있으면 점수, 없으면 비율 문구
    if (intPointType == 1) {
      if (price != null && price > 0) {
        final earned = itemUnitPoint(
          pointType: intPointType,
          point: intPoint,
          price: price,
        );
        if (earned <= 0) return null;
        return '${formatPoint(earned)}점';
      }
      return '판매가의 $intPoint% 적립';
    }

    // 설정금액
    return '${formatPoint(intPoint)}점';
  }

  /// 개당 적립 점수. 웹 get_item_point(trunc=10)와 동일.
  static int itemUnitPoint({
    required dynamic pointType,
    required dynamic point,
    required int price,
    int optionPrice = 0,
    int ioType = 0,
    int supplyPoint = 0,
  }) {
    if (ioType > 0) {
      return (_parseInt(supplyPoint) ?? 0).clamp(0, 1 << 30);
    }
    final type = _parseInt(pointType) ?? 0;
    final raw = _parseInt(point) ?? 0;
    if (raw <= 0) return 0;
    if (type > 0) {
      var base = price;
      if (type == 2) base += optionPrice;
      if (base <= 0) return 0;
      final unit = ((base * (raw / 100)) / 10).floor() * 10;
      return unit < 0 ? 0 : unit;
    }
    return raw;
  }

  /// 줄(수량 반영) 적립 점수
  static int itemLinePoint({
    required dynamic pointType,
    required dynamic point,
    required int price,
    required int qty,
    int optionPrice = 0,
    int ioType = 0,
    int supplyPoint = 0,
  }) {
    final unit = itemUnitPoint(
      pointType: pointType,
      point: point,
      price: price,
      optionPrice: optionPrice,
      ioType: ioType,
      supplyPoint: supplyPoint,
    );
    final safeQty = qty < 1 ? 1 : qty;
    return unit * safeQty;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  /// 포인트 포맷팅 (콤마 추가)
  static String formatPoint(int? point) {
    if (point == null) return '0';
    return point.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
