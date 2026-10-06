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
                    key: ValueKey(url),
                    url: url,
                    width: contentWidth,
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topCenter,
                    decodeWidthLogical: contentWidth,
                    preferHtmlElementOnWeb: false,
                    evictOnDispose: false,
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

class ProductDetailBlock {
  const ProductDetailBlock.image(this.imageUrl) : html = null;
  const ProductDetailBlock.html(this.html) : imageUrl = null;

  final String? imageUrl;
  final String? html;

  bool get isImage => imageUrl != null && imageUrl!.isNotEmpty;
}

/// 긴 상품 상세를 이미지/텍스트 단위로 분리하여 SliverList가 지연 생성할 수 있게 한다.
List<ProductDetailBlock> splitProductDetailBlocks(String html) {
  if (html.trim().isEmpty) return const [];
  final blocks = <ProductDetailBlock>[];
  final imageTag = RegExp(r'<img\b[^>]*>', caseSensitive: false);
  var start = 0;

  for (final match in imageTag.allMatches(html)) {
    _addDetailTextBlock(blocks, html.substring(start, match.start));
    final src = _detailImageSrc(match.group(0) ?? '');
    if (src != null) blocks.add(ProductDetailBlock.image(src));
    start = match.end;
  }
  _addDetailTextBlock(blocks, html.substring(start));
  return blocks;
}

void _addDetailTextBlock(List<ProductDetailBlock> blocks, String raw) {
  final chunk = raw.trim();
  final visible = chunk
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', '')
      .replaceAll(RegExp(r'\s+'), '');
  if (visible.isNotEmpty) blocks.add(ProductDetailBlock.html(chunk));
}

String? _detailImageSrc(String tag) {
  final match = RegExp(
    '''src\\s*=\\s*(['"])(.*?)\\1''',
    caseSensitive: false,
  ).firstMatch(tag);
  final raw = match?.group(2)?.trim().replaceAll('&amp;', '&');
  if (raw == null || raw.isEmpty) return null;
  return ImageUrlHelper.toWebSafeImageUrl(raw);
}

Widget buildProductDetailBlock({
  required BuildContext context,
  required ProductDetailBlock block,
  String fontFamily = 'Gmarket Sans TTF',
}) {
  if (!block.isImage) {
    return buildProductDetailHtml(
      context: context,
      html: block.html ?? '',
      fontFamily: fontFamily,
    );
  }
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      return AppNetworkImage(
        url: block.imageUrl!,
        width: width,
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
        decodeWidthLogical: width,
        preferHtmlElementOnWeb: false,
        evictOnDispose: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    },
  );
}

/// 펼치기 전 기존 모양을 유지하는 미리보기.
class ProductDetailCollapsedPreview extends StatelessWidget {
  const ProductDetailCollapsedPreview({
    super.key,
    required this.html,
    required this.horizontalPadding,
    required this.onExpand,
    this.expanded = false,
    this.margin,
    this.fontFamily = 'Gmarket Sans TTF',
  });

  final String html;
  final double horizontalPadding;
  final VoidCallback onExpand;
  final bool expanded;
  final EdgeInsetsGeometry? margin;
  final String fontFamily;

  @override
  Widget build(BuildContext context) {
    final previewHeight = healthDp(context, 320);

    return Container(
      margin: margin,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        children: [
          Stack(
            children: [
              ClipRect(
                child: SizedBox(
                  height: expanded ? null : previewHeight,
                  width: double.infinity,
                  child: IgnorePointer(
                    ignoring: !expanded,
                    child: buildProductDetailHtml(
                      context: context,
                      html: html,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
              ),
              if (!expanded)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: healthDp(context, 50),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x0DFFFFFF),
                            Color(0xC7FFFFFF),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (!expanded)
            SizedBox(
              height: healthDp(context, 24),
              child: OutlinedButton(
                onPressed: onExpand,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: const Color(0xFFFF4081),
                    width: healthDp(context, 1),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 14)),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 40),
                    vertical: healthDp(context, 5),
                  ),
                  foregroundColor: const Color(0xFFFF4081),
                ),
                child: Text(
                  '+ 자세히 보기',
                  style: TextStyle(
                    fontSize: healthSp(context, 12),
                    fontWeight: FontWeight.w500,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 상단 캐러셀 — 화면 가로에 맞춰 전체 이미지 노출
Widget buildProductCarouselImage({
  required String imageUrl,
  required double width,
  required double height,
  required Widget Function(BuildContext, Object, StackTrace?) errorBuilder,
  required Widget Function(BuildContext, Widget, ImageChunkEvent?)
      loadingBuilder,
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
        fit: BoxFit.cover,
        alignment: Alignment.center,
        decodeWidthLogical: width,
        decodeHeightLogical: height,
        errorBuilder: errorBuilder,
        loadingBuilder: loadingBuilder,
      ),
    ),
  );
}
