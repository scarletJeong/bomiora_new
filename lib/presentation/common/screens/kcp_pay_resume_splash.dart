import 'package:flutter/material.dart';

import '../../shopping/kcp_pay_resume.dart';
import 'splash_screen.dart';

/// 웹에서 결제 도중 새로고침했을 때, 저장된 결제 결과를 확인하는 스플래시.
class KcpPayResumeSplash extends StatefulWidget {
  const KcpPayResumeSplash({super.key});

  @override
  State<KcpPayResumeSplash> createState() => _KcpPayResumeSplashState();
}

class _KcpPayResumeSplashState extends State<KcpPayResumeSplash> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    await KcpPayResume.tryResume(context);
    if (!mounted) return;
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
