import 'package:flutter/material.dart';

import '../../../core/navigation/app_action_gate.dart';
import '../../../core/utils/kcp_pay_session_store.dart';
import '../../shopping/kcp_pay_resume.dart';
import '../widgets/app_toast_overlay.dart';
import 'splash_screen.dart';

/// 웹에서 결제 도중 새로고침했을 때, 저장된 결제 결과를 확인하는 스플래시.
/// 뒤로가기로 이 화면이 다시 열리면 메인으로 보낸다.
class KcpPayResumeSplash extends StatefulWidget {
  const KcpPayResumeSplash({super.key});

  @override
  State<KcpPayResumeSplash> createState() => _KcpPayResumeSplashState();
}

class _KcpPayResumeSplashState extends State<KcpPayResumeSplash>
    with RouteAware {
  var _left = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      appRouteObserver.unsubscribe(this);
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _goHomeAsInvalidPath();
  }

  void _goHomeAsInvalidPath() {
    if (_left || !mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _left = true;
    clearKcpPayToken();
    AppToastOverlay.showAlert(context, '잘못된 경로입니다');
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
    );
  }

  Future<void> _run() async {
    await KcpPayResume.tryResume(context);
    if (!mounted || _left) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SplashView(caption: '결제 확인 중..');
  }
}
