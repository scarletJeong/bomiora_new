import 'package:flutter/material.dart';

import '../../settings/policy/legal_document_view.dart';
import '../../settings/policy/legal_documents.dart';
import 'agreement_popup_dialog.dart';

class PrivacyCollectionPopup extends StatelessWidget {
  const PrivacyCollectionPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return const AgreementPopupDialog(
      title: '개인정보 수집 및 이용',
      bodyChild: LegalDocumentView(
        assetPath: LegalDocuments.privacy,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
