import 'dart:convert';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/faq/faq_model.dart';

class FaqService {
  static Future<Map<String, dynamic>> getFaqList({
    int page = 1,
    int size = 20,
    String query = '',
    String category = '전체',
  }) async {
    try {
      final endpoint =
          '${ApiEndpoints.getFaqList}?page=$page&size=$size&query=${Uri.encodeComponent(query)}&category=${Uri.encodeComponent(category)}';
      final response = await ApiClient.get(endpoint);
      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': 'FAQ 목록을 불러오지 못했습니다.',
          'items': <FaqModel>[],
          'categories': <String>['전체'],
          'total': 0,
          'page': page,
          'size': size,
          'totalPages': 0,
        };
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final items = <FaqModel>[];
      final rawData = body['data'];
      if (rawData is List) {
        for (final e in rawData) {
          if (e is Map) {
            items.add(FaqModel.fromJson(Map<String, dynamic>.from(e)));
          }
        }
      }

      final rawCategories = body['categories'];
      final categories = <String>[];
      if (rawCategories is List) {
        for (final c in rawCategories) {
          final text = c?.toString() ?? '';
          if (text.isNotEmpty) categories.add(text);
        }
      }
      if (!categories.contains('전체')) {
        categories.insert(0, '전체');
      }

      final pagination = body['pagination'] as Map<String, dynamic>?;

      return {
        'success': body['success'] == true,
        'message': body['message']?.toString(),
        'items': items,
        'categories': categories,
        'total': pagination?['total'] ?? items.length,
        'page': pagination?['page'] ?? page,
        'size': pagination?['size'] ?? size,
        'totalPages': pagination?['totalPages'] ?? 1,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'FAQ 목록 조회 오류: $e',
        'items': <FaqModel>[],
        'categories': <String>['전체'],
        'total': 0,
        'page': page,
        'size': size,
        'totalPages': 0,
      };
    }
  }

  static Future<Map<String, dynamic>> getFaqDetail(int id) async {
    try {
      final endpoint = '${ApiEndpoints.getFaqDetail}/$id';
      final response = await ApiClient.get(endpoint);
      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': 'FAQ 상세를 불러오지 못했습니다.',
          'item': null,
        };
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final itemRaw = body['data'];
      return {
        'success': body['success'] == true,
        'message': body['message']?.toString(),
        'item': itemRaw is Map
            ? FaqModel.fromJson(Map<String, dynamic>.from(itemRaw))
            : null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'FAQ 상세 조회 오류: $e',
        'item': null,
      };
    }
  }
}
