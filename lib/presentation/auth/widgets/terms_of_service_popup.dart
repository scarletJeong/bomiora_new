import 'package:flutter/material.dart';

import 'agreement_popup_dialog.dart';

class TermsOfServicePopup extends StatelessWidget {
  const TermsOfServicePopup({super.key});

  @override
  Widget build(BuildContext context) {
    return const AgreementPopupDialog(
      title: '이용약관',
      subtitle: '이용약관',
      body: '이용약관 내용은 추후 제공 예정입니다.',
    );
  }
}
