import 'package:flutter/material.dart';
import '../../../../data/services/auth_service.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_bar.dart';

class RefundAccountScreen extends StatefulWidget {
  const RefundAccountScreen({super.key});

  @override
  State<RefundAccountScreen> createState() => _RefundAccountScreenState();
}

class _RefundAccountScreenState extends State<RefundAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerController = TextEditingController();
  final _accountController = TextEditingController();

  // 은행 목록은 추후 DB 연동 예정 (지금은 UI만 구성)
  static const String _bankPlaceholder = '은행을 선택하세요';
  final List<String> _banks = const [_bankPlaceholder];
  String _selectedBank = _bankPlaceholder;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getUser();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = user != null;
    });
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('환불계좌가 저장되었습니다.')),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(title: '환불계좌관리'),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
        child: _isLoggedIn
            ? Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.only(left: 27, right: 27, bottom: 20, top: 20),
                  children: [
                    const _FieldLabel('은행 선택'),
                    const SizedBox(height: 5),
                    _BoxDropdown<String>(
                      value: _selectedBank,
                      items: _banks
                          .map((bank) => DropdownMenuItem<String>(
                                value: bank,
                                child: Text(
                                  bank,
                                  style: const TextStyle(
                                    color: Color(0xFF1A1A1A),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ))
                          .toList(),
                      hintText: _bankPlaceholder,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedBank = value);
                      },
                      validator: (value) {
                        if (value == null || value == _bankPlaceholder) {
                          return null;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    const _FieldLabel('계좌번호'),
                    const SizedBox(height: 5),
                    _BoxField(
                      controller: _accountController,
                      hintText: '계좌번호를 입력해주세요.(- 는 제외)',
                      keyboardType: TextInputType.number,
                      validator: (v) => (v == null || v.trim().isEmpty) ? '계좌번호를 입력해주세요' : null,
                    ),
                    const SizedBox(height: 20),
                    const _FieldLabel('예금주명'),
                    const SizedBox(height: 5),
                    _BoxField(
                      controller: _ownerController,
                      hintText: '예금주 이름을 입력해주세요.',
                      validator: (v) => (v == null || v.trim().isEmpty) ? '예금주명을 입력해주세요' : null,
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5A8D),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
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
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '로그인 후 이용 가능합니다.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 16, height: 16),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
      style: const TextStyle(
        color: Color(0xFF898686),
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.57,
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
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  static const double _fieldH = 40;
  static const double _errorReserveH = 22;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return FormField<String>(
      initialValue: controller.text,
      validator: (v) => validator?.call(controller.text),
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _fieldH,
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                onChanged: (_) {
                  state.didChange(controller.text);
                  if (state.hasError) state.validate();
                },
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.all(10),
                  hintText: hintText,
                  hintStyle: const TextStyle(
                    color: Color(0xFF898686),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      width: 1,
                      color: state.hasError ? errorColor : const Color(0xFFD2D2D2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      width: 1,
                      color: state.hasError ? errorColor : const Color(0xFFD2D2D2),
                    ),
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
              ),
            ),
            SizedBox(
              height: _errorReserveH,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  state.errorText ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: errorColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BoxDropdown<T> extends StatelessWidget {
  const _BoxDropdown({
    required this.value,
    required this.items,
    required this.hintText,
    required this.onChanged,
    this.validator,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final String hintText;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        validator: validator,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.all(10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(width: 1, color: Color(0xFFD2D2D2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(width: 1, color: Color(0xFFD2D2D2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(width: 1, color: Color(0xFFFF5A8D)),
          ),
        ),
        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF898686)),
        style: const TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
