import 'package:flutter/material.dart';

import '../../common/widgets/app_toast_overlay.dart';

/// 건강 입력 화면 — 필수 칸이 비었을 때 공통 안내.
abstract final class HealthInputComplete {
  static const String requiredMessage = '모든 칸을 다 입력하셔야합니다.';
  static const Color activeColor = Color(0xFFFF5A8D);
  static const Color inactiveColor = Color(0xFFD2D2D2);

  static void showRequiredToast(BuildContext context) {
    AppToastOverlay.showAlert(context, requiredMessage);
  }
}
