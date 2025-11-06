import 'dart:convert';
import '../models/contact/contact_model.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../services/auth_service.dart';

class ContactService {
  /// 내 문의내역 조회
  static Future<List<Contact>> getMyContacts() async {
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final response = await ApiClient.get(
        '${ApiEndpoints.getMyContacts}?mb_id=${user.id}',
      );

      final responseData = json.decode(response.body);
      
      if (responseData['success'] == true && responseData['data'] != null) {
        final List<dynamic> dataList = responseData['data'];
        return dataList.map((json) => Contact.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      throw Exception('문의내역 조회 실패: $e');
    }
  }

  /// 문의 상세 조회
  static Future<Contact?> getContactDetail(int wrId) async {
    try {
      final response = await ApiClient.get(
        '${ApiEndpoints.getContactDetail}/$wrId',
      );

      final responseData = json.decode(response.body);

      if (responseData['success'] == true && responseData['data'] != null) {
        return Contact.fromJson(responseData['data']);
      }

      return null;
    } catch (e) {
      throw Exception('문의 상세 조회 실패: $e');
    }
  }

  /// 문의 답변 목록 조회
  static Future<List<Contact>> getContactReplies(int wrId) async {
    try {
      final response = await ApiClient.get(
        '${ApiEndpoints.getContactReplies}/$wrId/replies',
      );

      final responseData = json.decode(response.body);

      if (responseData['success'] == true && responseData['data'] != null) {
        final List<dynamic> dataList = responseData['data'];
        return dataList.map((json) => Contact.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      throw Exception('답변 목록 조회 실패: $e');
    }
  }

  /// 문의 작성
  static Future<Map<String, dynamic>> createContact({
    required String subject,
    required String content,
  }) async {
    try {
      final user = await AuthService.getUser();

      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final response = await ApiClient.post(
        ApiEndpoints.createContact,
        {
          'mb_id': user.id,
          'wr_name': user.name ?? user.id,
          'wr_email': user.email ?? '',
          'wr_subject': subject,
          'wr_content': content,
        },
      );

      return json.decode(response.body);
    } catch (e) {
      throw Exception('문의 작성 실패: $e');
    }
  }
}

