import 'package:flutter/foundation.dart';

import '../network/api_client.dart';

/// 이미지 URL 정규화 헬퍼
///
/// **Cafe24 `data/` 정적 파일** (상품·리뷰·배너·미러 업로드 등)
/// → `https://bomiora0.mycafe24.com/...` 직링크 (Node `/api/proxy/image` 사용 안 함)
/// → Cafe24 nginx CORS: `Access-Control-Allow-Origin: https://bomiora.net`
/// → `data/.htaccess` 에 ACAO 추가 금지 (nginx 와 중복 시 브라우저 CORS 실패)
///
/// **Node API 정적** (`/api/health/...`, `/api/user/reviews/images/...` 등)
/// → [ApiClient.baseUrl] origin
class ImageUrlHelper {
  static const _cafe24CanonicalHost = 'https://bomiora0.mycafe24.com';

  /// placehold.co 개발용 플레이스홀더 (기본 응답은 SVG → [Image.network] 디코드 실패).
  static String placeholdCo(int width, int height) {
    return placeholdCoAsPng('https://placehold.co/${width}x$height');
  }

  /// placehold.co URL에 `/png` 경로를 붙여 래스터 이미지로 요청합니다.
  static String placeholdCoAsPng(String url) {
    final u = url.trim();
    if (!u.contains('placehold.co')) return u;
    final lower = u.toLowerCase();
    if (lower.contains('/png') ||
        lower.endsWith('.png') ||
        lower.endsWith('.jpg')) {
      return u;
    }
    final uri = Uri.tryParse(u);
    if (uri == null) return '$u/png';
    final path = uri.path.endsWith('/png') ? uri.path : '${uri.path}/png';
    return uri.replace(path: path).toString();
  }

  /// DB/API에 남아 있는 예전 `/api/proxy/image?url=` 래핑만 벗김 (새 URL 생성 시 사용 안 함)
  static String unwrapProxyImageUrlIfAny(String url) {
    var current = url.trim();
    for (var i = 0; i < 8; i++) {
      final parsed = Uri.tryParse(current);
      if (parsed == null) break;
      final p = parsed.path.toLowerCase();
      if (!p.contains('proxy/image')) break;
      final inner = parsed.queryParameters['url'];
      if (inner == null || inner.isEmpty) break;
      final next = Uri.decodeFull(inner);
      if (next == current) break;
      current = next;
    }
    return current;
  }

  /// 웹에서만 쓰이는 `blob:` 등 — 서버 프록시로내면 415 등이 나므로 제외
  static bool isBrowserBlobOrInvalidImageUrl(String url) {
    final t = url.trim().toLowerCase();
    return t.startsWith('blob:') ||
        t.contains('blob:http') ||
        t.contains('blob:https');
  }

  /// HTML 조각에서 첫 번째 img src를 추출.
  /// - 리뷰 데이터가 URL 대신 `<img src="...">` 형태로 올 때 대응.
  static String? _extractFirstImageSrc(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final imgSrcPattern = RegExp(
      r'''<img[^>]*\bsrc\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    );
    final match = imgSrcPattern.firstMatch(text);
    if (match == null) return null;
    final src = match.group(1)?.trim();
    if (src == null || src.isEmpty) return null;
    return src;
  }

  /// 이미지 베이스 URL을 반환
  static String get imageBaseUrl {
    if (kIsWeb) {
      // 웹 환경: 현재 origin 사용 (Uri.base 사용)
      try {
        final currentHost = Uri.base.host;

        // localhost인 경우 로컬 웹 서버 사용 (XAMPP)
        if (currentHost == 'localhost' ||
            currentHost == '127.0.0.1' ||
            currentHost.isEmpty) {
          return 'https://bomiora0.mycafe24.com';
        }
        // Cafe24 개발 서버 환경 - 같은 도메인 사용 (CORS 해결)
        else if (currentHost.contains('mycafe24.com')) {
          return 'https://$currentHost';
        } else {
          // 프로덕션: 실제 도메인 - TODO: 프로덕션 도메인 설정
          // return 'https://bomiora.kr';
          return 'https://bomiora0.mycafe24.com';
        }
      } catch (e) {
        // 오류 시 프로덕션 URL 반환 - TODO: 프로덕션 도메인 설정
        // return 'https://bomiora.kr';
        return 'https://bomiora0.mycafe24.com';
      }
    } else {
      // 모바일/데스크톱: 프로덕션 URL 사용 - TODO: 프로덕션 도메인 설정
      // return 'https://bomiora.kr';
      return 'https://bomiora0.mycafe24.com';
    }
  }

  static const _cafe24EventImageBase =
      'https://bomiora0.mycafe24.com/data/event/';

  /// DB `image_path` 예: `event/e_xxx.png` → `https://bomiora0.mycafe24.com/data/event/e_xxx.png`
  static String resolveEventImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    var raw = path.trim();
    if (raw.isEmpty || isBrowserBlobOrInvalidImageUrl(raw)) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return convertToLocalUrl(raw);
    }

    raw = raw.replaceFirst(RegExp(r'^/+'), '');
    final lower = raw.toLowerCase();

    // FTP/서버 경로 `bomiora0/www/data/event/...` → 공개 URL `/data/event/...`
    if (lower.startsWith('bomiora0/www/data/event/')) {
      final fileName = raw.substring('bomiora0/www/data/event/'.length);
      return convertToLocalUrl('$_cafe24EventImageBase$fileName');
    }
    if (lower.startsWith('www/data/event/')) {
      final fileName = raw.substring('www/data/event/'.length);
      return convertToLocalUrl('$_cafe24EventImageBase$fileName');
    }
    if (lower.startsWith('data/event/')) {
      return convertToLocalUrl('https://bomiora0.mycafe24.com/$raw');
    }
    if (lower.startsWith('event/')) {
      final fileName = raw.substring('event/'.length);
      return convertToLocalUrl('$_cafe24EventImageBase$fileName');
    }

    return convertToLocalUrl('$_cafe24EventImageBase$raw');
  }

  /// 정적 사이트 에셋 (`assets/img/...`, `main_banner/...`) — `data/item`과 별도
  static String resolveSiteAssetUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    var p = path.trim();
    if (p.isEmpty || isBrowserBlobOrInvalidImageUrl(p)) return '';
    if (p.startsWith('http://') || p.startsWith('https://')) {
      return convertToLocalUrl(p);
    }
    if (!p.startsWith('/')) p = '/$p';
    return convertToLocalUrl('${imageBaseUrl}$p');
  }

  /// 상대 경로를 전체 URL로 변환
  static String normalizeImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return '';
    }
    if (isBrowserBlobOrInvalidImageUrl(imageUrl)) {
      return convertToLocalUrl('${imageBaseUrl}/data/item/no_img.png');
    }

    // 이미 전체 URL인 경우 convertToLocalUrl로 변환
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return convertToLocalUrl(imageUrl);
    }

    // 상대 경로인 경우 base URL과 조합
    String normalizedPath = imageUrl;

    // 건강 API 업로드 경로는 data/item 접두사 없음
    if (isWeightImagePath(normalizedPath)) {
      return _resolveWeightImageUrl(normalizedPath);
    }
    if (isFoodImagePath(normalizedPath)) {
      return _resolveFoodImageUrl(normalizedPath);
    }
    if (isHealthApiImagePath(normalizedPath)) {
      return _resolveHealthApiImageUrl(normalizedPath);
    }
    if (isReviewApiImagePath(normalizedPath)) {
      return _resolveReviewApiImageUrl(normalizedPath);
    }
    if (isQaApiImagePath(normalizedPath)) {
      return _resolveQaApiImageUrl(normalizedPath);
    }

    // data/item/이 없으면 추가
    if (!normalizedPath.contains('/data/item/')) {
      if (normalizedPath.startsWith('/')) {
        normalizedPath = '/data/item$normalizedPath';
      } else {
        normalizedPath = '/data/item/$normalizedPath';
      }
    } else if (!normalizedPath.startsWith('/')) {
      normalizedPath = '/$normalizedPath';
    }

    // 웹 환경에서는 같은 도메인 사용 (CORS 해결)
    if (kIsWeb) {
      final currentHost = Uri.base.host;

      // Cafe24 환경
      if (currentHost.contains('mycafe24.com')) {
        final result = 'https://$currentHost$normalizedPath';
        return result;
      }
    }

    final result = '${imageBaseUrl}$normalizedPath';
    return convertToLocalUrl(result);
  }

  /// 썸네일 이미지 경로 정규화 (data/item/ 경로 포함)
  /// 예: 1691484067/image.jpg -> /data/item/1691484067/image.jpg
  /// 예: /1691484067/image.jpg -> /data/item/1691484067/image.jpg
  static String? normalizeThumbnailUrl(String? imagePath, String? productId) {
    if (imagePath == null || imagePath.isEmpty) {
      return null;
    }

    // 이미 전체 URL인 경우 convertToLocalUrl로 변환
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      final converted = convertToLocalUrl(imagePath);
      return converted;
    }

    // 이미 data/item/이 포함된 경우 정규화만 수행
    if (imagePath.contains('/data/item/')) {
      String path = imagePath;
      if (!path.startsWith('/')) {
        path = '/$path';
      }
      final fullUrl = '${imageBaseUrl}$path';
      return convertToLocalUrl(fullUrl);
    }

    // 상대 경로 처리
    String path = imagePath.trim();

    // 숫자로 시작하는 폴더명 패턴 찾기 (예: 1691484067/image.jpg 또는 /1691484067/image.jpg)
    final numberFolderPattern = RegExp(r'^/?(\d+)/');
    final match = numberFolderPattern.firstMatch(path);

    if (match != null) {
      // 숫자 폴더가 있으면 data/item/ 추가
      final folderId = match.group(1);
      if (path.startsWith('/')) {
        path = path.replaceFirst('/$folderId/', '/data/item/$folderId/');
      } else {
        path = '/data/item/$path';
      }
    } else {
      // 숫자로 시작하는 경로인 경우 (예: 1691484067image.jpg - 슬래시 없음)
      final numberStartPattern = RegExp(r'^(\d+)');
      final match2 = numberStartPattern.firstMatch(path);
      if (match2 != null && productId != null && path.startsWith(productId)) {
        // productId로 시작하는 경우
        path = '/data/item/$path';
      } else if (match2 != null) {
        // 그 외 숫자로 시작하는 경우
        path = '/data/item/$path';
      } else {
        // 숫자로 시작하지 않으면 기존 방식 사용
        if (!path.startsWith('/')) {
          path = '/$path';
        }
        // data/item/이 없으면 추가 시도
        if (!path.contains('data/item/') && !path.contains('data/products/')) {
          // products 경로 체크
          if (path.contains('products/')) {
            path = path.replaceFirst('/products/', '/data/item/');
          } else if (productId != null && productId.isNotEmpty) {
            // productId를 사용하여 경로 생성
            path = '/data/item/$productId/${path.replaceFirst('/', '')}';
          }
        }
      }
    }

    // 앞에 /가 없으면 추가 (http로 시작하지 않는 경우만)
    if (!path.startsWith('/') && !path.startsWith('http')) {
      path = '/$path';
    }

    final result = '${imageBaseUrl}$path';
    return convertToLocalUrl(result);
  }

  /// bomiora.kr / mycafe24 → Cafe24 canonical 직링크
  static String _cafe24CanonicalUrl(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return '$_cafe24CanonicalHost$p';
  }

  /// Cafe24 호스트 URL → canonical 직링크 (프록시 없음)
  static String convertToLocalUrl(String url) {
    var u = unwrapProxyImageUrlIfAny(url);
    if (u.isEmpty) return url;
    if (isBrowserBlobOrInvalidImageUrl(u)) {
      return '$_cafe24CanonicalHost/data/item/no_img.png';
    }

    if (u.contains('bomiora.kr') ||
        u.contains('www.bomiora.kr') ||
        u.contains('bomiora0.mycafe24.com')) {
      return _cafe24CanonicalUrl(Uri.parse(u).path);
    }

    return u;
  }

  /// 간단한 이미지 URL 반환 (일반적인 용도)
  /// 이미 전체 URL이면 그대로 반환, 아니면 normalizeImageUrl 사용
  static bool isCorruptStoredImagePath(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return true;
    final t = imageUrl.trim();
    return t.contains('{type:') ||
        t.contains('"type":"Buffer"') ||
        t.contains('"type": "Buffer"');
  }

  /// 건강 API 업로드 경로(`/api/health/...`) — 쇼핑 `data/item`과 별도
  static bool isHealthApiImagePath(String path) {
    final p = path.toLowerCase();
    return p.contains('/api/health/');
  }

  static bool isReviewApiImagePath(String path) {
    final p = path.toLowerCase();
    return p.contains('/api/user/reviews/images/') ||
        p.contains('/data/review_images/');
  }

  static bool isQaApiImagePath(String path) {
    final p = path.toLowerCase();
    return p.contains('/api/qa/images/') || p.contains('/data/qa_images/');
  }

  static bool isProfileImagePath(String path) {
    final p = path.toLowerCase();
    return p.contains('/uploads/profiles/') || p.contains('/data/profiles/');
  }

  static bool isWeightImagePath(String path) {
    final p = path.toLowerCase();
    return p.contains('/data/weight_images/') ||
        p.contains('/api/health/weight/images/');
  }

  static bool isFoodImagePath(String path) {
    final p = path.toLowerCase();
    return p.contains('/data/food_images/') ||
        p.contains('/api/health/food/images/');
  }

  static bool isRemoteImageUrl(String? path) {
    final t = (path ?? '').trim().toLowerCase();
    return t.startsWith('http://') ||
        t.startsWith('https://') ||
        t.startsWith('blob:');
  }

  /// Cafe24 미러 경로 → Node 즉시 서빙 URL (미러 완료 전에도 표시)
  static String? _nodeProfileImageUrl(String pathOrUrl) {
    var raw = unwrapProxyImageUrlIfAny(pathOrUrl.trim());
    if (raw.isEmpty) return null;

    String path = raw;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      path = Uri.tryParse(raw)?.path ?? raw;
    } else if (!path.startsWith('/')) {
      path = '/$path';
    }

    final match = RegExp(
      r'/(?:data|uploads)/profiles/([^/]+)/([^/?#]+)',
      caseSensitive: false,
    ).firstMatch(path);
    if (match == null) return null;

    final mbId = Uri.decodeComponent(match.group(1)!);
    final file = Uri.decodeComponent(match.group(2)!);
    return '${ApiClient.baseUrl}/uploads/profiles/$mbId/$file';
  }

  static String? _nodeReviewImageUrl(String pathOrUrl) {
    var raw = unwrapProxyImageUrlIfAny(pathOrUrl.trim());
    if (raw.isEmpty) return null;

    String path = raw;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      path = Uri.tryParse(raw)?.path ?? raw;
    } else if (!path.startsWith('/')) {
      path = '/$path';
    }

    final apiMatch = RegExp(
      r'/api/user/reviews/images/([^/?#]+)',
      caseSensitive: false,
    ).firstMatch(path);
    if (apiMatch != null) {
      final file = Uri.decodeComponent(apiMatch.group(1)!);
      return '${ApiClient.baseUrl}/api/user/reviews/images/$file';
    }

    final cafeMatch = RegExp(
      r'/data/review_images/([^/?#]+)',
      caseSensitive: false,
    ).firstMatch(path);
    if (cafeMatch != null) {
      final file = Uri.decodeComponent(cafeMatch.group(1)!);
      return '${ApiClient.baseUrl}/api/user/reviews/images/$file';
    }

    return null;
  }

  static String? _nodeWeightImageUrl(String pathOrUrl) {
    var raw = unwrapProxyImageUrlIfAny(pathOrUrl.trim());
    if (raw.isEmpty) return null;

    String path = raw;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      path = Uri.tryParse(raw)?.path ?? raw;
    } else if (!path.startsWith('/')) {
      path = '/$path';
    }

    final apiMatch = RegExp(
      r'/api/health/weight/images/([^/?#]+)',
      caseSensitive: false,
    ).firstMatch(path);
    if (apiMatch != null) {
      final file = Uri.decodeComponent(apiMatch.group(1)!);
      return '${ApiClient.baseUrl}/api/health/weight/images/$file';
    }

    final cafeMatch = RegExp(
      r'/data/weight_images/([^/?#]+)',
      caseSensitive: false,
    ).firstMatch(path);
    if (cafeMatch != null) {
      final file = Uri.decodeComponent(cafeMatch.group(1)!);
      return '${ApiClient.baseUrl}/api/health/weight/images/$file';
    }

    return null;
  }

  static String? _nodeFoodImageUrl(String pathOrUrl) {
    var raw = unwrapProxyImageUrlIfAny(pathOrUrl.trim());
    if (raw.isEmpty) return null;

    String path = raw;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      path = Uri.tryParse(raw)?.path ?? raw;
    } else if (!path.startsWith('/')) {
      path = '/$path';
    }

    final match = RegExp(
      r'/(?:data/food_images|api/health/food/images)/([^/?#]+)',
      caseSensitive: false,
    ).firstMatch(path);
    if (match == null) return null;

    final file = Uri.decodeComponent(match.group(1)!);
    return '${ApiClient.baseUrl}/api/health/food/images/$file';
  }

  /// 과거 `normalizeImageUrl`이 붙인 `/data/item/api/health/...` 접두사 제거
  static String fixHealthApiImagePath(String path) {
    var p = path.trim();
    p = p.replaceFirst(
      RegExp(r'^/data/item/(?=https?://)', caseSensitive: false),
      '',
    );
    while (p.startsWith('/http://') || p.startsWith('/https://')) {
      p = p.substring(1);
    }
    var lower = p.toLowerCase();
    if (lower.contains('/data/item/api/health/')) {
      p = p.replaceFirst(
        RegExp(r'/data/item(?=/api/health/)', caseSensitive: false),
        '',
      );
      lower = p.toLowerCase();
    }
    if (lower.contains('/data/item/api/qa/')) {
      p = p.replaceFirst(
        RegExp(r'/data/item(?=/api/qa/)', caseSensitive: false),
        '',
      );
    }
    return p;
  }

  /// 건강 식사·체중 등 API 정적 파일의 호스트 (로컬 웹은 Node API 서버)
  static String _healthApiImageOrigin() {
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host == 'localhost' || host == '127.0.0.1' || host.isEmpty) {
        return ApiClient.baseUrl;
      }
      if (host.contains('mycafe24.com')) {
        return 'https://$host';
      }
    }
    return ApiClient.baseUrl;
  }

  static String _resolveHealthApiImageUrl(String imageUrl) {
    final fixed = fixHealthApiImagePath(imageUrl);
    late final String fullUrl;
    if (fixed.startsWith('http://') || fixed.startsWith('https://')) {
      fullUrl = fixed;
    } else {
      var path = fixed;
      if (!path.startsWith('/')) path = '/$path';
      fullUrl = '${_healthApiImageOrigin()}$path';
    }

    final uri = Uri.tryParse(fullUrl);
    if (uri == null) return fullUrl;

    if (kIsWeb) {
      final webHost = Uri.base.host;
      final isLocalWeb =
          webHost == 'localhost' || webHost == '127.0.0.1' || webHost.isEmpty;

      // 로컬 웹 + 로컬 API 서버 파일 → 프록시 없이 직접 로드 (415·CORS 방지)
      if (isLocalWeb && (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
        return fullUrl;
      }

      // 로컬 웹인데 Cafe24 URL로 저장된 건강 API 경로 → 로컬 API로 재작성
      if (isLocalWeb && isHealthApiImagePath(uri.path)) {
        return '${ApiClient.baseUrl}${uri.path}';
      }
    }

    return convertToLocalUrl(fullUrl);
  }

  static String _resolveReviewApiImageUrl(String imageUrl) {
    final fixed = fixHealthApiImagePath(imageUrl);
    late final String fullUrl;
    if (fixed.startsWith('http://') || fixed.startsWith('https://')) {
      fullUrl = fixed;
    } else {
      var path = fixed;
      if (!path.startsWith('/')) path = '/$path';
      fullUrl = '${_healthApiImageOrigin()}$path';
    }

    final uri = Uri.tryParse(fullUrl);
    if (uri == null) return fullUrl;

    final nodeReviewUrl = _nodeReviewImageUrl(fullUrl);
    if (nodeReviewUrl != null) return nodeReviewUrl;

    if (kIsWeb) {
      final webHost = Uri.base.host;
      final isLocalWeb =
          webHost == 'localhost' || webHost == '127.0.0.1' || webHost.isEmpty;
      if (isLocalWeb && isReviewApiImagePath(uri.path)) {
        return '${ApiClient.baseUrl}${uri.path}';
      }
    }

    if (isReviewApiImagePath(uri.path)) {
      return '${ApiClient.baseUrl}${uri.path}';
    }

    return convertToLocalUrl(fullUrl);
  }

  static String _resolveQaApiImageUrl(String imageUrl) {
    final fixed = fixHealthApiImagePath(imageUrl);
    late final String fullUrl;
    if (fixed.startsWith('http://') || fixed.startsWith('https://')) {
      fullUrl = fixed;
    } else {
      var path = fixed;
      if (!path.startsWith('/')) path = '/$path';
      fullUrl = '${_healthApiImageOrigin()}$path';
    }

    final uri = Uri.tryParse(fullUrl);
    if (uri == null) return fullUrl;

    // QA 이미지: Cafe24 data/qa_images 는 정적, Node /api/qa/images 는 API origin
    if (isQaApiImagePath(uri.path) || isQaApiImagePath(fullUrl)) {
      if (uri.path.toLowerCase().contains('/data/qa_images/')) {
        if (uri.hasScheme) return fullUrl;
        return convertToLocalUrl('https://bomiora0.mycafe24.com${uri.path}');
      }
      return '${ApiClient.baseUrl}${uri.path}';
    }

    return convertToLocalUrl(fullUrl);
  }

  static String _resolveProfileImageUrl(String imageUrl) {
    final nodeUrl = _nodeProfileImageUrl(imageUrl);
    if (nodeUrl != null) return nodeUrl;

    final fixed = fixHealthApiImagePath(imageUrl);
    late final String fullUrl;
    if (fixed.startsWith('http://') || fixed.startsWith('https://')) {
      fullUrl = fixed;
    } else {
      var path = fixed;
      if (!path.startsWith('/')) path = '/$path';
      fullUrl = '${ApiClient.baseUrl}$path';
    }

    final uri = Uri.tryParse(fullUrl);
    if (uri == null) return fullUrl;

    if (kIsWeb) {
      final webHost = Uri.base.host;
      final isLocalWeb =
          webHost == 'localhost' || webHost == '127.0.0.1' || webHost.isEmpty;
      if (isLocalWeb && isProfileImagePath(uri.path)) {
        return '${ApiClient.baseUrl}${uri.path}';
      }
    }

    if (isProfileImagePath(uri.path)) {
      return '${ApiClient.baseUrl}${uri.path.startsWith('/') ? uri.path : '/${uri.path}'}';
    }

    return convertToLocalUrl(fullUrl);
  }

  static String _resolveWeightImageUrl(String imageUrl) {
    final nodeUrl = _nodeWeightImageUrl(imageUrl);
    if (nodeUrl != null) return nodeUrl;
    return _resolveHealthApiImageUrl(imageUrl);
  }

  static String _resolveFoodImageUrl(String imageUrl) {
    final nodeUrl = _nodeFoodImageUrl(imageUrl);
    if (nodeUrl != null) return nodeUrl;
    return _resolveHealthApiImageUrl(imageUrl);
  }

  static String getImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return convertToLocalUrl('${imageBaseUrl}/data/item/no_img.png');
    }
    if (isCorruptStoredImagePath(imageUrl)) {
      return convertToLocalUrl('${imageBaseUrl}/data/item/no_img.png');
    }
    if (isBrowserBlobOrInvalidImageUrl(imageUrl)) {
      return convertToLocalUrl('${imageBaseUrl}/data/item/no_img.png');
    }

    final normalizedPath = fixHealthApiImagePath(imageUrl);
    if (isWeightImagePath(normalizedPath)) {
      return _resolveWeightImageUrl(normalizedPath);
    }
    if (isFoodImagePath(normalizedPath)) {
      return _resolveFoodImageUrl(normalizedPath);
    }
    if (isHealthApiImagePath(normalizedPath)) {
      return _resolveHealthApiImageUrl(normalizedPath);
    }
    if (isReviewApiImagePath(normalizedPath)) {
      return _resolveReviewApiImageUrl(normalizedPath);
    }
    if (isQaApiImagePath(normalizedPath)) {
      return _resolveQaApiImageUrl(normalizedPath);
    }
    if (isProfileImagePath(normalizedPath)) {
      return _resolveProfileImageUrl(normalizedPath);
    }

    // localhost URL 수정 (잘못된 형태)
    if (imageUrl.contains('localhost/bomiora/www/')) {
      String fixedUrl = imageUrl
          .replaceAll(
              'https://localhost/bomiora/www/', '$imageBaseUrl/data/item/')
          .replaceAll(
              'http://localhost/bomiora/www/', '$imageBaseUrl/data/item/');
      return normalizeImageUrl(fixedUrl);
    }

    // 이미 전체 URL인 경우 convertToLocalUrl로 변환
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      if (isWeightImagePath(imageUrl)) {
        return _resolveWeightImageUrl(imageUrl);
      }
      if (isFoodImagePath(imageUrl)) {
        return _resolveFoodImageUrl(imageUrl);
      }
      if (isProfileImagePath(imageUrl)) {
        return _resolveProfileImageUrl(imageUrl);
      }
      // localhost:9000/api/qa/images 등 API 정적 파일
      if (isQaApiImagePath(imageUrl) ||
          isReviewApiImagePath(imageUrl) ||
          isHealthApiImagePath(imageUrl)) {
        final uri = Uri.tryParse(imageUrl);
        if (uri != null && uri.path.isNotEmpty) {
          return '${ApiClient.baseUrl}${uri.path}';
        }
      }
      return convertToLocalUrl(imageUrl);
    }

    // 상대 경로인 경우 normalizeImageUrl 사용
    return normalizeImageUrl(imageUrl);
  }

  /// `data/itemuse/` 상대경로 정리 — 선행 `/`, 중복 `data/itemuse/` 제거
  static String _normalizeReviewItemuseRelativePath(String raw) {
    var path = raw.trim().replaceAll('\\', '/');
    while (path.startsWith('/')) {
      path = path.substring(1);
    }
    const prefix = 'data/itemuse/';
    if (path.startsWith(prefix)) {
      path = path.substring(prefix.length);
    }
    return path;
  }

  /// 리뷰 이미지 URL 변환 (data/itemuse/ 경로 사용)
  /// 예: 1686290723/IMG_6466.jpeg -> /data/itemuse/1686290723/IMG_6466.jpeg
  static String getReviewImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return convertToLocalUrl('${imageBaseUrl}/data/item/no_img.png');
    }

    final extractedSrc = _extractFirstImageSrc(imageUrl);
    final trimmed = (extractedSrc ?? imageUrl).trim();
    if (isBrowserBlobOrInvalidImageUrl(trimmed)) {
      return convertToLocalUrl('${imageBaseUrl}/data/item/no_img.png');
    }
    if (isReviewApiImagePath(trimmed)) {
      return _resolveReviewApiImageUrl(trimmed);
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return convertToLocalUrl(trimmed);
    }

    final path = _normalizeReviewItemuseRelativePath(trimmed);
    if (path.isEmpty) {
      return convertToLocalUrl('${imageBaseUrl}/data/item/no_img.png');
    }

    // 웹 환경에서 처리
    if (kIsWeb) {
      final currentHost = Uri.base.host;

      // Cafe24 프로덕션 환경 - 같은 도메인 사용 (CORS 없음!)
      if (currentHost.contains('mycafe24.com')) {
        return 'https://$currentHost/data/itemuse/$path';
      }

      // bomiora.net 등 — mycafe24 canonical 직링크
      return convertToLocalUrl('https://bomiora.kr/data/itemuse/$path');
    }

    return convertToLocalUrl('https://bomiora.kr/data/itemuse/$path');
  }

  /// 메인 홈 리뷰 이미지 URL 변환 (data/mainreview 경로 사용)
  /// 입력 예:
  /// - 1686290723/7KO864Sk66W0_01.gif
  /// - /bomiora0/www/data/mainreview/1686290723/7KO864Sk66W0_01.gif
  /// - https://bomiora0.mycafe24.com/www/data/mainreview/...
  static String getMainReviewImageUrl(String? imageUrl) {
    const fallbackPath = '/data/item/no_img.png';
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return convertToLocalUrl('${imageBaseUrl}$fallbackPath');
    }

    final extractedSrc = _extractFirstImageSrc(imageUrl);
    var raw = (extractedSrc ?? imageUrl).trim().replaceAll('\\', '/');
    if (raw.isEmpty) {
      return convertToLocalUrl('${imageBaseUrl}$fallbackPath');
    }

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return convertToLocalUrl(raw);
    }

    // 절대/상대 경로 혼재 정리
    raw = raw
        .replaceFirst(
            RegExp(r'^/bomiora0/www/data/mainreview/', caseSensitive: false),
            '')
        .replaceFirst(
            RegExp(r'^bomiora0/www/data/mainreview/', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^/data/mainreview/', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^data/mainreview/', caseSensitive: false), '');

    while (raw.startsWith('/')) {
      raw = raw.substring(1);
    }

    if (raw.isEmpty) {
      return convertToLocalUrl('${imageBaseUrl}$fallbackPath');
    }

    if (kIsWeb) {
      final currentHost = Uri.base.host;
      if (currentHost.contains('mycafe24.com')) {
        return 'https://$currentHost/data/mainreview/$raw';
      }
      return convertToLocalUrl('https://bomiora.kr/data/mainreview/$raw');
    }

    return convertToLocalUrl('https://bomiora.kr/data/mainreview/$raw');
  }
}
