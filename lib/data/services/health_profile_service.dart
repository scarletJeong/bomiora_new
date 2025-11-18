import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/network/api_client.dart';
import '../../presentation/user/healthprofile/models/health_profile_model.dart';

class HealthProfileService {
  // ApiClient의 동적 baseUrl 사용 (로컬: localhost:9000, 서버: bomiora.net:9000)
  
  // 건강프로필 조회
  static Future<HealthProfileModel?> getHealthProfile(String userId) async {
    try {
      final response = await ApiClient.get('/api/healthprofile/$userId');
      
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          return HealthProfileModel.fromJson(data['data']);
        }
        return null;
      } else {
        throw Exception('건강프로필 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('건강프로필 조회 중 오류 발생: $e');
      throw Exception('건강프로필 조회 중 오류 발생: $e');
    }
  }
  
  // 건강프로필 저장
  static Future<bool> saveHealthProfile(HealthProfileModel profile) async {
    try {
      final response = await ApiClient.post('/api/healthprofile', profile.toJson());
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else {
        throw Exception('건강프로필 저장 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('건강프로필 저장 중 오류 발생: $e');
    }
  }
  
  // 건강프로필 수정
  static Future<bool> updateHealthProfile(HealthProfileModel profile) async {
    try {
      print('=== HealthProfileService.updateHealthProfile 호출 ===');
      print('pfNo: ${profile.pfNo}');
      print('요청 URL: ${ApiClient.baseUrl}/api/healthprofile/${profile.pfNo}');
      
      // PUT 대신 POST로 변경 (pfNo를 포함하여 전송)
      // 백엔드에서 pfNo가 있으면 업데이트, 없으면 생성하도록 처리
      final response = await ApiClient.post('/api/healthprofile', profile.toJson());
      
      print('HTTP 응답 상태 코드: ${response.statusCode}');
      print('HTTP 응답 본문: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else {
        throw Exception('건강프로필 수정 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('건강프로필 수정 중 오류 발생: $e');
      throw Exception('건강프로필 수정 중 오류 발생: $e');
    }
  }
  
  // 건강프로필 삭제
  static Future<bool> deleteHealthProfile(int profileId) async {
    try {
      final response = await ApiClient.delete('/api/healthprofile/$profileId');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else {
        throw Exception('건강프로필 삭제 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('건강프로필 삭제 중 오류 발생: $e');
    }
  }
  
  // 건강프로필 존재 여부 확인
  static Future<bool> hasHealthProfile(String userId) async {
    try {
      final profile = await getHealthProfile(userId);
      return profile != null;
    } catch (e) {
      return false;
    }
  }
  
  // 건강프로필 검증
  static Map<String, String> validateHealthProfile(HealthProfileModel profile) {
    final errors = <String, String>{};
    
    if (profile.answer1.isEmpty) {
      errors['answer_1'] = '생년월일을 입력해주세요';
    }
    
    if (profile.answer2.isEmpty) {
      errors['answer_2'] = '성별을 선택해주세요';
    }
    
    if (profile.answer3.isEmpty) {
      errors['answer_3'] = '목표 감량 체중을 입력해주세요';
    }
    
    if (profile.answer4.isEmpty) {
      errors['answer_4'] = '키를 입력해주세요';
    }
    
    if (profile.answer5.isEmpty) {
      errors['answer_5'] = '현재 몸무게를 입력해주세요';
    }
    
    if (profile.answer6.isEmpty) {
      errors['answer_6'] = '다이어트 예상 기간을 선택해주세요';
    }
    
    if (profile.answer7.isEmpty) {
      errors['answer_7'] = '하루 끼니를 선택해주세요';
    }
    
    if (profile.answer8.isEmpty) {
      errors['answer_8'] = '식습관을 선택해주세요';
    }
    
    if (profile.answer9.isEmpty) {
      errors['answer_9'] = '자주 먹는 음식을 입력해주세요';
    }
    
    if (profile.answer10.isEmpty) {
      errors['answer_10'] = '운동 습관을 선택해주세요';
    }
    
    return errors;
  }
  
  // BMI 계산
  static double calculateBMI(double height, double weight) {
    if (height <= 0 || weight <= 0) return 0;
    return weight / ((height / 100) * (height / 100));
  }
  
  // BMI 분류
  static String getBMICategory(double bmi) {
    if (bmi < 18.5) return '저체중';
    if (bmi < 23) return '정상';
    if (bmi < 25) return '과체중';
    if (bmi < 30) return '비만';
    return '고도비만';
  }
  
  // 권장 체중 계산
  static double getRecommendedWeight(double height) {
    // 표준 체중 = (키 - 100) * 0.9
    return (height - 100) * 0.9;
  }
  
  // 목표 체중 달성 가능성 평가
  static String evaluateWeightLossGoal(double currentWeight, double targetWeight, double height) {
    final bmi = calculateBMI(height, currentWeight);
    final targetBMI = calculateBMI(height, currentWeight - targetWeight);
    
    if (targetBMI < 18.5) {
      return '목표 체중이 너무 낮습니다. 건강한 범위 내에서 목표를 조정해주세요.';
    } else if (targetBMI < 23) {
      return '건강한 목표입니다. 꾸준히 노력하시면 달성 가능합니다.';
    } else {
      return '현재 목표로도 충분히 건강해질 수 있습니다.';
    }
  }
}

