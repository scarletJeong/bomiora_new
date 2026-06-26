import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class AuthRepository {
  /// 임시: 이 계정만 로그인 허용 (그 외 이메일/비밀번호는 API 호출 전 차단)
  static const String devAllowedLoginEmail = 'test@naver.com';
  static const String devAllowedLoginPassword = 'testtest1234';

  static bool isDevAllowedLogin({
    required String email,
    required String password,
  }) {
    return email.trim() == devAllowedLoginEmail &&
        password == devAllowedLoginPassword;
  }

  static String _asErrorMessage(dynamic value, {String fallback = '요청 처리 중 오류가 발생했습니다'}) {
    if (value == null) return fallback;
    if (value is String && value.isNotEmpty) return value;
    return value.toString();
  }

  /// KCP 등 본인인증 고유값(`mb_dupinfo`)으로 이미 가입된 계정이 있는지 확인
  static Future<Map<String, dynamic>> checkDupInfo({
    required String mbDupinfo,
  }) async {
    final trimmed = mbDupinfo.trim();
    if (trimmed.isEmpty) {
      return {'success': true, 'exists': false};
    }
    try {
      final response = await ApiClient.post(ApiEndpoints.checkDupInfo, {
        'mb_dupinfo': trimmed,
      });

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{};
        final exists = data['exists'] == true ||
            data['duplicate'] == true ||
            data['registered'] == true;
        return {
          'success': true,
          'exists': exists,
          'error': exists
              ? _asErrorMessage(
                  data['message'],
                  fallback: '이미 가입된 본인인증 정보입니다.',
                )
              : null,
        };
      }

      // 엔드포인트 미배포(404 등) — 클라이언트만으로는 막지 않고 서버 register에서 검증
      return {'success': true, 'exists': false};
    } catch (e) {
      return {'success': false, 'exists': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> checkEmail({
    required String email,
  }) async {
    try {
      final response = await ApiClient.post(ApiEndpoints.checkEmail, {
        'email': email,
      });

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{};
        final exists = data['exists'] == true;
        return {
          'success': true,
          'exists': exists,
          'data': data,
          'error': exists ? _asErrorMessage(data['message'], fallback: '이미 존재하는 이메일입니다.') : null,
        };
      }

      String errorMessage = '서버 오류: ${response.statusCode}';
      try {
        final errorData = json.decode(response.body);
        if (errorData is Map<String, dynamic>) {
          errorMessage = _asErrorMessage(
            errorData['message'] ?? errorData['error'],
            fallback: errorMessage,
          );
        }
      } catch (_) {}

      return {
        'success': false,
        'exists': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'exists': false,
        'error': '이메일 중복 확인 중 오류가 발생했습니다: $e',
      };
    }
  }

  /// 비밀번호를 SHA1로 해시 처리 (PHP 서버와 호환)
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha1.convert(bytes);
    return digest.toString();
  }

  // 로그인 API 호출 (Spring Boot 서버)
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    if (!isDevAllowedLogin(email: email, password: password)) {
      return {
        'success': false,
        'error': '아이디 혹은 비밀번호가 일치하지 않습니다.',
      };
    }

    try {
      // 평문 비밀번호를 전송 (Spring Boot에서 PBKDF2로 검증)
      final response = await ApiClient.post(ApiEndpoints.login, {
        'email': email.trim(),
        'password': password,
      });

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{};
        
        // success 필드가 없으면 기본값으로 true 설정
        final success = data['success'] ?? true;
        
        return {
          'success': success,
          'data': data,
          'error': success ? null : _asErrorMessage(data['message'], fallback: '로그인에 실패했습니다'),
        };
      } else if (response.statusCode == 405) {
        // Method Not Allowed - 서버가 POST를 허용하지 않음
        return {
          'success': false,
          'error': '서버 설정 오류: POST 메서드가 허용되지 않습니다. 서버 관리자에게 문의하세요.',
        };
      } else {
        String errorMessage = '서버 오류: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map<String, dynamic>) {
            errorMessage = _asErrorMessage(
              errorData['message'] ?? errorData['error'],
              fallback: errorMessage,
            );
          }
        } catch (e) {
          // JSON 파싱 실패 시 기본 메시지 사용
        }
        
        return {
          'success': false,
          'error': errorMessage,
        };
      }
    } catch (e) {
      // API 서버 연결 실패 시 에러 반환
      String errorMessage = 'API 서버에 연결할 수 없습니다. 네트워크 연결을 확인해주세요.';
      
      if (e.toString().contains('Connection refused')) {
        errorMessage = '서버에 연결할 수 없습니다. 서버가 실행 중인지 확인해주세요.';
      } else if (e.toString().contains('Failed host lookup')) {
        errorMessage = '서버 주소를 찾을 수 없습니다. IP 주소를 확인해주세요.';
      }
      
      return {
        'success': false,
        'error': errorMessage,
      };
    }
  }

  // 카카오 로그인 — social/login 과 동일 응답 (needRegister 지원)
  static Future<Map<String, dynamic>> loginWithKakao({
    required String kakaoId,
    required String? email,
    required String? nickname,
    String? profileImageUrl,
    String? accessToken,
  }) {
    return loginWithSocial(
      provider: 'kakao',
      identifier: kakaoId,
      email: email,
      nickname: nickname,
      profileImageUrl: profileImageUrl,
      accessToken: accessToken,
    );
  }

  /// 네이버 로그인 (네이버 SDK 연동 후 identifier 전달)
  static Future<Map<String, dynamic>> loginWithNaver({
    required String naverId,
    String? email,
    String? nickname,
    String? name,
    String? profileImageUrl,
    String? gender,
    String? birthday,
    String? accessToken,
  }) {
    return loginWithSocial(
      provider: 'naver',
      identifier: naverId,
      email: email,
      nickname: nickname,
      name: name,
      profileImageUrl: profileImageUrl,
      gender: gender,
      birthday: birthday,
      accessToken: accessToken,
    );
  }

  static Future<Map<String, dynamic>> loginWithSocial({
    required String provider,
    required String identifier,
    String? email,
    String? nickname,
    String? name,
    String? profileImageUrl,
    String? accessToken,
    String? gender,
    String? birthday,
  }) async {
    try {
      final endpoint = provider == 'naver'
          ? ApiEndpoints.naverLogin
          : provider == 'kakao'
              ? ApiEndpoints.kakaoLogin
              : ApiEndpoints.socialLogin;

      final response = await ApiClient.post(endpoint, {
        'provider': provider,
        'identifier': identifier,
        if (provider == 'kakao') 'kakaoId': identifier,
        if (provider == 'naver') 'naverId': identifier,
        if (email != null && email.isNotEmpty) 'email': email,
        if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
        if (name != null && name.isNotEmpty) 'name': name,
        if (profileImageUrl != null && profileImageUrl.isNotEmpty)
          'profileImageUrl': profileImageUrl,
        if (accessToken != null && accessToken.isNotEmpty)
          'accessToken': accessToken,
        if (gender != null && gender.isNotEmpty) 'gender': gender,
        if (birthday != null && birthday.isNotEmpty) 'birthday': birthday,
      });

      return _parseSocialAuthResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': '소셜 로그인 중 오류가 발생했습니다: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> registerWithSocial({
    required String provider,
    required String identifier,
    required String phone,
    required String email,
    required String name,
    String? nickname,
    String? gender,
    String? birthday,
    String? profileImageUrl,
    Map<String, bool>? agreements,
  }) async {
    try {
      final response = await ApiClient.post(ApiEndpoints.socialRegister, {
        'provider': provider,
        'identifier': identifier,
        if (provider == 'kakao') 'kakaoId': identifier,
        if (provider == 'naver') 'naverId': identifier,
        'phone': phone,
        'email': email,
        'name': name,
        if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
        if (gender != null && gender.isNotEmpty) 'gender': gender,
        if (birthday != null && birthday.isNotEmpty) 'birthday': birthday,
        if (profileImageUrl != null && profileImageUrl.isNotEmpty)
          'profileImageUrl': profileImageUrl,
        'agreements': agreements ??
            const {
              'terms': true,
              'privacy': true,
            },
      });

      return _parseSocialAuthResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': '소셜 회원가입 중 오류가 발생했습니다: $e',
      };
    }
  }

  static Map<String, dynamic> _parseSocialAuthResponse(dynamic response) {
    if (response.statusCode != 200) {
      String errorMessage = '서버 오류: ${response.statusCode}';
      try {
        final errorData = json.decode(response.body);
        if (errorData is Map<String, dynamic>) {
          errorMessage = _asErrorMessage(
            errorData['message'] ?? errorData['error'],
            fallback: errorMessage,
          );
        }
      } catch (_) {}
      return {
        'success': false,
        'error': errorMessage,
      };
    }

    final decoded = json.decode(response.body);
    final data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    final success = data['success'] == true;
    final needRegister = data['needRegister'] == true;

    return {
      'success': success,
      'needRegister': needRegister,
      'data': data,
      'prefill': data['prefill'],
      'error': success
          ? null
          : needRegister
              ? null
              : _asErrorMessage(
                  data['message'],
                  fallback: '소셜 인증에 실패했습니다.',
                ),
    };
  }

  // (구) 카카오 전용 구현 제거 — loginWithSocial 사용

  // 아이디/비밀번호호 찾기 API 호출
  ///
  /// - 본인인증(KCP): `fromKcp` + `mbDupinfo` (이름·휴대폰은 인증서와 교차검증용)
  /// - 소유인증(OTP): `otpToken`(id_find) + 이름 + 휴대폰
  static Future<Map<String, dynamic>> findId({
    required String name,
    required String phone,
    String? otpToken,
    bool fromKcp = false,
    String? mbDupinfo,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'phone': phone,
        if (otpToken != null && otpToken.trim().isNotEmpty) 'otpToken': otpToken.trim(),
        if (fromKcp) 'from_kcp': true,
        if (mbDupinfo != null && mbDupinfo.trim().isNotEmpty) 'mb_dupinfo': mbDupinfo.trim(),
      };
      final response = await ApiClient.post(ApiEndpoints.findId, body);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{};
        final success = data['success'] ?? true;
        return {
          'success': success,
          'data': data,
          'accounts': data['accounts'],
          'error': success ? null : _asErrorMessage(data['message'], fallback: '아이디 찾기에 실패했습니다'),
        };
      }

      String errorMessage = '서버 오류: ${response.statusCode}';
      try {
        final errorData = json.decode(response.body);
        if (errorData is Map<String, dynamic>) {
          errorMessage = _asErrorMessage(
            errorData['message'] ?? errorData['error'],
            fallback: errorMessage,
          );
        }
      } catch (_) {}

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': '아이디 찾기 중 오류가 발생했습니다: $e',
      };
    }
  }

  /// 비밀번호 찾기 사전 확인
  ///
  /// - 문자(OTP): `otpToken` + `identifier`(가입 이메일, mb_email) + 이름 + 휴대폰 (본인인증 등록 시 차단)
  /// - KCP: `fromKcp` + `mbDupinfo` + `identifier`(가입 이메일)
  /// - 레거시: `email`(로그인 이메일) + 이름 + 휴대폰만
  static Future<Map<String, dynamic>> forgotPassword({
    required String name,
    required String phone,
    String? email,
    String? identifier,
    String? otpToken,
    bool fromKcp = false,
    String? mbDupinfo,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'phone': phone,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (identifier != null && identifier.trim().isNotEmpty) 'identifier': identifier.trim(),
        if (otpToken != null && otpToken.trim().isNotEmpty) 'otpToken': otpToken.trim(),
        if (fromKcp) 'from_kcp': true,
        if (mbDupinfo != null && mbDupinfo.trim().isNotEmpty) 'mb_dupinfo': mbDupinfo.trim(),
      };

      final response = await ApiClient.post(ApiEndpoints.forgotPassword, body);

      Map<String, dynamic> data = <String, dynamic>{};
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}

      final success = data['success'] == true;
      return {
        'success': success,
        'data': data,
        'code': data['code']?.toString(),
        'error': success
            ? null
            : _asErrorMessage(data['message'], fallback: '비밀번호 찾기에 실패했습니다'),
      };
    } catch (e) {
      return {
        'success': false,
        'error': '비밀번호 찾기 중 오류가 발생했습니다: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> otpSend({
    required String purpose,
    required String name,
    required String phone,
  }) async {
    try {
      final response = await ApiClient.post(ApiEndpoints.otpSend, {
        'purpose': purpose,
        'name': name,
        'phone': phone,
      });

      Map<String, dynamic> data = <String, dynamic>{};
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}

      if (response.statusCode == 200) {
        return {
          'success': data['success'] == true,
          'data': data,
          'otpToken': data['otpToken'],
          'expiresAt': data['expiresAt'],
          'ttlSeconds': data['ttlSeconds'],
          'resendCooldownSeconds': data['resendCooldownSeconds'],
          'retryAfterSec': data['retryAfterSec'],
          'code': data['code'],
          'error': null,
        };
      }

      return {
        'success': false,
        'data': data,
        'code': data['code']?.toString(),
        'retryAfterSec': data['retryAfterSec'],
        'error': _asErrorMessage(
          data['message'] ?? data['error'],
          fallback: '인증번호 발송에 실패했습니다. (${response.statusCode})',
        ),
      };
    } catch (e) {
      return {
        'success': false,
        'error': '인증번호 발송 중 오류가 발생했습니다: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> otpVerify({
    required String otpToken,
    required String code,
    required String purpose,
  }) async {
    try {
      final response = await ApiClient.post(ApiEndpoints.otpVerify, {
        'otpToken': otpToken,
        'code': code,
        'purpose': purpose,
      });

      Map<String, dynamic> data = <String, dynamic>{};
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}

      if (response.statusCode == 200) {
        return {
          'success': data['success'] == true,
          'data': data,
          'code': data['code'],
          'error': null,
        };
      }

      return {
        'success': false,
        'data': data,
        'code': data['code']?.toString(),
        'expiresAt': data['expiresAt'],
        'tryCount': data['tryCount'],
        'remainingAttempts': data['remainingAttempts'],
        'error': _asErrorMessage(
          data['message'] ?? data['error'],
          fallback: '인증번호 확인에 실패했습니다. (${response.statusCode})',
        ),
      };
    } catch (e) {
      return {
        'success': false,
        'error': '인증번호 확인 중 오류가 발생했습니다: $e',
      };
    }
  }

  /// 비밀번호 재설정
  ///
  /// - OTP: `otpToken` + `identifier`(가입 이메일) + 이름 + 휴대폰
  /// - KCP: `fromKcp` + `mbDupinfo` + `identifier`(가입 이메일)
  /// - 레거시: `email` + 이름 + 휴대폰
  static Future<Map<String, dynamic>> resetPassword({
    required String name,
    required String phone,
    required String password,
    String? email,
    String? identifier,
    String? otpToken,
    bool fromKcp = false,
    String? mbDupinfo,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'phone': phone,
        'password': password,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (identifier != null && identifier.trim().isNotEmpty) 'identifier': identifier.trim(),
        if (otpToken != null && otpToken.trim().isNotEmpty) 'otpToken': otpToken.trim(),
        if (fromKcp) 'from_kcp': true,
        if (mbDupinfo != null && mbDupinfo.trim().isNotEmpty) 'mb_dupinfo': mbDupinfo.trim(),
      };

      final response = await ApiClient.post(ApiEndpoints.resetPassword, body);

      Map<String, dynamic> data = <String, dynamic>{};
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}

      final success = data['success'] == true;
      return {
        'success': success,
        'data': data,
        'error': success
            ? null
            : _asErrorMessage(
                data['message'],
                fallback: '비밀번호 재설정에 실패했습니다',
              ),
      };
    } catch (e) {
      return {
        'success': false,
        'error': '비밀번호 재설정 중 오류가 발생했습니다: $e',
      };
    }
  }

  // 회원가입 API 호출 (Spring Boot 서버)
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? birthday,
    String? gender,
    Map<String, dynamic>? certInfo,
    Map<String, bool>? agreements,
  }) async {
    try {
      // 평문 비밀번호를 전송 (Spring Boot에서 PBKDF2로 해싱)
      final mbDup = (certInfo?['mb_dupinfo'] ?? certInfo?['mbDupinfo'])
          ?.toString()
          .trim();
      final response = await ApiClient.post(ApiEndpoints.register, {
        'email': email,
        'password': password, // 평문 비밀번호 전송 (HTTPS로 보호)
        'name': name,
        'phone': phone,
        'birthday': birthday,
        'gender': gender,
        if (mbDup != null && mbDup.isNotEmpty) 'mb_dupinfo': mbDup,
        'certInfo': certInfo,
        'agreements': agreements,
      });

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{};
        return {
          'success': data['success'],
          'data': data,
          'error': _asErrorMessage(data['message']),
        };
      }

      String errorMessage = '서버 오류: ${response.statusCode}';
      try {
        final errorData = json.decode(response.body);
        if (errorData is Map<String, dynamic>) {
          errorMessage = _asErrorMessage(
            errorData['message'] ?? errorData['error'],
            fallback: errorMessage,
          );
        }
      } catch (_) {}

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'error': '회원가입 중 오류가 발생했습니다: $e',
      };
    }
  }
}