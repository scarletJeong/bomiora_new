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
    if (_quotedFinalAmount != null) return;
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
    } else if (_usedPoint > _maxUsablePointSnapped) {
      _usedPoint = _maxUsablePointSnapped;
      _writePointField(_usedPoint);
    }
  }

  int get _purchaseAmount {
    final quoted = _quotedPurchaseAmount;
    if (quoted != null) return quoted;
    return widget.cartItems.fold(0, (sum, item) => sum + item.lineAmount);
  }


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
    final effectiveByNo = _effectiveProductDiscountByNo(_selectedCoupons);
    for (final coupon in _selectedCoupons) {
      final id = coupon.id.trim();
      if (id.isEmpty) continue;
      final row = <String, dynamic>{
        'cp_id': id,
        'discount': coupon.method == 3
            ? _shippingDiscountFor(coupon)
            : (effectiveByNo[coupon.no] ?? 0),
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

  /// 최소 결제 3,000원을 남기도록 상품 쿠폰 할인액을 캡한 결과(쿠폰 no → 실할인).
  Map<int, int> _effectiveProductDiscountByNo(List<Coupon> coupons) {
    final productCoupons =
        coupons.where((coupon) => coupon.method != 3).toList(growable: false);
    final rawByNo = <int, int>{};
    var rawTotal = 0;
    for (final coupon in productCoupons) {
      final discount = _discountForCoupon(coupon);
      rawByNo[coupon.no] = discount;
      rawTotal += discount;
    }
    if (rawTotal <= 0) return rawByNo;

    final shippingDisc = _shippingCouponDiscountFor(coupons);
    final maxTotal = _purchaseAmount +
        _baseShipping +
        _extraShipping -
        shippingDisc -
        _minPayableAmount;
    final cap = maxTotal < 0 ? 0 : maxTotal;
    if (rawTotal <= cap) return rawByNo;

    final out = <int, int>{};
    var assigned = 0;
    for (var i = 0; i < productCoupons.length; i++) {
      final coupon = productCoupons[i];
      final raw = rawByNo[coupon.no] ?? 0;
      if (i == productCoupons.length - 1) {
        final rest = cap - assigned;
        out[coupon.no] = rest < 0 ? 0 : (rest > raw ? raw : rest);
      } else {
        final scaled = ((raw * cap) / rawTotal).floor();
        out[coupon.no] = scaled;
        assigned += scaled;
      }
    }
    return out;
  }

  int _productCouponDiscountFor(List<Coupon> coupons) {
    if (_couponPointDisabled) return 0;
    return _effectiveProductDiscountByNo(coupons)
        .values
        .fold<int>(0, (sum, discount) => sum + discount);
  }

  int _shippingCouponDiscountFor(List<Coupon> coupons) {
    if (_couponPointDisabled) return 0;
    final raw = coupons
        .where((coupon) => coupon.method == 3)
        .fold<int>(0, (sum, coupon) => sum + _shippingDiscountFor(coupon));
    return raw < 0 ? 0 : raw;
  }

  int get _productCouponDiscount {
    final quoted = _quotedProductCoupon;
    if (quoted != null) return quoted;
    return _productCouponDiscountFor(_selectedCoupons);
  }

  int get _shippingCouponDiscount {
    final quoted = _quotedShippingCoupon;
    if (quoted != null) return quoted;
    return _shippingCouponDiscountFor(_selectedCoupons);
  }

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


  /// 처방 다이어트/디톡스 카테고리만 서로 1장씩 동시 사용 가능.
  static const _kDietCategoryId = '10';
  static const _kDetoxCategoryId = '20';

  String _categoryCouponKey(Coupon coupon) =>
      coupon.target.trim().toLowerCase();

  bool _isDietOrDetoxCategory(String target) {
    final t = target.trim().toLowerCase();
    return t == _kDietCategoryId || t == _kDetoxCategoryId;
  }

  bool _isCouponMethodDisabled(int method) {
    if (_selectedCoupons.isEmpty) return false;
    if (method == 1) {
      // 상품/주문/배송비 쿠폰과 카테고리 쿠폰은 동시 사용 불가
      return _selectedCoupons.any((coupon) => coupon.method != 1);
    }
    return true;
  }

  List<Coupon> _selectionAfterPicking(Coupon picked) {
    final next = List<Coupon>.from(_selectedCoupons);
    final method = picked.method;
    if (method == 1) {
      // 카테고리 외 쿠폰 제거
      next.removeWhere((coupon) => coupon.method != 1);
      final pickedKey = _categoryCouponKey(picked);
      // 같은 카테고리는 1장만 — 기존 동일 target 교체
      next.removeWhere(
        (coupon) =>
            coupon.method == 1 && _categoryCouponKey(coupon) == pickedKey,
      );
      if (_isDietOrDetoxCategory(picked.target)) {
        // 다이어트·디톡스만 서로 다른 카테고리 1장씩 유지
        next.removeWhere(
          (coupon) =>
              coupon.method == 1 && !_isDietOrDetoxCategory(coupon.target),
        );
      } else {
        // 그 외 카테고리는 전체 1장만
        next.removeWhere((coupon) => coupon.method == 1);
      }
      next.add(picked);
    } else {
      next
        ..clear()
        ..add(picked);
    }
    return next;
  }

  /// 기존 선택 유지한 채 장수만 늘어나는 선택인지 (교체만 가능한 경우 false).
  bool _isAdditiveCouponPick(Coupon picked) {
    final next = _selectionAfterPicking(picked);
    if (next.length != _selectedCoupons.length + 1) return false;
    return _selectedCoupons.every(
      (selected) => next.any((coupon) => coupon.no == selected.no),
    );
  }

  List<Coupon> _availableCouponsForUnifiedPicker() {
    return _applicableCoupons.where((coupon) {
      if (_selectedCoupons.any((selected) => selected.no == coupon.no)) {
        return false;
      }
      if (_isCouponMethodDisabled(coupon.method)) return false;
      final next = _selectionAfterPicking(coupon);
      // 상품 쿠폰은 최소결제 3천을 남기도록 할인이 캡되므로, 서버 한도만 검사
      return _serverAcceptsCouponTotals(next);
    }).toList();
  }

  /// 규칙상 더 추가할 쿠폰이 없으면 true (교체만 가능한 상태 포함).
  bool get _isCouponSelectionFull {
    if (_selectedCoupons.isEmpty) return false;
    return !_applicableCoupons.any((coupon) {
      if (_selectedCoupons.any((selected) => selected.no == coupon.no)) {
        return false;
      }
      if (_isCouponMethodDisabled(coupon.method)) return false;
      if (!_isAdditiveCouponPick(coupon)) return false;
      return _serverAcceptsCouponTotals(_selectionAfterPicking(coupon));
    });
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
    final maxPoint = _snapPointDown(_maxUsablePointFor(next));

    _setState(() {
      _clearAmountQuote();
      _selectedCoupons = next;
      if (_usedPoint > maxPoint) {
        _usedPoint = maxPoint;
        _writePointField(_usedPoint);
      }
    });
  }

  Widget _couponDropdown(BuildContext context) {
    final candidates = _availableCouponsForUnifiedPicker();
    final lines = _uniqueCouponPickerLines(candidates);
    final hasItems = lines.isNotEmpty;
    final full = _isCouponSelectionFull;
    final emptyText = full
        ? '쿠폰을 모두 적용했습니다'
        : (hasItems ? '쿠폰을 선택해 주세요' : '적용할 쿠폰이 없어요');

    return DropdownBtn(
      buttonHeight: healthDp(context, 45),
      enabled: hasItems,
      items: lines,
      value: '',
      emptyText: emptyText,
      emptyTextColor: _muted,
      emptyFontWeight: FontWeight.w300,
      valueTextColor: const Color(0xFF1A1A1E),
      borderColor: _border,
      // 한도 적용(모두 적용)일 때는 흰색, 후보 자체가 없을 때만 회색
      backgroundColor:
          hasItems || full ? Colors.white : const Color(0xFFF7F7F7),
      dimWhenDisabled: false,
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
    final closeSize = healthDp(context, 16);

    return Padding(
      padding: EdgeInsets.only(bottom: healthDp(context, 10)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(healthDp(context, 12)),
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: const Color(0x07FF5A8D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      color: const Color(0xFFFF5C8F),
                      fontSize: healthSp(context, 12),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    _setState(() {
                      _clearAmountQuote();
                      _selectedCoupons.removeWhere((c) => c.no == coupon.no);
                      if (_usedPoint > _maxUsablePointSnapped) {
                        _usedPoint = _maxUsablePointSnapped;
                        _writePointField(_usedPoint);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(healthDp(context, 14)),
                  child: SizedBox(
                    width: healthDp(context, 28),
                    height: healthDp(context, 28),
                    child: Center(
                      child: SvgPicture.asset(
                        AppAssets.popupCloseIcon,
                        width: closeSize,
                        height: closeSize,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: healthDp(context, 0)),
            Text(
              line,
              style: TextStyle(
                color: const Color(0xFF1A1A1E),
                fontSize: healthSp(context, 12),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                height: 1.0,
                letterSpacing: -0.6,
              ),
            ),
          ],
        ),
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
