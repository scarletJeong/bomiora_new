import 'dart:async';

import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';

/// 하단 검은 토스트 오버레이 (메시지 문구만 교체해서 재사용)
class AppToastOverlay {
  AppToastOverlay._();

  static OverlayEntry? _activeEntry;
  static Timer? _hideTimer;

  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    hide();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        final bottomInset = MediaQuery.paddingOf(ctx).bottom;
        return Positioned(
          left: healthDp(ctx, 27),
          right: healthDp(ctx, 27),
          bottom: bottomInset + healthDp(ctx, 24),
          child: Material(
            color: Colors.transparent,
            child: _AppToastBar(message: message),
          ),
        );
      },
    );

    _activeEntry = entry;
    overlay.insert(entry);
    _hideTimer = Timer(duration, hide);
  }

  static void hide() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _activeEntry?.remove();
    _activeEntry = null;
  }
}

class _AppToastBar extends StatelessWidget {
  const _AppToastBar({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: healthDp(context, 40),
      padding: EdgeInsets.all(healthDp(context, 10)),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: const Color(0xFF050505),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        message,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: healthSp(context, 13),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
          height: 1.23,
        ),
      ),
    );
  }
}
