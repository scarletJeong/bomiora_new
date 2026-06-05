import 'package:flutter/material.dart';
import '../../../common/widgets/daum_postcode_search_dialog.dart';
import '../../../../data/models/delivery/delivery_model.dart';
import '../../../../data/services/address_service.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/delivery_service.dart' as order_service;

class DeliveryAddressChangePopup extends StatefulWidget {
  final String orderId;

  const DeliveryAddressChangePopup({
    super.key,
    required this.orderId,
  });

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

    final detailResult = await order_service.OrderService.getOrderDetail(
      odId: widget.orderId,
      mbId: user.id,
    );
    final addresses = await AddressService.getAddressList(user.id);

    if (!mounted) return;
    if (detailResult['success'] == true) {
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
    setState(() => _isSubmitting = true);

    final user = await AuthService.getUser();
    if (user == null) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      return;
    }

    final result = await order_service.OrderService.changeDeliveryAddress(
      odId: widget.orderId,
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
      builder: (ctx) => _AddressRegisterDialog(orderId: widget.orderId),
    );
    if (result == true && mounted) {
      setState(() => _isLoading = true);
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: SizedBox(
          width: 300,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '배송지 변경',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _kInk,
                          fontSize: 20,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          onTap: _openAddressRegister,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 2, vertical: 2),
                            child: Text(
                              '+ 새 배송지 등록',
                              style: TextStyle(
                                color: _kPink,
                                fontSize: 12,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: ShapeDecoration(
                          color: const Color(0x33D2D2D2),
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(width: 1, color: _kBorder),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '주문정보',
                              style: TextStyle(
                                color: _kInk,
                                fontSize: 14,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('주문일자: $_orderDateText',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'Gmarket Sans TTF')),
                            const SizedBox(height: 4),
                            Text('주문번호: $_orderNumberText',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'Gmarket Sans TTF')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '배송지 선택',
                        style: TextStyle(
                          color: _kMuted,
                          fontSize: 14,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 280),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _addresses.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
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
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: selected ? _kPink : _kBorder,
                                      width: selected ? 1.5 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a['adSubject']?.toString() ?? '',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontFamily: 'Gmarket Sans TTF',
                                            fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${a['adName'] ?? ''} ${a['adHp'] ?? ''}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'Gmarket Sans TTF',
                                            color: _kMuted),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        line,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'Gmarket Sans TTF',
                                            color: _kInk),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                SizedBox(
                  height: 50,
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: const Color(0xFFF7F7F7),
                          child: InkWell(
                            onTap: () => Navigator.pop(context, false),
                            child: const Center(
                              child: Text(
                                '취소',
                                style: TextStyle(
                                  color: _kMuted,
                                  fontSize: 16,
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
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text(
                                      '확인',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
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
  const _AddressRegisterDialog({required this.orderId});
  final String orderId;

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
    final extraAddress = (selected['extraAddress'] ?? '').toString().trim();

    final baseAddress = roadAddress.isNotEmpty ? roadAddress : jibunAddress;

    setState(() {
      _zip.text = _formatPostalCodeDisplay(postalCode);
      _addr1.text = baseAddress;
      if (_addr2.text.trim().isEmpty && extraAddress.isNotEmpty) {
        _addr2.text = extraAddress;
      }
    });
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
    if (!_formKey.currentState!.validate() || _saving) return;
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
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 300,
        decoration: const ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          shadows: [
            BoxShadow(
              color: Color(0x19000000),
              blurRadius: 8.14,
              offset: Offset(0, 0),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text(
                          '새 배송지 등록',
                          style: TextStyle(
                            color: _kInk,
                            fontSize: 20,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _field('배송지 이름', _subject, '집'),
                      const SizedBox(height: 8),
                      _field('받으시는 분', _name, '홍길동'),
                      const SizedBox(height: 8),
                      _field('연락처', _phone, '010-0000-0000'),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _openAddressSearch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kPink,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            '주소 검색',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _field('우편번호', _zip, '우편번호'),
                      const SizedBox(height: 8),
                      _field('주소', _addr1, '기본 주소'),
                      const SizedBox(height: 8),
                      _field('상세 주소', _addr2, '상세 주소'),
                      const SizedBox(height: 8),
                      _field('배송 요청사항', _memo, '요청사항이 있으면 입력', required: false),
                    ],
                  ),
                ),
                SizedBox(
                  height: 50,
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _saving
                              ? null
                              : () => Navigator.pop(context, false),
                          child: const ColoredBox(
                            color: Color(0xFFF7F7F7),
                            child: Center(
                              child: Text(
                                '취소',
                                style: TextStyle(
                                  color: _kMuted,
                                  fontSize: 16,
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
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      '변경',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
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
    String label,
    TextEditingController controller,
    String hint, {
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _kMuted,
            fontSize: 12,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          validator: (v) {
            if (!required) return null;
            if (v == null || v.trim().isEmpty) return '$label 입력해 주세요.';
            return null;
          },
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            hintText: hint,
            hintStyle: const TextStyle(
              color: _kMuted,
              fontSize: 12,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kPink),
            ),
          ),
          style: const TextStyle(
            color: _kInk,
            fontSize: 12,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
