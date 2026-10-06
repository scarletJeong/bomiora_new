import 'package:flutter/material.dart';

import '../../settings/policy/legal_document_view.dart';
import '../../settings/policy/legal_documents.dart';
import 'agreement_popup_dialog.dart';

class MarketingConsentPopup extends StatelessWidget {
  const MarketingConsentPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return const AgreementPopupDialog(
      title: '마케팅 및 광고 활용 동의',
      bodyChild: LegalDocumentView(
        assetPath: LegalDocuments.marketing,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
