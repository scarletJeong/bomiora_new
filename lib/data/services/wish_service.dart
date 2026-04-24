import 'dart:convert';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/node_value_parser.dart';
import '../services/auth_service.dart';

class WishService {
  static const Map<String, String> _noCacheHeaders = {
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache',
  };

  static String _withNoCacheParam(String endpoint) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return endpoint.contains('?') ? '$endpoint&_ts=$ts' : '$endpoint?_ts=$ts';
  }

  static Map<String, dynamic>? _normalizeWishItem(dynamic raw) {
    if (raw is! Map) return null;
    final item = NodeValueParser.normalizeMap(Map<String, dynamic>.from(raw));
    // API는 `product_kind`(snake, Buffer)만 주는 경우가 많음 → 탭/상세와 맞추기 위해 it_kind·productKind 보강
    final productKindRaw = NodeValueParser.asString(item['product_kind']) ??
        NodeValueParser.asString(item['productKind']) ??
        '';
    final itKindRaw = NodeValueParser.asString(item['it_kind']) ??
        NodeValueParser.asString(item['itKind']) ??
        '';
    final wiKindRaw =
        NodeValueParser.asString(item['wi_it_kind']) ?? NodeValueParser.asString(item['wiItKind']) ?? '';
    final kind = wiKindRaw.isNotEmpty
        ? wiKindRaw
        : (itKindRaw.isNotEmpty ? itKindRaw : productKindRaw);

    return {
      ...item,
      'it_id':
          NodeValueParser.asString(item['it_id']) ??
          NodeValueParser.asString(item['itId']) ??
          '',
      'mb_id':
          NodeValueParser.asString(item['mb_id']) ??
          NodeValueParser.asString(item['mbId']) ??
          '',
      if (kind.isNotEmpty) 'it_kind': kind,
      if (productKindRaw.isNotEmpty) 'productKind': productKindRaw,
      if (wiKindRaw.isNotEmpty) 'wi_it_kind': wiKindRaw,
    };
  }

  /// 찜 목록 조회
  static Future<List<dynamic>> getWishList() async {
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final url = _withNoCacheParam('${ApiEndpoints.getWishList}?mb_id=${user.id}');
      final response = await ApiClient.get(url, additionalHeaders: _noCacheHeaders);

      if (response.statusCode == 404) {
        throw Exception('API 엔드포인트를 찾을 수 없습니다: $url');
      }

      if (response.statusCode == 304 || response.body.trim().isEmpty) {
        return [];
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['data'] != null && data['data'] is List) {
          final normalized = (data['data'] as List)
              .map(_normalizeWishItem)
              .whereType<Map<String, dynamic>>()
              .toList();
          return normalized;
        }
      }

      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// 찜 여부 (콘텐츠는 [productId]에 글 id 문자열, 상품은 it_id)
  static Future<bool> isWished(String productId) async {
    try {
      final user = await AuthService.getUser();
      if (user == null) return false;
      final q = Uri.encodeQueryComponent(user.id);
      final p = Uri.encodeQueryComponent(productId);
      final response = await ApiClient.get(
        '${ApiEndpoints.checkWish}?mb_id=$q&it_id=$p',
        additionalHeaders: _noCacheHeaders,
      );
      if (response.statusCode != 200) return false;
      final data = json.decode(response.body);
      if (data is! Map<String, dynamic>) return false;
      return data['is_wished'] == true;
    } catch (_) {
      return false;
    }
  }

  /// 찜 추가
  static Future<Map<String, dynamic>> addToWish(
    String productId, {
    String? wiItKind,
  }) async {
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final body = <String, dynamic>{
        'mb_id': user.id,
        'it_id': productId,
      };
      final k = wiItKind?.trim();
      if (k != null && k.isNotEmpty) {
        body['wi_it_kind'] = k;
      }

      final response = await ApiClient.post(
        ApiEndpoints.addToWish,
        body,
      );

      return json.decode(response.body);
    } catch (e) {
      throw Exception('찜 추가 실패: $e');
    }
  }

  /// 찜 삭제
  static Future<Map<String, dynamic>> removeFromWish(String productId) async {
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final response = await ApiClient.delete(
        ApiEndpoints.removeFromWish,
        data: {
          'mb_id': user.id,
          'it_id': productId,
        },
      );

      return json.decode(response.body);
    } catch (e) {
      throw Exception('찜 삭제 실패: $e');
    }
  }
}

