import 'dart:convert';

/// 건강 기록 저장 결과. 실패 문구는 서버 `message`, 없으면 `error`만 담는다.
class HealthSaveResult {
  const HealthSaveResult({required this.success, this.message});

  final bool success;
  final String? message;

  static const ok = HealthSaveResult(success: true);

  factory HealthSaveResult.failed(dynamic body) {
    return HealthSaveResult(success: false, message: readMessage(body));
  }

  static dynamic decode(String body) {
    try {
      return json.decode(body);
    } catch (_) {
      return null;
    }
  }

  static String? readMessage(dynamic body) {
    dynamic data = body;
    if (body is String) {
      final trimmed = body.trim();
      if (trimmed.isEmpty) return null;
      try {
        data = json.decode(trimmed);
      } catch (_) {
        return null;
      }
    }
    if (data is! Map) return null;
    for (final key in ['message', 'error']) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }
}
