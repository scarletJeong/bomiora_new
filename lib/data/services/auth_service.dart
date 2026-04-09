import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user/user_model.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';

class AuthService {
  static const String _userKey = 'user_data';
  static const String _tokenKey = 'auth_token';
  static const String _isLoggedInKey = 'is_logged_in';

  // 로그인 상태 저장
  static Future<void> saveLoginData({
    required UserModel user,
    String? token, // String?으로 변경
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final userJsonStr = json.encode(user.toJson());

    await prefs.setString(_userKey, userJsonStr);
    if (token != null) { // token이 null이 아닐 때만 저장
      await prefs.setString(_tokenKey, token);
    } else {
      await prefs.remove(_tokenKey); // 기존 토큰이 있다면 삭제
    }
    await prefs.setBool(_isLoggedInKey, true);
  }

  // 로그인 상태 확인
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  // 사용자 정보 가져오기
  static Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    
    if (userJson != null) {
      try {
        final userData = json.decode(userJson);     
        final user = UserModel.fromJson(userData);
        return user;
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  // 토큰 가져오기
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // 로그아웃 (모든 데이터 삭제)
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove(_userKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_isLoggedInKey);
  }

  // 사용자 정보 업데이트
  static Future<void> updateUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, json.encode(user.toJson()));
  }

  // 토큰 업데이트
  static Future<void> updateToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// 프로필 수정
  static Future<Map<String, dynamic>> updateProfile({
    required String mbId,
    String? name,
    String? nickname,
    String? phone,
  }) async {
    try {
      print('✏️ [프로필 수정] 요청 - mbId: $mbId');
      
      final requestData = {
        'mbId': mbId,
        if (name != null) 'name': name,
        if (nickname != null) 'nickname': nickname,
        if (phone != null) 'phone': phone,
      };
      
      final response = await http.put(
        Uri.parse('${ApiClient.baseUrl}/api/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestData),
      );
      
      print('📡 [프로필 수정] 응답 상태: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          print('✅ [프로필 수정] 성공');
          
          // 수정된 사용자 정보 저장
          if (data['user'] != null) {
            final updatedUser = UserModel.fromJson(data['user']);
            await updateUser(updatedUser);
          }
          
          return {
            'success': true,
            'message': data['message'] ?? '프로필이 수정되었습니다.',
          };
        }
      }
      
      print('❌ [프로필 수정] 실패');
      final errorData = json.decode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? '프로필 수정에 실패했습니다.',
      };
    } catch (e) {
      print('❌ [프로필 수정] 에러: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다.',
      };
    }
  }

  /// 비밀번호 확인(재인증) - 개인정보 수정 진입용
  ///
  /// 백엔드에 비밀번호 검증 엔드포인트가 있어야 동작합니다.
  /// 성공 시 true, 불일치/실패 시 false를 반환합니다.
  static Future<bool> verifyPassword({
    required String mbId,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/api/user/verify-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'mbId': mbId,
          // 로그인과 동일하게 "평문 비밀번호"를 그대로 전송
          // (백엔드에서 PBKDF2 / MySQL PASSWORD() 규칙에 따라 검증)
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }

      return false;
    } catch (e) {
      print('❌ [비밀번호 확인] 에러: $e');
      return false;
    }
  }

  /// 회원 탈퇴(Soft Delete)
  static Future<Map<String, dynamic>> withdrawMember({
    required String mbId,
    String? reason,
  }) async {
    try {
      final response = await ApiClient.post(
        ApiEndpoints.withdraw,
        {
          'mbId': mbId,
          'reason': (reason ?? '').trim(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] == true,
          'message': data['message']?.toString() ?? '',
        };
      }

      return {
        'success': false,
        'message': '회원 탈퇴 처리에 실패했습니다.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': '회원 탈퇴 중 오류가 발생했습니다.',
      };
    }
  }
}
