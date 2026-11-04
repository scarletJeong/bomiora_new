part of 'payment_screen.dart';

extension _PaymentPoint on _PaymentScreenState {
  int _pointEligibleBaseAmountFor(List<Coupon> coupons) {
    final base =
        _nonInfluencerAmount - _productCouponDiscountFor(coupons);
    return base < 0 ? 0 : base;
  }

  int get _pointEligibleBaseAmount =>
      _pointEligibleBaseAmountFor(_selectedCoupons);

  int _maxPointByRateFor(List<Coupon> coupons) {
    final eligibleBase = _pointEligibleBaseAmountFor(coupons);
    final nonInfTotal = _nonInfluencerAmount;
    if (eligibleBase <= 0 || nonInfTotal <= 0) return 0;

    var total = 0;
    for (final item in widget.cartItems) {
      if (_isInfluencerCartItem(item)) continue;
      final share = (eligibleBase * item.lineAmount / nonInfTotal).floor();
      final rate = _pointRateForItem(item);
      total += (share * rate / 100).floor();
    }
    return total < 0 ? 0 : total;
  }

  int get _maxPointByRate => _maxPointByRateFor(_selectedCoupons);

  int _shippingNetFor(List<Coupon> coupons) =>
      _baseShipping +
      _extraShipping -
      _shippingCouponDiscountFor(coupons);

  int get _shippingNet => _shippingNetFor(_selectedCoupons);

  int _maxPointByMinimumPayableFor(List<Coupon> coupons) {
    final maxByMinimum = _purchaseAmount +
        _shippingNetFor(coupons) -
        _productCouponDiscountFor(coupons) -
        _minPayableAmount;
    return maxByMinimum < 0 ? 0 : maxByMinimum;
  }

  int get _maxPointByMinimumPayable =>
      _maxPointByMinimumPayableFor(_selectedCoupons);

  int _maxUsablePointFor(List<Coupon> coupons) {
    if (_couponPointDisabled) return 0;
    const maxPerOrder = 50000;
    final candidates = [
      _myPoint,
      _maxPointByRateFor(coupons),
      _maxPointByMinimumPayableFor(coupons),
      maxPerOrder,
    ];
    final v = candidates.reduce((a, b) => a < b ? a : b);
    return v < 0 ? 0 : v;
  }

  int get _maxUsablePoint => _maxUsablePointFor(_selectedCoupons);

  int get _maxUsablePointHundreds => (_maxUsablePoint ~/ 100) * 100;

  int _pointDiscountFor(List<Coupon> coupons, int usedPoint) {
    final maxHundreds = (_maxUsablePointFor(coupons) ~/ 100) * 100;
    final capped = usedPoint > maxHundreds ? maxHundreds : usedPoint;
    return (capped ~/ 100) * 100;
  }

  int get _pointDiscount =>
      _pointDiscountFor(_selectedCoupons, _usedPoint);


  /// 쿠폰·포인트 적용 후 최종 결제액 (하한 검증용).
  int _finalAmountFor(List<Coupon> coupons, int usedPoint) {
    final amount = _purchaseAmount +
        _baseShipping +
        _extraShipping -
        _productCouponDiscountFor(coupons) -
        _shippingCouponDiscountFor(coupons) -
        _pointDiscountFor(coupons, usedPoint);
    return amount < 0 ? 0 : amount;
  }

  int get _finalAmount => _finalAmountFor(_selectedCoupons, _usedPoint);

  bool _keepsMinPayable(List<Coupon> coupons, [int? usedPoint]) {
    return _finalAmountFor(coupons, usedPoint ?? _usedPoint) >=
        _minPayableAmount;
  }


  /// 실결제에서 남은 배송비(기본 + 지역 - 배송비 쿠폰)를 뺀 금액.
  int get _rewardBase {
    final raw = _finalAmount - _shippingNet;
    if (raw <= 0) return 0;
    final goodsAfterCoupon = _purchaseAmount - _productCouponDiscount;
    final cap = goodsAfterCoupon < 0 ? 0 : goodsAfterCoupon;
    return raw > cap ? cap : raw;
  }

  int get _expectedPoint => (_rewardBase * _pointRate / 100).floor();

  String _pointFieldText(int value) =>
      value <= 0 ? '' : PointService.formatPoint(value);

  void _writePointField(int value) {
    final formatted = _pointFieldText(value);
    if (_pointController.text == formatted) return;
    _syncingPoint = true;
    _pointController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _syncingPoint = false;
  }

  void _onPointChanged() {
    if (_syncingPoint) return;
    final raw = _pointController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final value = int.tryParse(raw) ?? 0;
    final capped =
        value > _maxUsablePointHundreds ? _maxUsablePointHundreds : value;
    // 1224 입력 → 1200 처럼 100점 단위로 자동 절삭 (단, 0~99는 그대로 입력 유지)
    final safe = capped >= 100 ? (capped ~/ 100) * 100 : capped;
    final formatted = _pointFieldText(safe);

    if (_pointController.text != formatted) {
      final digitsBefore = _digitsBeforeSelection(_pointController);
      _syncingPoint = true;
      _pointController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(
          offset: _offsetAfterDigits(formatted, digitsBefore),
        ),
      );
      _syncingPoint = false;
    }

    if (safe != _usedPoint) {
      _setState(() {
        _usedPoint = safe;
      });
    }
  }

  int _digitsBeforeSelection(TextEditingController controller) {
    final text = controller.text;
    final offset = controller.selection.isValid
        ? controller.selection.extentOffset.clamp(0, text.length)
        : text.length;
    return text.substring(0, offset).replaceAll(RegExp(r'[^0-9]'), '').length;
  }

  int _offsetAfterDigits(String formatted, int digits) {
    var cursor = 0;
    var seen = 0;
    while (cursor < formatted.length && seen < digits) {
      if (formatted[cursor] != ',') seen++;
      cursor++;
    }
    return cursor;
  }


  int _pointRateForItem(CartItem item) {
    if (item.ctMbInf.trim().isNotEmpty) return 0;
    final kind = item.ctKind.toLowerCase();
    if (kind == 'prescription') return 100;
    if (kind == 'general') return 10;
    final rate = item.pointUsageRate;
    if (rate <= 0) return 100;
    if (rate > 100) return 100;
    return rate;
  }
}
