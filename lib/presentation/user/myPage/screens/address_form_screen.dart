import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../../../common/widgets/daum_postcode_search_dialog.dart';
import '../../../../data/services/address_service.dart';
import '../../../../data/services/auth_service.dart';

/// 배송지 추가/수정 화면
class AddressFormScreen extends StatefulWidget {
  final Map<String, dynamic>? address; // 수정 시 기존 주소 데이터

  const AddressFormScreen({
    super.key,
    this.address,
  });

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey<FormFieldState<String>> _zipFormFieldKey =
      GlobalKey<FormFieldState<String>>();

  // 입력 컨트롤러
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();
  final TextEditingController _address1Controller = TextEditingController();
  final TextEditingController _address2Controller = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _zipFormFieldKey.currentState?.didChange(_zipController.text);
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _zipController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _memoController.dispose();
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

  /// 우편번호: API는 ad_zip1·ad_zip2 분리, UI는 한 칸에 `12345` 형태로 표시
  static String _zipLine(Map<String, dynamic> m) {
    final z1 = _str(m, ['adZip1', 'ad_zip1']);
    final z2 = _str(m, ['adZip2', 'ad_zip2']);
    final joined = ('$z1$z2').replaceAll(RegExp(r'[^0-9]'), '');
    return joined;
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
    // 주소검색 결과에 하이픈이 포함되어도 화면에는 숫자 5자리로만 표시
    return postalCode.replaceAll(RegExp(r'[^0-9]'), '').trim();
  }

  /// 기존 데이터 로드 (수정 모드인 경우)
  void _loadData() {
    final m = widget.address;
    if (m == null) return;

    final zipLine = _zipLine(m);
    _subjectController.text = _str(m, ['adSubject', 'ad_subject']);
    _nameController.text = _str(m, ['adName', 'ad_name']);
    _phoneController.text = _str(m, ['adHp', 'ad_hp', 'adTel', 'ad_tel']);
    _zipController.text = zipLine;
    _address1Controller.text = _str(m, ['adAddr1', 'ad_addr1']);
    final a2 = _str(m, ['adAddr2', 'ad_addr2']);
    final a3 = _str(m, ['adAddr3', 'ad_addr3']);
    _address2Controller.text = '$a2 $a3'.trim();
    _memoController.text = _str(m, ['adMemo', 'ad_memo']);
  }

  Future<void> _openAddressSearch() async {
    final selected = await showDaumPostcodeSearchDialog(context);

    if (!mounted || selected == null) return;

    final postalCode = (selected['postalCode'] ?? '').toString().trim();
    final roadAddress = (selected['roadAddress'] ?? '').toString().trim();
    final jibunAddress = (selected['jibunAddress'] ?? '').toString().trim();
    final baseAddress = roadAddress.isNotEmpty ? roadAddress : jibunAddress;
    final displayZip = _formatPostalCodeDisplay(postalCode);

    setState(() {
      _zipController.text = displayZip;
      _address1Controller.text = baseAddress;
      // 상세주소(마지막 입력란)는 자동 채움 금지: 사용자가 항상 직접 입력
      _address2Controller.text = '';
    });

    _zipFormFieldKey.currentState?.didChange(_zipController.text);
  }

  /// 배송지 저장
  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await AuthService.getUser();
      if (user == null) {
        return;
      }

      final zipParts = _splitZipForApi(_zipController.text.trim());
      int defaultFlag = 0;
      if (widget.address != null) {
        defaultFlag = widget.address!['adDefault'] == 1 ? 1 : 0;
      } else {
        final existing = await AddressService.getAddressList(user.id);
        if (existing.isEmpty) {
          defaultFlag = 1;
        }
      }
      final addressData = {
        'mbId': user.id,
        'adSubject': _subjectController.text.trim(),
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
        'adMemo': _memoController.text.trim(),
      };

      Map<String, dynamic> result;

      if (widget.address != null) {
        // 수정
        result = await AddressService.updateAddress(
          widget.address!['adId'],
          addressData,
        );
      } else {
        // 추가
        result = await AddressService.addAddress(addressData);
      }

      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.of(context).pop(true); // 성공 시 true 반환
      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
              const _FieldLabel('배송지 이름'),
              SizedBox(height: healthDp(context, 5)),
              _BoxField(
                controller: _subjectController,
                hintText: '배송지 이름을 입력해주세요.',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '배송지 이름을 입력해주세요.' : null,
              ),
              SizedBox(height: healthDp(context, 10)),
              const _FieldLabel('받으시는 분'),
              SizedBox(height: healthDp(context, 5)),
              _BoxField(
                controller: _nameController,
                hintText: '수령인의 이름을 입력해주세요.',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '받으시는 분을 입력해주세요.' : null,
              ),
              SizedBox(height: healthDp(context, 10)),
              const _FieldLabel('연락처'),
              SizedBox(height: healthDp(context, 5)),
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
                  if (t.length > 11) return '연락처는 11자리까지 입력해주세요.';
                  return null;
                },
              ),
              SizedBox(height: healthDp(context, 10)),
              const _FieldLabel('배송지 주소'),
              SizedBox(height: healthDp(context, 5)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: FormField<String>(
                      key: _zipFormFieldKey,
                      validator: (_) {
                        final t = _zipController.text.trim();
                        return t.isEmpty ? '우편번호를 입력해주세요.' : null;
                      },
                      builder: (state) {
                        final hasErr = state.hasError;
                        final errColor = Theme.of(context).colorScheme.error;
                        final borderColor =
                            hasErr ? errColor : const Color(0xFFD2D2D2);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: fieldHeight,
                              child: TextField(
                                controller: _zipController,
                                enabled: false,
                                textAlignVertical: TextAlignVertical.center,
                                onChanged: (_) =>
                                    state.didChange(_zipController.text),
                                style: TextStyle(
                                  color: const Color(0xFF1A1A1A),
                                  fontSize: healthSp(context, 12),
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: healthDp(context, 12),
                                    vertical: healthDp(context, 12),
                                  ),
                                  hintText: '우편번호',
                                  hintStyle: TextStyle(
                                    color: const Color(0xFF898686),
                                    fontSize: healthSp(context, 12),
                                    fontWeight: FontWeight.w300,
                                    height: 1.83,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        healthDp(context, 10)),
                                    borderSide: BorderSide(
                                      width: healthDp(context, 1),
                                      color: borderColor,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        healthDp(context, 10)),
                                    borderSide: BorderSide(
                                      width: healthDp(context, 1),
                                      color: borderColor,
                                    ),
                                  ),
                                  disabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        healthDp(context, 10)),
                                    borderSide: BorderSide(
                                      width: healthDp(context, 1),
                                      color: borderColor,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        healthDp(context, 10)),
                                    borderSide: BorderSide(
                                      width: healthDp(context, 1),
                                      color: hasErr
                                          ? errColor
                                          : const Color(0xFFFF5A8D),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (state.hasError)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: healthDp(context, 4),
                                  left: healthDp(context, 4),
                                ),
                                child: Text(
                                  state.errorText!,
                                  style: TextStyle(
                                    color: errColor,
                                    fontSize: healthSp(context, 12),
                                    fontFamily: 'Gmarket Sans TTF',
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  SizedBox(width: healthDp(context, 8)),
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: fieldHeight,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _openAddressSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5A8D),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(healthDp(context, 10)),
                          ),
                          padding: EdgeInsets.zero,
                          minimumSize: Size(0, fieldHeight),
                          fixedSize: Size(double.infinity, fieldHeight),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          alignment: Alignment.center,
                        ),
                        child: Text(
                          '주소 검색',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: healthSp(context, 12),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: healthDp(context, 5)),
              _BoxField(
                controller: _address1Controller,
                hintText: "'주소 검색'을 통해 입력됩니다.",
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '주소를 입력해주세요.' : null,
              ),
              SizedBox(height: healthDp(context, 5)),
              _BoxField(
                controller: _address2Controller,
                hintText: '상세 주소를 입력해 주세요.',
              ),
              SizedBox(height: healthDp(context, 10)),
              const _FieldLabel('배송 요청사항'),
              SizedBox(height: healthDp(context, 5)),
              _BoxField(
                controller: _memoController,
                hintText: '요청사항이 있으시면 입력해주세요.',
              ),
              SizedBox(height: healthDp(context, 20)),
              SizedBox(
                width: double.infinity,
                height: healthDp(context, 40),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5A8D),
                    disabledBackgroundColor: const Color(0x7FD2D2D2),
                    elevation: 0,
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: const Color(0xFF898686),
        fontSize: healthSp(context, 14),
        fontWeight: FontWeight.w500,
        height: 1.57,
      ),
    );
  }
}

class _FieldHelperText extends StatelessWidget {
  const _FieldHelperText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: const Color(0xFF898686),
        fontSize: healthSp(context, 12),
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),
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
  });

  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final fieldHeight = healthDp(context, 40);
    final radius = healthDp(context, 10);
    final borderWidth = healthDp(context, 1);

    return SizedBox(
      height: fieldHeight,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        minLines: 1,
        maxLines: 1,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 10),
            vertical: healthDp(context, 10),
          ),
          hintText: hintText,
          hintStyle: TextStyle(
            color: const Color(0xFF898686),
            fontSize: healthSp(context, 12),
            fontWeight: FontWeight.w300,
            height: 1.83,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: BorderSide(
              width: borderWidth,
              color: const Color(0xFFD2D2D2),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: BorderSide(
              width: borderWidth,
              color: const Color(0xFFD2D2D2),
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: BorderSide(
              width: borderWidth,
              color: const Color(0xFFD2D2D2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: BorderSide(
              width: borderWidth,
              color: const Color(0xFFFF5A8D),
            ),
          ),
        ),
        style: TextStyle(
          color: const Color(0xFF1A1A1A),
          fontSize: healthSp(context, 12),
          fontWeight: FontWeight.w500,
        ),
        validator: validator,
      ),
    );
  }
}
