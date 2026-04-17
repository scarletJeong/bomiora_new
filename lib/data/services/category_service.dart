import 'dart:convert';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';

class CategoryService {
  static Future<Map<String, dynamic>> getCategoriesByGroup(String grp) async {
    try {
      final endpoint =
          '${ApiEndpoints.getCategoryList}?grp=${Uri.encodeComponent(grp)}';
      final response = await ApiClient.get(endpoint);
      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': '카테고리 목록을 불러오지 못했습니다.',
          'categories': <String>[],
        };
      }
      final body = json.decode(response.body) as Map<String, dynamic>;
      final data = body['data'];
      final categories = <String>[];
      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            final name = item['category_name']?.toString().trim() ?? '';
            if (name.isNotEmpty) categories.add(name);
          }
        }
      }
      return {
        'success': body['success'] == true,
        'categories': categories,
      };
    } catch (e) {
      return {
        'success': false,
        'message': '카테고리 조회 오류: $e',
        'categories': <String>[],
      };
    }
  }
}
