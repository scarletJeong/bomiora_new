import '../network/api_client.dart';
import 'failure_log_member.dart';
import 'failure_log_route_tracker.dart';

/// 사진 로드·업로드 실패는 서버에 보내지 않는다.
bool failureLogSkipsServer(String code) {
  return code.trim().endsWith('.image');
}

/// 기기 로그와 별도로 서버에 남긴다. 전송 실패는 다시 로그로 쌓지 않는다.
Future<void> sendFailureLogToServer({
  required String code,
  required String mbId,
  required String reason,
  required String occurredAt,
  required String device,
  Map<String, Object?>? detail,
}) async {
  try {
    final passedId = mbId.trim();
    final sessionId = FailureLogMember.mbId;
    final memberId = passedId.isNotEmpty ? passedId : sessionId;
    final phone = (sessionId.isEmpty || sessionId == memberId)
        ? FailureLogMember.phone
        : '';
    await ApiClient.post('/api/client-failure-log', {
      'mbId': memberId,
      'phone': phone,
      'occurredAt': occurredAt,
      'page': FailureLogRouteTracker.page,
      'code': code,
      'reason': reason,
      'device': device,
      if (detail != null && detail.isNotEmpty) 'detail': detail,
    });
  } catch (_) {}
}
