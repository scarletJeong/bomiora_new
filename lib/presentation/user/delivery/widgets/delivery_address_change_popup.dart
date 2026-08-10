import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
const Color _kInk = Color(0xFF1A1A1A);
const Color _kMuted = Color(0xFF898686);
const Color _kAddrMuted = Color(0xFF898383);
const Color _kBorder = Color(0xFFD2D2D2);
const Color _kFieldFill = Color(0xFFF8FAFC);
const Color _kSelectedBg = Color(0x0CFF5C8F);
const Color _kSelectedBorder = Color(0xFFFF5C8F);
const Color _kChipTint = Color(0x0CFF5A8D);
const Color _kReadonlyFill = Color(0xFFF8F8F8);

enum _SubjectPreset { none, home, office, custom }

enum _PopupPage { list, form }

/// 주문 배송지 변경 팝업.
///
/// 목록 / 신규·수정 폼이 **동일 고정 크기** 안에서 페이지 전환됩니다.
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

class _DeliveryAddressChangePopupState extends State<DeliveryAddressChangePopup>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _addresses = [];
  int? _selectedAddressId;

  _PopupPage _page = _PopupPage.list;
  Map<String, dynamic>? _editingAddress;

  final _pageController = PageController();
  final _subjectController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _zipController = TextEditingController();
  final _addr1Controller = TextEditingController();
  final _addr2Controller = TextEditingController();

  _SubjectPreset _subjectPreset = _SubjectPreset.none;
  bool _isDefault = false;

  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  Set<String> _pulseFields = {};

  bool get _isEditForm => _editingAddress != null;

  String get _formTitle =>
      _isEditForm ? '배송지 수정' : '배송지 추가';

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFormChanged);
    _phoneController.addListener(_onFormChanged);
    _addr1Controller.addListener(_onFormChanged);
    _addr2Controller.addListener(_onFormChanged);
    _subjectController.addListener(_onFormChanged);
    _loadData();
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFormChanged);
    _phoneController.removeListener(_onFormChanged);
    _addr1Controller.removeListener(_onFormChanged);
    _addr2Controller.removeListener(_onFormChanged);
    _subjectController.removeListener(_onFormChanged);
    _pageController.dispose();
    _subjectController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _zipController.dispose();
    _addr1Controller.dispose();
    _addr2Controller.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  /// 제목 + 신규입력 + 카드 3개 분량 + 푸터 (스케일 적용, 고정)
  double _fixedPopupHeight(BuildContext context) {
    final pad = healthDp(context, 20);
    final titleH = healthDp(context, 30);
    final addH = healthDp(context, 42);
    final cardH = healthDp(context, 112);
    final cardGap = healthDp(context, 8);
    final listViewport = cardH * 3 + cardGap * 2;
    final footer = healthDp(context, 50);
    return pad +
        titleH +
        healthDp(context, 16) +
        addH +
        healthDp(context, 12) +
        listViewport +
        healthDp(context, 12) +
        footer;
  }

  Future<void> _loadData() async {
    final user = await AuthService.getUser();
    if (user == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    final addresses = await AddressService.getAddressList(user.id);
    if (!mounted) return;

    _addresses = addresses;
    if (_addresses.isNotEmpty) {
      final hasSelected =
          _addresses.any((a) => a['adId'] == _selectedAddressId);
      if (!hasSelected) {
        final matchedId = await _matchOrderAddressId(user.id);
        if (matchedId != null &&
            _addresses.any((a) => a['adId'] == matchedId)) {
          _selectedAddressId = matchedId;
        } else {
          final defaultAddress = _addresses.firstWhere(
            (a) => a['adDefault'] == 1,
            orElse: () => _addresses.first,
          );
          _selectedAddressId = defaultAddress['adId'] as int?;
        }
      }
    } else {
      _selectedAddressId = null;
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  /// 주문에 현재 적용된 배송지와 동일한 주소 카드 id를 찾습니다.
  Future<int?> _matchOrderAddressId(String mbId) async {
    final orderId = widget.orderId.trim();
    if (orderId.isEmpty) return null;

    try {
      final result = await order_service.OrderService.getOrderDetail(
        odId: orderId,
        mbId: mbId,
      );
      if (result['success'] != true) return null;
      final order = result['order'];
      if (order is! OrderDetailModel) return null;

      final oName = order.recipientName.trim();
      final oPhone =
          order.recipientPhone.replaceAll(RegExp(r'[^0-9]'), '');
      final oAddr1 = order.recipientAddress.trim();
      final oAddr2 = order.recipientAddressDetail.trim();

      int? softMatch;
      for (final a in _addresses) {
        final aName = (a['adName'] ?? '').toString().trim();
        final aPhone = (a['adHp'] ?? a['adTel'] ?? '')
            .toString()
            .replaceAll(RegExp(r'[^0-9]'), '');
        final a1 = (a['adAddr1'] ?? '').toString().trim();
        final a2 = (a['adAddr2'] ?? '').toString().trim();

        if (oName == aName &&
            oPhone == aPhone &&
            oAddr1 == a1 &&
            oAddr2 == a2) {
          return a['adId'] as int?;
        }
        if (softMatch == null &&
            oName == aName &&
            oPhone == aPhone &&
            oAddr1 == a1) {
          softMatch = a['adId'] as int?;
        }
      }
      return softMatch;
    } catch (_) {
      return null;
    }
  }

  void _resetForm() {
    _subjectController.clear();
    _nameController.clear();
    _phoneController.clear();
    _zipController.clear();
    _addr1Controller.clear();
    _addr2Controller.clear();
    _subjectPreset = _SubjectPreset.none;
    _isDefault = false;
    _pulseFields = {};
    _editingAddress = null;
  }

  void _loadFormFromExisting(Map<String, dynamic> m) {
    _editingAddress = m;
    _nameController.text = (m['adName'] ?? '').toString().trim();
    _phoneController.text =
        (m['adHp'] ?? m['adTel'] ?? '').toString().trim();
    _zipController.text = (m['adZip1'] ?? '').toString().trim();
    _addr1Controller.text = (m['adAddr1'] ?? '').toString().trim();
    _addr2Controller.text = (m['adAddr2'] ?? '').toString().trim();
    _isDefault = m['adDefault'] == 1;

    final subject = (m['adSubject'] ?? '').toString().trim();
    if (subject.isEmpty) {
      _subjectPreset = _SubjectPreset.none;
      _subjectController.clear();
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

  Future<void> _goToForm({Map<String, dynamic>? existing}) async {
    setState(() {
      if (existing != null) {
        _loadFormFromExisting(existing);
      } else {
        _resetForm();
      }
      _page = _PopupPage.form;
    });
    await _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _goToList() async {
    await _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    setState(() {
      _page = _PopupPage.list;
      _resetForm();
    });
  }

  Future<void> _changeOrderAddress(int addressId) async {
    final user = await AuthService.getUser();
    if (user == null) return;

    final result = await order_service.OrderService.changeDeliveryAddress(
      odId: widget.orderId,
      mbId: user.id,
      addressId: addressId,
    );
    if (!mounted) return;
    if (result['success'] == true) {
      AppToastOverlay.show(context, '배송지를 변경했습니다.');
      Navigator.pop(context, true);
    }
  }

  Future<void> _submitList() async {
    if (_selectedAddressId == null || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await _changeOrderAddress(_selectedAddressId!);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool get _isFormComplete {
    if (_nameController.text.trim().isEmpty) return false;
    if (_phoneController.text.trim().isEmpty) return false;
    if (_addr1Controller.text.trim().isEmpty) return false;
    if (_addr2Controller.text.trim().isEmpty) return false;
    if (_subjectPreset == _SubjectPreset.custom &&
        _subjectController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _submitForm() async {
    if (_isSubmitting) return;

    final nameEmpty = _nameController.text.trim().isEmpty;
    final phoneEmpty = _phoneController.text.trim().isEmpty;
    final addressEmpty = _addr1Controller.text.trim().isEmpty;
    final addr2Empty = _addr2Controller.text.trim().isEmpty;
    final subjectEmpty = _subjectPreset == _SubjectPreset.custom &&
        _subjectController.text.trim().isEmpty;

    if (nameEmpty || phoneEmpty || addressEmpty || addr2Empty || subjectEmpty) {
      await _triggerPulse({
        if (nameEmpty) 'name',
        if (phoneEmpty) 'phone',
        if (addressEmpty) 'address',
        if (addr2Empty) 'addr2',
        if (subjectEmpty) 'subject',
      });
      return;
    }

    final wasEdit = _isEditForm;
    setState(() => _isSubmitting = true);
    try {
      final user = await AuthService.getUser();
      if (user == null) return;

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

      final result = wasEdit
          ? await AddressService.updateAddress(
              _editingAddress!['adId'] as int,
              payload,
            )
          : await AddressService.addAddress(payload);

      if (!mounted) return;
      if (result['success'] != true) return;

      int? addressId;
      if (wasEdit) {
        addressId = _editingAddress!['adId'] as int?;
      } else {
        final raw = result['data'];
        if (raw is Map) {
          addressId = NodeValueParser.asInt(raw['adId'] ?? raw['ad_id']);
        }
      }

      setState(() => _isLoading = true);
      await _loadData();
      if (addressId != null) {
        _selectedAddressId = addressId;
      } else if (_addresses.isNotEmpty && !wasEdit) {
        _selectedAddressId = _addresses.last['adId'] as int?;
      }
      if (!mounted) return;
      await _goToList();
      if (!mounted) return;
      AppToastOverlay.show(
        context,
        wasEdit ? '배송지를 수정했습니다.' : '배송지를 추가했습니다.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _onCancel() {
    if (_page == _PopupPage.form) {
      _goToList();
      return;
    }
    Navigator.pop(context, false);
  }

  void _onConfirm() {
    if (_page == _PopupPage.form) {
      _submitForm();
      return;
    }
    _submitList();
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

  static String _formatPostalCodeDisplay(String postalCode) {
    return postalCode.replaceAll(RegExp(r'[^0-9]'), '').trim();
  }

  Future<void> _openAddressSearch() async {
    final selected = await showDaumPostcodeSearchDialog(context);
    if (!mounted || selected == null) return;

    final postalCode = (selected['postalCode'] ?? '').toString().trim();
    final roadAddress = (selected['roadAddress'] ?? '').toString().trim();
    final jibunAddress = (selected['jibunAddress'] ?? '').toString().trim();
    final baseAddress = roadAddress.isNotEmpty ? roadAddress : jibunAddress;

    setState(() {
      _zipController.text = _formatPostalCodeDisplay(postalCode);
      _addr1Controller.text = baseAddress;
      _addr2Controller.clear();
      if (_pulseFields.contains('address')) {
        _pulseFields = {..._pulseFields}..remove('address');
      }
    });
  }

  // —— UI bits ——

  Widget _buildAddButton(BuildContext context) {
    return InkWell(
      onTap: () => _goToForm(),
      borderRadius: BorderRadius.circular(healthDp(context, 8)),
      child: Container(
        width: double.infinity,
        height: healthDp(context, 42),
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(width: healthDp(context, 1), color: _kBorder),
            borderRadius: BorderRadius.circular(healthDp(context, 8)),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '+ 배송지 신규입력',
          style: TextStyle(
            color: _kMuted,
            fontSize: healthSp(context, 12),
            fontFamily: _kFont,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildRadio(BuildContext context, bool selected) {
    final size = healthDp(context, 20);
    return Padding(
      padding: EdgeInsets.only(top: healthDp(context, 2)),
      child: Container(
        width: size,
        height: size,
        decoration: ShapeDecoration(
          color: selected ? _kPink : Colors.white,
          shape: OvalBorder(
            side: BorderSide(
              width: healthDp(context, 1.5),
              color: selected ? _kPink : _kBorder,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: selected
            ? Container(
                width: size * 0.4,
                height: size * 0.4,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildEditButton(BuildContext context, Map<String, dynamic> a) {
    return InkWell(
      onTap: () => _goToForm(existing: a),
      borderRadius: BorderRadius.circular(healthDp(context, 4)),
      child: Container(
        width: healthDp(context, 44),
        height: healthDp(context, 24),
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(width: healthDp(context, 1), color: _kBorder),
            borderRadius: BorderRadius.circular(healthDp(context, 4)),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '수정',
          style: TextStyle(
            color: _kInk,
            fontSize: healthSp(context, 11),
            fontFamily: _kFont,
            fontWeight: FontWeight.w500,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard(BuildContext context, Map<String, dynamic> a) {
    final adId = a['adId'] as int?;
    final selected = _selectedAddressId != null && _selectedAddressId == adId;
    final subject = (a['adSubject'] ?? '').toString().trim();
    final name = (a['adName'] ?? '').toString().trim();
    final title = subject.isNotEmpty ? '$name($subject)' : name;
    final phone = (a['adHp'] ?? '').toString().trim();
    final fullAddress = [
      (a['adAddr1'] ?? '').toString().trim(),
      (a['adAddr2'] ?? '').toString().trim(),
      (a['adAddr3'] ?? '').toString().trim(),
    ].where((e) => e.isNotEmpty).join(' ');
    final isDefault = a['adDefault'] == 1;

    return InkWell(
      onTap: adId == null
          ? null
          : () => setState(() => _selectedAddressId = adId),
      borderRadius: BorderRadius.circular(healthDp(context, 12)),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
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
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                healthDp(context, 12),
                healthDp(context, 12),
                isDefault ? healthDp(context, 72) : healthDp(context, 12),
                healthDp(context, 12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRadio(context, selected),
                  SizedBox(width: healthDp(context, 10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.isEmpty ? '수령인' : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: healthSp(context, 14),
                            fontFamily: _kFont,
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                          ),
                        ),
                        SizedBox(height: healthDp(context, 8)),
                        if (phone.isNotEmpty) ...[
                          Text(
                            phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _kAddrMuted,
                              fontSize: healthSp(context, 12),
                              fontFamily: _kFont,
                              fontWeight: FontWeight.w500,
                              height: 1.0,
                            ),
                          ),
                          SizedBox(height: healthDp(context, 4)),
                        ],
                        Text(
                          fullAddress.isEmpty ? '-' : fullAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _kAddrMuted,
                            fontSize: healthSp(context, 12),
                            fontFamily: _kFont,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                        SizedBox(height: healthDp(context, 8)),
                        _buildEditButton(context, a),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isDefault)
              Positioned(
                top: healthDp(context, 10),
                right: healthDp(context, 10),
                child: _defaultBadge(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListPage(BuildContext context) {
    final pad20 = healthDp(context, 20);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad20, pad20, pad20, 0),
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
              SizedBox(height: healthDp(context, 16)),
              _buildAddButton(context),
              SizedBox(height: healthDp(context, 12)),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _addresses.isEmpty
                  ? Center(
                      child: Text(
                        '등록된 배송지가 없습니다.',
                        style: TextStyle(
                          color: _kMuted,
                          fontSize: healthSp(context, 12),
                          fontFamily: _kFont,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        pad20,
                        0,
                        pad20,
                        healthDp(context, 12),
                      ),
                      itemCount: _addresses.length,
                      separatorBuilder: (_, __) =>
                          SizedBox(height: healthDp(context, 8)),
                      itemBuilder: (context, i) =>
                          _buildAddressCard(context, _addresses[i]),
                    ),
        ),
      ],
    );
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
          ' *',
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

  static double _fieldHeight(BuildContext context) => healthDp(context, 45);

  Widget _field({
    required BuildContext context,
    required TextEditingController controller,
    required String hint,
    required String pulseKey,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Color fillColor = Colors.white,
  }) {
    final borderColor = _pulseBorderColor(pulseKey);
    final radius = healthDp(context, 10);
    final fieldH = _fieldHeight(context);
    return Container(
      width: double.infinity,
      height: fieldH,
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.centerLeft,
      decoration: ShapeDecoration(
        color: fillColor,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: borderColor),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        cursorColor: _kPink,
        style: TextStyle(
          color: _kInk,
          fontSize: healthSp(context, 12),
          fontFamily: _kFont,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
        onChanged: (_) {
          if (_pulseFields.contains(pulseKey)) {
            setState(() => _pulseFields = {..._pulseFields}..remove(pulseKey));
          }
        },
        decoration: InputDecoration(
          isDense: true,
          isCollapsed: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            color: _kMuted,
            fontSize: healthSp(context, 12),
            fontFamily: _kFont,
            fontWeight: FontWeight.w300,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _defaultBadge(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 8),
        vertical: healthDp(context, 4),
      ),
      decoration: BoxDecoration(
        color: _kPink,
        borderRadius: BorderRadius.circular(healthDp(context, 999)),
      ),
      child: Text(
        '기본배송지',
        style: TextStyle(
          color: Colors.white,
          fontSize: healthSp(context, 10),
          fontFamily: _kFont,
          fontWeight: FontWeight.w500,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _readOnlyBox(BuildContext context, String text, {String? hint}) {
    final display = text.trim();
    final radius = healthDp(context, 10);
    return Container(
      width: double.infinity,
      height: _fieldHeight(context),
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: _kReadonlyFill,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _kBorder),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        display.isEmpty ? (hint ?? '') : display,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: display.isEmpty ? _kMuted : _kInk,
          fontSize: healthSp(context, 12),
          fontFamily: _kFont,
          fontWeight: display.isEmpty ? FontWeight.w300 : FontWeight.w500,
          height: 1.2,
        ),
      ),
    );
  }

  /// '주소 검색' 버튼 고정 폭 (입력칸 정렬용)
  double _addressSearchButtonWidth(BuildContext context) {
    final style = TextStyle(
      fontSize: healthSp(context, 12),
      fontFamily: _kFont,
      fontWeight: FontWeight.w500,
    );
    final painter = TextPainter(
      text: TextSpan(text: '주소 검색', style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width + healthDp(context, 14) * 2;
  }

  Widget _addressSearchButton(BuildContext context) {
    final radius = healthDp(context, 10);
    final fieldH = _fieldHeight(context);
    final btnW = _addressSearchButtonWidth(context);
    return InkWell(
      onTap: _openAddressSearch,
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: btnW,
        height: fieldH,
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
    // 검색 후 이 칸에 우편번호 표시 (총 3칸: 우편번호+검색 / 주소1 / 상세)
    final zipText = _zipController.text.trim();
    final borderColor = _pulseBorderColor('address');
    final radius = healthDp(context, 10);
    final fieldH = _fieldHeight(context);

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _openAddressSearch,
            borderRadius: BorderRadius.circular(radius),
            child: Container(
              height: fieldH,
              padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
              clipBehavior: Clip.antiAlias,
              decoration: ShapeDecoration(
                color: _kReadonlyFill,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: borderColor),
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                zipText.isEmpty ? '주소를 검색해 주세요' : zipText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: zipText.isEmpty ? _kMuted : _kInk,
                  fontSize: healthSp(context, 12),
                  fontFamily: _kFont,
                  fontWeight:
                      zipText.isEmpty ? FontWeight.w300 : FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: healthDp(context, 8)),
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
        decoration: ShapeDecoration(
          color: selected ? _kChipTint : Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: selected ? _kPink : _kBorder),
            borderRadius: BorderRadius.circular(healthDp(context, 15)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF1A1A1E) : _kAddrMuted,
                fontSize: healthSp(context, 12),
                fontFamily: _kFont,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultCheckbox(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _isDefault = !_isDefault),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: healthDp(context, 20),
            height: healthDp(context, 20),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  width: healthDp(context, 1.5),
                  // 체크해도 테두리는 회색 유지
                  color: _kBorder,
                ),
                borderRadius: BorderRadius.circular(healthDp(context, 4)),
              ),
            ),
            alignment: Alignment.center,
            child: _isDefault
                ? Icon(Icons.check, size: healthDp(context, 14), color: _kPink)
                : null,
          ),
          SizedBox(width: healthDp(context, 8)),
          Text(
            '기본 배송지로 설정',
            style: TextStyle(
              color: _kMuted,
              fontSize: healthSp(context, 12),
              fontFamily: _kFont,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormPage(BuildContext context) {
    final pad20 = healthDp(context, 20);
    final hasAddress = _addr1Controller.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad20, pad20, pad20, 0),
          child: Text(
            _formTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _kInk,
              fontSize: healthSp(context, 20),
              fontFamily: _kFont,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, _) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  pad20,
                  healthDp(context, 16),
                  pad20,
                  healthDp(context, 12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '배송지',
                      style: TextStyle(
                        color: _kInk,
                        fontSize: healthSp(context, 16),
                        fontFamily: _kFont,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: healthDp(context, 10)),
                    Text(
                      '배송지명 (선택)',
                      style: TextStyle(
                        color: _kMuted,
                        fontSize: healthSp(context, 12),
                        fontFamily: _kFont,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: healthDp(context, 8)),
                    Row(
                      children: [
                        _subjectChip(context, '집', _SubjectPreset.home),
                        SizedBox(width: healthDp(context, 8)),
                        _subjectChip(context, '회사', _SubjectPreset.office),
                        SizedBox(width: healthDp(context, 8)),
                        _subjectChip(context, '직접입력', _SubjectPreset.custom),
                      ],
                    ),
                    if (_subjectPreset == _SubjectPreset.custom) ...[
                      SizedBox(height: healthDp(context, 8)),
                      _field(
                        context: context,
                        controller: _subjectController,
                        hint: '배송지명을 입력해 주세요.',
                        pulseKey: 'subject',
                      ),
                    ],
                    SizedBox(height: healthDp(context, 16)),
                    _requiredLabel(context, '받으시는 분'),
                    SizedBox(height: healthDp(context, 8)),
                    _field(
                      context: context,
                      controller: _nameController,
                      hint: '수령인의 이름을 입력해 주세요.',
                      pulseKey: 'name',
                    ),
                    SizedBox(height: healthDp(context, 16)),
                    _requiredLabel(context, '연락처'),
                    SizedBox(height: healthDp(context, 8)),
                    _field(
                      context: context,
                      controller: _phoneController,
                      hint: "'-' 없이 기입해 주세요.",
                      pulseKey: 'phone',
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                    ),
                    SizedBox(height: healthDp(context, 16)),
                    _requiredLabel(context, '배송지 주소'),
                    SizedBox(height: healthDp(context, 8)),
                    _addressSearchRow(context),
                    if (hasAddress) ...[
                      SizedBox(height: healthDp(context, 8)),
                      _readOnlyBox(
                        context,
                        _addr1Controller.text,
                        hint: '기본 주소',
                      ),
                      SizedBox(height: healthDp(context, 8)),
                      _field(
                        context: context,
                        controller: _addr2Controller,
                        hint: '상세 주소를 입력해 주세요.',
                        pulseKey: 'addr2',
                      ),
                    ],
                    SizedBox(height: healthDp(context, 16)),
                    _defaultCheckbox(context),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final confirmEnabled = _page == _PopupPage.form
        ? _isFormComplete
        : _selectedAddressId != null;
    return SizedBox(
      height: healthDp(context, 50),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: const Color(0xFFF7F7F7),
              child: InkWell(
                onTap: _isSubmitting ? null : _onCancel,
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
              color: confirmEnabled
                  ? _kPink
                  : _kPink.withValues(alpha: 0.45),
              child: InkWell(
                onTap: (_isSubmitting || !confirmEnabled) ? null : _onConfirm,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final popupWidth = healthDp(context, 361);
    final popupHeight = _fixedPopupHeight(context);
    final popupRadius = healthDp(context, 20);

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          width: popupWidth,
          height: popupHeight,
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
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildListPage(context),
                    _buildFormPage(context),
                  ],
                ),
              ),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }
}
