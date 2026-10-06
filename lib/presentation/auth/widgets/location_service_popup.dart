import 'package:flutter/material.dart';

import '../../settings/policy/legal_document_view.dart';
import '../../settings/policy/legal_documents.dart';
import 'agreement_popup_dialog.dart';

class LocationServicePopup extends StatelessWidget {
  const LocationServicePopup({super.key});

  @override
  Widget build(BuildContext context) {
    return const AgreementPopupDialog(
      title: '위치기반서비스 이용약관',
      bodyChild: LegalDocumentView(
        assetPath: LegalDocuments.location,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
