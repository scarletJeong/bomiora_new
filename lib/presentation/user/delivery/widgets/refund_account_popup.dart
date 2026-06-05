import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../data/services/refund_account_service.dart';
import '../../../common/widgets/dropdown_btn.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../myPage/utils/bank_icon_resolver.dart';

/// 환불 계좌 입력 결과 (가상계좌 주문 취소 등)
class RefundAccountInput {
  final String bank;
  final String accountDigits;
  final String holder;

  const RefundAccountInput({
    required this.bank,
    required this.accountDigits,
    required this.holder,
  });
}

/// 가상계좌 환불용 계좌 입력 팝업 — 등록된 환불계좌가 있으면 API로 채움
class RefundAccountPopup extends StatefulWidget {
  final String mbId;

  const RefundAccountPopup({super.key, required this.mbId});

  static const List<String> bankNames = [
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

  static Future<RefundAccountInput?> show(
    BuildContext context, {
    required String mbId,
  }) {
    return showDialog<RefundAccountInput>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RefundAccountPopup(mbId: mbId),
    );
  }

  @override
  State<RefundAccountPopup> createState() => _RefundAccountPopupState();
}

class _RefundAccountPopupState extends State<RefundAccountPopup> {
  static const Color _ink = Color(0xFF1A1A1E);
  static const Color _muted = Color(0xFF898686);
  static const Color _border = Color(0xFFD2D2D2);
  static const Color _pink = Color(0xFFFF5A8D);

  final _accountController = TextEditingController();
  final _holderController = TextEditingController();

  String _selectedBank = '';
  bool _loading = true;

  List<String> get _bankItems {
    final b = _selectedBank.trim();
    if (b.isNotEmpty && !RefundAccountPopup.bankNames.contains(b)) {
      return [b, ...RefundAccountPopup.bankNames];
    }
    return RefundAccountPopup.bankNames;
  }

  @override
  void initState() {
    super.initState();
    _loadRefundAccount();
  }

  @override
  void dispose() {
    _accountController.dispose();
    _holderController.dispose();
    super.dispose();
  }

  Future<void> _loadRefundAccount() async {
    try {
      final data = await RefundAccountService.fetch(widget.mbId);
      if (!mounted) return;
      if (data['success'] == true) {
        final bank = '${data['refundBank'] ?? data['mb_refund_bank'] ?? ''}'.trim();
        final acc = '${data['refundAccount'] ?? data['mb_refund_account'] ?? ''}'.trim();
        final holder = '${data['refundHolder'] ?? data['mb_refund_holder'] ?? ''}'.trim();
        setState(() => _selectedBank = bank);
        _accountController.text = acc;
        _holderController.text = holder;
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onCancel() => Navigator.pop(context);

  void _onConfirm() {
    if (_selectedBank.trim().isEmpty) return;
    final digits = _accountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) return;
    final holder = _holderController.text.trim();
    if (holder.isEmpty) return;
    Navigator.pop(
      context,
      RefundAccountInput(
        bank: _selectedBank.trim(),
        accountDigits: digits,
        holder: holder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final popupW = healthDp(context, 321);
    final radius = healthDp(context, 20);
    final fieldH = healthDp(context, 50);
    final padH = healthDp(context, 20);
    final padTop = healthDp(context, 20);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: healthDp(context, 27)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          width: popupW,
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
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
            child: _loading
                ? Padding(
                    padding: EdgeInsets.all(padH),
                    child: SizedBox(
                      height: healthDp(context, 200),
                      child: const Center(
                        child: CircularProgressIndicator(color: _pink),
                      ),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(padH, padTop, padH, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '환불 계좌 정보 입력',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _ink,
                                fontSize: healthSp(context, 20),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: healthDp(context, 20)),
                            _fieldBlock(
                              context,
                              label: '은행 선택',
                              child: DropdownBtn(
                                items: _bankItems,
                                value: _selectedBank,
                                emptyText: '은행을 선택하세요.',
                                buttonHeight: fieldH,
                                panelMaxHeight: healthDp(context, 280),
                                itemFontSizeBase: 12,
                                itemTextAlign: TextAlign.start,
                                itemLeadingGapBase: 8,
                                leadingBuilder: (name) => _BankIconLeading(
                                  bankName: name,
                                  size: healthDp(context, 22),
                                ),
                                onChanged: (v) => setState(() => _selectedBank = v),
                              ),
                            ),
                            SizedBox(height: healthDp(context, 20)),
                            _fieldBlock(
                              context,
                              label: '계좌번호',
                              child: _textFieldBox(
                                context,
                                height: fieldH,
                                controller: _accountController,
                                hint: '계좌번호를 입력해주세요.(-는 제외)',
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              ),
                            ),
                            SizedBox(height: healthDp(context, 20)),
                            _fieldBlock(
                              context,
                              label: '예금주명',
                              child: _textFieldBox(
                                context,
                                height: fieldH,
                                controller: _holderController,
                                hint: '예금주 이름을 입력해주세요.',
                              ),
                            ),
                            SizedBox(height: healthDp(context, 10)),
                            Text(
                              '*환불 처리를 위해 정확한 계좌정보를 입력해 주세요.',
                              style: TextStyle(
                                color: _muted,
                                fontSize: healthSp(context, 10),
                                fontWeight: FontWeight.w300,
                                height: 1.4,
                              ),
                            ),
                            SizedBox(height: healthDp(context, 10)),
                            Text(
                              '입력하신 정보가 부정확할 경우 환불이 지연되거나 처리되지 않을 수 있으며, 이에 대한 책임은 입력자 본인에게 있습니다.',
                              style: TextStyle(
                                color: _muted,
                                fontSize: healthSp(context, 10),
                                fontWeight: FontWeight.w300,
                                height: 1.4,
                              ),
                            ),
                            SizedBox(height: healthDp(context, 20)),
                          ],
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
                                  onTap: _onCancel,
                                  child: Center(
                                    child: Text(
                                      '취소',
                                      style: TextStyle(
                                        color: _muted,
                                        fontSize: healthSp(context, 16),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Material(
                                color: _pink,
                                child: InkWell(
                                  onTap: _onConfirm,
                                  child: Center(
                                    child: Text(
                                      '확인',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: healthSp(context, 16),
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

  Widget _fieldBlock(
    BuildContext context, {
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _muted,
            fontSize: healthSp(context, 14),
            fontWeight: FontWeight.w500,
            height: 1.57,
          ),
        ),
        SizedBox(height: healthDp(context, 5)),
        child,
      ],
    );
  }

  Widget _textFieldBox(
    BuildContext context, {
    required double height,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final padH = healthDp(context, 10);
    final radius = healthDp(context, 10);
    final borderW = healthDp(context, 1);

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(width: borderW, color: _border),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padH),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            expands: true,
            maxLines: null,
            textAlignVertical: TextAlignVertical.center,
            style: TextStyle(
              color: _ink,
              fontSize: healthSp(context, 12),
              fontWeight: FontWeight.w500,
              height: 1,
            ),
            decoration: InputDecoration(
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
              hintText: hint,
              hintStyle: TextStyle(
                color: _muted,
                fontSize: healthSp(context, 12),
                fontWeight: FontWeight.w300,
                height: 1,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
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
