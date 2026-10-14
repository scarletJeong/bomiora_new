import 'package:flutter/material.dart';

import '../../../data/models/cart/cart_item_model.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../user/healthprofile/widgets/health_profile_common.dart';
import '../../user/healthprofile/widgets/health_profile_prescription_booking_args.dart';
import 'splash_screen.dart';

/// 처방 예약 담기가 끝나기 전에 다음 단계로 갈 때 띄우는 스플래시.
class ConsultationPrepareSplash extends StatefulWidget {
  const ConsultationPrepareSplash({
    super.key,
    required this.pending,
    required this.buildNext,
    this.popFormRoutes = false,
    this.alreadyFailed = false,
  });

  static const routeName = 'consultation_prepare_splash';

  final Future<List<CartItem>> pending;
  final Widget Function(List<CartItem> items) buildNext;
  final bool popFormRoutes;
  final bool alreadyFailed;

  @override
  State<ConsultationPrepareSplash> createState() =>
      _ConsultationPrepareSplashState();
}

class _ConsultationPrepareSplashState extends State<ConsultationPrepareSplash> {
  var _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.alreadyFailed) {
      _failed = true;
      return;
    }
    _wait();
  }

  Future<void> _wait() async {
    List<CartItem> items = const [];
    try {
      items = await widget.pending;
    } catch (_) {
      items = const [];
    }
    if (!mounted) return;
    if (items.isEmpty) {
      setState(() => _failed = true);
      return;
    }
    _openNext(
      context,
      widget.buildNext(items),
      popFormRoutes: widget.popFormRoutes,
      replaceCurrent: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SplashView(
      caption: _failed ? '상담을 준비하지 못했습니다' : '상담 준비 중..',
      trailing: _failed
          ? TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF5A8D),
                padding: EdgeInsets.symmetric(horizontal: healthDp(context, 12)),
              ),
              child: Text(
                '돌아가기',
                style: TextStyle(
                  color: const Color(0xFFFF5A8D),
                  fontSize: healthSp(context, 14),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : null,
    );
  }
}

/// 장바구니 반영이 끝났으면 바로 다음 화면으로, 아직이면 상담 준비 스플래시를 연다.
Future<void> openPrescriptionTimeAfterPrepare({
  required BuildContext context,
  required HealthProfilePrescriptionBookingArgs booking,
  required Widget Function(List<CartItem> items) buildNext,
  bool popFormRoutes = false,
}) async {
  final peeked = await booking.peekCheckoutItems();
  if (!context.mounted) return;

  if (peeked != null && peeked.isNotEmpty) {
    _openNext(context, buildNext(peeked), popFormRoutes: popFormRoutes);
    return;
  }

  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      settings: const RouteSettings(name: ConsultationPrepareSplash.routeName),
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ConsultationPrepareSplash(
          pending: booking.resolveCheckoutItems(),
          buildNext: buildNext,
          popFormRoutes: popFormRoutes,
          alreadyFailed: peeked != null && peeked.isEmpty,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

void _openNext(
  BuildContext context,
  Widget page, {
  required bool popFormRoutes,
  bool replaceCurrent = false,
}) {
  final route = MaterialPageRoute<void>(builder: (_) => page);
  final nav = Navigator.of(context);
  if (popFormRoutes) {
    nav.pushAndRemoveUntil(route, (route) {
      if (route.isFirst) return true;
      final name = route.settings.name;
      if (name == ConsultationPrepareSplash.routeName) return false;
      return !HealthProfileFormCommon.isFormRouteName(name);
    });
    return;
  }
  if (replaceCurrent) {
    nav.pushReplacement(route);
    return;
  }
  nav.push(route);
}
