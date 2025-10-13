import 'dart:convert';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';

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
      return {
        'success': false,
        'error': '로그인 중 오류가 발생했습니다: $e',
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