part of 'payment_screen.dart';

extension _PaymentSections on _PaymentScreenState {
  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 14),
        vertical: healthDp(context, 20),
      ),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Color(0x7FD2D2D2)),
          borderRadius: BorderRadius.circular(healthDp(context, 15)),
        ),
      ),
      child: child,
    );
  }

  Widget _requiredLabel(BuildContext context, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(
            color: _muted,
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '*',
          style: TextStyle(
            color: _pink,
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderListSection(BuildContext context) {
    // 비대면: 예약시간 + 본품/추가상품 그룹 카드
    if (widget.showPrescriptionBookingProgress) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: healthDp(context, 20)),
        child: _sectionCard(
          child: PaymentProductCard(
            cartItems: widget.cartItems,
            reservationDate: widget.reservationDate,
            reservationTime: widget.reservationTime,
          ),
        ),
      );
    }

    // 일반상품: 업체별 묶음배송 카드 (CartGroupGeneralCard)
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 20)),
      child: PaymentGeneralProductCard(cartItems: widget.cartItems),
    );
  }


  /// 쿠폰/포인트 + 결제금액 내역 + 총 결제비용
  Widget _buildCouponPointTotalSection(BuildContext context) { 
    final showCoupon = !_couponPointDisabled &&
        !_couponLoadFailed &&
        _applicableCoupons.isNotEmpty;
    final showCouponFailure = !_couponPointDisabled && _couponLoadFailed;
    final showPoint = !_couponPointDisabled &&
        !_pointLoadFailed &&
        _pointSettings.usePoint &&
        _myPoint >= _pointMinToUse &&
        _myPoint > 0;
    final showPointFailure = !_couponPointDisabled && _pointLoadFailed;
    final remainCouponCount = _availableCouponsForUnifiedPicker().length;
    final remainPoint = (_myPoint - _pointDiscount).clamp(0, _myPoint);
    final showCouponPoint =
        showCoupon || showPoint || showCouponFailure || showPointFailure;

    // 페이지 양옆 20 + 쿠폰 카드 안쪽 14 → 결제금액 정렬
    final amountPad = healthDp(context, 34);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showCouponPoint)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: healthDp(context, 20)),
            child: _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showCouponFailure)
                    Text(
                      '쿠폰을 불러오지 못했습니다.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: healthSp(context, 14),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (showCoupon) ...[
                    Row(
                      children: [
                        Text(
                          '쿠폰 선택',
                          style: TextStyle(
                            color: const Color(0xFF1A1A1A),
                            fontSize: healthSp(context, 16),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            letterSpacing: -1.44,
                          ),
                        ),
                        SizedBox(width: healthDp(context, 5)),
                        Container(
                          constraints: BoxConstraints(
                            minWidth: healthDp(context, 18),
                            minHeight: healthDp(context, 18),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: healthDp(context, 5),
                            vertical: healthDp(context, 2),
                          ),
                          alignment: Alignment.center,
                          decoration: ShapeDecoration(
                            color: const Color(0x19FF5A8D),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(healthDp(context, 50)),
                            ),
                          ),
                          child: Text(
                            '$remainCouponCount',
                            style: TextStyle(
                              color: _pink,
                              fontSize: healthSp(context, 10),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: healthDp(context, 2)),
                    _couponDropdown(context),
                    if (_selectedCoupons.isNotEmpty) ...[
                      SizedBox(height: healthDp(context, 10)),
                      ..._selectedCoupons
                          .map((c) => _selectedCouponRow(context, c)),
                    ],
                  ],
                  if ((showCoupon || showCouponFailure) &&
                      (showPoint || showPointFailure)) ...[
                    // 선택 카드가 있으면 카드 bottom 10이 위 간격, 없으면 드롭다운과 10
                    if (_selectedCoupons.isEmpty)
                      SizedBox(height: healthDp(context, 10)),
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: _border,
                    ),
                    SizedBox(height: healthDp(context, 10)),
                  ],
                  if (showPointFailure)
                    Text(
                      '포인트를 불러오지 못했습니다.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: healthSp(context, 14),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (showPoint) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '포인트',
                          style: TextStyle(
                            color: const Color(0xFF1A1A1E),
                            fontSize: healthSp(context, 16),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            letterSpacing: -1.44,
                          ),
                        ),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '보유',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: healthSp(context, 14),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                              TextSpan(
                                text:
                                    ' ${PointService.formatPoint(remainPoint)}',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: healthSp(context, 14),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextSpan(
                                text: '점',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: healthSp(context, 14),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: healthDp(context, 10)),
                    Builder(
                      builder: (context) {
                        final maxPoint = _maxUsablePointSnapped;
                        final hasPoint = _usedPoint > 0;
                        final usedAll =
                            hasPoint && maxPoint > 0 && _usedPoint >= maxPoint;
                        final clearSize = healthDp(context, 16);
                        final pointFs = healthSp(context, 12);
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                height: healthDp(context, 45),
                                padding: EdgeInsets.symmetric(
                                  horizontal: healthDp(context, 10),
                                ),
                                alignment: Alignment.centerLeft,
                                clipBehavior: Clip.antiAlias,
                                decoration: ShapeDecoration(
                                  shape: RoundedRectangleBorder(
                                    side: const BorderSide(
                                      width: 1,
                                      color: _border,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      healthDp(context, 10),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _pointController,
                                        keyboardType: TextInputType.number,
                                        textAlignVertical:
                                            TextAlignVertical.center,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly
                                        ],
                                        strutStyle: StrutStyle(
                                          fontSize: pointFs,
                                          height: 1,
                                          forceStrutHeight: true,
                                        ),
                                        style: TextStyle(
                                          fontSize: pointFs,
                                          fontFamily: 'Gmarket Sans TTF',
                                          fontWeight: hasPoint
                                              ? FontWeight.w500
                                              : FontWeight.w300,
                                          height: 1,
                                          leadingDistribution:
                                              TextLeadingDistribution.even,
                                          color: const Color(0xFF1A1A1E),
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          isCollapsed: true,
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          contentPadding: EdgeInsets.only(
                                            bottom: healthDp(context, 2),
                                          ),
                                          hintText: '0 포인트',
                                          hintStyle: TextStyle(
                                            color: _muted,
                                            fontSize: pointFs,
                                            fontFamily: 'Gmarket Sans TTF',
                                            fontWeight: FontWeight.w300,
                                            height: 1,
                                            leadingDistribution:
                                                TextLeadingDistribution.even,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (hasPoint) ...[
                                      SizedBox(width: healthDp(context, 6)),
                                      InkWell(
                                        onTap: () {
                                          _setState(() {
                                            _clearAmountQuote();
                                            _usedPoint = 0;
                                            _writePointField(0);
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(
                                          clearSize,
                                        ),
                                        child: Container(
                                          width: clearSize,
                                          height: clearSize,
                                          alignment: Alignment.center,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFD2D2D2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.close,
                                            size: healthSp(context, 10),
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: healthDp(context, 10)),
                            InkWell(
                              onTap: usedAll || maxPoint <= 0
                                  ? null
                                  : () {
                                      _setState(() {
                                        _clearAmountQuote();
                                        _usedPoint = maxPoint;
                                        _writePointField(maxPoint);
                                      });
                                    },
                              borderRadius: BorderRadius.circular(
                                healthDp(context, 10),
                              ),
                              child: Container(
                                height: healthDp(context, 45),
                                padding: EdgeInsets.symmetric(
                                  horizontal: healthDp(context, 10),
                                  vertical: healthDp(context, 5),
                                ),
                                alignment: Alignment.center,
                                clipBehavior: Clip.antiAlias,
                                decoration: ShapeDecoration(
                                  color: usedAll || maxPoint <= 0
                                      ? _border
                                      : _pink,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      healthDp(context, 10),
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '전액사용',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: healthSp(context, 12),
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w500,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: healthDp(context, 10)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '※ 포인트는 100점 단위로 사용 가능합니다.',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: _muted,
                          fontSize: healthSp(context, 10),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                          letterSpacing: -0.40,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (showCouponPoint) SizedBox(height: healthDp(context, 20)),
        if (_couponPointNotice.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: amountPad),
            child: Text(
              _couponPointNotice,
              style: TextStyle(
                color: _muted,
                fontSize: healthSp(context, 11),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          SizedBox(height: healthDp(context, 20)),
        ],
        Padding(
          padding: EdgeInsets.symmetric(horizontal: amountPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '결제 금액',
                style: TextStyle(
                  color: const Color(0xFF1A1A1E),
                  fontSize: healthSp(context, 16),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  letterSpacing: -1.44,
                ),
              ),
              SizedBox(height: healthDp(context, 10)),
              _paymentAmountRow(
                context,
                '구매금액',
                '${PriceFormatter.format(_purchaseAmount)} 원',
              ),
              if (_couponDiscount > 0) ...[
                SizedBox(height: healthDp(context, 10)),
                _paymentAmountRow(
                  context,
                  '쿠폰할인',
                  '-${PriceFormatter.format(_couponDiscount)} 원',
                  valueColor: _pink,
                ),
              ],
              if (_pointDiscount > 0) ...[
                SizedBox(height: healthDp(context, 10)),
                _paymentAmountRow(
                  context,
                  '포인트 할인',
                  '-${PriceFormatter.format(_pointDiscount)} 원',
                  valueColor: _pink,
                ),
              ],
              if (_baseShipping + _extraShipping > 0) ...[
                SizedBox(height: healthDp(context, 10)),
                _paymentAmountRow(
                  context,
                  '배송비',
                  '${PriceFormatter.format(_baseShipping + _extraShipping)} 원',
                ),
                if (_extraShipping > 0) ...[
                  SizedBox(height: healthDp(context, 4)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '산간·도서 지역은 추가 배송비가 발생합니다',
                      style: TextStyle(
                        color: _muted,
                        fontSize: healthSp(context, 10),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                        letterSpacing: -0.40,
                      ),
                    ),
                  ),
                ],
              ],
              ..._shippingPayGuide(context),
              if (_shippingCouponDiscount > 0) ...[
                SizedBox(height: healthDp(context, 10)),
                _paymentAmountRow(
                  context,
                  '배송비 쿠폰',
                  '-${PriceFormatter.format(_shippingCouponDiscount)} 원',
                  valueColor: _pink,
                ),
              ],
              SizedBox(height: healthDp(context, 20)),
              Container(
                width: double.infinity,
                height: healthDp(context, 1),
                color: _border,
              ),
              SizedBox(height: healthDp(context, 20)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '총 결제비용',
                    style: TextStyle(
                      color: const Color(0xFF1A1A1E),
                      fontSize: healthSp(context, 16),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.44,
                    ),
                  ),
                  SizedBox(width: healthDp(context, 8)),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${PriceFormatter.format(_finalAmount)}원',
                          style: TextStyle(
                            color: _pink,
                            fontSize: healthSp(context, 20),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_pointSettings.showExpectedEarn) ...[
                          SizedBox(height: healthDp(context, 0)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: Text(
                                    _showExpectedPointHint
                                        ? '배송비를 제외한 결제 금액 기준, 상품별 적립'
                                        : '예상 적립 포인트 : ${PointService.formatPoint(_expectedPoint)} 점',
                                    key: ValueKey(_showExpectedPointHint),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: healthSp(context, 10),
                                      fontFamily: 'Gmarket Sans TTF',
                                      fontWeight: FontWeight.w300,
                                      letterSpacing: -0.40,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: healthDp(context, 0)),
                              GestureDetector(
                                onTap: () {
                                  _expectedPointHintTimer?.cancel();
                                  _setState(() => _showExpectedPointHint = true);
                                  _expectedPointHintTimer = Timer(
                                    const Duration(seconds: 2),
                                    () {
                                      if (!mounted) return;
                                      _setState(
                                        () => _showExpectedPointHint = false,
                                      );
                                    },
                                  );
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: EdgeInsets.all(healthDp(context, 2)),
                                  child: SvgPicture.asset(
                                    AppAssets.guideIcon,
                                    width: healthDp(context, 14),
                                    height: healthDp(context, 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _shippingPayGuide(BuildContext context) {
    if (_collectShipping.isEmpty && _choiceShipping.isEmpty) return const [];
    final noteStyle = TextStyle(
      color: _muted,
      fontSize: healthSp(context, 10),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w300,
      height: 1.4,
      letterSpacing: -0.40,
    );
    final widgets = <Widget>[SizedBox(height: healthDp(context, 8))];
    for (final item in _collectShipping) {
      final name = item.name.isEmpty ? '상품' : item.name;
      widgets.add(Text(
        '$name 배송비 ${PriceFormatter.format(item.fee)}원은 수령 후 지불입니다',
        style: noteStyle,
      ));
      widgets.add(SizedBox(height: healthDp(context, 6)));
    }
    for (final item in _choiceShipping) {
      final name = item.name.isEmpty ? '상품' : item.name;
      widgets.add(Text('$name 배송비 결제', style: noteStyle));
      widgets.add(SizedBox(height: healthDp(context, 4)));
      widgets.add(Row(
        children: [
          _sendCostOption(context, item, 0, '주문시 결제'),
          SizedBox(width: healthDp(context, 12)),
          _sendCostOption(context, item, 1, '수령후 지불'),
        ],
      ));
      widgets.add(SizedBox(height: healthDp(context, 6)));
    }
    return widgets;
  }

  Widget _sendCostOption(
    BuildContext context,
    ShippingPayItem item,
    int value,
    String label,
  ) {
    final selected = item.sendCost == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _updatingSendCost ? null : () => _chooseSendCost(item, value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: healthDp(context, 14),
            color: selected ? _pink : _muted,
          ),
          SizedBox(width: healthDp(context, 4)),
          Text(
            label,
            style: TextStyle(
              color: selected ? _pink : _muted,
              fontSize: healthSp(context, 11),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              letterSpacing: -0.40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentAmountRow(
    BuildContext context,
    String label,
    String value, {
    Color valueColor = const Color(0xFF1A1A1E),
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _muted,
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodHeaderSection(BuildContext context) {
    final showEscrow = _pointSettings.escrowUse &&
        (_paymentMethodIndex == 1 || _paymentMethodIndex == 2);
    final showCardNoint =
        _pointSettings.cardNointUse && _paymentMethodIndex == 0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 34)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '결제 수단',
            style: TextStyle(
              color: const Color(0xFF1A1A1A),
              fontSize: healthSp(context, 16),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              letterSpacing: -1.44,
            ),
          ),
          SizedBox(height: healthDp(context, 2)),
          Row(
            children: [
              Expanded(child: _methodButton(context, '신용카드', 0)),
              SizedBox(width: healthDp(context, 10)),
              Expanded(child: _methodButton(context, '계좌이체', 1)),
              SizedBox(width: healthDp(context, 10)),
              Expanded(child: _methodButton(context, '가상계좌', 2)),
            ],
          ),
          if (showEscrow) ...[
            SizedBox(height: healthDp(context, 20)),
            _escrowCombinedCard(context),
          ],
          SizedBox(height: healthDp(context, 10)),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (showCardNoint) ...[
                  Text(
                    '※ 무이자할부는 일반카드 결제에 적용됩니다.',
                    style: TextStyle(
                      color: _muted,
                      fontSize: healthSp(context, 10),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                      letterSpacing: -0.40,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 5)),
                ],
                Text(
                  '※ 최소 결제금액은 3,000원 입니다.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: healthSp(context, 10),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.40,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _paymentMethodIconAsset(int index) {
    switch (index) {
      case 0:
        return AppAssets.payCredit;
      case 1:
        return AppAssets.payCash;
      case 2:
        return AppAssets.payVirtualAccount;
      default:
        return AppAssets.payCredit;
    }
  }

  Widget _methodButton(BuildContext context, String label, int index) {
    final selected = _paymentMethodIndex == index;
    final iconAsset = _paymentMethodIconAsset(index);
    final iconSz = healthDp(context, 24);
    return InkWell(
      onTap: () {
        if (_paymentMethodIndex == index) return;
        _setState(() {
          _paymentMethodIndex = index;
          if (!_pointSettings.escrowUse || (index != 1 && index != 2)) {
            _useEscrow = false;
          }
        });
      },
      borderRadius: BorderRadius.circular(healthDp(context, 12)),
      child: Container(
        constraints: BoxConstraints(minHeight: healthDp(context, 65)),
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 11),
          vertical: healthDp(context, 10),
        ),
        decoration: ShapeDecoration(
          color: selected ? const Color(0x0CFF5A8D) : Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: healthDp(context, 1.11),
              color: selected ? const Color(0xFFFF5A8D) : _border,
            ),
            borderRadius: BorderRadius.circular(healthDp(context, 12)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              iconAsset,
              width: iconSz,
              height: iconSz,
              colorFilter: const ColorFilter.mode(
                Color(0xFF1A1A1A),
                BlendMode.srcIn,
              ),
            ),
            SizedBox(height: healthDp(context, 5)),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF1A1A1A),
                fontSize: healthSp(context, 12),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _escrowCombinedCard(BuildContext context) {
    final on = _useEscrow;
    final topRadius = healthDp(context, 12);
    final bottomRadius = healthDp(context, on ? 10 : 12);
    const borderColor = Color(0x7FD2D2D2);
    final headerRadius = BorderRadius.only(
      topLeft: Radius.circular(topRadius),
      topRight: Radius.circular(topRadius),
      bottomLeft: Radius.circular(on ? 0 : bottomRadius),
      bottomRight: Radius.circular(on ? 0 : bottomRadius),
    );
    final iconSz = healthDp(context, 66);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => _setState(() => _useEscrow = !_useEscrow),
          borderRadius: headerRadius,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(healthDp(context, 10)),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 1, color: borderColor),
                borderRadius: headerRadius,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '에스크로 결제 사용',
                        style: TextStyle(
                          color: const Color(0xFF1A1A1A),
                          fontSize: healthSp(context, 12),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: healthDp(context, 0)),
                      Text(
                        '구매자 안전결제로 진행합니다',
                        style: TextStyle(
                          color: const Color(0xFF898989),
                          fontSize: healthSp(context, 10),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: healthDp(context, 35),
                  padding: EdgeInsets.all(healthDp(context, 2)),
                  decoration: ShapeDecoration(
                    color: on ? _pink : const Color(0xFFD2D2D2),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 12)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: on
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      Container(
                        width: healthDp(context, 15),
                        height: healthDp(context, 15),
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              healthDp(context, 50),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (on)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(healthDp(context, 10)),
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: const Color(0xFFF1F1F1),
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 1, color: borderColor),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(bottomRadius),
                  bottomRight: Radius.circular(bottomRadius),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      AppAssets.escrow,
                      width: iconSz,
                      height: iconSz,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(width: healthDp(context, 10)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '구매안전 (에스크로) 서비스',
                            style: TextStyle(
                              color: const Color(0xFF1A1A1E),
                              fontSize: healthSp(context, 10),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                          SizedBox(height: healthDp(context, 5)),
                          Text(
                            '고객님은 안전거래를 위해 현금 등으로 결제시 저희 쇼핑몰에 가입한 KCP의 구매안전서비스를 이용하실 수 있습니다. 계좌이체 또는 가상계좌 등 현금 거래에만 해당되며, 신용카드로 구매하는 거래에는 해당되지 않습니다.',
                            style: TextStyle(
                              color: const Color(0xFF1A1A1E),
                              fontSize: healthSp(context, 8),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                              height: 1.3,
                              letterSpacing: -0.32,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: healthDp(context, 10)),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '2006.4.1 제정, 2013.11.29 개정 전자상거래 등에서의 소비자 보호에 관한 법률',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: const Color(0xFF1A1A1E),
                      fontSize: healthSp(context, 8),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
