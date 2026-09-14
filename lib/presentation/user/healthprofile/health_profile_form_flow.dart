import 'package:flutter/material.dart';

import 'health_profile_common.dart';
import 'health_profile_prescription_booking_args.dart';
import 'models/health_profile_model.dart';
import 'screens/health_profile_form_screen.dart';

/// 문진표 작성 진입. 전체 작성은 1페이지, 섹션 수정은 해당 페이지로 엽니다.
abstract final class HealthProfileFormFlow {
  HealthProfileFormFlow._();

  static const String routeName = HealthProfileFormCommon.formRouteName;

  static Widget start({
    HealthProfileModel? existingProfile,
    List<int>? initialSectionIndices,
    String? editScreenTitle,
    int? initialWizardIndex,
    HealthProfilePrescriptionBookingArgs? prescriptionBooking,
  }) {
    final page = HealthProfileFormCommon.startPageIndex(
      initialSectionIndices: initialSectionIndices,
      initialWizardIndex: initialWizardIndex,
    );
    switch (page) {
      case 1:
        return HealthProfileForm2Screen(
          existingProfile: existingProfile,
          initialSectionIndices: initialSectionIndices,
          editScreenTitle: editScreenTitle,
          prescriptionBooking: prescriptionBooking,
        );
      case 2:
        return HealthProfileForm3Screen(
          existingProfile: existingProfile,
          initialSectionIndices: initialSectionIndices,
          editScreenTitle: editScreenTitle,
          prescriptionBooking: prescriptionBooking,
        );
      case 3:
        return HealthProfileForm4Screen(
          existingProfile: existingProfile,
          initialSectionIndices: initialSectionIndices,
          editScreenTitle: editScreenTitle,
          prescriptionBooking: prescriptionBooking,
        );
      default:
        return HealthProfileForm1Screen(
          existingProfile: existingProfile,
          initialSectionIndices: initialSectionIndices,
          editScreenTitle: editScreenTitle,
          prescriptionBooking: prescriptionBooking,
        );
    }
  }

  static Future<T?> open<T>(
    BuildContext context, {
    HealthProfileModel? existingProfile,
    List<int>? initialSectionIndices,
    String? editScreenTitle,
    int? initialWizardIndex,
    HealthProfilePrescriptionBookingArgs? prescriptionBooking,
  }) {
    final page = HealthProfileFormCommon.startPageIndex(
      initialSectionIndices: initialSectionIndices,
      initialWizardIndex: initialWizardIndex,
    );
    return Navigator.push<T>(
      context,
      MaterialPageRoute<T>(
        settings: RouteSettings(
          name: HealthProfileFormCommon.formPageRouteNames[page],
        ),
        builder: (_) => start(
          existingProfile: existingProfile,
          initialSectionIndices: initialSectionIndices,
          editScreenTitle: editScreenTitle,
          initialWizardIndex: initialWizardIndex,
          prescriptionBooking: prescriptionBooking,
        ),
      ),
    );
  }
}

/// 이전 진입점. 새 코드는 [HealthProfileForm1Screen] 또는 [HealthProfileFormFlow]를 사용합니다.
class HealthProfileFormScreen extends StatelessWidget {
  static const String routeName = HealthProfileFormFlow.routeName;

  const HealthProfileFormScreen({
    super.key,
    this.existingProfile,
    this.initialSectionIndices,
    this.editScreenTitle,
    this.initialWizardIndex,
    this.prescriptionBooking,
  });

  final HealthProfileModel? existingProfile;
  final List<int>? initialSectionIndices;
  final String? editScreenTitle;
  final int? initialWizardIndex;
  final HealthProfilePrescriptionBookingArgs? prescriptionBooking;

  @override
  Widget build(BuildContext context) {
    return HealthProfileFormFlow.start(
      existingProfile: existingProfile,
      initialSectionIndices: initialSectionIndices,
      editScreenTitle: editScreenTitle,
      initialWizardIndex: initialWizardIndex,
      prescriptionBooking: prescriptionBooking,
    );
  }
}
