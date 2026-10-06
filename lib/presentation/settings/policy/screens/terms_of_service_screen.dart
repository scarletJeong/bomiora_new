import 'package:flutter/material.dart';

import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../legal_document_view.dart';
import '../legal_documents.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MobileAppLayoutWrapper(
      appBar: HealthAppBar(
        title: '서비스 이용약관',
      ),
      child: LegalDocumentView(assetPath: LegalDocuments.terms),
    );
  }
}
