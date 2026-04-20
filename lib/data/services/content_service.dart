import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/image_url_helper.dart';

class ContentService {
  /// Cafe24 업로드 썸네일 실제 경로 (HTML이 아닌 이미지 바이트가 내려오는 경로)
  static const String _contentThumbBase =
      'https://bomiora0.mycafe24.com/data/content/';

  static String? _extractFirstImageSrc(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final regex = RegExp(
      r'''<img[^>]*\bsrc\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    );
    final m = regex.firstMatch(text);
    final src = m?.group(1)?.trim();
    if (src == null || src.isEmpty) return null;
    return src;
  }

  static String normalizeHtmlToText(String raw) {
    var text = raw;
    text = text.replaceAll(r'\n', '\n');
    text = text.replaceAll(
      RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false),
      '\n',
    );
    text = text.replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    final lines = text
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .toList();

    final compact = <String>[];
    var blankStreak = 0;
    for (final line in lines) {
      if (line.isEmpty) {
        blankStreak += 1;
        if (blankStreak <= 1) compact.add('');
      } else {
        blankStreak = 0;
        compact.add(line);
      }
    }
    return compact.join('\n').trim();
  }

  static String prepareContentHtmlForRender(String raw) {
    if (raw.trim().isEmpty) return '';
    return raw.replaceAllMapped(
      RegExp(
        r'''(<img[^>]*\bsrc\s*=\s*["'])([^"']+)(["'][^>]*>)''',
        caseSensitive: false,
      ),
      (match) {
        final prefix = match.group(1) ?? '';
        final src = match.group(2) ?? '';
        final suffix = match.group(3) ?? '';
        final resolved = resolveThumbnailUrl(src, fallback: src);
        return '$prefix$resolved$suffix';
      },
    );
  }

  static String resolveThumbnailUrl(String? rawUrl, {String fallback = ''}) {
    final raw = (rawUrl ?? '').trim();
    if (raw.isEmpty) return fallback;

    final extracted = _extractFirstImageSrc(raw);
    final source = (extracted ?? raw).trim();

    if (source.startsWith('http://') || source.startsWith('https://')) {
      return _toWebSafeImageUrl(source);
    }

    if (source.startsWith('/')) {
      final noSlash = source.replaceFirst(RegExp(r'^/+'), '');
      if (noSlash.startsWith('bomiora0/www/data/content/')) {
        final fileName = noSlash.substring('bomiora0/www/data/content/'.length);
        return _toWebSafeImageUrl('$_contentThumbBase$fileName');
      }
      if (noSlash.startsWith('www/data/content/')) {
        final fileName = noSlash.substring('www/data/content/'.length);
        return _toWebSafeImageUrl('$_contentThumbBase$fileName');
      }
      if (noSlash.startsWith('data/content/')) {
        return _toWebSafeImageUrl('https://bomiora0.mycafe24.com/$noSlash');
      }
      if (noSlash.startsWith('content/')) {
        final fileName = noSlash.substring('content/'.length);
        return _toWebSafeImageUrl('$_contentThumbBase$fileName');
      }
      if (noSlash.startsWith('www/')) {
        return _toWebSafeImageUrl('https://bomiora0.mycafe24.com/$noSlash');
      }
      if (noSlash.startsWith('uploads/')) {
        return '${ApiClient.baseUrl}/$noSlash';
      }
    }

    final normalized = source.replaceFirst(RegExp(r'^/+'), '');
    if (normalized.startsWith('bomiora0/www/data/content/')) {
      final fileName = normalized.substring('bomiora0/www/data/content/'.length);
      return _toWebSafeImageUrl('$_contentThumbBase$fileName');
    }
    if (normalized.startsWith('www/data/content/')) {
      final fileName = normalized.substring('www/data/content/'.length);
      return _toWebSafeImageUrl('$_contentThumbBase$fileName');
    }
    if (normalized.startsWith('content/')) {
      final fileName = normalized.substring('content/'.length);
      return _toWebSafeImageUrl('$_contentThumbBase$fileName');
    }
    if (normalized.startsWith('data/content/')) {
      return _toWebSafeImageUrl('https://bomiora0.mycafe24.com/$normalized');
    }
    if (normalized.startsWith('www/')) {
      return _toWebSafeImageUrl('https://bomiora0.mycafe24.com/$normalized');
    }
    if (normalized.startsWith('uploads/')) {
      return '${ApiClient.baseUrl}/$normalized';
    }
    return '${ApiClient.baseUrl}/uploads/$normalized';
  }

  static String _toWebSafeImageUrl(String url) {
    if (!kIsWeb) return url;
    final host = Uri.base.host;
    final isLocalWeb = host == 'localhost' || host == '127.0.0.1' || host.isEmpty;
    if (!isLocalWeb) return url;
    // 로컬 웹: [ImageUrlHelper.convertToLocalUrl] — 프록시 이중 감싸기·415 방지, Cafe24 원본 직링크 사용
    return ImageUrlHelper.convertToLocalUrl(url);
  }

  static String? resolveFirstBodyImageUrl(String? html) {
    if (html == null || html.trim().isEmpty) return null;
    final src = _extractFirstImageSrc(html);
    if (src == null || src.isEmpty) return null;
    return resolveThumbnailUrl(src, fallback: '');
  }

  static String resolveDisplayImageUrl({
    String? thumbnail,
    String? contentHtml,
    required String fallback,
  }) {
    final thumbRaw = (thumbnail ?? '').trim();
    final bodyImage = resolveFirstBodyImageUrl(contentHtml);

    final thumbResolved = resolveThumbnailUrl(thumbRaw, fallback: '');
    if (thumbResolved.isNotEmpty) return thumbResolved;
    if (bodyImage != null && bodyImage.isNotEmpty) return bodyImage;
    return fallback;
  }

  static Future<Map<String, dynamic>> getContentList({
    int page = 1,
    int size = 20,
    String? query,
    String? category,
  }) async {
    try {
      final params = <String>[
        'page=$page',
        'size=$size',
      ];
      final q = (query ?? '').trim();
      if (q.isNotEmpty) {
        params.add('query=${Uri.encodeQueryComponent(q)}');
      }
      final c = (category ?? '').trim();
      if (c.isNotEmpty && c != '전체') {
        params.add('category=${Uri.encodeQueryComponent(c)}');
      }

      final endpoint = '${ApiEndpoints.getContentList}?${params.join('&')}';
      final response = await ApiClient.get(endpoint);
      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': '콘텐츠 목록을 불러오지 못했습니다.',
          'data': <Map<String, dynamic>>[],
          'categories': <String>[],
          'pagination': const <String, dynamic>{},
        };
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final dataRaw = body['data'];
      final categoryRaw = body['categories'];
      final paginationRaw = body['pagination'];

      final data = <Map<String, dynamic>>[];
      if (dataRaw is List) {
        for (final item in dataRaw) {
          if (item is Map<String, dynamic>) {
            data.add(item);
          } else if (item is Map) {
            data.add(Map<String, dynamic>.from(item));
          }
        }
      }

      final categories = <String>[];
      if (categoryRaw is List) {
        for (final item in categoryRaw) {
          final text = item?.toString().trim() ?? '';
          if (text.isNotEmpty) categories.add(text);
        }
      }

      return {
        'success': body['success'] == true,
        'data': data,
        'categories': categories,
        'pagination': paginationRaw is Map
            ? Map<String, dynamic>.from(paginationRaw)
            : <String, dynamic>{},
      };
    } catch (e) {
      return {
        'success': false,
        'message': '콘텐츠 목록 조회 오류: $e',
        'data': <Map<String, dynamic>>[],
        'categories': <String>[],
        'pagination': const <String, dynamic>{},
      };
    }
  }

  static Future<Map<String, dynamic>> getContentDetail(int id) async {
    try {
      final endpoint = '${ApiEndpoints.getContentDetail}/$id';
      final response = await ApiClient.get(endpoint);
      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': '콘텐츠 상세를 불러오지 못했습니다.',
          'data': <String, dynamic>{},
          'prev': null,
          'next': null,
        };
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final data = body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : <String, dynamic>{};
      final prev = body['prev'] is Map
          ? Map<String, dynamic>.from(body['prev'] as Map)
          : null;
      final next = body['next'] is Map
          ? Map<String, dynamic>.from(body['next'] as Map)
          : null;

      return {
        'success': body['success'] == true,
        'data': data,
        'prev': prev,
        'next': next,
      };
    } catch (e) {
      return {
        'success': false,
        'message': '콘텐츠 상세 조회 오류: $e',
        'data': <String, dynamic>{},
        'prev': null,
        'next': null,
      };
    }
  }
}

