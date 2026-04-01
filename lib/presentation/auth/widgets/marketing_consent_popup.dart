import 'package:flutter/material.dart';

import 'agreement_popup_dialog.dart';

class MarketingConsentPopup extends StatelessWidget {
  const MarketingConsentPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return const AgreementPopupDialog(
      title: '마케팅 및 광고 활용 동의',
      subtitle: '마케팅 및 광고 활용 동의',
      body: '마케팅 및 광고 활용 동의 약관 내용은 추후 제공 예정입니다.',
    );
  }
}
