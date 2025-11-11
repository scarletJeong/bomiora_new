import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class AuthRepository {
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
      
      final response = await ApiClient.post(ApiEndpoints.login, {
        'email': email,
        'password': password, // 평문 비밀번호 전송 (HTTPS로 보호)
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('로그인 응답 데이터: $data'); // 디버깅용 로그
        return {
          'success': data['success'],
          'data': data,
          'error': data['message'],
        };
      } else {
        return {
          'success': false,
          'error': '서버 오류: ${response.statusCode}',
        };
      }
    } catch (e) {
      // API 서버 연결 실패 시 에러 반환
      print('❌ API 서버 연결 실패: $e');
      
      return {
        'success': false,
        'error': 'API 서버에 연결할 수 없습니다. 네트워크 연결을 확인해주세요.',
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
        final data = json.decode(response.body);
        return {
          'success': data['success'],
          'data': data,
          'error': data['message'],
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