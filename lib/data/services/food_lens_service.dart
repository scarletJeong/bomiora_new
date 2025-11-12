import 'package:flutter/services.dart';

/// FoodLens SDK Flutter 서비스
/// 
/// Flutter에서 FoodLens SDK를 사용하기 위한 공통 인터페이스를 제공합니다.
/// Android와 iOS의 네이티브 SDK를 Platform Channel을 통해 호출합니다.
class FoodLensService {
  static const MethodChannel _channel = MethodChannel('com.bomiora.app/foodlens');

  /// FoodLens SDK 초기화
  /// 
  /// [apiKey] FoodLens API 키
  /// 
  /// Returns `true` if initialization is successful, `false` otherwise
  static Future<bool> initialize({
    required String apiKey,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'initialize',
        {'apiKey': apiKey},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('❌ FoodLens 초기화 오류: ${e.message}');
      print('   코드: ${e.code}, 상세: ${e.details}');
      return false;
    } catch (e) {
      print('❌ FoodLens 초기화 예외: $e');
      return false;
    }
  }

  /// 이미지 파일로부터 음식 인식
  /// 
  /// [imagePath] 인식할 이미지 파일 경로
  /// 
  /// Returns 음식 인식 결과 (음식명, 칼로리, 영양정보 등)
  static Future<Map<String, dynamic>?> recognizeFood({
    required String imagePath,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'recognizeFood',
        {'imagePath': imagePath},
      );
      
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      print('❌ FoodLens 인식 오류: ${e.message}');
      print('   코드: ${e.code}, 상세: ${e.details}');
      throw Exception('음식 인식 실패: ${e.message}');
    } catch (e) {
      print('❌ FoodLens 인식 예외: $e');
      throw Exception('음식 인식 실패: $e');
    }
  }

  /// 카메라로 음식 촬영 후 인식
  /// 
  /// Returns 음식 인식 결과 (음식명, 칼로리, 영양정보 등)
  static Future<Map<String, dynamic>?> captureAndRecognize() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'captureAndRecognize',
      );
      
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      print('❌ FoodLens 촬영/인식 오류: ${e.message}');
      print('   코드: ${e.code}, 상세: ${e.details}');
      throw Exception('음식 촬영/인식 실패: ${e.message}');
    } catch (e) {
      print('❌ FoodLens 촬영/인식 예외: $e');
      throw Exception('음식 촬영/인식 실패: $e');
    }
  }
}

