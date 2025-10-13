import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user/user_model.dart';

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
    
    await prefs.setString(_userKey, json.encode(user.toJson()));
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
        return UserModel.fromJson(userData);
      } catch (e) {
        print('사용자 정보 파싱 오류: $e');
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
}
