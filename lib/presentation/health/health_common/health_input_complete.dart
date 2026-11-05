import 'package:flutter/material.dart';

import '../../common/widgets/app_toast_overlay.dart';

/// 건강 입력 화면 — 필수 칸이 비었을 때 공통 안내.
abstract final class HealthInputComplete {
  static const String requiredMessage = '모든 칸을 다 입력하셔야합니다.';
  static const String saveFailedMessage = '저장하지 못했습니다.';
  static const Color activeColor = Color(0xFFFF5A8D);
  static const Color inactiveColor = Color(0xFFD2D2D2);

  static void showRequiredToast(BuildContext context) {
    AppToastOverlay.showAlert(context, requiredMessage);
  }

  /// 저장 실패. 서버 문구가 없으면 [saveFailedMessage]를 쓴다.
  static void showSaveFailureToast(BuildContext context, String? serverMessage) {
    final message = (serverMessage ?? '').trim();
    AppToastOverlay.showAlert(
      context,
      message.isEmpty ? saveFailedMessage : message,
    );
  }
}
