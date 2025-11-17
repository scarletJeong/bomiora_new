import 'dart:convert';
import '../../core/network/api_client.dart';

/// 배송지 관리 서비스
class AddressService {
  /// 배송지 목록 조회
  static Future<List<Map<String, dynamic>>> getAddressList(String mbId) async {
    try {
      print('📦 [배송지 목록 조회] 요청 - mbId: $mbId');
      
      final response = await ApiClient.get('/api/user/address?mbId=$mbId');
      
      print('📡 [배송지 목록 조회] 응답 상태: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> addressList = data['data'];
          print('✅ [배송지 목록 조회] 성공: ${addressList.length}개');
          return addressList.cast<Map<String, dynamic>>();
        }
      }
      
      print('❌ [배송지 목록 조회] 실패');
      return [];
    } catch (e) {
      print('❌ [배송지 목록 조회] 에러: $e');
      return [];
    }
  }
  
  /// 배송지 추가
  static Future<Map<String, dynamic>> addAddress(Map<String, dynamic> addressData) async {
    try {
      print('📦 [배송지 추가] 요청');
      
      final response = await ApiClient.post('/api/user/address', addressData);
      
      print('📡 [배송지 추가] 응답 상태: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ [배송지 추가] 성공');
        
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'] ?? '배송지가 추가되었습니다.',
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['error'] ?? '배송지 추가에 실패했습니다.',
        };
      }
    } catch (e) {
      print('❌ [배송지 추가] 에러: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다.',
      };
    }
  }
  
  /// 배송지 수정
  static Future<Map<String, dynamic>> updateAddress(int id, Map<String, dynamic> addressData) async {
    try {
      print('📦 [배송지 수정] 요청 - id: $id');
      
      final response = await ApiClient.put('/api/user/address/$id', addressData);
      
      print('📡 [배송지 수정] 응답 상태: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ [배송지 수정] 성공');
        
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'] ?? '배송지가 수정되었습니다.',
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['error'] ?? '배송지 수정에 실패했습니다.',
        };
      }
    } catch (e) {
      print('❌ [배송지 수정] 에러: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다.',
      };
    }
  }
  
  /// 배송지 삭제
  static Future<Map<String, dynamic>> deleteAddress(int id, String mbId) async {
    try {
      print('📦 [배송지 삭제] 요청 - id: $id');
      
      final response = await ApiClient.delete('/api/user/address/$id?mbId=$mbId');
      
      print('📡 [배송지 삭제] 응답 상태: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ [배송지 삭제] 성공');
        
        return {
          'success': true,
          'message': data['message'] ?? '배송지가 삭제되었습니다.',
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['error'] ?? '배송지 삭제에 실패했습니다.',
        };
      }
    } catch (e) {
      print('❌ [배송지 삭제] 에러: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다.',
      };
    }
  }
}

