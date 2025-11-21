package com.bomiora.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
// import com.bomiora.app.FoodLensPlugin  // 일시적으로 주석 처리 - jcenter 종료로 인한 의존성 문제

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // FoodLensPlugin 등록 (일시적으로 주석 처리)
        // flutterEngine.plugins.add(FoodLensPlugin())
    }
}

