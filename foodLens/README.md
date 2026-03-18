# FoodLens SDK 통합

FoodLens SDK를 Flutter 앱에 통합하기 위한 네이티브 코드입니다.

## 폴더 구조

```
foodLens/
├── android/
│   └── kotlin/
│       └── com/bomiora/app/
│           └── FoodLensPlugin.kt  # Android Plugin
├── ios/
│   └── FoodLensPlugin.swift       # iOS Plugin (추후 구현)
└── README.md
```

## Android 설정

### 1. FoodLensSDK 다운로드

```bash
# GitHub에서 SDK 다운로드
git clone https://github.com/doinglab/FoodLensSDK.git
cd FoodLensSDK/Android
```

### 2. SDK를 프로젝트에 추가

- `android/app/libs/` 폴더에 `.aar` 또는 `.jar` 파일 복사
- 또는 `android/app/build.gradle`에 의존성 추가

### 3. build.gradle 설정

`android/app/build.gradle`에 다음을 추가:

```gradle
android {
    sourceSets {
        main {
            java {
                // foodLens 폴더의 Kotlin 소스 포함
                srcDirs += ['../../foodLens/android/kotlin']
            }
        }
    }
}

dependencies {
    // FoodLensSDK 의존성 추가
    // implementation files('libs/foodlens-sdk.aar')
}
```

### 4. MainActivity에 Plugin 등록

`android/app/src/main/kotlin/com/bomiora/app/MainActivity.kt`:

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

## iOS 설정 (추후 구현)

iOS는 추후 구현 예정입니다.

## 사용 방법

Flutter에서 사용:

```dart
import 'package:bomiora_app/data/services/food_lens_service.dart';

// SDK 초기화
await FoodLensService.initialize(apiKey: 'YOUR_API_KEY');

// 음식 인식
final result = await FoodLensService.recognizeFood(
  imagePath: '/path/to/image.jpg',
);
```

## 참고

- [FoodLensSDK GitHub](https://github.com/doinglab/FoodLensSDK)
- [Flutter Platform Channels](https://docs.flutter.dev/development/platform-integration/platform-channels)

