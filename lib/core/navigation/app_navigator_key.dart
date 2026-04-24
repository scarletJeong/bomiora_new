import 'package:flutter/material.dart';

/// [MaterialApp.navigatorKey]에 연결. context 없이 pop/push가 필요할 때 사용.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
