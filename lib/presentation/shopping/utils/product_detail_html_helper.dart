import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../health/health_common/health_responsive_scale.dart';

/// 상품 상세 HTML의 고정 width/height 제거 — 화면 너비에 맞게 표시
String sanitizeProductDetailHtmlImages(String html) {
  var result = html;
  result = result.replaceAll(
    RegExp(
      r'''(<img\b[^>]*?)\s+width\s*=\s*(["'])[^"']*\2''',
      caseSensitive: false,
    ),
    r'$1',
  );
  result = result.replaceAll(
    RegExp(
      r'''(<img\b[^>]*?)\s+height\s*=\s*(["'])[^"']*\2''',
      caseSensitive: false,
    ),
    r'$1',
  );
  result = result.replaceAllMapped(
    RegExp(
      r'(<img\b[^>]*\sstyle\s*=\s*")([^"]*)(")',
      caseSensitive: false,
    ),
    (match) {
      var style = match.group(2) ?? '';
      style = style.replaceAll(
        RegExp(r'width\s*:\s*[^;]+;?', caseSensitive: false),
        '',
      );
      style = style.replaceAll(
        RegExp(r'height\s*:\s*[^;]+;?', caseSensitive: false),
        '',
      );
      style = style.replaceAll(
        RegExp(r'max-width\s*:\s*[^;]+;?', caseSensitive: false),
        '',
      );
      return '${match.group(1)}$style${match.group(3)}';
    },
  );
  return result;
}

String processProductDetailHtml(String? rawHtml) {
  if (rawHtml == null || rawHtml.trim().isEmpty) return '';

  final srcPattern = RegExp(
    r'''src\s*=\s*(['"])(https?://[^'"]+)\1''',
    caseSensitive: false,
  );
  final withUrls = rawHtml.replaceAllMapped(srcPattern, (match) {
    final quote = match.group(1) ?? '"';
    final originalUrl = match.group(2) ?? '';
    final convertedUrl = ImageUrlHelper.convertToLocalUrl(originalUrl);
    return 'src=$quote$convertedUrl$quote';
  });
  return sanitizeProductDetailHtmlImages(withUrls);
}

Widget buildProductDetailHtml({
  required BuildContext context,
  required String html,
  String fontFamily = 'Gmarket Sans TTF',
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final contentWidth = constraints.maxWidth.clamp(0.0, double.infinity);
      final verticalGap = healthDp(context, 8);

      return SizedBox(
        width: contentWidth,
        child: Html(
          data: html,
          shrinkWrap: true,
          style: {
            'body': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              fontFamily: fontFamily,
              width: Width(contentWidth),
            ),
            'img': Style(
              width: Width(contentWidth),
              display: Display.block,
              margin: Margins.symmetric(vertical: verticalGap),
              alignment: Alignment.center,
            ),
            'div': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              fontFamily: fontFamily,
              width: Width(contentWidth),
            ),
            'p': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              display: Display.block,
              fontFamily: fontFamily,
              width: Width(contentWidth),
            ),
            'table': Style(
              width: Width(contentWidth),
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
            ),
            'span': Style(fontFamily: fontFamily),
            'li': Style(fontFamily: fontFamily),
            'h1': Style(fontFamily: fontFamily),
            'h2': Style(fontFamily: fontFamily),
            'h3': Style(fontFamily: fontFamily),
            'h4': Style(fontFamily: fontFamily),
            'a': Style(fontFamily: fontFamily),
          },
        ),
      );
    },
  );
}

/// 상단 캐러셀 — 화면 가로에 맞춰 전체 이미지 노출
Widget buildProductCarouselImage({
  required String imageUrl,
  required double width,
  required double height,
  required Widget Function(BuildContext, Object, StackTrace?) errorBuilder,
  required Widget Function(BuildContext, Widget, ImageChunkEvent?) loadingBuilder,
}) {
  return SizedBox(
    width: width,
    height: height,
    child: ColoredBox(
      color: const Color(0xFFF8F8F8),
      child: Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        errorBuilder: errorBuilder,
        loadingBuilder: loadingBuilder,
      ),
    ),
  );
}
