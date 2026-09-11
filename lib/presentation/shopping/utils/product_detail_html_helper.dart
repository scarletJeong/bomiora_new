import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../common/widgets/app_network_image.dart';
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

String _rewriteHtmlImageSrc(String html) {
  var result = html.replaceAllMapped(
    RegExp(
      r'''src\s*=\s*(['"])(//[^'"]+)\1''',
      caseSensitive: false,
    ),
    (match) {
      final quote = match.group(1) ?? '"';
      final originalUrl = 'https:${match.group(2) ?? ''}';
      return 'src=$quote${ImageUrlHelper.toWebSafeImageUrl(originalUrl)}$quote';
    },
  );

  result = result.replaceAllMapped(
    RegExp(
      r'''src\s*=\s*(['"])(https?://[^'"]+)\1''',
      caseSensitive: false,
    ),
    (match) {
      final quote = match.group(1) ?? '"';
      final originalUrl = (match.group(2) ?? '').replaceAll('&amp;', '&');
      return 'src=$quote${ImageUrlHelper.toWebSafeImageUrl(originalUrl)}$quote';
    },
  );

  result = result.replaceAllMapped(
    RegExp(
      r'''src\s*=\s*(['"])(/data/[^'"]+)\1''',
      caseSensitive: false,
    ),
    (match) {
      final quote = match.group(1) ?? '"';
      final path = match.group(2) ?? '';
      return 'src=$quote${ImageUrlHelper.toWebSafeImageUrl('https://bomiora0.mycafe24.com$path')}$quote';
    },
  );

  return result;
}

String _stripBlockHeights(String html) {
  return html.replaceAllMapped(
    RegExp(r'''(<(?:p|div|table|td|tr|span)\b[^>]*\sstyle\s*=\s*")([^"]*)(")''',
        caseSensitive: false),
    (match) {
      var style = match.group(2) ?? '';
      style = style.replaceAll(
        RegExp(r'(?:min-|max-)?height\s*:\s*[^;]+;?', caseSensitive: false),
        '',
      );
      style = style.replaceAll(
        RegExp(r'padding(?:-bottom|-top)?\s*:\s*[^;]+;?', caseSensitive: false),
        '',
      );
      return '${match.group(1)}$style${match.group(3)}';
    },
  );
}

String _stripTrailingEmptyHtml(String html) {
  var result = html.trimRight();
  final patterns = <RegExp>[
    RegExp(
      r'(?:<(?:p|div)[^>]*>\s*(?:&nbsp;|\s|<br[^>]*>)*\s*</(?:p|div)>)+$',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:<br[^>]*>|&nbsp;|\s)+$',
      caseSensitive: false,
    ),
  ];
  var prev = '';
  while (prev != result) {
    prev = result;
    result = result.trimRight();
    for (final pattern in patterns) {
      result = result.replaceAll(pattern, '');
    }
    result = result.replaceAllMapped(
      RegExp(
        r'(?:<br[^>]*>\s*)+(?:&nbsp;|\s)*</(p|div)>\s*$',
        caseSensitive: false,
      ),
      (m) => '</${m.group(1)}>',
    );
  }
  return result.trimRight();
}

String processProductDetailHtml(String? rawHtml) {
  if (rawHtml == null || rawHtml.trim().isEmpty) return '';
  final withUrls = _rewriteHtmlImageSrc(rawHtml);
  final cleaned = sanitizeProductDetailHtmlImages(withUrls);
  return _stripTrailingEmptyHtml(_stripBlockHeights(cleaned));
}

Widget buildProductDetailHtml({
  required BuildContext context,
  required String html,
  String fontFamily = 'Gmarket Sans TTF',
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final contentWidth = constraints.maxWidth.clamp(0.0, double.infinity);
      final verticalGap = healthDp(context, 4);

      return SizedBox(
        width: contentWidth,
        child: Html(
          data: html,
          shrinkWrap: true,
          extensions: [
            TagExtension(
              tagsToExtend: const {'img'},
              builder: (extensionContext) {
                final rawSrc = (extensionContext.attributes['src'] ?? '')
                    .trim()
                    .replaceAll('&amp;', '&');
                if (rawSrc.isEmpty) return const SizedBox.shrink();
                final url = ImageUrlHelper.toWebSafeImageUrl(rawSrc);
                return Padding(
                  padding: EdgeInsets.only(bottom: verticalGap),
                  child: AppNetworkImage(
                    url: url,
                    width: contentWidth,
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topCenter,
                    decodeWidthLogical: contentWidth,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                );
              },
            ),
          ],
          style: {
            'html': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
            ),
            'body': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              fontFamily: fontFamily,
              lineHeight: LineHeight.number(1),
            ),
            'img': Style(
              width: Width(contentWidth),
              display: Display.block,
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              alignment: Alignment.topCenter,
            ),
            'div': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              fontFamily: fontFamily,
              lineHeight: LineHeight.number(1),
            ),
            'p': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              display: Display.block,
              fontFamily: fontFamily,
              lineHeight: LineHeight.number(1),
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
      child: AppNetworkImage(
        url: ImageUrlHelper.toWebSafeImageUrl(imageUrl),
        width: width,
        height: height,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        decodeWidthLogical: width,
        decodeHeightLogical: height,
        errorBuilder: errorBuilder,
        loadingBuilder: loadingBuilder,
      ),
    ),
  );
}
