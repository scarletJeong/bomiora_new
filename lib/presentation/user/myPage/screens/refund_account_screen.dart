import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/refund_account_service.dart';
import '../../../common/widgets/dropdown_btn.dart';
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

  static const String _bankEmptyHint = '은행을 선택하세요';

  /// 드롭다운 노출 순서 (고정)
  static const List<String> _bankNames = [
    'KB 국민은행',
    'SH 신한은행',
    'WOORI 우리은행',
    '하나은행',
    'NH 농협은행',
    'IBK 기업은행',
    'KAKAO 카카오뱅크',
    'K 케이뱅크',
    'TOSS 토스뱅크',
    'BS 부산은행',
    'DG 대구은행',
    'G 광주은행',
    'GN 경남은행',
    'JB 전북은행',
    'JJ 제주은행',
    'SH 수협은행',
    'U 우체국',
    'SC제일은행',
    'CITI 씨티은행',
  ];

  String _selectedBank = '';
  bool _isLoggedIn = false;
  bool _loadingRefund = true;

  List<String> get _bankItemsForDropdown {
    final b = _selectedBank.trim();
    if (b.isNotEmpty && !_bankNames.contains(b)) {
      return [b, ..._bankNames];
    }
    return _bankNames;
  }

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getUser();
    if (!mounted) return;
    if (user == null) {
      setState(() {
        _isLoggedIn = false;
        _loadingRefund = false;
      });
      return;
    }
    setState(() {
      _isLoggedIn = true;
      _loadingRefund = true;
    });
    await _loadRefund(user.id);
  }

  Future<void> _loadRefund(String mbId) async {
    try {
      final data = await RefundAccountService.fetch(mbId);
      if (!mounted) return;
      if (data['success'] == true) {
        final bank = '${data['refundBank'] ?? data['mb_refund_bank'] ?? ''}'.trim();
        final acc = '${data['refundAccount'] ?? data['mb_refund_account'] ?? ''}'.trim();
        final holder = '${data['refundHolder'] ?? data['mb_refund_holder'] ?? ''}'.trim();
        setState(() {
          _selectedBank = bank;
        });
        _accountController.text = acc;
        _ownerController.text = holder;
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _loadingRefund = false);
      }
    }
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedBank.trim().isEmpty) {
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final user = await AuthService.getUser();
    if (!mounted) return;
    if (user == null) {
      return;
    }

    final digitsOnly = _accountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length < 10) {
      return;
    }

    try {
      final data = await RefundAccountService.save(
        mbId: user.id,
        refundBank: _selectedBank.trim(),
        refundAccountDigits: digitsOnly,
        refundHolder: _ownerController.text.trim(),
      );
      if (!mounted) return;
      if (data['success'] == true) {
        Navigator.pop(context, true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(title: '환불 계좌 관리'),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
        child: _isLoggedIn
            ? _loadingRefund
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A8D)))
                : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.only(left: 27, right: 27, bottom: 20, top: 20),
                  children: [
                    const _FieldLabel('은행 선택'),
                    const SizedBox(height: 5),
                    DropdownBtn(
                      items: _bankItemsForDropdown,
                      value: _selectedBank,
                      emptyText: _bankEmptyHint,
                      buttonHeight: 40,
                      panelMaxHeight: 320,
                      onChanged: (v) => setState(() => _selectedBank = v),
                    ),
                    const SizedBox(height: 20),
                    const _FieldLabel('계좌번호'),
                    const SizedBox(height: 5),
                    _BoxField(
                      controller: _accountController,
                      hintText: '계좌번호를 입력해주세요.(- 는 제외)',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (v) => (v == null || v.trim().isEmpty) ? '계좌번호를 입력해주세요' : null,
                    ),
                    const SizedBox(height: 0),
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
    this.inputFormatters,
    this.validator,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
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
                inputFormatters: inputFormatters,
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
