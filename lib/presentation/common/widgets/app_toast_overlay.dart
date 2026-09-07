import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../health/health_common/health_responsive_scale.dart';
import 'mobile_layout_wrapper.dart';

/// 하단 검은 토스트 오버레이 (메시지 문구만 교체해서 재사용)
///
/// 앱 패널(최대 650) 안에 맞춰 표시 — 와이드 화면에서도 패널 밖으로 나가지 않음.
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
        final screenW = MediaQuery.sizeOf(ctx).width;
        final contentW = MobileAppLayoutWrapper.contentWidthOf(ctx);
        final panelLeft = (screenW - contentW) / 2;
        final scale = healthTextScaleByWidth(contentW);
        final toastW = 301 * scale;
        final bottomInset = MediaQuery.paddingOf(ctx).bottom;
        final bottomPad = 24 * scale;

        return Positioned(
          left: panelLeft + (contentW - toastW) / 2,
          width: toastW,
          bottom: bottomInset + bottomPad,
          child: MediaQuery(
            data: MediaQuery.of(ctx).copyWith(
              size: Size(contentW, MediaQuery.sizeOf(ctx).height),
            ),
            child: Material(
              color: Colors.transparent,
              child: _AppToastBar(message: message),
            ),
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
      width: healthDp(context, 301),
      height: healthDp(context, 49),
      padding: EdgeInsets.all(healthDp(context, 10)),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: Colors.black.withValues(alpha: 0.40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 14)),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: healthDp(context, 30),
            height: healthDp(context, 30),
            child: Center(
              child: SvgPicture.asset(
                AppAssets.commonToastOverlay,
                width: healthDp(context, 20),
                height: healthDp(context, 20),
              ),
            ),
          ),
          SizedBox(width: healthDp(context, 4)),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: healthSp(context, 12),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                height: 1.33,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
