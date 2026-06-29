# Firebase FCM 설정 가이드

Android FCM 빌드·테스트 전에 **Firebase 콘솔 설정**이 필요합니다.

## 파일 구분 (중요)

| 파일 | 용도 | 위치 |
|------|------|------|
| **`google-services.json`** | Android **앱** (토큰 발급) | `android/app/google-services.json` |
| **`firebase-bomiora.json`** | **백엔드** Admin SDK (푸시 발송) | `bomiora_back/config/firebase-bomiora.json` |

> Admin SDK 키(`firebase-bomiora.json`)는 **Flutter 앱에 넣지 않습니다.**  
> 백엔드 API는 [bomiora_back/docs/fcm-backend.md](../../../bomioraProject/bomiora_back/docs/fcm-backend.md) 참고.

## 1. Firebase 프로젝트 생성

1. [Firebase Console](https://console.firebase.google.com/) 접속
2. 프로젝트 추가 (또는 기존 프로젝트 선택)
3. **Android 앱 추가**
   - 패키지명: `com.bomiora.app` (반드시 동일)
   - 앱 닉네임: 보미오라 (임의)

## 2. google-services.json 배치

1. Firebase에서 `google-services.json` 다운로드
2. 아래 경로에 **복사** (example 파일을 덮어씀):

```
android/app/google-services.json
```

> example 파일(`google-services.json.example`)은 구조 참고용입니다.  
> **실제 Firebase에서 받은 JSON**을 사용해야 FCM 토큰이 발급됩니다.

## 3. 빌드 & 실행

```bash
flutter pub get
flutter run
```

앱 시작 시 `main.dart`에서 `Firebase.initializeApp()` → `FCMService().initialize()` 가 실행됩니다.

## 4. 토큰 확인

로그인 후 Logcat에서 `[FCM]` 또는 `FirebaseMessaging` 로그 확인.  
또는 디버그:

```dart
debugPrint(FCMService().fcmToken);
```

## 5. 테스트 푸시 (Firebase Console)

1. Firebase Console → **Messaging** → 새 캠페인
2. 테스트 메시지 → FCM 등록 토큰 입력
3. 추가 옵션 → **사용자 지정 데이터** 예시:

| key | value | 이동 화면 |
|-----|-------|-----------|
| `type` | `order` | 주문 상세 |
| `od_id` | `20260331001` | 주문번호 |
| `type` | `delivery` | 배송 목록/상세 |
| `type` | `event` | 이벤트 |
| `id` | `123` | 이벤트 ID |
| `type` | `announcement` | 공지 |
| `id` | `45` | 공지 ID |

## 6. 백엔드 API (연동 예정)

| 메서드 | 경로 | 본문 |
|--------|------|------|
| POST | `/api/user/fcm-token` | `{ mb_id, fcm_token, platform }` |
| GET | `/api/user/notification-settings?mb_id=` | — |
| PUT | `/api/user/notification-settings` | `{ mb_id, order_agree, marketing_agree, app_push_agree, sms_agree }` |

API가 404이면 **로컬(SharedPreferences) 저장만** 동작합니다.  
백엔드 배포 후 `sql/bomiora_member_fcm_notification.sql` 실행 필요.

## 7. 알림 설정 화면

**설정 → 알림 설정** (`NotificationSettingsScreen`)

- 주문 정보 알림 / 마케팅(앱 푸시·SMS) 토글
- 저장 시 로컬 + 서버 동기화, FCM 토픽(`orders`, `marketing`) 구독/해제

## 8. 웹 개발

웹(`flutter run -d chrome`)은 `fcm_service_stub.dart`를 사용하므로 Firebase 없이 동작합니다.

## 9. 문제 해결

| 증상 | 확인 |
|------|------|
| `Firebase.initializeApp` 실패 | `google-services.json` 경로·패키지명 |
| 토큰 null | Google Play Services (에뮬레이터는 Play Store 이미지) |
| 알림 안 옴 | Android 13+ 알림 권한 허용, 채널 `high_importance_channel` |
| 빌드 오류 google-services | `android/app/build.gradle.kts`에 `com.google.gms.google-services` 플러그인 |
