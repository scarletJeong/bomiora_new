import 'package:flutter/material.dart';

import '../../settings/policy/legal_document_view.dart';
import '../../settings/policy/legal_documents.dart';
import 'agreement_popup_dialog.dart';

class TermsOfServicePopup extends StatelessWidget {
  const TermsOfServicePopup({super.key});

  @override
  Widget build(BuildContext context) {
    return const AgreementPopupDialog(
      title: '이용약관',
      bodyChild: LegalDocumentView(
        assetPath: LegalDocuments.terms,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
