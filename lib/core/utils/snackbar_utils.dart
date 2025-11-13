import 'package:flutter/material.dart';

/// 스낵바 유틸리티 클래스
/// 모바일 레이아웃 (600px)에 맞춘 스낵바를 쉽게 표시
class SnackBarUtils {
  // 600px - 32px (양쪽 16px 여백)
  static const double _snackBarWidth = 568;

  /// 성공 메시지 스낵바 (초록색)
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        width: _snackBarWidth,
        duration: duration,
      ),
    );
  }

  /// 에러 메시지 스낵바 (빨간색)
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        width: _snackBarWidth,
        duration: duration,
      ),
    );
  }

  /// 정보 메시지 스낵바 (파란색)
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        width: _snackBarWidth,
        duration: duration,
      ),
    );
  }

  /// 경고 메시지 스낵바 (주황색)
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        width: _snackBarWidth,
        duration: duration,
      ),
    );
  }

  /// 커스텀 스낵바
  static void showCustom(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        width: _snackBarWidth,
        duration: duration,
        action: action,
      ),
    );
  }
}

