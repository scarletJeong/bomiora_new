import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../common/widgets/daum_postcode_search_dialog.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../../core/utils/node_value_parser.dart';
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
  static const Color _kInk = Color(0xFF1A1A1E);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kBorder = Color(0xFFD2D2D2);

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _zip = TextEditingController();
  final _addr1 = TextEditingController();
  final _memo = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String _orderDateText = '-';
  String _orderNumberText = '-';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _zip.dispose();
    _addr1.dispose();
    _memo.dispose();
    super.dispose();
  }

  static String _formatPostalCodeDisplay(String postalCode) {
    final t = postalCode.replaceAll(RegExp(r'[^0-9]'), '');
    if (t.length == 5) {
      return '${t.substring(0, 3)}-${t.substring(3)}';
    }
    return postalCode.trim();
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

    if (!mounted) return;
    if (detailResult['success'] == true) {
      final order = detailResult['order'] as OrderDetailModel;
      _orderDateText = order.orderDate;
      _orderNumberText = order.odId;
      _name.text = order.recipientName;
      _phone.text = order.recipientPhone;
      _addr1.text = order.recipientAddress;
      if (order.recipientAddressDetail.isNotEmpty) {
        _addr1.text = '${order.recipientAddress} ${order.recipientAddressDetail}'
            .trim();
      }
      _memo.text = order.deliveryMessage ?? '';
    }

    setState(() => _isLoading = false);
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final user = await AuthService.getUser();
      if (user == null) return;

      final addResult = await AddressService.addAddress({
        'mbId': user.id,
        'adSubject': '배송지변경',
        'adDefault': 0,
        'adName': _name.text.trim(),
        'adTel': _phone.text.trim(),
        'adHp': _phone.text.trim(),
        'adZip1': _zip.text.trim(),
        'adZip2': '',
        'adAddr1': _addr1.text.trim(),
        'adAddr2': '',
        'adAddr3': '',
        'adJibeon': '',
        'adMemo': _memo.text.trim(),
      });

      if (!mounted) return;
      if (addResult['success'] != true) return;

      final rawData = addResult['data'];
      int? addressId;
      if (rawData is Map) {
        addressId = NodeValueParser.asInt(
          rawData['adId'] ?? rawData['ad_id'],
        );
      }
      if (addressId == null) return;

      final result = await order_service.OrderService.changeDeliveryAddress(
        odId: widget.orderId,
        mbId: user.id,
        addressId: addressId,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        color: _kMuted,
        fontSize: healthSp(context, 14),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w500,
        height: 1,
      ),
    );
  }

  Widget _inputField(
    BuildContext context, {
    required TextEditingController controller,
    required String hint,
    bool readOnly = false,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final fieldH = healthDp(context, 40);
    final radius = healthDp(context, 10);
    final pad = healthDp(context, 10);

    return Container(
      width: double.infinity,
      height: fieldH,
      padding: EdgeInsets.symmetric(horizontal: pad),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _kBorder),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        validator: validator,
        inputFormatters: inputFormatters,
        style: TextStyle(
          color: _kInk,
          fontSize: healthSp(context, 12),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
          height: 1,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            color: _kMuted,
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            height: 1,
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _labeledField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required String hint,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context, label),
        SizedBox(height: healthDp(context, 5)),
        _inputField(
          context,
          controller: controller,
          hint: hint,
          readOnly: readOnly,
          validator: validator,
        ),
      ],
    );
  }

  Widget _orderInfoBox(BuildContext context) {
    final pad = healthDp(context, 10);
    final gap5 = healthDp(context, 5);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(pad),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: const Color(0x33D2D2D2),
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _kBorder),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
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
              height: 1,
            ),
          ),
          SizedBox(height: pad),
          Text(
            '주문일자: $_orderDateText',
            style: TextStyle(
              color: _kInk,
              fontSize: healthSp(context, 10),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
              height: 1,
            ),
          ),
          SizedBox(height: gap5),
          Text(
            '주문번호: $_orderNumberText',
            style: TextStyle(
              color: _kInk,
              fontSize: healthSp(context, 10),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressSection(BuildContext context) {
    final fieldH = healthDp(context, 40);
    final gap5 = healthDp(context, 5);
    final radius = healthDp(context, 10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context, '배송지 주소'),
        SizedBox(height: gap5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _inputField(
                context,
                controller: _zip,
                hint: '우편번호',
                readOnly: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return '주소 검색을 통해 우편번호를 입력해 주세요.';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(width: gap5),
            InkWell(
              onTap: _openAddressSearch,
              borderRadius: BorderRadius.circular(radius),
              child: Container(
                height: fieldH,
                padding: EdgeInsets.symmetric(
                  horizontal: healthDp(context, 10),
                  vertical: healthDp(context, 5),
                ),
                decoration: ShapeDecoration(
                  color: _kPink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '주소 검색',
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
        SizedBox(height: gap5),
        _inputField(
          context,
          controller: _addr1,
          hint: '\'주소 검색\'을 통해 입력됩니다.',
          readOnly: true,
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return '주소 검색을 통해 주소를 입력해 주세요.';
            }
            return null;
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final popupW = healthDp(context, 321);
    final popupRadius = healthDp(context, 20);
    final pad20 = healthDp(context, 20);
    final gap20 = healthDp(context, 20);
    final btnH = healthDp(context, 50);
    final maxPopupH = MediaQuery.sizeOf(context).height - healthDp(context, 48);

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: popupW,
            maxHeight: maxPopupH,
          ),
          child: SizedBox(
            width: popupW,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(popupRadius),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x19000000),
                      blurRadius: 8.14,
                      offset: Offset.zero,
                    ),
                  ],
                ),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(
                            top: pad20,
                            left: pad20,
                            right: pad20,
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '배송지 변경',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _kInk,
                                    fontSize: healthSp(context, 20),
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w700,
                                    height: 1,
                                  ),
                                ),
                                SizedBox(height: gap20),
                                if (_isLoading)
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: healthDp(context, 24),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                else ...[
                                  _orderInfoBox(context),
                                  SizedBox(height: gap20),
                                  _labeledField(
                                    context,
                                    label: '받으시는 분',
                                    controller: _name,
                                    hint: '받으시는 분',
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return '받으시는 분을 입력해 주세요.';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: gap20),
                                  _labeledField(
                                    context,
                                    label: '연락처',
                                    controller: _phone,
                                    hint: '010-0000-0000',
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return '연락처를 입력해 주세요.';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: gap20),
                                  _addressSection(context),
                                  SizedBox(height: gap20),
                                  _labeledField(
                                    context,
                                    label: '배송 요청사항',
                                    controller: _memo,
                                    hint: '요청사항이 있으시면 입력해주세요.',
                                  ),
                                ],
                                SizedBox(height: pad20),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: btnH,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Material(
                                color: const Color(0xFFF7F7F7),
                                child: InkWell(
                                  onTap: _isSubmitting
                                      ? null
                                      : () => Navigator.pop(context, false),
                                  child: Center(
                                    child: Text(
                                      '취소',
                                      style: TextStyle(
                                        color: _kMuted,
                                        fontSize: healthSp(context, 16),
                                        fontFamily: 'Gmarket Sans TTF',
                                        fontWeight: FontWeight.w500,
                                        height: 1,
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
                                            width: healthDp(context, 20),
                                            height: healthDp(context, 20),
                                            child: const CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            '변경',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: healthSp(context, 16),
                                              fontFamily: 'Gmarket Sans TTF',
                                              fontWeight: FontWeight.w500,
                                              height: 1,
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
          ),
        ),
    );
  }
}
