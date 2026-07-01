import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/refund_account_service.dart';
import '../../../common/widgets/dropdown_btn.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/centered_empty_state.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../utils/bank_icon_resolver.dart';

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
    'HANA 하나은행',
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
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );
    return Theme(
      data: gmarketTheme,
      child: MobileAppLayoutWrapper(
        appBar: HealthAppBar(
          title: '환불 계좌 관리',
          titleFontSize: healthSp(context, 18),
          leadingIconSize: healthDp(context, 24),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
          child: _isLoggedIn
                ? _loadingRefund
                    ? Center(
                        child: SizedBox(
                          width: healthDp(context, 36),
                          height: healthDp(context, 36),
                          child: const CircularProgressIndicator(
                              color: Color(0xFFFF5A8D)),
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: Form(
                              key: _formKey,
                              child: ListView(
                                padding: EdgeInsets.only(
                                  left: healthDp(context, 27),
                                  right: healthDp(context, 27),
                                  top: healthDp(context, 20),
                                  bottom: healthDp(context, 16),
                                ),
                                children: [
                                  const _FieldLabel('은행 선택'),
                                  SizedBox(height: healthDp(context, 5)),
                                  DropdownBtn(
                                    items: _bankItemsForDropdown,
                                    value: _selectedBank,
                                    emptyText: _bankEmptyHint,
                                    buttonHeight: healthDp(context, 40),
                                    panelMaxHeight: healthDp(context, 320),
                                    itemFontSizeBase: 12,
                                    itemTextAlign: TextAlign.start,
                                    itemLeadingGapBase: 8,
                                    leadingBuilder: (name) => _BankIconLeading(
                                      bankName: name,
                                      size: healthDp(context, 22),
                                    ),
                                    onChanged: (v) =>
                                        setState(() => _selectedBank = v),
                                  ),
                                  SizedBox(height: healthDp(context, 20)),
                                  const _FieldLabel('계좌번호'),
                                  SizedBox(height: healthDp(context, 5)),
                                  _BoxField(
                                    controller: _accountController,
                                    hintText: '계좌번호를 입력해주세요.(- 는 제외)',
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? '계좌번호를 입력해주세요'
                                            : null,
                                  ),
                                  const SizedBox(height: 20),
                                  const _FieldLabel('예금주명'),
                                  SizedBox(height: healthDp(context, 5)),
                                  _BoxField(
                                    controller: _ownerController,
                                    hintText: '예금주 이름을 입력해주세요.',
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? '예금주명을 입력해주세요'
                                            : null,
                                  ),
                                  SizedBox(height: healthDp(context, 10)),
                                  Text(
                                    '*환불 처리를 위해 정확한 계좌정보를 입력해 주세요.',
                                    style: TextStyle(
                                      color: const Color(0xFF898686),
                                      fontSize: healthSp(context, 10),
                                      fontWeight: FontWeight.w300,
                                      height: 1.4,
                                    ),
                                  ),
                                  SizedBox(height: healthDp(context, 10)),
                                  Text(
                                    '입력하신 정보가 부정확할 경우 환불이 지연되거나 처리되지 않을 수 있으며, 이에 대한 책임은 입력자 본인에게 있습니다.',
                                    style: TextStyle(
                                      color: const Color(0xFF898686),
                                      fontSize: healthSp(context, 10),
                                      fontWeight: FontWeight.w300,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SafeArea(
                            top: false,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                healthDp(context, 27),
                                healthDp(context, 12),
                                healthDp(context, 27),
                                healthDp(context, 16),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _RefundFormButton(
                                      label: '취소',
                                      filled: false,
                                      onTap: () => Navigator.pop(context),
                                    ),
                                  ),
                                  SizedBox(width: healthDp(context, 20)),
                                  Expanded(
                                    child: _RefundFormButton(
                                      label: '확인',
                                      filled: true,
                                      onTap: _submit,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                : const CenteredEmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    message: '로그인 후 이용 가능합니다.',
                  ),
        ),
      ),
    );
  }
}

class _BankIconLeading extends StatelessWidget {
  const _BankIconLeading({
    required this.bankName,
    required this.size,
  });

  final String bankName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = bankIconAssetForName(bankName);
    if (asset == null) {
      return SizedBox(width: size, height: size);
    }
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _RefundFormButton extends StatelessWidget {
  const _RefundFormButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final height = healthDp(context, 40);
    final radius = healthDp(context, 10);
    final borderW = healthDp(context, 0.5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          height: height,
          decoration: ShapeDecoration(
            color: filled ? const Color(0xFFFF5A8D) : Colors.white,
            shape: RoundedRectangleBorder(
              side: filled
                  ? BorderSide.none
                  : BorderSide(
                      width: borderW,
                      color: const Color(0xFFD2D2D2),
                    ),
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
              style: TextStyle(
                color: filled ? Colors.white : const Color(0xFF898686),
                fontSize: healthSp(context, 16),
                fontWeight: FontWeight.w500,
                height: 1.0,
              ),
            ),
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

class _BoxField extends StatefulWidget {
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

  @override
  State<_BoxField> createState() => _BoxFieldState();
}

class _BoxFieldState extends State<_BoxField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    final fieldH = healthDp(context, 40);
    final padH = healthDp(context, 12);
    final radius = healthDp(context, 10);
    final borderW = healthDp(context, 1);

    return FormField<String>(
      initialValue: widget.controller.text,
      validator: (v) => widget.validator?.call(widget.controller.text),
      builder: (state) {
        Color borderColor = const Color(0xFFD2D2D2);
        if (state.hasError) {
          borderColor = errorColor;
        } else if (_focusNode.hasFocus) {
          borderColor = const Color(0xFFFF5A8D);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: fieldH,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(width: borderW, color: borderColor),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: padH),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    keyboardType: widget.keyboardType,
                    inputFormatters: widget.inputFormatters,
                    expands: true,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.center,
                    onChanged: (_) {
                      state.didChange(widget.controller.text);
                      if (state.hasError) state.validate();
                    },
                    decoration: InputDecoration(
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        color: const Color(0xFF898686),
                        fontSize: healthSp(context, 12),
                        fontWeight: FontWeight.w500,
                        height: 1.0,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                    ),
                    style: TextStyle(
                      color: const Color(0xFF1A1A1A),
                      fontSize: healthSp(context, 12),
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: EdgeInsets.only(top: healthDp(context, 4)),
                child: Text(
                  state.errorText ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: errorColor,
                    fontSize: healthSp(context, 11),
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
