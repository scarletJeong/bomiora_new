import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Apple 로그인. iOS는 네이티브, Android·웹은 Service ID + redirect가 필요합니다.
class AppleAuthService {
  AppleAuthService._();

  static const serviceId = String.fromEnvironment(
    'APPLE_SERVICE_ID',
    defaultValue: 'com.bomiora.app.signin',
  );
  static const redirectUri = String.fromEnvironment(
    'APPLE_REDIRECT_URI',
    defaultValue: 'https://bomiora.net/api/auth/apple/callback',
  );

  static bool get _needsWebOptions =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  static Future<Map<String, dynamic>> login() async {
    try {
      final available = await SignInWithApple.isAvailable();
      if (!available) {
        return {
          'success': false,
          'error': '이 기기에서는 Apple 로그인을 사용할 수 없습니다.',
        };
      }

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: _needsWebOptions
            ? WebAuthenticationOptions(
                clientId: serviceId,
                redirectUri: Uri.parse(redirectUri),
              )
            : null,
      );

      final appleId = credential.userIdentifier?.trim() ?? '';
      if (appleId.isEmpty) {
        return {
          'success': false,
          'error': 'Apple 사용자 정보를 가져오지 못했습니다.',
        };
      }

      final given = credential.givenName?.trim() ?? '';
      final family = credential.familyName?.trim() ?? '';
      final name = [family, given].where((e) => e.isNotEmpty).join(' ');

      return {
        'success': true,
        'data': {
          'appleId': appleId,
          'email': credential.email,
          'name': name.isEmpty ? null : name,
          'identityToken': credential.identityToken,
          'authorizationCode': credential.authorizationCode,
        },
      };
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return {
          'success': false,
          'cancelled': true,
        };
      }
      return {
        'success': false,
        'error': 'Apple 로그인에 실패했습니다.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Apple 로그인 중 오류가 발생했습니다: $e',
      };
    }
  }
}
