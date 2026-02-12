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
      print('🔐 [LOGIN] 이메일: $email');
      print('🔐 [LOGIN] 비밀번호: [보호됨]');
      print('🌐 [LOGIN] API URL: ${ApiClient.baseUrl}${ApiEndpoints.login}');
      
      final response = await ApiClient.post(ApiEndpoints.login, {
        'email': email,
        'password': password, // 평문 비밀번호 전송 (HTTPS로 보호)
      });

      print('📡 [LOGIN] 응답 상태 코드: ${response.statusCode}');
      print('📄 [LOGIN] 응답 헤더: ${response.headers}');
      print('📄 [LOGIN] 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{};
        print('✅ [LOGIN] 로그인 응답 데이터: $data');
        
        // success 필드가 없으면 기본값으로 true 설정
        final success = data['success'] ?? true;
        
        return {
          'success': success,
          'data': data,
          'error': success ? null : _asErrorMessage(data['message'], fallback: '로그인에 실패했습니다'),
        };
      } else if (response.statusCode == 405) {
        // Method Not Allowed - 서버가 POST를 허용하지 않음
        print('❌ [LOGIN] 405 Method Not Allowed - 서버가 POST 메서드를 허용하지 않습니다');
        print('❌ [LOGIN] 응답 본문: ${response.body}');
        
        return {
          'success': false,
          'error': '서버 설정 오류: POST 메서드가 허용되지 않습니다. 서버 관리자에게 문의하세요.',
        };
      } else {
        print('❌ [LOGIN] 서버 오류: ${response.statusCode}');
        print('❌ [LOGIN] 응답 본문: ${response.body}');
        
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
    } catch (e, stackTrace) {
      // API 서버 연결 실패 시 에러 반환
      print('❌ [LOGIN] API 서버 연결 실패: $e');
      print('❌ [LOGIN] 스택 트레이스: $stackTrace');
      
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
      print('🔐 [KAKAO LOGIN] 카카오 ID: $kakaoId');
      print('🔐 [KAKAO LOGIN] 이메일: $email');
      print('🔐 [KAKAO LOGIN] 닉네임: $nickname');
      
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

  // 회원가입 API 호출 (Spring Boot 서버)
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    try {
      // 평문 비밀번호를 전송 (Spring Boot에서 PBKDF2로 해싱)
      print('🔐 [REGISTER] 이메일: $email');
      print('🔐 [REGISTER] 비밀번호: [보호됨]');
      
      final response = await ApiClient.post(ApiEndpoints.register, {
        'email': email,
        'password': password, // 평문 비밀번호 전송 (HTTPS로 보호)
        'name': name,
        'phone': phone,
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
      } else {
        return {
          'success': false,
          'error': '서버 오류: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': '회원가입 중 오류가 발생했습니다: $e',
      };
    }
  }
}