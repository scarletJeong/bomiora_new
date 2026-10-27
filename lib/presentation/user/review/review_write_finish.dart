import 'package:flutter/material.dart';

import '../../../core/navigation/app_action_gate.dart';
import '../../../data/services/delivery_service.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import 'my_reviews_screen.dart';

/// 리뷰 저장 후 내 리뷰로 보낸다.
/// 그 화면에서 뒤로 가면 작성 화면 대신 안내 후 마이페이지로 간다.
void openMyReviewsAfterWrite(BuildContext context, {int? focusIsId}) {
  OrderService.invalidateOrderList();
  final navigator = Navigator.of(context);
  navigator.pushAndRemoveUntil(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/review-return'),
      builder: (_) => const InvalidPathRedirectScreen(),
    ),
    (route) => false,
  );
  navigator.push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/my_reviews'),
      builder: (_) => MyReviewsScreen(focusIsId: focusIsId),
    ),
  );
}

/// 리뷰 작성 화면으로 돌아갈 수 없을 때 잠깐 안내하고 마이페이지로 이동한다.
class InvalidPathRedirectScreen extends StatefulWidget {
  const InvalidPathRedirectScreen({super.key});

  @override
  State<InvalidPathRedirectScreen> createState() =>
      _InvalidPathRedirectScreenState();
}

class _InvalidPathRedirectScreenState extends State<InvalidPathRedirectScreen>
    with RouteAware {
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      appRouteObserver.unsubscribe(this);
      appRouteObserver.subscribe(this, route);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _leaveIfCurrent());
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _leaveIfCurrent();
  }

  void _leaveIfCurrent() {
    if (_scheduled || !mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _scheduled = true;
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/my_page',
        (route) => false,
      );
    });
  }

  void _goMyPage() {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/my_page',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: MobileAppLayoutWrapper(
        backgroundColor: Colors.white,
        appBar: HealthAppBar(
          title: '',
          onBack: _goMyPage,
        ),
        child: Center(
          child: Text(
            '잘못된 경로입니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF1A1A1E),
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
