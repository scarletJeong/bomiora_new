import 'package:flutter/material.dart';

import '../../settings/policy/policy_texts.dart';
import 'agreement_popup_dialog.dart';

class TermsOfServicePopup extends StatelessWidget {
  const TermsOfServicePopup({super.key});

  @override
  Widget build(BuildContext context) {
    return AgreementPopupDialog(
      title: '이용약관',
      subtitle: PolicyTexts.termsHeading,
      body: PolicyTexts.popupBody(sections: PolicyTexts.termsSections),
    );
  }
}
