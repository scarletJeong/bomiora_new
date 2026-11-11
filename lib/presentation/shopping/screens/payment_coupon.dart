part of 'payment_screen.dart';

extension _PaymentCoupon on _PaymentScreenState {
  bool _isCouponApplicable(Coupon coupon) {
    if (!coupon.isAvailable) return false;
    // 인플루언서 상품만 있으면 상품·카테고리·주문·배송비 쿠폰 전부 불가
    if (_couponPointDisabled) return false;
    if (coupon.method == 3) {
      if (_baseShipping <= 0) return false;
      if (_shippingCouponGoodsAmount < coupon.minimum) return false;
      return _shippingDiscountFor(coupon) > 0;
    }
    // 서버 baseAmountForCoupon: 개별 상품은 그 상품 금액, 카테고리는 그 분류 금액.
    final base = _baseAmountForCoupon(coupon);
    if (base <= 0 || base < coupon.minimum) return false;
    return _discountForCoupon(coupon) > 0;
  }

  void _syncCouponLists() {
    _applicableCoupons = _loadedCoupons.where(_isCouponApplicable).toList()
      ..sort((a, b) => a.no.compareTo(b.no));
    _selectedCoupons =
        _selectedCoupons.where(_isCouponApplicable).toList();
    // 배송비 변동 등으로 최종액이 3천원 미만이면 쿠폰을 뒤에서부터 해제
    while (_selectedCoupons.isNotEmpty &&
        (!_keepsMinPayable(_selectedCoupons) ||
            !_serverAcceptsCouponTotals(_selectedCoupons))) {
      _selectedCoupons.removeLast();
    }
    if (_couponPointDisabled) {
      _usedPoint = 0;
      _pointController.clear();
    } else if (_usedPoint > _maxUsablePointHundreds) {
      _usedPoint = _maxUsablePointHundreds;
      _writePointField(_usedPoint);
    }
  }

  int get _purchaseAmount =>
      widget.cartItems.fold(0, (sum, item) => sum + item.lineAmount);


  /// 배송비 쿠폰 최소 금액. 일반·처방 상품 중 인플루언서가 아닌 라인 금액 합.
  int get _shippingCouponGoodsAmount => widget.cartItems.fold<int>(0, (sum, item) {
        if (_isInfluencerCartItem(item)) return sum;
        final kind = item.ctKind.toLowerCase();
        if (kind.isNotEmpty && kind != 'general' && kind != 'prescription') {
          return sum;
        }
        return sum + item.lineAmount;
      });

  bool _isInfluencerCartItem(CartItem item) => item.ctMbInf.trim().isNotEmpty;


  /// 인플루언서 제외 상품 금액(쿠폰·포인트 기준). 라인 결제액 합.
  int get _nonInfluencerAmount => widget.cartItems
      .where((item) => !_isInfluencerCartItem(item))
      .fold<int>(0, (sum, item) => sum + item.lineAmount);

  bool get _hasInfluencerItems => widget.cartItems.any(_isInfluencerCartItem);

  bool get _isInfluencerOnly =>
      widget.cartItems.isNotEmpty &&
      widget.cartItems.every(_isInfluencerCartItem);

  bool get _couponPointDisabled => _nonInfluencerAmount <= 0;

  String get _couponPointNotice {
    if (_isInfluencerOnly) {
      return '인플루언서 상품에는 쿠폰(배송비 포함)과 포인트를 쓸 수 없습니다.';
    }
    if (_hasInfluencerItems) {
      return '인플루언서 상품에는 쿠폰/포인트가 적용되지 않습니다.';
    }
    return '';
  }


  /// 서버는 장당 할인액을 줄여 받지 않는다. 합이 한도를 넘으면 그 조합을 고르지 않는다.
  bool _serverAcceptsCouponTotals(List<Coupon> coupons) {
    var product = 0;
    var shipping = 0;
    for (final coupon in coupons) {
      if (coupon.method == 3) {
        shipping += _shippingDiscountFor(coupon);
      } else {
        product += _discountForCoupon(coupon);
      }
    }
    if (product > _nonInfluencerAmount) return false;
    if (shipping > _baseShipping) return false;
    return true;
  }

  List<Map<String, dynamic>> _checkoutCouponPayload() {
    final product = <Map<String, dynamic>>[];
    final shipping = <Map<String, dynamic>>[];
    for (final coupon in _selectedCoupons) {
      final id = coupon.id.trim();
      if (id.isEmpty) continue;
      final row = <String, dynamic>{
        'cp_id': id,
        'discount': coupon.method == 3
            ? _shippingDiscountFor(coupon)
            : _discountForCoupon(coupon),
      };
      if (coupon.method == 3) {
        shipping.add(row);
      } else {
        product.add(row);
      }
    }
    return [...product, ...shipping];
  }


  /// 서버 `computeCouponDiscount`와 동일: type=1 비율(+trunc), 아니면 정액, maximum 상한.
  int _discountForCoupon(Coupon coupon) {
    if (coupon.method == 3) return _shippingDiscountFor(coupon);
    final base = _baseAmountForCoupon(coupon);
    if (base <= 0 || base < coupon.minimum) return 0;
    var discount = coupon.price;
    if (coupon.type == 1) {
      final trunc = coupon.trunc > 0 ? coupon.trunc : 1;
      discount = ((base * coupon.price / 100) / trunc).floor() * trunc;
    }
    if (coupon.maximum > 0 && discount > coupon.maximum) {
      discount = coupon.maximum;
    }
    if (discount > base) discount = base;
    return discount < 0 ? 0 : discount;
  }


  /// 배송비 쿠폰은 기본 배송비만 기준으로 깎고, 상품 쿠폰 한도와 더하지 않는다.
  int _shippingDiscountFor(Coupon coupon) {
    if (_couponPointDisabled) return 0;
    final base = _baseShipping;
    if (base <= 0 || _shippingCouponGoodsAmount < coupon.minimum) return 0;
    var discount = coupon.price;
    if (coupon.type == 1) {
      final trunc = coupon.trunc > 0 ? coupon.trunc : 1;
      discount = ((base * coupon.price / 100) / trunc).floor() * trunc;
    }
    if (coupon.maximum > 0 && discount > coupon.maximum) {
      discount = coupon.maximum;
    }
    if (discount > base) discount = base;
    return discount < 0 ? 0 : discount;
  }

  int _productCouponDiscountFor(List<Coupon> coupons) {
    if (_couponPointDisabled) return 0;
    return coupons
        .where((coupon) => coupon.method != 3)
        .fold<int>(0, (sum, coupon) => sum + _discountForCoupon(coupon));
  }

  int _shippingCouponDiscountFor(List<Coupon> coupons) {
    if (_couponPointDisabled) return 0;
    final raw = coupons
        .where((coupon) => coupon.method == 3)
        .fold<int>(0, (sum, coupon) => sum + _shippingDiscountFor(coupon));
    return raw < 0 ? 0 : raw;
  }

  int get _productCouponDiscount =>
      _productCouponDiscountFor(_selectedCoupons);

  int get _shippingCouponDiscount =>
      _shippingCouponDiscountFor(_selectedCoupons);

  int get _couponDiscount => _productCouponDiscount;

  int _baseAmountForCoupon(Coupon coupon) {
    bool isEligibleItem(CartItem item) => !_isInfluencerCartItem(item);

    switch (coupon.method) {
      case 0:
        if (coupon.target.trim().isEmpty) return _nonInfluencerAmount;
        return widget.cartItems
            .where((item) =>
                isEligibleItem(item) && item.itId == coupon.target.trim())
            .fold<int>(0, (sum, item) => sum + item.lineAmount);
      case 1:
        if (coupon.target.trim().isEmpty) return _nonInfluencerAmount;
        return widget.cartItems
            .where((item) =>
                isEligibleItem(item) &&
                item.matchesCategoryTarget(coupon.target))
            .fold<int>(0, (sum, item) => sum + item.lineAmount);
      case 2:
        return _nonInfluencerAmount;
      case 3:
        return _baseShipping;
      default:
        return _purchaseAmount;
    }
  }

  String _couponPickerLine(Coupon c) {
    final sub = c.subject.trim();
    final disc = c.discountText.trim();
    if (sub.isEmpty && disc.isEmpty) return '쿠폰 #${c.no}';
    if (sub.isEmpty) return '$disc (#${c.no})';
    if (disc.isEmpty) return sub;
    return '$sub ($disc)';
  }

  List<String> _uniqueCouponPickerLines(List<Coupon> candidates) {
    final seen = <String>{};
    final out = <String>[];
    for (final c in candidates) {
      var line = _couponPickerLine(c);
      var n = 0;
      while (seen.contains(line)) {
        n += 1;
        line = '${_couponPickerLine(c)} ·$n';
      }
      seen.add(line);
      out.add(line);
    }
    return out;
  }


  bool _isCouponMethodDisabled(int method) {
    if (_selectedCoupons.isEmpty) return false;
    if (method == 1) {
      if (_selectedCoupons.any((coupon) => coupon.method != 1)) return true;
      return _selectedCoupons.where((coupon) => coupon.method == 1).length >= 2;
    }
    return true;
  }

  List<Coupon> _selectionAfterPicking(Coupon picked) {
    final next = List<Coupon>.from(_selectedCoupons);
    final method = picked.method;
    if (method == 1) {
      next.removeWhere((coupon) => coupon.method != 1);
      if (next.where((coupon) => coupon.method == 1).length < 2) {
        next.add(picked);
      }
    } else {
      next
        ..clear()
        ..add(picked);
    }
    return next;
  }

  List<Coupon> _availableCouponsForUnifiedPicker() {
    return _applicableCoupons.where((coupon) {
      if (_selectedCoupons.any((selected) => selected.no == coupon.no)) {
        return false;
      }
      if (_isCouponMethodDisabled(coupon.method)) return false;
      if (coupon.method == 1) {
        final categoryCount =
            _selectedCoupons.where((c) => c.method == 1).length;
        if (categoryCount >= 2) return false;
      }
      final next = _selectionAfterPicking(coupon);
      return _keepsMinPayable(next) && _serverAcceptsCouponTotals(next);
    }).toList();
  }

  void _onUnifiedCouponChosen(String label) {
    final candidates = _availableCouponsForUnifiedPicker();
    final lines = _uniqueCouponPickerLines(candidates);
    final index = lines.indexOf(label);
    if (index < 0 || index >= candidates.length) return;
    final picked = candidates[index];
    final next = _selectionAfterPicking(picked);
    if (!_serverAcceptsCouponTotals(next)) {
      AppToastOverlay.showAlert(context, '쿠폰 할인 금액이 주문 금액을 넘습니다.');
      return;
    }
    if (!_keepsMinPayable(next)) {
      AppToastOverlay.showAlert(
        context,
        '최종 결제금액은 ${PriceFormatter.format(_minPayableAmount)}원 이상이어야 합니다.',
      );
      return;
    }

    _setState(() {
      _selectedCoupons = next;
      if (_usedPoint > _maxUsablePoint) {
        _usedPoint = _maxUsablePoint;
        _writePointField(_usedPoint);
      }
    });
  }

  Widget _couponDropdown(BuildContext context) {
    final candidates = _availableCouponsForUnifiedPicker();
    final lines = _uniqueCouponPickerLines(candidates);
    if (lines.isEmpty) return const SizedBox.shrink();

    return DropdownBtn(
      buttonHeight: healthDp(context, 45),
      enabled: true,
      items: lines,
      value: '',
      emptyText: '쿠폰 선택 안함',
      emptyTextColor: _muted,
      valueTextColor: const Color(0xFF1A1A1E),
      borderColor: _border,
      itemFontSizeBase: 12,
      itemTextAlign: TextAlign.left,
      onChanged: _onUnifiedCouponChosen,
    );
  }

  Widget _selectedCouponRow(BuildContext context, Coupon coupon) {
    final typeLabel = _couponTypeLabel(coupon);
    final safeSubject = coupon.subject.trim();
    final safeTarget = coupon.target.trim();
    final safeDiscount = coupon.discountText.trim();
    final name = safeSubject.isNotEmpty
        ? safeSubject
        : (safeTarget.isNotEmpty ? safeTarget : '쿠폰명 없음');
    final line = safeDiscount.isNotEmpty ? '$name ($safeDiscount)' : name;

    return Padding(
      padding: EdgeInsets.only(bottom: healthDp(context, 10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeLabel,
                  style: TextStyle(
                    color: _pink,
                    fontSize: healthSp(context, 12),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  line,
                  style: TextStyle(
                    color: _figmaDark,
                    fontSize: healthSp(context, 12),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              _setState(() {
                _selectedCoupons.removeWhere((c) => c.no == coupon.no);
                if (_usedPoint > _maxUsablePointHundreds) {
                  _usedPoint = _maxUsablePointHundreds;
                  _writePointField(_usedPoint);
                }
              });
            },
            child: Text(
              '삭제',
              style: TextStyle(
                color: _figmaBrown,
                fontSize: healthSp(context, 10),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _couponTypeLabel(Coupon coupon) {
    switch (coupon.method) {
      case 0:
        return '[상품 쿠폰]';
      case 1:
        return '[카테고리 쿠폰]';
      case 2:
        return '[주문할인 쿠폰]';
      case 3:
        return '[배송비 쿠폰]';
      default:
        return '[쿠폰]';
    }
  }
}
