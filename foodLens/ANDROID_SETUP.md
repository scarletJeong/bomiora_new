# Android FoodLens SDK 설정 가이드

## 1단계: FoodLensSDK 다운로드

```bash
# GitHub 저장소 클론
git clone https://github.com/doinglab/FoodLensSDK.git

# Android SDK 폴더로 이동
cd FoodLensSDK/Android
```

## 2단계: SDK 파일 확인

다음 중 하나의 형태로 SDK가 제공됩니다:
- `.aar` 파일 (Android Archive)
- `.jar` 파일 (Java Archive)
- Gradle 의존성 (Maven 등)

## 3단계: 프로젝트에 SDK 추가

### 방법 A: AAR/JAR 파일 직접 추가

1. `android/app/libs/` 폴더 생성 (없는 경우)
2. SDK 파일을 `libs/` 폴더에 복사
3. `android/app/build.gradle`에 추가:

```gradle
dependencies {
    implementation files('libs/foodlens-sdk.aar')
    // 또는
    // implementation files('libs/foodlens-sdk.jar')
}
```

### 방법 B: Maven/Gradle 의존성 추가

`android/app/build.gradle`에 추가:

```gradle
repositories {
    maven {
        url 'https://your-maven-repo-url'
    }
}

dependencies {
    implementation 'com.doinglab:foodlens:1.0.0'
}
```

## 4단계: build.gradle 소스 경로 설정

`android/app/build.gradle`에 foodLens 폴더의 소스를 포함:

```gradle
android {
    // ...
    
    sourceSets {
        main {
            java {
                // foodLens 폴더의 Kotlin 소스 포함
                srcDirs += ['../../foodLens/android/kotlin']
            }
        }
    }
    
    // Kotlin 설정
    kotlin {
        sourceSets {
            main {
                kotlin.srcDirs += ['../../foodLens/android/kotlin']
            }
        }
    }
}
```

## 5단계: MainActivity 생성/수정

`android/app/src/main/kotlin/com/bomiora/app/MainActivity.kt` 파일 생성 또는 수정:

```kotlin
package com.bomiora.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // FoodLensPlugin 등록
        flutterEngine.plugins.add(FoodLensPlugin())
    }
}
```

## 6단계: AndroidManifest.xml 권한 추가

`android/app/src/main/AndroidManifest.xml`에 카메라 권한 추가:

```xml
<manifest>
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    
    <application>
        <!-- ... -->
    </application>
</manifest>
```

## 7단계: FoodLensPlugin.kt에서 실제 SDK 연동

`foodLens/android/kotlin/com/bomiora/app/FoodLensPlugin.kt` 파일의 TODO 부분을 실제 SDK 호출 코드로 교체:

```kotlin
// initialize 메서드
FoodLensSDK.initialize(apiKey)

// recognizeFood 메서드
val recognitionResult = FoodLensSDK.recognize(imagePath)
```

## 8단계: 테스트

Flutter 앱 실행:

```bash
flutter run
```

## 문제 해결

### 빌드 오류: 소스를 찾을 수 없음
- `build.gradle`의 `srcDirs` 경로가 올바른지 확인
- 상대 경로는 `android/app/` 폴더 기준

### Plugin을 찾을 수 없음
- MainActivity에서 FoodLensPlugin import 확인
- 패키지 이름이 일치하는지 확인

### SDK 초기화 실패
- API Key가 올바른지 확인
- SDK 파일이 제대로 추가되었는지 확인
- 로그 확인: `adb logcat | grep FoodLensPlugin`

