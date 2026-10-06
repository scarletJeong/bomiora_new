import 'package:flutter/material.dart';

import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../legal_document_view.dart';
import '../legal_documents.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MobileAppLayoutWrapper(
      appBar: HealthAppBar(
        title: '개인정보 처리방침',
      ),
      child: LegalDocumentView(assetPath: LegalDocuments.privacy),
    );
  }
}
