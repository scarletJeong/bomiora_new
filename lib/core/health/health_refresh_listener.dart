import 'package:flutter/widgets.dart';

import 'health_refresh_bus.dart';

/// 건강 데이터 변경 시 [onHealthDataChanged]를 호출하는 mixin.
mixin HealthRefreshListener<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    HealthRefreshBus.instance.addListener(_handleHealthRefresh);
  }

  @override
  void dispose() {
    HealthRefreshBus.instance.removeListener(_handleHealthRefresh);
    super.dispose();
  }

  void _handleHealthRefresh() {
    if (!mounted) return;
    onHealthDataChanged();
  }

  void onHealthDataChanged();
}
