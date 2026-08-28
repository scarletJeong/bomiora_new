import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_account_result.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import 'package:http/http.dart' as http;

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/web_history.dart';

class NaverAuthService {
  static const _naverAuthTokenKey = 'naver_auth_token';
  static const _naverAuthErrorKey = 'naver_auth_error';

  static Future<void> initialize() async {
    if (kIsWeb) {
      return;
    }
  }

  /// 웹 OAuth 복귀 URL (항상 /login 으로 돌아와 토큰 처리)
  static String buildWebOAuthReturnUrl({String? returnToAfterLogin}) {
    final origin = Uri.base.origin;
    final params = <String, String>{};
    if (returnToAfterLogin != null && returnToAfterLogin.trim().isNotEmpty) {
      params['returnTo'] = returnToAfterLogin.trim();
    }
    final loginUri = Uri(path: '/login', queryParameters: params.isEmpty ? null : params);
    return origin + loginUri.toString();
  }

  static String buildWebAuthorizeUrl({String? returnToAfterLogin}) {
    final returnTo = buildWebOAuthReturnUrl(returnToAfterLogin: returnToAfterLogin);
    return '${ApiClient.baseUrl}${ApiEndpoints.naverOAuthAuthorize(returnTo)}';
  }

  static String? peekWebAuthToken() {
    if (!kIsWeb) return null;
    final token = Uri.base.queryParameters[_naverAuthTokenKey]?.trim();
    return (token != null && token.isNotEmpty) ? token : null;
  }

  static String? peekWebAuthError() {
    if (!kIsWeb) return null;
    final error = Uri.base.queryParameters[_naverAuthErrorKey]?.trim();
    return (error != null && error.isNotEmpty) ? error : null;
  }

  static void clearWebAuthQueryFromUrl() {
    if (!kIsWeb) return;

    final params = Map<String, String>.from(Uri.base.queryParameters);
    params.remove(_naverAuthTokenKey);
    params.remove(_naverAuthErrorKey);

    final nextUri = Uri(
      scheme: Uri.base.scheme,
      host: Uri.base.host,
      port: Uri.base.hasPort ? Uri.base.port : null,
      path: Uri.base.path,
      queryParameters: params.isEmpty ? null : params,
      fragment: Uri.base.fragment.isEmpty ? null : Uri.base.fragment,
    );
    replaceBrowserUrl(nextUri.toString());
  }

  static Future<Map<String, dynamic>> fetchWebAuthResult(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}${ApiEndpoints.naverOAuthResult(token)}'),
        headers: const {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
        },
      );

      Map<String, dynamic> body = {};
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      } catch (_) {}

      if (response.statusCode != 200 || body['success'] != true) {
        return {
          'success': false,
          'error': body['message']?.toString() ??
              '네이버 로그인 결과를 가져오지 못했습니다.',
        };
      }

      final data = body['data'];
      if (data is! Map) {
        return {
          'success': false,
          'error': '네이버 사용자 정보 형식이 올바르지 않습니다.',
        };
      }

      return {
        'success': true,
        'data': Map<String, dynamic>.from(data),
      };
    } catch (e) {
      return {
        'success': false,
        'error': '네이버 로그인 결과 조회 중 오류가 발생했습니다: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> login({String? returnToAfterLogin}) async {
    if (kIsWeb) {
      return _loginWeb(returnToAfterLogin: returnToAfterLogin);
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

  static Future<Map<String, dynamic>> _loginWeb({String? returnToAfterLogin}) async {
    final url = buildWebAuthorizeUrl(returnToAfterLogin: returnToAfterLogin);
    return {
      'success': false,
      'needsRedirect': true,
      'redirectUrl': url,
    };
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
