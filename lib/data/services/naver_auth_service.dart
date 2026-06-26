import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_account_result.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';

class NaverAuthService {
  static Future<void> initialize() async {
    if (kIsWeb) {
      return;
    }
  }

  static Future<Map<String, dynamic>> login() async {
    if (kIsWeb) {
      return {
        'success': false,
        'error': '웹 환경에서는 네이버 로그인을 지원하지 않습니다.',
        'needsServerAuth': true,
      };
    }

    try {
      final res = await FlutterNaverLogin.logIn();

      if (res.status != NaverLoginStatus.loggedIn) {
        final cancelled = res.status == NaverLoginStatus.loggedOut;
        return {
          'success': false,
          'cancelled': cancelled,
          if (!cancelled)
            'error': res.errorMessage ?? '네이버 로그인에 실패했습니다.',
        };
      }

      NaverAccountResult account = res.account ??
          await FlutterNaverLogin.getCurrentAccount();

      if ((account.id ?? '').isEmpty) {
        return {
          'success': false,
          'error': '네이버 사용자 정보를 가져오지 못했습니다.',
        };
      }

      String? accessToken;
      final token = res.accessToken;
      if (token != null && token.isValid()) {
        accessToken = token.accessToken;
      } else {
        try {
          final currentToken = await FlutterNaverLogin.getCurrentAccessToken();
          if (currentToken.isValid()) {
            accessToken = currentToken.accessToken;
          }
        } catch (_) {}
      }

      return {
        'success': true,
        'data': {
          'naverId': account.id!,
          'email': _nullIfEmpty(account.email),
          'nickname': _nullIfEmpty(account.nickname),
          'name': _nullIfEmpty(account.name),
          'profileImageUrl': _nullIfEmpty(account.profileImage),
          'mobile': _nullIfEmpty(account.mobile),
          'gender': _normalizeGender(account.gender),
          'birthday': _formatBirthday(account.birthYear, account.birthday),
          'accessToken': accessToken,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': '네이버 로그인 중 오류가 발생했습니다: $e',
      };
    }
  }

  static Future<void> logout() async {
    if (kIsWeb) {
      return;
    }

    try {
      await FlutterNaverLogin.logOutAndDeleteToken();
    } catch (_) {}
  }

  static String? _nullIfEmpty(String? value) {
    final trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _normalizeGender(String? value) {
    final v = (value ?? '').trim().toUpperCase();
    if (v == 'M' || v == 'F') {
      return v;
    }
    return null;
  }

  static String? _formatBirthday(String? birthyear, String? birthday) {
    final year = (birthyear ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final dayPart = (birthday ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (year.length == 4 && dayPart.length == 4) {
      return '$year$dayPart';
    }
    return null;
  }
}
