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
        padding: EdgeInsets.symmetric(horizontal: healthDp(context, 27)),
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
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 27)),
      child: PaymentGeneralProductCard(cartItems: widget.cartItems),
    );
  }


  /// 쿠폰/포인트 + 결제금액 내역 + 총 결제비용
  Widget _buildCouponPointTotalSection(BuildContext context) {
    final showCoupon = !_couponPointDisabled && _applicableCoupons.isNotEmpty;
    final showPoint = !_couponPointDisabled && _myPoint > 0;
    final showCouponPoint = showCoupon || showPoint;

    // 쿠폰 카드 안쪽(14)과 맞춰 결제금액·수단은 약 41(≈35~)로 맞춤
    final amountPad = healthDp(context, 41);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showCouponPoint)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: healthDp(context, 27)),
            child: _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showCoupon) ...[
                    Row(
                      children: [
                        Text(
                          '쿠폰 선택',
                          style: TextStyle(
                            color: const Color(0xFF1A1A1E),
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
                            '${_applicableCoupons.length}',
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
                  if (showCoupon && showPoint)
                    SizedBox(height: healthDp(context, 20)),
                  if (showPoint) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        Text(
                          '보유 ${PointService.formatPoint(_myPoint)}점',
                          style: TextStyle(
                            color: _muted,
                            fontSize: healthSp(context, 14),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: healthDp(context, 2)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Container(
                            height: healthDp(context, 45),
                            alignment: Alignment.centerLeft,
                            padding: EdgeInsets.symmetric(
                              horizontal: healthDp(context, 10),
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              border: Border.all(color: _border),
                              borderRadius:
                                  BorderRadius.circular(healthDp(context, 10)),
                            ),
                            child: TextField(
                              controller: _pointController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              style: TextStyle(
                                fontSize: healthSp(context, 12),
                                fontFamily: 'Gmarket Sans TTF',
                                height: 1,
                                color: const Color(0xFF1A1A1E),
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText:
                                    '${_usedPoint > 0 ? PointService.formatPoint(_usedPoint) : '0'} 포인트',
                                hintStyle: TextStyle(
                                  color: _muted,
                                  fontSize: healthSp(context, 12),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w300,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: healthDp(context, 10)),
                        InkWell(
                          onTap: () {
                            final max = _maxUsablePointHundreds;
                            _setState(() {
                              _usedPoint = max;
                              _writePointField(max);
                            });
                          },
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 10)),
                          child: Container(
                            height: healthDp(context, 45),
                            padding: EdgeInsets.symmetric(
                              horizontal: healthDp(context, 10),
                              vertical: healthDp(context, 5),
                            ),
                            alignment: Alignment.center,
                            decoration: ShapeDecoration(
                              color: _pink,
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
                SizedBox(height: healthDp(context, 16)),
                _paymentAmountRow(
                  context,
                  '쿠폰할인',
                  '-${PriceFormatter.format(_couponDiscount)} 원',
                  valueColor: _pink,
                ),
              ],
              if (_pointDiscount > 0) ...[
                SizedBox(height: healthDp(context, 16)),
                _paymentAmountRow(
                  context,
                  '포인트할인',
                  '-${PriceFormatter.format(_pointDiscount)} 원',
                  valueColor: _pink,
                ),
              ],
              if (_baseShipping + _extraShipping > 0) ...[
                SizedBox(height: healthDp(context, 16)),
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
              if (_shippingCouponDiscount > 0) ...[
                SizedBox(height: healthDp(context, 16)),
                _paymentAmountRow(
                  context,
                  '배송비 쿠폰',
                  '-${PriceFormatter.format(_shippingCouponDiscount)} 원',
                  valueColor: _pink,
                ),
              ],
              SizedBox(height: healthDp(context, 16)),
              Container(
                width: double.infinity,
                height: healthDp(context, 1),
                color: _border,
              ),
              SizedBox(height: healthDp(context, 16)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${PriceFormatter.format(_finalAmount)}원',
                        style: TextStyle(
                          color: _pink,
                          fontSize: healthSp(context, 20),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: healthDp(context, 4)),
                      Text(
                        '예상 적립 포인트 : ${PointService.formatPoint(_expectedPoint)} 점',
                        style: TextStyle(
                          color: _muted,
                          fontSize: healthSp(context, 10),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                          height: 1.5,
                          letterSpacing: -0.40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
    final showEscrow = _paymentMethodIndex == 1 || _paymentMethodIndex == 2;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 41)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '결제 수단',
            style: TextStyle(
              color: const Color(0xFF1A1A1E),
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
                Text(
                  '※ 할부 결제는 일반카드 결제만 가능합니다.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: healthSp(context, 10),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.40,
                  ),
                ),
                SizedBox(height: healthDp(context, 5)),
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
      case 2:
        return AppAssets.payCash;
      default:
        return AppAssets.payCredit;
    }
  }

  Widget _methodButton(BuildContext context, String label, int index) {
    final selected = _paymentMethodIndex == index;
    final iconAsset = _paymentMethodIconAsset(index);
    final iconSz = healthDp(context, 24);
    return InkWell(
      onTap: () => _setState(() => _paymentMethodIndex = index),
      borderRadius: BorderRadius.circular(healthDp(context, 12)),
      child: Container(
        constraints: BoxConstraints(minHeight: healthDp(context, 65)),
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 11),
          vertical: healthDp(context, 10),
        ),
        decoration: ShapeDecoration(
          color: selected ? const Color(0x0CFF5C8F) : Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: healthDp(context, 1.11),
              color: selected ? const Color(0xFFFF5C8F) : _border,
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
                Color(0xFF1A1A1E),
                BlendMode.srcIn,
              ),
            ),
            SizedBox(height: healthDp(context, 5)),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF1A1A1E),
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
    final radius = healthDp(context, 12);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(width: 1, color: const Color(0x7FD2D2D2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _setState(() => _useEscrow = !_useEscrow),
            borderRadius: BorderRadius.circular(radius),
            child: Padding(
              padding: EdgeInsets.all(healthDp(context, 10)),
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
                        SizedBox(height: healthDp(context, 3)),
                        Text(
                          '구매자 안전결제로 진행합니다',
                          style: TextStyle(
                            color: const Color(0xFF898989),
                            fontSize: healthSp(context, 10),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w300,
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
                    decoration: BoxDecoration(
                      color: on ? _pink : const Color(0xFFD2D2D2),
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 12)),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          on ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        Container(
                          width: healthDp(context, 15),
                          height: healthDp(context, 15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(healthDp(context, 50)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x19000000),
                                blurRadius: 2,
                                offset: Offset(0, 1),
                                spreadRadius: -1,
                              ),
                              BoxShadow(
                                color: Color(0x19000000),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (on) ...[
            Container(
              width: double.infinity,
              height: 1,
              color: const Color(0xFFE8E8E8),
            ),
            ClipRRect(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(radius),
                bottomRight: Radius.circular(radius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFF7F7F7),
                    padding: EdgeInsets.all(healthDp(context, 10)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 6)),
                          child: Image.asset(
                            AppAssets.escrow,
                            width: healthDp(context, 56),
                            height: healthDp(context, 56),
                            fit: BoxFit.contain,
                          ),
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
                                ),
                              ),
                              SizedBox(height: healthDp(context, 5)),
                              Text(
                                '고객님은 안전거래를 위해 현금 등으로 결제시 저희 쇼핑몰에 가입한 KCP의 구매안전서비스를 이용하실 수 있습니다. 계좌이체 또는 가상계좌 등 현금 거래에만 해당되며, 신용카드 거래에는 해당되지 않습니다.',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: healthSp(context, 8),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w300,
                                  height: 1.88,
                                  letterSpacing: -0.24,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFF7F7F7),
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 10),
                      vertical: healthDp(context, 6),
                    ),
                    child: Text(
                      '2006.4.1 제정, 2013.11.29 개정 전자상거래 등에서의 소비자 보호에 관한 법률',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: const Color(0xFFAAAAAA),
                        fontSize: healthSp(context, 8),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                        letterSpacing: -0.32,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
