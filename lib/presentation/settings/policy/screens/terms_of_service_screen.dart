import 'package:flutter/material.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../policy_texts.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(
        title: '서비스 이용약관',
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(healthDp(context, 20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              PolicyTexts.termsHeading,
              style: TextStyle(
                fontSize: healthSp(context, 14),
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: healthDp(context, 24)),
            for (final section in PolicyTexts.termsSections)
              _buildSection(context, section.title, section.body),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: EdgeInsets.only(bottom: healthDp(context, 24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: healthSp(context, 10),
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: healthDp(context, 8)),
          Text(
            content,
            style: TextStyle(
              fontSize: healthSp(context, 8),
              color: Colors.black87,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
