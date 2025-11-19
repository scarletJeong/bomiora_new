import 'package:flutter/foundation.dart';

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
  /// 이미지 베이스 URL을 반환
  static String get imageBaseUrl {
    if (kIsWeb) {
      // 웹 환경: 현재 origin 사용 (Uri.base 사용)
      try {
        final currentHost = Uri.base.host;
        final currentPort = Uri.base.port;
        
        // localhost인 경우 로컬 웹 서버 사용 (XAMPP)
        if (currentHost == 'localhost' || currentHost == '127.0.0.1' || currentHost.isEmpty) {
          // 로컬 개발 환경에서는 HTTP 사용 (SSL 인증서 문제 방지)
          return 'https://localhost/bomiora/www';
        } 
        // Cafe24 개발 서버 환경 - 같은 도메인 사용 (CORS 해결)
        else if (currentHost.contains('mycafe24.com')) {
          return 'https://$currentHost';
        } 
        else {
          // 프로덕션: 실제 도메인
          return 'https://bomiora.kr';
        }
      } catch (e) {
        // 오류 시 프로덕션 URL 반환
        return 'https://bomiora.kr';
      }
    } else {
      // 모바일/데스크톱: 프로덕션 URL 사용
      return 'https://bomiora.kr';
    }
  }
  
  /// 상대 경로를 전체 URL로 변환
  static String normalizeImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return '';
    }
    
    print('📸 [normalizeImageUrl] 입력: $imageUrl');
    
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
        print('  📍 Cafe24 같은 도메인: $result');
        return result;
      }
      
      // 로컬 환경
      if (currentHost == 'localhost' || currentHost == '127.0.0.1' || currentHost.isEmpty) {
        final result = '$imageBaseUrl$normalizedPath';
        print('  📍 로컬: $result');
        return result;
      }
    }
    
    final result = '${imageBaseUrl}$normalizedPath';
    print('  📍 기본: $result');
    return result;
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
      return convertToLocalUrl(imagePath);
    }
    
    // 이미 data/item/이 포함된 경우 정규화만 수행
    if (imagePath.contains('/data/item/')) {
      String path = imagePath;
      if (!path.startsWith('/')) {
        path = '/$path';
      }
      return '${imageBaseUrl}$path';
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
    
    return '${imageBaseUrl}$path';
  }

  /// 프로덕션 URL을 현재 환경에 맞는 URL로 변환
  /// 예: https://bomiora.kr/data/item/... -> http://localhost/bomiora/www/data/item/... (로컬 환경)
  /// CORS 문제 해결: 같은 도메인 사용
  static String convertToLocalUrl(String url) {
    if (url.contains('bomiora.kr') || url.contains('www.bomiora.kr') || url.contains('bomiora0.mycafe24.com')) {
      Uri uri = Uri.parse(url);
      String path = uri.path;
      
      if (kIsWeb) {
        final currentHost = Uri.base.host;
        
        // 로컬 개발 환경 - 로컬 경로 사용
        if (currentHost == 'localhost' || currentHost == '127.0.0.1' || currentHost.isEmpty) {
          // 모든 경로를 직접 로컬 경로로 변환 (프록시 사용 안 함)
          final result = '$imageBaseUrl$path';
          return result;
        }
        
        // Cafe24 프로덕션 환경 - 같은 도메인 사용 (CORS 해결!)
        if (currentHost.contains('mycafe24.com')) {
          // bomiora.kr -> bomiora0.mycafe24.com 으로 변경
          final result = 'https://$currentHost$path';
          return result;
        }
        
        // 기타 프로덕션 (bomiora.kr 등) - 프록시 사용
        if (path.contains('/data/editor/') || path.contains('/data/itemuse/')) {
          final result = 'https://bomiora.net:9000/api/proxy/image?url=${Uri.encodeComponent(url)}';
          return result;
        }
      }
      
      // 기본: 현재 환경에 맞는 base URL 사용
      String baseUrl = imageBaseUrl;
      final result = path.startsWith('/') ? '$baseUrl$path' : '$baseUrl/$path';
      return result;
    }
    
    return url;
  }

  /// 간단한 이미지 URL 반환 (일반적인 용도)
  /// 이미 전체 URL이면 그대로 반환, 아니면 normalizeImageUrl 사용
  static String getImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return '${imageBaseUrl}/data/item/no_img.png';
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

  /// 리뷰 이미지 URL 변환 (data/itemuse/ 경로 사용)
  /// 예: 1686290723/IMG_6466.jpeg -> /data/itemuse/1686290723/IMG_6466.jpeg
  static String getReviewImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return '${imageBaseUrl}/data/item/no_img.png';
    }
    
    // 이미 전체 URL인 경우
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return convertToLocalUrl(imageUrl);
    }
    
    // 웹 환경에서 처리
    if (kIsWeb) {
      final currentHost = Uri.base.host;
      
      // 로컬 개발 환경 - 로컬 경로 사용
      if (currentHost == 'localhost' || currentHost == '127.0.0.1' || currentHost.isEmpty) {
        String path = imageUrl;
        if (path.startsWith('/')) {
          path = path.substring(1);
        }
        return '$imageBaseUrl/data/itemuse/$path';
      }
      
      // Cafe24 프로덕션 환경 - 같은 도메인 사용 (CORS 없음!)
      if (currentHost.contains('mycafe24.com')) {
        String path = imageUrl;
        if (path.startsWith('/')) {
          path = path.substring(1);
        }
        // 같은 도메인의 경로 사용
        return 'https://$currentHost/data/itemuse/$path';
      }
      
      // 기타 프로덕션 환경 (bomiora.kr 등) - 프록시 사용
      String path = imageUrl;
      if (path.startsWith('/')) {
        path = path.substring(1);
      }
      final fullUrl = 'https://bomiora.kr/data/itemuse/$path';
      return 'https://bomiora.net:9000/api/proxy/image?url=${Uri.encodeComponent(fullUrl)}';
    }
    
    // 모바일 앱 - bomiora.kr 경로 사용
    String path = imageUrl;
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    return 'https://bomiora.kr/data/itemuse/$path';
  }
}
