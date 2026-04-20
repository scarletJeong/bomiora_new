import 'package:flutter/foundation.dart';

import '../network/api_client.dart';

/// 이미지 URL 정규화 헬퍼
/// 
/// 주의: CORS 문제 해결 필요
/// Flutter 앱이 localhost:5000에서 실행되고 이미지가 localhost:80에 있으면
/// CORS 정책으로 차단될 수 있습니다.
/// 
/// 해결 방법:
/// 1. XAMPP Apache 설정에 CORS 헤더 추가 (httpd.conf 또는 .htaccess)
///    Header set Access-Control-Allow-Origin "*"
/// 
/// 2. 또는 Flutter 앱을 XAMPP를 통해 서빙 (포트 80)
class ImageUrlHelper {
  /// `/api/proxy/image?url=` 로 감싼 URL을 최대 여러 겹 벗겨 실제 이미지 주소만 남김.
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
        if (currentHost == 'localhost' || currentHost == '127.0.0.1' || currentHost.isEmpty) {
          return 'https://bomiora0.mycafe24.com';
        }
        // Cafe24 개발 서버 환경 - 같은 도메인 사용 (CORS 해결)
        else if (currentHost.contains('mycafe24.com')) {
          return 'https://$currentHost';
        }
        else {
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

  /// 프로덕션 URL을 현재 환경에 맞는 URL로 변환
  /// 예: https://bomiora.kr/data/item/... -> http://localhost/bomiora/www/data/item/... (로컬 환경)
  /// CORS 문제 해결: 같은 도메인 사용
  static String convertToLocalUrl(String url) {
    var u = unwrapProxyImageUrlIfAny(url);
    if (u.isEmpty) return url;
    if (isBrowserBlobOrInvalidImageUrl(u)) {
      // 재귀: 로컬 웹이면 프록시 경로로 정리됨
      return convertToLocalUrl('https://bomiora0.mycafe24.com/data/item/no_img.png');
    }

    if (u.contains('bomiora.kr') || u.contains('www.bomiora.kr') || u.contains('bomiora0.mycafe24.com')) {
      Uri uri = Uri.parse(u);
      String path = uri.path;
      // TODO: 운영 전환 시 canonicalUpstreamHost를 bomiora.kr로 변경
      const canonicalUpstreamHost = 'https://bomiora0.mycafe24.com';
      final canonicalUpstreamUrl = '$canonicalUpstreamHost$path';
      
      if (kIsWeb) {
        final currentHost = Uri.base.host;
        
        // 로컬 웹: Flutter web은 이미지 로드에 XHR을 쓰는 경우가 많아 cross-origin 원본은 CORS에 막힘 → 백엔드 프록시(한 겹)
        if (currentHost == 'localhost' || currentHost == '127.0.0.1' || currentHost.isEmpty) {
          return '${ApiClient.baseUrl}/api/proxy/image?url=${Uri.encodeComponent(canonicalUpstreamUrl)}';
        }
        
        // Cafe24 프로덕션 환경 - 같은 도메인 사용 (CORS 해결!)
        if (currentHost.contains('mycafe24.com')) {
          // TODO: 운영 전환 시 이 반환값도 bomiora.kr 기준으로 변경
          final result = canonicalUpstreamUrl;
          return result;
        }
        
        // bomiora.net 웹에서는 항상 mycafe24 원본으로 프록시 우회
        // TODO: 운영 전환 시 proxy 대상 URL을 bomiora.kr로 변경
        final result = 'https://bomiora.net/api/proxy/image?url=${Uri.encodeComponent(canonicalUpstreamUrl)}';
        return result;
      }
      
      // 기본: 현재 환경에 맞는 base URL 사용
      String baseUrl = imageBaseUrl;
      final result = path.startsWith('/') ? '$baseUrl$path' : '$baseUrl/$path';
      return result;
    }
    
    return u;
  }

  /// 간단한 이미지 URL 반환 (일반적인 용도)
  /// 이미 전체 URL이면 그대로 반환, 아니면 normalizeImageUrl 사용
  static String getImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return convertToLocalUrl('${imageBaseUrl}/data/item/no_img.png');
    }
    if (isBrowserBlobOrInvalidImageUrl(imageUrl)) {
      return convertToLocalUrl('${imageBaseUrl}/data/item/no_img.png');
    }

    // localhost URL 수정 (잘못된 형태)
    if (imageUrl.contains('localhost/bomiora/www/')) {
      String fixedUrl = imageUrl
          .replaceAll('https://localhost/bomiora/www/', '$imageBaseUrl/data/item/')
          .replaceAll('http://localhost/bomiora/www/', '$imageBaseUrl/data/item/');
      return normalizeImageUrl(fixedUrl);
    }
    
    // 이미 전체 URL인 경우 convertToLocalUrl로 변환
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
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

      // bomiora.net 등 — 상대경로만 오는 경우 여기로 오는데,
      // 수동으로 bomiora.kr 을 넣으면 프록시 대상이 [convertToLocalUrl] 과 달라져 502 등이 날 수 있음.
      // 항상 bomiora.kr URL 을 넘겨 [convertToLocalUrl] 이 mycafe24 canonical + 동일 프록시 규칙 적용.
      return convertToLocalUrl('https://bomiora.kr/data/itemuse/$path');
    }

    // 모바일 앱 - bomiora.kr 경로 사용
    return 'https://bomiora.kr/data/itemuse/$path';
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
        .replaceFirst(RegExp(r'^/bomiora0/www/data/mainreview/', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^bomiora0/www/data/mainreview/', caseSensitive: false), '')
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

    return 'https://bomiora.kr/data/mainreview/$raw';
  }
}
