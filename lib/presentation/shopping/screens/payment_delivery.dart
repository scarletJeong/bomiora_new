part of 'payment_screen.dart';

extension _PaymentDelivery on _PaymentScreenState {
  bool get _hasSavedAddress {
    final ad = _defaultAddress;
    if (ad == null) return false;
    final addr = [
      _safe(ad['adAddr1']),
      _safe(ad['adAddr2']),
      _safe(ad['adName']),
    ].any((e) => e.isNotEmpty);
    return addr;
  }

  /// [preserveDeliveryMemo]: 배송지 변경 시 주소북 adMemo가 비어 있으면
  /// 결제 화면에서 고른 배송요청사항(드롭다운)을 유지한다.
  void _applyAddressMode({
    bool preserveDeliveryMemo = false,
    bool refreshShipping = true,
  }) {
    final ad = _defaultAddress;
    _addressNameController.text = _safe(ad?['adSubject']);
    _receiverController.text = _safe(ad?['adName']);
    _phoneController.text = _safe(ad?['adHp']);
    _zipController.text =
        _formatPostalCodeDisplay(_shippingZipFromAddress(ad));
    _addressController.text = [
      _safe(ad?['adAddr1']),
      _safe(ad?['adAddr2']),
      _safe(ad?['adAddr3']),
    ].where((e) => e.isNotEmpty).join(' ');
    _detailAddressController.clear();
    final addressMemo = _safe(ad?['adMemo']);
    if (addressMemo.isNotEmpty || !preserveDeliveryMemo) {
      _deliveryMemo = addressMemo;
      _deliveryMemoCustomSelected =
          DeliveryMemoDropdown.isCustomMemo(addressMemo);
    }
    if (refreshShipping) {
      _loadShippingQuote();
    }
  }

  Future<CartShippingQuote?> _loadShippingQuote({bool retryIfZero = false}) async {
    final quote = await _fetchShippingQuote();
    final missingFee = quote == null || quote.baseShipping <= 0;
    if (!retryIfZero || !missingFee || widget.cartItems.isEmpty) {
      return quote;
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return quote;
    return _fetchShippingQuote();
  }

  Future<CartShippingQuote?> _fetchShippingQuote() async {
    final gen = ++_shippingQuoteGen;
    final ids = widget.cartItems.map((item) => item.ctId).where((id) => id > 0).toList();
    if (ids.isEmpty) return null;
    final quote = await CartService.getShippingQuote(
      ctIds: ids,
      zip: _zipController.text,
    );
    if (!mounted || gen != _shippingQuoteGen) return quote;
    if (quote == null) return null;
    // 진입 shippingCost와 무관하게 견적 결과를 UI·쿠폰 기준으로 쓴다(0원 무료배송 포함).
    _setState(() {
      _baseShipping = quote.baseShipping < 0 ? 0 : quote.baseShipping;
      _extraShipping = quote.extraShipping < 0 ? 0 : quote.extraShipping;
      _pointRate = quote.pointRate;
      _syncCouponLists();
    });
    return quote;
  }

  Future<void> _openDeliveryAddressChangePopup() async {
    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DeliveryAddressChangePopup(
        initiallySelectedAddress: _defaultAddress,
      ),
    );
    if (!mounted) return;
    if (result is Map<String, dynamic>) {
      _setState(() {
        _defaultAddress = result;
        _applyAddressMode(preserveDeliveryMemo: true);
      });
    }
  }


  /// 배송요청사항 드롭다운 선택값 → 주문 `od_memo`
  String get _deliveryRequestMemo => _deliveryMemo.trim();

  String _safe(dynamic value) => (value ?? '').toString().trim();

  String _postalDigits(String raw) =>
      raw.replaceAll(RegExp(r'[^0-9]'), '');


  /// 웹 주문서와 같이 `ad_zip1 + ad_zip2` 전체로 도서·산간 추가배송비를 조회한다.
  /// 5자리가 `adZip1`에만 있으면 그 값을 쓰고, 3+2로 나뉜 주소는 이어 붙인다.
  String _shippingZipFromAddress(Map<String, dynamic>? ad) {
    final z1 = _postalDigits(_safe(ad?['adZip1']));
    final z2 = _postalDigits(_safe(ad?['adZip2']));
    if (z1.length >= 5) return z1;
    return '$z1$z2';
  }

  String _formatPostalCodeDisplay(String postalCode) {
    final t = _postalDigits(postalCode);
    if (t.length == 5) {
      return '${t.substring(0, 3)}-${t.substring(3)}';
    }
    return t;
  }

  String _formatPhoneDisplay(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    }
    if (digits.length == 10) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return raw;
  }

  String _fullDeliveryAddressText() {
    return [
      _addressController.text.trim(),
      _detailAddressController.text.trim(),
    ].where((e) => e.isNotEmpty).join(' ');
  }


  Map<String, String> _splitZipForApi(String raw) {
    var t = raw.replaceAll(RegExp(r'\s'), '');
    if (t.isEmpty) return {'zip1': '', 'zip2': ''};
    if (t.contains('-')) {
      final i = t.indexOf('-');
      return {'zip1': t.substring(0, i), 'zip2': t.substring(i + 1)};
    }
    if (t.length == 5) {
      return {'zip1': t.substring(0, 3), 'zip2': t.substring(3)};
    }
    return {'zip1': t, 'zip2': ''};
  }

  Future<void> _maybeSaveDefaultAddress(String mbId) async {
    if (_hasSavedAddress && !_saveAsDefault) return;
    if (!_hasSavedAddress) {
      _saveAsDefault = true;
    }
    final zipParts = _splitZipForApi(_zipController.text.trim());
    final subject = _addressNameController.text.trim().isNotEmpty
        ? _addressNameController.text.trim()
        : _addressLabelChip;
    await AddressService.addAddress({
      'mbId': mbId,
      'adSubject': subject,
      'adDefault': 1,
      'ad_default': 1,
      'adName': _receiverController.text.trim(),
      'adTel': _phoneController.text.trim(),
      'adHp': _phoneController.text.trim(),
      'adZip1': zipParts['zip1'] ?? '',
      'adZip2': zipParts['zip2'] ?? '',
      'adAddr1': _addressController.text.trim(),
      'adAddr2': _detailAddressController.text.trim(),
      'adAddr3': '',
      'adJibeon': '',
      'adMemo': _deliveryRequestMemo,
    });
  }

  Widget _addressChangeButton(BuildContext context) => InkWell(
        onTap: _openDeliveryAddressChangePopup,
        borderRadius: BorderRadius.circular(healthDp(context, 9999)),
        child: Container(
          width: healthDp(context, 94),
          height: healthDp(context, 30),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(healthDp(context, 9999)),
            ),
          ),
          child: Text(
            '배송지 변경',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );

  Widget _addressLabelChipBtn(BuildContext context, String label) {
    final selected = (!_showCustomAddressName && _addressLabelChip == label) ||
        (_showCustomAddressName && label == '직접입력');
    return InkWell(
      onTap: () {
        _setState(() {
          if (label == '직접입력') {
            _showCustomAddressName = true;
            _addressLabelChip = '직접입력';
            if (_addressNameController.text == '집' ||
                _addressNameController.text == '회사') {
              _addressNameController.clear();
            }
          } else {
            _showCustomAddressName = false;
            _addressLabelChip = label;
            _addressNameController.text = label;
          }
        });
      },
      borderRadius: BorderRadius.circular(healthDp(context, 15)),
      child: Container(
        height: healthDp(context, _kDeliveryFieldHeight),
        padding: EdgeInsets.symmetric(horizontal: healthDp(context, 14)),
        decoration: ShapeDecoration(
          color: selected ? const Color(0x0CFF5A8D) : Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: 1,
              color: selected ? _pink : _border,
            ),
            borderRadius: BorderRadius.circular(healthDp(context, 15)),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _pink : const Color(0xFF898383),
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
      ),
    );
  }


  /// 높이 45 고정 박스 (테두리·배경). TextField Outline은 높이 무시하므로 사용하지 않음.
  Widget _deliveryFieldBox({
    required Widget child,
    Color? fillColor,
    Color? borderColor,
    VoidCallback? onTap,
  }) {
    final h = healthDp(context, _kDeliveryFieldHeight);
    final r = healthDp(context, 10);
    final box = Container(
      width: double.infinity,
      height: h,
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: fillColor ?? _kDeliveryFieldFill,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(width: 1, color: borderColor ?? _border),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(r),
      child: box,
    );
  }

  Widget _buildDeliveryMemoDropdown() {
    return DeliveryMemoDropdown(
      value: _deliveryMemo,
      customSelected: _deliveryMemoCustomSelected,
      commitCustomOnUnfocus: false,
      onCustomModeChanged: (selected) {
        if (_deliveryMemoCustomSelected == selected) return;
        _setState(() => _deliveryMemoCustomSelected = selected);
      },
      onChanged: (value) {
        _setState(() => _deliveryMemo = value);
      },
    );
  }

  Widget _deliveryTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return _deliveryFieldBox(
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(
          fontSize: healthSp(context, 12),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
          height: 1.2,
          color: const Color(0xFF1A1A1E),
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isCollapsed: true,
          hintText: hint,
          hintStyle: TextStyle(
            color: _muted,
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildDeliverySection(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 27)),
      child: _hasSavedAddress
          ? _buildDeliveryFilledCard(context)
          : _buildDeliveryEmptyForm(context),
    );
  }

  Widget _buildDeliveryFilledCard(BuildContext context) {
    final name = _receiverController.text.trim();
    final label = _addressNameController.text.trim();
    final title = label.isEmpty ? name : '$name ($label)';
    final phone = _formatPhoneDisplay(_phoneController.text.trim());
    final fullAddress = _fullDeliveryAddressText();
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title.isEmpty ? '배송지' : title,
                  style: TextStyle(
                    color: const Color(0xFF333333),
                    fontSize: healthSp(context, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1.75,
                  ),
                ),
              ),
              _addressChangeButton(context),
            ],
          ),
          SizedBox(height: healthDp(context, 5)),
          if (phone.isNotEmpty)
            Text(
              phone,
              style: TextStyle(
                color: const Color(0xFF1A1A1E),
                fontSize: healthSp(context, 12),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          if (fullAddress.isNotEmpty) ...[
            SizedBox(height: healthDp(context, 4)),
            Text(
              fullAddress,
              style: TextStyle(
                color: const Color(0xFF1A1A1E),
                fontSize: healthSp(context, 12),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          SizedBox(height: healthDp(context, 10)),
          _buildDeliveryMemoDropdown(),
          SizedBox(height: healthDp(context, 5)),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '※ 영업일 기준 오후 2시 이전 처방완료 시 당일 발송',
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
      ),
    );
  }

  Widget _buildDeliveryEmptyForm(BuildContext context) {
    final addressDisplay = _addressController.text.trim();

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '배송지',
            style: TextStyle(
              color: const Color(0xFF1A1A1E),
              fontSize: healthSp(context, 16),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              letterSpacing: -1.44,
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          Text(
            '배송지명 (선택)',
            style: TextStyle(
              color: _muted,
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 2)),
          Row(
            children: [
              _addressLabelChipBtn(context, '집'),
              SizedBox(width: healthDp(context, 8)),
              _addressLabelChipBtn(context, '회사'),
              SizedBox(width: healthDp(context, 8)),
              _addressLabelChipBtn(context, '직접입력'),
            ],
          ),
          if (_showCustomAddressName) ...[
            SizedBox(height: healthDp(context, 2)),
            _deliveryTextField(
              controller: _addressNameController,
              hint: '배송지명을 입력해 주세요.',
            ),
          ],
          SizedBox(height: healthDp(context, 10)),
          _requiredLabel(context, '받으시는 분'),
          SizedBox(height: healthDp(context, 2)),
          _deliveryTextField(
            controller: _receiverController,
            hint: '수령인의 이름을 입력해 주세요.',
          ),
          SizedBox(height: healthDp(context, 10)),
          _requiredLabel(context, '연락처'),
          SizedBox(height: healthDp(context, 2)),
          _deliveryTextField(
            controller: _phoneController,
            hint: '‘-’없이 기입해주세요.',
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          SizedBox(height: healthDp(context, 10)),
          _requiredLabel(context, '배송지 주소'),
          SizedBox(height: healthDp(context, 2)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _deliveryFieldBox(
                  onTap: _openAddressSearch,
                  child: Text(
                    addressDisplay.isEmpty ? '주소를 검색해 주세요' : addressDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: addressDisplay.isEmpty
                          ? _muted
                          : const Color(0xFF1A1A1E),
                      fontSize: healthSp(context, 12),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              SizedBox(width: healthDp(context, 10)),
              Material(
                color: _pink,
                borderRadius: BorderRadius.circular(healthDp(context, 10)),
                child: InkWell(
                  onTap: _openAddressSearch,
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                  child: SizedBox(
                    height: healthDp(context, _kDeliveryFieldHeight),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 10),
                      ),
                      child: Center(
                        child: Text(
                          '주소 검색',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: healthSp(context, 12),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_addressController.text.trim().isNotEmpty) ...[
            SizedBox(height: healthDp(context, 10)),
            _deliveryTextField(
              controller: _detailAddressController,
              hint: '상세주소를 입력해 주세요.',
            ),
          ],
          SizedBox(height: healthDp(context, 10)),
          _buildDeliveryMemoDropdown(),
          SizedBox(height: healthDp(context, 10)),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '※ 영업일 기준 오후 2시 이전 처방완료 시 당일 발송',
              style: TextStyle(
                color: _muted,
                fontSize: healthSp(context, 10),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
                letterSpacing: -0.40,
              ),
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          InkWell(
            onTap: () {
              if (_saveAsDefault && !_hasSavedAddress) {
                AppToastOverlay.show(
                  context,
                  '기본 배송지는 한 개 이상 있어야 합니다.',
                );
                return;
              }
              _setState(() => _saveAsDefault = !_saveAsDefault);
            },
            child: Row(
              children: [
                Container(
                  width: healthDp(context, 20),
                  height: healthDp(context, 20),
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(width: 1, color: _border),
                      borderRadius: BorderRadius.circular(healthDp(context, 4)),
                    ),
                  ),
                  child: _saveAsDefault
                      ? Icon(Icons.check,
                          size: healthDp(context, 14), color: _pink)
                      : null,
                ),
                SizedBox(width: healthDp(context, 5)),
                Text(
                  '기본 배송지로 설정',
                  style: TextStyle(
                    color: const Color(0xFF1A1A1E),
                    fontSize: healthSp(context, 12),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddressSearch() async {
    final selected = await showDaumPostcodeSearchDialog(context);
    if (!mounted || selected == null) return;

    final parsed = daumSelectedAddress(selected);

    _setState(() {
      _zipController.text = _formatPostalCodeDisplay(parsed.postalCode);
      _addressController.text = parsed.address;
      _detailAddressController.clear();
    });
    _loadShippingQuote();
  }
}
