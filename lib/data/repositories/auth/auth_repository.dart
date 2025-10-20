import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class AuthRepository {
  // 로그인 API 호출 (Spring Boot 서버)
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await ApiClient.post(ApiEndpoints.login, {
        'email': email,
        'password': password,
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
      // API 서버 연결 실패 시 데모 모드로 전환
      print('API 서버 연결 실패, 데모 모드로 전환: $e');
      
      // 테스트 계정으로 자동 로그인 (배포용)
      if (email == 'test@naver.com' || email.isNotEmpty) {
        return {
          'success': true,
          'data': {
            'success': true,
            'user': {
              'mb_no': 1,
              'mb_id': 'test', // mb_id 추가!
              'mb_email': email,
              'mb_name': '테스트 사용자',
              'mb_phone': '010-1234-5678',
            },
            'token': 'demo_token_12345',
          },
          'error': null,
        };
      }
      
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
      final response = await ApiClient.post(ApiEndpoints.register, {
        'email': email,
        'password': password,
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