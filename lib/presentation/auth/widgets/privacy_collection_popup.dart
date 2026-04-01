import 'package:flutter/material.dart';

import 'agreement_popup_dialog.dart';

class PrivacyCollectionPopup extends StatelessWidget {
  const PrivacyCollectionPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return const AgreementPopupDialog(
      title: '개인정보 수집 및 이용',
      subtitle: '개인정보 수집 및 이용',
      body: '개인정보 수집 및 이용 약관 내용은 추후 제공 예정입니다.',
    );
  }
}
