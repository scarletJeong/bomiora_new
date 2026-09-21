import 'package:flutter/material.dart';

import '../../../../data/services/health_profile_service.dart';
import '../../../common/widgets/app_toast_overlay.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../../../shopping/screens/prescription_booking/prescription_time_screen.dart';
import '../../../shopping/widgets/prescription_booking_progress_bar.dart';
import '../models/health_profile_model.dart';
import 'health_profile_common.dart';
import 'health_profile_form_session.dart';
import 'health_profile_payload.dart';
import 'health_profile_questionnaire_options.dart';

/// 문진표 1~4 공통 UI (히어로 · 하단바 · 칩 · 질문 블록).
abstract final class HealthProfileFormUi {
  HealthProfileFormUi._();

  static void popAllFormRoutes(BuildContext context) {
    Navigator.of(context).popUntil((route) {
      if (route.isFirst) return true;
      return !HealthProfileFormCommon.isFormRouteName(route.settings.name);
    });
  }

  static Future<void> submit({
    required BuildContext context,
    required HealthProfileFormSession session,
    required GlobalKey<FormState> formKey,
  }) async {
    if (!session.isAllWizardStepsFilled()) {
      AppToastOverlay.show(context, '모든 문진표를 작성해야합니다');
      formKey.currentState?.validate();
      return;
    }
    if (formKey.currentState?.validate() != true) return;
    formKey.currentState?.save();

    session.isLoading = true;
    session.touch();
    try {
      await session.saveHealthProfile();
      if (!context.mounted) return;

      final booking = session.prescriptionBooking;
      if (booking != null) {
        final profile = await HealthProfileService.getHealthProfile(
          session.currentUser!.id,
        );
        if (!context.mounted) return;
        final navigator = Navigator.of(context);
        navigator.popUntil((route) {
          if (route.isFirst) return true;
          return !HealthProfileFormCommon.isFormRouteName(route.settings.name);
        });
        navigator.push(
          MaterialPageRoute<void>(
            builder: (context) => PrescriptionTimeScreen(
              productId: booking.productId,
              productName: booking.productName,
              selectedOptions: booking.selectedOptions,
              formData: profile != null
                  ? HealthProfilePayload.formDataFromProfile(profile)
                  : Map<String, dynamic>.from(session.formData),
              existingProfile: profile,
              cartCtIdsForCheckout: booking.cartCtIdsForCheckout,
              checkoutCartItems: booking.checkoutCartItems,
              checkoutShippingCost: booking.checkoutShippingCost,
            ),
          ),
        );
        return;
      }

      AppToastOverlay.show(context, '문진표를 수정하였습니다');
      if (Navigator.of(context).canPop()) {
        popAllFormRoutes(context);
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/profile',
          (route) => false,
        );
      }
    } catch (_) {
    } finally {
      if (context.mounted) {
        session.isLoading = false;
        session.touch();
      }
    }
  }
}

class HealthProfileFormFrame extends StatelessWidget {
  const HealthProfileFormFrame({
    super.key,
    required this.session,
    required this.pageIndex,
    required this.isSectionEdit,
    required this.child,
    this.editScreenTitle,
    this.pinnedBottom,
  });

  final HealthProfileFormSession session;
  final int pageIndex;
  final bool isSectionEdit;
  final Widget child;
  final String? editScreenTitle;
  final Widget? pinnedBottom;

  @override
  Widget build(BuildContext context) {
    final sectionTitle = pageIndex >= 0 && pageIndex < session.sections.length
        ? session.sections[pageIndex].title
        : '';
    final appBarEditTitle = editScreenTitle ?? sectionTitle;
    final isPrescriptionBooking = session.prescriptionBooking != null;
    final stepCount = session.sections.isEmpty ? 4 : session.sections.length;
    final wizardStepProgress =
        stepCount <= 0 ? 0.0 : (pageIndex / stepCount).clamp(0.0, 1.0);

    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        HealthProfileFormUi.popAllFormRoutes(context);
      },
      child: Theme(
        data: gmarketTheme,
        child: MobileAppLayoutWrapper(
          appBar: HealthAppBar(
            title: isPrescriptionBooking
                ? '진료 예약 중 _ 01 문진표'
                : (isSectionEdit ? '$appBarEditTitle 수정' : '문진표 작성하기'),
            leadingIconSize: healthDp(context, 24),
            onBack: () => HealthProfileFormUi.popAllFormRoutes(context),
            bottom: isPrescriptionBooking
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(
                      PrescriptionBookingProgressBar.preferredHeight,
                    ),
                    child: PrescriptionBookingProgressBar(
                      currentStep: PrescriptionBookingSteps.questionnaire,
                      stepProgress: wizardStepProgress,
                    ),
                  )
                : null,
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
            child: session.currentUser == null
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF3787)),
                  )
                : ColoredBox(
                    color: Colors.white,
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            Expanded(child: child),
                            if (pinnedBottom != null) pinnedBottom!,
                          ],
                        ),
                        if (session.isLoading)
                          const Positioned.fill(
                            child: ColoredBox(
                              color: Color(0x33000000),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFFF3787),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class HealthProfileWizardHero extends StatelessWidget {
  const HealthProfileWizardHero({
    super.key,
    required this.session,
    required this.stepIndex,
  });

  final HealthProfileFormSession session;
  final int stepIndex;

  @override
  Widget build(BuildContext context) {
    final name = (session.currentUser?.name.trim().isNotEmpty ?? false)
        ? session.currentUser!.name.trim()
        : '회원';
    final total = session.sections.length;
    final step = stepIndex + 1;

    final (String emphasis, String prefix, String suffix) = switch (stepIndex) {
      0 => ('기본정보', '님의 맞춤 처방을 위해\n', '를 입력해 주세요'),
      1 => ('식습관', '님의 ', '을 체크해볼게요.'),
      2 => ('운동습관', '님의 ', '을 체크해볼게요.'),
      _ => ('건강상태', '님의 ', '를 체크해볼게요.'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 14),
            vertical: healthDp(context, 4),
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(healthDp(context, 9999)),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$step',
                  style: TextStyle(
                    color: const Color(0xFF0F172A),
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1.43,
                  ),
                ),
                TextSpan(
                  text: '/$total',
                  style: TextStyle(
                    color: const Color(0xFF898686),
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1.43,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: healthDp(context, 10)),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: name,
                style: TextStyle(
                  color: const Color(0xFF0F172A),
                  fontSize: healthSp(context, 22),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  letterSpacing: healthSp(context, -2),
                ),
              ),
              TextSpan(
                text: prefix,
                style: TextStyle(
                  color: const Color(0xFF0F172A),
                  fontSize: healthSp(context, 22),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                  letterSpacing: healthSp(context, -2),
                ),
              ),
              TextSpan(
                text: emphasis,
                style: TextStyle(
                  color: const Color(0xFF0F172A),
                  fontSize: healthSp(context, 22),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  letterSpacing: healthSp(context, -2),
                ),
              ),
              TextSpan(
                text: suffix,
                style: TextStyle(
                  color: const Color(0xFF0F172A),
                  fontSize: healthSp(context, 22),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                  letterSpacing: healthSp(context, -2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class HealthProfileWizardBottomBar extends StatelessWidget {
  const HealthProfileWizardBottomBar({
    super.key,
    required this.session,
    required this.pageIndex,
    required this.onNext,
    required this.onPrevious,
    required this.onSubmit,
  });

  final HealthProfileFormSession session;
  final int pageIndex;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final last = pageIndex >= session.sections.length - 1;
    final stepFilled = session.isWizardStepFilled(pageIndex);
    final canProceed = last ? session.isAllWizardStepsFilled() : stepFilled;
    return Row(
      children: [
        if (pageIndex > 0) ...[
          SizedBox(
            width: healthDp(context, 45),
            height: healthDp(context, 45),
            child: OutlinedButton(
              onPressed: session.isLoading ? null : onPrevious,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                side: BorderSide(
                    width: healthDp(context, 1),
                    color: const Color(0x7FD2D2D2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 8)),
                ),
              ),
              child: Icon(
                Icons.chevron_left,
                color: const Color(0xFF898686),
                size: healthDp(context, 22),
              ),
            ),
          ),
          SizedBox(width: healthDp(context, 10)),
        ],
        Expanded(
          child: SizedBox(
            height: healthDp(context, 45),
            child: FilledButton(
              onPressed: session.isLoading
                  ? null
                  : () {
                      if (!canProceed) {
                        AppToastOverlay.show(
                          context,
                          '모든 문진표를 작성해야합니다',
                        );
                        return;
                      }
                      if (last) {
                        onSubmit();
                      } else {
                        onNext();
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: canProceed
                    ? const Color(0xFFFF5A8D)
                    : const Color(0xFFD2D2D2),
                disabledBackgroundColor: const Color(0xFFD2D2D2),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                ),
              ),
              child: Text(
                last ? '제출하기' : '다음',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: healthSp(context, 16),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class HealthProfileSectionSubmitBar extends StatelessWidget {
  const HealthProfileSectionSubmitBar({
    super.key,
    required this.session,
    required this.onSubmit,
  });

  final HealthProfileFormSession session;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 20),
        healthDp(context, 4),
        healthDp(context, 20),
        healthDp(context, 20),
      ),
      child: SizedBox(
        width: double.infinity,
        height: healthDp(context, 40),
        child: ElevatedButton(
          onPressed: session.isLoading ? null : onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF3787),
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            minimumSize: Size(double.infinity, healthDp(context, 40)),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
            ),
          ),
          child: Text(
            '수정하기',
            style: TextStyle(
              fontSize: healthSp(context, 16),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class HealthProfileOptionChip extends StatelessWidget {
  const HealthProfileOptionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.stretchWidth = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool stretchWidth;

  int _chipCharCount(String text) =>
      text.replaceAll(RegExp(r'\s'), '').replaceAll('\n', '').length;

  @override
  Widget build(BuildContext context) {
    final display = HealthProfileFormCommon.normalizeChipOptionLabel(label);
    final isSaladDiet = display == '샐러드/다이어트식단';
    final isLateNight = display.contains('야식');
    final isCaffeine = display.contains('카페인');
    final chars = _chipCharCount(display);
    final fixedShort = !stretchWidth && !isSaladDiet && chars <= 3;
    final fixedFour = !stretchWidth && !isSaladDiet && chars == 4;
    final fixedWidth = fixedShort || fixedFour;
    final hPad = healthDp(
      context,
      isSaladDiet
          ? 14
          : (fixedWidth
              ? 6
              : (isLateNight
                  ? 2
                  : (isCaffeine
                      ? 6
                      : (stretchWidth
                          ? 4
                          : (chars == 5 ? 14 : (chars < 5 ? 6 : 14)))))),
    );

    final text = Text(
      display,
      textAlign: TextAlign.center,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        color: selected ? const Color(0xFF1A1A1E) : const Color(0xFF898383),
        fontSize: healthSp(context, 14),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w500,
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: stretchWidth
            ? double.infinity
            : (fixedShort
                ? healthDp(context, 71)
                : (fixedFour ? healthDp(context, 82) : null)),
        height: healthDp(context, 45),
        padding: EdgeInsets.symmetric(horizontal: hPad),
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: selected ? const Color(0x0CFF5A8D) : Colors.transparent,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: healthDp(context, 1),
              color: selected
                  ? const Color(0xFFFF5A8D)
                  : HealthProfileFormCommon.border,
            ),
            borderRadius: BorderRadius.circular(
              healthDp(context, selected ? 36 : 50),
            ),
          ),
        ),
        child: stretchWidth || fixedWidth
            ? FittedBox(fit: BoxFit.scaleDown, child: text)
            : text,
      ),
    );
  }
}

class HealthProfileQuestionGrid extends StatelessWidget {
  const HealthProfileQuestionGrid({
    super.key,
    required this.session,
    required this.question,
  });

  final HealthProfileFormSession session;
  final HealthProfileQuestion question;

  @override
  Widget build(BuildContext context) {
    final options = question.options ?? [];
    var gridOptions = List<String>.from(options);
    String? fullWidthNoneLabel;
    for (final candidate in const ['해당 없음', '해당없음', '없음']) {
      final hit = gridOptions.firstWhere(
        (e) => e.trim() == candidate,
        orElse: () => '',
      );
      if (hit.isNotEmpty) {
        fullWidthNoneLabel = hit;
        gridOptions.remove(hit);
        break;
      }
    }

    Widget chip(String opt, {bool stretch = false}) {
      return HealthProfileOptionChip(
        label: opt,
        selected: session.isGridOptionSelected(question, opt),
        onTap: () => session.toggleGridOption(question, opt),
        stretchWidth: stretch,
      );
    }

    Widget pairedChipRows() {
      final rows = <Widget>[];
      for (var i = 0; i < gridOptions.length; i += 2) {
        if (i > 0) rows.add(SizedBox(height: healthDp(context, 8)));
        final left = gridOptions[i];
        final hasRight = i + 1 < gridOptions.length;
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(child: chip(left, stretch: true)),
              if (hasRight) ...[
                SizedBox(width: healthDp(context, 6)),
                Flexible(child: chip(gridOptions[i + 1], stretch: true)),
              ],
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      );
    }

    List<List<String>>? presetRows;
    if (question.id == 'answer_9') {
      presetRows = HealthProfileQuestionnaireOptions.foodPreferenceRows;
    } else if (question.id == 'answer_10') {
      presetRows = HealthProfileQuestionnaireOptions.exerciseFrequencyRows;
    } else if (question.id == 'answer_10_types') {
      presetRows = HealthProfileQuestionnaireOptions.exerciseTypeRows;
    } else if (question.id == 'answer_11') {
      presetRows = HealthProfileQuestionnaireOptions.diseaseRows;
    } else if (question.id == 'answer_12') {
      presetRows = HealthProfileQuestionnaireOptions.medicationRows;
    }

    Widget buildPresetChipRows(List<List<String>> rows) {
      final available = gridOptions.toSet();
      final widgets = <Widget>[];
      for (final row in rows) {
        final opts = row.where(available.contains).toList();
        if (opts.isEmpty) continue;
        if (widgets.isNotEmpty) {
          widgets.add(SizedBox(height: healthDp(context, 8)));
        }
        widgets.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < opts.length; i++) ...[
                if (i > 0) SizedBox(width: healthDp(context, 8)),
                chip(opts[i]),
              ],
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (question.id == 'answer_7')
          Row(
            children: [
              for (var i = 0; i < gridOptions.length; i++) ...[
                if (i > 0) SizedBox(width: healthDp(context, 8)),
                Expanded(child: chip(gridOptions[i], stretch: true)),
              ],
            ],
          )
        else if (question.id == 'answer_8')
          pairedChipRows()
        else if (presetRows != null)
          buildPresetChipRows(presetRows)
        else
          Wrap(
            spacing: healthDp(context, 8),
            runSpacing: healthDp(context, 8),
            children: [
              for (final opt in gridOptions) chip(opt),
            ],
          ),
        if (fullWidthNoneLabel != null) ...[
          SizedBox(height: healthDp(context, 8)),
          chip(fullWidthNoneLabel, stretch: true),
        ],
        if (question.id == 'answer_10_types' &&
            session.isExerciseOtherSelected()) ...[
          SizedBox(height: healthDp(context, 10)),
          HealthProfileOtherExerciseCard(session: session),
        ],
      ],
    );
  }
}

class HealthProfileQuestionBlock extends StatelessWidget {
  const HealthProfileQuestionBlock({
    super.key,
    required this.session,
    required this.question,
    required this.stepIndex,
    this.basicInfo,
    this.mealtime,
    this.yesNo,
  });

  final HealthProfileFormSession session;
  final HealthProfileQuestion question;
  final int stepIndex;
  final Widget? basicInfo;
  final Widget? mealtime;
  final Widget? yesNo;

  bool get _showCaption {
    if (question.type == 'wizard_basic') return false;
    if (question.id == 'answer_12_other') return false;
    return true;
  }

  Widget _input() {
    switch (question.type) {
      case 'wizard_basic':
      case 'birthdate':
        return basicInfo ?? const SizedBox.shrink();
      case 'radio':
        if (question.id == 'answer_2') return const SizedBox.shrink();
        if (question.id == 'answer_13') {
          return yesNo ?? const SizedBox.shrink();
        }
        return const SizedBox.shrink();
      case 'mealtime':
        return mealtime ?? const SizedBox.shrink();
      case 'grid':
        return HealthProfileQuestionGrid(
          session: session,
          question: question,
        );
      case 'text':
        if (question.id == 'answer_12_other') {
          return HealthProfileOtherMedicationCard(session: session);
        }
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    const hintInlineIds = <String>{
      'answer_12',
      'answer_10_types',
      'answer_8',
      'answer_9',
      'answer_11',
    };
    final showInlineMultipleHint =
        question.allowMultiple && hintInlineIds.contains(question.id);

    return Padding(
      padding: EdgeInsets.only(bottom: healthDp(context, 4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showCaption && question.type != 'mealtime') ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  question.question,
                  style: TextStyle(
                    color: const Color(0xFF1A1A1E),
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                if (showInlineMultipleHint) ...[
                  SizedBox(width: healthDp(context, 10)),
                  Text(
                    '*중복선택가능',
                    style: HealthProfileFormCommon.multiHintStyle(context),
                  ),
                ],
              ],
            ),
            SizedBox(height: healthDp(context, 10)),
          ],
          if (question.type == 'mealtime') ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '식사시간',
                  style: TextStyle(
                    color: const Color(0xFF1A1A1E),
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                SizedBox(width: healthDp(context, 10)),
                Text(
                  '*해당되는 입력란에만 입력하세요',
                  style: HealthProfileFormCommon.multiHintStyle(context),
                ),
              ],
            ),
            SizedBox(height: healthDp(context, 10)),
          ],
          _input(),
        ],
      ),
    );
  }
}

class HealthProfileQuestionsColumn extends StatelessWidget {
  const HealthProfileQuestionsColumn({
    super.key,
    required this.session,
    required this.stepIndex,
    this.basicInfo,
    this.mealtime,
    this.yesNo,
  });

  final HealthProfileFormSession session;
  final int stepIndex;
  final Widget? basicInfo;
  final Widget? mealtime;
  final Widget? yesNo;

  @override
  Widget build(BuildContext context) {
    final section = session.sections[stepIndex];
    final visible =
        section.questions.where(session.shouldShowQuestion).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          HealthProfileQuestionBlock(
            session: session,
            question: visible[i],
            stepIndex: stepIndex,
            basicInfo: basicInfo,
            mealtime: mealtime,
            yesNo: yesNo,
          ),
          if (i < visible.length - 1) SizedBox(height: healthDp(context, 20)),
        ],
      ],
    );
  }
}

class HealthProfileStepScroll extends StatelessWidget {
  const HealthProfileStepScroll({
    super.key,
    required this.session,
    required this.pageIndex,
    required this.showHero,
    required this.showBottomBar,
    required this.questions,
    this.onNext,
    this.onPrevious,
    this.onSubmit,
  });

  final HealthProfileFormSession session;
  final int pageIndex;
  final bool showHero;
  final bool showBottomBar;
  final Widget questions;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 20),
        healthDp(context, 10),
        healthDp(context, 20),
        healthDp(context, 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHero) ...[
            HealthProfileWizardHero(session: session, stepIndex: pageIndex),
            SizedBox(height: healthDp(context, 30)),
          ],
          questions,
          if (showBottomBar) ...[
            SizedBox(height: healthDp(context, 24)),
            HealthProfileWizardBottomBar(
              session: session,
              pageIndex: pageIndex,
              onNext: onNext ?? () {},
              onPrevious: onPrevious ?? () {},
              onSubmit: onSubmit ?? () {},
            ),
            SizedBox(height: healthDp(context, 8)),
          ],
        ],
      ),
    );
  }
}

class HealthProfileOtherExerciseCard extends StatelessWidget {
  const HealthProfileOtherExerciseCard({super.key, required this.session});

  final HealthProfileFormSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 14)),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
              width: healthDp(context, 1),
              color: HealthProfileFormCommon.border),
          borderRadius: BorderRadius.circular(healthDp(context, 15)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '기타 운동',
                  style: TextStyle(
                    color: const Color(0xFF1A1A1E),
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: session.openExerciseOtherDraft,
                  borderRadius: BorderRadius.circular(healthDp(context, 50)),
                  child: Container(
                    height: healthDp(context, 28),
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 10),
                    ),
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                            width: healthDp(context, 1),
                            color: HealthProfileFormCommon.border),
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 50)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          size: healthDp(context, 14),
                          color: const Color(0xFF898686),
                        ),
                        SizedBox(width: healthDp(context, 2)),
                        Text(
                          '추가',
                          style: TextStyle(
                            color: const Color(0xFF898686),
                            fontSize: healthSp(context, 12),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: healthDp(context, 14)),
          Container(
              height: healthDp(context, 1),
              color: HealthProfileFormCommon.border),
          SizedBox(height: healthDp(context, 20)),
          if (session.exerciseOtherDraftOpen || session.exerciseOthers.isEmpty)
            _draftField(context),
          if (session.exerciseOthers.isNotEmpty) ...[
            if (session.exerciseOtherDraftOpen ||
                session.exerciseOthers.isEmpty)
              SizedBox(height: healthDp(context, 8)),
            Wrap(
              spacing: healthDp(context, 8),
              runSpacing: healthDp(context, 8),
              children: [
                for (var i = 0; i < session.exerciseOthers.length; i++)
                  _chip(context, session.exerciseOthers[i], i),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, int index) {
    return Container(
      height: healthDp(context, 45),
      padding: EdgeInsets.only(
        left: healthDp(context, 14),
        right: healthDp(context, 8),
      ),
      decoration: ShapeDecoration(
        color: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(
          side: BorderSide(
              width: healthDp(context, 1),
              color: HealthProfileFormCommon.border),
          borderRadius: BorderRadius.circular(healthDp(context, 50)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF1A1A1E),
              fontSize: healthSp(context, 14),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: healthDp(context, 4)),
          GestureDetector(
            onTap: () => session.removeExerciseOtherAt(index),
            behavior: HitTestBehavior.opaque,
            child: Icon(
              Icons.close,
              size: healthSp(context, 16),
              color: const Color(0xFF898686),
            ),
          ),
        ],
      ),
    );
  }

  Widget _draftField(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: healthDp(context, 45),
      child: TextField(
        controller: session.exerciseOtherDraftCtrl,
        focusNode: session.exerciseOtherDraftFocus,
        textInputAction: TextInputAction.done,
        textAlignVertical: TextAlignVertical.center,
        onSubmitted: (_) => session.commitExerciseOtherDraft(),
        onChanged: (_) => session.touch(),
        style: TextStyle(
          color: const Color(0xFF1A1A1E),
          fontSize: healthSp(context, 14),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: '운동을 입력해주세요',
          hintStyle: TextStyle(
            color: const Color(0xFF898686),
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 14),
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 50)),
            borderSide: BorderSide(
                width: healthDp(context, 1),
                color: HealthProfileFormCommon.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 50)),
            borderSide: BorderSide(
                width: healthDp(context, 1),
                color: HealthProfileFormCommon.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 50)),
            borderSide: BorderSide(
                width: healthDp(context, 1), color: const Color(0xFFFF5A8D)),
          ),
        ),
      ),
    );
  }
}

class HealthProfileOtherMedicationCard extends StatelessWidget {
  const HealthProfileOtherMedicationCard({super.key, required this.session});

  final HealthProfileFormSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 14)),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
              width: healthDp(context, 1),
              color: HealthProfileFormCommon.border),
          borderRadius: BorderRadius.circular(healthDp(context, 15)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '기타 약 정보',
                  style: TextStyle(
                    color: const Color(0xFF1A1A1E),
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: session.openMedicationOtherDraft,
                  borderRadius: BorderRadius.circular(healthDp(context, 50)),
                  child: Container(
                    height: healthDp(context, 28),
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 10),
                    ),
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                            width: healthDp(context, 1),
                            color: HealthProfileFormCommon.border),
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 50)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          size: healthDp(context, 14),
                          color: const Color(0xFF898686),
                        ),
                        SizedBox(width: healthDp(context, 2)),
                        Text(
                          '추가',
                          style: TextStyle(
                            color: const Color(0xFF898686),
                            fontSize: healthSp(context, 12),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: healthDp(context, 14)),
          Container(
              height: healthDp(context, 1),
              color: HealthProfileFormCommon.border),
          SizedBox(height: healthDp(context, 20)),
          if (session.medicationOthers.isNotEmpty)
            Wrap(
              spacing: healthDp(context, 8),
              runSpacing: healthDp(context, 8),
              children: [
                for (var i = 0; i < session.medicationOthers.length; i++)
                  _chip(context, session.medicationOthers[i], i),
              ],
            ),
          if (session.medicationOtherDraftOpen ||
              session.medicationOthers.isEmpty) ...[
            if (session.medicationOthers.isNotEmpty)
              SizedBox(height: healthDp(context, 8)),
            _draftField(context),
          ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, int index) {
    return Container(
      height: healthDp(context, 45),
      padding: EdgeInsets.only(
        left: healthDp(context, 14),
        right: healthDp(context, 8),
      ),
      decoration: ShapeDecoration(
        color: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(
          side: BorderSide(
              width: healthDp(context, 1),
              color: HealthProfileFormCommon.border),
          borderRadius: BorderRadius.circular(healthDp(context, 50)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF1A1A1E),
              fontSize: healthSp(context, 14),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: healthDp(context, 4)),
          GestureDetector(
            onTap: () => session.removeMedicationOtherAt(index),
            behavior: HitTestBehavior.opaque,
            child: Icon(
              Icons.close,
              size: healthSp(context, 16),
              color: const Color(0xFF898686),
            ),
          ),
        ],
      ),
    );
  }

  Widget _draftField(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: healthDp(context, 45),
      child: TextField(
        controller: session.medicationOtherDraftCtrl,
        focusNode: session.medicationOtherDraftFocus,
        textInputAction: TextInputAction.done,
        textAlignVertical: TextAlignVertical.center,
        onSubmitted: (_) => session.commitMedicationOtherDraft(),
        onChanged: (_) {
          session.syncMedicationOtherFormData();
          session.touch();
        },
        style: TextStyle(
          color: const Color(0xFF1A1A1E),
          fontSize: healthSp(context, 14),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: '복용중인 약 이름을 입력해주세요',
          hintStyle: TextStyle(
            color: const Color(0xFF898686),
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 14),
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 50)),
            borderSide: BorderSide(
                width: healthDp(context, 1),
                color: HealthProfileFormCommon.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 50)),
            borderSide: BorderSide(
                width: healthDp(context, 1),
                color: HealthProfileFormCommon.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 50)),
            borderSide: BorderSide(
                width: healthDp(context, 1), color: const Color(0xFFFF5A8D)),
          ),
        ),
      ),
    );
  }
}
