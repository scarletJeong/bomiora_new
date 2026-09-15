import 'package:flutter/material.dart';

import '../../settings/policy/policy_texts.dart';
import 'agreement_popup_dialog.dart';

class PrivacyCollectionPopup extends StatelessWidget {
  const PrivacyCollectionPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return AgreementPopupDialog(
      title: '개인정보 수집 및 이용',
      subtitle: PolicyTexts.privacyHeading,
      body: PolicyTexts.popupBody(
        sections: PolicyTexts.privacySections,
        intros: PolicyTexts.privacyIntros,
      ),
    );
  }
}
