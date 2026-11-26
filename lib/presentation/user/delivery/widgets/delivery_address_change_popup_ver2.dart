import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/logging/failure_log.dart';
import '../../../common/widgets/app_toast_overlay.dart';
import '../../../common/widgets/daum_postcode_search_dialog.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../../core/utils/node_value_parser.dart';
import '../../../../data/models/delivery/delivery_model.dart';
import '../../../../data/services/address_service.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/delivery_service.dart' as order_service;

const String _kFont = 'Gmarket Sans TTF';
const Color _kPink = Color(0xFFFF5A8D);
const Color _kInk = Color(0xFF1A1A1E);
const Color _kMuted = Color(0xFF898686);
const Color _kAddrMuted = Color(0xFF898383);
const Color _kBorder = Color(0xFFD2D2D2);
const Color _kFieldFill = Color(0xFFF8FAFC);
const Color _kSelectedBg = Color(0x0CFF5C8F);
const Color _kSelectedBorder = Color(0xFFFF5C8F);
const int _kMaxAddresses = 10;

/// 배송지 변경 팝업 (목록 선택형).
///
/// - [orderId]가 없으면 결제(체크아웃) 모드: 선택한 배송지 Map을 그대로 pop.
/// - [orderId]가 있으면 주문 모드: [order_service.OrderService.changeDeliveryAddress] 호출 후 성공 여부(bool) pop.
class DeliveryAddressChangePopup extends StatefulWidget {
  final String? orderId;

  /// 주문/결제 화면에서 현재 선택된 배송지 (목록 핑크 선택 초기값).
  final Map<String, dynamic>? initiallySelectedAddress;

  const DeliveryAddressChangePopup({
    super.key,
    this.orderId,
    this.initiallySelectedAddress,
  });

  bool get _isCheckoutMode => orderId == null || orderId!.trim().isEmpty;

  @override
  State<DeliveryAddressChangePopup> createState() =>
      _DeliveryAddressChangePopupState();
}

class _DeliveryAddressChangePopupState
    extends State<DeliveryAddressChangePopup> {
  bool _isLoading = true;
  bool _listFailed = false;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _addresses = [];
  int? _selectedAddressId;

  /// 목록/추가·수정 팝업 공통 크기 (Figma 321×615)
  static Size _sharedPopupSize(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height - healthDp(context, 48);
    final h = healthDp(context, 615).clamp(0.0, maxH);
    return Size(healthDp(context, 321), h);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({int? preferSelectId, bool forceRefresh = false}) async {
    final user = await AuthService.getUser();
    if (user == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    final loaded = await AddressService.loadAddresses(
      user.id,
      forceRefresh: forceRefresh,
    );
    if (!mounted) return;
    if (!loaded.ok) {
      final keepList = _addresses.isNotEmpty;
      setState(() {
        _isLoading = false;
        _listFailed = !keepList;
      });
      if (keepList) {
        AppToastOverlay.showAlert(context, '배송지를 불러오지 못했습니다.');
      }
      return;
    }

    _listFailed = false;
    _addresses = loaded.items;
    if (_addresses.isEmpty) {
      _selectedAddressId = null;
    } else if (preferSelectId != null &&
        _addresses.any((a) => _asAddressId(a['adId']) == preferSelectId)) {
      // 신규/수정한 배송지를 선택
      _selectedAddressId = preferSelectId;
    } else if (_addresses
        .any((a) => _asAddressId(a['adId']) == _selectedAddressId)) {
      // 기존 선택 유지
    } else {
      var matchedId = _matchInitiallySelectedAddressId();
      final hasInitial = widget.initiallySelectedAddress != null &&
          widget.initiallySelectedAddress!.isNotEmpty;
      // 주문 모드인데 현재 배송지 힌트가 없으면 주문 수령지로 맞춘다.
      // 기본배송지라는 이유만으로 선택(핑크)하지 않는다.
      if (matchedId == null && !hasInitial && !widget._isCheckoutMode) {
        matchedId = await _matchOrderRecipientId(user.id);
        if (!mounted) return;
      }
      _selectedAddressId = matchedId;
    }
    setState(() => _isLoading = false);
  }

  int? _asAddressId(dynamic value) {
    if (value is int) return value;
    return int.tryParse('$value');
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

  String _addrField(Map<String, dynamic> m, String key) =>
      (m[key] ?? '').toString().trim();

  String _zipOf(Map<String, dynamic> m) {
    final z1 = _addrField(m, 'adZip1').replaceAll(RegExp(r'\D'), '');
    final z2 = _addrField(m, 'adZip2').replaceAll(RegExp(r'\D'), '');
    if (z1.length >= 5) return z1;
    if (z1.isNotEmpty || z2.isNotEmpty) return '$z1$z2';
    return _addrField(m, 'adZip').replaceAll(RegExp(r'\D'), '');
  }

  static String _normText(String value) =>
      value.replaceAll(RegExp(r'\s+'), '').trim();

  /// 결제 화면에서 넘긴 현재 선택 배송지와 목록 항목을 매칭합니다.
  int? _matchInitiallySelectedAddressId() {
    final initial = widget.initiallySelectedAddress;
    if (initial == null || initial.isEmpty) return null;

    final initialId = _asAddressId(initial['adId'] ?? initial['ad_id']);
    if (initialId != null &&
        _addresses.any((a) => _asAddressId(a['adId']) == initialId)) {
      return initialId;
    }

    final zip = _zipOf(initial);
    final name = _addrField(initial, 'adName');
    final hp = _addrField(initial, 'adHp').replaceAll(RegExp(r'\D'), '');
    final addr1 = _normText(_addrField(initial, 'adAddr1'));
    final addr2 = _normText(_addrField(initial, 'adAddr2'));
    if (zip.isEmpty &&
        name.isEmpty &&
        hp.isEmpty &&
        addr1.isEmpty &&
        addr2.isEmpty) {
      return null;
    }

    int? bestId;
    var bestScore = 0;
    for (final a in _addresses) {
      final aZip = _zipOf(a);
      final aName = _addrField(a, 'adName');
      final aHp = _addrField(a, 'adHp').replaceAll(RegExp(r'\D'), '');
      final aAddr1 = _normText(_addrField(a, 'adAddr1'));
      final aAddr2 = _normText(_addrField(a, 'adAddr2'));
      final id = _asAddressId(a['adId']);
      if (id == null) continue;

      final zipOk = zip.isEmpty || aZip == zip;
      final nameOk = name.isEmpty || aName == name;
      final hpOk = hp.isEmpty || aHp == hp;
      if (!zipOk || !nameOk || !hpOk) continue;

      final score = _addressMatchScore(
        orderAddr1: addr1,
        orderAddr2: addr2,
        cardAddr1: aAddr1,
        cardAddr2: aAddr2,
      );
      if (score > bestScore) {
        bestScore = score;
        bestId = id;
      }
    }
    return bestId;
  }

  /// 주소가 실제로 같을 때만 점수를 줍니다. 이름만 같은 기본배송지는 제외합니다.
  static int _addressMatchScore({
    required String orderAddr1,
    required String orderAddr2,
    required String cardAddr1,
    required String cardAddr2,
  }) {
    if (orderAddr1.isEmpty && orderAddr2.isEmpty) return 0;
    if (orderAddr1 == cardAddr1 && orderAddr2 == cardAddr2) return 100;
    if (orderAddr1 == cardAddr1 &&
        (orderAddr2.isEmpty || cardAddr2.isEmpty)) {
      return 80;
    }
    final combined = '$cardAddr1$cardAddr2';
    if (orderAddr1.isNotEmpty && orderAddr1 == combined) return 90;
    if (orderAddr1.isNotEmpty &&
        cardAddr1.isNotEmpty &&
        orderAddr1.startsWith(cardAddr1)) {
      final rest = orderAddr1.substring(cardAddr1.length);
      if (cardAddr2.isNotEmpty && rest.contains(cardAddr2)) return 70;
    }
    return 0;
  }

  Future<int?> _matchOrderRecipientId(String mbId) async {
    final orderId = widget.orderId?.trim() ?? '';
    if (orderId.isEmpty) return null;
    try {
      final result = await order_service.OrderService.getOrderDetail(
        odId: orderId,
        mbId: mbId,
      );
      if (result['success'] != true) return null;
      final order = result['order'];
      if (order is! OrderDetailModel) return null;
      return _matchRecipientAddressId(
        name: order.recipientName,
        phone: order.recipientPhone,
        addr1: order.recipientAddress,
        addr2: order.recipientAddressDetail,
      );
    } catch (_) {
      return null;
    }
  }

  int? _matchRecipientAddressId({
    required String name,
    required String phone,
    required String addr1,
    required String addr2,
  }) {
    final oName = name.trim();
    final oPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final oAddr1 = _normText(addr1);
    final oAddr2 = _normText(addr2);
    if (oName.isEmpty && oPhone.isEmpty && oAddr1.isEmpty) return null;

    int? bestId;
    var bestScore = 0;
    for (final a in _addresses) {
      final aName = _addrField(a, 'adName');
      final aPhone = _addrField(a, 'adHp').replaceAll(RegExp(r'\D'), '');
      final a1 = _normText(_addrField(a, 'adAddr1'));
      final a2 = _normText(_addrField(a, 'adAddr2'));
      final id = _asAddressId(a['adId']);
      if (id == null) continue;
      final nameOk = oName.isEmpty || oName == aName;
      final phoneOk = oPhone.isEmpty || oPhone == aPhone;
      if (!nameOk || !phoneOk) continue;
      final score = _addressMatchScore(
        orderAddr1: oAddr1,
        orderAddr2: oAddr2,
        cardAddr1: a1,
        cardAddr2: a2,
      );
      if (score > bestScore) {
        bestScore = score;
        bestId = id;
      }
    }
    return bestId;
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
    if (result['success'] == true) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      Navigator.pop(context, true);
      return;
    }

    final reason = result['message']?.toString().trim() ?? '';
    await FailureLog.record(
      code: 'payment.complete.address',
      mbId: user.id,
      reason: reason.isEmpty ? '배송지를 바꾸지 못했습니다.' : reason,
      detail: {
        'orderId': widget.orderId,
        'addressId': _selectedAddressId,
      },
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    AppToastOverlay.show(context, '배송지를 바꾸지 못했습니다.');
  }

  Future<void> _openAddressForm({Map<String, dynamic>? existing}) async {
    if (existing == null && _addresses.length >= _kMaxAddresses) {
      AppToastOverlay.showAlert(context, '배송지는 최대 10개까지 등록할 수 있습니다.');
      return;
    }
    final result = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddressFormDialog(existing: existing),
    );
    // 취소 시 null. 저장 성공 시 adId(또는 0=목록 마지막 선택)
    if (!mounted || result == null) return;
    setState(() => _isLoading = true);
    if (result > 0) {
      await _loadData(preferSelectId: result);
      return;
    }
    await _loadData();
    if (!mounted || _addresses.isEmpty) return;
    int? newest;
    for (final a in _addresses) {
      final id = _asAddressId(a['adId']);
      if (id == null) continue;
      if (newest == null || id > newest) newest = id;
    }
    if (newest != null) {
      setState(() => _selectedAddressId = newest);
    }
  }

  Widget _buildAddButton(BuildContext context) {
    final iconSize = healthDp(context, 16);
    final enabled = _addresses.length < _kMaxAddresses;
    final accent = enabled ? _kPink : _kBorder;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        onTap: enabled ? () => _openAddressForm() : null,
        borderRadius: BorderRadius.circular(healthDp(context, 50)),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: healthDp(context, 12)),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(width: healthDp(context, 1.5), color: accent),
              borderRadius: BorderRadius.circular(healthDp(context, 50)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: iconSize, color: accent),
              SizedBox(width: healthDp(context, 4)),
              Text(
                '배송지 신규입력',
                style: TextStyle(
                  color: accent,
                  fontSize: healthSp(context, 12),
                  fontFamily: _kFont,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditButton(BuildContext context, Map<String, dynamic> a) {
    return InkWell(
      onTap: () => _openAddressForm(existing: a),
      borderRadius: BorderRadius.circular(healthDp(context, 6)),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 10),
          vertical: healthDp(context, 5),
        ),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(width: healthDp(context, 1), color: _kBorder),
            borderRadius: BorderRadius.circular(healthDp(context, 6)),
          ),
        ),
        child: Text(
          '수정',
          style: TextStyle(
            color: _kAddrMuted,
            fontSize: healthSp(context, 12),
            fontFamily: _kFont,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard(BuildContext context, Map<String, dynamic> a) {
    final adId = _asAddressId(a['adId']);
    final selected = _selectedAddressId != null && _selectedAddressId == adId;
    final subject = (a['adSubject'] ?? '').toString().trim();
    final name = (a['adName'] ?? '').toString().trim();
    final title = subject.isNotEmpty ? '$name($subject)' : name;
    final phone = _formatPhoneDisplay((a['adHp'] ?? '').toString().trim());
    final fullAddress = [
      (a['adAddr1'] ?? '').toString().trim(),
      (a['adAddr2'] ?? '').toString().trim(),
      (a['adAddr3'] ?? '').toString().trim(),
    ].where((e) => e.isNotEmpty).join(' ');
    final isDefault = a['adDefault'] == 1;
    final detailStyle = TextStyle(
      color: _kAddrMuted,
      fontSize: healthSp(context, 12),
      fontFamily: _kFont,
      fontWeight: FontWeight.w500,
      height: 1.42,
      letterSpacing: -0.6,
    );

    return InkWell(
      onTap:
          adId == null ? null : () => setState(() => _selectedAddressId = adId),
      borderRadius: BorderRadius.circular(healthDp(context, 12)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(healthDp(context, 16)),
        decoration: ShapeDecoration(
          color: selected ? _kSelectedBg : Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: healthDp(context, 1),
              color: selected ? _kSelectedBorder : _kBorder,
            ),
            borderRadius: BorderRadius.circular(healthDp(context, 12)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          title.isEmpty ? '수령인' : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _kInk,
                            fontSize: healthSp(context, 14),
                            fontFamily: _kFont,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.28,
                          ),
                        ),
                      ),
                      if (isDefault) ...[
                        SizedBox(width: healthDp(context, 4)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: healthDp(context, 6),
                            vertical: healthDp(context, 4),
                          ),
                          decoration: ShapeDecoration(
                            color: selected ? Colors.white : _kSelectedBg,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(healthDp(context, 50)),
                            ),
                          ),
                          child: Text(
                            '기본배송지',
                            style: TextStyle(
                              color: const Color(0xFFFF5C8F),
                              fontSize: healthSp(context, 10),
                              fontFamily: _kFont,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: healthDp(context, 8)),
                _buildEditButton(context, a),
              ],
            ),
            SizedBox(height: healthDp(context, 4)),
            if (phone.isNotEmpty)
              Text(
                phone,
                style: detailStyle,
              ),
            Text(
              fullAddress.isEmpty ? '-' : fullAddress,
              style: detailStyle,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = _sharedPopupSize(context);
    final popupRadius = healthDp(context, 20);
    final pad20 = healthDp(context, 20);

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          width: size.width,
          height: size.height,
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(popupRadius),
            ),
            shadows: const [
              BoxShadow(
                color: Color(0x19000000),
                blurRadius: 8.14,
                offset: Offset.zero,
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    pad20,
                    pad20,
                    pad20,
                    healthDp(context, 16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '배송지 변경',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _kInk,
                          fontSize: healthSp(context, 20),
                          fontFamily: _kFont,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: healthDp(context, 20)),
                      _buildAddButton(context),
                      SizedBox(height: healthDp(context, 10)),
                      if (_isLoading)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: healthDp(context, 24),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF5A8D),
                            ),
                          ),
                        )
                      else if (_listFailed)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: healthDp(context, 24),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '배송지를 불러오지 못했습니다.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _kMuted,
                                  fontSize: healthSp(context, 12),
                                  fontFamily: _kFont,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: healthDp(context, 8)),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isLoading = true;
                                    _listFailed = false;
                                  });
                                  _loadData(forceRefresh: true);
                                },
                                child: Text(
                                  '다시 시도',
                                  style: TextStyle(
                                    color: _kPink,
                                    fontSize: healthSp(context, 12),
                                    fontFamily: _kFont,
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.underline,
                                    decorationColor: _kPink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_addresses.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: healthDp(context, 24),
                          ),
                          child: Center(
                            child: Text(
                              '등록된 배송지가 없습니다.',
                              style: TextStyle(
                                color: _kMuted,
                                fontSize: healthSp(context, 12),
                                fontFamily: _kFont,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                      else
                        Column(
                          children: [
                            for (var i = 0; i < _addresses.length; i++) ...[
                              if (i > 0) SizedBox(height: healthDp(context, 12)),
                              _buildAddressCard(context, _addresses[i]),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: healthDp(context, 50),
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
                                fontSize: healthSp(context, 16),
                                fontFamily: _kFont,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Material(
                        color: _selectedAddressId == null
                            ? _kPink.withValues(alpha: 0.45)
                            : _kPink,
                        child: InkWell(
                          onTap: (_isSubmitting || _selectedAddressId == null)
                              ? null
                              : _submit,
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
                                    '확인',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: healthSp(context, 16),
                                      fontFamily: _kFont,
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
    );
  }
}

enum _SubjectPreset { none, home, office, custom }

/// 배송지 등록/수정 팝업. [existing]이 있으면 수정 모드([AddressService.updateAddress]),
/// 없으면 신규 등록 모드([AddressService.addAddress]).
class _AddressFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const _AddressFormDialog({this.existing});

  @override
  State<_AddressFormDialog> createState() => _AddressFormDialogState();
}

class _AddressFormDialogState extends State<_AddressFormDialog>
    with SingleTickerProviderStateMixin {
  final _subjectController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _zipController = TextEditingController();
  final _addr1Controller = TextEditingController();
  final _addr2Controller = TextEditingController();

  _SubjectPreset _subjectPreset = _SubjectPreset.none;
  bool _isDefault = false;
  bool _saving = false;

  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  Set<String> _pulseFields = {};

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFormChanged);
    _phoneController.addListener(_onFormChanged);
    _addr1Controller.addListener(_onFormChanged);
    _addr2Controller.addListener(_onFormChanged);
    _subjectController.addListener(_onFormChanged);
    _loadExisting();
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  void _loadExisting() {
    final m = widget.existing;
    if (m == null) return;

    _nameController.text = (m['adName'] ?? '').toString().trim();
    _phoneController.text = (m['adHp'] ?? m['adTel'] ?? '').toString().trim();
    final z1 = (m['adZip1'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    final z2 = (m['adZip2'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    _zipController.text = z1.length >= 5 ? z1 : '$z1$z2';
    _addr1Controller.text = (m['adAddr1'] ?? '').toString().trim();
    _addr2Controller.text = (m['adAddr2'] ?? '').toString().trim();
    _isDefault = m['adDefault'] == 1;

    final subject = (m['adSubject'] ?? '').toString().trim();
    if (subject.isEmpty) {
      _subjectPreset = _SubjectPreset.none;
    } else if (subject == '집') {
      _subjectPreset = _SubjectPreset.home;
      _subjectController.text = '집';
    } else if (subject == '회사') {
      _subjectPreset = _SubjectPreset.office;
      _subjectController.text = '회사';
    } else {
      _subjectPreset = _SubjectPreset.custom;
      _subjectController.text = subject;
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFormChanged);
    _phoneController.removeListener(_onFormChanged);
    _addr1Controller.removeListener(_onFormChanged);
    _addr2Controller.removeListener(_onFormChanged);
    _subjectController.removeListener(_onFormChanged);
    _subjectController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _zipController.dispose();
    _addr1Controller.dispose();
    _addr2Controller.dispose();
    _pulseCtrl.stop();
    _pulseCtrl.dispose();
    super.dispose();
  }

  static String _formatPostalCodeDisplay(String postalCode) {
    return postalCode.replaceAll(RegExp(r'[^0-9]'), '').trim();
  }

  Future<void> _openAddressSearch() async {
    final selected = await showDaumPostcodeSearchDialog(context);
    if (!mounted || selected == null) return;

    final parsed = daumSelectedAddress(selected);

    setState(() {
      _zipController.text = _formatPostalCodeDisplay(parsed.postalCode);
      _addr1Controller.text = parsed.address;
      _addr2Controller.clear();
      if (_pulseFields.contains('address')) {
        _pulseFields = {..._pulseFields}..remove('address');
      }
    });
  }

  Future<void> _triggerPulse(Set<String> fields) async {
    setState(() => _pulseFields = fields);
    for (var i = 0; i < 3; i++) {
      if (!mounted) return;
      await _pulseCtrl.forward(from: 0);
      if (!mounted) return;
      await _pulseCtrl.reverse();
    }
    if (mounted) setState(() => _pulseFields = {});
  }

  String get _phoneDigits =>
      _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

  bool get _isFormComplete {
    if (_nameController.text.trim().isEmpty) return false;
    if (_phoneDigits.length != 11) return false;
    if (_addr1Controller.text.trim().isEmpty) return false;
    if (_addr2Controller.text.trim().isEmpty) return false;
    if (_subjectPreset == _SubjectPreset.custom &&
        _subjectController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (_saving) return;

    final nameEmpty = _nameController.text.trim().isEmpty;
    final phoneInvalid = _phoneDigits.length != 11;
    final addressEmpty = _addr1Controller.text.trim().isEmpty;
    final addr2Empty = _addr2Controller.text.trim().isEmpty;

    if (!_isFormComplete) {
      await _triggerPulse({
        if (nameEmpty) 'name',
        if (phoneInvalid) 'phone',
        if (addressEmpty) 'address',
        if (addr2Empty) 'addr2',
      });
      return;
    }

    setState(() => _saving = true);
    try {
      final user = await AuthService.getUser();
      if (user == null) return;

      if (!_isEdit) {
        final existing = await AddressService.getAddressList(user.id);
        if (!mounted) return;
        if (existing.length >= _kMaxAddresses) {
          AppToastOverlay.showAlert(
            context,
            '배송지는 최대 10개까지 등록할 수 있습니다.',
          );
          return;
        }
      }

      final subject = _subjectPreset == _SubjectPreset.none
          ? ''
          : _subjectController.text.trim();

      final payload = {
        'mbId': user.id,
        'adSubject': subject,
        'adDefault': _isDefault ? 1 : 0,
        'ad_default': _isDefault ? 1 : 0,
        'adName': _nameController.text.trim(),
        'adTel': _phoneController.text.trim(),
        'adHp': _phoneController.text.trim(),
        'adZip1': _zipController.text.trim(),
        'adZip2': '',
        'adAddr1': _addr1Controller.text.trim(),
        'adAddr2': _addr2Controller.text.trim(),
        'adAddr3': '',
        'adJibeon': '',
        'adMemo': '',
      };

      final editingId = _asAddressId(widget.existing?['adId']);
      final result = _isEdit
          ? await AddressService.updateAddress(editingId!, payload)
          : await AddressService.addAddress(payload);

      if (!mounted) return;
      if (result['success'] != true) {
        AppToastOverlay.showAlert(context, '배송지를 저장하지 못했습니다.');
        return;
      }

      int? addressId = editingId;
      if (!_isEdit) {
        final raw = result['data'];
        if (raw is Map) {
          addressId = NodeValueParser.asInt(raw['adId'] ?? raw['ad_id']);
        }
      }
      // 저장된 배송지 id를 넘겨 목록에서 바로 선택되게 함 (0=id 미반환 시 폴백)
      Navigator.pop(context, addressId ?? 0);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int? _asAddressId(dynamic value) {
    if (value is int) return value;
    return int.tryParse('$value');
  }

  Color _pulseBorderColor(String key) {
    if (_pulseFields.contains(key)) {
      return Color.lerp(_kBorder, _kPink, _pulseCtrl.value) ?? _kBorder;
    }
    return _kBorder;
  }

  Widget _requiredLabel(BuildContext context, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(
            color: _kMuted,
            fontSize: healthSp(context, 12),
            fontFamily: _kFont,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '*',
          style: TextStyle(
            color: _kPink,
            fontSize: healthSp(context, 12),
            fontFamily: _kFont,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _field({
    required BuildContext context,
    required TextEditingController controller,
    required String hint,
    required String pulseKey,
    Color fillColor = Colors.white,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    final borderColor = _pulseBorderColor(pulseKey);
    final radius = healthDp(context, 10);
    final fieldH = healthDp(context, 45);
    final fs = healthSp(context, 12);
    return Container(
      width: double.infinity,
      height: fieldH,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
      decoration: ShapeDecoration(
        color: fillColor,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: 1, color: borderColor),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        cursorColor: _kPink,
        textAlignVertical: TextAlignVertical.center,
        strutStyle: StrutStyle(
          fontSize: fs,
          height: 1,
          forceStrutHeight: true,
        ),
        onChanged: (_) {
          if (_pulseFields.contains(pulseKey)) {
            setState(() => _pulseFields = {..._pulseFields}..remove(pulseKey));
          }
        },
        onSubmitted: (_) {
          if (textInputAction == TextInputAction.done) {
            FocusScope.of(context).unfocus();
          } else {
            FocusScope.of(context).nextFocus();
          }
        },
        style: TextStyle(
          color: _kInk,
          fontSize: fs,
          fontFamily: _kFont,
          fontWeight: FontWeight.w500,
          height: 1,
          leadingDistribution: TextLeadingDistribution.even,
        ),
        decoration: InputDecoration(
          isDense: true,
          isCollapsed: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          // Gmarket Sans 광학 보정 — 글자를 살짝 위로
          contentPadding: EdgeInsets.only(bottom: healthDp(context, 3)),
          hintText: hint,
          hintStyle: TextStyle(
            color: _kAddrMuted,
            fontSize: fs,
            fontFamily: _kFont,
            fontWeight: FontWeight.w300,
            height: 1,
            leadingDistribution: TextLeadingDistribution.even,
          ),
        ),
      ),
    );
  }

  Widget _addressSearchButton(BuildContext context) {
    final radius = healthDp(context, 10);
    final fieldH = healthDp(context, 45);
    return InkWell(
      onTap: _openAddressSearch,
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        height: fieldH,
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 10),
          vertical: healthDp(context, 5),
        ),
        clipBehavior: Clip.antiAlias,
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
            fontFamily: _kFont,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _addressSearchRow(BuildContext context) {
    final addressText = _addr1Controller.text.trim();
    final borderColor = _pulseBorderColor('address');
    final radius = healthDp(context, 10);
    final fieldH = healthDp(context, 45);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
            height: fieldH,
            padding: EdgeInsets.all(healthDp(context, 10)),
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: _kFieldFill,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: borderColor),
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              addressText.isEmpty ? '주소를 검색해 주세요' : addressText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: addressText.isEmpty ? _kMuted : _kInk,
                fontSize: healthSp(context, 12),
                fontFamily: _kFont,
                fontWeight:
                    addressText.isEmpty ? FontWeight.w300 : FontWeight.w500,
              ),
            ),
          ),
        ),
        SizedBox(width: healthDp(context, 10)),
        _addressSearchButton(context),
      ],
    );
  }

  Widget _subjectChip(
      BuildContext context, String label, _SubjectPreset preset) {
    final selected = _subjectPreset == preset;
    return InkWell(
      onTap: () {
        setState(() {
          if (preset == _SubjectPreset.custom) {
            _subjectPreset = _SubjectPreset.custom;
            if (_subjectController.text == '집' ||
                _subjectController.text == '회사') {
              _subjectController.clear();
            }
          } else {
            _subjectPreset = preset;
            _subjectController.text = label;
          }
        });
      },
      borderRadius: BorderRadius.circular(healthDp(context, 15)),
      child: Container(
        height: healthDp(context, 45),
        padding: EdgeInsets.symmetric(horizontal: healthDp(context, 14)),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: selected ? const Color(0x0CFF5A8D) : Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: 1,
              color: selected ? _kPink : _kBorder,
            ),
            borderRadius: BorderRadius.circular(healthDp(context, 15)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _kInk : _kMuted,
            fontSize: healthSp(context, 12),
            fontFamily: _kFont,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _defaultCheckbox(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _isDefault = !_isDefault),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: healthDp(context, 5)),
        child: Row(
          children: [
            Container(
              width: healthDp(context, 20),
              height: healthDp(context, 20),
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(width: 1, color: _kBorder),
                  borderRadius: BorderRadius.circular(healthDp(context, 4)),
                ),
              ),
              alignment: Alignment.center,
              child: _isDefault
                  ? Icon(
                      Icons.check,
                      size: healthDp(context, 14),
                      color: _kPink,
                    )
                  : null,
            ),
            SizedBox(width: healthDp(context, 5)),
            Expanded(
              child: Text(
                '기본 배송지로 설정',
                style: TextStyle(
                  color: _kInk,
                  fontSize: healthSp(context, 12),
                  fontFamily: _kFont,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = _DeliveryAddressChangePopupState._sharedPopupSize(context);
    final popupRadius = healthDp(context, 20);
    final pad20 = healthDp(context, 20);
    final btnH = healthDp(context, 50);
    final hasAddress = _addr1Controller.text.trim().isNotEmpty;

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          width: size.width,
          height: size.height,
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(popupRadius),
            ),
            shadows: const [
              BoxShadow(
                color: Color(0x19000000),
                blurRadius: 8.14,
                offset: Offset.zero,
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    pad20,
                    pad20,
                    pad20,
                    healthDp(context, 0),
                  ),
                  child: AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (context, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _isEdit ? '배송지 수정' : '배송지 신규 입력',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _kInk,
                              fontSize: healthSp(context, 20),
                              fontFamily: _kFont,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: healthDp(context, 20)),
                          Text(
                            '배송지명 (선택)',
                            style: TextStyle(
                              color: _kMuted,
                              fontSize: healthSp(context, 12),
                              fontFamily: _kFont,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: healthDp(context, 5)),
                          Row(
                            children: [
                              _subjectChip(context, '집', _SubjectPreset.home),
                              SizedBox(width: healthDp(context, 8)),
                              _subjectChip(
                                  context, '회사', _SubjectPreset.office),
                              SizedBox(width: healthDp(context, 8)),
                              _subjectChip(
                                  context, '직접입력', _SubjectPreset.custom),
                            ],
                          ),
                          if (_subjectPreset == _SubjectPreset.custom) ...[
                            SizedBox(height: healthDp(context, 10)),
                            _field(
                              context: context,
                              controller: _subjectController,
                              hint: '배송지명을 입력해 주세요.',
                              pulseKey: 'subject',
                            ),
                          ],
                          SizedBox(height: healthDp(context, 10)),
                          _requiredLabel(context, '받으시는 분'),
                          SizedBox(height: healthDp(context, 5)),
                          _field(
                            context: context,
                            controller: _nameController,
                            hint: '수령인의 이름을 입력해주세요.',
                            pulseKey: 'name',
                          ),
                          SizedBox(height: healthDp(context, 10)),
                          _requiredLabel(context, '연락처'),
                          SizedBox(height: healthDp(context, 5)),
                          _field(
                            context: context,
                            controller: _phoneController,
                            hint: "'-' 없이 기입해주세요.",
                            pulseKey: 'phone',
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                          ),
                          SizedBox(height: healthDp(context, 10)),
                          _requiredLabel(context, '배송지 주소'),
                          SizedBox(height: healthDp(context, 5)),
                          _addressSearchRow(context),
                          if (hasAddress) ...[
                            SizedBox(height: healthDp(context, 10)),
                            _field(
                              context: context,
                              controller: _addr2Controller,
                              hint: '상세 주소를 입력해 주세요.',
                              pulseKey: 'addr2',
                              textInputAction: TextInputAction.done,
                            ),
                          ],
                          SizedBox(height: healthDp(context, 10)),
                          _defaultCheckbox(context),
                        ],
                      );
                    },
                  ),
                ),
              ),
              SizedBox(
                height: btnH,
                child: Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: const Color(0xFFF7F7F7),
                        child: InkWell(
                          onTap: _saving ? null : () => Navigator.pop(context),
                          child: Center(
                            child: Text(
                              '취소',
                              style: TextStyle(
                                color: _kMuted,
                                fontSize: healthSp(context, 16),
                                fontFamily: _kFont,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Material(
                        color: _isFormComplete
                            ? _kPink
                            : _kPink.withValues(alpha: 0.45),
                        child: InkWell(
                          onTap: (_saving || !_isFormComplete) ? null : _save,
                          child: Center(
                            child: _saving
                                ? SizedBox(
                                    width: healthDp(context, 20),
                                    height: healthDp(context, 20),
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    '확인',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: healthSp(context, 16),
                                      fontFamily: _kFont,
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
    );
  }
}
