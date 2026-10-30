import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'failure_log_store.dart';

/// 화면 공통 실패 로그.
///
/// 한 줄에 시각, 코드, `mb_id`, 실패 사유, 기기를 JSON으로 남긴다.
/// 모바일·데스크톱은 앱 문서 폴더의 `bomiora_failure.log`,
/// 웹은 같은 이름의 브라우저 저장소 키에 이어 쓴다.
class FailureLog {
  FailureLog._();

  static Future<void> record({
    required String code,
    required String mbId,
    required String reason,
    Map<String, Object?>? detail,
  }) async {
    final device = await failureLogDeviceLabel();
    final entry = <String, Object?>{
      'at': DateTime.now().toIso8601String(),
      'code': code,
      'mb_id': mbId,
      'reason': reason,
      'device': device,
      if (detail != null && detail.isNotEmpty) 'detail': detail,
    };
    final line = jsonEncode(entry);
    debugPrint('[FailureLog] $line');
    try {
      await appendFailureLogLine(line);
    } catch (e) {
      debugPrint('[FailureLog] write failed: $e');
    }
  }
}
