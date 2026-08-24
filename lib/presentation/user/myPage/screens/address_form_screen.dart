import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/confirm_dialog.dart';
import '../../../common/widgets/app_toast_overlay.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../../../common/widgets/daum_postcode_search_dialog.dart';
import '../../../../data/services/address_service.dart';
import '../../../../data/services/auth_service.dart';

/// 배송지 추가/수정 화면
class AddressFormScreen extends StatefulWidget {
  final Map<String, dynamic>? address;

  const AddressFormScreen({
    super.key,
    this.address,
  });

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

enum _SubjectPreset { none, home, office, custom }

class _AddressFormScreenState extends State<AddressFormScreen> {
  static const double _confirmDialogWidth = 272;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();
  final TextEditingController _address1Controller = TextEditingController();
  final TextEditingController _address2Controller = TextEditingController();

  bool _isLoading = false;
  bool _isDefault = false;
  bool _wasDefault = false;
  /// 기본배송지를 해제할 수 없는지 (최초 등록 / 현재 유일한 기본배송지)
  bool _mustKeepDefault = false;
  bool _showDetailAddress = false;
  /// 주소 검색 직후 상세주소 칸 핑크 테두리 강조
  bool _highlightDetailAddress = false;
  _SubjectPreset _subjectPreset = _SubjectPreset.none;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFormChanged);
    _phoneController.addListener(_onFormChanged);
    _address1Controller.addListener(_onFormChanged);
    _address2Controller.addListener(_onFormChanged);
    _subjectController.addListener(_onFormChanged);
    _loadData();
    _resolveDefaultRequirement();
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  bool get _isPhoneValid {
    final t = _phoneController.text.trim();
    return RegExp(r'^\d{11}$').hasMatch(t);
  }

  bool get _canSave {
    if (_nameController.text.trim().isEmpty) return false;
    if (!_isPhoneValid) return false;
    if (_address1Controller.text.trim().isEmpty) return false;
    if (_address2Controller.text.trim().isEmpty) return false;
    if (_subjectPreset == _SubjectPreset.custom &&
        _subjectController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _resolveDefaultRequirement() async {
    final user = await AuthService.getUser();
    if (!mounted || user == null) return;

    final list = await AddressService.getAddressList(user.id);
    if (!mounted) return;

    if (widget.address == null) {
      // 최초 등록: 기본배송지 체크 필수
      final isFirst = list.isEmpty;
      setState(() {
        _mustKeepDefault = isFirst;
        if (isFirst) {
          _isDefault = true;
        }
      });
      return;
    }

    // 수정: 이 주소가 유일한 기본배송지면 해제 불가
    if (_wasDefault) {
      final otherDefaultExists = list.any((a) {
        if (a['adDefault'] != 1) return false;
        return a['adId'] != widget.address!['adId'];
      });
      setState(() {
        _mustKeepDefault = !otherDefaultExists;
        if (_mustKeepDefault) _isDefault = true;
      });
    }
  }

  void _onDefaultChanged(bool wantDefault) {
    if (!wantDefault && _mustKeepDefault) {
      AppToastOverlay.show(context, '기본 배송지는 1개 존재해야됩니다.');
      setState(() => _isDefault = true);
      return;
    }
    setState(() => _isDefault = wantDefault);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFormChanged);
    _phoneController.removeListener(_onFormChanged);
    _address1Controller.removeListener(_onFormChanged);
    _address2Controller.removeListener(_onFormChanged);
    _subjectController.removeListener(_onFormChanged);
    _subjectController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _zipController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    super.dispose();
  }

  static String _str(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      if (v is String) {
        final t = v.trim();
        if (t.isNotEmpty) return t;
      } else {
        final t = v.toString().trim();
        if (t.isNotEmpty && t != 'null') return t;
      }
    }
    return '';
  }

  static String _zipLine(Map<String, dynamic> m) {
    final z1 = _str(m, ['adZip1', 'ad_zip1']);
    final z2 = _str(m, ['adZip2', 'ad_zip2']);
    return ('$z1$z2').replaceAll(RegExp(r'[^0-9]'), '');
  }

  static Map<String, String> _splitZipForApi(String raw) {
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

  static String _formatPostalCodeDisplay(String postalCode) {
    return postalCode.replaceAll(RegExp(r'[^0-9]'), '').trim();
  }

  void _loadData() {
    final m = widget.address;
    if (m == null) {
      _subjectPreset = _SubjectPreset.none;
      _subjectController.text = '';
      return;
    }

    final zipLine = _zipLine(m);
    final subject = _str(m, ['adSubject', 'ad_subject']);
    _nameController.text = _str(m, ['adName', 'ad_name']);
    final rawPhone = _str(m, ['adHp', 'ad_hp', 'adTel', 'ad_tel']);
    final phoneDigits = rawPhone.replaceAll(RegExp(r'\D'), '');
    _phoneController.text =
        phoneDigits.length > 11 ? phoneDigits.substring(0, 11) : phoneDigits;
    _zipController.text = zipLine;
    _address1Controller.text = _str(m, ['adAddr1', 'ad_addr1']);
    final a2 = _str(m, ['adAddr2', 'ad_addr2']);
    final a3 = _str(m, ['adAddr3', 'ad_addr3']);
    _address2Controller.text = '$a2 $a3'.trim();
    _wasDefault = m['adDefault'] == 1 || m['ad_default'] == 1;
    _isDefault = _wasDefault;
    _showDetailAddress = _address1Controller.text.trim().isNotEmpty;

    if (subject.isEmpty) {
      _subjectPreset = _SubjectPreset.none;
      _subjectController.text = '';
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

  // 배송지 주소 읽기 전용 박스 (회색·수정 불가)
  Widget _buildReadonlyBox({
    required String text,
    required String hintText,
  }) {
    final fieldHeight = healthDp(context, 40);
    final hasValue = text.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      height: fieldHeight,
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 10),
      ),
      alignment: Alignment.centerLeft,
      decoration: ShapeDecoration(
        color: const Color(0xFFF8F8F8),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: const Color(0xFFD2D2D2),
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      child: Text(
        hasValue ? text : hintText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: hasValue
              ? const Color(0xFF1A1A1A)
              : const Color(0xFF898686),
          fontSize: healthSp(context, 12),
          fontWeight: hasValue ? FontWeight.w500 : FontWeight.w300,
        ),
      ),
    );
  }

  // 주소 검색 버튼
  Widget _buildAddressSearchButton(double fieldHeight) {
    return SizedBox(
      height: fieldHeight,
      child: ElevatedButton(
        onPressed: _openAddressSearch,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF5A8D),
          elevation: 0,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 12),
          ),
          minimumSize: Size(0, fieldHeight),
          maximumSize: Size(double.infinity, fieldHeight),
          fixedSize: Size.fromHeight(fieldHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          '주소 검색',
          style: TextStyle(
            color: Colors.white,
            fontSize: healthSp(context, 12),
            fontWeight: FontWeight.w500,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  // 주소 검색 대화상자 열기
  Future<void> _openAddressSearch() async {
    Map<String, dynamic>? selected;
    try {
      selected = await showDaumPostcodeSearchDialog(context);
    } catch (_) {
      return;
    }
    if (!mounted || selected == null) return;

    final postalCode = (selected['postalCode'] ?? '').toString().trim();
    final roadAddress = (selected['roadAddress'] ?? '').toString().trim();
    final jibunAddress = (selected['jibunAddress'] ?? '').toString().trim();
    final baseAddress = roadAddress.isNotEmpty ? roadAddress : jibunAddress;
    final displayZip = _formatPostalCodeDisplay(postalCode);

    setState(() {
      _zipController.text = displayZip;
      _address1Controller.text = baseAddress;
      _address2Controller.text = '';
      _showDetailAddress = true;
      _highlightDetailAddress = true;
    });
  }

  // 배송지 종류 선택
  void _selectSubjectPreset(_SubjectPreset preset) {
    setState(() {
      // 같은 칩 다시 누르면 선택 해제
      if (_subjectPreset == preset) {
        _subjectPreset = _SubjectPreset.none;
        _subjectController.text = '';
        return;
      }
      _subjectPreset = preset;
      if (preset == _SubjectPreset.home) {
        _subjectController.text = '집';
      } else if (preset == _SubjectPreset.office) {
        _subjectController.text = '회사';
      } else if (preset == _SubjectPreset.custom) {
        if (_subjectController.text == '집' ||
            _subjectController.text == '회사') {
          _subjectController.text = '';
        }
      } else {
        _subjectController.text = '';
      }
    });
  }

  // 기본 배송지 변경 확인
  Future<bool> _confirmDefaultChangeIfNeeded() async {
    if (!_isDefault || _wasDefault) return true;

    final user = await AuthService.getUser();
    if (user == null) return false;

    final list = await AddressService.getAddressList(user.id);
    final otherDefaultExists = list.any((a) {
      if (a['adDefault'] != 1) return false;
      if (widget.address == null) return true;
      return a['adId'] != widget.address!['adId'];
    });

    if (!otherDefaultExists) return true;
    if (!mounted) return false;

    return ConfirmDialog.show(
      context,
      title: '기본 배송지 변경',
      message: '이 주소로 기본 배송지가 변경됩니다.\n주소 변경에 따라 장바구니에\n 담은 상품도 변동될 수 있습니다.',
      width: _confirmDialogWidth,
    );
  }

  // 배송지 저장
  Future<void> _saveAddress() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 11 || !RegExp(r'^\d{11}$').hasMatch(phone)) {
      AppToastOverlay.show(context, '연락처 11자리를 확인해 주세요.');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final subject = _subjectPreset == _SubjectPreset.none
        ? ''
        : _subjectController.text.trim();
    if (_subjectPreset == _SubjectPreset.custom && subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('배송지명을 입력해주세요.')),
      );
      return;
    }
    if (_address1Controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주소를 검색해주세요.')),
      );
      return;
    }
    if (_address2Controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상세 주소를 입력해주세요.')),
      );
      setState(() => _highlightDetailAddress = true);
      return;
    }

    final ok = await _confirmDefaultChangeIfNeeded();
    if (!ok || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final user = await AuthService.getUser();
      if (user == null) return;

      // 신규 등록 시 mb_id당 최대 10개
      if (widget.address == null) {
        final existing = await AddressService.getAddressList(user.id);
        if (existing.length >= 10) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('배송지는 최대 10개까지 등록할 수 있습니다.'),
            ),
          );
          return;
        }
      }

      final zipParts = _splitZipForApi(_zipController.text.trim());
      int defaultFlag = _isDefault ? 1 : 0;
      // 최초 등록 또는 유일한 기본배송지는 무조건 유지
      if (_mustKeepDefault) {
        defaultFlag = 1;
      } else if (!_isDefault && widget.address == null) {
        final existing = await AddressService.getAddressList(user.id);
        if (existing.isEmpty) {
          defaultFlag = 1;
        }
      }

      final addressData = {
        'mbId': user.id,
        'adSubject': subject,
        'adDefault': defaultFlag,
        'ad_default': defaultFlag,
        'adName': _nameController.text.trim(),
        'adTel': _phoneController.text.trim(),
        'adHp': _phoneController.text.trim(),
        'adZip1': zipParts['zip1'] ?? '',
        'adZip2': zipParts['zip2'] ?? '',
        'adAddr1': _address1Controller.text.trim(),
        'adAddr2': _address2Controller.text.trim(),
        'adAddr3': '',
        'adJibeon': '',
        'adMemo': '',
      };

      Map<String, dynamic> result;
      if (widget.address != null) {
        result = await AddressService.updateAddress(
          widget.address!['adId'],
          addressData,
        );
      } else {
        result = await AddressService.addAddress(addressData);
      }

      if (!mounted) return;
      if (result['success'] == true) {
        final isNew = widget.address == null;
        final defaultChanged =
            defaultFlag == 1 && !_wasDefault && !(_mustKeepDefault && isNew);
        AppToastOverlay.show(
          context,
          defaultChanged
              ? '기본배송지가 변경되었어요.'
              : (isNew ? '배송지를 추가했습니다.' : '배송지를 수정했습니다.'),
        );
        Navigator.of(context).pop(<String, dynamic>{
          'ok': true,
          'registered': isNew,
          'defaultChanged': defaultChanged,
        });
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 화면 빌드
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.address != null;
    final fieldHeight = healthDp(context, 40);

    return MobileAppLayoutWrapper(
      appBar: HealthAppBar(
        title: isEdit ? '배송지 수정' : '배송지 등록',
        titleFontSize: healthSp(context, 18),
        leadingIconSize: healthDp(context, 24),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.only(
              left: healthDp(context, 27),
              right: healthDp(context, 27),
              bottom: healthDp(context, 20),
              top: healthDp(context, 20),
            ),
            children: [
              const _FieldLabel('배송지명 (선택)'),
              SizedBox(height: healthDp(context, 5)),
              Row(
                children: [
                  _SubjectChip(
                    label: '집',
                    selected: _subjectPreset == _SubjectPreset.home,
                    onTap: () => _selectSubjectPreset(_SubjectPreset.home),
                  ),
                  SizedBox(width: healthDp(context, 8)),
                  _SubjectChip(
                    label: '회사',
                    selected: _subjectPreset == _SubjectPreset.office,
                    onTap: () => _selectSubjectPreset(_SubjectPreset.office),
                  ),
                  SizedBox(width: healthDp(context, 8)),
                  _SubjectChip(
                    label: '직접입력',
                    selected: _subjectPreset == _SubjectPreset.custom,
                    onTap: () => _selectSubjectPreset(_SubjectPreset.custom),
                  ),
                ],
              ),
              if (_subjectPreset == _SubjectPreset.custom) ...[
                SizedBox(height: healthDp(context, 8)),
                _BoxField(
                  controller: _subjectController,
                  hintText: '배송지명을 입력해주세요.',
                ),
              ],
              SizedBox(height: healthDp(context, 10)),
              const _FieldLabel('받으시는 분', isRequired: true),
              SizedBox(height: healthDp(context, 2)),
              _BoxField(
                controller: _nameController,
                hintText: '수령인의 이름을 입력해주세요.',
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? '받으시는 분을 입력해주세요.'
                    : null,
              ),
              SizedBox(height: healthDp(context, 10)),
              const _FieldLabel('연락처', isRequired: true),
              SizedBox(height: healthDp(context, 2)),
              _BoxField(
                controller: _phoneController,
                hintText: "'-' 없이 기입해주세요.",
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return '연락처를 입력해주세요.';
                  if (t.length != 11) return '연락처는 11자리로 입력해주세요.';
                  return null;
                },
              ),
              SizedBox(height: healthDp(context, 10)),
              const _FieldLabel('배송지 주소', isRequired: true),
              SizedBox(height: healthDp(context, 2)),
              if (!_showDetailAddress)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildReadonlyBox(
                        text: '',
                        hintText: '주소를 검색해주세요.',
                      ),
                    ),
                    SizedBox(width: healthDp(context, 8)),
                    _buildAddressSearchButton(fieldHeight),
                  ],
                )
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildReadonlyBox(
                        text: _zipController.text.trim(),
                        hintText: '우편번호',
                      ),
                    ),
                    SizedBox(width: healthDp(context, 8)),
                    _buildAddressSearchButton(fieldHeight),
                  ],
                ),
                SizedBox(height: healthDp(context, 2)),
                _buildReadonlyBox(
                  text: _address1Controller.text.trim(),
                  hintText: '주소',
                ),
                SizedBox(height: healthDp(context, 2)),
                _BoxField(
                  controller: _address2Controller,
                  hintText: '상세 주소를 입력해 주세요.',
                  highlightBorder: _highlightDetailAddress,
                  onChanged: (value) {
                    if (value.trim().isNotEmpty && _highlightDetailAddress) {
                      setState(() => _highlightDetailAddress = false);
                    }
                  },
                ),
              ],
              SizedBox(height: healthDp(context, 12)),
              InkWell(
                onTap: () => _onDefaultChanged(!_isDefault),
                child: Row(
                  children: [
                    Container(
                      width: healthDp(context, 20),
                      height: healthDp(context, 20),
                      decoration: ShapeDecoration(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            width: healthDp(context, 1.5),
                            color: const Color(0xFF898686),
                          ),
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 4)),
                        ),
                      ),
                      child: _isDefault
                          ? Icon(
                              Icons.check,
                              size: healthDp(context, 16),
                              color: const Color(0xFFFF5A8D),
                            )
                          : null,
                    ),
                    SizedBox(width: healthDp(context, 8)),
                    Text(
                      '기본 배송지로 설정',
                      style: TextStyle(
                        color: const Color(0xFF898686),
                        fontSize: healthSp(context, 14),
                        fontWeight: FontWeight.w500,
                        height: 1.57,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: healthDp(context, 20)),
              SizedBox(
                width: double.infinity,
                height: healthDp(context, 40),
                child: ElevatedButton(
                  onPressed: (_isLoading || !_canSave) ? null : _saveAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5A8D),
                    disabledBackgroundColor: const Color(0x7FD2D2D2),
                    elevation: 0,
                    visualDensity: VisualDensity.compact,
                    minimumSize: Size(double.infinity, healthDp(context, 40)),
                    maximumSize: Size(double.infinity, healthDp(context, 40)),
                    fixedSize: Size(double.infinity, healthDp(context, 40)),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 10)),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: healthDp(context, 18),
                          height: healthDp(context, 18),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          '저장',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: healthSp(context, 16),
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(healthDp(context, 15)),
      child: Container(
        height: healthDp(context, 45),
        padding: EdgeInsets.symmetric(horizontal: healthDp(context, 14)),
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: selected ? const Color(0x0CFF5A8D) : Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: healthDp(context, 1),
              color: selected
                  ? const Color(0xFFFF5A8D)
                  : const Color(0xFFD2D2D2),
            ),
            borderRadius: BorderRadius.circular(healthDp(context, 15)),
          ),
        ),
        // alignment를 넣으면 max width로 늘어나 한 줄에 칩 1개씩 떨어짐
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF1A1A1E)
                    : const Color(0xFF898383),
                fontSize: healthSp(context, 12),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.isRequired = false});

  final String text;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(
            color: const Color(0xFF898686),
            fontSize: healthSp(context, 14),
            fontWeight: FontWeight.w500,
            height: 1.57,
          ),
        ),
        if (isRequired)
          Text(
            ' *',
            style: TextStyle(
              color: const Color(0xFFFF5A8D),
              fontSize: healthSp(context, 14),
              fontWeight: FontWeight.w500,
              height: 1.57,
            ),
          ),
      ],
    );
  }
}

class _BoxField extends StatelessWidget {
  const _BoxField({
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.highlightBorder = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final bool highlightBorder;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final fieldHeight = healthDp(context, 40);
    final radius = healthDp(context, 10);
    final borderWidth = healthDp(context, 1);

    // TextFormField+OutlineInputBorder는 내부 패딩 때문에 실제 높이가 줄어듦.
    // 칩/주소검색 박스와 동일하게 Container 높이로 고정한다.
    return FormField<String>(
      initialValue: controller.text,
      validator: validator,
      builder: (field) {
        final borderColor = (field.hasError || highlightBorder)
            ? const Color(0xFFFF5A8D)
            : const Color(0xFFD2D2D2);
        return Container(
          width: double.infinity,
          height: fieldHeight,
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: borderWidth,
                color: borderColor,
              ),
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            cursorColor: const Color(0xFFFF5A8D),
            style: TextStyle(
              color: const Color(0xFF1A1A1A),
              fontSize: healthSp(context, 12),
              fontWeight: FontWeight.w500,
              height: 1.2,
              fontFamily: 'Gmarket Sans TTF',
            ),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              hintText: hintText,
              hintStyle: TextStyle(
                color: const Color(0xFF898686),
                fontSize: healthSp(context, 12),
                fontWeight: FontWeight.w300,
                height: 1.2,
                fontFamily: 'Gmarket Sans TTF',
              ),
            ),
            onChanged: (value) {
              field.didChange(value);
              onChanged?.call(value);
            },
          ),
        );
      },
    );
  }
}
