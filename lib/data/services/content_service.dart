import 'dart:convert';

import '../../core/load/list_load.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/image_url_helper.dart';
import '../models/content/content_post.dart';

class ContentService {
  static const Duration _detailCacheTtl = Duration(minutes: 2);
  static final Map<String, ContentDetailResult> _detailCache = {};
  static final Map<String, DateTime> _detailCacheAt = {};
  static final Map<String, Future<ContentDetailResult>> _detailInFlight = {};

  static ContentDetailResult? peekDetail(int id) {
    ContentDetailResult? best;
    DateTime? bestAt;
    final prefix = '$id|';
    for (final key in _detailCache.keys) {
      if (!key.startsWith(prefix)) continue;
      final at = _detailCacheAt[key];
      if (at == null) continue;
      if (bestAt == null || at.isAfter(bestAt)) {
        bestAt = at;
        best = _detailCache[key];
      }
    }
    if (best == null || bestAt == null) return null;
    if (DateTime.now().difference(bestAt) >= _detailCacheTtl) return null;
    return best;
  }

  static void rememberRecommend({
    required int id,
    required bool recommended,
    required int count,
  }) {
    final prefix = '$id|';
    for (final key in _detailCache.keys) {
      if (!key.startsWith(prefix)) continue;
      final cached = _detailCache[key];
      final post = cached?.post;
      if (cached == null || post == null) continue;
      _detailCache[key] = cached.copyWith(
        post: post.copyWith(
          userRecommended: recommended,
          recommendCount: count,
        ),
      );
    }
  }

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
    return text.replaceAll('\r\n', '\n').trim();
  }

  static String prepareContentHtmlForRender(String raw) {
    if (raw.trim().isEmpty) return '';
    final withBreaks = raw.replaceAll('\r\n', '\n').replaceAll(r'\n', '\n');
    final withoutInlineFontSize = withBreaks
        .replaceAll(
          RegExp(r'font-size\s*:\s*[^;}"\x27]+;?', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(
            '''\\ssize\\s*=\\s*["\\x27]?\\d+["\\x27]?''',
            caseSensitive: false,
          ),
          '',
        );
    return withoutInlineFontSize.replaceAllMapped(
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
      if (noSlash.startsWith('data/')) {
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
    if (normalized.startsWith('data/')) {
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
    return ImageUrlHelper.toWebSafeImageUrl(url);
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

  static Future<ListLoad<ContentPost>>? _homePreviewInflight;
  static ListLoad<ContentPost>? _homePreviewCache;

  /// 메인 「건강 컨텐츠」 3건. 스플래시와 홈이 같은 요청을 나눠 쓰지 않도록 묶는다.
  static Future<ListLoad<ContentPost>> getHomePreviewList() {
    final cached = _homePreviewCache;
    if (cached != null) return Future.value(cached);
    final inflight = _homePreviewInflight;
    if (inflight != null) return inflight;
    late final Future<ListLoad<ContentPost>> future;
    future = getContentList(page: 1, size: 3).then((result) {
      if (identical(_homePreviewInflight, future)) {
        _homePreviewInflight = null;
      }
      if (!result.failed) {
        _homePreviewCache = result;
      }
      return result;
    });
    _homePreviewInflight = future;
    return future;
  }

  static Future<ListLoad<ContentPost>> getContentList({
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
        return ListLoad.failure();
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map || decoded['success'] != true) {
        return ListLoad.failure();
      }
      final body = Map<String, dynamic>.from(decoded);
      final dataRaw = body['data'];
      final data = <ContentPost>[];
      if (dataRaw is List) {
        for (final item in dataRaw) {
          if (item is Map) {
            data.add(ContentPost.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }

      final paginationRaw = body['pagination'];
      final pagination = paginationRaw is Map
          ? Map<String, dynamic>.from(paginationRaw)
          : const <String, dynamic>{};
      final totalRaw = pagination['total'];
      final total = totalRaw is num ? totalRaw.toInt() : data.length;
      return ListLoad.success(data, total: total);
    } catch (_) {
      return ListLoad.failure();
    }
  }

  /// [mbId]가 있으면 서버에 `user_recommended` 여부를 함께 조회(회원당 글당 1회).
  static Future<ContentDetailResult> getContentDetail(
    int id, {
    String? mbId,
  }) async {
    final key = '$id|${(mbId ?? '').trim()}';
    final cachedAt = _detailCacheAt[key];
    if (cachedAt != null &&
        DateTime.now().difference(cachedAt) < _detailCacheTtl) {
      return _detailCache[key]!;
    }
    final pending = _detailInFlight[key];
    if (pending != null) return pending;

    final request = _fetchContentDetail(id, mbId: mbId);
    _detailInFlight[key] = request;
    try {
      final result = await request;
      if (result.success) {
        _detailCache[key] = result;
        _detailCacheAt[key] = DateTime.now();
      }
      return result;
    } finally {
      _detailInFlight.remove(key);
    }
  }

  static Future<ContentDetailResult> _fetchContentDetail(
    int id, {
    String? mbId,
  }) async {
    try {
      final q = <String>[];
      final m = (mbId ?? '').trim();
      if (m.isNotEmpty) {
        q.add('mb_id=${Uri.encodeQueryComponent(m)}');
      }
      final query = q.isNotEmpty ? '?${q.join('&')}' : '';
      final endpoint = '${ApiEndpoints.getContentDetail}/$id$query';
      final response = await ApiClient.get(endpoint);
      if (response.statusCode != 200) {
        return const ContentDetailResult(success: false);
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map) {
        return const ContentDetailResult(success: false);
      }
      final body = Map<String, dynamic>.from(decoded);
      if (body['success'] != true) {
        return const ContentDetailResult(success: false);
      }
      final data = body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : <String, dynamic>{};

      return ContentDetailResult(
        success: true,
        post: ContentPost.fromJson(data),
        previous: ContentNeighbor.fromDynamic(body['prev']),
        next: ContentNeighbor.fromDynamic(body['next']),
      );
    } catch (_) {
      return const ContentDetailResult(success: false);
    }
  }

  /// 콘텐츠 추천 토글 (엄지업 설정/해제)
  static Future<Map<String, dynamic>> recommendContent(
    int id, {
    required String mbId,
    bool? recommended,
    int? recommendCount,
  }) async {
    try {
      if (recommended != null) {
        rememberRecommend(
          id: id,
          recommended: recommended,
          count: recommendCount ?? 0,
        );
      }
      final response = await ApiClient.post(
        ApiEndpoints.contentRecommend(id),
        <String, dynamic>{
          'mb_id': mbId,
          if (recommended != null) 'recommended': recommended,
          if (recommendCount != null) 'recommend_count': recommendCount,
        },
      );
      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': '추천 처리에 실패했습니다.',
        };
      }
      final body = json.decode(response.body);
      if (body is! Map<String, dynamic>) {
        return {'success': false, 'message': '응답 형식이 올바르지 않습니다.'};
      }
      return Map<String, dynamic>.from(body);
    } catch (e) {
      return {
        'success': false,
        'message': '네트워크 오류: $e',
      };
    }
  }
}

