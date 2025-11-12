package com.bomiora.app

import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.doinglab.foodlens.sdk.*
import com.doinglab.foodlens.sdk.errors.BaseError
import com.doinglab.foodlens.sdk.network.model.RecognitionResult
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * FoodLens SDK Flutter Plugin
 * 
 * Flutter와 Android 네이티브 FoodLens SDK 간의 통신을 담당합니다.
 */
class FoodLensPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var context: Context? = null
    private var networkService: NetworkService? = null

    companion object {
        private const val CHANNEL_NAME = "com.bomiora.app/foodlens"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
        
        // NetworkService 초기화
        context?.let {
            networkService = FoodLens.createNetworkService(it)
            networkService?.setNutritionRetrieveMode(NutritionRetrieveMode.TOP1_NUTRITION_ONLY)
            networkService?.setLanguageConfig(LanguageConfig.KO)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                handleInitialize(call, result)
            }
            "recognizeFood" -> {
                handleRecognizeFood(call, result)
            }
            "captureAndRecognize" -> {
                handleCaptureAndRecognize(call, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * FoodLens SDK 초기화
     * 
     * 참고: FoodLens SDK는 AndroidManifest.xml의 meta-data로 AccessToken을 설정합니다.
     * API Key 파라미터는 현재 사용하지 않지만, 향후 확장을 위해 유지합니다.
     */
    private fun handleInitialize(call: MethodCall, result: MethodChannel.Result) {
        try {
            val apiKey = call.argument<String>("apiKey")
            
            // NetworkService 재초기화 (이미 onAttachedToEngine에서 초기화됨)
            context?.let {
                networkService = FoodLens.createNetworkService(it)
                networkService?.setNutritionRetrieveMode(NutritionRetrieveMode.TOP1_NUTRITION_ONLY)
                networkService?.setLanguageConfig(LanguageConfig.KO)
            }
            
            android.util.Log.d("FoodLensPlugin", "SDK 초기화 완료")
            
            result.success(true)
        } catch (e: Exception) {
            android.util.Log.e("FoodLensPlugin", "초기화 오류", e)
            result.error("INIT_ERROR", "SDK 초기화 실패: ${e.message}", null)
        }
    }

    /**
     * 이미지 파일로부터 음식 인식
     */
    private fun handleRecognizeFood(call: MethodCall, result: MethodChannel.Result) {
        try {
            val imagePath = call.argument<String>("imagePath")
            
            if (imagePath.isNullOrEmpty()) {
                result.error("INVALID_ARGUMENT", "Image path is required", null)
                return
            }

            if (networkService == null) {
                result.error("NOT_INITIALIZED", "NetworkService is not initialized", null)
                return
            }

            android.util.Log.d("FoodLensPlugin", "음식 인식 요청: $imagePath")
            
            // 이미지 파일을 Bitmap으로 읽기
            val imageFile = File(imagePath)
            if (!imageFile.exists()) {
                result.error("FILE_NOT_FOUND", "Image file not found: $imagePath", null)
                return
            }
            
            val bitmap = BitmapFactory.decodeFile(imagePath)
            if (bitmap == null) {
                result.error("INVALID_IMAGE", "Failed to decode image file", null)
                return
            }
            
            // Bitmap을 JPEG byte array로 변환
            val baos = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, 90, baos)
            val imageBytes = baos.toByteArray()
            
            // FoodLens SDK로 음식 인식
            networkService?.predictMultipleFood(imageBytes, object : RecognizeResultHandler {
                override fun onSuccess(recognitionResult: RecognitionResult?) {
                    try {
                        if (recognitionResult == null || recognitionResult.foodPositions.isEmpty()) {
                            result.error("NO_FOOD_DETECTED", "음식을 인식할 수 없습니다", null)
                            return
                        }
                        
                        // 첫 번째 음식 정보 추출
                        val firstFoodPosition = recognitionResult.foodPositions[0]
                        val foods = firstFoodPosition.foods
                        
                        if (foods.isEmpty()) {
                            result.error("NO_FOOD_DETECTED", "음식을 인식할 수 없습니다", null)
                            return
                        }
                        
                        val selectedFood = firstFoodPosition.userSelectedFood ?: foods[0]
                        val nutrition = selectedFood.nutrition
                        
                        // Flutter로 전달할 결과 생성
                        val resultMap = mutableMapOf<String, Any>()
                        resultMap["foodName"] = selectedFood.foodName ?: ""
                        resultMap["foodId"] = selectedFood.foodId ?: 0
                        
                        if (nutrition != null) {
                            resultMap["calories"] = nutrition.calories ?: 0.0
                            resultMap["carbs"] = nutrition.carbonHydrate ?: 0.0
                            resultMap["protein"] = nutrition.protein ?: 0.0
                            resultMap["fat"] = nutrition.fat ?: 0.0
                            resultMap["sodium"] = nutrition.sodium ?: 0.0
                            resultMap["sugar"] = nutrition.sugar ?: 0.0
                        }
                        
                        resultMap["eatAmount"] = firstFoodPosition.eatAmount
                        resultMap["confidence"] = 1.0 // SDK에서 confidence 제공 안 함
                        
                        android.util.Log.d("FoodLensPlugin", "인식 성공: ${selectedFood.foodName}")
                        result.success(resultMap)
                    } catch (e: Exception) {
                        android.util.Log.e("FoodLensPlugin", "결과 처리 오류", e)
                        result.error("PROCESSING_ERROR", "결과 처리 실패: ${e.message}", null)
                    }
                }
                
                override fun onError(errorReason: BaseError?) {
                    val errorMessage = errorReason?.message ?: "알 수 없는 오류"
                    android.util.Log.e("FoodLensPlugin", "인식 오류: $errorMessage")
                    result.error("RECOGNITION_ERROR", errorMessage, null)
                }
            })
        } catch (e: Exception) {
            android.util.Log.e("FoodLensPlugin", "음식 인식 예외", e)
            result.error("EXCEPTION", "음식 인식 실패: ${e.message}", null)
        }
    }

    /**
     * 카메라로 음식 촬영 후 인식
     */
    private fun handleCaptureAndRecognize(call: MethodCall, result: MethodChannel.Result) {
        try {
            if (activity == null) {
                result.error("NO_ACTIVITY", "Activity is not available", null)
                return
            }

            // TODO: 실제 카메라 열기 및 FoodLensSDK 호출 코드
            // 예시:
            // val intent = Intent(activity, CameraActivity::class.java)
            // activity.startActivityForResult(intent, REQUEST_CODE_CAMERA)
            
            android.util.Log.d("FoodLensPlugin", "카메라 촬영 및 인식 요청")
            
            result.error("NOT_IMPLEMENTED", "카메라 촬영 기능은 아직 구현되지 않았습니다", null)
        } catch (e: Exception) {
            android.util.Log.e("FoodLensPlugin", "촬영/인식 오류", e)
            result.error("CAPTURE_ERROR", "촬영/인식 실패: ${e.message}", null)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        networkService = null
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}

