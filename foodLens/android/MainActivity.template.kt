package com.bomiora.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * MainActivity
 * 
 * 이 파일을 android/app/src/main/kotlin/com/bomiora/app/MainActivity.kt 에 복사하세요.
 * 
 * 만약 MainActivity가 이미 존재한다면, configureFlutterEngine 메서드에
 * FoodLensPlugin 등록 코드만 추가하면 됩니다.
 */
class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // FoodLensPlugin 등록
        flutterEngine.plugins.add(FoodLensPlugin())
    }
}

