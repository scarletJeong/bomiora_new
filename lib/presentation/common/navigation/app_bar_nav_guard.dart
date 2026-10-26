import 'dart:async';

import 'package:flutter/material.dart';

/// 메뉴·장바구니를 연 직후의 클릭이 화면을 닫거나 홈으로 보내지 않게 한다.
class AppBarNavGuard extends ChangeNotifier {
  AppBarNavGuard._();

  static final AppBarNavGuard instance = AppBarNavGuard._();

  static const Duration _guard = Duration(milliseconds: 450);

  bool _allowDismiss = true;
  Timer? _timer;

  /// 드로어 바깥 탭·로고·오버레이 배경이 닫기를 처리해도 되는 시점.
  bool get allowDismiss => _allowDismiss;

  void markOpening() {
    _timer?.cancel();
    _allowDismiss = false;
    notifyListeners();
    _timer = Timer(_guard, () {
      _allowDismiss = true;
      notifyListeners();
    });
  }
}

/// [Scaffold.drawerBarrierDismissible]을 가드 상태에 맞춘다.
class DrawerBarrierHost extends StatefulWidget {
  const DrawerBarrierHost({super.key, required this.builder});

  final Widget Function(bool allowDismiss) builder;

  @override
  State<DrawerBarrierHost> createState() => _DrawerBarrierHostState();
}

class _DrawerBarrierHostState extends State<DrawerBarrierHost> {
  @override
  void initState() {
    super.initState();
    AppBarNavGuard.instance.addListener(_onGuard);
  }

  @override
  void dispose() {
    AppBarNavGuard.instance.removeListener(_onGuard);
    super.dispose();
  }

  void _onGuard() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(AppBarNavGuard.instance.allowDismiss);
  }
}
