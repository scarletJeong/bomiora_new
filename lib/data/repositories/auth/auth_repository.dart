import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class AuthRepository {
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
    try {
      // 평문 비밀번호를 전송 (Spring Boot에서 PBKDF2로 검증)
      final response = await ApiClient.post(ApiEndpoints.login, {
        'email': email,
        'password': password, // 평문 비밀번호 전송 (HTTPS로 보호)
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

  // 카카오 로그인/회원가입 API 호출
  static Future<Map<String, dynamic>> loginWithKakao({
    required String kakaoId,
    required String? email,
    required String? nickname,
    String? profileImageUrl,
    String? accessToken,
  }) async {
    try {
      final response = await ApiClient.post('/api/auth/kakao/login', {
        'kakaoId': kakaoId,
        'email': email,
        'nickname': nickname,
        'profileImageUrl': profileImageUrl,
        'accessToken': accessToken,
      });

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{};
        return {
          'success': data['success'] ?? true,
          'data': data,
          'error': _asErrorMessage(data['message']),
        };
      } else {
        return {
          'success': false,
          'error': '서버 오류: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': '카카오 로그인 중 오류가 발생했습니다: $e',
      };
    }
  }

  // 아이디/비밀번호호 찾기 API 호출
  static Future<Map<String, dynamic>> findId({
    required String name,
    required String phone,
  }) async {
    try {
      final response = await ApiClient.post(ApiEndpoints.findId, {
        'name': name,
        'phone': phone,
      });

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

  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
    required String name,
    required String phone,
  }) async {
    try {
      final response = await ApiClient.post(ApiEndpoints.forgotPassword, {
        'email': email,
        'name': name,
        'phone': phone,
      });

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{};
        final success = data['success'] ?? true;
        return {
          'success': success,
          'data': data,
          'error': success ? null : _asErrorMessage(data['message'], fallback: '비밀번호 찾기에 실패했습니다'),
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

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String name,
    required String phone,
    required String password,
  }) async {
    try {
      final response = await ApiClient.post(ApiEndpoints.resetPassword, {
        'email': email,
        'name': name,
        'phone': phone,
        'password': password,
      });

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{};
        final success = data['success'] ?? true;
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
      print('🔐 [REGISTER] 이메일: $email');
      print('🔐 [REGISTER] 비밀번호: [보호됨]');
      
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