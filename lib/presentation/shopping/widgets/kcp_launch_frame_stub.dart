import 'package:flutter/material.dart';

/// 비웹 플랫폼용. 웹은 [kcp_launch_frame_web.dart]가 같은 이름으로 연결된다.
class KcpLaunchFrame extends StatelessWidget {
  const KcpLaunchFrame({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
