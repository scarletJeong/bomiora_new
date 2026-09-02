import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/web_history.dart';

class KakaoAuthService {
  static const _kakaoAuthTokenKey = 'kakao_auth_token';
  static const _kakaoAuthErrorKey = 'kakao_auth_error';

  static Future<void> initialize() async {
    try {
      if (kIsWeb) {
        return;
      }
      KakaoSdk.init();
    } catch (_) {}
  }

  static String buildWebOAuthReturnUrl({String? returnToAfterLogin}) {
    final origin = Uri.base.origin;
    final params = <String, String>{};
    if (returnToAfterLogin != null && returnToAfterLogin.trim().isNotEmpty) {
      params['returnTo'] = returnToAfterLogin.trim();
    }
    final loginUri =
        Uri(path: '/login', queryParameters: params.isEmpty ? null : params);
    return origin + loginUri.toString();
  }

  static String buildWebAuthorizeUrl({String? returnToAfterLogin}) {
    final returnTo =
        buildWebOAuthReturnUrl(returnToAfterLogin: returnToAfterLogin);
    return '${ApiClient.baseUrl}${ApiEndpoints.kakaoOAuthAuthorize(returnTo)}';
  }

  static String? peekWebAuthToken() {
    if (!kIsWeb) return null;
    final token = Uri.base.queryParameters[_kakaoAuthTokenKey]?.trim();
    return (token != null && token.isNotEmpty) ? token : null;
  }

  static String? peekWebAuthError() {
    if (!kIsWeb) return null;
    final error = Uri.base.queryParameters[_kakaoAuthErrorKey]?.trim();
    return (error != null && error.isNotEmpty) ? error : null;
  }

  static void clearWebAuthQueryFromUrl() {
    if (!kIsWeb) return;

    final params = Map<String, String>.from(Uri.base.queryParameters);
    params.remove(_kakaoAuthTokenKey);
    params.remove(_kakaoAuthErrorKey);

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
        Uri.parse('${ApiClient.baseUrl}${ApiEndpoints.kakaoOAuthResult(token)}'),
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
              '카카오 로그인 결과를 가져오지 못했습니다.',
        };
      }

      final data = body['data'];
      if (data is! Map) {
        return {
          'success': false,
          'error': '카카오 사용자 정보 형식이 올바르지 않습니다.',
        };
      }

      return {
        'success': true,
        'data': Map<String, dynamic>.from(data),
      };
    } catch (e) {
      return {
        'success': false,
        'error': '카카오 로그인 결과 조회 중 오류가 발생했습니다: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> login({String? returnToAfterLogin}) async {
    if (kIsWeb) {
      return _loginWeb(returnToAfterLogin: returnToAfterLogin);
    }

    try {
      late final OAuthToken token;
      try {
        token = await UserApi.instance.loginWithKakaoTalk();
      } catch (_) {
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      User user = await UserApi.instance.me();

      return {
        'success': true,
        'data': {
          'kakaoId': user.id.toString(),
          'email': user.kakaoAccount?.email,
          'nickname': user.kakaoAccount?.profile?.nickname,
          'profileImageUrl': user.kakaoAccount?.profile?.profileImageUrl,
          'accessToken': token.accessToken,
          'refreshToken': token.refreshToken,
        },
      };
    } on KakaoException catch (e) {
      return {
        'success': false,
        'error': _getErrorMessage(e),
      };
    } catch (e) {
      return {
        'success': false,
        'error': '카카오 로그인 중 오류가 발생했습니다: $e',
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
    try {
      if (kIsWeb) {
        return;
      }
      await UserApi.instance.logout();
    } catch (_) {}
  }

  static Future<void> unlink() async {
    try {
      if (kIsWeb) {
        return;
      }
      await UserApi.instance.unlink();
    } catch (_) {}
  }

  static String _getErrorMessage(KakaoException e) {
    final errorMessage = e.toString();
    if (errorMessage.contains('access_denied') || errorMessage.contains('권한')) {
      return '카카오 로그인 권한이 거부되었습니다.';
    } else if (errorMessage.contains('authentication') ||
        errorMessage.contains('인증')) {
      return '카카오 인증에 실패했습니다.';
    } else if (errorMessage.contains('invalid') || errorMessage.contains('잘못')) {
      return '잘못된 요청입니다.';
    } else if (errorMessage.contains('misconfigured') ||
        errorMessage.contains('설정')) {
      return '카카오 SDK 설정이 올바르지 않습니다.';
    } else {
      return '카카오 로그인 중 오류가 발생했습니다: ${e.toString()}';
    }
  }
}
