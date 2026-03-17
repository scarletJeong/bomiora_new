import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

class KakaoAuthService {
  // 카카오 SDK 초기화
  static Future<void> initialize() async {
    try {
      // 웹 환경에서는 JavaScript SDK를 사용하므로 별도 초기화 불필요
      if (kIsWeb) {
        print('✅ [KakaoAuth] 웹 환경 - 카카오 JavaScript SDK 사용');
        return;
      }

      // 모바일 환경: 카카오 SDK 초기화
      // Native App Key는 AndroidManifest.xml과 Info.plist에 설정되어 있어야 함
      // 실제 앱 키는 AndroidManifest.xml의 <meta-data android:name="com.kakao.sdk.AppKey" android:value="YOUR_APP_KEY" />
      // 또는 Info.plist의 KAKAO_APP_KEY에 설정되어 있어야 함
      KakaoSdk.init();
      print('✅ [KakaoAuth] 카카오 SDK 초기화 완료');
    } catch (e) {
      print('❌ [KakaoAuth] 카카오 SDK 초기화 실패: $e');
    }
  }

  // 카카오 로그인
  static Future<Map<String, dynamic>> login() async {
    try {
      // 웹 환경: OAuth 리다이렉트 방식 사용
      if (kIsWeb) {
        return await _loginWeb();
      }

      // 카카오톡으로 로그인 시도
      OAuthToken? token;
      
      try {
        // 카카오톡 앱이 설치되어 있으면 카카오톡으로 로그인 시도
        token = await UserApi.instance.loginWithKakaoTalk();
        print('✅ [KakaoAuth] 카카오톡으로 로그인 성공');
      } catch (e) {
        // 카카오톡 앱이 없거나 로그인 실패 시 카카오계정으로 로그인
        print('⚠️ [KakaoAuth] 카카오톡 로그인 실패, 카카오계정으로 시도: $e');
        token = await UserApi.instance.loginWithKakaoAccount();
        print('✅ [KakaoAuth] 카카오계정으로 로그인 성공');
      }

      if (token == null) {
        return {
          'success': false,
          'error': '카카오 로그인에 실패했습니다.',
        };
      }

      // 사용자 정보 가져오기
      User user = await UserApi.instance.me();
      
      print('👤 [KakaoAuth] 사용자 정보:');
      print('   - ID: ${user.id}');
      print('   - 닉네임: ${user.kakaoAccount?.profile?.nickname}');
      print('   - 이메일: ${user.kakaoAccount?.email}');
      print('   - 프로필 이미지: ${user.kakaoAccount?.profile?.profileImageUrl}');

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
      print('❌ [KakaoAuth] 카카오 로그인 오류: $e');
      return {
        'success': false,
        'error': _getErrorMessage(e),
      };
    } catch (e) {
      print('❌ [KakaoAuth] 예외 발생: $e');
      return {
        'success': false,
        'error': '카카오 로그인 중 오류가 발생했습니다: $e',
      };
    }
  }

  // 카카오 로그아웃
  static Future<void> logout() async {
    try {
      if (kIsWeb) {
        print('⚠️ [KakaoAuth] 웹 환경에서는 카카오 로그아웃을 사용할 수 없습니다.');
        return;
      }

      await UserApi.instance.logout();
      print('✅ [KakaoAuth] 카카오 로그아웃 완료');
    } catch (e) {
      print('❌ [KakaoAuth] 카카오 로그아웃 오류: $e');
    }
  }

  // 카카오 계정 연결 해제
  static Future<void> unlink() async {
    try {
      if (kIsWeb) {
        print('⚠️ [KakaoAuth] 웹 환경에서는 카카오 계정 연결 해제를 사용할 수 없습니다.');
        return;
      }

      await UserApi.instance.unlink();
      print('✅ [KakaoAuth] 카카오 계정 연결 해제 완료');
    } catch (e) {
      print('❌ [KakaoAuth] 카카오 계정 연결 해제 오류: $e');
    }
  }


  // 웹 환경 카카오 로그인 (서버 API를 통한 처리)
  static Future<Map<String, dynamic>> _loginWeb() async {
    try {
      // 웹 환경에서는 서버 API를 통해 카카오 로그인을 처리
      // 서버에서 카카오 OAuth를 처리하고 사용자 정보를 반환
      // 여기서는 서버 API를 호출하는 방식으로 처리
      
      // 서버의 카카오 로그인 엔드포인트 호출
      // 서버에서 카카오 OAuth URL로 리다이렉트하거나
      // 팝업을 통해 카카오 로그인을 처리
      
      // 임시로 서버 API를 통해 처리
      // 실제로는 서버에서 카카오 JavaScript SDK를 사용하여 처리
      return {
        'success': false,
        'error': '웹 환경에서는 서버 API를 통해 카카오 로그인을 처리해야 합니다. 서버에 카카오 로그인 엔드포인트를 구현해주세요.',
        'needsServerAuth': true,
      };
    } catch (e) {
      print('❌ [KakaoAuth] 웹 카카오 로그인 오류: $e');
      return {
        'success': false,
        'error': '카카오 로그인 중 오류가 발생했습니다: $e',
      };
    }
  }

  // 에러 메시지 변환
  static String _getErrorMessage(KakaoException e) {
    // KakaoException의 메시지를 직접 사용하거나, 기본 메시지 반환
    final errorMessage = e.toString();
    
    // 에러 메시지에 따라 사용자 친화적인 메시지로 변환
    if (errorMessage.contains('access_denied') || errorMessage.contains('권한')) {
      return '카카오 로그인 권한이 거부되었습니다.';
    } else if (errorMessage.contains('authentication') || errorMessage.contains('인증')) {
      return '카카오 인증에 실패했습니다.';
    } else if (errorMessage.contains('invalid') || errorMessage.contains('잘못')) {
      return '잘못된 요청입니다.';
    } else if (errorMessage.contains('misconfigured') || errorMessage.contains('설정')) {
      return '카카오 SDK 설정이 올바르지 않습니다.';
    } else {
      return '카카오 로그인 중 오류가 발생했습니다: ${e.toString()}';
    }
  }
}
