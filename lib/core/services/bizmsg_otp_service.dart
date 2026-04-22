import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

class BizmsgOtpConfig {
  const BizmsgOtpConfig({
    required this.userid,
    required this.profile,
    required this.tmplId,
    this.endpoint = 'https://alimtalk-api.bizmsg.kr/v2/sender/send',
  });

  final String userid; // Bizmsg 계정명 (API 헤더)
  final String profile; // senderKey
  final String tmplId; // 템플릿 코드
  final String endpoint;

  static const BizmsgOtpConfig fromEnv = BizmsgOtpConfig(
    userid: String.fromEnvironment(
      'BOMIORA_OTP_BIZM_USERID',
      defaultValue: 'bomioramall01',
    ),
    profile: String.fromEnvironment(
      'BOMIORA_OTP_BIZM_PROFILE',
      defaultValue: '',
    ),
    tmplId: String.fromEnvironment(
      'BOMIORA_OTP_TMPL_ID',
      defaultValue: 'bomiora_pwfind_otp',
    ),
  );
}

class BizmsgOtpSendResult {
  const BizmsgOtpSendResult({
    required this.ok,
    this.errorMessage,
    this.raw,
  });

  final bool ok;
  final String? errorMessage;
  final Map<String, dynamic>? raw;
}

class BizmsgOtpService {
  BizmsgOtpService({
    BizmsgOtpConfig? config,
    http.Client? client,
  })  : config = config ?? BizmsgOtpConfig.fromEnv,
        _client = client ?? http.Client();

  final BizmsgOtpConfig config;
  final http.Client _client;

  static String generateOtp({int length = 6}) {
    final rng = Random.secure();
    final min = pow(10, length - 1) as int;
    final maxExclusive = pow(10, length) as int;
    return (min + rng.nextInt(maxExclusive - min)).toString();
  }

  /// 01012345678 -> 821012345678
  static String toE164Korea82(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('82')) return digits;
    if (digits.startsWith('0')) return '82${digits.substring(1)}';
    return '82$digits';
  }

  Future<BizmsgOtpSendResult> sendAlimtalkOtp({
    required String phone010,
    required String otp,
  }) async {
    if (config.profile.trim().isEmpty) {
      return const BizmsgOtpSendResult(
        ok: false,
        errorMessage: '발신프로필(profile/senderKey) 설정이 없습니다.',
      );
    }

    final phn = toE164Korea82(phone010);
    final msg = '[보미오라]인증번호는 $otp입니다.';

    final uri = Uri.parse(config.endpoint);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'userid': config.userid,
    };

    // 주의: 기본형 템플릿이면 title 필드를 보내면 안 됨(K109)
    final body = <String, dynamic>{
      'message_type': 'at',
      'phn': phn,
      'profile': config.profile,
      'tmplId': config.tmplId,
      'msg': msg,
    };

    try {
      final res = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );

      Map<String, dynamic>? decoded;
      try {
        final dynamic jsonBody = jsonDecode(utf8.decode(res.bodyBytes));
        if (jsonBody is Map<String, dynamic>) {
          decoded = jsonBody;
        }
      } catch (_) {
        decoded = null;
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        // Bizmsg 응답 포맷이 케이스별로 달라질 수 있어,
        // 우선 HTTP 성공이면 ok 처리하고 raw를 남김.
        return BizmsgOtpSendResult(ok: true, raw: decoded);
      }

      final msgFromBody = (decoded?['message'] ??
              decoded?['msg'] ??
              decoded?['error'] ??
              decoded?['code'])
          ?.toString();

      return BizmsgOtpSendResult(
        ok: false,
        errorMessage: msgFromBody ?? '알림톡 발송에 실패했습니다. (${res.statusCode})',
        raw: decoded,
      );
    } catch (e) {
      return BizmsgOtpSendResult(
        ok: false,
        errorMessage: '알림톡 발송 중 오류가 발생했습니다: $e',
      );
    }
  }
}

