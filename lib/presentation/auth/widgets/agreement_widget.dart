import 'package:flutter/material.dart';

import 'location_service_popup.dart';
import 'marketing_consent_popup.dart';
import 'privacy_collection_popup.dart';
import 'terms_of_service_popup.dart';

enum AgreementPopupType {
  terms,
  privacy,
  location,
  marketing,
}

class AgreementWidget extends StatefulWidget {
  final bool isLoading;
  final ValueChanged<Map<String, bool>> onNext;

  const AgreementWidget({
    super.key,
    required this.onNext,
    this.isLoading = false,
  });

  @override
  State<AgreementWidget> createState() => _AgreementWidgetState();
}

class _AgreementWidgetState extends State<AgreementWidget> {
  bool _terms = false;
  bool _privacy = false;
  bool _location = false;
  bool _marketing = false;
  bool _marketingEmail = false;
  bool _marketingSms = false;

  bool get _allChecked =>
      _terms &&
      _privacy &&
      _location &&
      _marketing &&
      _marketingEmail &&
      _marketingSms;

  bool get _canProceed => _terms && _privacy;

  Map<String, bool> get _agreements => {
        'terms': _terms,
        'privacy': _privacy,
        'location': _location,
        'marketing': _marketing,
        'marketingEmail': _marketing && _marketingEmail,
        'marketingSms': _marketing && _marketingSms,
      };

  void _toggleAll(bool value) {
    setState(() {
      _terms = value;
      _privacy = value;
      _location = value;
      _marketing = value;
      _marketingEmail = value;
      _marketingSms = value;
    });
  }

  void _toggleMarketing(bool value) {
    setState(() {
      _marketing = value;
      if (!value) {
        _marketingEmail = false;
        _marketingSms = false;
      }
    });
  }

  void _toggleMarketingDetail(bool isEmail, bool value) {
    setState(() {
      if (!_marketing && value) {
        _marketing = true;
      }

      if (isEmail) {
        _marketingEmail = value;
      } else {
        _marketingSms = value;
      }

      if (!_marketingEmail && !_marketingSms) {
        _marketing = false;
      }
    });
  }

  Future<void> _showAgreementPopup(AgreementPopupType type) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        switch (type) {
          case AgreementPopupType.terms:
            return const TermsOfServicePopup();
          case AgreementPopupType.privacy:
            return const PrivacyCollectionPopup();
          case AgreementPopupType.location:
            return const LocationServicePopup();
          case AgreementPopupType.marketing:
            return const MarketingConsentPopup();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const captionStyle = TextStyle(
      color: Color(0xFF898686),
      fontSize: 14,
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w300,
    );

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '약관동의',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text('약관에 동의해주세요.', style: captionStyle),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      decoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _AgreementRow(
                        value: _allChecked,
                        title: '약관 전체 동의',
                        titleStyle: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                        ),
                        onChanged: _toggleAll,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: ShapeDecoration(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(
                            width: 1,
                            color: Color(0xFFD2D2D2),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AgreementTableRow(
                            value: _terms,
                            requiredLabel: '[필수]',
                            title: '이용약관',
                            popupType: AgreementPopupType.terms,
                            onChanged: (value) => setState(() => _terms = value),
                            onViewPressed: _showAgreementPopup,
                          ),
                          _AgreementTableRow(
                            value: _privacy,
                            requiredLabel: '[필수]',
                            title: '개인정보 수집 및 이용',
                            popupType: AgreementPopupType.privacy,
                            onChanged: (value) => setState(() => _privacy = value),
                            onViewPressed: _showAgreementPopup,
                          ),
                          _AgreementTableRow(
                            value: _location,
                            requiredLabel: '[선택]',
                            title: '위치기반서비스 이용약관',
                            popupType: AgreementPopupType.location,
                            onChanged: (value) => setState(() => _location = value),
                            onViewPressed: _showAgreementPopup,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _AgreementTableRow(
                                  value: _marketing,
                                  requiredLabel: '[선택]',
                                  title: '마케팅 및 광고 활용 동의',
                                  popupType: AgreementPopupType.marketing,
                                  showDivider: false,
                                  onChanged: _toggleMarketing,
                                  onViewPressed: _showAgreementPopup,
                                ),
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.only(left: 24),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _NestedAgreementOption(
                                          value: _marketingEmail,
                                          label: '이메일 수신',
                                          onChanged: (value) => _toggleMarketingDetail(true, value),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _NestedAgreementOption(
                                          value: _marketingSms,
                                          label: 'SNS 수신',
                                          onChanged: (value) => _toggleMarketingDetail(false, value),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: ElevatedButton(
            onPressed: !_canProceed || widget.isLoading
                ? null
                : () => widget.onNext(_agreements),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor:
                  _canProceed ? const Color(0xFFFF5A8D) : const Color(0xFFD2D2D2),
              disabledBackgroundColor: const Color(0xFFD2D2D2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: widget.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    '다음',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _AgreementRow extends StatelessWidget {
  final bool value;
  final String title;
  final TextStyle titleStyle;
  final ValueChanged<bool> onChanged;

  const _AgreementRow({
    required this.value,
    required this.title,
    required this.titleStyle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          _CheckboxBox(value: value, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: titleStyle)),
        ],
      ),
    );
  }
}

class _AgreementTableRow extends StatelessWidget {
  final bool value;
  final String requiredLabel;
  final String title;
  final bool showDivider;
  final AgreementPopupType popupType;
  final ValueChanged<bool> onChanged;
  final ValueChanged<AgreementPopupType> onViewPressed;

  const _AgreementTableRow({
    required this.value,
    required this.requiredLabel,
    required this.title,
    required this.popupType,
    required this.onChanged,
    required this.onViewPressed,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  width: 0.5,
                  color: Color(0xFFD2D2D2),
                ),
              ),
            )
          : null,
      child: Row(
        children: [
          InkWell(
            onTap: () => onChanged(!value),
            child: _CheckboxBox(value: value, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(!value),
                    child: Row(
                      children: [
                        Text(
                          requiredLabel,
                          style: const TextStyle(
                            color: Color(0xFF898686),
                            fontSize: 12,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => onViewPressed(popupType),
                  child: const Text(
                    '보기',
                    style: TextStyle(
                      color: Color(0xFF898686),
                      fontSize: 12,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NestedAgreementOption extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  const _NestedAgreementOption({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          _CheckboxBox(value: value, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckboxBox extends StatelessWidget {
  final bool value;
  final double size;

  const _CheckboxBox({
    required this.value,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: value ? const Color(0xFFFF5A8D) : Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: 1,
            color: value ? const Color(0xFFFF5A8D) : const Color(0xFFD2D2D2),
          ),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      child: value
          ? Icon(
              Icons.check,
              size: size - 5,
              color: Colors.white,
            )
          : null,
    );
  }
}
