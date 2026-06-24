import 'package:flutter/material.dart';
import '../../../common/widgets/daum_postcode_search_dialog.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../../data/models/delivery/delivery_model.dart';
import '../../../../data/services/address_service.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/delivery_service.dart' as order_service;

class DeliveryAddressChangePopup extends StatefulWidget {
  /// 주문 후 배송지 변경 시 주문번호. 결제 화면 등 주문 전에는 null.
  final String? orderId;

  const DeliveryAddressChangePopup({
    super.key,
    this.orderId,
  });

  bool get _isCheckoutMode =>
      orderId == null || orderId!.trim().isEmpty;

  @override
  State<DeliveryAddressChangePopup> createState() =>
      _DeliveryAddressChangePopupState();
}

class _DeliveryAddressChangePopupState
    extends State<DeliveryAddressChangePopup> {
  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kInk = Color(0xFF1A1A1A);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kBorder = Color(0xFFD2D2D2);

  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _addresses = [];
  int? _selectedAddressId;
  String _orderDateText = '-';
  String _orderNumberText = '-';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await AuthService.getUser();
    if (user == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    final detailResult = widget._isCheckoutMode
        ? null
        : await order_service.OrderService.getOrderDetail(
            odId: widget.orderId!,
            mbId: user.id,
          );
    final addresses = await AddressService.getAddressList(user.id);

    if (!mounted) return;
    if (!widget._isCheckoutMode &&
        detailResult != null &&
        detailResult['success'] == true) {
      final order = detailResult['order'] as OrderDetailModel;
      _orderDateText = order.orderDate;
      _orderNumberText = order.odId;
    }

    _addresses = addresses;
    if (_addresses.isNotEmpty) {
      final defaultAddress = _addresses.firstWhere(
        (a) => a['adDefault'] == 1,
        orElse: () => _addresses.first,
      );
      _selectedAddressId = defaultAddress['adId'] as int?;
    }
    setState(() => _isLoading = false);
  }

  Future<void> _submit() async {
    if (_selectedAddressId == null || _isSubmitting) return;

    if (widget._isCheckoutMode) {
      final selected = _addresses.firstWhere(
        (a) => a['adId'] == _selectedAddressId,
        orElse: () => <String, dynamic>{},
      );
      if (selected.isNotEmpty && mounted) {
        Navigator.pop(context, selected);
      }
      return;
    }

    setState(() => _isSubmitting = true);

    final user = await AuthService.getUser();
    if (user == null) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      return;
    }

    final result = await order_service.OrderService.changeDeliveryAddress(
      odId: widget.orderId!,
      mbId: user.id,
      addressId: _selectedAddressId!,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.pop(context, result['success'] == true);
  }

  Future<void> _openAddressRegister() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _AddressRegisterDialog(),
    );
    if (result == true && mounted) {
      setState(() => _isLoading = true);
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final popupWidth = healthDp(context, 300);
    final radius = healthDp(context, 20);
    final pad20 = healthDp(context, 20);
    final pad10 = healthDp(context, 10);
    final borderW = healthDp(context, 1);
    final selectedBorderW = healthDp(context, 1.5);

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: SizedBox(
          width: popupWidth,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.only(
                    top: pad20,
                    left: pad20,
                    right: pad20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '배송지 선택',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _kInk,
                          fontSize: healthSp(context, 20),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: healthDp(context, 5)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          onTap: _openAddressRegister,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: healthDp(context, 2),
                              vertical: healthDp(context, 2),
                            ),
                            child: Text(
                              '+ 새 배송지 등록',
                              style: TextStyle(
                                color: _kPink,
                                fontSize: healthSp(context, 12),
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!widget._isCheckoutMode) ...[
                        Container(
                          padding: EdgeInsets.all(pad10),
                          decoration: ShapeDecoration(
                            color: const Color(0x33D2D2D2),
                            shape: RoundedRectangleBorder(
                              side: BorderSide(width: borderW, color: _kBorder),
                              borderRadius:
                                  BorderRadius.circular(healthDp(context, 10)),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '주문정보',
                                style: TextStyle(
                                  color: _kInk,
                                  fontSize: healthSp(context, 14),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: healthDp(context, 8)),
                              Text(
                                '주문일자: $_orderDateText',
                                style: TextStyle(
                                  fontSize: healthSp(context, 10),
                                  fontFamily: 'Gmarket Sans TTF',
                                ),
                              ),
                              SizedBox(height: healthDp(context, 4)),
                              Text(
                                '주문번호: $_orderNumberText',
                                style: TextStyle(
                                  fontSize: healthSp(context, 10),
                                  fontFamily: 'Gmarket Sans TTF',
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: healthDp(context, 5)),
                      ],
                      if (_isLoading)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: healthDp(context, 10),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: healthDp(context, 280),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _addresses.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(height: healthDp(context, 5)),
                            itemBuilder: (context, index) {
                              final a = _addresses[index];
                              final adId = a['adId'] as int?;
                              final selected = _selectedAddressId == adId;
                              final line =
                                  '${a['adAddr1'] ?? ''} ${a['adAddr2'] ?? ''} ${a['adAddr3'] ?? ''}'
                                      .trim();
                              return InkWell(
                                onTap: adId == null
                                    ? null
                                    : () => setState(
                                        () => _selectedAddressId = adId),
                                borderRadius: BorderRadius.circular(
                                    healthDp(context, 10)),
                                child: Container(
                                  padding: EdgeInsets.all(pad10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: selected ? _kPink : _kBorder,
                                      width: selected ? selectedBorderW : borderW,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                        healthDp(context, 10)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a['adSubject']?.toString() ?? '',
                                        style: TextStyle(
                                          fontSize: healthSp(context, 13),
                                          fontFamily: 'Gmarket Sans TTF',
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: healthDp(context, 3)),
                                      Text(
                                        '${a['adName'] ?? ''} ${a['adHp'] ?? ''}',
                                        style: TextStyle(
                                          fontSize: healthSp(context, 13),
                                          fontFamily: 'Gmarket Sans TTF',
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                        ),
                                      ),
                                      SizedBox(height: healthDp(context, 3)),
                                      Text(
                                        line,
                                        style: TextStyle(
                                          fontSize: healthSp(context, 11),
                                          fontWeight: FontWeight.w300,
                                          fontFamily: 'Gmarket Sans TTF',
                                          color: _kInk,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      SizedBox(height: pad20),
                    ],
                  ),
                ),
                SizedBox(
                  height: healthDp(context, 42),
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: const Color(0xFFF7F7F7),
                          child: InkWell(
                            onTap: () => Navigator.pop(context, false),
                            child: Center(
                              child: Text(
                                '취소',
                                style: TextStyle(
                                  color: _kMuted,
                                  fontSize: healthSp(context, 14),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Material(
                          color: _kPink,
                          child: InkWell(
                            onTap: _isSubmitting ? null : _submit,
                            child: Center(
                              child: _isSubmitting
                                  ? SizedBox(
                                      width: healthDp(context, 16),
                                      height: healthDp(context, 16),
                                      child: CircularProgressIndicator(
                                        strokeWidth: healthDp(context, 2),
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      '확인',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: healthSp(context, 14),
                                        fontFamily: 'Gmarket Sans TTF',
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
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
      ),
    );
  }
}

class _AddressRegisterDialog extends StatefulWidget {
  const _AddressRegisterDialog();

  @override
  State<_AddressRegisterDialog> createState() => _AddressRegisterDialogState();
}

class _AddressRegisterDialogState extends State<_AddressRegisterDialog> {
  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kInk = Color(0xFF1A1A1A);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kBorder = Color(0xFFD2D2D2);

  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _zip = TextEditingController();
  final _addr1 = TextEditingController();
  final _addr2 = TextEditingController();
  final _memo = TextEditingController();
  bool _saving = false;

  static String _formatPostalCodeDisplay(String postalCode) {
    final t = postalCode.replaceAll(RegExp(r'[^0-9]'), '');
    if (t.length == 5) {
      return '${t.substring(0, 3)}-${t.substring(3)}';
    }
    return postalCode.trim();
  }

  Future<void> _openAddressSearch() async {
    final selected = await showDaumPostcodeSearchDialog(context);
    if (!mounted || selected == null) return;

    final postalCode = (selected['postalCode'] ?? '').toString().trim();
    final roadAddress = (selected['roadAddress'] ?? '').toString().trim();
    final jibunAddress = (selected['jibunAddress'] ?? '').toString().trim();

    final baseAddress = roadAddress.isNotEmpty ? roadAddress : jibunAddress;

    setState(() {
      _zip.text = _formatPostalCodeDisplay(postalCode);
      _addr1.text = baseAddress;
    });
  }

  bool get _hasSearchedAddress => _addr1.text.trim().isNotEmpty;

  Widget _buildAddressSearchSection(BuildContext context) {
    final radius = healthDp(context, 10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '주소',
          style: TextStyle(
            color: _kMuted,
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: healthDp(context, 4)),
        SizedBox(
          width: double.infinity,
          height: healthDp(context, 35),
          child: ElevatedButton(
            onPressed: _openAddressSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPink,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
            child: Text(
              '주소 검색',
              style: TextStyle(
                color: Colors.white,
                fontSize: healthSp(context, 14),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        if (_hasSearchedAddress) ...[
          SizedBox(height: healthDp(context, 8)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 10),
              vertical: healthDp(context, 10),
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_zip.text.trim().isNotEmpty)
                  Text(
                    _zip.text.trim(),
                    style: TextStyle(
                      color: _kMuted,
                      fontSize: healthSp(context, 11),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (_zip.text.trim().isNotEmpty)
                  SizedBox(height: healthDp(context, 4)),
                Text(
                  _addr1.text.trim(),
                  style: TextStyle(
                    color: _kInk,
                    fontSize: healthSp(context, 12),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _subject.dispose();
    _name.dispose();
    _phone.dispose();
    _zip.dispose();
    _addr1.dispose();
    _addr2.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_hasSearchedAddress) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주소 검색을 통해 주소를 선택해 주세요.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final user = await AuthService.getUser();
      if (user == null) {
        return;
      }

      final payload = {
        'mbId': user.id,
        'adSubject': _subject.text.trim(),
        'adDefault': 0,
        'adName': _name.text.trim(),
        'adTel': _phone.text.trim(),
        'adHp': _phone.text.trim(),
        'adZip1': _zip.text.trim(),
        'adZip2': '',
        'adAddr1': _addr1.text.trim(),
        'adAddr2': _addr2.text.trim(),
        'adAddr3': '',
        'adJibeon': '',
        'adMemo': _memo.text.trim(),
      };

      final result = await AddressService.addAddress(payload);
      if (!mounted) return;
      if (result['success'] == true) {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final popupWidth = healthDp(context, 300);
    final radius = healthDp(context, 20);
    final pad20 = healthDp(context, 20);
    final gap8 = healthDp(context, 8);
    final buttonH = healthDp(context, 42);
    final maxScrollHeight =
        MediaQuery.sizeOf(context).height * 0.88 - buttonH;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: popupWidth,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          ),
          shadows: [
            BoxShadow(
              color: const Color(0x19000000),
              blurRadius: healthDp(context, 8.14),
              offset: Offset.zero,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: maxScrollHeight.clamp(0.0, double.infinity),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      pad20,
                      pad20,
                      pad20,
                      healthDp(context, 12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            '새 배송지 등록',
                            style: TextStyle(
                              color: _kInk,
                              fontSize: healthSp(context, 20),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(height: healthDp(context, 14)),
                        _field(context, '배송지 이름', _subject, '집'),
                        SizedBox(height: gap8),
                        _field(context, '받으시는 분', _name, '홍길동'),
                        SizedBox(height: gap8),
                        _field(context, '연락처', _phone, '010-0000-0000'),
                        SizedBox(height: gap8),
                        _buildAddressSearchSection(context),
                        SizedBox(height: gap8),
                        _field(context, '상세 주소', _addr2, '상세 주소'),
                        SizedBox(height: gap8),
                        _field(
                          context,
                          '배송 요청사항',
                          _memo,
                          '요청사항이 있으면 입력',
                          required: false,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: buttonH,
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _saving
                              ? null
                              : () => Navigator.pop(context, false),
                          child: ColoredBox(
                            color: const Color(0xFFF7F7F7),
                            child: Center(
                              child: Text(
                                '취소',
                                style: TextStyle(
                                  color: _kMuted,
                                  fontSize: healthSp(context, 14),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: _saving ? null : _save,
                          child: ColoredBox(
                            color: _kPink,
                            child: Center(
                              child: _saving
                                  ? SizedBox(
                                      width: healthDp(context, 16),
                                      height: healthDp(context, 16),
                                      child: CircularProgressIndicator(
                                        strokeWidth: healthDp(context, 2),
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : Text(
                                      '등록',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: healthSp(context, 14),
                                        fontFamily: 'Gmarket Sans TTF',
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
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
      ),
    );
  }

  Widget _field(
    BuildContext context,
    String label,
    TextEditingController controller,
    String hint, {
    bool required = true,
  }) {
    final radius = healthDp(context, 10);
    final padH = healthDp(context, 10);
    final padV = healthDp(context, 10);
    final borderW = healthDp(context, 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _kMuted,
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: healthDp(context, 2)),
        TextFormField(
          controller: controller,
          validator: (v) {
            if (!required) return null;
            if (v == null || v.trim().isEmpty) return '$label 입력해 주세요.';
            return null;
          },
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: padH,
              vertical: padV,
            ),
            hintText: hint,
            hintStyle: TextStyle(
              color: _kMuted,
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide(color: _kBorder, width: borderW),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide(color: _kBorder, width: borderW),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide(color: _kPink, width: borderW),
            ),
          ),
          style: TextStyle(
            color: _kInk,
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
