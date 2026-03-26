import 'package:flutter/material.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_bar.dart';
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
  final GlobalKey<FormFieldState<String>> _zipFormFieldKey = GlobalKey<FormFieldState<String>>();

  static const double _addressSearchRowHeight = 40;
  
  // 입력 컨트롤러
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();
  final TextEditingController _address1Controller = TextEditingController();
  final TextEditingController _address2Controller = TextEditingController();
  final TextEditingController _requestMemoController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    _requestMemoController.dispose();
    super.dispose();
  }

  /// 기존 데이터 로드 (수정 모드인 경우)
  void _loadData() {
    if (widget.address != null) {
      _subjectController.text = widget.address!['adSubject'] ?? '';
      _nameController.text = widget.address!['adName'] ?? '';
      _phoneController.text = widget.address!['adHp'] ?? '';
      _zipController.text = widget.address!['adZip1'] ?? '';
      _address1Controller.text = widget.address!['adAddr1'] ?? '';
      _address2Controller.text = '${widget.address!['adAddr2'] ?? ''} ${widget.address!['adAddr3'] ?? ''}'.trim();
      _requestMemoController.text = widget.address!['adMemo'] ?? '';
    }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다.')),
          );
        }
        return;
      }

      final addressData = {
        'mbId': user.id,
        'adSubject': _subjectController.text.trim(),
        'adDefault': widget.address?['adDefault'] ?? 0,
        'adName': _nameController.text.trim(),
        'adTel': _phoneController.text.trim(),
        'adHp': _phoneController.text.trim(),
        'adZip1': _zipController.text.trim(),
        'adZip2': widget.address?['adZip2'] ?? '',
        'adAddr1': _address1Controller.text.trim(),
        'adAddr2': _address2Controller.text.trim(),
        'adAddr3': '',
        'adJibeon': '',
        'adMemo': _requestMemoController.text.trim(),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '배송지가 저장되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // 성공 시 true 반환
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '배송지 저장에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ 배송지 저장 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('배송지 저장 중 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.address != null;
    return MobileAppLayoutWrapper(
      appBar: HealthAppBar(title: isEdit ? '배송지 수정' : '배송지 등록'),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(left: 27, right: 27, bottom: 20, top: 20),
            children: [
              const Text(
                '배송지 이름',
                style: TextStyle(
                  color: Color(0xFF898686),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.57,
                ),
              ),
              const SizedBox(height: 5),
              _BoxField(
                controller: _subjectController,
                hintText: '집',
                validator: (v) => (v == null || v.trim().isEmpty) ? '배송지 이름을 입력해주세요' : null,
              ),
              const SizedBox(height: 10),

              const Text(
                '받으시는 분',
                style: TextStyle(
                  color: Color(0xFF898686),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.57,
                ),
              ),
              const SizedBox(height: 5),
              _BoxField(
                controller: _nameController,
                hintText: '고명진',
                validator: (v) => (v == null || v.trim().isEmpty) ? '받으시는 분을 입력해주세요' : null,
              ),
              const SizedBox(height: 10),

              const Text(
                '연락처',
                style: TextStyle(
                  color: Color(0xFF898686),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.57,
                ),
              ),
              const SizedBox(height: 5),
              _BoxField(
                controller: _phoneController,
                hintText: '010-8878-8617',
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().isEmpty) ? '연락처를 입력해주세요' : null,
              ),
              const SizedBox(height: 10),

              const Text(
                '배송지 주소',
                style: TextStyle(
                  color: Color(0xFF898686),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.57,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: FormField<String>(
                      key: _zipFormFieldKey,
                      validator: (_) {
                        final t = _zipController.text.trim();
                        return t.isEmpty ? '우편번호를 입력해주세요' : null;
                      },
                      builder: (state) {
                        final hasErr = state.hasError;
                        final errColor = Theme.of(context).colorScheme.error;
                        final borderColor = hasErr ? errColor : const Color(0xFFD2D2D2);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: _addressSearchRowHeight,
                              child: TextField(
                                controller: _zipController,
                                enabled: false,
                                onChanged: (_) => state.didChange(_zipController.text),
                                style: const TextStyle(
                                  color: Color(0xFF1A1A1A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  hintText: '우편번호',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF898686),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    height: 1.83,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(width: 1, color: borderColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(width: 1, color: borderColor),
                                  ),
                                  disabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(width: 1, color: borderColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      width: 1,
                                      color: hasErr ? errColor : const Color(0xFFFF5A8D),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (state.hasError)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 4),
                                child: Text(
                                  state.errorText!,
                                  style: TextStyle(
                                    color: errColor,
                                    fontSize: 12,
                                    fontFamily: 'Gmarket Sans TTF',
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: SizedBox(
                      height: _addressSearchRowHeight,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('주소 검색 기능은 추후 구현 예정입니다.')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5A8D),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size.fromHeight(_addressSearchRowHeight),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          '주소 검색',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              _BoxField(
                controller: _address1Controller,
                hintText: '‘주소 검색’을 통해 입력됩니다,',
                validator: (v) => (v == null || v.trim().isEmpty) ? '주소를 입력해주세요' : null,
              ),
              const SizedBox(height: 5),
              _BoxField(
                controller: _address2Controller,
                hintText: '상세 주소를 입력해 주세요.',
              ),
              const SizedBox(height: 10),

              const Text(
                '배송 요청사항',
                style: TextStyle(
                  color: Color(0xFF898686),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.57,
                ),
              ),
              const SizedBox(height: 5),
              _BoxField(
                controller: _requestMemoController,
                hintText: '요청사항이 있으시면 입력해주세요.',
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5A8D),
                    disabledBackgroundColor: const Color(0x7FD2D2D2),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '저장',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
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

class _BoxField extends StatelessWidget {
  const _BoxField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.validator,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      minLines: 1,
      maxLines: 1,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFF898686),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.83,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(width: 1, color: Color(0xFFD2D2D2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(width: 1, color: Color(0xFFD2D2D2)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(width: 1, color: Color(0xFFD2D2D2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(width: 1, color: Color(0xFFFF5A8D)),
        ),
      ),
      style: const TextStyle(
        color: Color(0xFF1A1A1A),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      validator: validator,
    );
  }
}


