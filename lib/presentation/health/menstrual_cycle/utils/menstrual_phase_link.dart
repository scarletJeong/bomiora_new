import 'package:flutter/material.dart';

import '../../../../data/models/health/menstrual_cycle/menstrual_cycle_model.dart';
import '../../../shopping/utils/get_product.dart';
import '../../dashboard/screens/health_goal_screen.dart';
import '../../food/screens/food_list_screen.dart';

void navigateMenstrualPhaseLink(
  BuildContext context,
  MenstrualPhaseLinkTarget target,
) {
  switch (target) {
    case MenstrualPhaseLinkTarget.none:
      return;
    case MenstrualPhaseLinkTarget.generalDietProducts:
      Navigator.pushNamed(
        context,
        '/product-general/',
        arguments: const {
          'categoryId': '90',
          'categoryName': '다이어트 제품',
          'productKind': 'general',
        },
      );
    case MenstrualPhaseLinkTarget.prescriptionDietProducts:
      Navigator.pushNamed(
        context,
        '/product/',
        arguments: prescriptionDietProductListArguments(),
      );
    case MenstrualPhaseLinkTarget.prescriptionDetoxProducts:
      Navigator.pushNamed(
        context,
        '/product/',
        arguments: const {
          'categoryId': '20',
          'categoryName': '디톡스환',
          'productKind': 'prescription',
        },
      );
    case MenstrualPhaseLinkTarget.prescriptionCalmProducts:
      Navigator.pushNamed(
        context,
        '/product/',
        arguments: const {
          'categoryId': '80',
          'categoryName': '심신안정환',
          'productKind': 'prescription',
        },
      );
    case MenstrualPhaseLinkTarget.healthGoal:
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (context) => const HealthGoalScreen(),
        ),
      );
    case MenstrualPhaseLinkTarget.mealRecord:
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (context) => const TodayDietScreen(),
        ),
      );
  }
}
