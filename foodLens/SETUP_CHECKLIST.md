# FoodLens Android 연동 체크리스트

## ✅ 준비 단계

- [x] FoodLensSDK 다운로드 완료
- [x] Flutter 서비스 레이어 생성 완료 (`lib/data/services/food_lens_service.dart`)
- [x] Android Plugin 생성 완료 (`foodLens/android/kotlin/com/bomiora/app/FoodLensPlugin.kt`)
- [x] 실제 SDK 연동 코드 작성 완료

## 📋 설정 단계

### 1. Android 프로젝트 확인
- [ ] `android/` 폴더 존재 확인
- [ ] 없으면 `flutter create --platforms=android .` 실행

### 2. build.gradle 설정
- [ ] `android/build.gradle`에 jcenter repository 추가
- [ ] `android/app/build.gradle`에 FoodLens SDK 의존성 추가
  ```gradle
  implementation 'com.doinglab.foodlens:FoodLens:2.6.4'
  ```
- [ ] `android/app/build.gradle`에 소스 경로 추가 (foodLens 폴더)
- [ ] `minSdkVersion 21` 설정 확인

### 3. MainActivity 생성
- [ ] `android/app/src/main/kotlin/com/bomiora/app/MainActivity.kt` 생성
- [ ] FoodLensPlugin 등록 코드 추가

### 4. AndroidManifest.xml 설정
- [ ] 카메라 권한 추가
- [ ] 인터넷 권한 추가
- [ ] `strings.xml`에 AccessToken 추가
- [ ] AndroidManifest.xml에 meta-data 추가

### 5. AccessToken 발급
- [ ] DoingLab에 AccessToken 발급 요청
- [ ] 또는 AppToken + CompanyToken 발급 요청

### 6. 테스트
- [ ] Flutter 앱 빌드 및 실행
- [ ] 음식 인식 기능 테스트

## 🔑 필수 정보

### AccessToken 발급
- DoingLab에 문의: hyunsuk.lee@doinglab.com
- 또는 [FoodLens 공식 사이트](https://www.foodlens.com)에서 신청

### SDK 버전
- 현재 최신 버전: **2.6.4**
- ReleaseNote.md에서 최신 버전 확인

### 참고 파일
- `foodLens/NEXT_STEPS.md` - 상세 설정 가이드
- `foodLens/ANDROID_SETUP.md` - Android 설정 상세
- `FoodLensSDK/Android/README.md` - 공식 문서
- `FoodLensSDK/Android/SampleCode_Kotlin/` - 샘플 코드

