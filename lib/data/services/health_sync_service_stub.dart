class HealthSyncResult {
  final bool success;
  final bool authorized;
  final bool supported;
  final int? steps;
  final int? heartRate;
  final String message;

  const HealthSyncResult({
    required this.success,
    required this.authorized,
    required this.supported,
    required this.steps,
    required this.heartRate,
    required this.message,
  });
}

class HealthSyncService {
  static Future<HealthSyncResult> connectAndFetchToday() async {
    return const HealthSyncResult(
      success: false,
      authorized: false,
      supported: false,
      steps: null,
      heartRate: null,
      message: '현재 플랫폼에서는 건강앱 연동이 지원되지 않습니다.',
    );
  }

  static Future<HealthSyncResult> fetchToday() async {
    return const HealthSyncResult(
      success: false,
      authorized: false,
      supported: false,
      steps: null,
      heartRate: null,
      message: '현재 플랫폼에서는 건강앱 연동이 지원되지 않습니다.',
    );
  }
}
