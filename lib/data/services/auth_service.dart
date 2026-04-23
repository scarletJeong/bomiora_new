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

  /// 탈퇴/차단 등으로 세션이 유효한지 확인
  /// - active=false면 호출 측에서 logout 처리
  static Future<bool> isSessionActive() async {
    try {
      final user = await getUser();
      if (user == null || user.id.trim().isEmpty) return false;

      final response = await http.get(
        Uri.parse(
          '${ApiClient.baseUrl}/api/auth/session?mb_id=${Uri.encodeQueryComponent(user.id)}',
        ),
        headers: const {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        // 서버 오류 시 즉시 로그아웃하지 않고 유지(보수적)
        return true;
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map) return true;
      return decoded['active'] == true;
    } catch (_) {
      return true;
    }
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

  /// 비밀번호 변경 (로그인 상태에서 마이페이지에서 사용)
  ///
  /// - 서버 구현에 따라 엔드포인트가 다를 수 있어, 먼저 `/api/user/change-password`를 시도합니다.
  /// - 성공 시 `{ success: true }` 형태를 기대합니다.
  static Future<Map<String, dynamic>> changePassword({
    required String mbId,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/api/user/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'mbId': mbId,
          'newPassword': newPassword,
        }),
      );

      Map<String, dynamic> data = <String, dynamic>{};
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}

      final ok = response.statusCode == 200 && (data['success'] == true);
      return {
        'success': ok,
        'message': data['message']?.toString() ??
            (ok ? '비밀번호가 변경되었습니다.' : '비밀번호 변경에 실패했습니다.'),
        'statusCode': response.statusCode,
        'data': data,
      };
    } catch (e) {
      print('❌ [비밀번호 변경] 에러: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다.',
      };
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
