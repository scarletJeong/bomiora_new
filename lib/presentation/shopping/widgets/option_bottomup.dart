import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/models/product/product_model.dart';
import '../../../data/models/product/product_option_model.dart';
import 'option_selector.dart';

Future<void> showProductOptionBottomup({
  required BuildContext context,
  required Product product,
  required List<ProductOption> options,
  required Map<ProductOption, int> selectedOptions,
  required int? userPoint,
  required void Function(Map<ProductOption, int>) onOptionsChanged,
  required VoidCallback onAddToCart,
  required VoidCallback onReserve,
  required VoidCallback onBuyNow,
  required FutureOr<void> Function() onNoOptionGeneral,
  required FutureOr<void> Function() onNoOptionPrescription,
}) async {
  if (options.isEmpty) {
    if (product.ctKind == 'general') {
      await onNoOptionGeneral();
    } else {
      await onNoOptionPrescription();
    }
    return;
  }

  final optionSubject =
      product.additionalInfo?['it_option_subject']?.toString() ?? '';
  final subjectLabels = optionSubject
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  String stepLabel = '다이어트환 단계';
  String monthsLabel = '처방 개월수';
  if (subjectLabels.length >= 2) {
    stepLabel = subjectLabels[0];
    monthsLabel = subjectLabels[1];
  } else if (subjectLabels.length == 1) {
    final only = subjectLabels.first;
    if (only.contains('개월')) {
      monthsLabel = only;
    } else if (only.contains('단계')) {
      stepLabel = only;
    } else {
      stepLabel = only;
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(50),
        topRight: Radius.circular(50),
      ),
    ),
    builder: (context) {
      final screenWidth = MediaQuery.of(context).size.width;
      final constrainedWidth = math.min(screenWidth - 12, 600.0);
      return Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constrainedWidth),
          child: OptionSelectorBottomSheet(
            options: options,
            selectedOptions: selectedOptions,
            basePrice: product.price,
            stepLabel: stepLabel,
            monthsLabel: monthsLabel,
            userPoint: userPoint,
            productKind: product.productKind ??
                product.additionalInfo?['it_kind']?.toString(),
            onOptionsChanged: onOptionsChanged,
            onAddToCart: onAddToCart,
            onReserve: onReserve,
            onBuyNow: onBuyNow,
          ),
        ),
      );
    },
  );
}
