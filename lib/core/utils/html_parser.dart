import 'dart:convert';

/// HTML 콘텐츠 파서 유틸리티
/// HTML에서 이미지 URL을 추출하는 등의 작업을 수행
class HtmlParser {
  /// HTML 콘텐츠에서 모든 이미지 URL 추출
  /// 
  /// 예: 
  /// <img src="https://example.com/image.jpg">
  /// -> ["https://example.com/image.jpg"]
  static List<String> extractImageUrls(String? htmlContent) {
    if (htmlContent == null || htmlContent.isEmpty) {
      return [];
    }

    final imageUrls = <String>[];
    
    // <img> 태그에서 src 속성 추출
    // 더 정확한 정규 표현식: src 속성의 값을 완전히 추출
    final imgPattern = RegExp(
      r'''<img[^>]+src\s*=\s*(["'])(.*?)\1''',
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );

    final matches = imgPattern.allMatches(htmlContent);
    for (final match in matches) {
      if (match.groupCount >= 2) {
        // group(2)는 실제 URL 값 (따옴표 제외)
        final imageUrl = match.group(2);
        if (imageUrl != null && imageUrl.isNotEmpty) {
          // HTML 엔티티 디코딩
          final decodedUrl = _decodeHtmlEntities(imageUrl.trim());
          imageUrls.add(decodedUrl);
        }
      }
    }

    return imageUrls;
  }

  /// HTML 콘텐츠에서 첫 번째 이미지 URL 추출
  static String? extractFirstImageUrl(String? htmlContent) {
    final urls = extractImageUrls(htmlContent);
    return urls.isNotEmpty ? urls.first : null;
  }

  /// HTML 콘텐츠 정리 (태그 제거, 텍스트만 추출)
  static String stripHtmlTags(String? htmlContent) {
    if (htmlContent == null || htmlContent.isEmpty) {
      return '';
    }

    // HTML 태그 제거
    String text = htmlContent
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // HTML 엔티티 디코딩
    text = _decodeHtmlEntities(text);

    return text;
  }

  /// HTML 엔티티 디코딩 (&nbsp; -> 공백 등)
  static String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }

  /// HTML 콘텐츠에서 <div> 태그로 감싸진 섹션 추출
  static List<String> extractDivSections(String? htmlContent) {
    if (htmlContent == null || htmlContent.isEmpty) {
      return [];
    }

    final sections = <String>[];
    
    // <div> 태그로 감싸진 섹션 추출
    final divPattern = RegExp(
      r'<div[^>]*>(.*?)</div>',
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );

    final matches = divPattern.allMatches(htmlContent);
    for (final match in matches) {
      if (match.groupCount >= 1) {
        final section = match.group(1);
        if (section != null && section.trim().isNotEmpty) {
          sections.add(section.trim());
        }
      }
    }

    return sections;
  }
}

